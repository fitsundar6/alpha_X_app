/**
 * Alpha X Vercel Serverless Cron Routes
 *
 * Provides authenticated, retry-safe endpoints for Vercel Cron jobs, external dispatchers,
 * and safe read-only preview diagnostics:
 *   - GET /api/v1/cron/morning-sweep          (07:30 AM IST / 02:00 UTC)
 *   - GET /api/v1/cron/missed-workout-sweep   (10:30 AM IST / 05:00 UTC)
 *   - GET /api/v1/cron/evening-sweep          (08:30 PM IST / 15:00 UTC)
 *   - GET /api/v1/cron/dispatcher             (Universal smart runner, preserves distinct times)
 *   - GET /api/v1/cron/diagnostics            (Authenticated read-only dry-run diagnostics)
 *   - GET /api/v1/cron/recover-stale          (Stale pending notification recovery worker)
 *
 * All endpoints are secured by CRON_SECRET header (Authorization: Bearer <CRON_SECRET>)
 * or ?secret=<CRON_SECRET> query parameter (in non-production only).
 *
 * Security & Preview Safety:
 *   - In Vercel Preview (VERCEL_ENV === "preview"), mutating sweep execution is strictly blocked
 *     unless an isolated test database is verified.
 *   - Supports true read-only dry-run (?dryRun=true or /diagnostics) performing ZERO database writes
 *     and ZERO OneSignal dispatches.
 */

import { Router, Request, Response } from 'express';
import { env } from '../../config/environment';
import { HttpStatus } from '../../constants/httpStatus';
import { sendSuccess, sendError } from '../../utils/responseEnvelope';
import { aiNotificationEngine } from './ai_notifications.service';
import { notificationPolicyService } from './notification_policy.service';
import { automationService } from '../automation/automation.service';

const router = Router();

/**
 * Check if current runtime is a Vercel Preview deployment.
 */
export function isVercelPreview(): boolean {
  return (
    process.env.VERCEL_ENV === 'preview' ||
    (typeof env !== 'undefined' && (env as any).VERCEL_ENV === 'preview')
  );
}

/**
 * Verifies whether the configured DATABASE_URL points to a genuinely isolated database.
 * Security guard against shared production database corruption:
 *   - NEVER trusts IS_ISOLATED_TEST_DB=true alone without positive verification.
 *   - Substring checks ("test", "staging", "localhost") are rejected as unverified.
 *   - In the absence of infrastructure-attested isolation, fails closed (returns false)
 *     to prevent preview cron sweeps from ever mutating a shared production database.
 */
export function isIsolatedTestDatabase(): boolean {
  return false;
}

/**
 * Enforces Preview Data Safety:
 * All mutating cron sweeps and recovery jobs are strictly blocked in Vercel Preview deployments.
 * To guarantee that shared production databases cannot be mutated under any circumstances,
 * Preview does not permit live sweep execution and strictly requires the authenticated
 * read-only dry-run diagnostics mode (?dryRun=true or /diagnostics).
 *
 * If isolation cannot be established reliably (isIsolatedTestDatabase() returns false),
 * it fails closed with HTTP 403 (PREVIEW_SWEEP_BLOCKED).
 */
export function enforcePreviewSafety(res: Response, isDryRun: boolean): boolean {
  if (isVercelPreview() && !isDryRun) {
    if (!isIsolatedTestDatabase()) {
      console.warn('[CRON_PREVIEW_GUARD] Mutating sweep rejected: Vercel Preview deployment has no verified isolated database.');
      sendError(
        res,
        'PREVIEW_SWEEP_BLOCKED',
        'Live cron sweep execution is strictly disabled in Vercel Preview deployments to guarantee production database protection. To validate cron configuration safely without database writes or pushes, use the authenticated dry-run diagnostics endpoint (?dryRun=true).',
        HttpStatus.FORBIDDEN
      );
      return false;
    }
  }
  return true;
}

/**
 * Authentication middleware for cron routes.
 *
 * Requirements:
 *   - Production and Vercel Preview strictly require 'Authorization: Bearer <CRON_SECRET>'.
 *   - Query-parameter credentials (?secret=...) are strictly rejected in production and preview.
 *   - Fails closed if CRON_SECRET is missing or empty on server.
 *   - Preserves non-production query parameter convenience only when NODE_ENV !== 'production' and not preview.
 *   - Never logs secrets or exposes expected tokens in response bodies.
 */
export function verifyCronSecret(req: Request, res: Response, next: () => void): void {
  const isStrictEnv =
    env.NODE_ENV === 'production' ||
    process.env.NODE_ENV === 'production' ||
    isVercelPreview();
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

  // Security rule: Query-parameter secrets are strictly forbidden in production and preview
  if (isStrictEnv && querySecret) {
    console.warn('[CRON_AUTH] Security violation: Query-parameter secret rejected in production/preview environment');
    sendError(
      res,
      'UNAUTHORIZED',
      'Query parameter authentication is not permitted in production or preview environments. Use Authorization: Bearer <token>',
      HttpStatus.UNAUTHORIZED
    );
    return;
  }

  // In local dev non-strict mode, permit query parameter as a fallback
  const providedSecret = bearerToken || (!isStrictEnv ? querySecret : null);

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
router.get('/morning-sweep', verifyCronSecret, async (req: Request, res: Response) => {
  const isDryRun = req.query.dryRun === 'true' || req.query.dryRun === '1';

  if (isDryRun) {
    const diagnostics = await aiNotificationEngine.runDryRunDiagnostics('MORNING_READINESS');
    sendSuccess(res, diagnostics, HttpStatus.OK);
    return;
  }

  if (!enforcePreviewSafety(res, isDryRun)) {
    return;
  }

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
router.get('/missed-workout-sweep', verifyCronSecret, async (req: Request, res: Response) => {
  const isDryRun = req.query.dryRun === 'true' || req.query.dryRun === '1';

  if (isDryRun) {
    const diagnostics = await aiNotificationEngine.runDryRunDiagnostics('MISSED_WORKOUT_CHECK_IN');
    sendSuccess(res, diagnostics, HttpStatus.OK);
    return;
  }

  if (!enforcePreviewSafety(res, isDryRun)) {
    return;
  }

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
router.get('/evening-sweep', verifyCronSecret, async (req: Request, res: Response) => {
  const isDryRun = req.query.dryRun === 'true' || req.query.dryRun === '1';

  if (isDryRun) {
    const diagnostics = await aiNotificationEngine.runDryRunDiagnostics('EVENING_NUTRITION_AND_RECOVERY');
    sendSuccess(res, diagnostics, HttpStatus.OK);
    return;
  }

  if (!enforcePreviewSafety(res, isDryRun)) {
    return;
  }

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

// ── GET /daily-automation ─────────────────────────────────────────────────────
// Daily Client Automation & Membership Expiry Sweep (Membership, Payment Reminders, Inactivity)
router.get('/daily-automation', verifyCronSecret, async (req: Request, res: Response) => {
  const isDryRun = req.query.dryRun === 'true' || req.query.dryRun === '1';

  if (isDryRun) {
    const diagnostics = await aiNotificationEngine.runDryRunDiagnostics('ALL');
    sendSuccess(res, diagnostics, HttpStatus.OK);
    return;
  }

  if (!enforcePreviewSafety(res, isDryRun)) {
    return;
  }

  try {
    console.log('[CRON_ROUTE] Authenticated trigger: Daily Automation & Membership Expiry Sweep');
    const result = await automationService.runDailyAutomationCycle();
    sendSuccess(
      res,
      {
        sweep: 'DAILY_AUTOMATION_CYCLE',
        scheduledIst: '09:00 AM IST',
        result,
      },
      HttpStatus.OK
    );
  } catch (err: any) {
    console.error('[CRON_ROUTE] Daily automation cycle error:', err?.message);
    sendError(res, 'CRON_EXECUTION_FAILED', err?.message || 'Daily automation cycle failed', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

// ── GET /dispatcher ───────────────────────────────────────────────────────────
// Universal dispatcher for Vercel Hobby (2 crons) or external scheduled triggers.
// Preserves distinct execution times and never runs all three together.
router.get('/dispatcher', verifyCronSecret, async (req: Request, res: Response) => {
  const isDryRun = req.query.dryRun === 'true' || req.query.dryRun === '1';

  if (isDryRun) {
    const diagnostics = await aiNotificationEngine.runDryRunDiagnostics('DISPATCHER');
    sendSuccess(res, diagnostics, HttpStatus.OK);
    return;
  }

  if (!enforcePreviewSafety(res, isDryRun)) {
    return;
  }

  const job = (req.query.job as string) || 'auto';

  try {
    if (job === 'morning') {
      const result = await aiNotificationEngine.runMorningCheckInSweep();
      sendSuccess(res, { executed: 'morning', result }, HttpStatus.OK);
      return;
    }

    if (job === 'automation') {
      const result = await automationService.runDailyAutomationCycle();
      sendSuccess(res, { executed: 'automation', result }, HttpStatus.OK);
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

// ── GET /diagnostics ─────────────────────────────────────────────────────────
// Dedicated authenticated read-only diagnostics endpoint
router.get('/diagnostics', verifyCronSecret, async (_req: Request, res: Response) => {
  try {
    const diagnostics = await aiNotificationEngine.runDryRunDiagnostics('ALL');
    sendSuccess(res, diagnostics, HttpStatus.OK);
  } catch (err: any) {
    sendError(res, 'DIAGNOSTICS_FAILED', err?.message || 'Dry-run diagnostics failed', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

// ── GET /recover-stale ────────────────────────────────────────────────────────
router.get('/recover-stale', verifyCronSecret, async (req: Request, res: Response) => {
  const isDryRun = req.query.dryRun === 'true' || req.query.dryRun === '1';

  if (isDryRun) {
    sendSuccess(
      res,
      {
        dryRun: true,
        task: 'RECOVER_STALE_PENDING',
        mode: 'READ_ONLY_SIMULATION',
        databaseWrites: 0,
        oneSignalDispatches: 0,
      },
      HttpStatus.OK
    );
    return;
  }

  if (!enforcePreviewSafety(res, isDryRun)) {
    return;
  }

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
