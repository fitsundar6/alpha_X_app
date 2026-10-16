/**
 * Alpha X Vercel Serverless Cron Routes
 *
 * Provides authenticated, retry-safe endpoints for Vercel Cron jobs and external dispatchers:
 *   - GET /api/v1/cron/morning-sweep          (07:30 AM IST / 02:00 UTC)
 *   - GET /api/v1/cron/missed-workout-sweep   (10:30 AM IST / 05:00 UTC)
 *   - GET /api/v1/cron/evening-sweep          (08:30 PM IST / 15:00 UTC)
 *   - GET /api/v1/cron/dispatcher             (Universal smart runner, preserves distinct times)
 *
 * All endpoints are secured by CRON_SECRET header (Authorization: Bearer <CRON_SECRET>)
 * or ?secret=<CRON_SECRET> query parameter.
 */

import { Router, Request, Response } from 'express';
import { env } from '../../config/environment';
import { HttpStatus } from '../../constants/httpStatus';
import { sendSuccess, sendError } from '../../utils/responseEnvelope';
import { aiNotificationEngine } from './ai_notifications.service';
import { notificationPolicyService } from './notification_policy.service';

const router = Router();

/**
 * Authentication middleware for cron routes.
 *
 * Requirements:
 *   - Production strictly requires 'Authorization: Bearer <CRON_SECRET>'.
 *   - Query-parameter credentials (?secret=...) are strictly rejected in production to prevent leaking tokens in logs/URLs.
 *   - Fails closed if CRON_SECRET is missing or empty on server.
 *   - Preserves non-production query parameter convenience only when NODE_ENV !== 'production'.
 *   - Never logs secrets or exposes expected tokens in response bodies.
 */
export function verifyCronSecret(req: Request, res: Response, next: () => void): void {
  const isProduction = env.NODE_ENV === 'production' || process.env.NODE_ENV === 'production';
  const expectedSecret = env.CRON_SECRET;

  // Fail closed if server has no configured CRON_SECRET
  if (!expectedSecret || typeof expectedSecret !== 'string' || expectedSecret.trim().length === 0) {
    console.error('[CRON_AUTH] Access denied: Server has no configured CRON_SECRET');
    sendError(res, 'UNAUTHORIZED', 'Cron execution is not configured', HttpStatus.UNAUTHORIZED);
    return;
  }

  const authHeader = req.headers['authorization'];
  const hasBearer = typeof authHeader === 'string' && authHeader.startsWith('Bearer ');
  const bearerToken = hasBearer ? authHeader.substring(7).trim() : null;
  const querySecret = typeof req.query.secret === 'string' ? req.query.secret.trim() : null;

  // Production security rule: Query-parameter secrets are strictly forbidden
  if (isProduction && querySecret) {
    console.warn('[CRON_AUTH] Security violation: Query-parameter secret rejected in production environment');
    sendError(
      res,
      'UNAUTHORIZED',
      'Query parameter authentication is not permitted in production. Use Authorization: Bearer <token>',
      HttpStatus.UNAUTHORIZED
    );
    return;
  }

  // In non-production, permit query parameter as a fallback
  const providedSecret = bearerToken || (!isProduction ? querySecret : null);

  if (!providedSecret) {
    sendError(res, 'UNAUTHORIZED', 'Missing authorization header', HttpStatus.UNAUTHORIZED);
    return;
  }

  if (providedSecret !== expectedSecret) {
    console.warn('[CRON_AUTH] Unauthorized request: Invalid cron secret provided');
    sendError(res, 'UNAUTHORIZED', 'Invalid authorization token', HttpStatus.UNAUTHORIZED);
    return;
  }

  next();
}

// ── GET /morning-sweep ─────────────────────────────────────────────────────────
router.get('/morning-sweep', verifyCronSecret, async (_req: Request, res: Response) => {
  try {
    console.log('[CRON_ROUTE] Authenticated trigger: Morning Readiness Sweep');
    const result = await aiNotificationEngine.runMorningCheckInSweep();
    sendSuccess(
      res,
      {
        sweep: 'MORNING_READINESS',
        scheduledIst: '07:30 AM IST',
        scheduledUtc: '02:00 UTC',
        result,
      },
      HttpStatus.OK
    );
  } catch (err: any) {
    console.error('[CRON_ROUTE] Morning sweep error:', err?.message);
    sendError(res, 'CRON_EXECUTION_FAILED', err?.message || 'Morning sweep failed', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

// ── GET /missed-workout-sweep ──────────────────────────────────────────────────
router.get('/missed-workout-sweep', verifyCronSecret, async (_req: Request, res: Response) => {
  try {
    console.log('[CRON_ROUTE] Authenticated trigger: Missed Workout Sweep');
    const result = await aiNotificationEngine.runMissedWorkoutSweep();
    sendSuccess(
      res,
      {
        sweep: 'MISSED_WORKOUT_CHECK_IN',
        scheduledIst: '10:30 AM IST',
        scheduledUtc: '05:00 UTC',
        result,
      },
      HttpStatus.OK
    );
  } catch (err: any) {
    console.error('[CRON_ROUTE] Missed workout sweep error:', err?.message);
    sendError(res, 'CRON_EXECUTION_FAILED', err?.message || 'Missed workout sweep failed', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

// ── GET /evening-sweep ────────────────────────────────────────────────────────
router.get('/evening-sweep', verifyCronSecret, async (_req: Request, res: Response) => {
  try {
    console.log('[CRON_ROUTE] Authenticated trigger: Evening Sweep');
    const result = await aiNotificationEngine.runEveningCheckInSweep();
    sendSuccess(
      res,
      {
        sweep: 'EVENING_NUTRITION_AND_RECOVERY',
        scheduledIst: '08:30 PM IST',
        scheduledUtc: '15:00 UTC',
        result,
      },
      HttpStatus.OK
    );
  } catch (err: any) {
    console.error('[CRON_ROUTE] Evening sweep error:', err?.message);
    sendError(res, 'CRON_EXECUTION_FAILED', err?.message || 'Evening sweep failed', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

// ── GET /dispatcher ───────────────────────────────────────────────────────────
// Universal dispatcher for Vercel Hobby (2 crons) or external scheduled triggers.
// Preserves distinct execution times and never runs all three together.
router.get('/dispatcher', verifyCronSecret, async (req: Request, res: Response) => {
  const job = (req.query.job as string) || 'auto';

  try {
    if (job === 'morning') {
      const result = await aiNotificationEngine.runMorningCheckInSweep();
      sendSuccess(res, { executed: 'morning', result }, HttpStatus.OK);
      return;
    }

    if (job === 'missed') {
      const result = await aiNotificationEngine.runMissedWorkoutSweep();
      sendSuccess(res, { executed: 'missed', result }, HttpStatus.OK);
      return;
    }

    if (job === 'evening') {
      const result = await aiNotificationEngine.runEveningCheckInSweep();
      sendSuccess(res, { executed: 'evening', result }, HttpStatus.OK);
      return;
    }

    if (job === 'auto') {
      // Determine which sweep to run based on current hour in Asia/Kolkata
      const { hour } = notificationPolicyService.getLocalTimeParts('Asia/Kolkata');
      if (hour >= 6 && hour < 10) {
        // Morning window (07:30 IST)
        const result = await aiNotificationEngine.runMorningCheckInSweep();
        sendSuccess(res, { executed: 'auto_morning', hourIST: hour, result }, HttpStatus.OK);
        return;
      } else if (hour >= 10 && hour < 14) {
        // Mid-morning window (10:30 IST)
        const result = await aiNotificationEngine.runMissedWorkoutSweep();
        sendSuccess(res, { executed: 'auto_missed', hourIST: hour, result }, HttpStatus.OK);
        return;
      } else if (hour >= 19 && hour <= 22) {
        // Evening window (20:30 IST)
        const result = await aiNotificationEngine.runEveningCheckInSweep();
        sendSuccess(res, { executed: 'auto_evening', hourIST: hour, result }, HttpStatus.OK);
        return;
      } else {
        // Outside scheduled windows: process any deferred quiet-hours queue only
        const deferred = await notificationPolicyService.processDeferredQueue();
        sendSuccess(
          res,
          {
            executed: 'deferred_only',
            hourIST: hour,
            message: 'Outside scheduled sweep windows. Processed deferred queue.',
            deferred,
          },
          HttpStatus.OK
        );
        return;
      }
    }

    sendError(res, 'BAD_REQUEST', `Unknown job "${job}". Valid options: morning, missed, evening, auto`, HttpStatus.BAD_REQUEST);
  } catch (err: any) {
    sendError(res, 'DISPATCH_ERROR', err?.message || 'Dispatcher failed', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

// ── GET /recover-stale ────────────────────────────────────────────────────────
router.get('/recover-stale', verifyCronSecret, async (_req: Request, res: Response) => {
  try {
    console.log('[CRON_ROUTE] Authenticated trigger: Stale Notification Recovery');
    const result = await notificationPolicyService.recoverStalePendingNotifications();
    sendSuccess(res, { task: 'RECOVER_STALE_PENDING', result }, HttpStatus.OK);
  } catch (err: any) {
    console.error('[CRON_ROUTE] Stale recovery error:', err?.message);
    sendError(res, 'RECOVERY_FAILED', err?.message || 'Stale recovery failed', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

export default router;
