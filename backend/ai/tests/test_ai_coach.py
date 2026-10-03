import pytest
import sys
from pathlib import Path
from datetime import datetime, date

# Ensure root in sys.path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent.parent))

from backend.ai.config import settings
from backend.ai.safety.auth import verify_admin_token, sanitize_sensitive_data
from backend.ai.services.calculations import calc_engine
from backend.ai.rag.retriever import rag_retriever
from backend.ai.controller.ai_controller import ai_controller
from backend.ai.models.schemas import AiCoachChatRequest
from fastapi import HTTPException
from fastapi.security import HTTPAuthorizationCredentials

class TestAlphaXSecurity:
    def test_sanitize_sensitive_data(self):
        dirty = {
            "name": "Kumar",
            "passwordHash": "$2b$12$secretHash",
            "token": "secret_jwt",
            "stats": {"weight": 80.0, "password": "123"}
        }
        clean = sanitize_sensitive_data(dirty)
        assert "passwordHash" not in clean
        assert "token" not in clean
        assert "password" not in clean["stats"]
        assert clean["name"] == "Kumar"
        assert clean["stats"]["weight"] == 80.0

    def test_unauthorized_token_rejection(self):
        creds = HTTPAuthorizationCredentials(scheme="Bearer", credentials="invalid_or_fake_token")
        with pytest.raises(HTTPException) as exc:
            verify_admin_token(creds)
        assert exc.value.status_code == 401

class TestDeterministicCalculations:
    def test_macro_totals_exact_math(self):
        logs = [
            {"calories": 500, "protein": 40, "carbohydrates": 50, "fat": 15, "fiber": 5, "dateString": "2026-10-01"},
            {"calories": 700, "protein": 50, "carbohydrates": 70, "fat": 20, "fiber": 8, "dateString": "2026-10-01"},
            {"calories": 600, "protein": 45, "carbohydrates": 60, "fat": 18, "fiber": 6, "dateString": "2026-10-02"},
        ]
        totals = calc_engine.calculate_macro_totals(logs)
        assert totals["totalCalories"] == 1800.0
        assert totals["totalProtein"] == 135.0
        assert totals["totalCarbs"] == 180.0
        assert totals["totalFat"] == 53.0
        assert totals["daysLogged"] == 2
        assert totals["averageDailyCalories"] == 900.0
        assert totals["averageDailyProtein"] == 67.5

    def test_progressive_overload_upper_body(self):
        history = [
            {"actualWeight": 80.0, "actualReps": 10, "actualRpe": 8.0, "actualRir": 2}
        ]
        res = calc_engine.calculate_progressive_overload("Barbell Bench Press", history)
        assert res["hasHistory"] is True
        # Upper body 10 reps with RPE <= 8 should propose +2.5kg at 8 reps
        assert res["proposal"]["targetWeight"] == 82.5
        assert res["proposal"]["targetReps"] == "8"

    def test_progressive_overload_lower_body(self):
        history = [
            {"actualWeight": 100.0, "actualReps": 10, "actualRpe": 7.5, "actualRir": 3}
        ]
        res = calc_engine.calculate_progressive_overload("Barbell Back Squat", history)
        # Lower body 10 reps with solid RIR should propose +5.0kg
        assert res["proposal"]["targetWeight"] == 105.0
        assert res["proposal"]["targetReps"] == "8"

    def test_progressive_overload_high_fatigue(self):
        history = [
            {"actualWeight": 80.0, "actualReps": 7, "actualRpe": 9.5, "actualRir": 0}
        ]
        res = calc_engine.calculate_progressive_overload("Barbell Bench Press", history)
        # High effort / RPE 9.5 should consolidate at current weight
        assert res["proposal"]["targetWeight"] == 80.0
        assert res["proposal"]["targetReps"] == "7"

    def test_date_range_resolution(self):
        now = datetime.utcnow()
        s, e, label = calc_engine.resolve_date_range("analyze today's sessions")
        assert label == "Today"
        assert s.day == now.day

        s, e, label = calc_engine.resolve_date_range("this week's checkins")
        assert label == "This Week"

class TestRAGRetriever:
    def test_rag_protein_search(self):
        hits = rag_retriever.search_knowledge("daily protein targets for athletes in deficit", category="NUTRITION")
        assert len(hits) > 0
        assert "protein" in hits[0]["title"].lower() or "protein" in hits[0]["content"].lower()

    def test_rag_exercise_biomechanics_search(self):
        hits = rag_retriever.search_knowledge("bench press movement pattern cues", category="EXERCISES")
        assert len(hits) > 0
        assert "compound" in hits[0]["title"].lower() or "bench" in hits[0]["content"].lower()

class TestAIController:
    def test_daily_report_intent(self):
        req = AiCoachChatRequest(message="Give me today's report")
        resp = ai_controller.handle_admin_message(req, admin_id="test_admin", admin_name="Admin Alex")
        assert resp.intent == "DAILY_REPORT"
        assert resp.reportCard is not None

    def test_ambiguous_client_clarification(self):
        req = AiCoachChatRequest(message="Analyze the client's progress")
        resp = ai_controller.handle_admin_message(req, admin_id="test_admin", admin_name="Admin Alex")
        assert resp.intent == "AMBIGUOUS_CLIENT"
        assert "Which client" in resp.replyText

    def test_workout_proposal_intent(self):
        req = AiCoachChatRequest(message="Create a workout for Kumar")
        resp = ai_controller.handle_admin_message(req, admin_id="test_admin", admin_name="Admin Alex")
        assert resp.intent == "WORKOUT_PROPOSAL"
        assert resp.proposal is not None
        assert resp.proposal.proposalType == "WORKOUT"

    def test_diet_proposal_intent(self):
        req = AiCoachChatRequest(message="Create a diet proposal for Kumar")
        resp = ai_controller.handle_admin_message(req, admin_id="test_admin", admin_name="Admin Alex")
        assert resp.intent == "DIET_PROPOSAL"
        assert resp.proposal is not None
        assert resp.proposal.proposalType == "DIET"
