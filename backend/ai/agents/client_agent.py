import logging
from datetime import datetime, date, timedelta
from typing import Dict, Any, List, Optional
from backend.ai.tools.alpha_x_tools import alpha_x_tools
from backend.ai.services.calculations import calc_engine
from backend.ai.rag.retriever import rag_retriever

logger = logging.getLogger("alpha_x_ai.client")

class ClientIntelligenceAgent:
    """
    Specialized Client Intelligence capability and Client Attention Engine.
    Aggregates the unified 360-degree client timeline and flags athletes requiring coach attention.
    """

    def analyze_client_holistic(
        self, client: Dict[str, Any], start_date: Optional[datetime] = None, end_date: Optional[datetime] = None
    ) -> Dict[str, Any]:
        """
        Synthesizes biometric trends, workout compliance, nutrition logs, and check-ins into an integrated report.
        Strictly distinguishes FACTS from POSSIBLE EXPLANATIONS and MISSING DATA.
        """
        user_id = client["userId"]
        client_profile_id = client["clientProfileId"]
        client_name = client["name"]

        # Gather data layers
        workouts = alpha_x_tools.get_workout_history(user_id, start_date=start_date, end_date=end_date)
        assigned_diet = alpha_x_tools.get_assigned_diet(client_profile_id)
        food_logs = alpha_x_tools.get_actual_food_log(
            client_profile_id,
            start_date=start_date.date() if start_date else None,
            end_date=end_date.date() if end_date else None,
        )
        progress = alpha_x_tools.get_weight_history(client_profile_id)
        checkins = alpha_x_tools.get_weekly_checkins(client_profile_id)
        steps = alpha_x_tools.get_steps_history(client_profile_id)
        alerts = alpha_x_tools.get_client_alerts(client_profile_id)

        # Computations
        workout_metrics = calc_engine.calculate_workout_metrics(workouts)
        macro_totals = calc_engine.calculate_macro_totals(food_logs)
        diet_adherence = calc_engine.calculate_diet_adherence(assigned_diet, macro_totals)
        weight_progress = calc_engine.calculate_weight_progress(progress, checkins)

        # Completeness calculation
        completeness = calc_engine.calculate_data_completeness(
            has_profile=bool(client.get("fitnessLevel")),
            has_workout_assigned=bool(client.get("trainingDaysPerWeek")),
            has_diet_assigned=bool(assigned_diet),
            checkin_count=len(checkins),
            food_log_days=macro_totals["daysLogged"],
            weight_count=weight_progress["readingsCount"],
            step_days=len(steps),
        )

        # Build Sectioned Narrative
        facts = []
        possible_explanations = []
        missing_data = list(completeness["missingItems"])

        # Facts
        if weight_progress["hasWeightData"]:
            w_str = f"Bodyweight changed from {weight_progress['startWeightKg']} kg to {weight_progress['latestWeightKg']} kg"
            if weight_progress["weightDeltaKg"] is not None:
                w_str += f" (Net delta: {weight_progress['weightDeltaKg']:+} kg)."
            facts.append(w_str)
        else:
            missing_data.append("No scale weight recorded in progress history.")

        if weight_progress["hasWaistData"]:
            facts.append(f"Waist measurement: {weight_progress['startWaistCm']} cm → {weight_progress['latestWaistCm']} cm (Delta: {weight_progress['waistDeltaCm']:+} cm).")

        facts.append(f"Completed {workout_metrics['workoutsCompleted']} workouts with {workout_metrics['totalVolumeKg']:,} kg total volume.")

        if macro_totals["entriesCount"] > 0:
            facts.append(f"Logged {macro_totals['entriesCount']} meals across {macro_totals['daysLogged']} days. Avg: {macro_totals['averageDailyCalories']} kcal, {macro_totals['averageDailyProtein']}g Protein.")
        else:
            missing_data.append("Food logging inactive in this timeframe.")

        # Check-in pain / recovery facts
        if checkins:
            latest_ci = checkins[0]
            if latest_ci.get("hasPain"):
                facts.append(f"Discomfort reported in Week {latest_ci.get('weekNumber')}: {latest_ci.get('painLocation')} during {latest_ci.get('painExercise')} (Severity {latest_ci.get('painLevel')}/10).")
            facts.append(f"Latest Check-In Sleep: {latest_ci.get('sleepHours')} hrs/night (Quality: {latest_ci.get('sleepQuality')}, Recovery: {latest_ci.get('recoveryQuality')}).")

        # Explanations / Insights
        if weight_progress.get("weightDeltaKg") == 0 and macro_totals["entriesCount"] > 0:
            if diet_adherence.get("isCalorieDeficit"):
                possible_explanations.append("Weight is stable despite logged calorie deficit; possible explanations include initial water retention from high training volume, or food logging under-reporting.")
            else:
                possible_explanations.append("Caloric intake appears near maintenance level, explaining weight stabilization.")

        if diet_adherence.get("isProteinDeficient"):
            possible_explanations.append(f"Actual protein intake ({macro_totals['averageDailyProtein']}g) is trailing the assigned target ({diet_adherence['targetProtein']}g), potentially impacting muscle recovery.")

        return {
            "client": client,
            "facts": facts,
            "possibleExplanations": possible_explanations,
            "missingData": missing_data,
            "completeness": completeness,
            "workoutMetrics": workout_metrics,
            "macroTotals": macro_totals,
            "dietAdherence": diet_adherence,
            "weightProgress": weight_progress,
            "alerts": alerts,
        }

    def evaluate_attention_signals(self, client: Dict[str, Any]) -> List[Dict[str, Any]]:
        """
        Evaluates multi-signal attention triggers for an athlete:
        - Inactive / Missed workouts
        - Missing weekly check-in (> 10 days)
        - Low protein adherence
        - High discomfort / pain reports
        - Stalled progress
        """
        user_id = client["userId"]
        cp_id = client["clientProfileId"]
        name = client["name"]
        client_id = client.get("clientId")

        signals: List[Dict[str, Any]] = []

        # 1. Check recent check-ins
        checkins = alpha_x_tools.get_weekly_checkins(cp_id, limit=2)
        if not checkins:
            signals.append({
                "attentionType": "MISSING_CHECKIN",
                "severity": "HIGH",
                "title": "Initial Check-In Missing",
                "details": f"{name} has no weekly check-in records on file.",
            })
        else:
            latest_ci = checkins[0]
            ci_date = latest_ci.get("checkInDate")
            if isinstance(ci_date, datetime) and (datetime.utcnow() - ci_date) > timedelta(days=10):
                signals.append({
                    "attentionType": "MISSING_CHECKIN",
                    "severity": "HIGH",
                    "title": "Weekly Check-In Overdue",
                    "details": f"{name}'s last check-in was {ci_date.strftime('%b %d')} (>10 days ago).",
                })
            if latest_ci.get("hasPain") and (latest_ci.get("painLevel") or 0) >= 6:
                signals.append({
                    "attentionType": "PAIN_REPORTED",
                    "severity": "CRITICAL",
                    "title": f"High Pain Reported: {latest_ci.get('painLocation')}",
                    "details": f"Rated {latest_ci.get('painLevel')}/10 during {latest_ci.get('painExercise')}. Coach review strongly advised.",
                })

        # 2. Check recent workouts
        workouts = alpha_x_tools.get_workout_history(user_id, limit=5)
        completed_recent = [w for w in workouts if w.get("isCompleted")]
        if not completed_recent:
            signals.append({
                "attentionType": "MISSED_WORKOUT",
                "severity": "MEDIUM",
                "title": "No Completed Workouts Recorded",
                "details": f"{name} has not completed any training sessions recently.",
            })

        # 3. Check food logs & protein
        food_logs = alpha_x_tools.get_actual_food_log(cp_id, limit=30)
        if not food_logs:
            signals.append({
                "attentionType": "MISSING_FOOD",
                "severity": "LOW",
                "title": "Food Tracking Inactive",
                "details": f"No food entries recorded by {name}.",
            })
        else:
            assigned_diet = alpha_x_tools.get_assigned_diet(cp_id)
            if assigned_diet:
                macros = calc_engine.calculate_macro_totals(food_logs)
                adh = calc_engine.calculate_diet_adherence(assigned_diet, macros)
                if adh["isProteinDeficient"]:
                    signals.append({
                        "attentionType": "LOW_PROTEIN",
                        "severity": "MEDIUM",
                        "title": "Protein Adherence Deficit",
                        "details": f"Averaging {macros['averageDailyProtein']}g protein vs {adh['targetProtein']}g target.",
                    })

        return signals

client_agent = ClientIntelligenceAgent()
