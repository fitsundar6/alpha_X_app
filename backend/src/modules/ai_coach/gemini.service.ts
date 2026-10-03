import { GoogleGenAI } from '@google/genai';
import { env } from '../../config/environment';
import {
  buildAlphaXSystemPrompt,
  ALPHA_X_AI_PROMPT_VERSION,
  PromptContextSlots,
} from './prompts/system_prompt';
import { knowledgeService, knowledgeConfig } from './knowledge';
import { FormattedHistoryMessage, VerifiedClientContext } from './conversation';
import { clientContextService } from './conversation/client_context.service';
import {
  toolRegistry,
  toolExecutor,
  toolConfig,
  ToolExecutionContext,
} from './tools';

export interface GeminiChatOptions {
  message: string;
  adminId: string;
  requestId: string;
  conversationId?: string;
  model?: string;
  timeoutMs?: number;
  contextSlots?: PromptContextSlots;
  history?: FormattedHistoryMessage[];
  toolsEnabled?: boolean;
  verifiedClient?: VerifiedClientContext | null;
}

export interface GeminiChatResult {
  replyText: string;
  response: string;
  requestId: string;
  conversationId: string;
  model: string;
  promptVersion: string;
  latencyMs: number;
  intent: string;
  suggestedFollowUps: string[];
  knowledgeRetrievalEnabled: boolean;
  retrievedKnowledgeCount: number;
  retrievedKnowledgeIds: string[];
  toolsInvokedCount?: number;
  toolsInvokedNames?: string[];
  verifiedClient?: VerifiedClientContext | null;
}

export class GeminiService {
  public static readonly PROMPT_VERSION = ALPHA_X_AI_PROMPT_VERSION;
  public get promptVersion(): string {
    return GeminiService.PROMPT_VERSION;
  }
  private static readonly DEFAULT_MODEL = 'gemini-2.5-flash';
  private static readonly FALLBACK_MODEL = 'gemini-3.8-flash';
  private static readonly DEFAULT_TIMEOUT_MS = 30000;

  /**
   * Generates an AI response from Google Gemini with safety controls,
   * conservative fitness instructions, latency tracking, and timeout protection.
   */
  public async generateFitnessResponse(options: GeminiChatOptions): Promise<GeminiChatResult> {
    const {
      message,
      adminId,
      requestId,
      conversationId,
      contextSlots,
      history,
      timeoutMs = GeminiService.DEFAULT_TIMEOUT_MS,
      verifiedClient,
    } = options;
    const startTime = Date.now();
    const effectiveConvId = conversationId || `conv_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;

    // 1. Validate Input
    const cleanMessage = (message || '').trim();
    if (!cleanMessage) {
      this.logAudit({
        requestId,
        conversationId: effectiveConvId,
        adminId,
        status: 'FAILED',
        errorCategory: 'VALIDATION_ERROR',
        latencyMs: 0,
        message: 'Empty prompt rejected',
      });
      throw new Error('Message prompt cannot be empty');
    }

    // 2. Validate API Key
    const apiKey = env.GEMINI_API_KEY || process.env.GEMINI_API_KEY;
    if (!apiKey || !apiKey.trim()) {
      this.logAudit({
        requestId,
        conversationId: effectiveConvId,
        adminId,
        status: 'FAILED',
        errorCategory: 'MISSING_API_KEY',
        latencyMs: 0,
        message: 'GEMINI_API_KEY environment variable is not configured',
      });
      throw new Error('AI service is temporarily unavailable: GEMINI_API_KEY is not configured on the server.');
    }

    // 3. Knowledge Retrieval Layer (Phase 3 RAG) & Active Client Context (Phase 7)
    const effectiveSlots: PromptContextSlots = contextSlots ? { ...contextSlots } : {};
    let retrievedDocIds: string[] = [];
    let retrievedCount = 0;
    const isRAGEnabled = knowledgeConfig.isEnabled;

    if (isRAGEnabled && !effectiveSlots.knowledgeContext) {
      try {
        const searchResults = await knowledgeService.searchKnowledge(cleanMessage);
        if (searchResults.length > 0) {
          const formatted = knowledgeService.formatRetrievedKnowledge(searchResults);
          effectiveSlots.knowledgeContext = formatted.contextBlock;
          retrievedDocIds = formatted.documentIds;
          retrievedCount = formatted.retrievedCount;
        }
      } catch (ragErr: any) {
        // Safe degradation: if retrieval fails, proceed with base Gemini reasoning
        console.warn(`[KNOWLEDGE RAG NOTICE] [${requestId}]: Non-critical knowledge retrieval error: ${ragErr?.message}`);
      }
    }

    // Phase 7: Automatically inject active verified client context slot if available
    if (verifiedClient && !effectiveSlots.clientContext) {
      effectiveSlots.clientContext = clientContextService.formatActiveClientContextSlot(verifiedClient);
    }

    // 4. Initialize GoogleGenAI Client
    const ai = new GoogleGenAI({ apiKey: apiKey.trim() });
    const targetModel = options.model || GeminiService.DEFAULT_MODEL;
    const executionContext: ToolExecutionContext = {
      adminId,
      requestId,
      conversationId: effectiveConvId,
      verifiedClient: verifiedClient || null,
    };

    // 5. Execute with Timeout & Fallback (passing multi-turn history & tool execution context)
    try {
      const response = await this.executeWithTimeout(
        ai,
        targetModel,
        cleanMessage,
        timeoutMs,
        effectiveSlots,
        history,
        executionContext,
        options.toolsEnabled !== false
      );

      const latencyMs = Date.now() - startTime;
      const text = response.text || '';

      this.logAudit({
        requestId,
        conversationId: effectiveConvId,
        adminId,
        status: 'SUCCESS',
        model: targetModel,
        promptVersion: ALPHA_X_AI_PROMPT_VERSION,
        knowledgeRetrievalEnabled: isRAGEnabled,
        retrievedKnowledgeIds: retrievedDocIds,
        retrievalCount: retrievedCount,
        toolsInvokedCount: response.toolsInvokedCount,
        toolsInvokedNames: response.toolsInvokedNames,
        latencyMs,
        responseLength: text.length,
      });

      return {
        replyText: text,
        response: text,
        requestId,
        conversationId: effectiveConvId,
        model: targetModel,
        promptVersion: ALPHA_X_AI_PROMPT_VERSION,
        latencyMs,
        intent: 'FITNESS_QUERY',
        suggestedFollowUps: [
          'What is RIR and how is it useful?',
          'Explain progressive overload for beginners',
          'How much protein should an athlete consume daily?',
        ],
        knowledgeRetrievalEnabled: isRAGEnabled,
        retrievedKnowledgeCount: retrievedCount,
        retrievedKnowledgeIds: retrievedDocIds,
        toolsInvokedCount: response.toolsInvokedCount,
        toolsInvokedNames: response.toolsInvokedNames,
        verifiedClient: verifiedClient || null,
      };
    } catch (err: any) {
      const latencyMs = Date.now() - startTime;
      const errorMsg = err?.message || String(err);
      // ── TEMP DEBUG: log real Gemini error ─────────────────────────────────
      console.error('[GEMINI RAW ERROR]', errorMsg);
      // ─────────────────────────────────────────────────────────────────────
      const isTimeout = errorMsg.includes('timed out');
      const isAuthError = errorMsg.includes('API key not valid') || errorMsg.includes('403') || errorMsg.includes('400');
      const isRateLimit = errorMsg.includes('429') || errorMsg.includes('RESOURCE_EXHAUSTED');
      const isModelError = errorMsg.includes('404') || errorMsg.includes('no longer available') || errorMsg.includes('NOT_FOUND');


      let errorCategory = 'GEMINI_API_ERROR';
      let clientFacingMessage = 'AI service is temporarily unavailable. Please try again shortly.';

      if (isTimeout) {
        errorCategory = 'TIMEOUT';
        clientFacingMessage = 'AI service request timed out after 15 seconds. Please try again.';
      } else if (isAuthError) {
        errorCategory = 'AUTHENTICATION_ERROR';
        clientFacingMessage = 'AI service authentication failed. Please verify server API key configuration.';
      } else if (isRateLimit) {
        errorCategory = 'RATE_LIMIT_EXCEEDED';
        clientFacingMessage = 'Gemini API rate limit reached. Please wait a moment before trying again.';
      }

      this.logAudit({
        requestId,
        conversationId: effectiveConvId,
        adminId,
        status: 'FAILED',
        errorCategory,
        promptVersion: ALPHA_X_AI_PROMPT_VERSION,
        knowledgeRetrievalEnabled: isRAGEnabled,
        retrievedKnowledgeIds: retrievedDocIds,
        retrievalCount: retrievedCount,
        latencyMs,
        message: errorCategory,
      });

      // Never leak internal stack trace, API keys, or raw system URLs to client
      throw new Error(clientFacingMessage);
    }
  }

  /**
   * Executes Gemini call with race timeout, multi-turn history, and secure tool execution loop
   */
  private async executeWithTimeout(
    ai: GoogleGenAI,
    modelName: string,
    prompt: string,
    timeoutMs: number,
    contextSlots?: PromptContextSlots,
    history?: FormattedHistoryMessage[],
    context?: ToolExecutionContext,
    toolsEnabled: boolean = true
  ): Promise<{ text: string; toolsInvokedCount: number; toolsInvokedNames: string[] }> {
    let timeoutHandle: NodeJS.Timeout;

    const timeoutPromise = new Promise<{ text: string; toolsInvokedCount: number; toolsInvokedNames: string[] }>((_, reject) => {
      timeoutHandle = setTimeout(() => {
        reject(new Error(`Gemini API request timed out after ${timeoutMs}ms`));
      }, timeoutMs);
    });

    const systemInstruction = buildAlphaXSystemPrompt(contextSlots);
    const toolDeclarations = toolsEnabled ? toolRegistry.getGeminiDeclarations() : [];
    const toolsConfig = toolDeclarations.length > 0 ? [{ functionDeclarations: toolDeclarations }] : undefined;

    // Prepare structured multi-turn payload
    let contentsPayload: any[];
    if (history && history.length > 0) {
      contentsPayload = [
        ...history.map((h) => ({
          role: h.role === 'assistant' ? 'model' : 'user',
          parts: [{ text: h.content }],
        })),
        {
          role: 'user',
          parts: [{ text: prompt }],
        },
      ];
    } else {
      contentsPayload = [
        {
          role: 'user',
          parts: [{ text: prompt }],
        },
      ];
    }

    const toolsInvokedNames: string[] = [];
    let toolCallsExecuted = 0;

    const callPromise = (async () => {
      console.log(`[DEBUG GEMINI] Gemini request: convId="${context?.conversationId || 'none'}", model="${modelName}", prompt="${prompt.substring(0, 100)}"`);
      let currentResponse = await this.callModelWithFallback(
        ai,
        modelName,
        contentsPayload,
        systemInstruction,
        toolsConfig
      );

      // Handle function calls loop if model requested any tool
      const maxCalls = toolConfig.maxToolCallsPerRequest;
      while (
        currentResponse?.functionCalls &&
        currentResponse.functionCalls.length > 0 &&
        toolCallsExecuted < maxCalls &&
        context
      ) {
        for (const call of currentResponse.functionCalls) {
          if (toolCallsExecuted >= maxCalls) {
            break;
          }

          toolCallsExecuted++;
          toolsInvokedNames.push(call.name);
          console.log(`[DEBUG GEMINI] Selected tool: ${call.name}, args: ${JSON.stringify(call.args)}`);

          // Execute tool securely through ToolExecutor
          const toolResult = await toolExecutor.executeTool(call.name, call.args, context);
          console.log(`[DEBUG GEMINI] Tool result for ${call.name}: success=${toolResult.success}, hasData=${toolResult.data !== undefined}`);

          // Append model turn with functionCall
          contentsPayload.push({
            role: 'model',
            parts: [
              {
                functionCall: {
                  name: call.name,
                  args: call.args || {},
                },
              },
            ],
          });

          // Append tool response
          contentsPayload.push({
            role: 'tool',
            parts: [
              {
                functionResponse: {
                  name: call.name,
                  response: {
                    output: toolResult.data !== undefined ? toolResult.data : { error: toolResult.error },
                  },
                },
              },
            ],
          });
        }

        // Call model with tool responses to generate final synthesis
        currentResponse = await this.callModelWithFallback(
          ai,
          modelName,
          contentsPayload,
          systemInstruction,
          toolsConfig
        );
      }

      console.log(`[DEBUG GEMINI] Gemini final response: toolsCount=${toolsInvokedNames.length}, length=${(currentResponse?.text || '').length}, preview="${(currentResponse?.text || '').substring(0, 100)}..."`);
      return {
        text: currentResponse?.text || '',
        toolsInvokedCount: toolsInvokedNames.length,
        toolsInvokedNames,
      };
    })();

    try {
      const result = await Promise.race([callPromise, timeoutPromise]);
      clearTimeout(timeoutHandle!);
      return result;
    } finally {
      clearTimeout(timeoutHandle!);
    }
  }

  /**
   * Helper that calls Gemini generateContent with fallback from 2.5-flash to 1.5-flash
   */
  private async callModelWithFallback(
    ai: GoogleGenAI,
    modelName: string,
    contents: any,
    systemInstruction: string,
    toolsConfig?: any
  ): Promise<any> {
    const config: any = {
      systemInstruction,
      temperature: 0.3,
    };
    if (toolsConfig) {
      config.tools = toolsConfig;
    }

    try {
      return await ai.models.generateContent({
        model: modelName,
        contents,
        config,
      });
    } catch (firstErr: any) {
      // If primary model fails with not found / 404, fallback to 1.5-flash
      if (modelName !== GeminiService.FALLBACK_MODEL && firstErr?.message?.includes('not found')) {
        console.warn(`[GEMINI SERVICE] Primary model ${modelName} unavailable, falling back to ${GeminiService.FALLBACK_MODEL}`);
        return await ai.models.generateContent({
          model: GeminiService.FALLBACK_MODEL,
          contents,
          config,
        });
      }
      throw firstErr;
    }
  }

  /**
   * Safe backend logging that never leaks API keys, secrets, or passwords
   */
  private logAudit(meta: {
    requestId: string;
    conversationId?: string;
    adminId: string;
    status: 'SUCCESS' | 'FAILED';
    model?: string;
    promptVersion?: string;
    knowledgeRetrievalEnabled?: boolean;
    retrievedKnowledgeIds?: string[];
    retrievalCount?: number;
    toolsInvokedCount?: number;
    toolsInvokedNames?: string[];
    errorCategory?: string;
    latencyMs: number;
    responseLength?: number;
    message?: string;
  }): void {
    const timestamp = new Date().toISOString();
    const ragLog = meta.knowledgeRetrievalEnabled !== undefined
      ? ` RAGEnabled=${meta.knowledgeRetrievalEnabled} RAGCount=${meta.retrievalCount ?? 0} RAGIds=[${(meta.retrievedKnowledgeIds || []).join(',')}]`
      : '';
    const convLog = meta.conversationId ? ` ConvID=${meta.conversationId}` : '';
    console.log(
      `[ALPHA X AI AUDIT] [${timestamp}] RequestID=${meta.requestId}${convLog} AdminID=${meta.adminId} Status=${meta.status} Latency=${meta.latencyMs}ms ${meta.model ? 'Model=' + meta.model : ''}${meta.promptVersion ? ' PromptVer=' + meta.promptVersion : ''}${ragLog} ${meta.errorCategory ? 'ErrorCategory=' + meta.errorCategory : ''}`
    );
  }
}

export const geminiService = new GeminiService();
