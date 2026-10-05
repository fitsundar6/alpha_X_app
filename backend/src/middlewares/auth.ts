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
    sendError(
      res,
      'UNAUTHORIZED',
      'Invalid/expired authentication token: Missing Authorization header',
      HttpStatus.UNAUTHORIZED,
      undefined,
      undefined,
      {
        activity: 'Verify Authentication Token',
        explanation: !authHeader
          ? 'No Authorization header was provided in the request. Athletes and admins must send "Authorization: Bearer <token>".'
          : 'Authorization header did not start with "Bearer ".',
      }
    );
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
    let decoded: { id: string; email: string; role?: UserRole };
    try {
      decoded = jwt.verify(token, env.JWT_ACCESS_SECRET) as { id: string; email: string; role?: UserRole };
    } catch (verifyErr: any) {
      if (verifyErr?.name === 'TokenExpiredError') {
        // Grace period for authentic tokens signed with our secret (e.g. issued with earlier 15m expiration)
        const unexpiredPayload = jwt.verify(token, env.JWT_ACCESS_SECRET, { ignoreExpiration: true }) as {
          id: string;
          email: string;
          role?: UserRole;
          exp?: number;
        };
        const expTimeMs = (unexpiredPayload.exp || 0) * 1000;
        const gracePeriodMs = 30 * 24 * 60 * 60 * 1000; // 30-day grace period
        if (Date.now() - expTimeMs < gracePeriodMs) {
          decoded = unexpiredPayload;
        } else {
          throw verifyErr;
        }
      } else {
        throw verifyErr;
      }
    }

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
  } catch (err: any) {
    const isExpired = err?.name === 'TokenExpiredError';
    sendError(
      res,
      'INVALID_TOKEN',
      isExpired ? 'Invalid/expired authentication token' : 'Session token is invalid or corrupted',
      HttpStatus.UNAUTHORIZED,
      undefined,
      err,
      {
        activity: 'Verify Authentication Token',
        explanation: isExpired
          ? `JWT token expired at ${err?.expiredAt ? new Date(err.expiredAt).toISOString() : 'earlier'}. Please log in again to refresh your session.`
          : `JWT verification failed (${err?.message || 'invalid signature'}).`,
      }
    );
  }
};

export const requireRoles = (allowedRoles: UserRole[]) => {
  return (req: Request, res: Response, next: NextFunction): void => {
    if (!req.user) {
      sendError(
        res,
        'UNAUTHORIZED',
        'Authentication is required',
        HttpStatus.UNAUTHORIZED,
        undefined,
        undefined,
        {
          activity: 'Verify Role Authorization',
          explanation: 'No authenticated user identity found on request.',
        }
      );
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
          HttpStatus.FORBIDDEN,
          undefined,
          undefined,
          {
            activity: 'Authorize Admin Role',
            explanation: `User "${req.user.email}" (Role: ${req.user.role}) is not authorized for administrator endpoints. Master admin email is "${env.ADMIN_EMAIL}".`,
          }
        );
        return;
      }
    }

    if (!allowedRoles.includes(req.user.role)) {
      sendError(
        res,
        'FORBIDDEN',
        `Access denied for role "${req.user.role}"`,
        HttpStatus.FORBIDDEN,
        undefined,
        undefined,
        {
          activity: 'Verify Role Authorization',
          explanation: `Endpoint requires one of roles [${allowedRoles.join(', ')}], but user has role "${req.user.role}".`,
        }
      );
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
