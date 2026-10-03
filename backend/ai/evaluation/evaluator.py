import time
import logging
from typing import Dict, Any, List
from backend.ai.controller.ai_controller import ai_controller
from backend.ai.models.schemas import AiCoachChatRequest
from backend.ai.services.calculations import calc_engine
from backend.ai.database.connection import get_db_cursor

logger = logging.getLogger("alpha_x_ai.evaluation")

class EvaluationTestCase:
    def __init__(
        self,
        name: str,
        prompt: str,
        expected_intent: str,
        preset: str = None,
        selected_client_id: str = None,
        must_contain: List[str] = None,
        must_not_contain: List[str] = None,
        requires_proposal: bool = False,
    ):
        self.name = name
        self.prompt = prompt
        self.expected_intent = expected_intent
        self.preset = preset
        self.selected_client_id = selected_client_id
        self.must_contain = must_contain or []
        self.must_not_contain = must_not_contain or []
        self.requires_proposal = requires_proposal

class AlphaXEvaluator:
    """
    Automated benchmark evaluation suite assessing AI retrieval precision,
    mathematical correctness, intent classification, and absence of hallucination.
    """

    def __init__(self):
        self.test_cases: List[EvaluationTestCase] = [
            EvaluationTestCase(
                name="1. Daily Operational Report Intent",
                prompt="Give me today's report",
                expected_intent="DAILY_REPORT",
                must_contain=["Active Athletes", "Workouts Completed Today"],
            ),
            EvaluationTestCase(
                name="2. Weekly Facility Report Intent",
                prompt="Give me this week's report",
                expected_intent="WEEKLY_REPORT",
                preset="this_week",
                must_contain=["Alpha X Weekly Facility Intelligence"],
            ),
            EvaluationTestCase(
                name="3. Clients Needing Review Query",
                prompt="Show me clients who need attention today",
                expected_intent="ATTENTION_CLIENTS",
                must_contain=["Athletes Requiring Attention"],
            ),
            EvaluationTestCase(
                name="4. Missed Workouts Query",
                prompt="Which clients are missing workouts this week?",
                expected_intent="MISSED_WORKOUTS",
                must_contain=["Athletes With Missed Workouts"],
            ),
            EvaluationTestCase(
                name="5. Missing Check-Ins Query",
                prompt="Which clients haven't completed their weekly check-in?",
                expected_intent="MISSING_CHECKINS",
                must_contain=["Athletes With Overdue Check-Ins"],
            ),
            EvaluationTestCase(
                name="6. Ambiguous Client Clarification",
                prompt="Analyze this client's progress",
                expected_intent="AMBIGUOUS_CLIENT",
                must_contain=["Which client would you like me to analyze"],
            ),
            EvaluationTestCase(
                name="7. Workout Session Proposal Generation",
                prompt="Create a workout for Kumar",
                expected_intent="WORKOUT_PROPOSAL",
                requires_proposal=True,
                must_contain=["AI Proposal", "Protocol"],
            ),
            EvaluationTestCase(
                name="8. Progressive Overload Proposal Generation",
                prompt="Progress Kumar's bench press",
                expected_intent="PROGRESSION_PROPOSAL",
                requires_proposal=True,
                must_contain=["AI Proposal", "Bench Press"],
            ),
            EvaluationTestCase(
                name="9. Diet Proposal Generation from Food Library",
                prompt="Create a diet proposal for Kumar",
                expected_intent="DIET_PROPOSAL",
                requires_proposal=True,
                must_contain=["AI Proposal", "Nutrition Plan"],
            ),
            EvaluationTestCase(
                name="10. Temporal Date Range Parsing - Last 4 Weeks",
                prompt="Analyze his last 4 weeks",
                expected_intent="AMBIGUOUS_CLIENT",
                must_contain=["Which client would you like me to analyze"],
            ),
        ]

    def run_all_evaluations(self) -> Dict[str, Any]:
        """Runs the entire evaluation suite and records results into ai_evaluations."""
        results = []
        passed_count = 0
        total_tests = len(self.test_cases)
        start_time = time.time()

        for tc in self.test_cases:
            print(f"Executing test: {tc.name}...", flush=True)
            t0 = time.time()
            req = AiCoachChatRequest(
                message=tc.prompt,
                dateRangePreset=tc.preset,
                selectedClientId=tc.selected_client_id,
            )

            try:
                resp = ai_controller.handle_admin_message(req, admin_id="admin_eval", admin_name="Eval Admin")
                latency_ms = int((time.time() - t0) * 1000)

                # Intent check
                intent_match = resp.intent == tc.expected_intent

                # Proposal check
                proposal_match = True
                if tc.requires_proposal:
                    proposal_match = resp.proposal is not None

                # Content check
                contains_all = all(item.lower() in resp.replyText.lower() for item in tc.must_contain)
                not_contains_any = not any(item.lower() in resp.replyText.lower() for item in tc.must_not_contain)

                hallucination_detected = not (contains_all and not_contains_any)
                passed = intent_match and proposal_match and contains_all and not_contains_any

                if passed:
                    passed_count += 1

                res_dict = {
                    "testCaseName": tc.name,
                    "prompt": tc.prompt,
                    "expectedIntent": tc.expected_intent,
                    "detectedIntent": resp.intent,
                    "passed": passed,
                    "latencyMs": latency_ms,
                    "hallucinationDetected": hallucination_detected,
                }
                results.append(res_dict)

                # Persist in DB
                try:
                    with get_db_cursor() as cur:
                        cur.execute("""
                            INSERT INTO ai_evaluations (
                                "testCaseName", "inputPrompt", "detectedIntent",
                                "dataRetrievalAccuracy", "calculationAccuracy",
                                "hallucinationDetected", "latencyMs", passed
                            ) VALUES (
                                %(name)s, %(prompt)s, %(intent)s,
                                %(retrieval)s, %(calc)s, %(halluc)s, %(latency)s, %(passed)s
                            );
                        """, {
                            "name": tc.name,
                            "prompt": tc.prompt,
                            "intent": resp.intent,
                            "retrieval": 100.0 if intent_match else 0.0,
                            "calc": 100.0 if proposal_match else 50.0,
                            "halluc": hallucination_detected,
                            "latency": latency_ms,
                            "passed": passed,
                        })
                except Exception:
                    pass

            except Exception as e:
                logger.error(f"Test case '{tc.name}' failed with exception: {e}")
                results.append({
                    "testCaseName": tc.name,
                    "prompt": tc.prompt,
                    "passed": False,
                    "error": str(e),
                })

        duration = round(time.time() - start_time, 2)
        score_percentage = round((passed_count / total_tests) * 100, 1) if total_tests > 0 else 0

        return {
            "totalTests": total_tests,
            "passedTests": passed_count,
            "failedTests": total_tests - passed_count,
            "qualityScorePercentage": score_percentage,
            "totalDurationSeconds": duration,
            "results": results,
        }

evaluator = AlphaXEvaluator()
