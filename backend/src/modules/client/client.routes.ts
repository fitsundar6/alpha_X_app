import { Router, Request, Response } from 'express';
import { requireAuth } from '../../middlewares/auth';
import { sendSuccess, sendError } from '../../utils/responseEnvelope';
import { HttpStatus } from '../../constants/httpStatus';
import { prisma } from '../../config/prisma';

const router = Router();

// ==========================================
// CLIENT SELF-SERVICE API
// All endpoints below strictly enforce role-based access.
// Clients can ONLY see and update their own data.
// Identity is strictly extracted from req.user!.id (verified JWT).
// Any attempt by client to pass another clientId in params/body is ignored.
// ==========================================

router.use(requireAuth);

// Helper: resolves authenticated client's profile
async function getAuthenticatedClientProfile(userId: string) {
  return prisma.clientProfile.findUnique({
    where: { userId },
    include: {
      user: {
        select: {
          id: true,
          email: true,
          name: true,
          role: true,
          createdAt: true,
        },
      },
    },
  });
}

// GET /api/v1/client/me
router.get('/me', async (req: Request, res: Response) => {
  try {
    const profile = await getAuthenticatedClientProfile(req.user!.id);
    if (!profile) {
      sendError(res, 'NOT_FOUND', 'Client profile not found', HttpStatus.NOT_FOUND);
      return;
    }

    sendSuccess(res, {
      id: profile.user.id,
      clientId: profile.clientId,
      name: profile.user.name,
      email: profile.user.email,
      phone: profile.phone,
      assessmentCompleted: profile.onboardingCompleted,
      onboardingCompleted: profile.onboardingCompleted,
      onboardingStep: profile.onboardingStep,
      profile,
    });
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Failed to retrieve profile', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

// PUT /api/v1/client/me/profile (also /profile and /me/assessment)
// Self-service: client updates their own assessment & profile in the database
router.put(['/me/profile', '/profile', '/me/assessment'], async (req: Request, res: Response) => {
  const userId = req.user!.id;

  try {
    const existingProfile = await prisma.clientProfile.findUnique({
      where: { userId },
      include: { user: true },
    });

    if (!existingProfile) {
      sendError(res, 'NOT_FOUND', 'Client profile not found for user', HttpStatus.NOT_FOUND);
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
      phone,
    } = req.body;

    // Biometric Validation: Realistic numbers only
    if (weightKg !== undefined && weightKg !== null && weightKg !== '') {
      const w = Number(weightKg);
      if (isNaN(w) || w <= 0 || w < 20 || w > 350) {
        sendError(res, 'VALIDATION_ERROR', 'Please enter a valid weight in kg (20 - 350 kg).', HttpStatus.BAD_REQUEST);
        return;
      }
    }

    if (heightCm !== undefined && heightCm !== null && heightCm !== '') {
      const h = Number(heightCm);
      if (isNaN(h) || h <= 0 || h < 50 || h > 280) {
        sendError(res, 'VALIDATION_ERROR', 'Please enter a valid height in cm (50 - 280 cm).', HttpStatus.BAD_REQUEST);
        return;
      }
    }

    if (age !== undefined && age !== null && age !== '') {
      const a = Number(age);
      if (isNaN(a) || a <= 0 || a < 10 || a > 120 || !Number.isInteger(a)) {
        sendError(res, 'VALIDATION_ERROR', 'Please enter a valid whole age (10 - 120).', HttpStatus.BAD_REQUEST);
        return;
      }
    }

    if (trainingDaysPerWeek !== undefined && trainingDaysPerWeek !== null && trainingDaysPerWeek !== '') {
      const d = Number(trainingDaysPerWeek);
      if (isNaN(d) || d < 1 || d > 7 || !Number.isInteger(d)) {
        sendError(res, 'VALIDATION_ERROR', 'Training days per week must be a whole number between 1 and 7.', HttpStatus.BAD_REQUEST);
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

    if (phone !== undefined && phone !== null && typeof phone === 'string' && phone.trim().length > 0) {
      updateData.phone = phone.trim();
    }

    const isDone = onboardingCompleted !== undefined ? Boolean(onboardingCompleted) : (assessmentCompleted !== undefined ? Boolean(assessmentCompleted) : undefined);
    if (isDone !== undefined) updateData.onboardingCompleted = isDone;
    if (onboardingStep !== undefined) updateData.onboardingStep = Number(onboardingStep);

    const updatedProfile = await prisma.clientProfile.update({
      where: { userId },
      data: updateData,
      include: {
        user: {
          select: {
            id: true,
            email: true,
            name: true,
            role: true,
            createdAt: true,
          },
        },
      },
    });

    sendSuccess(res, {
      message: 'Fitness assessment saved successfully',
      clientId: updatedProfile.clientId,
      assessmentCompleted: updatedProfile.onboardingCompleted,
      onboardingCompleted: updatedProfile.onboardingCompleted,
      onboardingStep: updatedProfile.onboardingStep,
      profile: updatedProfile,
    });
  } catch (err: any) {
    console.error('[CLIENT PROFILE UPDATE ERROR]', err);
    sendError(res, 'INTERNAL_ERROR', 'Failed to save assessment data', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

// GET /api/v1/client/me/workout: Active assigned workout
router.get('/me/workout', async (req: Request, res: Response) => {
  try {
    const userId = req.user!.id;

    // Check assignments for this specific client or global ("ALL") assignments
    const assignment = await prisma.workoutAssignment.findFirst({
      where: {
        OR: [
          { clientId: userId },
          { clientId: null }, // Global gym assignment
        ],
        active: true,
      },
      orderBy: [
        { isRecommended: 'desc' },
        { assignedAt: 'desc' },
      ],
      include: {
        session: {
          include: {
            exercises: {
              orderBy: { orderIndex: 'asc' },
              include: {
                setTemplates: { orderBy: { setNumber: 'asc' } },
              },
            },
          },
        },
      },
    });

    sendSuccess(res, assignment ? assignment.session : null);
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Failed to fetch assigned workout', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

// GET /api/v1/client/me/diet-plan: Active assigned diet plan
router.get('/me/diet-plan', async (req: Request, res: Response) => {
  try {
    const profile = await getAuthenticatedClientProfile(req.user!.id);
    if (!profile) {
      sendError(res, 'NOT_FOUND', 'Client profile not found', HttpStatus.NOT_FOUND);
      return;
    }

    const activeDietPlan = await prisma.dietPlan.findFirst({
      where: {
        clientProfileId: profile.id,
        isActive: true,
      },
      orderBy: { createdAt: 'desc' },
    });

    sendSuccess(res, activeDietPlan);
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Failed to fetch assigned diet plan', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

// GET /api/v1/client/me/macros: Active assigned macro targets
router.get('/me/macros', async (req: Request, res: Response) => {
  try {
    const profile = await getAuthenticatedClientProfile(req.user!.id);
    if (!profile) {
      sendError(res, 'NOT_FOUND', 'Client profile not found', HttpStatus.NOT_FOUND);
      return;
    }

    const activeMacroPlan = await prisma.macroPlan.findFirst({
      where: {
        clientProfileId: profile.id,
        isActive: true,
      },
      orderBy: { createdAt: 'desc' },
    });

    sendSuccess(res, activeMacroPlan);
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Failed to fetch assigned macros', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

// GET /api/v1/client/me/attendance: Attendance history
router.get('/me/attendance', async (req: Request, res: Response) => {
  try {
    const profile = await getAuthenticatedClientProfile(req.user!.id);
    if (!profile) {
      sendError(res, 'NOT_FOUND', 'Client profile not found', HttpStatus.NOT_FOUND);
      return;
    }

    const records = await prisma.clientAttendance.findMany({
      where: { clientProfileId: profile.id },
      orderBy: { date: 'desc' },
      take: 60,
    });

    sendSuccess(res, records);
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Failed to fetch attendance history', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

// GET /api/v1/client/me/progress: Weight & body progress history
router.get('/me/progress', async (req: Request, res: Response) => {
  try {
    const profile = await getAuthenticatedClientProfile(req.user!.id);
    if (!profile) {
      sendError(res, 'NOT_FOUND', 'Client profile not found', HttpStatus.NOT_FOUND);
      return;
    }

    const records = await prisma.clientProgress.findMany({
      where: { clientProfileId: profile.id },
      orderBy: { date: 'desc' },
      take: 60,
    });

    sendSuccess(res, records);
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Failed to fetch progress history', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

// POST /api/v1/client/me/progress: Client logs a weight check-in
router.post('/me/progress', async (req: Request, res: Response) => {
  const { weightKg, waistCm, notes } = req.body;

  if (weightKg === undefined || weightKg === null || isNaN(Number(weightKg))) {
    sendError(res, 'VALIDATION_ERROR', 'Valid weight in kg is required', HttpStatus.BAD_REQUEST);
    return;
  }

  try {
    const profile = await getAuthenticatedClientProfile(req.user!.id);
    if (!profile) {
      sendError(res, 'NOT_FOUND', 'Client profile not found', HttpStatus.NOT_FOUND);
      return;
    }

    const record = await prisma.clientProgress.create({
      data: {
        clientProfileId: profile.id,
        clientId: profile.clientId,
        weightKg: Number(weightKg),
        waistCm: waistCm ? Number(waistCm) : null,
        notes: notes || null,
        date: new Date(),
      },
    });

    // Update weight on profile
    await prisma.clientProfile.update({
      where: { id: profile.id },
      data: { weightKg: Number(weightKg) },
    });

    sendSuccess(res, record, HttpStatus.CREATED);
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Failed to log progress check-in', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

// GET /api/v1/client/me/challenge: Real challenge status for authenticated client
router.get('/me/challenge', async (req: Request, res: Response) => {
  try {
    const profile = await getAuthenticatedClientProfile(req.user!.id);
    if (!profile) {
      sendError(res, 'NOT_FOUND', 'Client profile not found', HttpStatus.NOT_FOUND);
      return;
    }

    if (!profile.onboardingCompleted) {
      sendSuccess(res, {
        active: false,
        message: 'No active challenge assigned',
      });
      return;
    }

    const daysSinceJoin = Math.floor((Date.now() - new Date(profile.createdAt).getTime()) / (1000 * 60 * 60 * 24)) + 1;
    const challengeDuration = 100;
    const currentDay = Math.min(daysSinceJoin, challengeDuration);
    const isCompleted = daysSinceJoin > challengeDuration;

    sendSuccess(res, {
      active: true,
      challengeId: 'ch_100_day_transformation',
      title: '100-Day Transformation Challenge',
      description: 'Alpha X flagship transformation protocol: consistency in prescribed workouts, nutrition targets, and progressive overload.',
      durationDays: challengeDuration,
      currentDay: currentDay,
      startDate: profile.createdAt,
      progressPercent: Number((currentDay / challengeDuration).toFixed(2)),
      status: isCompleted ? 'COMPLETED' : 'ACTIVE',
    });
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Failed to fetch challenge status', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

export const clientRoutes = router;

