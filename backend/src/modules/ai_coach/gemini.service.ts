import { GoogleGenAI } from '@google/genai';
import { geminiReliability, classifyGeminiError, redactSecrets } from './gemini.reliability';
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
  PROPOSAL_TOOL_NAMES,
  ToolExecutionContext,
} from './tools';
import { prisma } from '../../config/prisma';
import { env } from '../../config/environment';

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
  proposal?: any;
}

/**
 * Safely extracts concatenated text from a raw Gemini SDK response WITHOUT
 * triggering the SDK's internal ".text" getter warning:
 *   "there are non-text parts functionCall in the response,
 *    returning concatenation of all text parts..."
 *
 * The SDK emits this warning whenever response.text is accessed and the
 * candidate contains function-call parts alongside text parts.  By reading
 * candidates[0].content.parts directly we avoid the getter entirely.
 */
function extractResponseText(response: any): string {
  if (!response?.candidates?.[0]?.content?.parts) {
    return '';
  }
  let text = '';
  for (const part of response.candidates[0].content.parts) {
    // Skip thought / reasoning parts emitted by flash-thinking models
    if (typeof part.thought === 'boolean' && part.thought) continue;
    if (typeof part.text === 'string') {
      text += part.text;
    }
  }
  return text;
}

/**
 * Checks whether a raw Gemini SDK response still carries pending function
 * calls — without touching response.text (which triggers the SDK warning).
 */
function hasFunctionCallParts(response: any): boolean {
  const parts: any[] = response?.candidates?.[0]?.content?.parts ?? [];
  return parts.some((p: any) => p && typeof p === 'object' && 'functionCall' in p && p.functionCall);
}

export class GeminiService {
  public static readonly PROMPT_VERSION = ALPHA_X_AI_PROMPT_VERSION;
  public get promptVersion(): string {
    return GeminiService.PROMPT_VERSION;
  }
  // Primary: gemini-3.5-flash (fast GA workhorse, active free quota, supports tool calling)
  // Fallbacks: gemini-flash-latest, gemini-flash-lite-latest, gemini-3.8-flash
  public static get DEFAULT_MODEL(): string {
    return (env.GEMINI_MODEL || process.env.GEMINI_MODEL || 'gemini-3.5-flash').trim();
  }
  public static get FALLBACK_MODELS(): string[] {
    const primary = GeminiService.DEFAULT_MODEL;
    const candidates = [
      'gemini-3.5-flash',
      'gemini-flash-latest',
      'gemini-flash-lite-latest',
      'gemini-3.8-flash',
    ];
    return candidates.filter((m) => m !== primary);
  }
  private static readonly MAX_RETRIES = 3;
  private static readonly DEFAULT_TIMEOUT_MS = 45000;

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

    // 2. Validate API Key & Circuit Breaker State (Safe in-memory resolution, zero disk I/O on Vercel)
    if (!geminiReliability.hasConfiguredKey()) {
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

    if (geminiReliability.isCircuitTripped()) {
      const remainingSec = geminiReliability.getCircuitCooldownRemainingSeconds();
      this.logAudit({
        requestId,
        conversationId: effectiveConvId,
        adminId,
        status: 'FAILED',
        errorCategory: 'AUTHENTICATION_ERROR',
        latencyMs: 0,
        message: 'Circuit breaker active: invalid API credentials',
      });
      throw new Error(
        `AI service authentication is temporarily suspended due to recent invalid credentials (${remainingSec}s remaining). Server in degraded safe mode.`
      );
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

    // 4. Target Model & Execution Context
    const targetModel = options.model || GeminiService.DEFAULT_MODEL;
    const executionContext: ToolExecutionContext = {
      adminId,
      requestId,
      conversationId: effectiveConvId,
      verifiedClient: verifiedClient || null,
    };

    // 5. Execute with Bounded Retries, Jitter & Safe Backup Failover
    try {
      const response = await geminiReliability.executeWithReliability(
        async (ai) => {
          return this.executeWithTimeout(
            ai,
            targetModel,
            cleanMessage,
            timeoutMs,
            effectiveSlots,
            history,
            executionContext,
            options.toolsEnabled !== false
          );
        },
        {
          operationName: `GeminiChat_${requestId}`,
          maxRetries: GeminiService.MAX_RETRIES,
        }
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
        intent: response.proposal ? (response.proposal.type === 'DIET' ? 'DIET_PROPOSAL' : 'WORKOUT_PROPOSAL') : 'FITNESS_QUERY',
        proposal: response.proposal || null,
        suggestedFollowUps: response.proposal
          ? ['Review this proposal', 'Edit target exercises', 'Show clients needing review']
          : [
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
      const classified = classifyGeminiError(err);
      const isTimeout = classified.sanitizedMessage.includes('timed out');

      let errorCategory = classified.category as string;
      let clientFacingMessage = 'AI service is temporarily unavailable. Please try again shortly.';

      if (isTimeout) {
        errorCategory = 'TIMEOUT';
        clientFacingMessage = 'AI service request timed out. Please try again.';
      } else if (classified.isAuth) {
        errorCategory = 'AUTHENTICATION_ERROR';
        clientFacingMessage = 'AI service authentication failed. Please verify server API key configuration.';
      } else if (classified.isQuota || classified.isRateLimit) {
        errorCategory = 'RATE_LIMIT_EXCEEDED';
        clientFacingMessage = 'Gemini is experiencing high demand. Please wait a moment and try again.';
      } else if (classified.isModelError) {
        errorCategory = 'MODEL_ERROR';
        clientFacingMessage = `AI model configuration error: ${classified.sanitizedMessage.substring(0, 120)}`;
      } else {
        errorCategory = 'GEMINI_API_ERROR';
        clientFacingMessage = `AI service error: ${classified.sanitizedMessage.substring(0, 150)}`;
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
  ): Promise<{ text: string; toolsInvokedCount: number; toolsInvokedNames: string[]; proposal?: any }> {
    let timeoutHandle: NodeJS.Timeout;

    const timeoutPromise = new Promise<{ text: string; toolsInvokedCount: number; toolsInvokedNames: string[]; proposal?: any }>((_, reject) => {
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
    let executedProposal: any = null;
    let lastProposalError: string | null = null;

    const callPromise = (async () => {
      console.log(`[DEBUG GEMINI] Gemini request: convId="${context?.conversationId || 'none'}", model="${modelName}", prompt="${prompt.substring(0, 100)}"`);
      let currentResponse = await this.callModelWithFallback(
        ai,
        modelName,
        contentsPayload,
        systemInstruction,
        toolsConfig
      );

      // ── Tool-call execution loop ──────────────────────────────────────────────
      // Use hasFunctionCallParts() instead of currentResponse?.functionCalls
      // to avoid triggering the SDK ".text" getter warning:
      //   "there are non-text parts functionCall in the response, returning
      //    concatenation of all text parts."
      // The SDK emits that warning from its .text getter, not from .functionCalls,
      // but using our own part-level inspection keeps the code consistent and safe.
      const maxCalls = toolConfig.maxToolCallsPerRequest;
      const hardMaxCalls = maxCalls + 2; // Absolute safety ceiling to strictly prevent infinite looping

      while (hasFunctionCallParts(currentResponse) && context && toolCallsExecuted < hardMaxCalls) {
        // Once a proposal has been successfully executed, exit the tool loop immediately
        if (executedProposal) {
          break;
        }
        // Extract raw function-call parts so we never touch the SDK's .text getter
        const rawParts: any[] = currentResponse?.candidates?.[0]?.content?.parts ?? [];
        const fcParts = rawParts.filter((p: any) => p && 'functionCall' in p && p.functionCall);

        // If we have hit the call cap AND none of the pending function calls are
        // proposal tools (which must always be allowed to complete), exit the loop.
        const pendingProposalCalls = fcParts.filter((p: any) => PROPOSAL_TOOL_NAMES.has(p.functionCall?.name));
        if (toolCallsExecuted >= maxCalls && pendingProposalCalls.length === 0) {
          break;
        }

        // Push the full model turn (preserving thought_signature if present)
        if (currentResponse?.candidates?.[0]?.content) {
          contentsPayload.push(currentResponse.candidates[0].content);
        } else {
          contentsPayload.push({
            role: 'model',
            parts: fcParts.map((p: any) => ({
              functionCall: { name: p.functionCall.name, args: p.functionCall.args || {} },
            })),
          });
        }

        const functionResponseParts: any[] = [];

        for (const part of fcParts) {
          const call = part.functionCall as { name: string; args: any };

          if (toolCallsExecuted >= maxCalls) {
            // Proposal tools MUST NOT be blocked by the soft cap — they are the
            // terminal step in the entire tool chain.  If Gemini has decided to
            // invoke propose_workout_plan or propose_diet_plan, blocking it here
            // causes a text-only fallback with zero database persistence.
            // Non-proposal tools are still capped normally.
            if (!PROPOSAL_TOOL_NAMES.has(call.name)) {
              functionResponseParts.push({
                functionResponse: {
                  name: call.name,
                  response: { output: { notice: 'Maximum tool call depth reached.' } },
                },
              });
              continue;
            }
            // Proposal tool — fall through to execute despite the soft cap.
            console.log(`[DEBUG GEMINI] Proposal tool '${call.name}' bypassing soft cap (${toolCallsExecuted}/${maxCalls}).`);
          }

          toolCallsExecuted++;
          toolsInvokedNames.push(call.name);
          console.log(`[DEBUG GEMINI] Selected tool: ${call.name}, args: ${JSON.stringify(call.args)}`);

          // Execute tool securely through ToolExecutor
          const toolResult = await toolExecutor.executeTool(call.name, call.args, context);
          console.log(
            `[DEBUG GEMINI] Tool result for ${call.name}: ` +
            `executorSuccess=${toolResult.success}, toolSuccess=${toolResult.data?.success}, ` +
            `hasProposal=${!!toolResult.data?.proposal}, hasProposalId=${!!toolResult.data?.proposalId}`
          );

          if (call.name === 'propose_workout_plan' || call.name === 'propose_diet_plan') {
            // Success path: executor succeeded AND tool itself succeeded
            if (toolResult.success && toolResult.data?.success !== false) {
              if (toolResult.data?.proposal) {
                executedProposal = toolResult.data.proposal;
                console.log(`[DEBUG GEMINI] Captured proposal from tool result: id=${executedProposal.id}, type=${executedProposal.type}`);
              } else if (toolResult.data?.proposalId) {
                // Fetch full proposal from DB when tool only returned the ID
                try {
                  const propDb = await prisma.aIProposal.findUnique({ where: { id: toolResult.data.proposalId } });
                  if (propDb) {
                    let proposedData: any = {};
                    const rawPayload = propDb.finalDataJson || propDb.proposedDataJson;
                    if (typeof rawPayload === 'object' && rawPayload !== null) {
                      proposedData = rawPayload;
                    } else if (typeof rawPayload === 'string') {
                      try { proposedData = JSON.parse(rawPayload); } catch {}
                    }
                    executedProposal = {
                      id: propDb.id,
                      clientId: propDb.clientId || propDb.clientProfileId,
                      clientName: propDb.clientName,
                      type: propDb.proposalType,
                      title: propDb.title,
                      summary: propDb.summary,
                      reason: propDb.reason,
                      status: propDb.status,
                      payload: proposedData,
                      proposedData,
                    };
                    console.log(`[DEBUG GEMINI] Fetched proposal from DB: id=${executedProposal.id}`);
                  }
                } catch (dbFetchErr) {
                  console.warn(`[DEBUG GEMINI] Could not fetch proposal from DB: ${dbFetchErr}`);
                }
              }
            } else {
              // Tool failed (validation, client-not-found, split error, etc.)
              lastProposalError = toolResult.error || toolResult.data?.message || 'Proposal validation or database error';
              console.warn(`[DEBUG GEMINI] Proposal tool failed: ${lastProposalError}`);
            }
          }

          functionResponseParts.push({
            functionResponse: {
              name: call.name,
              response: {
                output: toolResult.data !== undefined ? toolResult.data : { error: toolResult.error },
              },
            },
          });
        }

        // Append all tool responses in a single user turn
        contentsPayload.push({ role: 'user', parts: functionResponseParts });

        // After a successful proposal is captured, disable further tool calls so Gemini
        // summarises rather than looping into another proposal attempt.
        const nextToolsConfig = (toolCallsExecuted < maxCalls && !executedProposal) ? toolsConfig : undefined;
        currentResponse = await this.callModelWithFallback(
          ai,
          modelName,
          contentsPayload,
          systemInstruction,
          nextToolsConfig
        );
      }

      const pendingText = extractResponseText(currentResponse);

      // Cap: if the loop exited due to hitting maxCalls and Gemini still has pending
      // function-call parts without producing a text reply, force a final text synthesis.
      if (hasFunctionCallParts(currentResponse) && (!pendingText || pendingText.trim().length === 0)) {
        if (currentResponse?.candidates?.[0]?.content) {
          contentsPayload.push(currentResponse.candidates[0].content);
        }
        const capParts: any[] = currentResponse?.candidates?.[0]?.content?.parts ?? [];
        const capResponses = capParts
          .filter((p: any) => p && 'functionCall' in p && p.functionCall)
          .map((p: any) => ({
            functionResponse: {
              name: p.functionCall.name,
              response: { output: { notice: 'Tool call cap reached. Please provide final answer using gathered data.' } },
            },
          }));
        if (capResponses.length > 0) {
          contentsPayload.push({ role: 'user', parts: capResponses });
          currentResponse = await this.callModelWithFallback(
            ai,
            modelName,
            contentsPayload,
            systemInstruction,
            undefined
          );
        }
      }

      let finalText = extractResponseText(currentResponse);

      if (executedProposal) {
        if (!finalText || finalText.trim().length === 0) {
          if (executedProposal.type === 'WORKOUT' || toolsInvokedNames.includes('propose_workout_plan')) {
            finalText = `Workout proposal created successfully for ${executedProposal.clientName || 'athlete'} (${executedProposal.clientId || 'AXG'}). Staged as PENDING in Workout Proposals for admin review.`;
          } else if (executedProposal.type === 'DIET' || toolsInvokedNames.includes('propose_diet_plan')) {
            const isMacroOnly = executedProposal.payload?.planKind === 'MACRO_ONLY' || executedProposal.payload?.isMacroOnly;
            const planLabel = isMacroOnly ? 'Macro-only proposal' : 'Diet plan proposal with structured meals';
            finalText = `${planLabel} created successfully for ${executedProposal.clientName || 'athlete'} (${executedProposal.clientId || 'AXG'}). Staged as PENDING in Admin Review.`;
          }
        }
      } else {
        if (!finalText || finalText.trim().length === 0) {
          if (toolsInvokedNames.includes('propose_workout_plan')) {
            finalText = `Failed to create workout proposal: ${lastProposalError || 'The plan was not saved to the database.'} Please verify the client identity and retry.`;
          } else if (toolsInvokedNames.includes('propose_diet_plan')) {
            finalText = `Failed to create diet proposal: ${lastProposalError || 'The plan was not saved to the database.'} Please address the missing required details (such as meal items and quantities) and retry.`;
          }
        }
      }

      console.log(`[DEBUG GEMINI] Gemini final response: toolsCount=${toolsInvokedNames.length}, length=${finalText.length}, preview="${finalText.substring(0, 100)}..."`);
      return {
        text: finalText,
        toolsInvokedCount: toolsInvokedNames.length,
        toolsInvokedNames,
        proposal: executedProposal,
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
   * Helper that calls Gemini generateContent with fallback across resilient models
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

    const candidateModels = [
      modelName,
      ...GeminiService.FALLBACK_MODELS.filter((m) => m !== modelName),
    ];

    let lastErr: any;
    for (const currentModel of candidateModels) {
      try {
        return await ai.models.generateContent({
          model: currentModel,
          contents,
          config,
        });
      } catch (err: any) {
        lastErr = err;
        const classified = classifyGeminiError(err);
        if (classified.isAuth || classified.isQuota) {
          console.warn(`[GEMINI SERVICE] Authentication / Quota failure with model ${currentModel}: ${classified.sanitizedMessage.substring(0, 100)}. Skipping remaining fallback models.`);
          throw err;
        }
        console.warn(`[GEMINI SERVICE] Model ${currentModel} failed (${classified.sanitizedMessage.substring(0, 80)}), trying fallback...`);
      }
    }
    throw lastErr;
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
      redactSecrets(
        `[ALPHA X AI AUDIT] [${timestamp}] RequestID=${meta.requestId}${convLog} AdminID=${meta.adminId} Status=${meta.status} Latency=${meta.latencyMs}ms ${meta.model ? 'Model=' + meta.model : ''}${meta.promptVersion ? ' PromptVer=' + meta.promptVersion : ''}${ragLog} ${meta.errorCategory ? 'ErrorCategory=' + meta.errorCategory : ''}`
      )
    );
  }
}

export const geminiService = new GeminiService();
