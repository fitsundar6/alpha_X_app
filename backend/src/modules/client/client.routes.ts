import { Router, Request, Response } from 'express';
import { requireAuth } from '../../middlewares/auth';
import { sendSuccess, sendError } from '../../utils/responseEnvelope';
import { HttpStatus } from '../../constants/httpStatus';
import { prisma } from '../../config/prisma';
import { foodPhotoController } from '../food/food.photo.controller';
import { automationController } from '../automation/automation.controller';

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
    sendError(res, 'INTERNAL_ERROR', 'Failed to retrieve profile', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err);
  }
});

// PUT & POST /api/v1/client/me/profile (also /profile and /me/assessment, /assessment)
// Self-service: client updates their own assessment & profile in the database
const assessmentPaths = ['/me/profile', '/profile', '/me/assessment', '/assessment'];
const handleAssessmentUpdate = async (req: Request, res: Response) => {
  const userId = req.user!.id;

  try {
    const existingProfile = await prisma.clientProfile.findUnique({
      where: { userId },
      include: { user: true },
    });

    if (!existingProfile) {
      sendError(res, 'NOT_FOUND', `Client profile not found for user "${userId}"`, HttpStatus.NOT_FOUND, undefined, undefined, {
        activity: 'Save Client Assessment',
        resourceId: userId,
        resourceType: 'ClientProfile',
        explanation: 'Authenticated user exists, but no client profile record was found in the database.',
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
      phone,
    } = req.body;

    // Biometric Validation: Realistic numbers only
    if (weightKg !== undefined && weightKg !== null && weightKg !== '') {
      const w = Number(weightKg);
      if (isNaN(w) || w <= 0 || w < 20 || w > 350) {
        sendError(res, 'VALIDATION_ERROR', 'Please enter a valid weight in kg (20 - 350 kg).', HttpStatus.BAD_REQUEST, undefined, undefined, {
          activity: 'Save Client Assessment',
          resourceId: existingProfile.clientId || undefined,
          resourceType: 'ClientProfile',
          explanation: `Invalid weight value: ${weightKg}. Must be a valid numeric weight between 20 and 350 kg.`,
          receivedPayload: { weightKg },
        });
        return;
      }
    }

    if (heightCm !== undefined && heightCm !== null && heightCm !== '') {
      const h = Number(heightCm);
      if (isNaN(h) || h <= 0 || h < 50 || h > 280) {
        sendError(res, 'VALIDATION_ERROR', 'Please enter a valid height in cm (50 - 280 cm).', HttpStatus.BAD_REQUEST, undefined, undefined, {
          activity: 'Save Client Assessment',
          resourceId: existingProfile.clientId || undefined,
          resourceType: 'ClientProfile',
          explanation: `Invalid height value: ${heightCm}. Must be a valid numeric height between 50 and 280 cm.`,
          receivedPayload: { heightCm },
        });
        return;
      }
    }

    if (age !== undefined && age !== null && age !== '') {
      const a = Number(age);
      if (isNaN(a) || a <= 0 || a < 10 || a > 120 || !Number.isInteger(a)) {
        sendError(res, 'VALIDATION_ERROR', 'Please enter a valid whole age (10 - 120).', HttpStatus.BAD_REQUEST, undefined, undefined, {
          activity: 'Save Client Assessment',
          resourceId: existingProfile.clientId || undefined,
          resourceType: 'ClientProfile',
          explanation: `Invalid age value: ${age}. Must be an integer age between 10 and 120.`,
          receivedPayload: { age },
        });
        return;
      }
    }

    if (trainingDaysPerWeek !== undefined && trainingDaysPerWeek !== null && trainingDaysPerWeek !== '') {
      const d = Number(trainingDaysPerWeek);
      if (isNaN(d) || d < 1 || d > 7 || !Number.isInteger(d)) {
        sendError(res, 'VALIDATION_ERROR', 'Training days per week must be a whole number between 1 and 7.', HttpStatus.BAD_REQUEST, undefined, undefined, {
          activity: 'Save Client Assessment',
          resourceId: existingProfile.clientId || undefined,
          resourceType: 'ClientProfile',
          explanation: `Invalid training days per week: ${trainingDaysPerWeek}. Must be an integer between 1 and 7.`,
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

    sendSuccess(
      res,
      {
        message: 'Fitness assessment saved successfully',
        clientId: updatedProfile.clientId,
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
      activity: 'Save Client Assessment',
      resourceId: userId,
      resourceType: 'ClientProfile',
      explanation: 'Database write failed while updating client assessment.',
    });
  }
};
router.put(assessmentPaths, handleAssessmentUpdate);
router.post(assessmentPaths, handleAssessmentUpdate);

// GET /api/v1/client/me/workout: Active assigned workout
router.get('/me/workout', async (req: Request, res: Response) => {
  try {
    const userId = req.user!.id;
    const profile = await getAuthenticatedClientProfile(userId);

    const clientIdsToMatch: Array<string | null> = [userId];
    if (profile) {
      if (profile.clientId) clientIdsToMatch.push(profile.clientId);
      if (profile.id) clientIdsToMatch.push(profile.id);
    }

    // Check assignments for this specific client or global ("ALL") assignments
    const assignment = await prisma.workoutAssignment.findFirst({
      where: {
        OR: [
          { clientId: { in: clientIdsToMatch.filter(Boolean) as string[] } },
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
    sendError(res, 'INTERNAL_ERROR', 'Failed to fetch assigned workout', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err);
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
        OR: [
          { clientProfileId: profile.id },
          { clientId: profile.clientId },
          { clientId: req.user!.id },
        ],
        isActive: true,
      },
      orderBy: { createdAt: 'desc' },
    });

    sendSuccess(res, activeDietPlan);
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Failed to fetch assigned diet plan', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err);
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
    sendError(res, 'INTERNAL_ERROR', 'Failed to fetch assigned macros', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err);
  }
});

// GET /api/v1/client/me/food-logs: Client fetches their actual logged meals for a specific date
router.get('/me/food-logs', async (req: Request, res: Response) => {
  const dateQuery = String(req.query.date || '');
  const targetDate = dateQuery.trim() || new Date().toISOString().split('T')[0];

  try {
    const profile = await getAuthenticatedClientProfile(req.user!.id);
    if (!profile) {
      sendError(res, 'NOT_FOUND', 'Client profile not found', HttpStatus.NOT_FOUND);
      return;
    }

    const logs = await prisma.clientFoodLog.findMany({
      where: {
        clientProfileId: profile.id,
        dateString: targetDate,
      },
      orderBy: { loggedAt: 'asc' },
    });

    sendSuccess(res, logs);
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Failed to fetch actual food logs', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err);
  }
});

// POST /api/v1/client/me/food-logs: Client logs confirmed actual food (Food Library, Snacks, Custom Food, or AI Camera)
router.post('/me/food-logs', async (req: Request, res: Response) => {
  try {
    const profile = await getAuthenticatedClientProfile(req.user!.id);
    if (!profile) {
      sendError(res, 'NOT_FOUND', 'Client profile not found', HttpStatus.NOT_FOUND);
      return;
    }

    const body = req.body;
    const entries = Array.isArray(body) ? body : (body.entries || [body]);

    const createdList = [];
    for (const item of entries) {
      if (!item.foodName || typeof item.foodName !== 'string') continue;

      const dateStr = item.dateString || new Date().toISOString().split('T')[0];
      const dateObj = new Date(dateStr);

      const created = await prisma.clientFoodLog.create({
        data: {
          clientProfileId: profile.id,
          clientId: profile.clientId || profile.id,
          date: dateObj,
          dateString: dateStr,
          mealType: item.mealType || 'Lunch',
          foodId: item.foodId || null,
          foodName: item.foodName.trim(),
          category: item.category || 'General',
          servingSize: Number(item.servingSize) || 100,
          servingUnit: item.servingUnit || 'g',
          quantity: Number(item.quantity) || 1.0,
          calories: Number(item.calories) || 0,
          protein: Number(item.protein) || 0,
          carbohydrates: Number(item.carbohydrates ?? item.carbs) || 0,
          fat: Number(item.fat) || 0,
          fiber: Number(item.fiber) || 0,
          source: item.source || 'FOOD_LIBRARY',
          isAiConfirmed: item.isAiConfirmed !== undefined ? Boolean(item.isAiConfirmed) : true,
          loggedAt: item.loggedAt ? new Date(item.loggedAt) : new Date(),
        },
      });
      createdList.push(created);
    }

    sendSuccess(res, createdList, HttpStatus.CREATED);
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Failed to log food entry', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err);
  }
});

// POST /api/v1/client/me/food-photos/confirm: Securely upload and confirm meal photo with food items
router.post('/me/food-photos/confirm', (req: Request, res: Response) => {
  foodPhotoController.confirmAndUploadMealPhoto(req, res);
});

// GET /api/v1/client/me/food-photos: Retrieve list of client's own confirmed meal photos
router.get('/me/food-photos', async (req: Request, res: Response) => {
  try {
    const profile = await getAuthenticatedClientProfile(req.user!.id);
    if (!profile) {
      sendError(res, 'NOT_FOUND', 'Client profile not found', HttpStatus.NOT_FOUND);
      return;
    }

    const dateQuery = String(req.query.date || '').trim();
    const whereClause: any = {
      clientProfileId: profile.id,
      isDeleted: false,
    };
    if (dateQuery) {
      whereClause.dateString = dateQuery;
    }

    const photos = await prisma.mealPhoto.findMany({
      where: whereClause,
      orderBy: { confirmedAt: 'desc' },
    });

    const mapped = photos.map((p) => {
      let items = [];
      if (p.itemsJson) {
        try {
          items = JSON.parse(p.itemsJson);
        } catch (_) {}
      }
      return {
        id: p.id,
        mealId: p.mealId,
        clientId: p.clientId,
        dateString: p.dateString,
        mealType: p.mealType,
        confirmedAt: p.confirmedAt,
        capturedAt: p.capturedAt,
        weightSource: p.weightSource,
        totalCalories: p.totalCalories,
        totalProtein: p.totalProtein,
        totalCarbs: p.totalCarbs,
        totalFat: p.totalFat,
        totalFiber: p.totalFiber,
        photoUrl: `/api/v1/food-photos/${p.id}/image`,
        photoAvailable: true,
        items,
      };
    });

    sendSuccess(res, mapped);
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Failed to fetch meal photos', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err);
  }
});

// DELETE /api/v1/client/me/food-logs/:id: Remove a single logged item (strictly authorized)
router.delete('/me/food-logs/:id', async (req: Request, res: Response) => {
  const id = String(req.params.id || '');
  try {
    const profile = await getAuthenticatedClientProfile(req.user!.id);
    if (!profile) {
      sendError(res, 'NOT_FOUND', 'Client profile not found', HttpStatus.NOT_FOUND);
      return;
    }

    const entry = await prisma.clientFoodLog.findFirst({
      where: { id, clientProfileId: profile.id },
    });

    if (!entry) {
      sendError(res, 'NOT_FOUND', 'Food log entry not found or unauthorized', HttpStatus.NOT_FOUND);
      return;
    }

    await prisma.clientFoodLog.delete({ where: { id } });
    sendSuccess(res, { deleted: true, id });
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Failed to delete food log entry', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err);
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
    sendError(res, 'INTERNAL_ERROR', 'Failed to fetch attendance history', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err);
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
    sendError(res, 'INTERNAL_ERROR', 'Failed to fetch progress history', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err);
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
    sendError(res, 'INTERNAL_ERROR', 'Failed to log progress check-in', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err);
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
    sendError(res, 'INTERNAL_ERROR', 'Failed to fetch challenge status', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err);
  }
});

// ==========================================
// WEEKLY CHECK-IN SYSTEM (CLIENT ENDPOINTS)
// ==========================================

// GET /api/v1/client/me/weekly-check-ins/status
// Determines if client can check in (only once per week)
router.get('/me/weekly-check-ins/status', async (req: Request, res: Response) => {
  try {
    const profile = await getAuthenticatedClientProfile(req.user!.id);
    if (!profile) {
      sendError(res, 'NOT_FOUND', 'Client profile not found', HttpStatus.NOT_FOUND);
      return;
    }

    const latestCheckIn = await prisma.weeklyCheckIn.findFirst({
      where: { clientProfileId: profile.id },
      orderBy: { checkInDate: 'desc' },
    });

    const now = new Date();

    if (!latestCheckIn) {
      // First check-in is immediately available
      sendSuccess(res, {
        isAvailable: true,
        currentWeekNumber: 1,
        lastCheckIn: null,
        nextCheckInDate: null,
        daysUntilNext: 0,
        statusText: 'Week 1 Check-In Available',
      });
      return;
    }

    const isAvailable = now >= latestCheckIn.nextCheckInDate;
    const diffMs = latestCheckIn.nextCheckInDate.getTime() - now.getTime();
    const daysUntilNext = isAvailable ? 0 : Math.ceil(diffMs / (1000 * 60 * 60 * 24));
    const nextWeekNumber = latestCheckIn.weekNumber + 1;

    sendSuccess(res, {
      isAvailable,
      currentWeekNumber: isAvailable ? nextWeekNumber : latestCheckIn.weekNumber,
      lastCheckIn: latestCheckIn,
      nextCheckInDate: latestCheckIn.nextCheckInDate.toISOString(),
      daysUntilNext,
      statusText: isAvailable
        ? `Week ${nextWeekNumber} Check-In Available`
        : `Weekly Check-In Completed ✓ (Next: ${latestCheckIn.nextCheckInDate.toISOString().split('T')[0]})`,
    });
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Failed to fetch weekly check-in status', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err);
  }
});

// GET /api/v1/client/me/weekly-check-ins: Full history of weekly check-ins for authenticated client
router.get('/me/weekly-check-ins', async (req: Request, res: Response) => {
  try {
    const profile = await getAuthenticatedClientProfile(req.user!.id);
    if (!profile) {
      sendError(res, 'NOT_FOUND', 'Client profile not found', HttpStatus.NOT_FOUND);
      return;
    }

    const checkIns = await prisma.weeklyCheckIn.findMany({
      where: { clientProfileId: profile.id },
      orderBy: { weekNumber: 'desc' },
    });

    sendSuccess(res, checkIns);
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Failed to fetch weekly check-in history', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err);
  }
});

// GET /api/v1/client/me/weekly-check-ins/:id: Specific check-in detail
router.get('/me/weekly-check-ins/:id', async (req: Request, res: Response) => {
  try {
    const profile = await getAuthenticatedClientProfile(req.user!.id);
    if (!profile) {
      sendError(res, 'NOT_FOUND', 'Client profile not found', HttpStatus.NOT_FOUND);
      return;
    }

    const checkInId = String(req.params.id);
    const checkIn = await prisma.weeklyCheckIn.findFirst({
      where: { id: checkInId, clientProfileId: profile.id },
    });

    if (!checkIn) {
      sendError(res, 'NOT_FOUND', 'Weekly check-in not found', HttpStatus.NOT_FOUND);
      return;
    }

    sendSuccess(res, checkIn);
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Failed to fetch check-in details', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err);
  }
});

// POST /api/v1/client/me/weekly-check-ins: Submit a weekly check-in
// Strictly enforces 1 check-in per week rule on the backend
router.post('/me/weekly-check-ins', async (req: Request, res: Response) => {
  const {
    weightKg,
    waistCm,
    chestCm,
    armsCm,
    hipsCm,
    thighsCm,
    nutritionCalories,
    nutritionProtein,
    nutritionWater,
    dietAdherence,
    sleepQuality,
    sleepHours,
    recoveryQuality,
    workoutCompletion,
    workoutFeeling,
    energyLevel,
    hasPain,
    painLocation,
    painExercise,
    painLevel,
    painDescription,
    weeklyProblems,
    clientNotes,
  } = req.body;

  if (weightKg === undefined || weightKg === null || isNaN(Number(weightKg)) || Number(weightKg) < 25 || Number(weightKg) > 350) {
    sendError(res, 'VALIDATION_ERROR', 'Valid body weight in kg (25-350 kg) is required', HttpStatus.BAD_REQUEST);
    return;
  }

  try {
    const profile = await getAuthenticatedClientProfile(req.user!.id);
    if (!profile) {
      sendError(res, 'NOT_FOUND', 'Client profile not found', HttpStatus.NOT_FOUND);
      return;
    }

    // 1. Check existing check-ins to enforce weekly restriction
    const latestCheckIn = await prisma.weeklyCheckIn.findFirst({
      where: { clientProfileId: profile.id },
      orderBy: { checkInDate: 'desc' },
    });

    const now = new Date();

    if (latestCheckIn && now < latestCheckIn.nextCheckInDate) {
      const nextDateStr = latestCheckIn.nextCheckInDate.toISOString().split('T')[0];
      sendError(
        res,
        'WEEKLY_LOCKED',
        `Weekly check-in already submitted for this week. Next check-in unlocks on ${nextDateStr}.`,
        HttpStatus.CONFLICT
      );
      return;
    }

    const weekNumber = latestCheckIn ? latestCheckIn.weekNumber + 1 : 1;
    const year = now.getFullYear();
    // Next check-in is exactly 7 days later
    const nextCheckInDate = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);

    // Calculate changes vs previous week if available
    const weightVal = Number(Number(weightKg).toFixed(1));
    const waistVal = waistCm && !isNaN(Number(waistCm)) ? Number(Number(waistCm).toFixed(1)) : null;

    let weightChange: number | null = null;
    let waistChange: number | null = null;

    if (latestCheckIn) {
      weightChange = Number((weightVal - latestCheckIn.weightKg).toFixed(1));
      if (waistVal !== null && latestCheckIn.waistCm !== null) {
        waistChange = Number((waistVal - latestCheckIn.waistCm).toFixed(1));
      }
    }

    // Create record in database
    const checkIn = await prisma.weeklyCheckIn.create({
      data: {
        clientProfileId: profile.id,
        clientId: profile.clientId,
        weekNumber,
        year,
        checkInDate: now,
        nextCheckInDate,
        weightKg: weightVal,
        waistCm: waistVal,
        chestCm: chestCm && !isNaN(Number(chestCm)) ? Number(chestCm) : null,
        armsCm: armsCm && !isNaN(Number(armsCm)) ? Number(armsCm) : null,
        hipsCm: hipsCm && !isNaN(Number(hipsCm)) ? Number(hipsCm) : null,
        thighsCm: thighsCm && !isNaN(Number(thighsCm)) ? Number(thighsCm) : null,
        weightChange,
        waistChange,
        nutritionCalories: String(nutritionCalories || 'Good'),
        nutritionProtein: String(nutritionProtein || 'Good'),
        nutritionWater: String(nutritionWater || 'Good'),
        dietAdherence: String(dietAdherence || 'Good'),
        sleepQuality: String(sleepQuality || 'Good'),
        sleepHours: Number(sleepHours) || 7.0,
        recoveryQuality: String(recoveryQuality || 'Good'),
        workoutCompletion: String(workoutCompletion || 'All'),
        workoutFeeling: String(workoutFeeling || 'Good'),
        energyLevel: String(energyLevel || 'Good'),
        hasPain: Boolean(hasPain),
        painLocation: hasPain ? String(painLocation || '') : null,
        painExercise: hasPain ? String(painExercise || '') : null,
        painLevel: hasPain && painLevel ? Number(painLevel) : null,
        painDescription: hasPain ? String(painDescription || '') : null,
        weeklyProblems: Array.isArray(weeklyProblems) ? weeklyProblems.map(String) : [],
        clientNotes: clientNotes ? String(clientNotes).trim() : null,
      },
    });

    // Also update client profile weightKg to keep profile current
    await prisma.clientProfile.update({
      where: { id: profile.id },
      data: { weightKg: weightVal },
    });

    sendSuccess(
      res,
      {
        checkIn,
        summary: {
          weekNumber,
          weightKg: weightVal,
          weightChange,
          waistCm: waistVal,
          waistChange,
          nextCheckInDate: nextCheckInDate.toISOString(),
          statusText: 'Weekly Check-In Completed ✓',
        },
      },
      HttpStatus.CREATED
    );
  } catch (err: any) {
    if (err.code === 'P2002') {
      sendError(res, 'DUPLICATE_CHECK_IN', 'A check-in for this week already exists.', HttpStatus.CONFLICT, undefined, err);
      return;
    }
    sendError(res, 'INTERNAL_ERROR', 'Failed to submit weekly check-in', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err);
  }
});

// ==========================================
// AUTOMATION & ENGAGEMENT CLIENT ENDPOINTS
// ==========================================

// Activity heartbeat ping: records app open timestamp for inactivity tracking
router.post('/me/activity-ping', (req: Request, res: Response) =>
  automationController.pingActivity(req, res)
);

// Notifications list for client
router.get('/me/notifications', (req: Request, res: Response) =>
  automationController.getClientNotifications(req, res)
);

// Mark single notification read
router.put('/me/notifications/:id/read', (req: Request, res: Response) =>
  automationController.markNotificationRead(req, res)
);

// Mark all notifications read
router.put('/me/notifications/read-all', (req: Request, res: Response) =>
  automationController.markAllNotificationsRead(req, res)
);

// Notification preferences
router.get('/me/notification-preferences', (req: Request, res: Response) =>
  automationController.getNotificationPreferences(req, res)
);

router.put('/me/notification-preferences', (req: Request, res: Response) =>
  automationController.updateNotificationPreferences(req, res)
);

// Transformation timeline milestones (Week 1, 4, 8, 12 photos + stats)
router.get('/me/transformation-timeline', (req: Request, res: Response) =>
  automationController.getTransformationTimeline(req, res)
);

router.post('/me/transformation-timeline', (req: Request, res: Response) =>
  automationController.saveTransformationMilestone(req, res)
);

export const clientRoutes = router;



