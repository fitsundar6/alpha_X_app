import { Router, Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import { requireAuth } from '../../middlewares/auth';
import { sendSuccess, sendError } from '../../utils/responseEnvelope';
import { UserRole } from '../../constants/roles';
import { env } from '../../config/environment';
import { HttpStatus } from '../../constants/httpStatus';
import { adminAuthService } from './admin_auth.service';
import { prisma } from '../../config/prisma';

const router = Router();

/**
 * Generates the next sequential unique Client ID in format AXG-XXXX (e.g. AXG-0001)
 * Permanent, immutable string identifier.
 */
export async function generateNextClientId(): Promise<string> {
  const count = await prisma.clientProfile.count();
  let candidateNum = count + 1;
  while (true) {
    const candidateId = `AXG-${String(candidateNum).padStart(4, '0')}`;
    const existing = await prisma.clientProfile.findUnique({
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
  if (!isMasterAdmin) {
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
    clientId: profileData?.clientId ?? (role === UserRole.ADMIN ? 'AXG-ADMIN' : null),
    assessmentCompleted: profileData?.onboardingCompleted ?? false,
    onboardingCompleted: profileData?.onboardingCompleted ?? false,
    onboardingStep: profileData?.onboardingStep ?? 0,
    profile: profileData,
  });
});

/**
 * POST /api/v1/auth/refresh
 * Refreshes an expired or existing valid session token.
 * Accepts Authorization Bearer token (including tokens expired within 30-day grace period).
 * Returns a fresh 30-day JWT access token.
 */
router.post('/refresh', async (req: Request, res: Response) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    sendError(res, 'UNAUTHORIZED', 'Missing Authorization header', HttpStatus.UNAUTHORIZED);
    return;
  }
  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwt.verify(token, env.JWT_ACCESS_SECRET, { ignoreExpiration: true }) as {
      id: string;
      email: string;
      role?: UserRole;
      exp?: number;
    };
    const expTimeMs = (decoded.exp || 0) * 1000;
    const gracePeriodMs = 30 * 24 * 60 * 60 * 1000; // 30 days
    if (Date.now() - expTimeMs > gracePeriodMs) {
      sendError(res, 'TOKEN_EXPIRED', 'Session has expired beyond recovery. Please log in again.', HttpStatus.UNAUTHORIZED);
      return;
    }

    const normalizedEmail = (decoded.email || '').trim().toLowerCase();
    const isMasterAdmin = normalizedEmail.length > 0 && normalizedEmail === env.ADMIN_EMAIL.trim().toLowerCase();

    let user: any = null;
    let clientId: string | null = null;
    if (isMasterAdmin) {
      user = { id: 'admin_alex_stone', email: env.ADMIN_EMAIL, role: UserRole.ADMIN, name: 'Alpha X Administrator' };
      clientId = 'AXG-ADMIN';
    } else {
      user = await prisma.user.findUnique({
        where: { id: decoded.id },
        include: { clientProfile: true },
      });
      if (!user) {
        sendError(res, 'USER_NOT_FOUND', 'User account not found', HttpStatus.UNAUTHORIZED);
        return;
      }
      clientId = user.clientProfile?.clientId ?? null;
    }

    const effectiveRole = isMasterAdmin ? UserRole.ADMIN : UserRole.CLIENT;
    const newToken = jwt.sign(
      {
        id: user.id,
        email: normalizedEmail,
        role: effectiveRole,
      },
      env.JWT_ACCESS_SECRET,
      {
        expiresIn: env.JWT_ACCESS_EXPIRES_IN as any,
      }
    );

    sendSuccess(res, {
      token: newToken,
      user: {
        id: user.id,
        email: normalizedEmail,
        role: effectiveRole,
        clientId,
      },
    });
  } catch (err: any) {
    sendError(res, 'INVALID_TOKEN', 'Session token is invalid or corrupted', HttpStatus.UNAUTHORIZED, undefined, err);
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
router.post('/register', async (req: Request, res: Response) => {
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

    // 3. Generate unique sequential Client ID: AXG-XXXX
    const uniqueClientId = await generateNextClientId();

    // 4. Securely hash password with bcrypt (Never plain text!)
    const passwordHash = await bcrypt.hash(password, 10);

    // 5. Create real Client Account in shared PostgreSQL database
    const newUser = await prisma.user.create({
      data: {
        email: normalizedEmail,
        passwordHash,
        name: cleanName,
        role: UserRole.CLIENT,
        clientProfile: {
          create: {
            clientId: uniqueClientId,
            phone: cleanPhone,
            dailyStepGoal: 6000,
            dailySteps: 6000,
            onboardingCompleted: false,
            onboardingStep: 0,
          },
        },
      },
      include: {
        clientProfile: true,
      },
    });

    const clientProfile = newUser.clientProfile!;

    // 6. Generate signed JWT session token
    const token = jwt.sign(
      {
        id: newUser.id,
        email: newUser.email,
        role: newUser.role,
      },
      env.JWT_ACCESS_SECRET,
      {
        expiresIn: env.JWT_ACCESS_EXPIRES_IN as any,
      }
    );

    sendSuccess(
      res,
      {
        message: 'Account created successfully',
        clientId: uniqueClientId,
        instruction: `Your Alpha X Gym Client ID is ${uniqueClientId}. Please keep this ID safe for future login.`,
        token,
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
          },
          profile: clientProfile,
        },
        HttpStatus.OK
      );
      return;
    }

    // New Google client -> auto-generate unique sequential Client ID (AXG-XXXX)
    const uniqueClientId = await generateNextClientId();
    const cleanName = (name || 'Athlete Member').trim();

    const newUser = await prisma.user.create({
      data: {
        email: normalizedEmail,
        name: cleanName,
        googleUid: cleanGoogleUid,
        role: UserRole.CLIENT,
        clientProfile: {
          create: {
            clientId: uniqueClientId,
            googleUid: cleanGoogleUid,
            dailyStepGoal: 6000,
            dailySteps: 6000,
            onboardingCompleted: false,
            onboardingStep: 0,
          },
        },
      },
      include: {
        clientProfile: true,
      },
    });

    const clientProfile = newUser.clientProfile!;
    const token = jwt.sign(
      {
        id: newUser.id,
        email: newUser.email,
        role: newUser.role,
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
        message: 'Google account linked successfully',
        clientId: uniqueClientId,
        instruction: `Your Alpha X Gym Client ID is ${uniqueClientId}. Please keep this ID safe for future login.`,
        token,
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
router.post('/login', async (req: Request, res: Response) => {
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
      sendError(res, 'INVALID_CREDENTIALS', `Account not found for "${rawIdentifier}"`, HttpStatus.UNAUTHORIZED, undefined, undefined, {
        activity: 'Client Login Authentication',
        resourceId: rawIdentifier,
        resourceType: 'ClientAccount',
        explanation: `No athlete user account in database with Client ID or Email "${rawIdentifier}".`,
      });
      return;
    }

    // Verify client password with bcrypt
    if (!dbUser.passwordHash) {
      sendError(res, 'INVALID_CREDENTIALS', 'No password set for this account. Please contact gym administration.', HttpStatus.UNAUTHORIZED, undefined, undefined, {
        activity: 'Client Login Authentication',
        resourceId: dbUser.id,
        resourceType: 'ClientAccount',
        explanation: 'User record exists but has no password hash registered.',
      });
      return;
    }

    const isPasswordValid = await bcrypt.compare(password, dbUser.passwordHash);
    if (!isPasswordValid) {
      sendError(res, 'INVALID_CREDENTIALS', 'Invalid password for account', HttpStatus.UNAUTHORIZED, undefined, undefined, {
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

    // Generate JWT
    const token = jwt.sign(
      {
        id: dbUser.id,
        email: dbUser.email,
        role: dbUser.role,
      },
      env.JWT_ACCESS_SECRET,
      {
        expiresIn: env.JWT_ACCESS_EXPIRES_IN as any,
      }
    );

    sendSuccess(
      res,
      {
        token,
        clientId: resolvedClientId,
        assessmentCompleted: isAssessmentCompleted,
        onboardingCompleted: isAssessmentCompleted,
        onboardingStep: currentAssessmentStep,
        user: {
          id: dbUser.id,
          clientId: resolvedClientId,
          name: dbUser.name,
          email: dbUser.email,
          phone: clientProfile?.phone || null,
          role: dbUser.role,
        },
        profile: clientProfile,
      },
      HttpStatus.OK,
      `Client "${resolvedClientId}" (${dbUser.name}) logged in successfully`,
      { clientId: resolvedClientId, email: dbUser.email }
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
router.post('/admin/login', async (req: Request, res: Response) => {
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
});

export const authRoutes = router;
