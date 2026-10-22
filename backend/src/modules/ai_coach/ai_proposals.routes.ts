/**
 * Alpha X — AI Proposals Routes
 *
 * GET  /api/v1/admin/ai-proposals              — List all pending proposals
 * GET  /api/v1/admin/ai-proposals/:id          — Get one proposal detail
 * POST /api/v1/admin/ai-proposals/:id/approve  — Approve and assign the plan
 * POST /api/v1/admin/ai-proposals/:id/reject   — Reject with a reason
 *
 * Admin-only. Clients never see these routes.
 */

import { Router, Request, Response } from 'express';
import { requireAuth, requireAdmin } from '../../middlewares/auth';
import { prisma } from '../../config/prisma';
import { HttpStatus } from '../../constants/httpStatus';
import { sendSuccess, sendError } from '../../utils/responseEnvelope';
import { aiTools } from './ai_tools';
import { handleGenerateProposal } from './ai_coach.routes';

const router = Router();

// ── GET /api/v1/admin/ai-proposals ──────────────────────────────────────────
// Returns all proposals, filtered by status if provided
router.get('/', requireAuth, requireAdmin, async (req: Request, res: Response) => {
  const status = req.query.status as string | undefined;  // PENDING | APPROVED | REJECTED
  const type = req.query.type as string | undefined;       // WORKOUT | DIET

  const proposals = await prisma.aIProposal.findMany({
    where: {
      ...(status ? { status: status.toUpperCase() } : {}),
      ...(type ? { proposalType: type.toUpperCase() } : {}),
    },
    orderBy: { createdAt: 'desc' },
    select: {
      id: true,
      clientId: true,
      clientName: true,
      clientProfileId: true,
      proposalType: true,
      status: true,
      title: true,
      summary: true,
      reason: true,
      proposedDataJson: true,
      finalDataJson: true,
      createdAt: true,
      approvedAt: true,
      approvedByName: true,
      rejectedAt: true,
      rejectionReason: true,
    },
  });

  const parsed = proposals.map((p) => {
    let proposedData: any = {};
    try { proposedData = JSON.parse(p.finalDataJson || p.proposedDataJson || '{}'); } catch {}
    return {
      ...p,
      proposedData,
      payload: proposedData,
    };
  });

  sendSuccess(res, { proposals: parsed, total: parsed.length }, HttpStatus.OK);
});

// ── GET /api/v1/admin/ai-proposals/:id ──────────────────────────────────────
// Returns full proposal including the proposed plan JSON
router.get('/:id', requireAuth, requireAdmin, async (req: Request, res: Response) => {
  const proposal = await prisma.aIProposal.findUnique({
    where: { id: req.params.id as string },
  });

  if (!proposal) {
    sendError(res, 'NOT_FOUND', 'Proposal not found', HttpStatus.NOT_FOUND);
    return;
  }

  // Parse the JSON data so Flutter can render it nicely
  let proposedData: any = {};
  try { proposedData = JSON.parse(proposal.finalDataJson || proposal.proposedDataJson || '{}'); } catch {}

  sendSuccess(res, { ...proposal, proposedData, payload: proposedData }, HttpStatus.OK);
});

// ── POST /api/v1/admin/ai-proposals/:id/approve ─────────────────────────────
// Admin approves the proposal → plan is created and assigned to the client
router.post('/:id/approve', requireAuth, requireAdmin, async (req: Request, res: Response) => {
  const adminId = (req as any).user?.id || 'admin';
  const adminName = (req as any).user?.name || 'Admin';
  const { assignmentType, clientIds, scheduledDate } = req.body || {};

  const proposal = await prisma.aIProposal.findUnique({
    where: { id: req.params.id as string },
  });

  if (!proposal) {
    sendError(res, 'NOT_FOUND', 'Proposal not found', HttpStatus.NOT_FOUND);
    return;
  }

  if (proposal.status !== 'PENDING' && proposal.status !== 'EDITED') {
    sendError(res, 'INVALID_STATUS', `Proposal is already ${proposal.status}`, HttpStatus.CONFLICT);
    return;
  }

  try {
    const updatedProposal = await aiTools.approveProposal(proposal.id, adminId, adminName, {
      assignmentType,
      clientIds,
      scheduledDate,
    });
    sendSuccess(res, {
      message: `${proposal.proposalType === 'WORKOUT' ? 'Workout' : 'Diet'} plan approved and assigned to ${proposal.clientName}`,
      proposal: updatedProposal,
      proposalId: proposal.id,
    }, HttpStatus.OK);
  } catch (err: any) {
    sendError(res, 'APPROVE_FAILED', err?.message || 'Failed to approve proposal', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

// ── POST /api/v1/admin/ai-proposals/:id/reject ───────────────────────────────
router.post('/:id/reject', requireAuth, requireAdmin, async (req: Request, res: Response) => {
  const adminId = (req as any).user?.id || 'admin';
  const { reason } = req.body;

  const proposal = await prisma.aIProposal.findUnique({ where: { id: req.params.id as string } });
  if (!proposal) {
    sendError(res, 'NOT_FOUND', 'Proposal not found', HttpStatus.NOT_FOUND);
    return;
  }

  if (proposal.status !== 'PENDING' && proposal.status !== 'EDITED') {
    sendError(res, 'INVALID_STATUS', `Proposal is already ${proposal.status}`, HttpStatus.CONFLICT);
    return;
  }

  try {
    const updated = await aiTools.rejectProposal(proposal.id, adminId, reason);
    sendSuccess(res, { message: 'Proposal rejected', proposal: updated, proposalId: proposal.id }, HttpStatus.OK);
  } catch (err: any) {
    sendError(res, 'REJECT_FAILED', err?.message || 'Failed to reject proposal', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

// ── PUT / POST /api/v1/admin/ai-proposals/:id/edit ────────────────────────────
router.put('/:id/edit', requireAuth, requireAdmin, async (req: Request, res: Response) => {
  const adminId = (req as any).user?.id || 'admin';
  const { editedPayload } = req.body;
  if (!editedPayload) {
    sendError(res, 'VALIDATION_ERROR', 'Edited payload is required', HttpStatus.BAD_REQUEST);
    return;
  }
  try {
    const updated = await aiTools.editProposal(req.params.id as string, adminId, editedPayload);
    sendSuccess(res, { message: 'Proposal edited successfully', proposal: updated }, HttpStatus.OK);
  } catch (err: any) {
    sendError(res, 'EDIT_FAILED', err?.message || 'Failed to edit proposal', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

router.post('/:id/edit', requireAuth, requireAdmin, async (req: Request, res: Response) => {
  const adminId = (req as any).user?.id || 'admin';
  const { editedPayload } = req.body;
  if (!editedPayload) {
    sendError(res, 'VALIDATION_ERROR', 'Edited payload is required', HttpStatus.BAD_REQUEST);
    return;
  }
  try {
    const updated = await aiTools.editProposal(req.params.id as string, adminId, editedPayload);
    sendSuccess(res, { message: 'Proposal edited successfully', proposal: updated }, HttpStatus.OK);
  } catch (err: any) {
    sendError(res, 'EDIT_FAILED', err?.message || 'Failed to edit proposal', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

// ── POST /api/v1/admin/ai-proposals/generate ──────────────────────────────
// Also accessible via /proposals/generate alias
router.post('/generate', requireAuth, requireAdmin, handleGenerateProposal);
router.post('/proposals/generate', requireAuth, requireAdmin, handleGenerateProposal);

export const aiProposalsRoutes = router;
