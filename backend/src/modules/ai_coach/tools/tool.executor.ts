/**
 * Alpha X AI — Tool Executor
 * Phase 5 — Secure AI Tool & Function Calling Architecture
 */

import { ToolDefinition, ToolExecutionContext, ToolResult } from './tool.types';
import { ToolNotFoundError, ToolTimeoutError, ToolValidationError } from './tool.errors';
import { toolRegistry, ToolRegistry } from './tool.registry';
import { validateToolPermission } from './tool.permissions';
import { toolValidator, ToolValidationService } from './tool.validation';
import { toolConfig } from './tool.config';
import { logServerError } from '../../../utils/serverLogger';

export interface ToolAuditLogEntry {
  requestId: string;
  conversationId: string;
  adminId: string;
  toolName: string;
  category: string;
  permission: string;
  status: 'SUCCESS' | 'FAILED' | 'TIMEOUT';
  latencyMs: number;
  errorMessage?: string;
}

export class ToolExecutor {
  private registry: ToolRegistry;
  private validator: ToolValidationService;

  constructor(registry: ToolRegistry = toolRegistry, validator: ToolValidationService = toolValidator) {
    this.registry = registry;
    this.validator = validator;
  }

  /**
   * Executes a requested tool safely through the multi-stage security pipeline:
   * 1. Registry lookup (safely rejects unknown or disabled tools)
   * 2. Permission & Admin validation (safely rejects unauthorized callers & WRITE tools)
   * 3. Argument schema validation & sanitization
   * 4. Race timeout execution
   * 5. Output size control & sanitization
   * 6. Audit logging
   */
  public async executeTool(
    toolName: string,
    rawArgs: any,
    context: ToolExecutionContext
  ): Promise<ToolResult> {
    const startTime = Date.now();

    // 1. Tool Lookup
    const tool = this.registry.getTool(toolName);
    if (!tool || tool.enabled === false) {
      const latencyMs = Date.now() - startTime;
      const notFoundErr = new ToolNotFoundError(toolName);
      this.logAudit({
        requestId: context.requestId,
        conversationId: context.conversationId,
        adminId: context.adminId,
        toolName,
        category: 'UNKNOWN',
        permission: 'NONE',
        status: 'FAILED',
        latencyMs,
        errorMessage: notFoundErr.message,
      });

      return {
        success: false,
        error: notFoundErr.message,
        toolName,
        latencyMs,
      };
    }

    const safeArgs = { ...(rawArgs || {}) };

    try {
      // 2. Permission & WRITE Protection Validation
      validateToolPermission(tool, context);

      // 2b. Phase 7: Safe Client Context Binding & Pronoun Resolution
      const pronouns = ['he', 'she', 'they', 'him', 'her', 'his', 'their', 'the client', 'this client', 'this member', 'current', 'client'];

      // Bind verified client context to 'clientId' field (standard read tools)
      if (tool.inputSchema?.properties?.clientId) {
        const rawClientId = typeof safeArgs.clientId === 'string' ? safeArgs.clientId.trim().toLowerCase() : '';
        const isPronounOrEmpty = !safeArgs.clientId || pronouns.includes(rawClientId);

        if (isPronounOrEmpty) {
          if (context.verifiedClient) {
            safeArgs.clientId = context.verifiedClient.clientId;
          } else if (tool.name !== 'search_clients') {
            throw new ToolValidationError(
              tool.name,
              `No verified client context is active in this conversation to resolve '${safeArgs.clientId || 'pronoun'}'. Please identify the client first.`
            );
          }
        }
      }

      // Bind verified client context to 'clientIdentifier' field (propose_workout_plan, propose_diet_plan)
      if (tool.inputSchema?.properties?.clientIdentifier) {
        const rawIdentifier = typeof safeArgs.clientIdentifier === 'string' ? safeArgs.clientIdentifier.trim().toLowerCase() : '';
        const isPronounOrEmpty = !safeArgs.clientIdentifier || pronouns.includes(rawIdentifier);

        if (isPronounOrEmpty) {
          if (context.verifiedClient) {
            safeArgs.clientIdentifier = context.verifiedClient.clientId;
          } else {
            throw new ToolValidationError(
              tool.name,
              `No verified client context is active in this conversation to resolve '${safeArgs.clientIdentifier || 'pronoun'}'. Please identify the client first.`
            );
          }
        }
      }

      // 3. Input Validation
      const validatedArgs = this.validator.validateInput(tool, safeArgs);

      // 4. Execution with Timeout
      const rawResult = await this.executeWithTimeout(tool, validatedArgs, context);

      // 5. Result Size Control & Sanitization
      const sanitizedData = this.validator.sanitizeResult(
        tool.name,
        rawResult,
        toolConfig.maxResultCharacters
      );

      const latencyMs = Date.now() - startTime;

      // Check if tool handler returned a structured failure
      if (rawResult && typeof rawResult === 'object' && rawResult.success === false) {
        const failureMessage = rawResult.message || rawResult.error || 'Tool operation failed';
        logServerError({
          requestId: context.requestId,
          activity: `Tool Execution: ${tool.name}`,
          errorMessage: failureMessage,
          errorCode: rawResult.error || 'TOOL_OPERATION_FAILED',
          clientId: context.verifiedClient?.clientId || safeArgs?.clientIdentifier || safeArgs?.clientId,
          details: { toolName: tool.name, conversationId: context.conversationId, adminId: context.adminId },
          receivedPayload: safeArgs,
        });

        this.logAudit({
          requestId: context.requestId,
          conversationId: context.conversationId,
          adminId: context.adminId,
          toolName: tool.name,
          category: tool.category,
          permission: tool.permission,
          status: 'FAILED',
          latencyMs,
          errorMessage: failureMessage,
        });

        return {
          success: false,
          error: failureMessage,
          data: sanitizedData,
          toolName: tool.name,
          latencyMs,
        };
      }

      this.logAudit({
        requestId: context.requestId,
        conversationId: context.conversationId,
        adminId: context.adminId,
        toolName: tool.name,
        category: tool.category,
        permission: tool.permission,
        status: 'SUCCESS',
        latencyMs,
      });

      return {
        success: true,
        data: sanitizedData,
        toolName: tool.name,
        latencyMs,
      };
    } catch (err: any) {
      console.error(`[ALPHA X TOOL EXECUTOR] Execution error in tool '${tool.name}':`, err);
      const latencyMs = Date.now() - startTime;
      const isTimeout = err instanceof ToolTimeoutError;
      const clientFacingError = this.sanitizeErrorMessage(err);

      logServerError({
        requestId: context.requestId,
        activity: `Tool Execution Error: ${tool.name}`,
        error: err,
        errorMessage: err?.message || String(err),
        clientId: context.verifiedClient?.clientId || safeArgs?.clientIdentifier || safeArgs?.clientId,
        details: { toolName: tool.name, conversationId: context.conversationId, adminId: context.adminId },
        receivedPayload: safeArgs,
      });

      this.logAudit({
        requestId: context.requestId,
        conversationId: context.conversationId,
        adminId: context.adminId,
        toolName: tool.name,
        category: tool.category,
        permission: tool.permission,
        status: isTimeout ? 'TIMEOUT' : 'FAILED',
        latencyMs,
        errorMessage: clientFacingError,
      });

      return {
        success: false,
        error: clientFacingError,
        toolName: tool.name,
        latencyMs,
      };
    }
  }

  /**
   * Runs tool handler bounded by timeout
   */
  private async executeWithTimeout(
    tool: ToolDefinition,
    args: any,
    context: ToolExecutionContext
  ): Promise<any> {
    const timeoutMs = toolConfig.toolTimeoutMs;
    let timeoutHandle: NodeJS.Timeout;

    const timeoutPromise = new Promise((_, reject) => {
      timeoutHandle = setTimeout(() => {
        reject(new ToolTimeoutError(tool.name, timeoutMs));
      }, timeoutMs);
    });

    try {
      const executionPromise = tool.handler(args, context);
      return await Promise.race([executionPromise, timeoutPromise]);
    } finally {
      clearTimeout(timeoutHandle!);
    }
  }

  /**
   * Formats tool result as UNTRUSTED DATA for LLM consumption
   */
  public formatAsUntrustedToolResult(result: ToolResult): string {
    const jsonStr = JSON.stringify(result.success ? result.data : { error: result.error });
    return `[TOOL_RESULT:${result.toolName}]\nStatus: ${result.success ? 'SUCCESS' : 'FAILED'}\nUNTRUSTED_DATA: ${jsonStr}\n[END_TOOL_RESULT]`;
  }

  /**
   * Sanitizes error message so no sensitive internal traces leak to Gemini or Admin
   */
  private sanitizeErrorMessage(err: any): string {
    const msg = err?.message || String(err);

    // If it's a known domain or validation error, preserve message
    if (
      msg.includes('Validation failed') ||
      msg.includes('Permission denied') ||
      msg.includes('WRITE tools are strictly disabled') ||
      msg.includes('timed out') ||
      msg.includes('not registered') ||
      msg.includes('required') ||
      msg.includes('not found') ||
      msg.includes('Invalid') ||
      msg.includes('CLIENT_NOT_FOUND') ||
      msg.includes('MULTIPLE_CLIENTS_FOUND') ||
      msg.includes('VALIDATION_ERROR')
    ) {
      return msg;
    }

    // Prisma and database errors: safe, useful domain error
    if (msg.includes('Prisma') || msg.includes('constraint') || msg.includes('database')) {
      if (msg.includes('Unique constraint failed')) {
        return 'A plan proposal with this title already exists in pending proposals.';
      }
      if (msg.includes('Foreign key constraint')) {
        return 'Referenced conversation or athlete record does not exist in the database.';
      }
      return 'Database operation failed while processing proposal.';
    }

    // Default safe fallback without server secrets or SQL
    return `Tool execution failed: ${msg.replace(/C:\\[^\s]+/g, '').substring(0, 150).trim() || 'Internal processing error'}`;
  }

  /**
   * Safe audit logging (never logs passwords, API keys, or raw JWTs)
   */
  private logAudit(entry: ToolAuditLogEntry): void {
    const timestamp = new Date().toISOString();
    console.log(
      `[ALPHA X AI TOOL AUDIT] [${timestamp}] RequestID=${entry.requestId} ConvID=${entry.conversationId} AdminID=${entry.adminId} Tool=${entry.toolName} Cat=${entry.category} Status=${entry.status} Latency=${entry.latencyMs}ms ${entry.errorMessage ? `Error=${entry.errorMessage}` : ''}`
    );
  }
}

export const toolExecutor = new ToolExecutor();
