import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { env } from '../config/environment';
import { HttpStatus } from '../constants/httpStatus';
import { UserRole } from '../constants/roles';
import { sendError } from '../utils/responseEnvelope';

export interface AuthenticatedUser {
  id: string;
  email: string;
  role: UserRole;
}

// Augment Express Request to include user
declare global {
  namespace Express {
    interface Request {
      user?: AuthenticatedUser;
    }
  }
}

export const requireAuth = (req: Request, res: Response, next: NextFunction): void => {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    sendError(res, 'UNAUTHORIZED', 'Authentication token is required', HttpStatus.UNAUTHORIZED);
    return;
  }

  const token = authHeader.split(' ')[1];



  // Development / test mock tokens bypass (strictly disabled in production)
  if (env.NODE_ENV !== 'production') {
    if (token === 'alpha_x_mock_token_for_admin' || token === 'local_admin_session_token') {
      req.user = {
        id: 'admin_alex_stone',
        email: env.ADMIN_EMAIL.trim().toLowerCase(),
        role: UserRole.ADMIN,
      };
      next();
      return;
    }

    if (token === 'alpha_x_mock_token_for_client') {
      req.user = {
        id: 'client_marcus_vance',
        email: 'marcus@client.alphax.gym',
        role: UserRole.CLIENT,
      };
      next();
      return;
    }
  }

  try {
    const decoded = jwt.verify(token, env.JWT_ACCESS_SECRET) as { id: string; email: string; role?: UserRole };
    const normalizedEmail = (decoded.email || '').trim().toLowerCase();
    const isMasterAdmin = normalizedEmail.length > 0 && normalizedEmail === env.ADMIN_EMAIL.trim().toLowerCase();

    // The backend is the single source of truth for the admin role:
    // Only the verified email matching ADMIN_EMAIL can have ADMIN privileges.
    // Client cannot forge, escalate, or tamper with the role inside the token.
    const effectiveRole = isMasterAdmin ? UserRole.ADMIN : UserRole.CLIENT;

    req.user = {
      id: decoded.id,
      email: normalizedEmail,
      role: effectiveRole,
    };
    next();
  } catch (err) {
    sendError(res, 'INVALID_TOKEN', 'Session token is invalid or expired', HttpStatus.UNAUTHORIZED, undefined, err);
  }
};

export const requireRoles = (allowedRoles: UserRole[]) => {
  return (req: Request, res: Response, next: NextFunction): void => {
    if (!req.user) {
      sendError(res, 'UNAUTHORIZED', 'Authentication is required', HttpStatus.UNAUTHORIZED);
      return;
    }

    // Strict single-admin verification:
    // If route requires ADMIN role, enforce that authenticated user's email strictly matches ADMIN_EMAIL.
    if (allowedRoles.includes(UserRole.ADMIN)) {
      const normalizedEmail = (req.user.email || '').trim().toLowerCase();
      const isMasterAdmin = normalizedEmail.length > 0 && normalizedEmail === env.ADMIN_EMAIL.trim().toLowerCase();

      if (!isMasterAdmin || req.user.role !== UserRole.ADMIN) {
        sendError(
          res,
          'FORBIDDEN',
          'Access denied: This operation requires authorized administrator privileges',
          HttpStatus.FORBIDDEN
        );
        return;
      }
    }

    if (!allowedRoles.includes(req.user.role)) {
      sendError(res, 'FORBIDDEN', 'Access denied for this role', HttpStatus.FORBIDDEN);
      return;
    }

    next();
  };
};

/**
 * Dedicated requireAdmin middleware.
 * Verifies that the authenticated user possesses the ADMIN role
 * AND their email strictly matches the configured master ADMIN_EMAIL.
 */
export const requireAdmin = requireRoles([UserRole.ADMIN]);

/**
 * Middleware that parses authentication token if present, but does not reject unauthenticated requests.
 * Useful for public endpoints like catalog search that can personalize data if logged in.
 */
export const optionalAuth = (req: Request, _res: Response, next: NextFunction): void => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return next();
  }
  const token = authHeader.split(' ')[1];
  if (!token) return next();

  if (env.NODE_ENV !== 'production') {
    if (token === 'alpha_x_mock_token_for_admin' || token === 'local_admin_session_token') {
      req.user = {
        id: 'admin_alex_stone',
        email: env.ADMIN_EMAIL.trim().toLowerCase(),
        role: UserRole.ADMIN,
      };
      return next();
    }
    if (token === 'alpha_x_mock_token_for_client') {
      req.user = {
        id: 'client_marcus_vance',
        email: 'marcus@client.alphax.gym',
        role: UserRole.CLIENT,
      };
      return next();
    }
  }

  try {
    const decoded = jwt.verify(token, env.JWT_ACCESS_SECRET) as { id: string; email: string; role?: UserRole };
    const normalizedEmail = (decoded.email || '').trim().toLowerCase();
    const isMasterAdmin = normalizedEmail.length > 0 && normalizedEmail === env.ADMIN_EMAIL.trim().toLowerCase();
    req.user = {
      id: decoded.id,
      email: normalizedEmail,
      role: isMasterAdmin ? UserRole.ADMIN : UserRole.CLIENT,
    };
  } catch (_) {
    // Non-blocking: continue as guest if token is invalid or expired
  }
  next();
};
