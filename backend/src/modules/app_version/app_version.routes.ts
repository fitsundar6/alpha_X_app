/**
 * Alpha X Gym — Application Version & Update Routes
 * Exposes public endpoint for client/admin version polling and
 * an administrative endpoint to broadcast updates and toggle forced update gates.
 */

import { Router, Request, Response } from 'express';
import { requireAuth, requireAdmin } from '../../middlewares/auth';
import { sendSuccess, sendError } from '../../utils/responseEnvelope';
import { HttpStatus } from '../../constants/httpStatus';
import { appVersionService, AppVersionConfig } from './app_version.service';

const router = Router();

/**
 * GET /api/v1/app/version
 * Public endpoint consumed by mobile client and admin applications on startup
 * and during periodic background refreshes.
 */
const getVersionHandler = (_req: Request, res: Response) => {
  const versionConfig = appVersionService.getVersionConfig();
  sendSuccess(res, versionConfig, HttpStatus.OK);
};

router.get('/version', getVersionHandler);
router.get('/', getVersionHandler);

/**
 * POST /api/v1/app/version
 * PUT /api/v1/app/version
 * Admin endpoint to update the minimum required version, latest release version,
 * release notes, or toggle force update flag.
 */
const updateVersionHandler = (req: Request, res: Response) => {
  try {
    const {
      latestVersion,
      minimumRequiredVersion,
      forceUpdate,
      releaseNotes,
      downloadUrl,
      playStoreUrl,
      appStoreUrl,
    } = req.body;

    const updates: Partial<AppVersionConfig> = {};

    if (typeof latestVersion === 'string' && latestVersion.trim().length > 0) {
      updates.latestVersion = latestVersion.trim();
    }
    if (typeof minimumRequiredVersion === 'string' && minimumRequiredVersion.trim().length > 0) {
      updates.minimumRequiredVersion = minimumRequiredVersion.trim();
    }
    if (typeof forceUpdate === 'boolean') {
      updates.forceUpdate = forceUpdate;
    }
    if (typeof releaseNotes === 'string' && releaseNotes.trim().length > 0) {
      updates.releaseNotes = releaseNotes.trim();
    }
    if (typeof downloadUrl === 'string' && downloadUrl.trim().length > 0) {
      updates.downloadUrl = downloadUrl.trim();
    }
    if (typeof playStoreUrl === 'string' && playStoreUrl.trim().length > 0) {
      updates.playStoreUrl = playStoreUrl.trim();
    }
    if (typeof appStoreUrl === 'string' && appStoreUrl.trim().length > 0) {
      updates.appStoreUrl = appStoreUrl.trim();
    }

    const updated = appVersionService.updateVersionConfig(updates);
    sendSuccess(res, updated, HttpStatus.OK);
  } catch (err: any) {
    sendError(
      res,
      'VERSION_UPDATE_ERROR',
      err?.message || 'Failed to update app version configuration',
      HttpStatus.BAD_REQUEST
    );
  }
};

router.post('/version', requireAuth, requireAdmin, updateVersionHandler);
router.put('/version', requireAuth, requireAdmin, updateVersionHandler);
router.patch('/version', requireAuth, requireAdmin, updateVersionHandler);
router.post('/', requireAuth, requireAdmin, updateVersionHandler);
router.put('/', requireAuth, requireAdmin, updateVersionHandler);
router.patch('/', requireAuth, requireAdmin, updateVersionHandler);

export { router as appVersionRoutes };
