import logging
from typing import Dict, Any, List, Optional
from backend.ai.tools.alpha_x_tools import alpha_x_tools
from backend.ai.services.calculations import calc_engine
from backend.ai.rag.retriever import rag_retriever

logger = logging.getLogger("alpha_x_ai.workout")

class WorkoutIntelligenceAgent:
    """
    Specialized Workout Intelligence capability within the Alpha X Master AI Coach.
    Analyzes historical performance, volume, and formulates evidence-based progressive overload.
    """

    def analyze_workout_history(
        self, user_id: str, client_name: str, start_date=None, end_date=None
    ) -> Dict[str, Any]:
        """Analyzes client training trajectory over a specified window."""
        records = alpha_x_tools.get_workout_history(user_id, start_date=start_date, end_date=end_date)
        metrics = calc_engine.calculate_workout_metrics(records)

        # Retrieve RAG context on progressive overload
        rag_context = rag_retriever.search_knowledge("progressive overload volume intensity", category="TRAINING", top_k=2)

        summary_points = []
        if metrics["workoutsCompleted"] == 0:
            summary_points.append(f"No completed workout sessions recorded for {client_name} in this period.")
        else:
            summary_points.append(f"{client_name} completed {metrics['workoutsCompleted']} workout sessions.")
            summary_points.append(f"Total training volume: {metrics['totalVolumeKg']:,} kg with an average session RPE of {metrics['averageRpe']}.")
            summary_points.append(f"Average workout duration: {metrics['averageDurationMinutes']} minutes.")

        return {
            "metrics": metrics,
            "recordsCount": len(records),
            "summaryPoints": summary_points,
            "ragInsights": [r["title"] for r in rag_context],
        }

    def generate_progressive_overload_proposal(
        self, client: Dict[str, Any], exercise_name: str, conversation_id: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Formulates a progressive overload proposal for an athlete on a specific lift.
        Uses deterministic performance calculations and saves pending proposal in database.
        """
        user_id = client["userId"]
        client_name = client["name"]
        client_profile_id = client["clientProfileId"]
        client_id = client.get("clientId")

        history = alpha_x_tools.get_exercise_history(user_id, exercise_name)
        progression = calc_engine.calculate_progressive_overload(exercise_name, history)

        proposal_data = progression["proposal"]
        title = f"{client_name} — {exercise_name} Progression"
        summary = f"{proposal_data['exerciseName']}: {proposal_data['targetWeight']} kg × {proposal_data['targetReps']} reps (RPE {proposal_data['targetRpe']}, RIR {proposal_data['targetRir']})"
        reason = proposal_data["reason"]

        db_proposal = alpha_x_tools.create_proposal(
            client_profile_id=client_profile_id,
            client_id=client_id,
            client_name=client_name,
            proposal_type="PROGRESSION",
            title=title,
            summary=summary,
            reason=reason,
            proposed_data=proposal_data,
            current_data=progression.get("current"),
            conversation_id=conversation_id,
        )

        return {
            "analysis": progression,
            "proposal": {
                "id": str(db_proposal["id"]),
                "proposalType": "PROGRESSION",
                "status": "PENDING",
                "title": title,
                "summary": summary,
                "reason": reason,
                "currentData": progression.get("current"),
                "proposedData": proposal_data,
            },
        }

    def generate_workout_session_proposal(
        self, client: Dict[str, Any], goal: Optional[str] = None, conversation_id: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Engineers a tailored workout session based on client goals and fitness assessment.
        Saves proposal as PENDING for Admin Coach approval.
        """
        client_name = client["name"]
        client_profile_id = client["clientProfileId"]
        client_id = client.get("clientId")
        primary_goal = goal or client.get("primaryGoal") or "Hypertrophy"
        fitness_level = client.get("fitnessLevel") or "Intermediate"
        injuries = client.get("injuryAreas") or []

        # Pull exercises from library
        exercises = alpha_x_tools.query_exercise_library(limit=40)
        selected_exercises = []

        # Select compound push, pull, legs based on goals
        def find_ex(name_part: str) -> Optional[Dict[str, Any]]:
            for ex in exercises:
                if name_part.lower() in ex["name"].lower():
                    # Check injury contraindications
                    if any(inj.lower() in ex.get("primaryMuscles", []) for inj in injuries):
                        continue
                    return ex
            return None

        candidates = ["Bench Press", "Squat", "Row", "Overhead Press", "Deadlift"]
        for c in candidates:
            match = find_ex(c)
            if match and len(selected_exercises) < 4:
                selected_exercises.append({
                    "exerciseId": str(match["id"]),
                    "exerciseName": match["name"],
                    "category": match.get("category", "Strength"),
                    "sets": 3 if fitness_level == "Beginner" else 4,
                    "targetReps": "8-10" if "Hypertrophy" in primary_goal else "5-8",
                    "targetWeight": 60.0 if "Squat" in match["name"] or "Deadlift" in match["name"] else 40.0,
                    "targetRir": 2,
                    "targetRpe": 8.0,
                    "restSeconds": 90,
                    "notes": f"Execute with strict control. Focus on {match.get('movementPattern', 'Compound')} mechanics.",
                })

        if not selected_exercises:
            selected_exercises = [
                {"exerciseName": "Barbell Bench Press", "sets": 3, "targetReps": "8-10", "targetWeight": 60.0, "restSeconds": 90, "targetRir": 2, "targetRpe": 8.0},
                {"exerciseName": "Barbell Back Squat", "sets": 3, "targetReps": "8-10", "targetWeight": 80.0, "restSeconds": 120, "targetRir": 2, "targetRpe": 8.0},
                {"exerciseName": "Seated Cable Row", "sets": 3, "targetReps": "10-12", "targetWeight": 50.0, "restSeconds": 90, "targetRir": 2, "targetRpe": 8.0},
            ]

        session_payload = {
            "title": f"{client_name} — {primary_goal} Session",
            "workoutType": primary_goal if primary_goal in ["Strength", "Hypertrophy", "Conditioning"] else "Hypertrophy",
            "targetMuscleGroup": "Full Body",
            "difficulty": fitness_level,
            "estimatedDurationMinutes": 50,
            "description": f"Custom designed for {client_name} aligning with primary goal of {primary_goal}.",
            "exercises": selected_exercises,
        }

        title = f"{client_name} — {primary_goal} Session"
        summary = f"{len(selected_exercises)}-exercise compound protocol ({session_payload['estimatedDurationMinutes']} min) tailored for {primary_goal}."
        reason = f"Engineered against fitness tier ({fitness_level}) and training goal ({primary_goal}) respecting injury safety screening."

        db_proposal = alpha_x_tools.create_proposal(
            client_profile_id=client_profile_id,
            client_id=client_id,
            client_name=client_name,
            proposal_type="WORKOUT",
            title=title,
            summary=summary,
            reason=reason,
            proposed_data=session_payload,
            conversation_id=conversation_id,
        )

        return {
            "id": str(db_proposal["id"]),
            "proposalType": "WORKOUT",
            "status": "PENDING",
            "title": title,
            "summary": summary,
            "reason": reason,
            "proposedData": session_payload,
        }

workout_agent = WorkoutIntelligenceAgent()
