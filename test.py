#!/usr/bin/env python3
"""
Alpha X Gym — Standalone Gemini API Key & Model Interactive Verification Tool
==============================================================================
Tests connectivity, authentication, model availability, and generates full
AI responses with custom or random fitness prompts directly from the terminal.

Requirements:
    Python 3.8+ (Zero external pip dependencies — uses standard library only)

Usage Examples:
    python test.py
        Runs connectivity ping check, then enters interactive prompt mode.

    python test.py --prompt "Create a 3-day hypertrophy workout split"
    python test.py -p "What are macro targets for an 80kg male in fat loss?"
        Sends a single prompt directly to the configured model.

    python test.py --random
    python test.py -r
        Picks a random gym coaching prompt and tests the model immediately.

    python test.py --model gemini-flash-lite-latest -p "Hello!"
        Tests a specific Gemini model with a custom prompt.

    python test.py --ping-only
        Runs only the connectivity ping check across candidate models.
"""

import os
import sys
import json
import time
import random
import argparse
import urllib.request
import urllib.error
from pathlib import Path

# Built-in sample prompts for instant testing
SAMPLE_PROMPTS = [
    "Create a 3-day full body workout split for an intermediate athlete focusing on hypertrophy.",
    "Calculate daily caloric intake and macro breakdown (Protein, Carbs, Fat) for an 82kg athlete cutting body fat.",
    "Explain proper cues and setup for the Barbell Romanian Deadlift (RDL) to avoid lower back strain.",
    "Design a 4-week progressive overload scheme for the Barbell Bench Press when plateaued at 80kg.",
    "Recommend a post-workout nutrition meal timing and hydration protocol for an intense 60-minute strength session.",
    "Suggest 4 effective accessory exercises to improve lockout strength in the Overhead Shoulder Press.",
]


def mask_key(key: str) -> str:
    """Masks an API key for safe display (e.g., AQ.A...eStQ)."""
    if not key or len(key) < 8:
        return "[EMPTY/INVALID]"
    return f"{key[:4]}...{key[-4:]}"


def load_env_var_from_file(var_name: str) -> str:
    """Reads a variable from backend/.env or .env without external packages."""
    potential_paths = [
        Path(__file__).parent / "backend" / ".env",
        Path(__file__).parent / ".env",
        Path.cwd() / "backend" / ".env",
        Path.cwd() / ".env",
    ]

    for p in potential_paths:
        if p.is_file():
            try:
                with open(p, "r", encoding="utf-8") as f:
                    for line in f:
                        line = line.strip()
                        if line.startswith(f"{var_name}="):
                            val = line.split("=", 1)[1].strip()
                            if (val.startswith('"') and val.endswith('"')) or (
                                val.startswith("'") and val.endswith("'")
                            ):
                                val = val[1:-1]
                            if val:
                                return val
            except Exception:
                pass
    return ""


def get_api_key(cli_key: str = None) -> str:
    """Resolves API key from CLI argument, environment variable, or backend/.env."""
    if cli_key and cli_key.strip():
        return cli_key.strip()

    env_key = os.environ.get("GEMINI_API_KEY", "").strip()
    if env_key:
        return env_key

    file_key = load_env_var_from_file("GEMINI_API_KEY")
    if file_key:
        return file_key

    try:
        entered = input("Enter your Gemini API key: ").strip()
        if entered:
            return entered
    except (KeyboardInterrupt, EOFError):
        print("\nOperation cancelled.")
        sys.exit(1)

    return ""


def get_configured_model(cli_model: str = None) -> str:
    """Resolves GEMINI_MODEL from CLI arg, env var, or backend/.env (default: gemini-flash-lite-latest)."""
    if cli_model and cli_model.strip():
        return cli_model.strip()

    model = os.environ.get("GEMINI_MODEL", "").strip()
    if not model:
        model = load_env_var_from_file("GEMINI_MODEL")
    return model.strip() if model else "gemini-flash-lite-latest"


def call_gemini_api(api_key: str, model: str, prompt: str, max_tokens: int = 1500, temperature: float = 0.7) -> dict:
    """
    Sends a prompt to the Gemini generateContent REST endpoint.
    Returns a dict with success, status_code, latency_ms, text, and error.
    """
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}"
    payload = {
        "contents": [
            {
                "role": "user",
                "parts": [{"text": prompt}],
            }
        ],
        "generationConfig": {
            "maxOutputTokens": max_tokens,
            "temperature": temperature,
        },
    }

    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    start_time = time.time()
    try:
        with urllib.request.urlopen(req, timeout=45) as resp:
            latency_ms = int((time.time() - start_time) * 1000)
            status_code = resp.getcode()
            response_body = resp.read().decode("utf-8")
            parsed = json.loads(response_body)

            generated_text = ""
            try:
                candidates = parsed.get("candidates", [])
                if candidates:
                    parts = candidates[0].get("content", {}).get("parts", [])
                    generated_text = "".join(p.get("text", "") for p in parts).strip()
            except Exception:
                pass

            usage = parsed.get("usageMetadata", {})

            return {
                "success": True,
                "status_code": status_code,
                "latency_ms": latency_ms,
                "model": model,
                "text": generated_text,
                "usage": usage,
                "error": None,
            }
    except urllib.error.HTTPError as e:
        latency_ms = int((time.time() - start_time) * 1000)
        raw_error = e.read().decode("utf-8", errors="replace")
        error_message = ""
        try:
            err_json = json.loads(raw_error)
            error_message = err_json.get("error", {}).get("message", "")
        except Exception:
            error_message = raw_error

        return {
            "success": False,
            "status_code": e.code,
            "latency_ms": latency_ms,
            "model": model,
            "text": None,
            "usage": {},
            "error": error_message or str(e),
        }
    except Exception as e:
        latency_ms = int((time.time() - start_time) * 1000)
        return {
            "success": False,
            "status_code": 0,
            "latency_ms": latency_ms,
            "model": model,
            "text": None,
            "usage": {},
            "error": str(e),
        }


def diagnose_error(status_code: int, error_msg: str) -> str:
    msg_lower = error_msg.lower()
    if status_code in (401, 403) or "api key not valid" in msg_lower or "api_key_invalid" in msg_lower:
        return "❌ AUTHENTICATION FAILED: The provided API key is invalid or has expired."
    if "unregistered callers" in msg_lower or "without established identity" in msg_lower:
        return "❌ UNREGISTERED CALLER: API key was missing, empty, or not recognized by Google API gateway."
    if status_code == 429 or "quota" in msg_lower or "resource_exhausted" in msg_lower:
        return "⚠️ QUOTA EXHAUSTED (HTTP 429): Key is authentic, but quota is exhausted for this model tier."
    if status_code == 404 or "not found" in msg_lower:
        return "ℹ️ MODEL NOT FOUND (HTTP 404): This model name is not available for this project tier."
    return f"❌ HTTP ERROR {status_code}: {error_msg[:120]}"


def run_ping_check(api_key: str, configured_model: str) -> list:
    """Runs a minimal connectivity ping test across candidate models."""
    candidate_models = [configured_model]
    other_models = [
        "gemini-flash-lite-latest",
        "gemini-2.0-flash",
        "gemini-1.5-flash",
        "gemini-2.5-flash",
    ]
    for m in other_models:
        if m not in candidate_models:
            candidate_models.append(m)

    results = []
    print("\nSending minimal ping requests to Google Generative Language API...\n")

    for model in candidate_models:
        is_active = model == configured_model
        label = f"[{model}] {'(Configured in .env)' if is_active else ''}".strip()
        print(f"Testing {label}...", end=" ", flush=True)

        res = call_gemini_api(
            api_key,
            model,
            prompt="Reply with exactly the word: ACTIVE",
            max_tokens=10,
            temperature=0.0,
        )
        results.append(res)

        if res["success"]:
            print(f"✅ OK ({res['status_code']}) in {res['latency_ms']}ms | Response: \"{res['text']}\"")
        else:
            print(f"❌ FAIL ({res['status_code']}) in {res['latency_ms']}ms")
            diagnosis = diagnose_error(res["status_code"], res["error"])
            print(f"   ↳ {diagnosis}")

    return results


def run_prompt_test(api_key: str, model: str, prompt: str):
    """Executes a full user prompt and prints the generated response."""
    print("\n" + "=" * 65)
    print(f"  AI GENERATION REQUEST [{model}]")
    print("=" * 65)
    print(f"Prompt: \"{prompt}\"")
    print("-" * 65)
    print("Contacting Gemini API...", end=" ", flush=True)

    res = call_gemini_api(api_key, model, prompt, max_tokens=2048, temperature=0.7)

    if res["success"]:
        print(f"✅ Response received in {res['latency_ms']}ms (HTTP 200)\n")
        print("─" * 65)
        print(res["text"])
        print("─" * 65)

        words = len(res["text"].split())
        chars = len(res["text"])
        tokens_info = ""
        if res.get("usage"):
            total_tok = res["usage"].get("totalTokenCount")
            if total_tok:
                tokens_info = f" | Total Tokens: {total_tok}"

        print(f"Stats: {words} words | {chars} characters | Latency: {res['latency_ms']}ms{tokens_info}")
        print("=" * 65 + "\n")
        return True
    else:
        print(f"❌ Failed in {res['latency_ms']}ms (HTTP {res['status_code']})")
        diagnosis = diagnose_error(res["status_code"], res["error"])
        print(f"↳ {diagnosis}")
        if res["error"]:
            print(f"↳ Details: {res['error']}")
        print("=" * 65 + "\n")
        return False


def interactive_prompt_loop(api_key: str, model: str):
    """Interactive CLI prompt loop allowing the user to test multiple prompts."""
    print("=" * 65)
    print("  INTERACTIVE PROMPT TEST MODE")
    print("=" * 65)
    print(f"Target Model: {model}")
    print("Commands:")
    print("  • Type any prompt to test the model")
    print("  • Press [Enter] on an empty line to pick a RANDOM fitness prompt")
    print("  • Type 'random' to pick a random prompt")
    print("  • Type 'exit' or 'q' to quit")
    print("-" * 65)

    while True:
        try:
            user_input = input("\nEnter prompt > ").strip()
        except (KeyboardInterrupt, EOFError):
            print("\nExiting interactive mode.")
            break

        if user_input.lower() in ("exit", "quit", "q"):
            print("Goodbye!")
            break

        if not user_input or user_input.lower() == "random":
            prompt = random.choice(SAMPLE_PROMPTS)
            print(f"[Random Pick]: \"{prompt}\"")
        else:
            prompt = user_input

        run_prompt_test(api_key, model, prompt)


def main():
    parser = argparse.ArgumentParser(
        description="Alpha X Gym — Gemini API Key & Model Interactive Verification Tool"
    )
    parser.add_argument(
        "-p", "--prompt",
        type=str,
        default=None,
        help="A prompt string to send to the model for test generation."
    )
    parser.add_argument(
        "-r", "--random",
        action="store_true",
        help="Test with a randomly chosen fitness/gym coaching prompt."
    )
    parser.add_argument(
        "-m", "--model",
        type=str,
        default=None,
        help="Specify Gemini model (defaults to GEMINI_MODEL or gemini-flash-lite-latest)."
    )
    parser.add_argument(
        "-k", "--key",
        type=str,
        default=None,
        help="Specify Gemini API key (defaults to GEMINI_API_KEY from environment or backend/.env)."
    )
    parser.add_argument(
        "-i", "--interactive",
        action="store_true",
        help="Start directly in interactive prompt mode without ping checks."
    )
    parser.add_argument(
        "--ping-only",
        action="store_true",
        help="Run only the availability ping test across models."
    )

    args, unknown = parser.parse_known_args()

    # If first positional argument looks like an API key or a prompt
    cli_key = args.key
    cli_prompt = args.prompt
    if unknown and not cli_key and not cli_prompt:
        arg0 = unknown[0]
        if arg0.startswith("AIza") or arg0.startswith("AQ."):
            cli_key = arg0
        elif len(unknown) > 0 and not arg0.startswith("-"):
            cli_prompt = " ".join(unknown)

    api_key = get_api_key(cli_key)
    if not api_key:
        print("\n[ERROR] No Gemini API key provided or found in environment.")
        print("Please provide it via: python test.py --key <YOUR_KEY>")
        sys.exit(1)

    model = get_configured_model(args.model)

    print("=" * 65)
    print("  ALPHA X GYM — GEMINI API VERIFICATION & PROMPT TESTING")
    print("=" * 65)
    print(f"[KEY DETECTED] Key: {mask_key(api_key)}")
    print(f"[TARGET MODEL] Model: {model}")
    print("-" * 65)

    # 1. Direct one-shot prompt execution
    if cli_prompt:
        run_prompt_test(api_key, model, cli_prompt)
        return

    # 2. Direct random prompt execution
    if args.random:
        prompt = random.choice(SAMPLE_PROMPTS)
        run_prompt_test(api_key, model, prompt)
        return

    # 3. Direct interactive mode
    if args.interactive:
        interactive_prompt_loop(api_key, model)
        return

    # 4. Standard flow: run ping check first
    ping_results = run_ping_check(api_key, model)

    print("\n" + "=" * 65)
    print("  PING SUMMARY")
    print("=" * 65)
    configured_res = next((r for r in ping_results if r["model"] == model), None)
    if configured_res and configured_res["success"]:
        print(f"✅ Target Model [{model}] is ACTIVE and WORKING ({configured_res['latency_ms']}ms)!")
    else:
        print(f"⚠️ Target Model [{model}] ping failed. Check available models below.")

    successful_models = [r["model"] for r in ping_results if r["success"]]
    print(f"\nAvailable working models on this key ({len(successful_models)}/{len(ping_results)}):")
    for m in successful_models:
        star = "★ (Selected Target)" if m == model else ""
        print(f"  • {m} {star}".strip())
    print("=" * 65)

    if args.ping_only:
        return

    # If the configured model failed but another succeeded, offer switching
    active_test_model = model
    if configured_res and not configured_res["success"] and successful_models:
        active_test_model = successful_models[0]
        print(f"\n[NOTE] Switching test prompt model to working candidate: {active_test_model}")

    # Prompt user to test custom prompts interactively
    print("\nWould you like to test a prompt now?")
    print("  1. Press [Enter] to run a RANDOM fitness prompt test")
    print("  2. Type 'chat' to enter interactive mode")
    print("  3. Type any custom prompt directly")
    print("  4. Type 'q' to exit")

    try:
        user_choice = input("\nEnter prompt or choice > ").strip()
    except (KeyboardInterrupt, EOFError):
        print("\nExiting.")
        return

    if user_choice.lower() in ("q", "quit", "exit"):
        print("Done.")
        return

    if user_choice.lower() == "chat":
        interactive_prompt_loop(api_key, active_test_model)
        return

    if not user_choice or user_choice.lower() == "1" or user_choice.lower() == "random":
        chosen_prompt = random.choice(SAMPLE_PROMPTS)
        print(f"\n[Random Pick]: \"{chosen_prompt}\"")
        run_prompt_test(api_key, active_test_model, chosen_prompt)
    else:
        run_prompt_test(api_key, active_test_model, user_choice)

    # Offer to continue in chat loop
    try:
        cont = input("Test another prompt? (y/N): ").strip().lower()
        if cont in ("y", "yes"):
            interactive_prompt_loop(api_key, active_test_model)
    except (KeyboardInterrupt, EOFError):
        pass


if __name__ == "__main__":
    main()
