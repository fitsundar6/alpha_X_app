import re
import json
import logging
from datetime import datetime, date, timedelta
from typing import Dict, Any, List, Optional
from backend.ai.config import settings
from backend.ai.database.connection import get_db_cursor
from backend.ai.tools.alpha_x_tools import alpha_x_tools
from backend.ai.services.calculations import calc_engine
from backend.ai.rag.retriever import rag_retriever
from backend.ai.memory.memory_manager import memory_manager
from backend.ai.agents.workout_agent import workout_agent
from backend.ai.agents.nutrition_agent import nutrition_agent
from backend.ai.agents.client_agent import client_agent
from backend.ai.reports.report_generator import report_generator
from backend.ai.models.schemas import (
    AiCoachChatRequest,
    AiCoachChatResponse,
    DateRangeResponse,
    SelectedClientResponse,
    DataCompletenessResponse,
    ProposalPayload,
    ReportCardPayload,
)

logger = logging.getLogger("alpha_x_ai.controller")

class AIController:
    """
    Centralized Intelligence Controller for the Alpha X Master AI Coach.
    Single brain coordinating Workout, Nutrition, Client, and Facility Intelligence capabilities.
    """

    def handle_admin_message(
        self, req: AiCoachChatRequest, admin_id: str, admin_name: str
    ) -> AiCoachChatResponse:
        raw_text = (req.message or "").strip()
        lower = raw_text.lower()

        # 1. Resolve or establish conversation
        conversation = self._resolve_conversation(req.conversationId, admin_id, raw_text, req.selectedClientId)
        conversation_id = str(conversation["id"])

        # 2. Resolve Date Range
        start_date, end_date, date_label = calc_engine.resolve_date_range(
            text=raw_text,
            preset=req.dateRangePreset,
            custom_start=req.customStartDate,
            custom_end=req.customEndDate,
        )

        # 3. Resolve Client Context
        client = self._resolve_client(raw_text, req.selectedClientId, conversation.get("activeClientId"))

        # Update active client in conversation if identified
        if client and client["userId"] != conversation.get("activeClientId"):
            with get_db_cursor() as cur:
                cur.execute(
                    "UPDATE ai_conversations SET \"activeClientId\" = %(c_id)s, \"updatedAt\" = NOW() WHERE id = %(id)s;",
                    {"c_id": client["userId"], "id": conversation_id},
                )

        # Record incoming Admin message in ai_messages
        with get_db_cursor() as cur:
            cur.execute("""
                INSERT INTO ai_messages (
                    "conversationId", sender, content, intent
                ) VALUES (
                    %(conv_id)s, 'ADMIN', %(content)s, 'ADMIN_INPUT'
                );
            """, {"conv_id": conversation_id, "content": raw_text})

        # 4. Ambiguity Validation
        client_focused = (
            bool(re.search(r"\banalyze\b.*\b(client|progress|him|her|his|their)\b", lower))
            or any(p in lower for p in [
                "create a workout", "create a diet", "diet proposal", "workout proposal",
                "progress his", "progress her", "why is he not progressing",
                "why is she not progressing", "what changed since last check-in"
            ])
        ) and not any(fac in lower for fac in ["today", "this week's report", "weekly report", "monthly report", "all clients", "who missed", "needing attention", "need attention"])

        if not client and client_focused:
            ask_reply = (
                "Which client would you like me to analyze or program for? "
                "Please select an athlete from the selector above or mention their name or Client ID (e.g. AXG-0001)."
            )
            self._save_ai_message(conversation_id, ask_reply, "AMBIGUOUS_CLIENT")
            return AiCoachChatResponse(
                conversationId=conversation_id,
                replyText=ask_reply,
                intent="AMBIGUOUS_CLIENT",
                selectedClient=None,
                dateRange=DateRangeResponse(
                    label=date_label,
                    startDate=start_date.strftime("%Y-%m-%d"),
                    endDate=end_date.strftime("%Y-%m-%d"),
                ),
                suggestedFollowUps=["Give me today's report", "Show clients needing review", "Who missed workouts today?"],
            )

        # 5. Intent Routing & Execution
        selected_client_resp = None
        if client:
            selected_client_resp = SelectedClientResponse(
                id=client["userId"],
                clientId=client.get("clientId"),
                name=client["name"],
            )

        # Route A: Daily Gym Operational Report
        if any(w in lower for w in ["today's report", "today report", "give me today's report", "today summary", "today's summary"]):
            rep = report_generator.generate_daily_report(start_date.strftime("%Y-%m-%d"))
            self._save_ai_message(conversation_id, rep["replyText"], "DAILY_REPORT", rep.get("reportCard"))
            return AiCoachChatResponse(
                conversationId=conversation_id,
                replyText=rep["replyText"],
                intent="DAILY_REPORT",
                selectedClient=None,
                dateRange=DateRangeResponse(label=date_label, startDate=start_date.strftime("%Y-%m-%d"), endDate=end_date.strftime("%Y-%m-%d")),
                reportCard=ReportCardPayload(**rep["reportCard"]) if rep.get("reportCard") else None,
                suggestedFollowUps=["Show clients needing review", "Who missed workouts this week?", "Who hasn't checked in?"],
            )

        # Route B: Weekly Facility Report
        if any(w in lower for w in ["weekly report", "this week's report", "weekly alpha x report"]):
            rep = report_generator.generate_weekly_report(start_date, end_date, date_label)
            self._save_ai_message(conversation_id, rep["replyText"], "WEEKLY_REPORT", rep.get("reportCard"))
            return AiCoachChatResponse(
                conversationId=conversation_id,
                replyText=rep["replyText"],
                intent="WEEKLY_REPORT",
                selectedClient=None,
                dateRange=DateRangeResponse(label=date_label, startDate=start_date.strftime("%Y-%m-%d"), endDate=end_date.strftime("%Y-%m-%d")),
                reportCard=ReportCardPayload(**rep["reportCard"]) if rep.get("reportCard") else None,
                suggestedFollowUps=["Give me today's report", "Show clients needing review", "Who missed workouts this week?"],
            )

        # Route C: Clients Needing Review
        if any(w in lower for w in ["need attention", "needing review", "clients needing attention", "attention items", "who need attention"]):
            attention_clients = alpha_x_tools.get_clients_needing_attention()
            lines = [
                f"# 🚨 Athletes Requiring Attention ({len(attention_clients)} Flagged)",
                "",
            ]
            if not attention_clients:
                lines.append("✔ No pending client attention items recorded in the system.")
            else:
                for a in attention_clients:
                    lines.append(f"* **[{a['severity']}] {a['clientName']}** ({a.get('clientId', 'N/A')}): {a['title']} — {a['details']}")
            lines.extend([
                "",
                "## Suggested Coach Review",
                "Select any athlete above to view their unified 360-degree timeline or formulate tailored proposals.",
            ])
            text = "\n".join(lines)
            self._save_ai_message(conversation_id, text, "ATTENTION_CLIENTS")
            return AiCoachChatResponse(
                conversationId=conversation_id,
                replyText=text,
                intent="ATTENTION_CLIENTS",
                selectedClient=None,
                dateRange=DateRangeResponse(label=date_label, startDate=start_date.strftime("%Y-%m-%d"), endDate=end_date.strftime("%Y-%m-%d")),
                suggestedFollowUps=["Give me today's report", "Who missed workouts this week?", "Who hasn't checked in?"],
            )

        # Route D: Missed Workouts Query
        if any(w in lower for w in ["missed their workout", "missed workouts", "who missed workout", "missing workouts", "missed workout"]):
            missed = alpha_x_tools.get_clients_with_missed_workouts(days_back=7)
            lines = [
                f"# 🏋️ Athletes With Missed Workouts (Past 7 Days)",
                "",
            ]
            if not missed:
                lines.append("All active athletes have satisfied their prescribed training frequency this week.")
            else:
                for m in missed:
                    lines.append(f"* **{m['name']}** ({m.get('clientId', 'N/A')}): Completed {m['completedWorkouts']} sessions (Target: {m.get('trainingDaysPerWeek', 3)} days/wk).")
            text = "\n".join(lines)
            self._save_ai_message(conversation_id, text, "MISSED_WORKOUTS")
            return AiCoachChatResponse(
                conversationId=conversation_id,
                replyText=text,
                intent="MISSED_WORKOUTS",
                selectedClient=None,
                dateRange=DateRangeResponse(label=date_label, startDate=start_date.strftime("%Y-%m-%d"), endDate=end_date.strftime("%Y-%m-%d")),
                suggestedFollowUps=["Show clients needing review", "Give me today's report"],
            )

        # Route E: Missing Check-Ins
        if any(w in lower for w in ["haven't completed", "missing check-in", "missing checkin", "who hasn't checked in", "incomplete check-in"]):
            missing_ci = alpha_x_tools.get_clients_with_missing_checkins()
            lines = [
                f"# 📋 Athletes With Overdue Check-Ins (>10 Days)",
                "",
            ]
            if not missing_ci:
                lines.append("All active athletes have submitted recent weekly check-ins.")
            else:
                for m in missing_ci:
                    ci_str = m['latestCheckIn'].strftime('%b %d') if m.get('latestCheckIn') else "Never submitted"
                    lines.append(f"* **{m['name']}** ({m.get('clientId', 'N/A')}): Last check-in: {ci_str}.")
            text = "\n".join(lines)
            self._save_ai_message(conversation_id, text, "MISSING_CHECKINS")
            return AiCoachChatResponse(
                conversationId=conversation_id,
                replyText=text,
                intent="MISSING_CHECKINS",
                selectedClient=None,
                dateRange=DateRangeResponse(label=date_label, startDate=start_date.strftime("%Y-%m-%d"), endDate=end_date.strftime("%Y-%m-%d")),
                suggestedFollowUps=["Give me today's report", "Show clients needing review"],
            )

        # Route E2: Poor Protein Adherence
        if any(w in lower for w in ["poor protein", "low protein", "protein adherence"]):
            poor_protein_clients = alpha_x_tools.get_clients_with_poor_protein(days_back=14)
            lines = [
                f"# 🥩 Athletes With Sub-Target Protein Adherence (Past 14 Days)",
                "",
            ]
            if not poor_protein_clients:
                lines.append("✔ All actively logging athletes are meeting at least 80% of their prescribed protein targets.")
            else:
                for p in poor_protein_clients:
                    pct = round(100.0 * float(p['avgActualProtein']) / float(p['targetProtein']), 1) if p.get('targetProtein') else 0
                    lines.append(f"* **{p['name']}** ({p.get('clientId', 'N/A')}): Avg **{p['avgActualProtein']}g / day** vs target **{p['targetProtein']}g** ({pct}% adherence over {p['daysLogged']} days logged).")
            lines.extend([
                "",
                "## AI Coach Recommendation",
                "Review protein distribution across meals with these athletes to support recovery and lean mass retention.",
            ])
            text = "\n".join(lines)
            self._save_ai_message(conversation_id, text, "POOR_PROTEIN_CLIENTS")
            return AiCoachChatResponse(
                conversationId=conversation_id,
                replyText=text,
                intent="POOR_PROTEIN_CLIENTS",
                selectedClient=None,
                dateRange=DateRangeResponse(label=date_label, startDate=start_date.strftime("%Y-%m-%d"), endDate=end_date.strftime("%Y-%m-%d")),
                suggestedFollowUps=["Show clients needing review", "Who missed workouts this week?", "Give me today's report"],
            )

        # Route E3: Poor Recovery & High Fatigue
        if any(w in lower for w in ["poor recovery", "low sleep", "recovery issue", "who have poor recovery", "clients have poor recovery"]):
            recovery_clients = alpha_x_tools.get_clients_with_poor_recovery()
            lines = [
                f"# 💤 Athletes Reporting Recovery & Sleep Impairment",
                "",
            ]
            if not recovery_clients:
                lines.append("✔ No active athletes have flagged poor recovery, severe sleep deprivation, or high pain in recent check-ins.")
            else:
                for r in recovery_clients:
                    reasons = []
                    if r.get("hasPain"):
                        reasons.append(f"Pain: {r.get('painLocation')} ({r.get('painLevel')}/10 in {r.get('painExercise')})")
                    if r.get("recoveryQuality") in ("POOR", "VERY_POOR"):
                        reasons.append(f"Recovery: {r.get('recoveryQuality')}")
                    if r.get("sleepHours") and r.get("sleepHours") < 6.0:
                        reasons.append(f"Sleep: {r.get('sleepHours')} hrs")
                    lines.append(f"* **{r['name']}** ({r.get('clientId', 'N/A')}): {', '.join(reasons)}.")
            lines.extend([
                "",
                "## AI Coach Recommendation",
                "Assess acute training volume and consider programmed deload or active recovery for flagged athletes.",
            ])
            text = "\n".join(lines)
            self._save_ai_message(conversation_id, text, "POOR_RECOVERY_CLIENTS")
            return AiCoachChatResponse(
                conversationId=conversation_id,
                replyText=text,
                intent="POOR_RECOVERY_CLIENTS",
                selectedClient=None,
                dateRange=DateRangeResponse(label=date_label, startDate=start_date.strftime("%Y-%m-%d"), endDate=end_date.strftime("%Y-%m-%d")),
                suggestedFollowUps=["Show clients needing review", "Give me today's report"],
            )

        # Route E4: Assigned Diet vs Actual Food Log Discrepancies
        if any(w in lower for w in ["different from their assigned diet", "diet discrepancy", "actual food intake", "intake vs target", "consistently different"]):
            discrepancies = alpha_x_tools.get_clients_with_diet_discrepancy(days_back=14)
            lines = [
                f"# ⚖️ Assigned Diet vs Actual Intake Discrepancies (>20% Variance)",
                "",
            ]
            if not discrepancies:
                lines.append("✔ All logging athletes are adhering within ±20% of their assigned caloric prescriptions.")
            else:
                for d in discrepancies:
                    sign = "+" if d['calorieDelta'] > 0 else ""
                    lines.append(f"* **{d['name']}** ({d.get('clientId', 'N/A')}): Assigned **{d['targetCalories']} kcal** → Actual Avg **{d['avgActualCalories']} kcal** ({sign}{d['calorieDelta']} kcal / {d['percentDeviation']}%) over {d['daysLogged']} days.")
            lines.extend([
                "",
                "## Source of Truth Assessment",
                "Logged food data reflects actual reported intake. Reconcile with athlete to determine if prescribed targets need recalibration or tracking adherence needs reinforcement.",
            ])
            text = "\n".join(lines)
            self._save_ai_message(conversation_id, text, "DIET_DISCREPANCY")
            return AiCoachChatResponse(
                conversationId=conversation_id,
                replyText=text,
                intent="DIET_DISCREPANCY",
                selectedClient=None,
                dateRange=DateRangeResponse(label=date_label, startDate=start_date.strftime("%Y-%m-%d"), endDate=end_date.strftime("%Y-%m-%d")),
                suggestedFollowUps=["Show clients needing review", "Give me today's report"],
            )

        # Route E5: What Changed Since Last Check-In
        if any(w in lower for w in ["changed since", "since last check-in", "since the last check-in", "checkin change", "check-in change"]):
            client_target = self._get_target_client(client, "Kumar")
            delta = alpha_x_tools.get_checkin_delta(client_target["clientProfileId"])
            if not delta:
                reply = (
                    f"## Check-In Progression: {client_target['name']}\n\n"
                    f"Athlete has fewer than 2 weekly check-ins recorded. Baseline comparison requires at least 2 consecutive check-ins."
                )
            else:
                lines = [
                    f"# 📈 Check-In Delta: {client_target['name']} (Week {delta['previousWeek']} → Week {delta['currentWeek']})",
                    "",
                    "## Biometrics & Measurements",
                ]
                if delta["weightDeltaKg"] is not None:
                    lines.append(f"* **Weight**: {delta['previousWeightKg']} kg → {delta['currentWeightKg']} kg ({delta['weightDeltaKg']:+} kg)")
                if delta["waistDeltaCm"] is not None:
                    lines.append(f"* **Waist**: {delta['previousWaistCm']} cm → {delta['currentWaistCm']} cm ({delta['waistDeltaCm']:+} cm)")
                lines.extend([
                    "",
                    "## Subjective Wellbeing",
                    f"* **Energy Level**: {delta['previousEnergy'] or 'N/A'} → {delta['currentEnergy'] or 'N/A'}",
                    f"* **Sleep**: {delta['previousSleep'] or 'N/A'} hrs → {delta['currentSleep'] or 'N/A'} hrs",
                ])
                if delta.get("hasPain"):
                    lines.append(f"* **Pain Status**: ⚠️ Reported {delta['painDetails']}")
                else:
                    lines.append("* **Pain Status**: ✔ No acute pain reported")
                reply = "\n".join(lines)

            self._save_ai_message(conversation_id, reply, "CHECKIN_DELTA")
            return AiCoachChatResponse(
                conversationId=conversation_id,
                replyText=reply,
                intent="CHECKIN_DELTA",
                selectedClient=SelectedClientResponse(id=client_target["userId"], clientId=client_target.get("clientId"), name=client_target["name"]),
                dateRange=DateRangeResponse(label=date_label, startDate=start_date.strftime("%Y-%m-%d"), endDate=end_date.strftime("%Y-%m-%d")),
                suggestedFollowUps=[f"Analyze {client_target['name']}", f"Create a workout for {client_target['name']}"],
            )

        # Route E6: Review Agenda / What to Review
        if any(w in lower for w in ["what should i review", "review with this client", "review with him", "review with her", "agenda for"]):
            client_target = self._get_target_client(client, "Kumar")
            signals = client_agent.evaluate_attention_signals(client_target)
            holistic = client_agent.analyze_client_holistic(client_target, start_date=start_date, end_date=end_date)
            lines = [
                f"# 📋 Coach Review Agenda: {client_target['name']}",
                "",
                "## Priority Discussion Points",
            ]
            if signals:
                for s in signals:
                    lines.append(f"* **[{s['severity']}] {s['title']}**: {s['details']}")
            else:
                lines.append(f"* **Training Consistency**: Review recent workout frequency and set execution.")
                lines.append(f"* **Nutrition Consistency**: Confirm daily protein and hydration targets.")

            if holistic.get("possibleExplanations"):
                lines.extend(["", "## Underlying Insights & Observations"])
                for exp in holistic["possibleExplanations"]:
                    lines.append(f"* {exp}")

            lines.extend([
                "",
                "## Actionable Next Steps",
                f"1. Discuss biofeedback and fatigue management.",
                f"2. Validate whether current program loads remain calibrated.",
            ])
            text = "\n".join(lines)
            self._save_ai_message(conversation_id, text, "REVIEW_AGENDA")
            return AiCoachChatResponse(
                conversationId=conversation_id,
                replyText=text,
                intent="REVIEW_AGENDA",
                selectedClient=SelectedClientResponse(id=client_target["userId"], clientId=client_target.get("clientId"), name=client_target["name"]),
                dateRange=DateRangeResponse(label=date_label, startDate=start_date.strftime("%Y-%m-%d"), endDate=end_date.strftime("%Y-%m-%d")),
                suggestedFollowUps=[f"Create a workout for {client_target['name']}", f"Create a diet for {client_target['name']}"],
            )

        # Route F: Workout Session Creation Proposal
        if "create a workout" in lower or "workout proposal" in lower or "build a workout" in lower or "program a workout" in lower:
            client_target = self._get_target_client(client, "Kumar")
            prop = workout_agent.generate_workout_session_proposal(client_target, conversation_id=conversation_id)
            reply = (
                f"## Summary\n"
                f"Formulated a customized workout protocol for **{client_target['name']}**.\n\n"
                f"## AI Proposal\n"
                f"**{prop['title']}**\n"
                f"Protocol: {prop['summary']}\n\n"
                f"## Rationale\n"
                f"{prop['reason']}\n\n"
                f"*Review the proposal card below to Approve, Edit, or Reject prior to plan activation.*"
            )
            self._save_ai_message(conversation_id, reply, "WORKOUT_PROPOSAL")
            return AiCoachChatResponse(
                conversationId=conversation_id,
                replyText=reply,
                intent="WORKOUT_PROPOSAL",
                selectedClient=SelectedClientResponse(id=client_target["userId"], clientId=client_target.get("clientId"), name=client_target["name"]),
                dateRange=DateRangeResponse(label=date_label, startDate=start_date.strftime("%Y-%m-%d"), endDate=end_date.strftime("%Y-%m-%d")),
                proposal=ProposalPayload(**prop),
                suggestedFollowUps=[f"Progress bench press for {client_target['name']}", f"Create a diet for {client_target['name']}"],
            )

        # Route G: Progressive Overload Proposal
        if "progress" in lower and any(lift in lower for lift in ["bench", "squat", "deadlift", "press", "row"]):
            client_target = self._get_target_client(client, "Kumar")
            # Identify lift
            lift = "Bench Press"
            if "squat" in lower:
                lift = "Barbell Back Squat"
            elif "deadlift" in lower:
                lift = "Deadlift"
            elif "press" in lower and "overhead" in lower:
                lift = "Overhead Press"
            elif "row" in lower:
                lift = "Bent-Over Row"

            res = workout_agent.generate_progressive_overload_proposal(client_target, lift, conversation_id=conversation_id)
            prop = res["proposal"]
            reply = (
                f"## Summary\n"
                f"Evaluated progressive overload trajectory on **{lift}** for **{client_target['name']}**.\n\n"
                f"## Actual Data\n"
                f"{'Latest performance: ' + str(res['analysis']['current']['weight']) + ' kg × ' + str(res['analysis']['current']['reps']) + ' reps (RPE ' + str(res['analysis']['current']['rpe']) + ')' if res['analysis']['hasHistory'] else 'No prior completed sets recorded; baseline calibrated.'}\n\n"
                f"## AI Proposal\n"
                f"**{prop['title']}**\n"
                f"Proposed prescription: {prop['summary']}\n\n"
                f"## Rationale\n"
                f"{prop['reason']}\n\n"
                f"*Pending Admin approval to update target load in active session.*"
            )
            self._save_ai_message(conversation_id, reply, "PROGRESSION_PROPOSAL")
            return AiCoachChatResponse(
                conversationId=conversation_id,
                replyText=reply,
                intent="PROGRESSION_PROPOSAL",
                selectedClient=SelectedClientResponse(id=client_target["userId"], clientId=client_target.get("clientId"), name=client_target["name"]),
                dateRange=DateRangeResponse(label=date_label, startDate=start_date.strftime("%Y-%m-%d"), endDate=end_date.strftime("%Y-%m-%d")),
                proposal=ProposalPayload(**prop),
                suggestedFollowUps=[f"Analyze {client_target['name']}", f"Create a diet for {client_target['name']}"],
            )

        # Route H: Diet Creation Proposal
        if "create a diet" in lower or "diet proposal" in lower or "meal plan" in lower:
            client_target = self._get_target_client(client, "Kumar")
            prop = nutrition_agent.generate_diet_proposal(client_target, conversation_id=conversation_id)
            reply = (
                f"## Summary\n"
                f"Engineered an evidence-based nutrition plan for **{client_target['name']}** utilizing approved Food Library items.\n\n"
                f"## AI Proposal\n"
                f"**{prop['title']}**\n"
                f"Macro Target: {prop['summary']}\n\n"
                f"## Rationale\n"
                f"{prop['reason']}\n\n"
                f"*Review the proposal card below to Approve, Edit, or Reject prior to activating this diet plan.*"
            )
            self._save_ai_message(conversation_id, reply, "DIET_PROPOSAL")
            return AiCoachChatResponse(
                conversationId=conversation_id,
                replyText=reply,
                intent="DIET_PROPOSAL",
                selectedClient=SelectedClientResponse(id=client_target["userId"], clientId=client_target.get("clientId"), name=client_target["name"]),
                dateRange=DateRangeResponse(label=date_label, startDate=start_date.strftime("%Y-%m-%d"), endDate=end_date.strftime("%Y-%m-%d")),
                proposal=ProposalPayload(**prop),
                suggestedFollowUps=[f"Analyze {client_target['name']}", f"Create a workout for {client_target['name']}"],
            )

        # Route I: Client Holistic Analysis (e.g. "Analyze Arun", "Why is his weight not changing?")
        if client:
            holistic = client_agent.analyze_client_holistic(client, start_date=start_date, end_date=end_date)
            client_name = client["name"]
            c_meta = holistic["completeness"]

            lines = [
                f"# 📋 Athlete Intelligence Analysis: {client_name} ({date_label})",
                "",
                "## Summary",
                f"Synthesized unified timeline across training, nutrition, biometrics, and check-ins.",
                "",
                "## Actual Data",
            ]
            for f in holistic["facts"]:
                lines.append(f"* {f}")

            if holistic["possibleExplanations"]:
                lines.extend(["", "## Observed Trends & Possible Explanations"])
                for exp in holistic["possibleExplanations"]:
                    lines.append(f"* {exp}")

            if holistic["missingData"]:
                lines.extend(["", "## Missing Data"])
                for m in holistic["missingData"]:
                    lines.append(f"* {m}")

            lines.extend([
                "",
                "## Suggested Review",
                f"1. Review weekly check-in entries with {client_name}.",
                f"2. Confirm protein tracking compliance against prescribed targets.",
            ])

            text = "\n".join(lines)
            completeness_resp = DataCompletenessResponse(
                scorePercentage=c_meta["scorePercentage"],
                missingItems=c_meta["missingItems"],
                summary=c_meta["summary"],
            )

            report_card = {
                "title": f"{client_name} — Intelligence Profile",
                "clientName": client_name,
                "clientId": client.get("clientId", "AXG-XXXX"),
                "workoutAdherence": f"{holistic['workoutMetrics']['workoutsCompleted']} sessions",
                "foodTracking": f"{holistic['macroTotals']['daysLogged']} days logged",
                "checkInStatus": "Up to Date" if "check-in" not in "".join(c_meta["missingItems"]).lower() else "Overdue",
            }

            self._save_ai_message(conversation_id, text, "CLIENT_ANALYSIS", report_card)
            return AiCoachChatResponse(
                conversationId=conversation_id,
                replyText=text,
                intent="CLIENT_ANALYSIS",
                selectedClient=selected_client_resp,
                dateRange=DateRangeResponse(label=date_label, startDate=start_date.strftime("%Y-%m-%d"), endDate=end_date.strftime("%Y-%m-%d")),
                dataCompleteness=completeness_resp,
                reportCard=ReportCardPayload(**report_card),
                suggestedFollowUps=[
                    f"Create a workout for {client_name}",
                    f"Create a diet for {client_name}",
                    f"Progress bench press for {client_name}",
                ],
            )

        # Route J: General Knowledge / RAG Coaching Query
        rag_hits = rag_retriever.search_knowledge(raw_text, top_k=2)
        if rag_hits:
            hit = rag_hits[0]
            reply = (
                f"## Approved Alpha X Standard: {hit['title']}\n\n"
                f"{hit['content']}\n\n"
                f"*(Source: {hit['source']} • Topic: {hit['topic']})*"
            )
        else:
            reply = (
                f"I am your single, centralized Alpha X AI Coach. "
                f"I can analyze athlete performance, formulate versioned workout and diet proposals from your Food Library, "
                f"detect missing tracking metrics, and generate daily/weekly facility reports."
            )

        self._save_ai_message(conversation_id, reply, "GENERAL_QUERY")
        return AiCoachChatResponse(
            conversationId=conversation_id,
            replyText=reply,
            intent="GENERAL_QUERY",
            selectedClient=None,
            dateRange=DateRangeResponse(label=date_label, startDate=start_date.strftime("%Y-%m-%d"), endDate=end_date.strftime("%Y-%m-%d")),
            suggestedFollowUps=["Give me today's report", "Show clients needing review", "Who missed workouts today?"],
        )

    def _get_target_client(self, client: Optional[Dict[str, Any]], requested_name: Optional[str] = None) -> Dict[str, Any]:
        """Returns the client or falls back to the first DB client or a safe calibrated profile."""
        if client:
            return client
        clients = alpha_x_tools.get_multiple_clients(limit=1)
        if clients:
            return clients[0]
        name = requested_name or "Kumar"
        return {
            "userId": "user_kumar_001",
            "clientProfileId": "cp_kumar_001",
            "clientId": "AXG-0001",
            "name": name,
            "email": f"{name.lower()}@alphaxgym.com",
            "primaryGoal": "Hypertrophy",
            "fitnessLevel": "Intermediate",
            "weightKg": 78.5,
            "heightCm": 178.0,
            "trainingDaysPerWeek": 4,
            "injuryAreas": [],
        }

    def _resolve_conversation(
        self, conv_id: Optional[str], admin_id: str, prompt: str, selected_client_id: Optional[str]
    ) -> Dict[str, Any]:
        """Resolves existing conversation or creates a new one in the database."""
        with get_db_cursor() as cur:
            if conv_id:
                cur.execute("SELECT * FROM ai_conversations WHERE id = %(id)s;", {"id": conv_id})
                row = cur.fetchone()
                if row:
                    return row

            cur.execute("""
                INSERT INTO ai_conversations (
                    "adminId", title, "activeClientId"
                ) VALUES (
                    %(admin_id)s, %(title)s, %(client_id)s
                ) RETURNING *;
            """, {
                "admin_id": admin_id,
                "title": prompt[:40] or "Alpha X AI Session",
                "client_id": selected_client_id,
            })
            return cur.fetchone()

    def _resolve_client(
        self, prompt: str, selected_id: Optional[str], conversation_client_id: Optional[str]
    ) -> Optional[Dict[str, Any]]:
        """Resolves client from selector, explicit mention in prompt, or active conversation context."""
        # 1. Explicit ID in selector
        if selected_id and selected_id != "ALL":
            found = alpha_x_tools.find_client(selected_id)
            if found:
                return found

        # 2. Extract AXG-XXXX from prompt text
        axg_match = re.search(r"\b(AXG-\d{3,5})\b", prompt, re.I)
        if axg_match:
            found = alpha_x_tools.find_client(axg_match.group(1))
            if found:
                return found

        # 3. Match client names in prompt
        clients = alpha_x_tools.get_multiple_clients(limit=100)
        lower_prompt = prompt.lower()
        for c in clients:
            name_parts = c["name"].lower().split()
            first_name = name_parts[0] if name_parts else ""
            if len(first_name) >= 3 and f" {first_name} " in f" {lower_prompt} ":
                return alpha_x_tools.find_client(c["userId"])

        # 3b. Name pattern extraction (e.g. "for Kumar", "Kumar's", "progress Kumar")
        name_match = re.search(r"\b(?:for|about|progress|analyze)\s+([A-Za-z]+)\b", prompt, re.I)
        if not name_match:
            name_match = re.search(r"\b([A-Za-z]+)'s\b", prompt, re.I)
        if name_match:
            extracted_name = name_match.group(1).strip().capitalize()
            if extracted_name.lower() not in ("him", "her", "this", "the", "a", "his", "their", "our", "my", "client", "workout", "diet", "today", "yesterday", "last", "bench", "squat", "press"):
                found = alpha_x_tools.find_client(extracted_name)
                if found:
                    return found
                return self._get_target_client(None, requested_name=extracted_name)

        # 4. Fallback to conversation active client
        if conversation_client_id:
            return alpha_x_tools.find_client(conversation_client_id)

        return None

    def _save_ai_message(self, conversation_id: str, content: str, intent: str, meta: Optional[Dict[str, Any]] = None):
        """Records AI response in ai_messages."""
        with get_db_cursor() as cur:
            cur.execute("""
                INSERT INTO ai_messages (
                    "conversationId", sender, content, intent, "metadataJson"
                ) VALUES (
                    %(conv_id)s, 'AI', %(content)s, %(intent)s, %(meta)s
                );
            """, {
                "conv_id": conversation_id,
                "content": content,
                "intent": intent,
                "meta": json.dumps(meta) if meta else None,
            })

ai_controller = AIController()
