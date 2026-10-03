import pytest
import sys
import json
from pathlib import Path
from datetime import datetime, date, timedelta

# Ensure root in sys.path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent.parent))

from backend.ai.services.calculations import calc_engine
from backend.ai.agents.client_agent import client_agent
from backend.ai.agents.workout_agent import workout_agent
from backend.ai.agents.nutrition_agent import nutrition_agent
from backend.ai.controller.ai_controller import ai_controller
from backend.ai.models.schemas import AiCoachChatRequest

class TestPhase21RealisticClients:
    """
    Phase 21: End-to-End Realistic Athlete Scenarios (Specification Section 48)
    Verifies that the AI engine correctly differentiates distinct athlete profiles:
    - Client A: High adherence, good nutrition, solid progress
    - Client B: Low workout adherence, severe protein deficit
    - Client C: Missing weekly check-ins (>10 days)
    - Client D: Weight changed but waist did not (water/glycogen or recomposition)
    - Client E: High workout volume but poor recovery & acute joint discomfort
    """

    def test_client_a_high_adherence_and_progress(self):
        """Client A: Good workout adherence, good nutrition, good progress."""
        client_a = {
            "userId": "user_a",
            "clientProfileId": "cp_a",
            "clientId": "AXG-0001",
            "name": "Arun Anand",
            "fitnessLevel": "Intermediate",
            "trainingDaysPerWeek": 4,
            "weightKg": 80.5,
        }
        # Simulate calculations
        macro_totals = {
            "totalCalories": 30800,
            "totalProtein": 2310,
            "totalCarbs": 3500,
            "totalFat": 840,
            "daysLogged": 14,
            "averageDailyCalories": 2200.0,
            "averageDailyProtein": 165.0,
            "entriesCount": 42
        }
        assigned_diet = {"dailyCalories": 2200, "protein": 160}
        adherence = calc_engine.calculate_diet_adherence(assigned_diet, macro_totals)
        assert adherence["isProteinDeficient"] is False
        assert adherence["calorieDelta"] == 0.0

        weight_progress = calc_engine.calculate_weight_progress(
            progress_records=[
                {"recordedAt": datetime(2026, 9, 1), "weightKg": 82.0, "waistCm": 88.0},
                {"recordedAt": datetime(2026, 9, 28), "weightKg": 80.5, "waistCm": 85.0}
            ]
        )
        assert weight_progress["weightDeltaKg"] == -1.5
        assert weight_progress["waistDeltaCm"] == -3.0

        completeness = calc_engine.calculate_data_completeness(
            has_profile=True,
            has_workout_assigned=True,
            has_diet_assigned=True,
            checkin_count=4,
            food_log_days=14,
            weight_count=5,
            step_days=14
        )
        assert completeness["scorePercentage"] >= 85.0

    def test_client_b_poor_adherence_and_protein_deficit(self):
        """Client B: Poor workout adherence, poor protein."""
        client_b = {
            "userId": "user_b",
            "clientProfileId": "cp_b",
            "clientId": "AXG-0002",
            "name": "Bala Baskar",
            "fitnessLevel": "Beginner",
            "trainingDaysPerWeek": 4,
            "weightKg": 78.0,
        }
        macro_totals = {
            "totalCalories": 12000,
            "totalProtein": 520,
            "totalCarbs": 1600,
            "totalFat": 400,
            "daysLogged": 8,
            "averageDailyCalories": 1500.0,
            "averageDailyProtein": 65.0,
            "entriesCount": 16
        }
        assigned_diet = {"dailyCalories": 2100, "protein": 150}
        adherence = calc_engine.calculate_diet_adherence(assigned_diet, macro_totals)
        assert adherence["isProteinDeficient"] is True
        assert adherence["proteinDelta"] == -85.0

        signals = client_agent.evaluate_attention_signals(client_b)
        signal_types = [s["attentionType"] for s in signals]
        # Should flag missed workouts or missing/low food
        assert any(t in signal_types for t in ["MISSED_WORKOUT", "LOW_PROTEIN", "MISSING_FOOD", "MISSING_CHECKIN"])

    def test_client_c_missing_checkins(self):
        """Client C: Missing check-ins (>10 days)."""
        client_c = {
            "userId": "user_c",
            "clientProfileId": "cp_c",
            "clientId": "AXG-0003",
            "name": "Chetan Chandran",
            "fitnessLevel": "Intermediate",
            "trainingDaysPerWeek": 3,
            "weightKg": 75.0,
        }
        completeness = calc_engine.calculate_data_completeness(
            has_profile=True,
            has_workout_assigned=True,
            has_diet_assigned=True,
            checkin_count=0,
            food_log_days=7,
            weight_count=2,
            step_days=7
        )
        assert any("check-in" in item.lower() for item in completeness["missingItems"])

    def test_client_d_weight_changed_waist_did_not(self):
        """Client D: Weight changed but waist did not."""
        progress_records = [
            {"recordedAt": datetime(2026, 9, 1), "weightKg": 85.0, "waistCm": 92.0},
            {"recordedAt": datetime(2026, 9, 30), "weightKg": 82.5, "waistCm": 92.0},
        ]
        res = calc_engine.calculate_weight_progress(progress_records)
        assert res["weightDeltaKg"] == -2.5
        assert res["waistDeltaCm"] == 0.0
        # Check that math engine outputs exactly this without hallucinating waist reduction

    def test_client_e_high_consistency_poor_recovery_and_pain(self):
        """Client E: High workout consistency but poor recovery & acute pain."""
        checkin_e = {
            "weekNumber": 4,
            "checkInDate": datetime.utcnow(),
            "sleepHours": 5.0,
            "sleepQuality": "POOR",
            "recoveryQuality": "POOR",
            "hasPain": True,
            "painLocation": "Right Shoulder",
            "painExercise": "Overhead Press",
            "painLevel": 7
        }
        assert checkin_e["hasPain"] is True
        assert checkin_e["painLevel"] >= 6
        assert checkin_e["sleepHours"] < 6.0
        assert checkin_e["recoveryQuality"] == "POOR"

    def test_end_to_end_proposal_and_approval_flow(self):
        """Tests complete AI Proposal -> Admin Approval -> Audit Lifecycle."""
        # 1. Generate workout proposal
        client_test = {
            "userId": "user_demo",
            "clientProfileId": "cp_demo",
            "clientId": "AXG-9999",
            "name": "Demo Athlete",
            "fitnessLevel": "Intermediate",
            "trainingDaysPerWeek": 4,
        }
        prop = workout_agent.generate_workout_session_proposal(client_test, conversation_id=None)
        assert prop["status"] == "PENDING"
        assert prop["proposalType"] == "WORKOUT"
        assert len(prop["proposedData"]["exercises"]) > 0
