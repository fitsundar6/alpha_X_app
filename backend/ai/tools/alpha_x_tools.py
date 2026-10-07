import json
import logging
from datetime import datetime, date, timedelta
from typing import Dict, Any, List, Optional
from backend.ai.database.connection import get_db_cursor
from backend.ai.safety.auth import sanitize_sensitive_data

logger = logging.getLogger("alpha_x_ai.tools")

class AlphaXTools:
    """
    Controlled, secure tools accessing the existing Alpha X PostgreSQL database.
    Enforces parameterized queries (preventing SQL injection) and sanitizes sensitive data.
    """

    # ==========================================
    # CLIENT DISCOVERY & PROFILE TOOLS
    # ==========================================

    def find_client(self, identifier: str) -> Optional[Dict[str, Any]]:
        """
        Resolves client by AXG-XXXX Client ID, User UUID, ClientProfile UUID, email, or name.
        """
        clean = identifier.strip()
        if not clean:
            return None

        query = """
        SELECT 
            u.id as "userId", u.name, u.email, u."photoUrl", u."createdAt" as "userCreatedAt",
            cp.id as "clientProfileId", cp."clientId", cp."primaryGoal", cp."secondaryGoal",
            cp."fitnessLevel", cp."weightKg", cp."heightCm", cp.age, cp.gender,
            cp."trainingExperience", cp."trainingDaysPerWeek", cp."hasCurrentInjury",
            cp."injuryAreas", cp."injuryDescription", cp."activityLevel", cp."sleepHours",
            cp."dailySteps", cp."dailyStepGoal", cp."trainingTimePref", cp."preferredDays",
            cp."trainingPreferences", cp."onboardingCompleted", cp."membershipPlan",
            cp."membershipStatus", cp."adminNotes", cp."lastAppOpenAt"
        FROM users u
        LEFT JOIN client_profiles cp ON u.id = cp."userId"
        WHERE u.role = 'CLIENT'
          AND (
            u.id = %(id)s
            OR cp.id = %(id)s
            OR UPPER(cp."clientId") = UPPER(%(clean)s)
            OR LOWER(u.email) = LOWER(%(clean)s)
            OR u.name ILIKE %(like_name)s
          )
        ORDER BY 
            CASE WHEN UPPER(cp."clientId") = UPPER(%(clean)s) THEN 1
                 WHEN u.id = %(id)s THEN 2
                 WHEN LOWER(u.email) = LOWER(%(clean)s) THEN 3
                 ELSE 4 END
        LIMIT 1;
        """
        with get_db_cursor() as cur:
            cur.execute(query, {
                "id": clean,
                "clean": clean,
                "like_name": f"%{clean}%"
            })
            row = cur.fetchone()
            return sanitize_sensitive_data(row) if row else None

    def get_client_profile(self, client_id_or_profile_id: str) -> Optional[Dict[str, Any]]:
        """Retrieves athlete profile and onboarding demographics."""
        return self.find_client(client_id_or_profile_id)

    def get_client_assessment(self, client_id_or_profile_id: str) -> Optional[Dict[str, Any]]:
        """Retrieves 10-step assessment parameters (injuries, training days, preferences)."""
        client = self.find_client(client_id_or_profile_id)
        if not client:
            return None
        return {
            "clientId": client.get("clientId"),
            "name": client.get("name"),
            "fitnessLevel": client.get("fitnessLevel"),
            "primaryGoal": client.get("primaryGoal"),
            "secondaryGoal": client.get("secondaryGoal"),
            "trainingExperience": client.get("trainingExperience"),
            "trainingDaysPerWeek": client.get("trainingDaysPerWeek"),
            "hasCurrentInjury": client.get("hasCurrentInjury"),
            "injuryAreas": client.get("injuryAreas") or [],
            "injuryDescription": client.get("injuryDescription"),
            "sleepHours": client.get("sleepHours"),
            "preferredDays": client.get("preferredDays") or [],
            "trainingPreferences": client.get("trainingPreferences") or [],
            "onboardingCompleted": client.get("onboardingCompleted"),
        }

    def get_multiple_clients(self, limit: int = 100) -> List[Dict[str, Any]]:
        """Retrieves active authorized gym athletes."""
        query = """
        SELECT 
            u.id as "userId", u.name, u.email,
            cp.id as "clientProfileId", cp."clientId", cp."primaryGoal",
            cp."fitnessLevel", cp."weightKg", cp."heightCm", cp."membershipStatus",
            cp."adminNotes", cp."lastAppOpenAt"
        FROM users u
        JOIN client_profiles cp ON u.id = cp."userId"
        WHERE u.role = 'CLIENT'
        ORDER BY u.name ASC
        LIMIT %(limit)s;
        """
        with get_db_cursor() as cur:
            cur.execute(query, {"limit": limit})
            rows = cur.fetchall()
            return [sanitize_sensitive_data(r) for r in rows]

    # ==========================================
    # WORKOUT INTELLIGENCE TOOLS
    # ==========================================

    def get_current_workout_plan(self, user_id: str) -> Optional[Dict[str, Any]]:
        """Retrieves active assigned workout session and exercises."""
        query = """
        SELECT 
            wa.id as "assignmentId", wa."assignedAt", wa.active,
            ws.id as "sessionId", ws.title, ws."workoutType", ws."targetMuscleGroup",
            ws.difficulty, ws."estimatedDurationMinutes", ws.description
        FROM workout_assignments wa
        JOIN workout_sessions ws ON wa."sessionId" = ws.id
        WHERE wa."clientId" = %(user_id)s AND wa.active = TRUE
        ORDER BY wa."assignedAt" DESC
        LIMIT 1;
        """
        with get_db_cursor() as cur:
            cur.execute(query, {"user_id": user_id})
            session = cur.fetchone()
            if not session:
                return None

            # Retrieve exercises
            ex_query = """
            SELECT 
                wse.id, wse."exerciseId", wse."exerciseName", wse.category,
                wse."orderIndex", wse."numberOfSets", wse."targetReps",
                wse."targetWeight", wse."restSeconds", wse."targetRir",
                wse."targetRpe", wse.tempo, wse."adminInstruction"
            FROM workout_session_exercises wse
            WHERE wse."sessionId" = %(session_id)s
            ORDER BY wse."orderIndex" ASC;
            """
            cur.execute(ex_query, {"session_id": session["sessionId"]})
            session["exercises"] = cur.fetchall()
            return session

    def get_workout_history(
        self, user_id: str, start_date: Optional[datetime] = None, end_date: Optional[datetime] = None, limit: int = 30
    ) -> List[Dict[str, Any]]:
        """Retrieves completed workout records including exercise and set performance."""
        query = """
        SELECT 
            wr.id, wr."sessionTitle", wr."workoutType", wr."startedAt", wr."completedAt",
            wr."durationSeconds", wr."totalVolume", wr."completedSetsCount",
            wr."skippedSetsCount", wr."averageRpe", wr."averageRir", wr."isCompleted",
            wr."personalRecordsJson", wr.notes
        FROM workout_records wr
        WHERE wr."clientId" = %(user_id)s
          AND (%(start)s::timestamp IS NULL OR wr."startedAt" >= %(start)s)
          AND (%(end)s::timestamp IS NULL OR wr."startedAt" <= %(end)s)
        ORDER BY wr."startedAt" DESC
        LIMIT %(limit)s;
        """
        with get_db_cursor() as cur:
            cur.execute(query, {
                "user_id": user_id,
                "start": start_date,
                "end": end_date,
                "limit": limit
            })
            records = cur.fetchall()

            for rec in records:
                ex_query = """
                SELECT 
                    wer.id, wer."exerciseId", wer."exerciseName", wer."orderIndex",
                    wer."isSkipped", wer."skipReason", wer."clientNote", wer."adminNote"
                FROM workout_exercise_records wer
                WHERE wer."recordId" = %(record_id)s
                ORDER BY wer."orderIndex" ASC;
                """
                cur.execute(ex_query, {"record_id": rec["id"]})
                ex_records = cur.fetchall()

                for ex in ex_records:
                    set_query = """
                    SELECT 
                        wsr."setNumber", wsr."setType", wsr."targetReps", wsr."targetWeight",
                        wsr."actualWeight", wsr."actualReps", wsr."actualRir", wsr."actualRpe",
                        wsr."isCompleted"
                    FROM workout_set_records wsr
                    WHERE wsr."exerciseRecordId" = %(ex_record_id)s
                    ORDER BY wsr."setNumber" ASC;
                    """
                    cur.execute(set_query, {"ex_record_id": ex["id"]})
                    ex["sets"] = cur.fetchall()

                rec["exercises"] = ex_records

            return records

    def get_exercise_history(self, user_id: str, exercise_name: str, limit: int = 10) -> List[Dict[str, Any]]:
        """Retrieves history for a specific exercise across all past workout sessions."""
        query = """
        SELECT 
            wr."startedAt", wer."exerciseName",
            wsr."setNumber", wsr."setType", wsr."actualWeight", wsr."actualReps",
            wsr."actualRir", wsr."actualRpe", wsr."isCompleted"
        FROM workout_records wr
        JOIN workout_exercise_records wer ON wr.id = wer."recordId"
        JOIN workout_set_records wsr ON wer.id = wsr."exerciseRecordId"
        WHERE wr."clientId" = %(user_id)s
          AND wer."exerciseName" ILIKE %(ex_name)s
          AND wsr."isCompleted" = TRUE
        ORDER BY wr."startedAt" DESC, wsr."setNumber" ASC
        LIMIT %(limit)s;
        """
        with get_db_cursor() as cur:
            cur.execute(query, {
                "user_id": user_id,
                "ex_name": f"%{exercise_name.strip()}%",
                "limit": limit * 5
            })
            return cur.fetchall()

    def query_exercise_library(self, search_term: Optional[str] = None, body_part: Optional[str] = None, limit: int = 25) -> List[Dict[str, Any]]:
        """Queries approved Alpha X exercise database."""
        conditions = ["\"isActive\" = TRUE"]
        params: Dict[str, Any] = {"limit": limit}

        if search_term and search_term.strip():
            conditions.append("(name ILIKE %(search)s OR %(term)s = ANY(\"primaryMuscles\") OR \"movementPattern\" ILIKE %(search)s)")
            params["search"] = f"%{search_term.strip()}%"
            params["term"] = search_term.strip()

        if body_part and body_part != "ALL":
            conditions.append("\"bodyPart\" ILIKE %(body_part)s")
            params["body_part"] = f"%{body_part.strip()}%"

        where_clause = " AND ".join(conditions)
        query = f"""
        SELECT 
            id, name, "normalizedName", "primaryMuscles", "secondaryMuscles",
            "bodyPart", category, equipment, "movementPattern", difficulty,
            mechanics, "forceType", instructions, "coachingCues", "commonMistakes",
            variations, progressions, regressions, "alternativeExercises"
        FROM exercises
        WHERE {where_clause}
        ORDER BY name ASC
        LIMIT %(limit)s;
        """
        with get_db_cursor() as cur:
            cur.execute(query, params)
            return cur.fetchall()

    # ==========================================
    # NUTRITION & FOOD LIBRARY TOOLS
    # ==========================================

    def get_assigned_diet(self, client_profile_id: str) -> Optional[Dict[str, Any]]:
        """Retrieves active prescribed DietPlan for athlete."""
        query = """
        SELECT 
            id, "clientProfileId", "clientId", "planName", version,
            "assignedByName", "startDate", "endDate", "dailyCalories",
            protein, carbohydrates, fat, fiber, "waterTargetLiters",
            "isActive", "mealsJson", notes, "createdAt", "updatedAt"
        FROM diet_plans
        WHERE "clientProfileId" = %(cp_id)s AND "isActive" = TRUE
        ORDER BY "createdAt" DESC
        LIMIT 1;
        """
        with get_db_cursor() as cur:
            cur.execute(query, {"cp_id": client_profile_id})
            plan = cur.fetchone()
            if plan and plan.get("mealsJson"):
                try:
                    plan["meals"] = json.loads(plan["mealsJson"])
                except Exception:
                    plan["meals"] = []
            return plan

    def get_diet_history(self, client_profile_id: str, limit: int = 10) -> List[Dict[str, Any]]:
        """Retrieves historical versions of diet plans."""
        query = """
        SELECT 
            id, "dietPlanId", version, "planName", "dailyCalories",
            protein, carbohydrates, fat, fiber, "waterTargetLiters",
            "adminName", "changeSummary", notes, "createdAt"
        FROM diet_plan_histories
        WHERE "clientProfileId" = %(cp_id)s
        ORDER BY version DESC
        LIMIT %(limit)s;
        """
        with get_db_cursor() as cur:
            cur.execute(query, {"cp_id": client_profile_id, "limit": limit})
            return cur.fetchall()

    def get_actual_food_log(
        self, client_profile_id: str, start_date: Optional[date] = None, end_date: Optional[date] = None, limit: int = 150
    ) -> List[Dict[str, Any]]:
        """Retrieves actual food intake logged by the athlete."""
        query = """
        SELECT 
            id, "clientId", date, "dateString", "mealType", "foodId",
            "foodName", category, "servingSize", "servingUnit", quantity,
            calories, protein, carbohydrates, fat, fiber, source,
            "photoAvailable", "loggedAt"
        FROM client_food_logs
        WHERE "clientProfileId" = %(cp_id)s
          AND (%(start)s::date IS NULL OR date >= %(start)s)
          AND (%(end)s::date IS NULL OR date <= %(end)s)
        ORDER BY "loggedAt" DESC
        LIMIT %(limit)s;
        """
        with get_db_cursor() as cur:
            cur.execute(query, {
                "cp_id": client_profile_id,
                "start": start_date,
                "end": end_date,
                "limit": limit
            })
            return cur.fetchall()

    def query_food_library(self, search_term: Optional[str] = None, category: Optional[str] = None, limit: int = 25) -> List[Dict[str, Any]]:
        """Queries approved Alpha X food database (calories, macros, serving units)."""
        conditions = ["status = 'PUBLISHED'"]
        params: Dict[str, Any] = {"limit": limit}

        if search_term and search_term.strip():
            conditions.append("(name ILIKE %(search)s OR \"normalizedName\" ILIKE %(search)s)")
            params["search"] = f"%{search_term.strip()}%"

        if category and category != "ALL":
            conditions.append("category ILIKE %(category)s")
            params["category"] = f"%{category.strip()}%"

        where_clause = " AND ".join(conditions)
        query = f"""
        SELECT 
            id, name, category, "servingSize", "servingUnit",
            calories, protein, carbohydrates, fat, fiber, source
        FROM foods
        WHERE {where_clause}
        ORDER BY name ASC
        LIMIT %(limit)s;
        """
        with get_db_cursor() as cur:
            cur.execute(query, params)
            return cur.fetchall()

    # ==========================================
    # BIOMETRICS & CHECK-INS TOOLS
    # ==========================================

    def get_weekly_checkins(self, client_profile_id: str, limit: int = 12) -> List[Dict[str, Any]]:
        """Retrieves weekly check-in records (weight, waist, sleep, energy, pain)."""
        query = """
        SELECT 
            id, "weekNumber", year, "checkInDate", "nextCheckInDate",
            "weightKg", "waistCm", "chestCm", "armsCm", "hipsCm", "thighsCm",
            "weightChange", "waistChange", "nutritionCalories", "nutritionProtein",
            "nutritionWater", "dietAdherence", "sleepQuality", "sleepHours",
            "recoveryQuality", "workoutCompletion", "workoutFeeling", "energyLevel",
            "hasPain", "painLocation", "painExercise", "painLevel", "painDescription",
            "weeklyProblems", "clientNotes", "hasCoachReview", "whatWentWell",
            "needsImprovement", "nextWeekFocus"
        FROM weekly_check_ins
        WHERE "clientProfileId" = %(cp_id)s
        ORDER BY year DESC, "weekNumber" DESC
        LIMIT %(limit)s;
        """
        with get_db_cursor() as cur:
            cur.execute(query, {"cp_id": client_profile_id, "limit": limit})
            return cur.fetchall()

    def get_weight_history(self, client_profile_id: str, limit: int = 30) -> List[Dict[str, Any]]:
        """Retrieves bodyweight measurements timeline."""
        query = """
        SELECT id, date, "weightKg", "waistCm", notes
        FROM client_progress
        WHERE "clientProfileId" = %(cp_id)s
        ORDER BY date DESC
        LIMIT %(limit)s;
        """
        with get_db_cursor() as cur:
            cur.execute(query, {"cp_id": client_profile_id, "limit": limit})
            return cur.fetchall()

    def get_steps_history(self, client_profile_id: str, limit: int = 30) -> List[Dict[str, Any]]:
        """Retrieves daily step counts and cardio activity."""
        query = """
        SELECT date, steps, "stepGoal", "cardioMinutes", "caloriesBurned", "isGoalAchieved"
        FROM activity_records
        WHERE "clientId" = %(cp_id)s
        ORDER BY date DESC
        LIMIT %(limit)s;
        """
        with get_db_cursor() as cur:
            cur.execute(query, {"cp_id": client_profile_id, "limit": limit})
            return cur.fetchall()

    def get_client_alerts(self, client_profile_id: str) -> List[Dict[str, Any]]:
        """Retrieves attention items flagged for the client."""
        query = """
        SELECT id, "attentionType", severity, title, details, "isReviewed", "createdAt"
        FROM admin_attention_items
        WHERE "clientProfileId" = %(cp_id)s
        ORDER BY "createdAt" DESC
        LIMIT 10;
        """
        with get_db_cursor() as cur:
            cur.execute(query, {"cp_id": client_profile_id})
            return cur.fetchall()

    # ==========================================
    # FACILITY REPORTS & MULTI-CLIENT QUERIES
    # ==========================================

    def get_daily_gym_summary(self, target_date_str: Optional[str] = None) -> Dict[str, Any]:
        """Generates facility daily report metrics."""
        today_str = target_date_str or date.today().isoformat()
        with get_db_cursor() as cur:
            cur.execute("SELECT COUNT(*) as count FROM users WHERE role = 'CLIENT';")
            total_clients = cur.fetchone()["count"]

            cur.execute("""
                SELECT COUNT(*) as count FROM workout_records 
                WHERE "isCompleted" = TRUE AND DATE("startedAt") = %(target)s;
            """, {"target": today_str})
            today_workouts = cur.fetchone()["count"]

            cur.execute("""
                SELECT COUNT(*) as count FROM client_food_logs 
                WHERE "dateString" = %(target)s;
            """, {"target": today_str})
            today_food_logs = cur.fetchone()["count"]

            cur.execute("""
                SELECT COUNT(DISTINCT "clientProfileId") as count FROM client_food_logs 
                WHERE "dateString" = %(target)s;
            """, {"target": today_str})
            tracking_clients = cur.fetchone()["count"]

            cur.execute("""
                SELECT id, "clientName", "clientId", "attentionType", severity, title, details
                FROM admin_attention_items
                WHERE "isReviewed" = FALSE
                ORDER BY CASE severity WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2 WHEN 'MEDIUM' THEN 3 ELSE 4 END, "createdAt" DESC
                LIMIT 10;
            """)
            attention_items = cur.fetchall()

            cur.execute("""
                SELECT COUNT(*) as count FROM weekly_check_ins
                WHERE "checkInDate" >= NOW() - INTERVAL '7 days';
            """)
            completed_checkins = cur.fetchone()["count"]

            pending_checkins = max(0, total_clients - completed_checkins)

            return {
                "date": today_str,
                "totalActiveClients": total_clients,
                "workoutsCompletedToday": today_workouts,
                "foodLogsRecordedToday": today_food_logs,
                "clientsTrackingFoodToday": tracking_clients,
                "weeklyCheckInsPending": pending_checkins,
                "clientsNeedingReviewCount": len(attention_items),
                "attentionItems": attention_items,
            }

    def get_clients_needing_attention(self, limit: int = 50) -> List[Dict[str, Any]]:
        """Retrieves all athletes currently flagged with pending review items."""
        query = """
        SELECT 
            aai.id, aai."clientProfileId", aai."clientId", aai."clientName",
            aai."attentionType", aai.severity, aai.title, aai.details,
            aai."createdAt", cp."primaryGoal", cp."membershipStatus"
        FROM admin_attention_items aai
        JOIN client_profiles cp ON aai."clientProfileId" = cp.id
        WHERE aai."isReviewed" = FALSE
        ORDER BY 
            CASE aai.severity WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2 WHEN 'MEDIUM' THEN 3 ELSE 4 END,
            aai."createdAt" DESC
        LIMIT %(limit)s;
        """
        with get_db_cursor() as cur:
            cur.execute(query, {"limit": limit})
            return cur.fetchall()

    def get_clients_with_missed_workouts(self, days_back: int = 7) -> List[Dict[str, Any]]:
        """Identifies clients who have missed workout targets in the specified window."""
        query = """
        SELECT 
            u.id as "userId", u.name, cp.id as "clientProfileId", cp."clientId",
            cp."trainingDaysPerWeek",
            COUNT(wr.id) as "completedWorkouts"
        FROM users u
        JOIN client_profiles cp ON u.id = cp."userId"
        LEFT JOIN workout_records wr ON u.id = wr."clientId" 
             AND wr."isCompleted" = TRUE 
             AND wr."startedAt" >= NOW() - INTERVAL '%(days)s days'
        WHERE u.role = 'CLIENT' AND cp."membershipStatus" = 'ACTIVE'
        GROUP BY u.id, u.name, cp.id, cp."clientId", cp."trainingDaysPerWeek"
        HAVING COUNT(wr.id) < COALESCE(cp."trainingDaysPerWeek", 3)
        ORDER BY "completedWorkouts" ASC, u.name ASC;
        """
        with get_db_cursor() as cur:
            cur.execute(query.replace("%(days)s", str(int(days_back))))
            return cur.fetchall()

    def get_clients_with_missing_checkins(self) -> List[Dict[str, Any]]:
        """Identifies active clients without a weekly check-in in the last 10 days."""
        query = """
        SELECT 
            u.id as "userId", u.name, cp.id as "clientProfileId", cp."clientId",
            cp."lastAppOpenAt",
            MAX(wci."checkInDate") as "latestCheckIn"
        FROM users u
        JOIN client_profiles cp ON u.id = cp."userId"
        LEFT JOIN weekly_check_ins wci ON cp.id = wci."clientProfileId"
        WHERE u.role = 'CLIENT' AND cp."membershipStatus" = 'ACTIVE'
        GROUP BY u.id, u.name, cp.id, cp."clientId", cp."lastAppOpenAt"
        HAVING MAX(wci."checkInDate") IS NULL OR MAX(wci."checkInDate") < NOW() - INTERVAL '10 days'
        ORDER BY MAX(wci."checkInDate") ASC NULLS FIRST, u.name ASC;
        """
        with get_db_cursor() as cur:
            cur.execute(query)
            return cur.fetchall()

    def get_clients_with_poor_protein(self, days_back: int = 14) -> List[Dict[str, Any]]:
        """Identifies clients whose average actual protein intake is < 80% of assigned diet target."""
        query = """
        SELECT 
            u.id as "userId", u.name, cp.id as "clientProfileId", cp."clientId",
            dp.protein as "targetProtein",
            ROUND(AVG(cfl.protein)::numeric, 1) as "avgActualProtein",
            COUNT(DISTINCT cfl.date) as "daysLogged"
        FROM users u
        JOIN client_profiles cp ON u.id = cp."userId"
        JOIN diet_plans dp ON cp.id = dp."clientProfileId" AND dp."isActive" = TRUE
        JOIN client_food_logs cfl ON cp.id = cfl."clientProfileId"
             AND cfl.date >= (CURRENT_DATE - (%(days)s || ' days')::interval)::date
        WHERE u.role = 'CLIENT' AND cp."membershipStatus" = 'ACTIVE'
        GROUP BY u.id, u.name, cp.id, cp."clientId", dp.protein
        HAVING dp.protein > 0 AND AVG(cfl.protein) < (dp.protein * 0.8)
        ORDER BY (AVG(cfl.protein) / dp.protein) ASC;
        """
        with get_db_cursor() as cur:
            cur.execute(query, {"days": days_back})
            return cur.fetchall()

    def get_clients_with_poor_recovery(self) -> List[Dict[str, Any]]:
        """Identifies clients reporting poor sleep, high fatigue, or pain in their latest check-in."""
        query = """
        WITH latest_checkins AS (
            SELECT DISTINCT ON ("clientProfileId") *
            FROM weekly_check_ins
            ORDER BY "clientProfileId", "checkInDate" DESC
        )
        SELECT 
            u.id as "userId", u.name, cp.id as "clientProfileId", cp."clientId",
            lc."checkInDate", lc."sleepHours", lc."sleepQuality",
            lc."recoveryQuality", lc."energyLevel", lc."stressLevel",
            lc."hasPain", lc."painLocation", lc."painLevel", lc."painExercise"
        FROM users u
        JOIN client_profiles cp ON u.id = cp."userId"
        JOIN latest_checkins lc ON cp.id = lc."clientProfileId"
        WHERE u.role = 'CLIENT' AND cp."membershipStatus" = 'ACTIVE'
          AND (
            lc."hasPain" = TRUE 
            OR lc."recoveryQuality" IN ('POOR', 'VERY_POOR')
            OR lc."sleepQuality" IN ('POOR', 'VERY_POOR')
            OR (lc."sleepHours" IS NOT NULL AND lc."sleepHours" < 6.0)
            OR (lc."stressLevel" IS NOT NULL AND lc."stressLevel" >= 8)
          )
        ORDER BY lc."checkInDate" DESC;
        """
        with get_db_cursor() as cur:
            cur.execute(query)
            return cur.fetchall()

    def get_clients_with_diet_discrepancy(self, days_back: int = 14) -> List[Dict[str, Any]]:
        """Identifies clients whose actual food log calories deviate by > 20% from assigned diet."""
        query = """
        SELECT 
            u.id as "userId", u.name, cp.id as "clientProfileId", cp."clientId",
            dp."dailyCalories" as "targetCalories",
            ROUND(AVG(cfl.calories)::numeric, 0) as "avgActualCalories",
            ROUND(AVG(cfl.calories)::numeric - dp."dailyCalories", 0) as "calorieDelta",
            ROUND(100.0 * (AVG(cfl.calories) - dp."dailyCalories") / NULLIF(dp."dailyCalories", 0), 1) as "percentDeviation",
            COUNT(DISTINCT cfl.date) as "daysLogged"
        FROM users u
        JOIN client_profiles cp ON u.id = cp."userId"
        JOIN diet_plans dp ON cp.id = dp."clientProfileId" AND dp."isActive" = TRUE
        JOIN client_food_logs cfl ON cp.id = cfl."clientProfileId"
             AND cfl.date >= (CURRENT_DATE - (%(days)s || ' days')::interval)::date
        WHERE u.role = 'CLIENT' AND cp."membershipStatus" = 'ACTIVE'
        GROUP BY u.id, u.name, cp.id, cp."clientId", dp."dailyCalories"
        HAVING dp."dailyCalories" > 0 AND ABS(AVG(cfl.calories) - dp."dailyCalories") > (dp."dailyCalories" * 0.20)
        ORDER BY ABS(AVG(cfl.calories) - dp."dailyCalories") DESC;
        """
        with get_db_cursor() as cur:
            cur.execute(query, {"days": days_back})
            return cur.fetchall()

    def get_checkin_delta(self, client_profile_id: str) -> Optional[Dict[str, Any]]:
        """Fetches latest two weekly check-ins and returns factual differences."""
        checkins = self.get_weekly_checkins(client_profile_id, limit=2)
        if len(checkins) < 2:
            return None
        current = checkins[0]
        prev = checkins[1]
        w_cur = current.get("currentWeightKg")
        w_prev = prev.get("currentWeightKg")
        waist_cur = current.get("waistCm")
        waist_prev = prev.get("waistCm")
        return {
            "currentDate": current.get("checkInDate"),
            "previousDate": prev.get("checkInDate"),
            "currentWeek": current.get("weekNumber"),
            "previousWeek": prev.get("weekNumber"),
            "currentWeightKg": w_cur,
            "previousWeightKg": w_prev,
            "weightDeltaKg": round(w_cur - w_prev, 2) if (w_cur is not None and w_prev is not None) else None,
            "currentWaistCm": waist_cur,
            "previousWaistCm": waist_prev,
            "waistDeltaCm": round(waist_cur - waist_prev, 2) if (waist_cur is not None and waist_prev is not None) else None,
            "currentEnergy": current.get("energyLevel"),
            "previousEnergy": prev.get("energyLevel"),
            "currentSleep": current.get("sleepHours"),
            "previousSleep": prev.get("sleepHours"),
            "hasPain": current.get("hasPain"),
            "painDetails": f"{current.get('painLocation')} ({current.get('painLevel')}/10)" if current.get("hasPain") else None,
        }

    # ==========================================
    # PROPOSAL CREATION & ADMIN APPROVAL LIFECYCLE
    # ==========================================

    def create_proposal(
        self,
        client_profile_id: str,
        client_name: str,
        proposal_type: str,
        title: str,
        summary: str,
        reason: str,
        proposed_data: Dict[str, Any],
        client_id: Optional[str] = None,
        conversation_id: Optional[str] = None,
        current_data: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """Creates a pending AI proposal. Status starts at PENDING."""
        query = """
        INSERT INTO ai_proposals (
            "conversationId", "clientProfileId", "clientId", "clientName",
            "proposalType", status, title, summary, reason,
            "currentDataJson", "proposedDataJson"
        ) VALUES (
            %(conv_id)s, %(cp_id)s, %(client_id)s, %(name)s,
            %(type)s, 'PENDING', %(title)s, %(summary)s, %(reason)s,
            %(current_json)s, %(proposed_json)s
        )
        RETURNING *;
        """
        with get_db_cursor() as cur:
            cur.execute(query, {
                "conv_id": conversation_id,
                "cp_id": client_profile_id,
                "client_id": client_id,
                "name": client_name,
                "type": proposal_type.upper(),
                "title": title,
                "summary": summary,
                "reason": reason,
                "current_json": json.dumps(current_data) if current_data else None,
                "proposed_json": json.dumps(proposed_data),
            })
            return cur.fetchone()

    def approve_proposal(self, proposal_id: str, admin_id: str, admin_name: str) -> Dict[str, Any]:
        """
        Authoritative write operation executing Admin approval.
        Updates client plan, versions the update, and records audit trail.
        """
        with get_db_cursor() as cur:
            cur.execute("SELECT * FROM ai_proposals WHERE id = %(id)s;", {"id": proposal_id})
            proposal = cur.fetchone()
            if not proposal:
                raise ValueError(f"Proposal not found: {proposal_id}")
            if proposal["status"] == "APPROVED":
                return proposal

            payload_raw = proposal.get("finalDataJson") or proposal["proposedDataJson"]
            payload = json.loads(payload_raw)
            p_type = proposal["proposalType"].upper()

            if p_type == "DIET":
                # Deactivate current active diet plan
                cur.execute("""
                    UPDATE diet_plans SET "isActive" = FALSE 
                    WHERE "clientProfileId" = %(cp_id)s AND "isActive" = TRUE;
                """, {"cp_id": proposal["clientProfileId"]})

                # Determine next version number
                cur.execute("""
                    SELECT COALESCE(MAX(version), 0) + 1 as "nextVersion"
                    FROM diet_plans WHERE "clientProfileId" = %(cp_id)s;
                """, {"cp_id": proposal["clientProfileId"]})
                next_version = cur.fetchone()["nextVersion"]

                # Insert new active DietPlan
                meals_data = payload.get("meals", [])
                meals_json = meals_data if isinstance(meals_data, str) else json.dumps(meals_data)
                cur.execute("""
                    INSERT INTO diet_plans (
                        id, "clientProfileId", "clientId", "planName", version,
                        "assignedById", "assignedByName", "dailyCalories",
                        protein, carbohydrates, fat, fiber, "waterTargetLiters",
                        "isActive", "mealsJson", notes
                    ) VALUES (
                        gen_random_uuid(), %(cp_id)s, %(client_id)s, %(plan_name)s, %(version)s,
                        %(admin_id)s, %(admin_name)s, %(cals)s,
                        %(protein)s, %(carbs)s, %(fat)s, %(fiber)s, %(water)s,
                        TRUE, %(meals_json)s, %(notes)s
                    ) RETURNING id;
                """, {
                    "cp_id": proposal["clientProfileId"],
                    "client_id": proposal["clientId"],
                    "plan_name": payload.get("planName") or "AI-Engineered Nutrition Plan",
                    "version": next_version,
                    "admin_id": admin_id,
                    "admin_name": admin_name,
                    "cals": float(payload.get("dailyCalories", 2000)),
                    "protein": float(payload.get("protein", 150)),
                    "carbs": float(payload.get("carbohydrates", 200)),
                    "fat": float(payload.get("fat", 60)),
                    "fiber": float(payload.get("fiber", 30)),
                    "water": float(payload.get("waterTargetLiters", 3.0)),
                    "meals_json": meals_json,
                    "notes": payload.get("notes") or f"Approved by Admin from AI Proposal {proposal_id}",
                })
                new_diet_id = cur.fetchone()["id"]

                # Insert DietPlanHistory
                cur.execute("""
                    INSERT INTO diet_plan_histories (
                        id, "dietPlanId", "clientProfileId", "clientId",
                        "adminId", "adminName", version, "planName",
                        "dailyCalories", protein, carbohydrates, fat, fiber,
                        "waterTargetLiters", "mealsJson", notes, "changeSummary"
                    ) VALUES (
                        gen_random_uuid(), %(diet_id)s, %(cp_id)s, %(client_id)s,
                        %(admin_id)s, %(admin_name)s, %(version)s, %(plan_name)s,
                        %(cals)s, %(protein)s, %(carbs)s, %(fat)s, %(fiber)s,
                        %(water)s, %(meals_json)s, %(notes)s, %(summary)s
                    );
                """, {
                    "diet_id": new_diet_id,
                    "cp_id": proposal["clientProfileId"],
                    "client_id": proposal["clientId"],
                    "admin_id": admin_id,
                    "admin_name": admin_name,
                    "version": next_version,
                    "plan_name": payload.get("planName") or "AI-Engineered Nutrition Plan",
                    "cals": float(payload.get("dailyCalories", 2000)),
                    "protein": float(payload.get("protein", 150)),
                    "carbs": float(payload.get("carbohydrates", 200)),
                    "fat": float(payload.get("fat", 60)),
                    "fiber": float(payload.get("fiber", 30)),
                    "water": float(payload.get("waterTargetLiters", 3.0)),
                    "meals_json": meals_json,
                    "notes": payload.get("notes") or "Approved proposal",
                    "summary": f"AI Nutrition Proposal approved by {admin_name}",
                })

            elif p_type == "WORKOUT":
                # Lookup client userId
                cur.execute("SELECT \"userId\" FROM client_profiles WHERE id = %(cp_id)s;", {"cp_id": proposal["clientProfileId"]})
                profile_row = cur.fetchone()
                user_id = profile_row["userId"] if profile_row else None

                if user_id:
                    # Create WorkoutSession
                    cur.execute("""
                        INSERT INTO workout_sessions (
                            id, title, "workoutType", "targetMuscleGroup", difficulty,
                            "estimatedDurationMinutes", description, "createdById",
                            "isActive", "availabilityType"
                        ) VALUES (
                            gen_random_uuid(), %(title)s, %(type)s, %(muscle)s, %(diff)s,
                            %(duration)s, %(desc)s, %(admin_id)s,
                            TRUE, 'INDIVIDUAL'
                        ) RETURNING id;
                    """, {
                        "title": payload.get("title") or "AI Optimized Training Session",
                        "type": payload.get("workoutType") or "Hypertrophy",
                        "muscle": payload.get("targetMuscleGroup") or "Full Body",
                        "diff": payload.get("difficulty") or "Intermediate",
                        "duration": int(payload.get("estimatedDurationMinutes", 50)),
                        "desc": payload.get("description") or "Custom tailored by Alpha X AI Coach with Admin approval.",
                        "admin_id": admin_id,
                    })
                    session_id = cur.fetchone()["id"]

                    # Insert exercises
                    exercises = payload.get("exercises", [])
                    for i, ex in enumerate(exercises):
                        cur.execute("""
                            INSERT INTO workout_session_exercises (
                                id, "sessionId", "exerciseId", "exerciseName", category,
                                "orderIndex", "numberOfSets", "targetReps", "targetWeight",
                                "restSeconds", "targetRir", "targetRpe", tempo, "adminInstruction"
                            ) VALUES (
                                gen_random_uuid(), %(session_id)s, %(ex_id)s, %(name)s, %(cat)s,
                                %(idx)s, %(sets)s, %(reps)s, %(weight)s,
                                %(rest)s, %(rir)s, %(rpe)s, %(tempo)s, %(instruct)s
                            ) RETURNING id;
                        """, {
                            "session_id": session_id,
                            "ex_id": ex.get("exerciseId") or f"ex_custom_{i}",
                            "name": ex.get("exerciseName") or "Exercise",
                            "cat": ex.get("category") or "Strength",
                            "idx": i,
                            "sets": int(ex.get("sets") or ex.get("numberOfSets") or 3),
                            "reps": str(ex.get("targetReps", "8-12")),
                            "weight": float(ex["targetWeight"]) if ex.get("targetWeight") is not None else None,
                            "rest": int(ex.get("restSeconds", 90)),
                            "rir": int(ex.get("targetRir", 2)),
                            "rpe": float(ex.get("targetRpe", 8.0)),
                            "tempo": ex.get("tempo", "3-1-1-0"),
                            "instruct": ex.get("notes") or ex.get("adminInstruction"),
                        })
                        session_ex_id = cur.fetchone()["id"]

                        # Insert set templates
                        num_sets = int(ex.get("sets") or ex.get("numberOfSets") or 3)
                        for s in range(1, num_sets + 1):
                            cur.execute("""
                                INSERT INTO workout_set_templates (
                                    id, "sessionExerciseId", "setNumber", "setType",
                                    "targetWeight", "targetRepsMin", "targetRepsMax",
                                    "targetRir", "targetRpe"
                                ) VALUES (
                                    gen_random_uuid(), %(session_ex_id)s, %(set_num)s, 'WORKING',
                                    %(weight)s, 8, 12, %(rir)s, %(rpe)s
                                );
                            """, {
                                "session_ex_id": session_ex_id,
                                "set_num": s,
                                "weight": float(ex["targetWeight"]) if ex.get("targetWeight") is not None else None,
                                "rir": int(ex.get("targetRir", 2)),
                                "rpe": float(ex.get("targetRpe", 8.0)),
                            })

                    # Deactivate previous active workout assignments
                    cur.execute("""
                        UPDATE workout_assignments SET active = FALSE
                        WHERE "clientId" = %(user_id)s AND active = TRUE;
                    """, {"user_id": user_id})

                    # Assign new session to client
                    cur.execute("""
                        INSERT INTO workout_assignments (
                            id, "sessionId", "clientId", "isRecommended", "assignedById", active
                        ) VALUES (
                            gen_random_uuid(), %(session_id)s, %(user_id)s, TRUE, %(admin_id)s, TRUE
                        );
                    """, {
                        "session_id": session_id,
                        "user_id": user_id,
                        "admin_id": admin_id,
                    })

            # Update proposal status to APPROVED
            cur.execute("""
                UPDATE ai_proposals
                SET status = 'APPROVED',
                    "approvedById" = %(admin_id)s,
                    "approvedByName" = %(admin_name)s,
                    "approvedAt" = NOW(),
                    "updatedAt" = NOW()
                WHERE id = %(id)s
                RETURNING *;
            """, {
                "id": proposal_id,
                "admin_id": admin_id,
                "admin_name": admin_name,
            })
            updated_proposal = cur.fetchone()

            # Record audit log
            cur.execute("""
                INSERT INTO ai_audit_logs (
                    id, "adminId", "adminName", "clientId", "clientName",
                    action, details, "metadataJson"
                ) VALUES (
                    gen_random_uuid(), %(admin_id)s, %(admin_name)s, %(client_id)s, %(client_name)s,
                    'PROPOSAL_APPROVED', %(details)s, %(meta)s
                );
            """, {
                "admin_id": admin_id,
                "admin_name": admin_name,
                "client_id": proposal["clientId"],
                "client_name": proposal["clientName"],
                "details": f"Approved {proposal['proposalType']} proposal \"{proposal['title']}\" for athlete {proposal['clientName']}",
                "meta": json.dumps({"proposalId": proposal_id, "proposalType": proposal["proposalType"]}),
            })

            return updated_proposal

    def reject_proposal(self, proposal_id: str, admin_id: str, reason: Optional[str] = None) -> Dict[str, Any]:
        """Rejects proposal and documents rationale."""
        with get_db_cursor() as cur:
            cur.execute("""
                UPDATE ai_proposals
                SET status = 'REJECTED',
                    "rejectedById" = %(admin_id)s,
                    "rejectedAt" = NOW(),
                    "rejectionReason" = %(reason)s,
                    "updatedAt" = NOW()
                WHERE id = %(id)s
                RETURNING *;
            """, {
                "id": proposal_id,
                "admin_id": admin_id,
                "reason": reason or "Rejected by Admin",
            })
            rejected = cur.fetchone()
            if not rejected:
                raise ValueError(f"Proposal not found: {proposal_id}")

            # Audit log
            cur.execute("""
                INSERT INTO ai_audit_logs (
                    id, "adminId", "clientId", "clientName",
                    action, details, "metadataJson"
                ) VALUES (
                    gen_random_uuid(), %(admin_id)s, %(client_id)s, %(client_name)s,
                    'PROPOSAL_REJECTED', %(details)s, %(meta)s
                );
            """, {
                "admin_id": admin_id,
                "client_id": rejected["clientId"],
                "client_name": rejected["clientName"],
                "details": f"Rejected {rejected['proposalType']} proposal \"{rejected['title']}\". Reason: {reason or 'Admin decision'}",
                "meta": json.dumps({"proposalId": proposal_id}),
            })
            return rejected

    def edit_proposal(self, proposal_id: str, admin_id: str, edited_payload: Dict[str, Any]) -> Dict[str, Any]:
        """Saves Admin adjustments to proposal payload."""
        with get_db_cursor() as cur:
            cur.execute("""
                UPDATE ai_proposals
                SET status = 'EDITED',
                    "finalDataJson" = %(payload)s,
                    "updatedAt" = NOW()
                WHERE id = %(id)s
                RETURNING *;
            """, {
                "id": proposal_id,
                "payload": json.dumps(edited_payload),
            })
            edited = cur.fetchone()
            if not edited:
                raise ValueError(f"Proposal not found: {proposal_id}")

            cur.execute("""
                INSERT INTO ai_audit_logs (
                    id, "adminId", "clientId", "clientName",
                    action, details, "metadataJson"
                ) VALUES (
                    gen_random_uuid(), %(admin_id)s, %(client_id)s, %(client_name)s,
                    'PROPOSAL_EDITED', %(details)s, %(meta)s
                );
            """, {
                "admin_id": admin_id,
                "client_id": edited["clientId"],
                "client_name": edited["clientName"],
                "details": f"Admin modified proposal payload for \"{edited['title']}\"",
                "meta": json.dumps({"proposalId": proposal_id}),
            })
            return edited

alpha_x_tools = AlphaXTools()
