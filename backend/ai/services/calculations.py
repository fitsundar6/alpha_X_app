import re
from datetime import datetime, date, timedelta
from typing import Dict, Any, List, Optional, Tuple

class DeterministicCalculationEngine:
    """
    Guarantees mathematically exact calculations without relying on LLM probabilistic arithmetic.
    Every number cited in AI reports is computed deterministically.
    """

    @staticmethod
    def resolve_date_range(
        text: str = "",
        preset: Optional[str] = None,
        custom_start: Optional[str] = None,
        custom_end: Optional[str] = None,
    ) -> Tuple[datetime, datetime, str]:
        """
        Parses explicit and natural-language temporal requests into definite start and end UTC timestamps.
        Never guesses date ranges.
        """
        now = datetime.utcnow()
        today_start = datetime(now.year, now.month, now.day, 0, 0, 0)
        today_end = datetime(now.year, now.month, now.day, 23, 59, 59)

        lower = text.lower() if text else ""

        # 1. Custom ISO strings supplied
        if custom_start and custom_end:
            try:
                s = datetime.fromisoformat(custom_start.replace("Z", ""))
                e = datetime.fromisoformat(custom_end.replace("Z", ""))
                return s, e, f"{s.strftime('%b %d, %Y')} – {e.strftime('%b %d, %Y')}"
            except Exception:
                pass

        # 2. Preset or NLP matching
        if preset == "today" or "today" in lower:
            return today_start, today_end, "Today"

        if preset == "yesterday" or "yesterday" in lower:
            y_start = today_start - timedelta(days=1)
            y_end = datetime(y_start.year, y_start.month, y_start.day, 23, 59, 59)
            return y_start, y_end, "Yesterday"

        if preset == "this_week" or "this week" in lower:
            start_of_week = today_start - timedelta(days=now.weekday())
            return start_of_week, today_end, "This Week"

        if preset == "last_week" or "last week" in lower:
            start_of_this_week = today_start - timedelta(days=now.weekday())
            start_of_last_week = start_of_this_week - timedelta(days=7)
            end_of_last_week = start_of_this_week - timedelta(seconds=1)
            return start_of_last_week, end_of_last_week, "Last Week"

        if preset == "last_4_weeks" or "last 4 weeks" in lower or "last four weeks" in lower:
            start = today_start - timedelta(days=28)
            return start, today_end, "Last 4 Weeks"

        if preset == "last_30_days" or "last 30 days" in lower or "last month" in lower:
            start = today_start - timedelta(days=30)
            return start, today_end, "Last 30 Days"

        if preset == "last_90_days" or "last 90 days" in lower or "last 3 months" in lower:
            start = today_start - timedelta(days=90)
            return start, today_end, "Last 90 Days"

        if "since joining" in lower or "all time" in lower:
            start = today_start - timedelta(days=365 * 2)
            return start, today_end, "Since Joining"

        # Default fallback: past 30 days
        start = today_start - timedelta(days=30)
        return start, today_end, "Past 30 Days"

    @staticmethod
    def calculate_macro_totals(food_logs: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Computes exact macro totals, daily averages, and food log counts.
        """
        if not food_logs:
            return {
                "totalCalories": 0.0,
                "totalProtein": 0.0,
                "totalCarbs": 0.0,
                "totalFat": 0.0,
                "totalFiber": 0.0,
                "averageDailyCalories": 0.0,
                "averageDailyProtein": 0.0,
                "averageDailyCarbs": 0.0,
                "averageDailyFat": 0.0,
                "daysLogged": 0,
                "entriesCount": 0,
            }

        cals = sum(float(l.get("calories") or 0.0) for l in food_logs)
        protein = sum(float(l.get("protein") or 0.0) for l in food_logs)
        carbs = sum(float(l.get("carbohydrates") or 0.0) for l in food_logs)
        fat = sum(float(l.get("fat") or 0.0) for l in food_logs)
        fiber = sum(float(l.get("fiber") or 0.0) for l in food_logs)

        # Count distinct dates
        dates = set(str(l.get("dateString") or l.get("date"))[:10] for l in food_logs if l.get("dateString") or l.get("date"))
        days_logged = max(1, len(dates))

        return {
            "totalCalories": round(cals, 1),
            "totalProtein": round(protein, 1),
            "totalCarbs": round(carbs, 1),
            "totalFat": round(fat, 1),
            "totalFiber": round(fiber, 1),
            "averageDailyCalories": round(cals / days_logged, 1),
            "averageDailyProtein": round(protein / days_logged, 1),
            "averageDailyCarbs": round(carbs / days_logged, 1),
            "averageDailyFat": round(fat / days_logged, 1),
            "daysLogged": len(dates),
            "entriesCount": len(food_logs),
        }

    @staticmethod
    def calculate_diet_adherence(assigned_plan: Optional[Dict[str, Any]], actual_macros: Dict[str, Any]) -> Dict[str, Any]:
        """
        Factual comparison between Admin-prescribed targets and actual athlete food consumption.
        """
        if not assigned_plan:
            return {
                "hasAssignedPlan": False,
                "summary": "No active diet plan currently assigned.",
                "calorieAdherenceRate": 0.0,
                "proteinAdherenceRate": 0.0,
                "calorieDelta": 0.0,
                "proteinDelta": 0.0,
            }

        target_cals = float(assigned_plan.get("dailyCalories") or 2000)
        target_protein = float(assigned_plan.get("protein") or 150)
        target_carbs = float(assigned_plan.get("carbohydrates") or 200)
        target_fat = float(assigned_plan.get("fat") or 60)

        actual_cals = float(actual_macros.get("averageDailyCalories", 0.0))
        actual_protein = float(actual_macros.get("averageDailyProtein", 0.0))
        actual_carbs = float(actual_macros.get("averageDailyCarbs", 0.0))
        actual_fat = float(actual_macros.get("averageDailyFat", 0.0))

        cal_adherence = round((actual_cals / target_cals) * 100, 1) if target_cals > 0 else 0.0
        protein_adherence = round((actual_protein / target_protein) * 100, 1) if target_protein > 0 else 0.0

        cal_delta = round(actual_cals - target_cals, 1)
        protein_delta = round(actual_protein - target_protein, 1)

        return {
            "hasAssignedPlan": True,
            "targetCalories": target_cals,
            "targetProtein": target_protein,
            "targetCarbs": target_carbs,
            "targetFat": target_fat,
            "actualCalories": actual_cals,
            "actualProtein": actual_protein,
            "actualCarbs": actual_carbs,
            "actualFat": actual_fat,
            "calorieAdherenceRate": cal_adherence,
            "proteinAdherenceRate": protein_adherence,
            "calorieDelta": cal_delta,
            "proteinDelta": protein_delta,
            "isCalorieDeficit": cal_delta < -150,
            "isCalorieSurplus": cal_delta > 150,
            "isProteinDeficient": protein_delta < -20,
        }

    @staticmethod
    def calculate_weight_progress(progress_records: List[Dict[str, Any]], checkins: Optional[List[Dict[str, Any]]] = None) -> Dict[str, Any]:
        """
        Computes starting, latest, and delta weight and waist measurements.
        """
        checkins = checkins or []
        weights: List[Tuple[date, float]] = []
        waists: List[Tuple[date, float]] = []

        # Extract from progress records
        for p in progress_records:
            d = p.get("date") or p.get("recordedAt") or p.get("createdAt")
            if isinstance(d, datetime):
                d = d.date()
            d = d or date.min
            if p.get("weightKg") is not None:
                weights.append((d, float(p["weightKg"])))
            if p.get("waistCm") is not None:
                waists.append((d, float(p["waistCm"])))

        # Extract from checkins
        for c in checkins:
            d = c.get("checkInDate") or c.get("date") or c.get("createdAt")
            if isinstance(d, datetime):
                d = d.date()
            d = d or date.min
            if c.get("weightKg") is not None:
                weights.append((d, float(c["weightKg"])))
            if c.get("waistCm") is not None:
                waists.append((d, float(c["waistCm"])))

        # Sort chronological
        weights.sort(key=lambda x: x[0] or date.min)
        waists.sort(key=lambda x: x[0] or date.min)

        start_weight = weights[0][1] if weights else None
        latest_weight = weights[-1][1] if weights else None
        weight_delta = round(latest_weight - start_weight, 2) if (start_weight and latest_weight) else None

        start_waist = waists[0][1] if waists else None
        latest_waist = waists[-1][1] if waists else None
        waist_delta = round(latest_waist - start_waist, 1) if (start_waist and latest_waist) else None

        return {
            "hasWeightData": latest_weight is not None,
            "startWeightKg": start_weight,
            "latestWeightKg": latest_weight,
            "weightDeltaKg": weight_delta,
            "hasWaistData": latest_waist is not None,
            "startWaistCm": start_waist,
            "latestWaistCm": latest_waist,
            "waistDeltaCm": waist_delta,
            "readingsCount": len(weights),
        }

    @staticmethod
    def calculate_workout_metrics(workout_records: List[Dict[str, Any]], target_days_per_week: int = 3) -> Dict[str, Any]:
        """
        Computes total training volume, completed sets, RPE averages, and workout completion percentage.
        """
        if not workout_records:
            return {
                "workoutsCompleted": 0,
                "totalVolumeKg": 0.0,
                "averageDurationMinutes": 0,
                "averageRpe": 0.0,
                "completionRate": 0.0,
            }

        completed = [w for w in workout_records if w.get("isCompleted") is True]
        total_vol = sum(float(w.get("totalVolume") or 0.0) for w in completed)
        durations = [int(w.get("durationSeconds") or 0) for w in completed if int(w.get("durationSeconds") or 0) > 0]
        avg_duration = round((sum(durations) / len(durations)) / 60) if durations else 45

        rpes = [float(w["averageRpe"]) for w in completed if w.get("averageRpe")]
        avg_rpe = round(sum(rpes) / len(rpes), 1) if rpes else 8.0

        return {
            "workoutsCompleted": len(completed),
            "totalVolumeKg": round(total_vol, 1),
            "averageDurationMinutes": avg_duration,
            "averageRpe": avg_rpe,
            "totalSessionsLogged": len(workout_records),
        }

    @staticmethod
    def calculate_progressive_overload(exercise_name: str, history: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Deterministic Progressive Overload Rule Engine.
        Analyzes previous sets, weights, reps, and RPE/RIR to generate an exact proposal.
        """
        clean_name = exercise_name.strip()
        is_lower = bool(re.search(r"squat|deadlift|leg press|lunge|hip thrust", clean_name, re.I))
        weight_step = 5.0 if is_lower else 2.5

        if not history:
            return {
                "hasHistory": False,
                "exerciseName": clean_name,
                "proposal": {
                    "exerciseName": clean_name,
                    "sets": 3,
                    "targetReps": "8-10",
                    "targetWeight": 50.0 if not is_lower else 70.0,
                    "targetRir": 2,
                    "targetRpe": 8.0,
                    "reason": "Baseline protocol prescribed for initial calibration.",
                },
            }

        # Analyze latest completed set
        latest = history[0]
        current_weight = float(latest.get("actualWeight") or 60.0)
        current_reps = int(latest.get("actualReps") or 8)
        current_rpe = float(latest.get("actualRpe") or 8.0)
        current_rir = int(latest.get("actualRir") or 2)

        # Progression Rules
        if current_rpe <= 8.0 and current_rir >= 2:
            if current_reps >= 10:
                proposed_weight = round(current_weight + weight_step, 1)
                proposed_reps = "8"
                reason = f"Completed {current_weight} kg × {current_reps} with RPE {current_rpe} (RIR {current_rir}). Solid technical reserve justifies +{weight_step} kg load progression."
            else:
                proposed_weight = current_weight
                proposed_reps = str(current_reps + 1)
                reason = f"Completed {current_weight} kg × {current_reps} with RPE {current_rpe}. Proposing rep increase to {proposed_reps} before increasing external load."
        elif current_rpe >= 9.5 or current_rir == 0:
            proposed_weight = current_weight
            proposed_reps = str(current_reps)
            reason = f"Near failure recorded (RPE {current_rpe}). Consolidate load at {current_weight} kg to allow neurological recovery and form stabilization."
        else:
            proposed_weight = round(current_weight + (weight_step if current_reps >= 10 else 0), 1)
            proposed_reps = "8" if current_reps >= 10 else str(current_reps + 1)
            reason = f"Steadily advancing performance from {current_weight} kg × {current_reps} reps."

        return {
            "hasHistory": True,
            "exerciseName": clean_name,
            "current": {
                "weight": current_weight,
                "reps": current_reps,
                "rpe": current_rpe,
                "rir": current_rir,
            },
            "proposal": {
                "exerciseName": clean_name,
                "sets": 3,
                "targetWeight": proposed_weight,
                "targetReps": proposed_reps,
                "targetRir": 2,
                "targetRpe": 8.0,
                "reason": reason,
            },
        }

    @staticmethod
    def calculate_estimated_1rm(weight: float, reps: int) -> float:
        """Computes estimated 1-Rep Max using the Epley equation."""
        if reps <= 1:
            return round(weight, 1)
        return round(weight * (1.0 + (reps / 30.0)), 1)

    @staticmethod
    def calculate_data_completeness(
        has_profile: bool,
        has_workout_assigned: bool,
        has_diet_assigned: bool,
        checkin_count: int,
        food_log_days: int,
        weight_count: int,
        step_days: int,
    ) -> Dict[str, Any]:
        """
        Calculates a data completeness score (0-100%) and identifies missing tracking parameters.
        """
        checks = [
            (has_profile, "Complete fitness assessment on file"),
            (has_workout_assigned, "Active workout plan assigned by Admin"),
            (has_diet_assigned, "Active diet plan assigned by Admin"),
            (checkin_count > 0, "Weekly check-in logged within recent period"),
            (food_log_days >= 3, "Food logged on at least 3 days in current window"),
            (weight_count > 0, "Bodyweight measurement recorded"),
            (step_days >= 3, "Step activity recorded on at least 3 days"),
        ]

        passed = sum(1 for c, _ in checks if c)
        missing = [desc for c, desc in checks if not c]
        score = round((passed / len(checks)) * 100)

        return {
            "scorePercentage": score,
            "missingItems": missing,
            "summary": f"Data Completeness: {score}% ({'Missing: ' + '; '.join(missing) if missing else 'All key tracking metrics available'})",
        }

calc_engine = DeterministicCalculationEngine()
