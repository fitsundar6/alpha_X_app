import { Router, Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import crypto from 'crypto';
import { requireAuth } from '../../middlewares/auth';
import { sendSuccess, sendError } from '../../utils/responseEnvelope';
import { UserRole, UserStatus } from '../../constants/roles';
import { env } from '../../config/environment';
import { HttpStatus } from '../../constants/httpStatus';
import rateLimit from 'express-rate-limit';
import { adminAuthService } from './admin_auth.service';
import { refreshTokenService } from './refresh_token.service';
import { prisma } from '../../config/prisma';
import { passwordResetService } from '../../services/password_reset.service';
import { emailService } from '../../services/email.service';

const router = Router();

// Rate limiter for forgot-password requests to prevent abuse
const forgotPasswordRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 15, // Up to 15 requests per IP
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    error: {
      code: 'TOO_MANY_REQUESTS',
      message: 'Too many password reset requests. Please try again later.',
    },
  },
});

// Dedicated brute-force rate limiter for login endpoints (stricter than general 300/15min)
const loginRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10, // Max 10 login attempts per IP per window
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    error: {
      code: 'TOO_MANY_REQUESTS',
      message: 'Too many login attempts. Please wait 15 minutes before trying again.',
    },
  },
});

// Rate limiter for registration to prevent spam account creation
const registerRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // Max 5 registrations per IP per window
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    error: {
      code: 'TOO_MANY_REQUESTS',
      message: 'Too many registration attempts. Please try again later.',
    },
  },
});

/**
 * Generates the next sequential unique Client ID in format AXG-XXXX (e.g. AXG-0001).
 * Permanent, immutable string identifier.
 * Uses highest existing ID to avoid collisions and supports optional database transaction client.
 */
export async function generateNextClientId(tx?: any): Promise<string> {
  const db = tx || prisma;
  // Fetch the latest profiles ordered descending by clientId to get the highest numeric AXG-XXXX
  const latestProfiles = await db.clientProfile.findMany({
    where: { clientId: { startsWith: 'AXG-' } },
    select: { clientId: true },
    orderBy: { clientId: 'desc' },
    take: 50,
  });

  let maxNum = 0;
  for (const profile of latestProfiles) {
    if (profile.clientId) {
      const match = profile.clientId.match(/^AXG-(\d+)$/i);
      if (match) {
        const parsed = parseInt(match[1], 10);
        if (!isNaN(parsed) && parsed > maxNum) {
          maxNum = parsed;
        }
      }
    }
  }

  if (maxNum === 0) {
    const totalCount = await db.clientProfile.count();
    maxNum = totalCount;
  }

  let candidateNum = maxNum + 1;
  while (true) {
    const candidateId = `AXG-${String(candidateNum).padStart(4, '0')}`;
    const existing = await db.clientProfile.findUnique({
      where: { clientId: candidateId },
    });
    if (!existing) {
      return candidateId;
    }
    candidateNum++;
  }
}

/**
 * GET /api/v1/auth/me
 * Profile endpoint used by client/mobile app to verify active session and role.
 * Derived strictly from verified user email against backend ADMIN_EMAIL.
 */
router.get('/me', requireAuth, async (req: Request, res: Response) => {
  const user = req.user!;
  const normalizedEmail = (user.email || '').trim().toLowerCase();
  const configuredAdminEmail = env.ADMIN_EMAIL.trim().toLowerCase();
  const isMasterAdmin = normalizedEmail.length > 0 && normalizedEmail === configuredAdminEmail;
  const role = isMasterAdmin ? UserRole.ADMIN : UserRole.CLIENT;

  let profileData: any = null;
  let userStatus: UserStatus = UserStatus.APPROVED;
  let rejectionReason: string | null = null;
  let rejectedAt: string | null = null;
  let approvedAt: string | null = null;
  let mustChangePassword = false;

  if (!isMasterAdmin) {
    const dbUser = await prisma.user.findUnique({
      where: { id: user.id },
      select: {
        status: true,
        rejectionReason: true,
        rejectedAt: true,
        approvedAt: true,
        mustChangePassword: true,
      },
    });
    if (dbUser) {
      userStatus = dbUser.status as UserStatus;
      rejectionReason = dbUser.rejectionReason;
      rejectedAt = dbUser.rejectedAt ? dbUser.rejectedAt.toISOString() : null;
      approvedAt = dbUser.approvedAt ? dbUser.approvedAt.toISOString() : null;
      mustChangePassword = dbUser.mustChangePassword ?? false;
    }

    const dbProfile = await prisma.clientProfile.findUnique({
      where: { userId: user.id },
      include: {
        dietPlans: { where: { isActive: true }, take: 1 },
        macroPlans: { where: { isActive: true }, take: 1 },
      },
    });
    profileData = dbProfile;
  }

  sendSuccess(res, {
    id: user.id,
    email: normalizedEmail,
    name: role === UserRole.ADMIN ? 'Alpha X Administrator' : (user as any).name || 'Athlete Member',
    role,
    status: userStatus,
    rejectionReason,
    rejectedAt,
    approvedAt,
    mustChangePassword,
    clientId: profileData?.clientId ?? (role === UserRole.ADMIN ? 'AXG-ADMIN' : null),
    assessmentCompleted: profileData?.onboardingCompleted ?? false,
    onboardingCompleted: profileData?.onboardingCompleted ?? false,
    onboardingStep: profileData?.onboardingStep ?? 0,
    profile: profileData,
  });
});

/**
 * POST /api/v1/auth/refresh
 * Refreshes a valid, non-expired session token for the currently authenticated user.
 * F-04: Requires a currently-valid (non-expired) token. The 30-day grace period for
 * expired tokens has been removed. Expired tokens must re-authenticate via /login.
 * Returns a fresh JWT with the current tokenVersion embedded.
 */
/**
 * POST /api/v1/auth/refresh
 * Phase 7: Atomic single-use refresh token rotation.
 * Accepts { refreshToken } in request body, rotates the token atomically in PostgreSQL,
 * and issues a new 15-minute access token and new 30-day refresh token.
 * Master Admin (BUG-04) continues using dedicated durable revocation via Authorization header.
 */
router.post('/refresh', async (req: Request, res: Response) => {
  const { refreshToken, deviceInfo } = req.body || {};

  // Phase 7 Client Refresh Token Flow
  if (refreshToken && typeof refreshToken === 'string' && refreshToken.trim().length > 0) {
    try {
      const result = await refreshTokenService.rotateRefreshToken(
        refreshToken,
        deviceInfo || (req.headers['user-agent'] as string)
      );

      if (result.status === 'SUCCESS') {
        sendSuccess(res, result.data, HttpStatus.OK, 'Token refreshed successfully');
        return;
      }

      sendError(res, result.errorCode, result.message, result.httpStatus);
      return;
    } catch (err: any) {
      sendError(
        res,
        'INTERNAL_ERROR',
        'Token refresh failed',
        HttpStatus.INTERNAL_SERVER_ERROR,
        undefined,
        err
      );
      return;
    }
  }

  // Check for Master Admin Bearer token refresh (BUG-04 preservation)
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    const token = authHeader.split(' ')[1];
    try {
      const decoded = jwt.verify(token, env.JWT_ACCESS_SECRET) as {
        id: string;
        email: string;
        role?: UserRole;
        tokenVersion?: number;
        sessionId?: string;
      };

      const normalizedEmail = (decoded.email || '').trim().toLowerCase();
      const isMasterAdmin =
        normalizedEmail.length > 0 &&
        normalizedEmail === env.ADMIN_EMAIL.trim().toLowerCase();

      if (isMasterAdmin) {
        // BUG-04: Master Admin session revocation validation on refresh (durable PostgreSQL backed)
        try {
          const isRevoked = await adminAuthService.isRevoked(decoded.sessionId, token);
          if (isRevoked) {
            sendError(
              res,
              'TOKEN_REVOKED',
              'Your session has been revoked. Please log in again.',
              HttpStatus.UNAUTHORIZED
            );
            return;
          }
        } catch (err: any) {
          sendError(
            res,
            'AUTH_SERVICE_UNAVAILABLE',
            'Authentication verification service is temporarily unavailable.',
            HttpStatus.SERVICE_UNAVAILABLE
          );
          return;
        }

        const adminId =
          env.ADMIN_ID ||
          `admin_${env.ADMIN_EMAIL.split('@')[0].replace(/[^a-zA-Z0-9_]/g, '_')}`.toLowerCase();
        const newAdminSessionId = decoded.sessionId || crypto.randomUUID();

        const newToken = jwt.sign(
          {
            id: adminId,
            email: env.ADMIN_EMAIL.trim().toLowerCase(),
            role: UserRole.ADMIN,
            sessionId: newAdminSessionId,
          },
          env.JWT_ACCESS_SECRET,
          {
            expiresIn: env.JWT_ACCESS_EXPIRES_IN as any,
          }
        );

        sendSuccess(res, {
          token: newToken,
          mustChangePassword: false,
          user: {
            id: adminId,
            email: env.ADMIN_EMAIL,
            role: UserRole.ADMIN,
            clientId: 'AXG-ADMIN',
            mustChangePassword: false,
            sessionId: newAdminSessionId,
          },
        });
        return;
      }

      // If client attempts to use an access token as a refresh token: REJECT
      sendError(
        res,
        'MISSING_REFRESH_TOKEN',
        'Refresh tokens must be sent in the request body as { refreshToken: string }. Access tokens cannot be used to refresh sessions.',
        HttpStatus.BAD_REQUEST
      );
      return;
    } catch (err: any) {
      sendError(
        res,
        'INVALID_TOKEN',
        'Session token is invalid or expired. Please log in again.',
        HttpStatus.UNAUTHORIZED
      );
      return;
    }
  }

  sendError(
    res,
    'MISSING_REFRESH_TOKEN',
    'A valid refreshToken must be provided in the request body.',
    HttpStatus.BAD_REQUEST
  );
});

/**
 * POST /api/v1/auth/logout
 * F-04 / Phase 7: Authenticated server-side logout.
 * - Single-device: revokes only current sessionId refresh tokens.
 * - All-devices: locks user, increments tokenVersion, and revokes all refresh tokens.
 * - BUG-04: Master Admin revokes the current session and token immediately in PostgreSQL.
 */
router.post('/logout', requireAuth, async (req: Request, res: Response) => {
  const user = req.user!;
  // BUG-04: Master Admin session revocation upon logout (durable PostgreSQL backed)
  if (user.role === UserRole.ADMIN) {
    const rawToken = req.headers.authorization?.split(' ')[1];
    const sid = (req as any).adminSessionId;
    try {
      await adminAuthService.revokeAdminSession(sid, rawToken);
    } catch (err: any) {
      // Fail safely — allow response so client clears local credentials
    }
    sendSuccess(res, { message: 'Logged out successfully.' });
    return;
  }

  // Client logout
  const allDevices = req.body?.allDevices === true;
  const clientSessionId = (req as any).tokenSessionId || (req as any).sessionId;
  try {
    if (allDevices) {
      await prisma.$transaction(async (tx) => {
        await tx.$queryRaw`SELECT id FROM "users" WHERE id = ${user.id} FOR UPDATE;`;
        await tx.user.update({
          where: { id: user.id },
          data: { tokenVersion: { increment: 1 } },
        });
        await refreshTokenService.revokeAllUserSessions(user.id, 'LOGOUT_ALL', tx);
      });
    } else {
      await prisma.$transaction(async (tx) => {
        await tx.$queryRaw`SELECT id FROM "users" WHERE id = ${user.id} FOR UPDATE;`;
        if (clientSessionId && (tx as any).refreshToken) {
          await (tx as any).refreshToken.updateMany({
            where: {
              userId: user.id,
              sessionId: clientSessionId,
              isRevoked: false,
            },
            data: {
              isRevoked: true,
              revokedAt: new Date(),
              revokedReason: 'LOGOUT_SINGLE',
            },
          });
        }
      });
    }
    sendSuccess(res, { message: 'Logged out successfully.' });
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Logout failed', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err);
  }
});

/**
 * POST /api/v1/auth/register
 * "Create Your Alpha X Gym Account"
 * Fields:
 * - Full Name
 * - Email
 * - Phone Number (stored as String/Text)
 * - Password (hashed with bcrypt, never plain text)
 * - Confirm Password
 *
 * System automatically generates a unique, permanent sequential Client ID: AXG-XXXX (e.g. AXG-0001).
 * Returns generated Client ID and instructions to keep it safe for future login.
 */
router.post('/register', registerRateLimiter, async (req: Request, res: Response) => {
  const { name, email, phone, password, confirmPassword } = req.body;

  // 1. Validation
  if (!name || typeof name !== 'string' || name.trim().length === 0) {
    sendError(res, 'VALIDATION_ERROR', 'Full name is required', HttpStatus.BAD_REQUEST, undefined, undefined, {
      activity: 'Client Account Registration',
      explanation: 'Full name was empty or missing in request payload.',
      receivedPayload: req.body,
    });
    return;
  }

  if (!email || typeof email !== 'string' || !email.includes('@')) {
    sendError(res, 'VALIDATION_ERROR', 'Valid email address is required', HttpStatus.BAD_REQUEST, undefined, undefined, {
      activity: 'Client Account Registration',
      explanation: 'Email field was missing or invalid (missing @).',
      receivedPayload: req.body,
    });
    return;
  }

  if (!phone || typeof phone !== 'string' || phone.trim().length === 0) {
    sendError(res, 'VALIDATION_ERROR', 'Phone number is required', HttpStatus.BAD_REQUEST, undefined, undefined, {
      activity: 'Client Account Registration',
      explanation: 'Phone number was empty or missing in request payload.',
      receivedPayload: req.body,
    });
    return;
  }

  if (!password || typeof password !== 'string' || password.length < 6) {
    sendError(res, 'VALIDATION_ERROR', 'Password must be at least 6 characters', HttpStatus.BAD_REQUEST, undefined, undefined, {
      activity: 'Client Account Registration',
      explanation: 'Password must be a string of at least 6 characters.',
    });
    return;
  }

  if (confirmPassword && password !== confirmPassword) {
    sendError(res, 'VALIDATION_ERROR', 'Password and Confirm Password do not match', HttpStatus.BAD_REQUEST, undefined, undefined, {
      activity: 'Client Account Registration',
      explanation: 'Password confirmation failed because confirmPassword did not match password.',
    });
    return;
  }

  const cleanName = name.trim();
  const normalizedEmail = email.trim().toLowerCase();
  const cleanPhone = phone.trim(); // Preserved strictly as string for country codes & leading zeros
  const configuredAdminEmail = env.ADMIN_EMAIL.trim().toLowerCase();

  // Admin email cannot be registered as a normal client
  if (normalizedEmail === configuredAdminEmail) {
    sendError(res, 'FORBIDDEN', 'This email is reserved for administration. Please sign in.', HttpStatus.FORBIDDEN, undefined, undefined, {
      activity: 'Client Account Registration',
      resourceId: normalizedEmail,
      resourceType: 'User',
      explanation: 'The requested registration email matches the configured master administrator email.',
    });
    return;
  }

  try {
    // 2. Check if user already exists
    const existingUser = await prisma.user.findUnique({
      where: { email: normalizedEmail },
    });

    if (existingUser) {
      sendError(res, 'USER_EXISTS', `This email (${normalizedEmail}) is already registered. Please login.`, HttpStatus.CONFLICT, undefined, undefined, {
        activity: 'Client Account Registration',
        resourceId: normalizedEmail,
        resourceType: 'User',
        explanation: `An account with email "${normalizedEmail}" already exists in the database.`,
      });
      return;
    }

    // 2b. Check if phone number already exists
    const existingPhone = await prisma.clientProfile.findFirst({
      where: { phone: cleanPhone },
    });

    if (existingPhone) {
      sendError(res, 'PHONE_EXISTS', `This phone number (${cleanPhone}) is already registered.`, HttpStatus.CONFLICT, undefined, undefined, {
        activity: 'Client Account Registration',
        resourceId: cleanPhone,
        resourceType: 'ClientProfile',
        explanation: `An account with phone number "${cleanPhone}" already exists in the database.`,
      });
      return;
    }

    // 3. Securely hash password with bcrypt (Never plain text!)
    const passwordHash = await bcrypt.hash(password, 10);

    // 4. Generate unique sequential Client ID (AXG-XXXX) with concurrency retry
    let newUser: any;
    let uniqueClientId = '';
    for (let attempt = 0; attempt < 5; attempt++) {
      try {
        uniqueClientId = await generateNextClientId();

        // Create real Client Account in shared PostgreSQL database with default PENDING verification status
        newUser = await prisma.user.create({
          data: {
            email: normalizedEmail,
            passwordHash,
            name: cleanName,
            role: UserRole.CLIENT,
            status: UserStatus.PENDING,
            clientProfile: {
              create: {
                clientId: uniqueClientId,
                phone: cleanPhone,
                dailyStepGoal: 6000,
                dailySteps: 6000,
                onboardingCompleted: false,
                onboardingStep: 0,
                notificationPref: {
                  create: {
                    timezone: 'Asia/Kolkata',
                    quietHoursStart: 21,
                    quietHoursEnd: 7,
                    workoutReminders: true,
                    nutritionReminders: true,
                    weeklyCheckInReminders: true,
                    activityReminders: true,
                    membershipAlerts: true,
                    aiEngagementEnabled: true,
                  },
                },
              },
            },
          },
          include: {
            clientProfile: {
              include: { notificationPref: true },
            },
          },
        });
        break;
      } catch (createErr: any) {
        if (createErr?.code === 'P2002' && (createErr?.meta?.target?.includes('clientId') || String(createErr?.message).includes('clientId'))) {
          continue;
        }
        throw createErr;
      }
    }

    if (!newUser) {
      throw new Error('Failed to generate a unique Client ID after multiple attempts');
    }

    const clientProfile = newUser.clientProfile!;

    // 6. Generate signed JWT session token
    const token = jwt.sign(
      {
        id: newUser.id,
        email: newUser.email,
        role: newUser.role,
        tokenVersion: newUser.tokenVersion ?? 0,
      },
      env.JWT_ACCESS_SECRET,
      {
        expiresIn: env.JWT_ACCESS_EXPIRES_IN as any,
      }
    );

    sendSuccess(
      res,
      {
        message: 'Account created successfully. Submitted for admin verification.',
        clientId: uniqueClientId,
        instruction: `Your Alpha X Gym Client ID is ${uniqueClientId}. Please keep this ID safe for future login.`,
        token,
        status: UserStatus.PENDING,
        assessmentCompleted: false,
        onboardingCompleted: false,
        onboardingStep: 0,
        user: {
          id: newUser.id,
          clientId: uniqueClientId,
          name: newUser.name,
          email: newUser.email,
          phone: cleanPhone,
          role: newUser.role,
          status: UserStatus.PENDING,
          createdAt: newUser.createdAt.toISOString(),
        },
        profile: clientProfile,
      },
      HttpStatus.CREATED,
      `Registered client account "${uniqueClientId}" (${cleanName}) in database`,
      { clientId: uniqueClientId, email: normalizedEmail }
    );
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Failed to register client account in database', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err, {
      activity: 'Client Account Registration',
      explanation: 'Database insertion failed while creating User or ClientProfile records.',
    });
  }
});

/**
 * POST /api/v1/auth/google
 * Google Authentication & Auto Client ID Generation.
 */
router.post('/google', async (req: Request, res: Response) => {
  const { googleUid, email, name, photoUrl } = req.body;

  if (!googleUid || typeof googleUid !== 'string' || googleUid.trim().length === 0) {
    sendError(res, 'VALIDATION_ERROR', 'Google UID is required', HttpStatus.BAD_REQUEST);
    return;
  }

  if (!email || typeof email !== 'string' || !email.includes('@')) {
    sendError(res, 'VALIDATION_ERROR', 'Valid email address is required', HttpStatus.BAD_REQUEST);
    return;
  }

  const normalizedEmail = email.trim().toLowerCase();
  const cleanGoogleUid = googleUid.trim();
  const configuredAdminEmail = env.ADMIN_EMAIL.trim().toLowerCase();

  // Admin email cannot be registered/signed in as a normal client via Google
  if (normalizedEmail === configuredAdminEmail) {
    sendError(res, 'FORBIDDEN', 'This email is reserved for administration. Please sign in via Admin Portal.', HttpStatus.FORBIDDEN);
    return;
  }

  try {
    // Check if user exists by googleUid or email
    let existingUser = await prisma.user.findFirst({
      where: {
        OR: [
          { googleUid: cleanGoogleUid },
          { email: normalizedEmail },
          { clientProfile: { googleUid: cleanGoogleUid } },
        ],
      },
      include: {
        clientProfile: true,
      },
    });

    if (existingUser) {
      if (!existingUser.googleUid) {
        existingUser = await prisma.user.update({
          where: { id: existingUser.id },
          data: {
            googleUid: cleanGoogleUid,
            clientProfile: {
              update: {
                googleUid: cleanGoogleUid,
              },
            },
          },
          include: {
            clientProfile: true,
          },
        });
      }

      const clientProfile = existingUser.clientProfile;
      const resolvedClientId = clientProfile?.clientId || '';
      const isAssessmentCompleted = clientProfile?.onboardingCompleted ?? false;
      const currentAssessmentStep = clientProfile?.onboardingStep ?? 0;

      const token = jwt.sign(
        {
          id: existingUser.id,
          email: existingUser.email,
          role: existingUser.role,
          tokenVersion: (existingUser as any).tokenVersion ?? 0,
        },
        env.JWT_ACCESS_SECRET,
        {
          expiresIn: env.JWT_ACCESS_EXPIRES_IN as any,
        }
      );

      sendSuccess(
        res,
        {
          isNewClient: false,
          token,
          clientId: resolvedClientId,
          status: existingUser.status,
          rejectionReason: existingUser.rejectionReason || null,
          assessmentCompleted: isAssessmentCompleted,
          onboardingCompleted: isAssessmentCompleted,
          onboardingStep: currentAssessmentStep,
          user: {
            id: existingUser.id,
            clientId: resolvedClientId,
            name: existingUser.name,
            email: existingUser.email,
            phone: clientProfile?.phone || null,
            role: existingUser.role,
            status: existingUser.status,
            rejectionReason: existingUser.rejectionReason || null,
          },
          profile: clientProfile,
        },
        HttpStatus.OK
      );
      return;
    }

    // New Google client -> auto-generate unique sequential Client ID (AXG-XXXX) with concurrency retry
    let newUser: any;
    let uniqueClientId = '';
    const cleanName = (name || 'Athlete Member').trim();

    for (let attempt = 0; attempt < 5; attempt++) {
      try {
        uniqueClientId = await generateNextClientId();

        newUser = await prisma.user.create({
          data: {
            email: normalizedEmail,
            name: cleanName,
            googleUid: cleanGoogleUid,
            role: UserRole.CLIENT,
            status: UserStatus.PENDING,
            clientProfile: {
              create: {
                clientId: uniqueClientId,
                googleUid: cleanGoogleUid,
                dailyStepGoal: 6000,
                dailySteps: 6000,
                onboardingCompleted: false,
                onboardingStep: 0,
                notificationPref: {
                  create: {
                    timezone: 'Asia/Kolkata',
                    quietHoursStart: 21,
                    quietHoursEnd: 7,
                    workoutReminders: true,
                    nutritionReminders: true,
                    weeklyCheckInReminders: true,
                    activityReminders: true,
                    membershipAlerts: true,
                    aiEngagementEnabled: true,
                  },
                },
              },
            },
          },
          include: {
            clientProfile: {
              include: { notificationPref: true },
            },
          },
        });
        break;
      } catch (createErr: any) {
        if (createErr?.code === 'P2002' && (createErr?.meta?.target?.includes('clientId') || String(createErr?.message).includes('clientId'))) {
          continue;
        }
        throw createErr;
      }
    }

    if (!newUser) {
      throw new Error('Failed to generate a unique Client ID after multiple attempts');
    }

    const clientProfile = newUser.clientProfile!;
    const token = jwt.sign(
      {
        id: newUser.id,
        email: newUser.email,
        role: newUser.role,
        tokenVersion: newUser.tokenVersion ?? 0,
      },
      env.JWT_ACCESS_SECRET,
      {
        expiresIn: env.JWT_ACCESS_EXPIRES_IN as any,
      }
    );

    sendSuccess(
      res,
      {
        isNewClient: true,
        message: 'Google account linked successfully. Submitted for admin verification.',
        clientId: uniqueClientId,
        instruction: `Your Alpha X Gym Client ID is ${uniqueClientId}. Please keep this ID safe for future login.`,
        token,
        status: UserStatus.PENDING,
        assessmentCompleted: false,
        onboardingCompleted: false,
        onboardingStep: 0,
        user: {
          id: newUser.id,
          clientId: uniqueClientId,
          name: newUser.name,
          email: newUser.email,
          phone: null,
          role: newUser.role,
          status: UserStatus.PENDING,
          createdAt: newUser.createdAt.toISOString(),
        },
        profile: clientProfile,
      },
      HttpStatus.CREATED
    );
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Google authentication failed', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err);
  }
});

/**
 * POST /api/v1/auth/login
 * Client & Admin Login:
 * - Admin Login: Admin Email + Admin Password -> Admin Dashboard (unchanged).
 * - Client Login: Client ID (e.g. AXG-0001) or Email + Password.
 * - Secure bcrypt verification. Password hashes are never returned.
 * - Checks assessmentCompleted.
 *   If false -> assessment needs to be completed/resumed.
 *   If true -> opens Client Dashboard.
 */
router.post('/login', loginRateLimiter, async (req: Request, res: Response) => {
  const { clientId, email, username, clientIdOrEmail, password } = req.body;

  const rawIdentifier = (clientId || clientIdOrEmail || username || email || '').trim();
  if (!rawIdentifier) {
    sendError(res, 'INVALID_CREDENTIALS', 'Client ID or Email is required', HttpStatus.BAD_REQUEST, undefined, undefined, {
      activity: 'User Login Authentication',
      explanation: 'No Client ID or Email was provided in request body.',
      receivedPayload: req.body,
    });
    return;
  }

  if (!password || typeof password !== 'string') {
    sendError(res, 'INVALID_CREDENTIALS', 'Password is required', HttpStatus.BAD_REQUEST, undefined, undefined, {
      activity: 'User Login Authentication',
      explanation: 'No password was provided in request body.',
    });
    return;
  }

  const normalizedIdentifier = rawIdentifier.toLowerCase();
  const configuredAdminEmail = env.ADMIN_EMAIL.trim().toLowerCase();

  // 1. MASTER ADMIN LOGIN CHECK
  // Exactly preserves working Admin Login
  if (normalizedIdentifier === configuredAdminEmail) {
    const isValidAdmin = await adminAuthService.verifyAdminCredentials(normalizedIdentifier, password);
    if (!isValidAdmin) {
      sendError(res, 'INVALID_CREDENTIALS', 'Invalid administrator credentials', HttpStatus.UNAUTHORIZED, undefined, undefined, {
        activity: 'Admin Login Authentication',
        resourceId: normalizedIdentifier,
        resourceType: 'AdminAccount',
        explanation: 'Provided password did not match master admin password.',
      });
      return;
    }

    const session = adminAuthService.generateAdminSession();
    sendSuccess(res, session, HttpStatus.OK, 'Admin Login Authentication: Session granted', { adminEmail: normalizedIdentifier });
    return;
  }

  // 2. CLIENT LOGIN CHECK
  // Search for client by permanent Client ID (e.g. AXG-0001) or Email
  try {
    const isClientIdFormat = /^AXG-\d+$/i.test(rawIdentifier);
    const uppercaseClientId = rawIdentifier.toUpperCase();

    const dbUser = await prisma.user.findFirst({
      where: {
        OR: [
          { email: normalizedIdentifier },
          { clientProfile: { clientId: uppercaseClientId } },
          ...(isClientIdFormat ? [{ clientProfile: { clientId: uppercaseClientId } }] : []),
        ],
      },
      include: {
        clientProfile: true,
      },
    });

    if (!dbUser) {
      // Anti-enumeration: use same message as wrong-password to not reveal account existence
      sendError(res, 'INVALID_CREDENTIALS', 'Invalid Client ID or password. Please check your credentials and try again.', HttpStatus.UNAUTHORIZED, undefined, undefined, {
        activity: 'Client Login Authentication',
        resourceId: rawIdentifier,
        resourceType: 'ClientAccount',
        explanation: `No athlete user account in database with Client ID or Email "${rawIdentifier}".`,
      });
      return;
    }

    // Verify client password with bcrypt
    if (!dbUser.passwordHash) {
      sendError(res, 'INVALID_CREDENTIALS', 'Invalid Client ID or password. Please check your credentials and try again.', HttpStatus.UNAUTHORIZED, undefined, undefined, {
        activity: 'Client Login Authentication',
        resourceId: dbUser.id,
        resourceType: 'ClientAccount',
        explanation: 'User record exists but has no password hash registered.',
      });
      return;
    }

    const isPasswordValid = await bcrypt.compare(password, dbUser.passwordHash);
    if (!isPasswordValid) {
      // Anti-enumeration: use same message as account-not-found
      sendError(res, 'INVALID_CREDENTIALS', 'Invalid Client ID or password. Please check your credentials and try again.', HttpStatus.UNAUTHORIZED, undefined, undefined, {
        activity: 'Client Login Authentication',
        resourceId: dbUser.clientProfile?.clientId || dbUser.email,
        resourceType: 'ClientAccount',
        explanation: 'Provided password does not match the bcrypt password hash on file.',
      });
      return;
    }

    const clientProfile = dbUser.clientProfile;
    const resolvedClientId = clientProfile?.clientId || '';
    const isAssessmentCompleted = clientProfile?.onboardingCompleted ?? false;
    const currentAssessmentStep = clientProfile?.onboardingStep ?? 0;

    // Track last login timestamp asynchronously
    await prisma.user.update({
      where: { id: dbUser.id },
      data: { lastLoginAt: new Date() },
    }).catch(() => {});

    // Phase 7: Issue short-lived access token (15m) and persistent refresh token (30d)
    let token: string;
    let refreshToken: string | null = null;
    let sessionId: string | null = null;

    if (dbUser.mustChangePassword) {
      token = jwt.sign(
        {
          id: dbUser.id,
          email: dbUser.email,
          role: dbUser.role,
          tokenVersion: (dbUser as any).tokenVersion ?? 0,
          mustChangePassword: true,
          scope: 'FORCE_PASSWORD_CHANGE',
        },
        env.JWT_ACCESS_SECRET,
        { expiresIn: '15m' }
      );
    } else {
      const initialSession = await refreshTokenService.createInitialRefreshToken(
        dbUser.id,
        (dbUser as any).tokenVersion ?? 0,
        (req.body?.deviceInfo as string) || (req.headers['user-agent'] as string)
      );
      refreshToken = initialSession.rawRefreshToken;
      sessionId = initialSession.sessionId;

      token = jwt.sign(
        {
          id: dbUser.id,
          email: dbUser.email,
          role: dbUser.role,
          tokenVersion: (dbUser as any).tokenVersion ?? 0,
          sessionId: initialSession.sessionId,
          familyId: initialSession.familyId,
        },
        env.JWT_ACCESS_SECRET,
        { expiresIn: '15m' }
      );
    }

    sendSuccess(
      res,
      {
        token,
        refreshToken,
        sessionId,
        clientId: resolvedClientId,
        status: dbUser.status,
        rejectionReason: dbUser.rejectionReason || null,
        rejectedAt: dbUser.rejectedAt ? dbUser.rejectedAt.toISOString() : null,
        approvedAt: dbUser.approvedAt ? dbUser.approvedAt.toISOString() : null,
        assessmentCompleted: isAssessmentCompleted,
        onboardingCompleted: isAssessmentCompleted,
        onboardingStep: currentAssessmentStep,
        mustChangePassword: dbUser.mustChangePassword ?? false,
        user: {
          id: dbUser.id,
          clientId: resolvedClientId,
          name: dbUser.name,
          email: dbUser.email,
          phone: clientProfile?.phone || null,
          role: dbUser.role,
          status: dbUser.status,
          rejectionReason: dbUser.rejectionReason || null,
          rejectedAt: dbUser.rejectedAt ? dbUser.rejectedAt.toISOString() : null,
          approvedAt: dbUser.approvedAt ? dbUser.approvedAt.toISOString() : null,
          lastLoginAt: new Date().toISOString(),
        },
        profile: clientProfile,
      },
      HttpStatus.OK,
      `Client "${resolvedClientId}" (${dbUser.name}) logged in successfully`,
      { clientId: resolvedClientId, email: dbUser.email, status: dbUser.status }
    );
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Authentication failed', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err, {
      activity: 'Client Login Authentication',
      resourceId: rawIdentifier,
      explanation: 'Database query failed during login credential lookup.',
    });
  }
});

/**
 * PUT & POST /api/v1/auth/onboarding (also /api/v1/auth/assessment, /api/client/assessment)
 * Incremental and Final Fitness Assessment Persistence.
 * - Saves each section progressively so client never loses work.
 * - On final submission sets onboardingCompleted = true (assessmentCompleted = true).
 * - Enforces realistic numeric types for weight, height, age, steps, training days.
 */
const onboardingAssessmentHandler = async (req: Request, res: Response) => {
  const userId = req.user!.id;

  try {
    const existingProfile = await prisma.clientProfile.findUnique({
      where: { userId },
    });

    if (!existingProfile) {
      sendError(res, 'NOT_FOUND', `Client profile not found for user "${userId}"`, HttpStatus.NOT_FOUND, undefined, undefined, {
        activity: 'Save Fitness Assessment',
        resourceId: userId,
        resourceType: 'ClientProfile',
        explanation: 'Authenticated user exists but does not have a client profile record in PostgreSQL.',
      });
      return;
    }

    const {
      fitnessLevel,
      primaryGoal,
      secondaryGoal,
      weightKg,
      heightCm,
      age,
      gender,
      trainingExperience,
      trainingDaysPerWeek,
      preferredDays,
      preferredTrainingDays,
      hasCurrentInjury,
      injuryAreas,
      injuryDetails,
      injuryDescription,
      hasPreviousSurgery,
      surgeryDetails,
      activityLevel,
      sleepHours,
      dailySteps,
      trainingTimePref,
      trainingPreferences,
      onboardingCompleted,
      assessmentCompleted,
      onboardingStep,
    } = req.body;

    // Biometric Validation: Realistic numbers only
    if (weightKg !== undefined && weightKg !== null && weightKg !== '') {
      const w = Number(weightKg);
      if (isNaN(w) || w <= 0 || w < 20 || w > 350) {
        sendError(res, 'VALIDATION_ERROR', 'Please enter a valid weight in kg (20 - 350 kg).', HttpStatus.BAD_REQUEST, undefined, undefined, {
          activity: 'Save Fitness Assessment',
          resourceId: existingProfile.clientId || undefined,
          resourceType: 'ClientProfile',
          explanation: `Invalid weight value: ${weightKg}. Must be numeric between 20 and 350 kg.`,
          receivedPayload: { weightKg },
        });
        return;
      }
    }

    if (heightCm !== undefined && heightCm !== null && heightCm !== '') {
      const h = Number(heightCm);
      if (isNaN(h) || h <= 0 || h < 50 || h > 280) {
        sendError(res, 'VALIDATION_ERROR', 'Please enter a valid height in cm (50 - 280 cm).', HttpStatus.BAD_REQUEST, undefined, undefined, {
          activity: 'Save Fitness Assessment',
          resourceId: existingProfile.clientId || undefined,
          resourceType: 'ClientProfile',
          explanation: `Invalid height value: ${heightCm}. Must be numeric between 50 and 280 cm.`,
          receivedPayload: { heightCm },
        });
        return;
      }
    }

    if (age !== undefined && age !== null && age !== '') {
      const a = Number(age);
      if (isNaN(a) || a <= 0 || a < 10 || a > 120 || !Number.isInteger(a)) {
        sendError(res, 'VALIDATION_ERROR', 'Please enter a valid whole age (10 - 120).', HttpStatus.BAD_REQUEST, undefined, undefined, {
          activity: 'Save Fitness Assessment',
          resourceId: existingProfile.clientId || undefined,
          resourceType: 'ClientProfile',
          explanation: `Invalid age value: ${age}. Must be an integer between 10 and 120.`,
          receivedPayload: { age },
        });
        return;
      }
    }

    if (trainingDaysPerWeek !== undefined && trainingDaysPerWeek !== null && trainingDaysPerWeek !== '') {
      const d = Number(trainingDaysPerWeek);
      if (isNaN(d) || d < 1 || d > 7 || !Number.isInteger(d)) {
        sendError(res, 'VALIDATION_ERROR', 'Training days per week must be a whole number between 1 and 7.', HttpStatus.BAD_REQUEST, undefined, undefined, {
          activity: 'Save Fitness Assessment',
          resourceId: existingProfile.clientId || undefined,
          resourceType: 'ClientProfile',
          explanation: `Invalid training days: ${trainingDaysPerWeek}. Must be an integer between 1 and 7.`,
          receivedPayload: { trainingDaysPerWeek },
        });
        return;
      }
    }

    // Prepare update data
    const updateData: any = {};
    if (fitnessLevel !== undefined) updateData.fitnessLevel = fitnessLevel;
    if (primaryGoal !== undefined) updateData.primaryGoal = primaryGoal;
    if (secondaryGoal !== undefined) updateData.secondaryGoal = secondaryGoal;
    if (weightKg !== undefined) updateData.weightKg = weightKg !== null && weightKg !== '' ? Number(weightKg) : null;
    if (heightCm !== undefined) updateData.heightCm = heightCm !== null && heightCm !== '' ? Number(heightCm) : null;
    if (age !== undefined) updateData.age = age !== null && age !== '' ? Number(age) : null;
    if (gender !== undefined) updateData.gender = gender;
    if (trainingExperience !== undefined) updateData.trainingExperience = trainingExperience;
    if (trainingDaysPerWeek !== undefined) updateData.trainingDaysPerWeek = trainingDaysPerWeek !== null && trainingDaysPerWeek !== '' ? Number(trainingDaysPerWeek) : null;

    const days = preferredDays || preferredTrainingDays;
    if (days !== undefined) updateData.preferredDays = Array.isArray(days) ? days : [];

    if (hasCurrentInjury !== undefined) updateData.hasCurrentInjury = Boolean(hasCurrentInjury);
    if (injuryAreas !== undefined) updateData.injuryAreas = Array.isArray(injuryAreas) ? injuryAreas : [];

    const injDesc = injuryDetails || injuryDescription;
    if (injDesc !== undefined) updateData.injuryDescription = injDesc;

    if (hasPreviousSurgery !== undefined) updateData.hasPreviousSurgery = Boolean(hasPreviousSurgery);
    if (surgeryDetails !== undefined) updateData.surgeryDetails = surgeryDetails;
    if (activityLevel !== undefined) updateData.activityLevel = activityLevel;
    if (sleepHours !== undefined) updateData.sleepHours = sleepHours;

    if (dailySteps !== undefined) {
      const steps = Number(dailySteps) || 6000;
      updateData.dailySteps = steps;
      updateData.dailyStepGoal = steps;
    }

    if (trainingTimePref !== undefined) updateData.trainingTimePref = trainingTimePref;
    if (trainingPreferences !== undefined) updateData.trainingPreferences = Array.isArray(trainingPreferences) ? trainingPreferences : [];

    const isDone = onboardingCompleted !== undefined ? Boolean(onboardingCompleted) : (assessmentCompleted !== undefined ? Boolean(assessmentCompleted) : undefined);
    if (isDone !== undefined) updateData.onboardingCompleted = isDone;
    if (onboardingStep !== undefined) updateData.onboardingStep = Number(onboardingStep);

    const updatedProfile = await prisma.clientProfile.update({
      where: { userId },
      data: updateData,
    });

    sendSuccess(
      res,
      {
        message: 'Fitness assessment saved successfully',
        assessmentCompleted: updatedProfile.onboardingCompleted,
        onboardingCompleted: updatedProfile.onboardingCompleted,
        onboardingStep: updatedProfile.onboardingStep,
        profile: updatedProfile,
      },
      HttpStatus.OK,
      `Saved fitness assessment for client "${updatedProfile.clientId}" (Completed: ${updatedProfile.onboardingCompleted})`,
      { clientId: updatedProfile.clientId, onboardingCompleted: updatedProfile.onboardingCompleted, step: updatedProfile.onboardingStep }
    );
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Failed to save assessment data in database', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err, {
      activity: 'Save Fitness Assessment',
      resourceId: userId,
      resourceType: 'ClientProfile',
      explanation: 'Database write failed while updating client assessment data.',
    });
  }
};
router.put(['/onboarding', '/assessment'], requireAuth, onboardingAssessmentHandler);
router.post(['/onboarding', '/assessment'], requireAuth, onboardingAssessmentHandler);

/**
 * GET /api/v1/auth/profile
 * Returns the client's complete profile and assessment.
 */
router.get('/profile', requireAuth, async (req: Request, res: Response) => {
  const userId = req.user!.id;
  try {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      include: {
        clientProfile: {
          include: {
            dietPlans: { where: { isActive: true }, take: 1 },
            macroPlans: { where: { isActive: true }, take: 1 },
          },
        },
      },
    });

    if (!user) {
      sendError(res, 'NOT_FOUND', 'User not found', HttpStatus.NOT_FOUND);
      return;
    }

    sendSuccess(res, {
      user: {
        id: user.id,
        clientId: user.clientProfile?.clientId,
        name: user.name,
        email: user.email,
        phone: user.clientProfile?.phone,
        role: user.role,
      },
      assessmentCompleted: user.clientProfile?.onboardingCompleted ?? false,
      profile: user.clientProfile,
    });
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Failed to load profile', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err);
  }
});

/**
 * POST /api/v1/auth/admin/login
 * Dedicated Administrator Authentication Endpoint.
 */
router.post('/admin/login', loginRateLimiter, async (req: Request, res: Response) => {
  try {
    const { email, password } = req.body;

    if (!email || typeof email !== 'string' || !password || typeof password !== 'string') {
      sendError(res, 'INVALID_CREDENTIALS', 'Email and password are required', HttpStatus.BAD_REQUEST);
      return;
    }

    const isValid = await adminAuthService.verifyAdminCredentials(email, password);
    if (!isValid) {
      sendError(res, 'INVALID_CREDENTIALS', 'Invalid administrator credentials', HttpStatus.UNAUTHORIZED);
      return;
    }

    const session = adminAuthService.generateAdminSession();
    sendSuccess(res, session, HttpStatus.OK);
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Admin authentication failed', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err);
  }
});

/**
 * POST /api/v1/auth/forgot-password
 * Initiates the password recovery flow.
 * Rate-limited to prevent enumeration and denial-of-service.
 * Enforces strict anti-enumeration: always returns uniform confirmation.
 */
router.post('/forgot-password', forgotPasswordRateLimiter, async (req: Request, res: Response) => {
  try {
    const { email } = req.body;
    const result = await passwordResetService.requestPasswordReset(email);
    if (!result.success) {
      sendError(res, 'SERVICE_UNAVAILABLE', result.message, HttpStatus.SERVICE_UNAVAILABLE);
      return;
    }
    sendSuccess(res, { message: result.message }, HttpStatus.OK);
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Password reset request failed', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err);
  }
});

/**
 * GET /api/v1/auth/reset-password/verify
 * Validates a password reset token without consuming it.
 * Used by recovery screens to verify token validity before presenting password inputs.
 */
router.get('/reset-password/verify', async (req: Request, res: Response) => {
  try {
    const token = typeof req.query.token === 'string' ? req.query.token : '';

    if (!token) {
      sendError(res, 'VALIDATION_ERROR', 'Reset token query parameter is required', HttpStatus.BAD_REQUEST);
      return;
    }

    const result = await passwordResetService.verifyResetToken(token);
    if (!result.valid) {
      sendError(res, result.error || 'INVALID_TOKEN', result.message || 'Invalid or expired reset token', HttpStatus.BAD_REQUEST);
      return;
    }

    sendSuccess(res, {
      valid: true,
      email: result.email,
      role: result.role,
    }, HttpStatus.OK);
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Token verification failed', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err);
  }
});

/**
 * POST /api/v1/auth/reset-password
 * Executes password update using the verified single-use reset token.
 * Validates password, saves new bcrypt hash, and consumes token.
 */
router.post('/reset-password', async (req: Request, res: Response) => {
  try {
    const { token, newPassword, confirmPassword } = req.body;

    if (!token || typeof token !== 'string') {
      sendError(res, 'VALIDATION_ERROR', 'Reset token is required', HttpStatus.BAD_REQUEST);
      return;
    }

    if (!newPassword || typeof newPassword !== 'string' || newPassword.length < 6) {
      sendError(res, 'VALIDATION_ERROR', 'New password must be at least 6 characters', HttpStatus.BAD_REQUEST);
      return;
    }

    if (confirmPassword && newPassword !== confirmPassword) {
      sendError(res, 'VALIDATION_ERROR', 'New password and confirm password do not match', HttpStatus.BAD_REQUEST);
      return;
    }

    const result = await passwordResetService.resetPassword(token, newPassword);
    if (!result.success) {
      sendError(res, result.error || 'RESET_FAILED', result.message, HttpStatus.BAD_REQUEST);
      return;
    }

    sendSuccess(res, { message: result.message }, HttpStatus.OK);
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Password reset failed', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err);
  }
});

/**
 * POST /api/v1/auth/reset-password-with-code
 * Zero-cost, email-free password reset using admin-issued single-use 6-digit code.
 * Validates identifier (email or Client ID AXG-XXXX) + single-use code + new password.
 * Rate-limited to prevent brute-force attacks.
 * Strictly avoids exposing passwords, password hashes, reset tokens, or client PII.
 */
router.post('/reset-password-with-code', forgotPasswordRateLimiter, async (req: Request, res: Response) => {
  try {
    const { identifier, code, newPassword, confirmPassword } = req.body;

    if (!identifier || typeof identifier !== 'string' || !identifier.trim()) {
      sendError(res, 'VALIDATION_ERROR', 'Athlete email or Client ID is required', HttpStatus.BAD_REQUEST);
      return;
    }

    if (!code || typeof code !== 'string' || !code.trim()) {
      sendError(res, 'VALIDATION_ERROR', '6-digit verification code is required', HttpStatus.BAD_REQUEST);
      return;
    }

    if (!newPassword || typeof newPassword !== 'string' || newPassword.length < 6) {
      sendError(res, 'VALIDATION_ERROR', 'New password must be at least 6 characters', HttpStatus.BAD_REQUEST);
      return;
    }

    if (confirmPassword && newPassword !== confirmPassword) {
      sendError(res, 'VALIDATION_ERROR', 'New password and confirm password do not match', HttpStatus.BAD_REQUEST);
      return;
    }

    const result = await passwordResetService.resetPasswordWithAdminCode(
      identifier.trim(),
      code.trim(),
      newPassword
    );

    if (!result.success) {
      sendError(res, result.error || 'RESET_FAILED', result.message, HttpStatus.BAD_REQUEST);
      return;
    }

    sendSuccess(res, { message: result.message }, HttpStatus.OK);
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Password reset with code failed', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err);
  }
});

/**
 * GET /api/v1/auth/gym-contact-info
 * Returns official gym administrator contact details for zero-cost, email-free recovery.
 */
router.get('/gym-contact-info', async (_req: Request, res: Response) => {
  try {
    const publicSupportEmail = env.SUPPORT_EMAIL || 'support@alphaxgym.com';
    sendSuccess(res, {
      gymName: 'Alpha X Gym',
      supportEmail: publicSupportEmail,
      adminEmail: publicSupportEmail, // Backwards-compatible alias for existing mobile screens
      instructions: 'Visit the Alpha X Gym front desk or contact gym support to verify your athlete identity and receive a secure single-use reset code.',
      verificationMethod: 'In-Person or Direct Support Verification',
      emailConfigured: emailService.isConfigured(),
    }, HttpStatus.OK);
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Failed to retrieve gym contact info', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err);
  }
});

/**
 * POST /api/v1/auth/change-password
 * Authenticated password update (used for user settings and forced password changes).
 * F-04: After a successful password change, tokenVersion is incremented. A fresh JWT
 * is issued and returned in the response so the current user is not stranded.
 */
router.post('/change-password', requireAuth, async (req: Request, res: Response) => {
  try {
    const { currentPassword, newPassword, confirmPassword } = req.body;

    if (!currentPassword || typeof currentPassword !== 'string') {
      sendError(res, 'VALIDATION_ERROR', 'Current password is required', HttpStatus.BAD_REQUEST);
      return;
    }

    if (!newPassword || typeof newPassword !== 'string' || newPassword.length < 6) {
      sendError(res, 'VALIDATION_ERROR', 'New password must be at least 6 characters', HttpStatus.BAD_REQUEST);
      return;
    }

    if (confirmPassword && newPassword !== confirmPassword) {
      sendError(res, 'VALIDATION_ERROR', 'New password and confirm password do not match', HttpStatus.BAD_REQUEST);
      return;
    }

    const result = await passwordResetService.changePassword(
      req.user!.id,
      currentPassword,
      newPassword
    );

    if (!result.success) {
      sendError(res, result.error || 'CHANGE_PASSWORD_FAILED', result.message, HttpStatus.BAD_REQUEST);
      return;
    }

    // Phase 7: Issue a fresh 15-minute JWT and 30-day refresh token with the updated tokenVersion
    const newTokenVersion = result.tokenVersion ?? 0;
    const initialSession = await refreshTokenService.createInitialRefreshToken(
      req.user!.id,
      newTokenVersion,
      (req.body?.deviceInfo as string) || (req.headers['user-agent'] as string)
    );

    const freshToken = jwt.sign(
      {
        id: req.user!.id,
        email: req.user!.email,
        role: req.user!.role,
        tokenVersion: newTokenVersion,
        sessionId: initialSession.sessionId,
        familyId: initialSession.familyId,
      },
      env.JWT_ACCESS_SECRET,
      { expiresIn: '15m' }
    );

    sendSuccess(
      res,
      {
        message: result.message,
        token: freshToken,
        refreshToken: initialSession.rawRefreshToken,
        sessionId: initialSession.sessionId,
      },
      HttpStatus.OK
    );
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Password change failed', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err);
  }
});

export const authRoutes = router;
