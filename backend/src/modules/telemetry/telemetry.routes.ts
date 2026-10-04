/**
 * Alpha X — Weekly Telemetry HTTP Routes
 * Exposes endpoints for Client "Spotify-Wrapped" Telemetry and Admin Overview Dossiers
 */

import { Router, Request, Response } from 'express';
import { requireAuth, requireAdmin } from '../../middlewares/auth';
import { sendSuccess, sendError } from '../../utils/responseEnvelope';
import { HttpStatus } from '../../constants/httpStatus';
import { telemetryService } from './telemetry.service';

const router = Router();

/**
 * GET /api/v1/telemetry/client/weekly-report
 * Logged-in client fetches their Sunday Telemetry report card.
 * Query param: ?date=YYYY-MM-DD (optional, defaults to today/current week)
 */
router.get('/client/weekly-report', requireAuth, async (req: Request, res: Response) => {
  const clientId = (req as any).user?.id;
  const dateParam = req.query.date as string | undefined;
  const refDate = dateParam ? new Date(dateParam) : new Date();

  try {
    const report = await telemetryService.generateWeeklyTelemetry(clientId, refDate);
    sendSuccess(res, report, HttpStatus.OK);
  } catch (err: any) {
    console.error('[TELEMETRY] Failed to generate client telemetry:', err?.message);
    sendError(res, 'TELEMETRY_ERROR', err?.message || 'Failed to generate weekly telemetry report', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

/**
 * GET /api/v1/telemetry/admin/overview
 * Admin views all clients ranked by total tonnage, adherence, and PRs.
 * Query param: ?date=YYYY-MM-DD (optional)
 */
router.get('/admin/overview', requireAuth, requireAdmin, async (req: Request, res: Response) => {
  const dateParam = req.query.date as string | undefined;
  const refDate = dateParam ? new Date(dateParam) : new Date();

  try {
    const overview = await telemetryService.getAdminWeeklyTelemetryOverview(refDate);
    sendSuccess(res, overview, HttpStatus.OK);
  } catch (err: any) {
    console.error('[TELEMETRY] Failed to fetch admin telemetry overview:', err?.message);
    sendError(res, 'TELEMETRY_OVERVIEW_ERROR', err?.message || 'Failed to fetch overview', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

/**
 * GET /api/v1/telemetry/admin/client/:clientId
 * Admin fetches detailed telemetry dossier for a specific client.
 */
router.get('/admin/client/:clientId', requireAuth, requireAdmin, async (req: Request, res: Response) => {
  const clientId = String(req.params.clientId);
  const dateParam = req.query.date as string | undefined;
  const refDate = dateParam ? new Date(dateParam) : new Date();

  try {
    const report = await telemetryService.generateWeeklyTelemetry(clientId, refDate);
    sendSuccess(res, report, HttpStatus.OK);
  } catch (err: any) {
    sendError(res, 'CLIENT_TELEMETRY_ERROR', err?.message || 'Failed to fetch client telemetry', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

/**
 * POST /api/v1/telemetry/admin/trigger-dispatch
 * Admin manually triggers the Sunday Telemetry push dispatch sweep for all active clients.
 */
router.post('/admin/trigger-dispatch', requireAuth, requireAdmin, async (req: Request, res: Response) => {
  try {
    const result = await telemetryService.dispatchSundayTelemetrySweep();
    sendSuccess(res, { message: 'Sunday Telemetry dispatch completed', ...result }, HttpStatus.OK);
  } catch (err: any) {
    sendError(res, 'DISPATCH_ERROR', err?.message || 'Failed to dispatch telemetry', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

export const telemetryRoutes = router;
