/**
 * Alpha X — Notifications Routes
 *
 * POST /api/v1/notifications/register-device
 *   Client registers their OneSignal player ID after login.
 *
 * POST /api/v1/admin/notifications/trigger-sweep
 *   Admin manually triggers the AI notification sweep for all clients.
 *
 * PATCH /api/v1/notifications/opt-out
 *   Client can disable notifications.
 */

import { Router, Request, Response } from 'express';
import { requireAuth, requireAdmin } from '../../middlewares/auth';
import { prisma } from '../../config/prisma';
import { HttpStatus } from '../../constants/httpStatus';
import { sendSuccess, sendError } from '../../utils/responseEnvelope';
import { aiNotificationEngine } from './ai_notifications.service';

const router = Router();

/**
 * POST /register-device
 * Client app calls this on login to register/update their push token.
 */
router.post('/register-device', requireAuth, async (req: Request, res: Response) => {
  const userId = (req as any).user?.id;
  const { playerId } = req.body;

  if (!playerId || typeof playerId !== 'string') {
    sendError(res, 'VALIDATION_ERROR', 'playerId is required', HttpStatus.BAD_REQUEST);
    return;
  }

  try {
    await prisma.user.update({
      where: { id: userId },
      data: { oneSignalPlayerId: playerId },
    });
    sendSuccess(res, { registered: true }, HttpStatus.OK);
  } catch (err: any) {
    sendError(res, 'DB_ERROR', 'Failed to register device', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

/**
 * PATCH /opt-out
 * Client disables or re-enables push notifications.
 */
router.patch('/opt-out', requireAuth, async (req: Request, res: Response) => {
  const userId = (req as any).user?.id;
  const { enabled } = req.body; // boolean

  try {
    await prisma.user.update({
      where: { id: userId },
      data: { notificationsEnabled: enabled !== false },
    });
    sendSuccess(res, { notificationsEnabled: enabled !== false }, HttpStatus.OK);
  } catch (err: any) {
    sendError(res, 'DB_ERROR', 'Failed to update preference', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

/**
 * POST /admin/trigger-sweep (Admin only)
 * Manually triggers the daily AI notification sweep.
 * Useful for testing without waiting for 6 PM.
 */
router.post('/admin/trigger-sweep', requireAuth, requireAdmin, async (req: Request, res: Response) => {
  try {
    // Run in background — don't await so the request returns immediately
    aiNotificationEngine.runDailySweep().catch((err) =>
      console.error('[NOTIFICATIONS] Manual sweep error:', err?.message)
    );
    sendSuccess(res, { message: 'Daily AI notification sweep triggered' }, HttpStatus.OK);
  } catch (err: any) {
    sendError(res, 'SWEEP_ERROR', 'Failed to trigger sweep', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

export const notificationsRoutes = router;
