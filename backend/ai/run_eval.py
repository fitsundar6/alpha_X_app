import sys
from pathlib import Path

# Add project root to sys.path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")

from backend.ai.evaluation.evaluator import evaluator

if __name__ == "__main__":
    report = evaluator.run_all_evaluations()
    print("=========================================")
    print("ALPHA X AI COACH EVALUATION RESULTS")
    print(f"Total Tests: {report['totalTests']}")
    print(f"Passed: {report['passedTests']}")
    print(f"Failed: {report['failedTests']}")
    print(f"Quality Score: {report['qualityScorePercentage']}%")
    print(f"Duration: {report['totalDurationSeconds']}s")
    print("=========================================")
    for r in report["results"]:
        status_icon = "✔" if r.get("passed") else "❌"
        print(f"{status_icon} {r['testCaseName']}: {r.get('detectedIntent', 'ERROR')} ({r.get('latencyMs', 0)}ms)")
