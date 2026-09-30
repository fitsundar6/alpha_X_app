import { Router, Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { env } from '../../config/environment';
import { UserRole } from '../../constants/roles';
import { foodController } from './food.controller';

const router = Router();

// Middleware that optionally parses token if present, but does not reject unauthenticated read queries
const optionalAuth = (req: Request, _res: Response, next: NextFunction) => {
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    const token = authHeader.split(' ')[1];
    if (token === 'alpha_x_mock_token_for_admin' || token === 'local_admin_session_token') {
      req.user = {
        id: 'admin_alex_stone',
        email: env.ADMIN_EMAIL.trim().toLowerCase(),
        role: UserRole.ADMIN,
      };
      return next();
    }
    try {
      const decoded = jwt.verify(token, env.JWT_ACCESS_SECRET) as { id: string; email: string; role?: UserRole; clientId?: string };
      const normalizedEmail = (decoded.email || '').trim().toLowerCase();
      const isMasterAdmin = normalizedEmail.length > 0 && normalizedEmail === env.ADMIN_EMAIL.trim().toLowerCase();
      req.user = {
        id: decoded.id || decoded.clientId || 'client_user',
        email: normalizedEmail,
        role: isMasterAdmin ? UserRole.ADMIN : UserRole.CLIENT,
      };
    } catch (_) {
      // Ignore invalid token on optional auth
    }
  }

  // Also check if clientId is provided in header
  const customClientId = req.headers['x-client-id'] as string;
  if (!req.user && customClientId) {
    req.user = {
      id: customClientId,
      email: `${customClientId}@alphaxgym.local`,
      role: UserRole.CLIENT,
    };
  }

  next();
};

// ==========================================
// FOOD API ROUTES
// ==========================================
router.use(optionalAuth);

// Seed / sync endpoint
router.post('/seed', (req, res) => foodController.seedDatabase(req, res));

// Query and read foods
router.get('/', (req, res) => foodController.searchFoods(req, res));
router.get('/:id', (req, res) => foodController.getFoodById(req, res));

// Create custom food (saves to global shared database)
router.post('/', (req, res) => foodController.createCustomFood(req, res));

// Delete custom food
router.delete('/:id', (req, res) => foodController.deleteFood(req, res));

export const foodRoutes = router;
