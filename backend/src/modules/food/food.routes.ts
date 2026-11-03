import express, { Router, Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { env } from '../../config/environment';
import { UserRole } from '../../constants/roles';
import { requireAuth, requireAdmin } from '../../middlewares/auth';
import { foodController } from './food.controller';

const router = Router();

/**
 * Optional authentication middleware for read queries.
 * Validates cryptographic JWT signature strictly without accepting expired tokens
 * or caller-supplied identity headers. If token is absent or invalid, req.user remains undefined.
 */
const optionalAuth = (req: Request, _res: Response, next: NextFunction) => {
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    const token = authHeader.split(' ')[1];
    try {
      const decoded = jwt.verify(token, env.JWT_ACCESS_SECRET) as any;
      if (decoded) {
        const normalizedEmail = (decoded.email || '').trim().toLowerCase();
        const isMasterAdmin = normalizedEmail.length > 0 && normalizedEmail === env.ADMIN_EMAIL.trim().toLowerCase();
        req.user = {
          id: decoded.id || decoded.clientId || 'client_user',
          email: normalizedEmail,
          role: isMasterAdmin ? UserRole.ADMIN : UserRole.CLIENT,
        };
      }
    } catch (_) {
      // Ignore invalid/expired token on optional auth read queries
    }
  }

  next();
};

// ==========================================
// FOOD API ROUTES
// ==========================================

// Seed / sync endpoint (Admin only)
router.post('/seed', requireAuth, requireAdmin, (req, res) => foodController.seedDatabase(req, res));

// Query and read foods (Public catalog search with optional auth for personal items)
router.get('/', optionalAuth, (req, res) => foodController.searchFoods(req, res));
router.get('/:id', optionalAuth, (req, res) => foodController.getFoodById(req, res));

// AI Food Camera Scanner endpoint (strictly authenticated; user quota and abuse protection)
router.post('/ai-scan', requireAuth, express.json({ limit: '10mb' }), (req, res) => foodController.analyzeFoodImage(req, res));

// Create custom food (requires authenticated user; derived strictly from token)
router.post('/', requireAuth, (req, res) => foodController.createCustomFood(req, res));

// Delete custom food (requires authenticated user; creator or admin only)
router.delete('/:id', requireAuth, (req, res) => foodController.deleteFood(req, res));

export const foodRoutes = router;
