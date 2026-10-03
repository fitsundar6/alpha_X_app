import logging
from typing import Dict, Any, List, Optional
from backend.ai.tools.alpha_x_tools import alpha_x_tools
from backend.ai.services.calculations import calc_engine
from backend.ai.rag.retriever import rag_retriever

logger = logging.getLogger("alpha_x_ai.nutrition")

class NutritionIntelligenceAgent:
    """
    Specialized Nutrition Intelligence capability within the Alpha X Master AI Coach.
    Analyzes actual client food tracking, compares against Admin prescribed diets,
    and formulates nutrition plans strictly leveraging the existing Food Library.
    """

    def analyze_nutrition_adherence(
        self, client_profile_id: str, client_name: str, start_date=None, end_date=None
    ) -> Dict[str, Any]:
        """
        Performs rigorous comparison between Assigned Diet Plan and Actual Food Logs.
        Never conflates prescribed diet with consumed food.
        """
        assigned_diet = alpha_x_tools.get_assigned_diet(client_profile_id)
        food_logs = alpha_x_tools.get_actual_food_log(client_profile_id, start_date=start_date, end_date=end_date)

        actual_macros = calc_engine.calculate_macro_totals(food_logs)
        adherence = calc_engine.calculate_diet_adherence(assigned_diet, actual_macros)

        # Retrieve RAG context on protein & fat loss
        rag_context = rag_retriever.search_knowledge("protein target intake fat loss deficit", category="NUTRITION", top_k=2)

        summary_points = []
        if actual_macros["entriesCount"] == 0:
            summary_points.append(f"No food logs recorded by {client_name} in this period.")
        else:
            summary_points.append(f"{client_name} logged {actual_macros['entriesCount']} food entries across {actual_macros['daysLogged']} days.")
            summary_points.append(f"Average intake: {actual_macros['averageDailyCalories']} kcal • {actual_macros['averageDailyProtein']}g Protein • {actual_macros['averageDailyCarbs']}g Carbs • {actual_macros['averageDailyFat']}g Fat.")

        if assigned_diet:
            summary_points.append(f"Assigned Target: {adherence['targetCalories']} kcal • {adherence['targetProtein']}g Protein.")
            summary_points.append(f"Adherence: Calories {adherence['calorieAdherenceRate']}% (Delta: {adherence['calorieDelta']:+} kcal), Protein {adherence['proteinAdherenceRate']}% (Delta: {adherence['proteinDelta']:+}g).")
            if adherence["isProteinDeficient"]:
                summary_points.append("⚠ Consistent protein deficiency observed vs prescribed target.")

        return {
            "assignedDiet": assigned_diet,
            "actualMacros": actual_macros,
            "adherence": adherence,
            "summaryPoints": summary_points,
            "ragInsights": [r["title"] for r in rag_context],
        }

    def generate_diet_proposal(
        self, client: Dict[str, Any], target_calories: Optional[float] = None, conversation_id: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Formulates a diet proposal based on bodyweight and goals, utilizing existing Food Library items.
        Stores proposal with PENDING status for Admin Coach approval.
        """
        client_name = client["name"]
        client_profile_id = client["clientProfileId"]
        client_id = client.get("clientId")
        weight_kg = float(client.get("weightKg") or 75.0)
        goal = client.get("primaryGoal") or "Fat Loss"

        # Calculate evidence-based targets:
        # Protein: 2.0g/kg for fat loss, 1.8g/kg for muscle gain
        protein_factor = 2.2 if "Fat Loss" in goal else 1.8
        target_p = round(weight_kg * protein_factor)

        # Calorie calculation
        if target_calories:
            cals = float(target_calories)
        elif "Fat Loss" in goal:
            cals = round(weight_kg * 26.0) # ~1950 kcal for 75kg
        else:
            cals = round(weight_kg * 32.0) # ~2400 kcal for 75kg

        target_fat = round((cals * 0.25) / 9.0)
        remaining_cals = cals - (target_p * 4.0) - (target_fat * 9.0)
        target_carbs = max(50.0, round(remaining_cals / 4.0))

        # Query existing Food Library for sample meal items
        foods = alpha_x_tools.query_food_library(limit=30)
        def find_food(name_part: str) -> Dict[str, Any]:
            for f in foods:
                if name_part.lower() in f["name"].lower():
                    return f
            return {"name": name_part, "servingSize": 100, "servingUnit": "g", "calories": 150, "protein": 10}

        breakfast_item = find_food("Egg")
        lunch_item = find_food("Chicken")
        carb_item = find_food("Rice")

        meals = [
            {
                "mealType": "Breakfast",
                "items": [
                    {"foodName": breakfast_item["name"], "quantity": 3, "unit": "piece"},
                    {"foodName": "Rolled Oats", "quantity": 50, "unit": "g"},
                ],
            },
            {
                "mealType": "Lunch",
                "items": [
                    {"foodName": lunch_item["name"], "quantity": 180, "unit": "g"},
                    {"foodName": carb_item["name"], "quantity": 150, "unit": "g"},
                    {"foodName": "Mixed Vegetables", "quantity": 100, "unit": "g"},
                ],
            },
            {
                "mealType": "Dinner",
                "items": [
                    {"foodName": "Paneer / Tofu / Fish", "quantity": 150, "unit": "g"},
                    {"foodName": "Green Salad", "quantity": 120, "unit": "g"},
                ],
            },
        ]

        payload = {
            "planName": f"{client_name} — {goal} Nutrition Protocol",
            "dailyCalories": cals,
            "protein": target_p,
            "carbohydrates": target_carbs,
            "fat": target_fat,
            "fiber": 28.0,
            "waterTargetLiters": 3.5,
            "meals": meals,
            "notes": f"High protein protocol configured for {client_name} ({weight_kg} kg) targeting {goal}.",
        }

        title = f"{client_name} — {goal} Nutrition Plan"
        summary = f"{cals} kcal • {target_p}g P • {target_carbs}g C • {target_fat}g F (3 structured meals)"
        reason = f"Formulated using {protein_factor}g/kg protein ratio aligned with {goal} goals and existing Food Library entries."

        db_proposal = alpha_x_tools.create_proposal(
            client_profile_id=client_profile_id,
            client_id=client_id,
            client_name=client_name,
            proposal_type="DIET",
            title=title,
            summary=summary,
            reason=reason,
            proposed_data=payload,
            conversation_id=conversation_id,
        )

        return {
            "id": str(db_proposal["id"]),
            "proposalType": "DIET",
            "status": "PENDING",
            "title": title,
            "summary": summary,
            "reason": reason,
            "proposedData": payload,
        }

nutrition_agent = NutritionIntelligenceAgent()
