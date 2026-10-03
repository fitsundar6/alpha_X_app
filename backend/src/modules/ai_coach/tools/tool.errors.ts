/**
 * Alpha X AI — Tool Error Hierarchy
 * Phase 5 — Secure AI Tool & Function Calling Architecture
 */

export class ToolError extends Error {
  public readonly code: string;
  public readonly toolName?: string;

  constructor(message: string, code: string = 'TOOL_ERROR', toolName?: string) {
    super(message);
    this.name = 'ToolError';
    this.code = code;
    this.toolName = toolName;
    Object.setPrototypeOf(this, new.target.prototype);
  }
}

export class ToolNotFoundError extends ToolError {
  constructor(toolName: string) {
    super(`Tool '${toolName}' is not registered or is not recognized by the system`, 'TOOL_NOT_FOUND', toolName);
  }
}

export class DuplicateToolError extends ToolError {
  constructor(toolName: string) {
    super(`A tool with the name '${toolName}' has already been registered`, 'DUPLICATE_TOOL', toolName);
  }
}

export class ToolValidationError extends ToolError {
  public readonly validationErrors?: string[];

  constructor(toolName: string, message: string, validationErrors?: string[]) {
    super(`Validation failed for tool '${toolName}': ${message}`, 'TOOL_VALIDATION_ERROR', toolName);
    this.validationErrors = validationErrors;
  }
}

export class ToolPermissionError extends ToolError {
  constructor(toolName: string, message: string) {
    super(`Permission denied for tool '${toolName}': ${message}`, 'TOOL_PERMISSION_DENIED', toolName);
  }
}

export class ToolTimeoutError extends ToolError {
  constructor(toolName: string, timeoutMs: number) {
    super(`Tool '${toolName}' execution timed out after ${timeoutMs}ms`, 'TOOL_TIMEOUT', toolName);
  }
}

export class ToolLimitExceededError extends ToolError {
  constructor(message: string) {
    super(message, 'TOOL_LIMIT_EXCEEDED');
  }
}

export class ToolExecutionError extends ToolError {
  constructor(toolName: string, internalMessage: string) {
    // Sanitized client-safe message: never leak DB queries, stack traces, or credentials
    super(`Tool '${toolName}' execution encountered an unexpected issue`, 'TOOL_EXECUTION_FAILED', toolName);
  }
}
