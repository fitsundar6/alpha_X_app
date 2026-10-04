import { Router, Request, Response } from 'express';
import { requireAuth, requireAdmin } from '../../middlewares/auth';
import { geminiService } from './gemini.service';
import { aiController } from './ai_controller';
import { aiTools } from './ai_tools';
import { conversationService, conversationStore, clientContextService } from './conversation';
import { toolRegistry } from './tools';
import { prisma } from '../../config/prisma';
import { HttpStatus } from '../../constants/httpStatus';
import { sendSuccess, sendError } from '../../utils/responseEnvelope';
import { env } from '../../config/environment';
import { clientSummaryService } from './client_summary.service';

const router = Router();

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
  const adminId = adminUser.id || 'admin_alex_stone';
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
    const hasFitnessQuery = /(weight|workout|nutrition|diet|calories|protein|checkin|attendance|steps|history|goal|record|progress|injury|pain|sleep|adherence)/i.test(cleanMessage);
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

  const rawApiKey = process.env.GEMINI_API_KEY || env.GEMINI_API_KEY;
  const apiKey = (rawApiKey || '')
    .trim()
    .replace(/^["']|["']$/g, '')
    .trim();

  // 8. Call Google Gemini Foundation Model if API Key is configured
  if (apiKey && apiKey.length > 0) {
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
        latencyMs: geminiResult.latencyMs,
        intent: geminiResult.intent,
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
      console.error(`[GEMINI SERVICE NOTICE] [${requestId}]:`, err.message || err);
      console.log(`[DEBUG CHAT] Final response returned to frontend: [ConvID: ${conversation.id}] (HTTP 503 ERROR) "${err.message || 'AI service unavailable'}"`);
      sendError(
        res,
        'AI_SERVICE_UNAVAILABLE',
        err.message || 'AI service is temporarily unavailable.',
        HttpStatus.SERVICE_UNAVAILABLE
      );
      return;
    }
  }

  // 10. Clear technical error when Gemini API Key is missing (No fake/mock responses)
  console.log(`[DEBUG CHAT] Final response returned to frontend: [ConvID: ${conversation.id}] (HTTP 503) "GEMINI_API_KEY is not configured on the server."`);
  sendError(
    res,
    'AI_CONFIGURATION_REQUIRED',
    'AI service is temporarily unavailable: GEMINI_API_KEY is not configured on the server.',
    HttpStatus.SERVICE_UNAVAILABLE
  );
});

/**
 * POST /api/v1/admin/ai-coach/new-chat
 * Initializes a new conversation session for the authenticated Admin.
 */
router.post('/new-chat', async (req: Request, res: Response) => {
  const adminUser = (req as any).user || {};
  const adminId = adminUser.id || 'admin_alex_stone';

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
  const adminId = adminUser.id || 'admin_alex_stone';

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
  const adminId = adminUser.id || 'admin_alex_stone';

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
      attendancesVerifiedToday: summary.attendancesVerifiedToday,
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

  try {
    const adminUser = (req as any).user || {};
    const adminId = adminUser.id || 'admin_alex_stone';
    const adminName = adminUser.name || 'Admin Alex';

    const approved = await aiTools.approveProposal(proposalId, adminId, adminName);
    sendSuccess(res, {
      message: `Proposal approved successfully. Active plan updated for client.`,
      proposal: approved,
    }, HttpStatus.OK);
  } catch (err: any) {
    console.error('[AI COACH APPROVE PROPOSAL ERROR]', err);
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
    const adminId = adminUser.id || 'admin_alex_stone';

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
 * PUT /api/v1/admin/ai-coach/proposals/:id/edit
 * Saves Admin modifications to an AI proposal prior to approval.
 */
router.put('/proposals/:id/edit', async (req: Request, res: Response) => {
  const proposalId = String(req.params.id);
  const { editedPayload } = req.body;

  if (!editedPayload) {
    sendError(res, 'VALIDATION_ERROR', 'Edited payload is required', HttpStatus.BAD_REQUEST);
    return;
  }

  try {
    const adminUser = (req as any).user || {};
    const adminId = adminUser.id || 'admin_alex_stone';

    const edited = await aiTools.editProposal(proposalId, adminId, editedPayload);
    sendSuccess(res, {
      message: 'Proposal updated with admin modifications',
      proposal: edited,
    }, HttpStatus.OK);
  } catch (err: any) {
    console.error('[AI COACH EDIT PROPOSAL ERROR]', err);
    sendError(res, 'INTERNAL_ERROR', err.message || 'Failed to edit proposal', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

/**
 * GET /api/v1/admin/ai-coach/history
 * Returns active Admin AI conversation history.
 */
router.get('/history', async (req: Request, res: Response) => {
  const adminUser = (req as any).user || {};
  const adminId = adminUser.id || 'admin_alex_stone';

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

export const aiCoachRoutes = router;
