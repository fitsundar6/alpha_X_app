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

export const DEFAULT_TOOL_CONFIG: ToolSystemConfig = {
  maxToolCallsPerRequest: 3,
  toolTimeoutMs: 5000,
  maxResultCharacters: 4000,
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
