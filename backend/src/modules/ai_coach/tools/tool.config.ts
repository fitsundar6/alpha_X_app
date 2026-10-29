/**
 * Alpha X AI — Tool System Configuration
 * Phase 5 — Secure AI Tool & Function Calling Architecture
 */

export interface ToolSystemConfig {
  /** Maximum number of tool calls permitted within a single AI request turn */
  maxToolCallsPerRequest: number;
  /** Maximum execution duration per tool before aborting (ms) */
  toolTimeoutMs: number;
  /** Maximum character length of serialized tool result data */
  maxResultCharacters: number;
  /** Hardcoded write protection flag — strictly false in Phase 5 */
  allowWriteTools: boolean;
}

/**
 * Proposal tool names that must NEVER be blocked by the tool-call cap.
 * A workout or diet proposal is the end-product of the entire tool-call chain;
 * if the cap prevents it from executing, Gemini falls back to a text-only
 * description and no database record is ever created.
 *
 * These tools are still subject to permission validation and secure execution —
 * they are simply exempt from the soft per-request call count limit so that the
 * structured proposal workflow always completes when Gemini decides to invoke it.
 */
export const PROPOSAL_TOOL_NAMES: ReadonlySet<string> = new Set([
  'propose_workout_plan',
  'propose_diet_plan',
]);

export const DEFAULT_TOOL_CONFIG: ToolSystemConfig = {
  /**
   * Raised from 3 → 8.
   *
   * Root-cause fix for "workout proposals not created" bug:
   * The Gemini model's typical chain for a workout plan is:
   *   1. get_client_profile
   *   2. search_exercise_library  (may be called 2–4 times for different splits/days)
   *   3. propose_workout_plan     ← was blocked when cap was 3
   *
   * A cap of 8 supports a 6-day PPL split (up to 6 search_exercise_library calls)
   * plus one get_client_profile and one propose_workout_plan without hitting the limit.
   * PROPOSAL_TOOL_NAMES also bypass the soft cap as a safety net (see gemini.service.ts).
   */
  maxToolCallsPerRequest: 8,
  toolTimeoutMs: 20000,
  maxResultCharacters: 16000,
  allowWriteTools: false, // Phase 5: WRITE tools strictly disabled at code level
};

class ToolConfigurationManager {
  private currentConfig: ToolSystemConfig = { ...DEFAULT_TOOL_CONFIG };

  public get config(): ToolSystemConfig {
    return { ...this.currentConfig };
  }

  public get maxToolCallsPerRequest(): number {
    return this.currentConfig.maxToolCallsPerRequest;
  }

  public get toolTimeoutMs(): number {
    return this.currentConfig.toolTimeoutMs;
  }

  public get maxResultCharacters(): number {
    return this.currentConfig.maxResultCharacters;
  }

  public get allowWriteTools(): boolean {
    return this.currentConfig.allowWriteTools;
  }

  public updateConfig(partial: Partial<ToolSystemConfig>): void {
    // Phase 5 security invariant: allowWriteTools CANNOT be enabled in Phase 5
    if (partial.allowWriteTools === true) {
      throw new Error('Security Violation: WRITE tools are strictly forbidden in Phase 5');
    }
    this.currentConfig = {
      ...this.currentConfig,
      ...partial,
      allowWriteTools: false, // Enforce false
    };
  }

  public resetToDefaults(): void {
    this.currentConfig = { ...DEFAULT_TOOL_CONFIG };
  }
}

export const toolConfig = new ToolConfigurationManager();
