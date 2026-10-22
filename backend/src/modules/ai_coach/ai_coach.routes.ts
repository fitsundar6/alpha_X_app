import { Router, Request, Response } from 'express';
import { requireAuth, requireAdmin } from '../../middlewares/auth';
import { geminiService } from './gemini.service';
import { geminiReliability } from './gemini.reliability';
import { aiController } from './ai_controller';
import { aiTools } from './ai_tools';
import { conversationService, conversationStore, clientContextService } from './conversation';
import { toolRegistry } from './tools';
import { prisma } from '../../config/prisma';
import { HttpStatus } from '../../constants/httpStatus';
import { sendSuccess, sendError } from '../../utils/responseEnvelope';
import { env } from '../../config/environment';
import { clientSummaryService } from './client_summary.service';
import { workoutIntentService } from './workout_intent.service';
import { proposeWorkoutPlanTool } from './tools/definitions/client/propose_workout_plan';
import { proposeDietPlanTool } from './tools/definitions/client/propose_diet_plan';
import { clientDataService } from './tools/definitions/client/client_data.service';
import { calculatePersonalizedDietMacros } from './diet_calculator';

const router = Router();

const defaultAdminId = env.ADMIN_ID || `admin_${(env.ADMIN_EMAIL || 'alphax').split('@')[0].replace(/[^a-zA-Z0-9_]/g, '_')}`.toLowerCase();

// Enforce Admin Authentication on all AI Coach routes
router.use(requireAuth, requireAdmin);

/**
 * POST /api/v1/admin/ai-coach/chat
 * Also accessible via /api/ai/chat and /api/v1/ai/chat.
 * Primary natural language chat interface powered by Google Gemini AI with multi-turn conversation and client context support.
 */
router.post('/chat', async (req: Request, res: Response) => {
  const { message, conversationId, selectedClientId, clearClient } = req.body;

  // 1. Validation: Message cannot be empty or exceed length limits
  let cleanMessage: string;
  try {
    cleanMessage = conversationService.validateMessage(message);
  } catch (valErr: any) {
    sendError(res, 'VALIDATION_ERROR', valErr.message || 'Prompt message cannot be empty', HttpStatus.BAD_REQUEST);
    return;
  }

  const adminUser = (req as any).user || {};
  const adminId = adminUser.id || defaultAdminId;
  const requestId = `req_ai_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;

  // 2. Resolve or initialize isolated conversation for the authenticated Admin
  const { conversation } = conversationService.resolveConversation(adminId, conversationId);

  console.log(`[DEBUG CHAT] Incoming user message: "${cleanMessage}", conversationId: "${conversation.id}", selectedClientId: "${selectedClientId || 'none'}"`);

  // 3. Handle explicit clearClient request
  if (clearClient === true) {
    clientContextService.clearClient(conversation);
  }

  // 4. Handle explicit selectedClientId parameter
  if (selectedClientId && typeof selectedClientId === 'string' && selectedClientId.trim().length > 0) {
    const selResult = await clientContextService.resolveAndSetClient(conversation, selectedClientId.trim());
    if (selResult.status === 'AMBIGUOUS') {
      sendSuccess(res, {
        status: 'MULTIPLE_CLIENTS_FOUND',
        response: `I found multiple clients matching "${selectedClientId}". Please provide the AXG ID to select the correct client.`,
        replyText: `I found multiple clients matching "${selectedClientId}". Please provide the AXG ID to select the correct client.`,
        conversationId: conversation.id,
        verifiedClient: conversation.verifiedClient || null,
        candidates: selResult.candidates,
      }, HttpStatus.OK);
      return;
    }
  }

  // 5. Detect client intent from natural language message
  const clientIntent = clientContextService.detectClientIntent(cleanMessage, conversation.verifiedClient || null);

  if (clientIntent.type === 'CLEAR') {
    clientContextService.clearClient(conversation);
    const ack = 'Client context has been cleared. No client is currently selected.';
    conversationService.recordExchange(conversation, cleanMessage, ack);
    sendSuccess(res, {
      conversationId: conversation.id,
      response: ack,
      replyText: ack,
      requestId,
      intent: 'CLIENT_CLEARED',
      verifiedClient: null,
    }, HttpStatus.OK);
    return;
  }

  if (clientIntent.type === 'SELECT' || clientIntent.type === 'SWITCH') {
    const resolveRes = await clientContextService.resolveAndSetClient(conversation, clientIntent.targetReference || clientIntent.targetIdentifier || '');

    if (resolveRes.status === 'AMBIGUOUS') {
      const reply = `I found multiple clients matching "${clientIntent.targetReference || clientIntent.targetIdentifier}". Please provide the AXG client ID or more specific details to select the correct client.`;
      conversationService.recordExchange(conversation, cleanMessage, reply);
      sendSuccess(res, {
        conversationId: conversation.id,
        response: reply,
        replyText: reply,
        requestId,
        intent: 'MULTIPLE_CLIENTS_FOUND',
        status: 'MULTIPLE_CLIENTS_FOUND',
        candidates: resolveRes.candidates || resolveRes.matches,
        verifiedClient: conversation.verifiedClient || null,
      }, HttpStatus.OK);
      return;
    }

    if (resolveRes.status === 'NOT_FOUND') {
      const reply = `I could not find any client matching "${clientIntent.targetReference || clientIntent.targetIdentifier}" in Alpha X Gym records. Please check the name or AXG ID.`;
      conversationService.recordExchange(conversation, cleanMessage, reply);
      sendSuccess(res, {
        conversationId: conversation.id,
        response: reply,
        replyText: reply,
        requestId,
        intent: 'CLIENT_NOT_FOUND',
        status: 'CLIENT_NOT_FOUND',
        verifiedClient: conversation.verifiedClient || null,
      }, HttpStatus.OK);
      return;
    }

    // If message is purely a select or switch declaration without further inquiry
    const hasFitnessQuery = /(weight|workout|nutrition|diet|calories|protein|checkin|steps|history|goal|record|progress|injury|pain|sleep|adherence)/i.test(cleanMessage);
    if (resolveRes.client && !hasFitnessQuery) {
      const isSwitch = clientIntent.type === 'SWITCH';
      const ack = isSwitch
        ? `Switched client context to ${resolveRes.client.displayName} (${resolveRes.client.clientId}). I am ready to review their records.`
        : `Understood. I am now working with ${resolveRes.client.displayName} (${resolveRes.client.clientId}). How can I assist you with this client?`;
      conversationService.recordExchange(conversation, cleanMessage, ack);
      sendSuccess(res, {
        conversationId: conversation.id,
        response: ack,
        replyText: ack,
        requestId,
        intent: isSwitch ? 'CLIENT_SWITCHED' : 'CLIENT_SELECTED',
        status: 'VERIFIED',
        verifiedClient: resolveRes.client,
      }, HttpStatus.OK);
      return;
    }
  }

  // 6. If message contains pronouns but no client is verified, prompt for identification
  if (clientIntent.type === 'PRONOUN_QUERY' && !conversation.verifiedClient) {
    const reply = 'No client is currently selected in this conversation. Please specify which client you would like to review (by name or AXG ID).';
    conversationService.recordExchange(conversation, cleanMessage, reply);
    console.log(`[DEBUG CHAT] Final response returned to frontend: [ConvID: ${conversation.id}] "${reply}"`);
    sendSuccess(res, {
      conversationId: conversation.id,
      response: reply,
      replyText: reply,
      requestId,
      intent: 'CLIENT_IDENTIFICATION_REQUIRED',
      verifiedClient: null,
    }, HttpStatus.OK);
    return;
  }

  // 7. Extract bounded multi-turn conversation history
  const history = conversationService.getRecentHistory(conversation);

  // 8. Call Google Gemini Foundation Model if configured and not circuit-tripped
  if (geminiReliability.hasConfiguredKey() && !geminiReliability.isCircuitTripped()) {
    try {
      const geminiResult = await geminiService.generateFitnessResponse({
        message: cleanMessage,
        adminId,
        requestId,
        conversationId: conversation.id,
        history,
        verifiedClient: conversation.verifiedClient || null,
      });

      // 9. Record exchange in conversation store with verifiedClient metadata
      conversationService.recordExchange(conversation, cleanMessage, geminiResult.replyText, {
        model: geminiResult.model,
        promptVersion: geminiResult.promptVersion,
        latencyMs: geminiResult.latencyMs,
        verifiedClient: conversation.verifiedClient || null,
      });

      console.log(`[DEBUG CHAT] Final response returned to frontend: [ConvID: ${conversation.id}] "${geminiResult.replyText.substring(0, 100)}..."`);
      sendSuccess(res, {
        conversationId: geminiResult.conversationId,
        response: geminiResult.response,
        replyText: geminiResult.replyText,
        requestId: geminiResult.requestId,
        model: geminiResult.model,
        promptVersion: geminiResult.promptVersion,
        intent: geminiResult.proposal
          ? (geminiResult.proposal.type === 'DIET' ? 'DIET_PROPOSAL' : 'WORKOUT_PROPOSAL')
          : geminiResult.intent,
        proposal: geminiResult.proposal || null,
        suggestedFollowUps: geminiResult.suggestedFollowUps,
        knowledgeRetrievalEnabled: geminiResult.knowledgeRetrievalEnabled,
        retrievedKnowledgeCount: geminiResult.retrievedKnowledgeCount,
        retrievedKnowledgeIds: geminiResult.retrievedKnowledgeIds,
        toolsInvokedCount: geminiResult.toolsInvokedCount || 0,
        toolsInvokedNames: geminiResult.toolsInvokedNames || [],
        verifiedClient: conversation.verifiedClient || null,
      }, HttpStatus.OK);
      return;
    } catch (err: any) {
      const errMsg = err.message || String(err);
      const isAuthError = errMsg.includes('401') || errMsg.includes('authentication') || errMsg.includes('API key');
      console.error(`[GEMINI SERVICE NOTICE] [${requestId}]:`, errMsg);

      console.log(`[DEBUG CHAT] Final response returned to frontend: [ConvID: ${conversation.id}] (HTTP 503 ERROR) "${errMsg}"`);
      sendError(
        res,
        isAuthError ? 'AI_AUTHENTICATION_ERROR' : 'AI_SERVICE_UNAVAILABLE',
        errMsg || 'AI service is temporarily unavailable.',
        HttpStatus.SERVICE_UNAVAILABLE,
        undefined,
        err,
        {
          activity: 'AI Coach Natural Language Query',
          explanation: isAuthError
            ? 'Google Gemini API rejected authentication credentials. Verify GEMINI_API_KEY in server environment.'
            : 'External AI reasoning model execution encountered an error.',
          receivedPayload: { message: cleanMessage, conversationId: conversation.id },
        }
      );
      return;
    }
  }

  // 10. If Gemini API Key is missing, attempt database-backed response via AiController
  try {
    const fallbackResult = await aiController.handleAdminMessage({
      adminId,
      adminName: adminUser.name || 'Alex Stone',
      conversationId: conversation.id,
      message: cleanMessage,
      selectedClientId: conversation.verifiedClient?.clientId || selectedClientId,
    });

    conversationService.recordExchange(conversation, cleanMessage, fallbackResult.replyText, {
      model: 'alpha-x-database-engine',
      promptVersion: '2.0-fallback',
      latencyMs: 30,
      verifiedClient: conversation.verifiedClient || null,
    });

    sendSuccess(res, {
      conversationId: conversation.id,
      response: fallbackResult.replyText,
      replyText: fallbackResult.replyText,
      requestId,
      model: 'alpha-x-database-engine',
      promptVersion: '2.0-fallback',
      latencyMs: 30,
      intent: fallbackResult.intent || 'FACILITY_QUERY',
      reportCard: fallbackResult.reportCard,
      proposal: fallbackResult.proposal,
      suggestedFollowUps: fallbackResult.suggestedFollowUps || [
        'Give me today\'s report',
        'Show clients needing review',
        'Who missed workouts today?',
      ],
      verifiedClient: conversation.verifiedClient || null,
    }, HttpStatus.OK, `AI Coach answered via Alpha X Analytics Engine (Prompt: "${cleanMessage}")`);
    return;
  } catch (_) {
    console.log(`[DEBUG CHAT] Final response returned to frontend: [ConvID: ${conversation.id}] (HTTP 503) "GEMINI_API_KEY is not configured on the server."`);
    sendError(
      res,
      'AI_CONFIGURATION_REQUIRED',
      'AI service is temporarily unavailable: GEMINI_API_KEY is not configured on the server.',
      HttpStatus.SERVICE_UNAVAILABLE,
      undefined,
      undefined,
      {
        activity: 'AI Coach Natural Language Query',
        explanation: 'GEMINI_API_KEY environment variable is not configured on the server.',
      }
    );
  }
});

/**
 * POST /api/v1/admin/ai-coach/new-chat
 * Initializes a new conversation session for the authenticated Admin.
 */
router.post('/new-chat', async (req: Request, res: Response) => {
  const adminUser = (req as any).user || {};
  const adminId = adminUser.id || defaultAdminId;

  const newConv = conversationStore.create(adminId);
  sendSuccess(res, {
    conversationId: newConv.id,
    createdAt: newConv.createdAt,
    message: 'New conversation session initialized',
  }, HttpStatus.CREATED);
});

/**
 * POST /api/v1/admin/ai-coach/clear-client
 * Clears active verified client context from a conversation session.
 */
router.post('/clear-client', async (req: Request, res: Response) => {
  const { conversationId } = req.body;
  const adminUser = (req as any).user || {};
  const adminId = adminUser.id || defaultAdminId;

  const { conversation } = conversationService.resolveConversation(adminId, conversationId);
  clientContextService.clearClient(conversation);

  sendSuccess(res, {
    conversationId: conversation.id,
    verifiedClient: null,
    message: 'Active client context cleared successfully.',
  }, HttpStatus.OK);
});

/**
 * POST /api/v1/admin/ai-coach/select-client
 * Explicitly resolves and sets verified client context on a conversation session.
 */
router.post('/select-client', async (req: Request, res: Response) => {
  const { conversationId, clientId } = req.body;
  if (!clientId || typeof clientId !== 'string' || !clientId.trim()) {
    sendError(res, 'VALIDATION_ERROR', 'clientId or client reference string is required', HttpStatus.BAD_REQUEST);
    return;
  }

  const adminUser = (req as any).user || {};
  const adminId = adminUser.id || defaultAdminId;

  const { conversation } = conversationService.resolveConversation(adminId, conversationId);
  const resolveResult = await clientContextService.resolveAndSetClient(conversation, clientId.trim());

  if (resolveResult.status === 'AMBIGUOUS') {
    sendSuccess(res, {
      status: 'MULTIPLE_CLIENTS_FOUND',
      message: `Multiple clients match "${clientId}". Please specify the unique AXG ID.`,
      candidates: resolveResult.candidates || resolveResult.matches,
      conversationId: conversation.id,
      verifiedClient: conversation.verifiedClient || null,
    }, HttpStatus.OK);
    return;
  }

  if (resolveResult.status === 'NOT_FOUND' || !resolveResult.client) {
    sendError(res, 'CLIENT_NOT_FOUND', `Client "${clientId}" not found in Alpha X records`, HttpStatus.NOT_FOUND);
    return;
  }

  sendSuccess(res, {
    status: 'VERIFIED',
    message: `Client context set to ${resolveResult.client.displayName} (${resolveResult.client.clientId})`,
    conversationId: conversation.id,
    verifiedClient: resolveResult.client,
  }, HttpStatus.OK);
});

/**
 * GET /api/v1/admin/ai-coach/tools
 * Returns active registered AI tools and capabilities.
 */
router.get('/tools', async (_req: Request, res: Response) => {
  const tools = toolRegistry.listTools(true).map((t) => ({
    name: t.name,
    description: t.description,
    category: t.category,
    permission: t.permission,
    enabled: t.enabled,
    parameters: t.inputSchema,
  }));

  sendSuccess(res, {
    totalTools: tools.length,
    activeToolsCount: tools.filter((t) => t.enabled).length,
    tools,
  });
});

/**
 * GET /api/v1/admin/ai-coach/summary
 * Returns Today's AI Summary for Admin Dashboard card display.
 */
router.get('/summary', async (req: Request, res: Response) => {
  try {
    const todayStr = new Date().toISOString().split('T')[0];
    const summary = await aiTools.getDailyGymSummary(todayStr);

    sendSuccess(res, {
      title: "Today's AI Summary",
      date: summary.date,
      workoutsCompleted: summary.workoutsCompletedToday,
      foodLogsRecorded: summary.foodLogsRecordedToday,
      weeklyCheckInsPending: summary.weeklyCheckInsPending,
      clientsNeedReview: summary.clientsNeedingReviewCount,
      totalActiveClients: summary.totalActiveClients,
      attentionItems: summary.attentionItems,
    });
  } catch (err: any) {
    console.error('[AI COACH SUMMARY ERROR]', err);
    sendError(res, 'INTERNAL_ERROR', 'Failed to retrieve AI summary', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

/**
 * GET /api/v1/admin/ai-coach/proposals
 * Retrieves AI-generated proposals for review (filtered by status or client).
 */
router.get('/proposals', async (req: Request, res: Response) => {
  const status = req.query.status as string | undefined;
  const clientId = req.query.clientId as string | undefined;
  const proposalType = req.query.type as string | undefined;

  const where: any = {};
  if (status) where.status = status.toUpperCase();
  if (clientId) where.clientId = clientId.toUpperCase();
  if (proposalType) where.proposalType = proposalType.toUpperCase();

  try {
    const proposals = await prisma.aIProposal.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: 50,
    });

    const parsed = proposals.map((p) => {
      let payload = null;
      let currentData = null;
      try {
        payload = JSON.parse(p.finalDataJson || p.proposedDataJson);
      } catch (_) {}
      try {
        if (p.currentDataJson) currentData = JSON.parse(p.currentDataJson);
      } catch (_) {}

      return {
        id: p.id,
        conversationId: p.conversationId,
        clientProfileId: p.clientProfileId,
        clientId: p.clientId,
        clientName: p.clientName,
        proposalType: p.proposalType,
        status: p.status,
        title: p.title,
        summary: p.summary,
        reason: p.reason,
        currentData,
        proposedData: payload,
        approvedById: p.approvedById,
        approvedByName: p.approvedByName,
        approvedAt: p.approvedAt,
        rejectedAt: p.rejectedAt,
        rejectionReason: p.rejectionReason,
        createdAt: p.createdAt,
        updatedAt: p.updatedAt,
      };
    });

    sendSuccess(res, parsed);
  } catch (err: any) {
    console.error('[AI COACH GET PROPOSALS ERROR]', err);
    sendError(res, 'INTERNAL_ERROR', 'Failed to fetch AI proposals', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

/**
 * POST /api/v1/admin/ai-coach/proposals/:id/approve
 * Approves a proposal, updates active client plan in database, creates audit record.
 */
router.post('/proposals/:id/approve', async (req: Request, res: Response) => {
  const proposalId = String(req.params.id);
  const { assignmentType, clientIds, scheduledDate, proposalData, proposal: inlineProposal } = req.body || {};

  try {
    const adminUser = (req as any).user || {};
    const adminId = adminUser.id || defaultAdminId;
    const adminName = adminUser.name || 'Admin Alex';

    const approved = await aiTools.approveProposal(proposalId, adminId, adminName, {
      assignmentType,
      clientIds,
      scheduledDate,
      proposalData: proposalData || inlineProposal,
    });
    sendSuccess(res, {
      message: `Proposal approved successfully. Active plan updated for client.`,
      proposal: approved,
    }, HttpStatus.OK);
  } catch (err: any) {
    console.error('[AI COACH APPROVE PROPOSAL ERROR]', err);
    if (err.message && err.message.includes('Proposal not found')) {
      sendError(res, 'NOT_FOUND', err.message, HttpStatus.NOT_FOUND);
      return;
    }
    sendError(res, 'INTERNAL_ERROR', err.message || 'Failed to approve proposal', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

/**
 * POST /api/v1/admin/ai-coach/proposals/:id/reject
 * Rejects a proposal and records rejection rationale in audit log.
 */
router.post('/proposals/:id/reject', async (req: Request, res: Response) => {
  const proposalId = String(req.params.id);
  const { reason } = req.body;

  try {
    const adminUser = (req as any).user || {};
    const adminId = adminUser.id || defaultAdminId;

    const rejected = await aiTools.rejectProposal(proposalId, adminId, reason);
    sendSuccess(res, {
      message: 'Proposal rejected successfully',
      proposal: rejected,
    }, HttpStatus.OK);
  } catch (err: any) {
    console.error('[AI COACH REJECT PROPOSAL ERROR]', err);
    sendError(res, 'INTERNAL_ERROR', err.message || 'Failed to reject proposal', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

/**
 * PUT / POST /api/v1/admin/ai-coach/proposals/:id/edit
 * Saves Admin modifications to an AI proposal prior to approval.
 */
const handleEditProposal = async (req: Request, res: Response) => {
  const proposalId = String(req.params.id);
  const { editedPayload } = req.body;

  if (!editedPayload) {
    sendError(res, 'VALIDATION_ERROR', 'Edited payload is required', HttpStatus.BAD_REQUEST);
    return;
  }

  try {
    const adminUser = (req as any).user || {};
    const adminId = adminUser.id || defaultAdminId;

    const edited = await aiTools.editProposal(proposalId, adminId, editedPayload);
    sendSuccess(res, {
      message: 'Proposal updated with admin modifications',
      proposal: edited,
    }, HttpStatus.OK);
  } catch (err: any) {
    console.error('[AI COACH EDIT PROPOSAL ERROR]', err);
    sendError(res, 'INTERNAL_ERROR', err.message || 'Failed to edit proposal', HttpStatus.INTERNAL_SERVER_ERROR);
  }
};

router.put('/proposals/:id/edit', handleEditProposal);
router.post('/proposals/:id/edit', handleEditProposal);

/**
 * GET /api/v1/admin/ai-coach/history
 * Returns active Admin AI conversation history.
 */
router.get('/history', async (req: Request, res: Response) => {
  const adminUser = (req as any).user || {};
  const adminId = adminUser.id || defaultAdminId;

  try {
    const memoryConversations = conversationStore.getByAdmin(adminId);
    if (memoryConversations.length > 0) {
      sendSuccess(res, memoryConversations);
      return;
    }

    try {
      if ((prisma as any).aIConversation?.findMany) {
        const dbConvs = await (prisma as any).aIConversation.findMany({
          where: { adminId },
          include: {
            messages: {
              orderBy: { createdAt: 'asc' },
              take: 50,
            },
          },
          orderBy: { updatedAt: 'desc' },
          take: 10,
        });
        sendSuccess(res, dbConvs);
        return;
      }
    } catch (_) {}

    sendSuccess(res, []);
  } catch (err: any) {
    console.error('[AI COACH HISTORY ERROR]', err);
    sendError(res, 'INTERNAL_ERROR', 'Failed to fetch conversation history', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

/**
 * GET /api/v1/admin/ai-coach/audit-logs
 * Retrieves audit log of all AI operations and Admin approval decisions.
 */
router.get('/audit-logs', async (_req: Request, res: Response) => {
  try {
    const logs = await prisma.aIAuditLog.findMany({
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
    sendSuccess(res, logs);
  } catch (err: any) {
    console.error('[AI COACH AUDIT LOGS ERROR]', err);
    sendError(res, 'INTERNAL_ERROR', 'Failed to retrieve audit logs', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

/**
 * GET /api/v1/admin/ai-coach/clients/:clientId/summary
 * Also accessible via /api/admin/ai-coach/clients/:clientId/summary
 *
 * Returns a compact, PII-safe JSON summary of one client's data over a date
 * range (workouts, diet, body metrics, personal records, adherence).
 * Intended as the pre-processing step before sending data to Gemini.
 *
 * Query params:
 *   startDate  YYYY-MM-DD  (default: 7 days ago)
 *   endDate    YYYY-MM-DD  (default: today)
 */
router.get('/clients/:clientId/summary', async (req: Request, res: Response) => {
  const { clientId } = req.params;
  const { startDate, endDate } = req.query as { startDate?: string; endDate?: string };

  const clientIdStr = Array.isArray(clientId) ? clientId[0] : clientId;
  if (!clientIdStr || !clientIdStr.trim()) {
    sendError(res, 'VALIDATION_ERROR', 'clientId path parameter is required', HttpStatus.BAD_REQUEST);
    return;
  }

  try {
    const summary = await clientSummaryService.buildClientSummary(clientIdStr.trim(), {
      startDate,
      endDate,
    });

    // Surface client-resolution errors as proper HTTP errors
    if ('error' in summary) {
      const httpStatus =
        summary.status === 'CLIENT_NOT_FOUND' ? HttpStatus.NOT_FOUND :
        summary.status === 'INVALID_DATE'     ? HttpStatus.BAD_REQUEST :
        HttpStatus.CONFLICT;
      sendError(res, summary.status, summary.error, httpStatus);
      return;
    }

    sendSuccess(res, summary, HttpStatus.OK);
  } catch (err: any) {
    console.error('[AI COACH CLIENT SUMMARY ERROR]', err);
    sendError(res, 'INTERNAL_ERROR', 'Failed to build client summary', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

/**
 * GET /api/v1/admin/ai-coach/health
 * Also accessible via /api/admin/ai-coach/health
 *
 * Lightweight Gemini API connectivity probe with TTL caching (no credential leaks).
 * Query param: ?refresh=true forces a fresh probe instead of returning cached status.
 */
router.get('/health', async (req: Request, res: Response) => {
  try {
    const forceRefresh = req.query.refresh === 'true';
    const health = await geminiReliability.checkHealth(forceRefresh);
    const statusCode = health.healthy ? HttpStatus.OK : HttpStatus.SERVICE_UNAVAILABLE;
    sendSuccess(res, health, statusCode);
  } catch (err: any) {
    sendError(
      res,
      'HEALTH_CHECK_ERROR',
      err?.message || 'Failed to check Gemini AI health',
      HttpStatus.INTERNAL_SERVER_ERROR
    );
  }
});

/**
 * GET /api/v1/admin/ai-coach/split-templates
 * Returns all 20 supported workout split configuration templates.
 */
router.get('/split-templates', (req: Request, res: Response) => {
  const templates = workoutIntentService.getSplitTemplates();
  sendSuccess(res, {
    templates: templates.map(t => ({
      key: t.key,
      id: t.id,
      displayName: t.displayName,
      category: t.category,
      description: t.description,
      defaultDaysPerWeek: t.defaultDaysPerWeek,
      minDays: t.minDays,
      maxDays: t.maxDays,
      sensibleDaysOptions: t.sensibleDaysOptions,
    })),
    total: templates.length,
  }, HttpStatus.OK);
});

/**
 * POST /api/v1/admin/ai-coach/proposals/generate
 * Three-Step Plan Configuration Generator:
 * Generates and validates a genuine database-backed proposal staged as PENDING for admin review.
 */
export const handleGenerateProposal = async (req: Request, res: Response): Promise<void> => {
  const {
    conversationId,
    workoutConfig,
    dietConfig,
  } = req.body;

  const clientIdentifier = (
    req.body.clientIdentifier ||
    req.body.clientId ||
    req.body.memberId ||
    req.body.userId ||
    ''
  ).toString().trim();

  const rawPlanType = (
    req.body.planType ||
    req.body.type ||
    req.body.proposalType ||
    (req.body.workoutConfig ? 'WORKOUT' : req.body.dietConfig ? 'DIET' : '')
  ).toString().toUpperCase().trim();

  const planType = rawPlanType.includes('DIET') ? 'DIET' : (rawPlanType.includes('WORKOUT') ? 'WORKOUT' : rawPlanType);

  if (!clientIdentifier) {
    sendError(res, 'VALIDATION_ERROR', 'clientIdentifier is required', HttpStatus.BAD_REQUEST);
    return;
  }

  if (planType !== 'WORKOUT' && planType !== 'DIET') {
    sendError(res, 'VALIDATION_ERROR', 'planType must be WORKOUT or DIET', HttpStatus.BAD_REQUEST);
    return;
  }

  // 1. Resolve client
  const resolved = await clientDataService.resolveClient(clientIdentifier.trim());
  if (resolved.status !== 'FOUND' || !resolved.client) {
    sendError(
      res,
      resolved.status === 'AMBIGUOUS' ? 'MULTIPLE_CLIENTS_FOUND' : 'CLIENT_NOT_FOUND',
      resolved.message || `Client "${clientIdentifier}" not found`,
      HttpStatus.NOT_FOUND
    );
    return;
  }

  const { profileId, clientId, name } = resolved.client;
  const adminUser = (req as any).user || {};
  const adminId = adminUser.id || defaultAdminId;
  const effectiveConvId = conversationId || `conv_gen_${Date.now()}`;

  // Read full client profile
  const clientProfile = await prisma.clientProfile.findUnique({
    where: { id: profileId },
    include: { user: true },
  });

  if (planType === 'WORKOUT') {
    const splitKeyOrId = workoutConfig?.splitKey || workoutConfig?.splitId || workoutConfig?.splitName || 'full_body';
    const splitTemplate = workoutIntentService.getSplitTemplate(splitKeyOrId) || workoutIntentService.getSplitTemplates()[0];
    const daysPerWeek = Number(workoutConfig?.daysPerWeek) || splitTemplate.defaultDaysPerWeek;
    const primaryGoal = workoutConfig?.primaryGoal || clientProfile?.primaryGoal || 'Hypertrophy';
    const experience = workoutConfig?.trainingExperience || clientProfile?.fitnessLevel || 'Intermediate';
    const sessionDuration = Number(workoutConfig?.sessionDurationMinutes) || 50;
    const focusMuscles = Array.isArray(workoutConfig?.focusMuscles) ? workoutConfig.focusMuscles : [];
    const weakPoints = Array.isArray(workoutConfig?.weakPoints) ? workoutConfig.weakPoints : [];
    const injuryExclusions = Array.isArray(workoutConfig?.injuryExclusions) ? workoutConfig.injuryExclusions : (clientProfile?.injuryAreas || []);

    // Generate schedule days according to split configuration template
    const dayPlans = splitTemplate.generateSchedule({
      daysPerWeek,
      primaryGoal,
      trainingExperience: experience,
      sessionDurationMinutes: sessionDuration,
      focusMuscles,
      weakPoints,
      equipment: workoutConfig?.equipment,
      injuryExclusions,
      weekdaySchedule: workoutConfig?.weekdaySchedule,
    });

    // Enforce reasonable, configurable per-session exercise count target based on client level
    let targetExercisesPerSession = Number(workoutConfig?.targetExercisesPerSession || workoutConfig?.exercisesPerSession);
    if (!targetExercisesPerSession || targetExercisesPerSession < 3 || targetExercisesPerSession > 9) {
      const expLower = experience.toLowerCase();
      if (expLower.includes('beginner') || expLower.includes('novice')) {
        targetExercisesPerSession = 5; // 5 exercises per session for beginners (5–7 range)
      } else if (expLower.includes('advanced') || expLower.includes('elite')) {
        targetExercisesPerSession = 6; // 6–7 exercises for advanced
      } else {
        targetExercisesPerSession = 5; // 5–6 exercises for intermediate
      }
    }

    const resolveSplitCategory = (title: string, muscleGroup: string, splitKey: string): string => {
      const combined = `${title} ${muscleGroup} ${splitKey}`.toLowerCase();
      if (combined.includes('push')) return 'Push';
      if (combined.includes('pull')) return 'Pull';
      if (combined.includes('leg') || combined.includes('quad') || combined.includes('hamstring') || combined.includes('squat')) return 'Legs';
      if (combined.includes('upper')) return 'Upper';
      if (combined.includes('lower')) return 'Lower';
      if (combined.includes('chest')) return 'Chest';
      if (combined.includes('back')) return 'Back';
      if (combined.includes('shoulder')) return 'Shoulders';
      if (combined.includes('arm')) return 'Arms';
      return 'Full Body';
    };

    // For each day, retrieve library-verified exercises
    const weeklySchedule: Array<any> = [];
    let dayIdx = 0;
    for (const d of dayPlans) {
      const dayExercises = await workoutIntentService.getBalancedExercisesForSplit(
        {
          split: splitTemplate.key,
          templateId: splitTemplate.id,
          displayName: splitTemplate.displayName,
          titleSuffix: splitTemplate.displayName,
          targetMuscleGroup: d.targetMuscleGroup,
          isAmbiguous: false,
          primaryBodyParts: d.primaryBodyParts,
          allowedBodyParts: d.allowedBodyParts,
          disallowedBodyParts: d.disallowedBodyParts,
          suggestedDaysPerWeek: daysPerWeek,
          isMultiDayTemplate: true,
        },
        {
          clientProfileId: profileId,
          fitnessLevel: experience,
          injuryAreas: injuryExclusions,
          count: targetExercisesPerSession,
          variationSeed: dayIdx++,
          primaryBodyParts: d.primaryBodyParts,
          allowedBodyParts: d.allowedBodyParts,
        }
      );

      const splitCategory = resolveSplitCategory(d.sessionTitle, d.targetMuscleGroup, splitTemplate.key);
      const dayId = `day_${dayIdx}_${d.dayName.toLowerCase().slice(0, 3)}_${splitCategory.toLowerCase().replace(/[^a-z0-9]/g, '_')}`;

      weeklySchedule.push({
        id: dayId,
        dayId,
        day: d.dayName,
        dayName: d.dayName,
        weekday: d.dayName,
        splitCategory,
        category: splitCategory,
        sessionTitle: d.sessionTitle,
        title: d.sessionTitle,
        workoutType: d.workoutType || 'Hypertrophy',
        targetMuscleGroup: d.targetMuscleGroup,
        targetMuscles: d.primaryBodyParts || [d.targetMuscleGroup],
        estimatedDurationMinutes: d.estimatedDurationMinutes || sessionDuration,
        recommendedExercisesCount: dayExercises.length,
        exercises: dayExercises.map((e, eIdx) => ({
          exerciseId: e.id,
          name: e.name,
          exerciseName: e.name,
          category: e.category,
          bodyPart: e.bodyPart,
          orderIndex: eIdx,
          sets: experience.toLowerCase() === 'advanced' ? 4 : 3,
          numberOfSets: experience.toLowerCase() === 'advanced' ? 4 : 3,
          reps: experience.toLowerCase() === 'advanced' ? '6-8' : (primaryGoal.toLowerCase().includes('strength') ? '5-6' : '8-10'),
          targetReps: experience.toLowerCase() === 'advanced' ? '6-8' : (primaryGoal.toLowerCase().includes('strength') ? '5-6' : '8-10'),
          restSeconds: primaryGoal.toLowerCase().includes('strength') ? 120 : 90,
          weight: experience.toLowerCase() === 'advanced' ? 75.0 : 50.0,
          targetWeight: experience.toLowerCase() === 'advanced' ? 75.0 : 50.0,
          targetRir: 2,
          targetRpe: 8.0,
          tempo: '3-1-1-0',
          notes: 'Tempo 3-1-1-0. Prioritize strict range of motion and form.',
          adminInstruction: 'Tempo 3-1-1-0. Prioritize strict range of motion and form.',
          day: d.dayName,
        })),
      });
    }

    const planTitle = `${name} — ${splitTemplate.displayName} (${daysPerWeek}-Day)`;
    const summary = `${daysPerWeek}-day ${splitTemplate.displayName} protocol (${primaryGoal}) tailored for ${name}.`;
    const reason = `Formulated for ${name} (${clientId || 'AXG'}) using ${splitTemplate.displayName} template based on ${experience} level, ${primaryGoal} goal, and recorded injury exclusions.`;

    // Invoke propose_workout_plan tool handler
    const toolResult = await proposeWorkoutPlanTool.handler(
      {
        clientIdentifier: clientId || name,
        planTitle,
        reason,
        summary,
        weeklySchedule,
      },
      {
        adminId,
        conversationId: effectiveConvId,
        requestId: `req_gen_${Date.now()}`,
      }
    );

    if (!toolResult.success) {
      sendError(res, toolResult.error || 'GENERATION_ERROR', toolResult.message || 'Failed to generate workout proposal', HttpStatus.BAD_REQUEST);
      return;
    }

    sendSuccess(res, {
      proposal: toolResult.proposal,
      proposalId: toolResult.proposalId,
      status: 'PENDING',
      message: 'Workout plan proposal generated and saved as PENDING for admin review',
    }, HttpStatus.CREATED);
    return;
  }

  // DIET PLAN GENERATION
  if (planType === 'DIET') {
    const isMacroOnly = dietConfig?.planKind === 'MACRO_ONLY';
    const primaryGoal = dietConfig?.primaryGoal || clientProfile?.primaryGoal || 'Fat Loss';

    const macroResult = calculatePersonalizedDietMacros(
      {
        weightKg: dietConfig?.weightKg || clientProfile?.weightKg,
        heightCm: dietConfig?.heightCm || clientProfile?.heightCm,
        age: dietConfig?.age || clientProfile?.age,
        gender: dietConfig?.sex || dietConfig?.gender || clientProfile?.gender,
        sex: dietConfig?.sex || dietConfig?.gender || clientProfile?.gender,
        activityLevel: dietConfig?.activityLevel || clientProfile?.activityLevel,
        activityMultiplier: dietConfig?.activityMultiplier,
        trainingDaysPerWeek: dietConfig?.trainingDaysPerWeek || clientProfile?.trainingDaysPerWeek,
        calorieAdjustmentPct: dietConfig?.calorieAdjustmentPct,
        proteinGramsPerKg: dietConfig?.proteinGramsPerKg,
      },
      primaryGoal,
      {
        dailyCalories: dietConfig?.dailyCalories || dietConfig?.calorieTarget || dietConfig?.calories,
        protein: dietConfig?.protein || dietConfig?.proteinGrams,
        carbohydrates: dietConfig?.carbohydrates || dietConfig?.carbGrams || dietConfig?.carbs,
        fat: dietConfig?.fat || dietConfig?.fatGrams,
        fiber: dietConfig?.fiber,
        waterTargetLiters: dietConfig?.waterTargetLiters,
      }
    );

    const dailyCalories = macroResult.dailyCalories;
    const protein = macroResult.protein;
    const carbs = macroResult.carbohydrates;
    const fat = macroResult.fat;
    const fiber = macroResult.fiber;
    const waterTargetLiters = macroResult.waterTargetLiters;

    const planTitle = isMacroOnly
      ? `${name} — Daily Macro Targets (${macroResult.normalizedGoal})`
      : `${name} — ${macroResult.normalizedGoal} Nutrition Plan`;
    const summary = `${dailyCalories} kcal • ${protein}g P • ${carbs}g C • ${fat}g F (${isMacroOnly ? 'Macro Targets' : 'Full Meal Plan'})`;
    const reason = macroResult.rationale;
    const notes = dietConfig?.notes || (macroResult.missingDataNotes
      ? `[FLAGGED FOR ADMIN REVIEW] ${macroResult.missingDataNotes}`
      : `Personalized ${macroResult.normalizedGoal} protocol for ${name}.`);

    let meals: Array<any> | undefined = undefined;
    if (!isMacroOnly) {
      const isVeg = (dietConfig?.dietaryPreferences || []).some((p: string) => /veg/i.test(p)) ||
        (clientProfile?.adminNotes || '').toLowerCase().includes('veg');
      const hasEggAllergy = (dietConfig?.dietaryPreferences || []).some((p: string) => /egg/i.test(p));
      const hasDairyAllergy = (dietConfig?.dietaryPreferences || []).some((p: string) => /dairy|lactose/i.test(p));

      const bfastProtein = (!isVeg && !hasEggAllergy)
        ? { name: 'Whole Eggs', qty: 3, unit: 'piece', cal: 210, pro: 18, carb: 1, fat: 15 }
        : { name: isVeg ? 'Low-Fat Paneer' : 'Organic Tofu', qty: 120, unit: 'g', cal: 216, pro: 21, carb: 4, fat: 12 };

      const lunchProtein = !isVeg
        ? { name: 'Chicken Breast (Grilled)', qty: 180, unit: 'g', cal: 297, pro: 55, carb: 0, fat: 6 }
        : { name: 'Paneer / Tofu Curry', qty: 150, unit: 'g', cal: 270, pro: 27, carb: 6, fat: 15 };

      const snackProtein = !hasDairyAllergy
        ? { name: 'Whey Protein Isolate', qty: 30, unit: 'g', cal: 120, pro: 25, carb: 1, fat: 1 }
        : { name: 'Plant Protein Blend', qty: 30, unit: 'g', cal: 115, pro: 24, carb: 2, fat: 1 };

      const dinProtein = !isVeg
        ? { name: 'Grilled Chicken Breast', qty: 150, unit: 'g', cal: 248, pro: 46, carb: 0, fat: 5 }
        : { name: 'Lentils / Dal & Tofu', qty: 150, unit: 'g', cal: 225, pro: 25, carb: 12, fat: 5 };

      const rawMeals = [
        {
          mealType: 'Breakfast',
          timing: '8:00 AM',
          foods: [
            { foodName: 'Rolled Oats', quantity: 60, unit: 'g', calories: 233, protein: 10, carbs: 40, fat: 4 },
            { foodName: bfastProtein.name, quantity: bfastProtein.qty, unit: bfastProtein.unit, calories: bfastProtein.cal, protein: bfastProtein.pro, carbs: bfastProtein.carb, fat: bfastProtein.fat },
          ],
        },
        {
          mealType: 'Lunch',
          timing: '1:00 PM',
          foods: [
            { foodName: lunchProtein.name, quantity: lunchProtein.qty, unit: lunchProtein.unit, calories: lunchProtein.cal, protein: lunchProtein.pro, carbs: lunchProtein.carb, fat: lunchProtein.fat },
            { foodName: 'Basmati Rice (Cooked)', quantity: 200, unit: 'g', calories: 260, protein: 5, carbs: 56, fat: 1 },
          ],
        },
        {
          mealType: 'Snacks',
          timing: '4:30 PM',
          foods: [
            { foodName: 'Fresh Apple', quantity: 1, unit: 'piece', calories: 95, protein: 0.5, carbs: 25, fat: 0.3 },
            { foodName: snackProtein.name, quantity: snackProtein.qty, unit: snackProtein.unit, calories: snackProtein.cal, protein: snackProtein.pro, carbs: snackProtein.carb, fat: snackProtein.fat },
          ],
        },
        {
          mealType: 'Dinner',
          timing: '8:00 PM',
          foods: [
            { foodName: dinProtein.name, quantity: dinProtein.qty, unit: dinProtein.unit, calories: dinProtein.cal, protein: dinProtein.pro, carbs: dinProtein.carb, fat: dinProtein.fat },
            { foodName: 'Steamed Rice', quantity: 150, unit: 'g', calories: 195, protein: 4, carbs: 42, fat: 0.5 },
          ],
        },
      ];

      // Proportionally scale meal portions and calories so sum closely matches dailyCalories
      const totalRawCalories = rawMeals.reduce((acc, m) => {
        return acc + m.foods.reduce((sum, f) => sum + (Number(f.calories) || 0), 0);
      }, 0);

      const scale = totalRawCalories > 0 && dailyCalories > 0 ? dailyCalories / totalRawCalories : 1.0;

      meals = rawMeals.map((meal) => ({
        ...meal,
        foods: meal.foods.map((food) => ({
          ...food,
          quantity: Math.max(1, Math.round(Number(food.quantity) * scale)),
          calories: Math.max(1, Math.round(Number(food.calories) * scale)),
          protein: Math.round(Number(food.protein) * scale * 10) / 10,
          carbs: Math.round(Number(food.carbs) * scale * 10) / 10,
          fat: Math.round(Number(food.fat) * scale * 10) / 10,
        })),
      }));
    }

    const dietResult = await proposeDietPlanTool.handler(
      {
        clientIdentifier: clientId || name,
        planName: planTitle,
        planKind: isMacroOnly ? 'MACRO_ONLY' : 'DIET_PLAN',
        reason,
        summary,
        dailyCalories,
        protein,
        carbohydrates: carbs,
        fat,
        fiber,
        waterTargetLiters,
        notes,
        meals,
      },
      {
        adminId,
        conversationId: effectiveConvId,
        requestId: `req_diet_gen_${Date.now()}`,
      }
    );

    if (!dietResult.success) {
      sendError(res, dietResult.error || 'GENERATION_ERROR', dietResult.message || 'Failed to generate diet proposal', HttpStatus.BAD_REQUEST);
      return;
    }

    sendSuccess(res, {
      proposal: dietResult.proposal,
      proposalId: dietResult.proposalId,
      status: 'PENDING',
      message: `${isMacroOnly ? 'Macro-only' : 'Diet plan'} proposal generated and saved as PENDING for admin review`,
    }, HttpStatus.CREATED);
    return;
  }
};

router.post('/proposals/generate', handleGenerateProposal);
router.post('/generate', handleGenerateProposal);

export const aiCoachRoutes = router;


