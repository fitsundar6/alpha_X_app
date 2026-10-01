import { Router } from 'express';
import { requireAuth, requireAdmin } from '../../middlewares/auth';
import { automationController } from './automation.controller';

const router = Router();

// ==========================================
// AUTOMATION & RULES ENGINE ROUTES
// ==========================================

// Trigger daily automation cycle (Requires Admin or internal worker auth)
router.post('/run-daily-check', requireAuth, requireAdmin, (req, res) =>
  automationController.runDailyCheck(req, res)
);

router.post('/trigger', requireAuth, requireAdmin, (req, res) =>
  automationController.runDailyCheck(req, res)
);

export const automationRoutes = router;
