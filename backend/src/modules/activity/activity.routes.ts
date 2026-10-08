import { Router } from 'express';
import { activityController } from './activity.controller';
import { requireAuth, requireRoles, requireApprovedUser } from '../../middlewares/auth';
import { UserRole } from '../../constants/roles';

const router = Router();

// Client routes (Authenticated and Approved client only)
router.post('/sync', requireAuth, requireApprovedUser, (req, res, next) => activityController.syncActivity(req, res, next));
router.get('/today', requireAuth, requireApprovedUser, (req, res, next) => activityController.getToday(req, res, next));
router.get('/history', requireAuth, requireApprovedUser, (req, res, next) => activityController.getHistory(req, res, next));

// Admin management routes
router.get(
  '/client/:clientId',
  requireAuth,
  requireRoles([UserRole.ADMIN]),
  (req, res, next) => activityController.inspectClient(req, res, next)
);

router.put(
  '/client/:clientId/goal',
  requireAuth,
  requireRoles([UserRole.ADMIN]),
  (req, res, next) => activityController.updateGoal(req, res, next)
);

export const activityRoutes = router;
