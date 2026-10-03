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
      proposalType: true,
      status: true,
      title: true,
      summary: true,
      reason: true,
      createdAt: true,
      approvedAt: true,
      approvedByName: true,
      rejectedAt: true,
      rejectionReason: true,
    },
  });

  sendSuccess(res, { proposals, total: proposals.length }, HttpStatus.OK);
});

// ── GET /api/v1/admin/ai-proposals/:id ──────────────────────────────────────
// Returns full proposal including the proposed plan JSON
router.get('/:id', requireAuth, requireAdmin, async (req: Request, res: Response) => {
  const proposal = await prisma.aIProposal.findUnique({
    where: { id: req.params.id },
  });

  if (!proposal) {
    sendError(res, 'NOT_FOUND', 'Proposal not found', HttpStatus.NOT_FOUND);
    return;
  }

  // Parse the JSON data so Flutter can render it nicely
  let proposedData: any = {};
  try { proposedData = JSON.parse(proposal.proposedDataJson || '{}'); } catch {}

  sendSuccess(res, { ...proposal, proposedData }, HttpStatus.OK);
});

// ── POST /api/v1/admin/ai-proposals/:id/approve ─────────────────────────────
// Admin approves the proposal → plan is created and assigned to the client
router.post('/:id/approve', requireAuth, requireAdmin, async (req: Request, res: Response) => {
  const adminId = (req as any).user?.id || 'admin';
  const adminName = (req as any).user?.name || 'Admin';

  const proposal = await prisma.aIProposal.findUnique({
    where: { id: req.params.id },
    include: { clientProfile: { select: { id: true, clientId: true, userId: true } } },
  });

  if (!proposal) {
    sendError(res, 'NOT_FOUND', 'Proposal not found', HttpStatus.NOT_FOUND);
    return;
  }

  if (proposal.status !== 'PENDING') {
    sendError(res, 'INVALID_STATUS', `Proposal is already ${proposal.status}`, HttpStatus.CONFLICT);
    return;
  }

  let proposedData: any = {};
  try { proposedData = JSON.parse(proposal.proposedDataJson || '{}'); } catch {}

  const profileId = proposal.clientProfileId;
  const clientId = proposal.clientId || null;

  // ── Handle WORKOUT proposal ─────────────────────────────────────────────
  if (proposal.proposalType === 'WORKOUT') {
    const schedule = proposedData.weeklySchedule || [];

    // Create one WorkoutSession per scheduled day
    const sessionIds: string[] = [];
    for (const day of schedule) {
      const exercises = day.exercises || [];
      const session = await prisma.workoutSession.create({
        data: {
          title: `${proposal.clientName} — ${day.sessionTitle}`,
          workoutType: day.workoutType || 'Strength',
          targetMuscleGroup: day.targetMuscleGroup || 'Full Body',
          difficulty: proposedData.difficulty || 'Intermediate',
          estimatedDurationMinutes: day.estimatedDurationMinutes || 45,
          description: `AI-generated plan: ${proposal.title}. Day: ${day.day}`,
          availabilityType: 'INDIVIDUAL',
          createdById: adminId,
          exercises: {
            create: exercises.map((ex: any, idx: number) => ({
              exerciseId: `ai-${proposal.id}-${idx}`,
              exerciseName: ex.name,
              category: 'AI Generated',
              orderIndex: idx,
              sets: {
                create: Array.from({ length: ex.sets || 3 }).map((_, setIdx) => ({
                  setNumber: setIdx + 1,
                  targetReps: parseInt(ex.reps) || 10,
                  targetWeight: null,
                  restSeconds: ex.restSeconds || 60,
                  notes: ex.notes || null,
                })),
              },
            })),
          },
        },
      });
      sessionIds.push(session.id);

      // Assign session to this specific client
      await prisma.workoutAssignment.create({
        data: {
          sessionId: session.id,
          clientId: proposal.clientProfile?.userId || '',
        },
      });
    }

    // Mark proposal as APPROVED
    await prisma.aIProposal.update({
      where: { id: proposal.id },
      data: {
        status: 'APPROVED',
        approvedById: adminId,
        approvedByName: adminName,
        approvedAt: new Date(),
        finalDataJson: JSON.stringify({ sessionIds, approvedAt: new Date() }),
      },
    });

    sendSuccess(res, {
      message: `Workout plan approved and assigned to ${proposal.clientName}`,
      proposalId: proposal.id,
      sessionsCreated: sessionIds.length,
    }, HttpStatus.OK);
    return;
  }

  // ── Handle DIET proposal ────────────────────────────────────────────────
  if (proposal.proposalType === 'DIET') {
    // Deactivate existing diet plans for this client
    await prisma.dietPlan.updateMany({
      where: { clientProfileId: profileId, isActive: true },
      data: { isActive: false },
    });

    // Create new active diet plan
    const dietPlan = await prisma.dietPlan.create({
      data: {
        clientProfileId: profileId,
        clientId: clientId,
        planName: proposedData.planName || proposal.title,
        assignedById: adminId,
        assignedByName: adminName,
        dailyCalories: proposedData.dailyCalories || 2000,
        protein: proposedData.protein || 150,
        carbohydrates: proposedData.carbohydrates || 200,
        fat: proposedData.fat || 60,
        fiber: proposedData.fiber || 30,
        waterTargetLiters: proposedData.waterTargetLiters || 3.0,
        mealsJson: JSON.stringify(proposedData.mealSuggestions || []),
        notes: `AI-generated plan approved by ${adminName}. ${proposedData.notes || ''}`,
        isActive: true,
        startDate: new Date(),
      },
    });

    // Mark proposal as APPROVED
    await prisma.aIProposal.update({
      where: { id: proposal.id },
      data: {
        status: 'APPROVED',
        approvedById: adminId,
        approvedByName: adminName,
        approvedAt: new Date(),
        finalDataJson: JSON.stringify({ dietPlanId: dietPlan.id, approvedAt: new Date() }),
      },
    });

    sendSuccess(res, {
      message: `Diet plan approved and assigned to ${proposal.clientName}`,
      proposalId: proposal.id,
      dietPlanId: dietPlan.id,
    }, HttpStatus.OK);
    return;
  }

  sendError(res, 'UNKNOWN_TYPE', `Unknown proposal type: ${proposal.proposalType}`, HttpStatus.BAD_REQUEST);
});

// ── POST /api/v1/admin/ai-proposals/:id/reject ───────────────────────────────
router.post('/:id/reject', requireAuth, requireAdmin, async (req: Request, res: Response) => {
  const adminId = (req as any).user?.id || 'admin';
  const { reason } = req.body;

  const proposal = await prisma.aIProposal.findUnique({ where: { id: req.params.id } });
  if (!proposal) {
    sendError(res, 'NOT_FOUND', 'Proposal not found', HttpStatus.NOT_FOUND);
    return;
  }

  if (proposal.status !== 'PENDING') {
    sendError(res, 'INVALID_STATUS', `Proposal is already ${proposal.status}`, HttpStatus.CONFLICT);
    return;
  }

  await prisma.aIProposal.update({
    where: { id: proposal.id },
    data: {
      status: 'REJECTED',
      rejectedById: adminId,
      rejectedAt: new Date(),
      rejectionReason: reason || 'No reason provided',
    },
  });

  sendSuccess(res, { message: 'Proposal rejected', proposalId: proposal.id }, HttpStatus.OK);
});

export const aiProposalsRoutes = router;
