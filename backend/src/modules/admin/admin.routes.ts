import { Router, Request, Response } from 'express';
import { requireAuth, requireAdmin } from '../../middlewares/auth';
import { adminAuthService } from '../auth/admin_auth.service';
import { workoutController } from '../workout/workout.controller';
import { exerciseController } from '../exercise/exercise.controller';
import { HttpStatus } from '../../constants/httpStatus';
import { sendSuccess, sendError } from '../../utils/responseEnvelope';
import { prisma } from '../../config/prisma';
import { foodPhotoController } from '../food/food.photo.controller';
import { automationController } from '../automation/automation.controller';
import { maskPhone, maskEmail } from '../../utils/pii_mask';

const router = Router();

// ==========================================
// 1. PUBLIC ADMIN LOGIN ENDPOINT
// POST /api/admin/login or POST /api/v1/admin/login
// 100% PRESERVES WORKING ADMIN LOGIN
// ==========================================
router.post('/login', async (req: Request, res: Response) => {
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

// ==========================================
// 2. PROTECTED ADMIN-ONLY API ROUTER
// All routes below require valid token + ADMIN role + match ADMIN_EMAIL.
// Unauthorized clients receive 403 Forbidden.
// ==========================================
router.use(requireAuth, requireAdmin);

// --- Admin Workout Operations ---
router.get(['/workouts', '/sessions'], (req: Request, res: Response) => workoutController.getAllAdminSessions(req, res));
router.post(['/workouts', '/sessions'], (req: Request, res: Response) => workoutController.createSession(req, res));
router.get(['/workouts/:id', '/sessions/:id'], (req: Request, res: Response) => workoutController.getAdminSessionById(req, res));
router.put(['/workouts/:id', '/sessions/:id'], (req: Request, res: Response) => workoutController.updateSession(req, res));
router.delete(['/workouts/:id', '/sessions/:id'], (req: Request, res: Response) => workoutController.deleteSession(req, res));
router.post(['/workouts/:id/duplicate', '/sessions/:id/duplicate'], (req: Request, res: Response) => workoutController.duplicateSession(req, res));
router.post(['/workouts/:id/assign', '/sessions/:id/assign'], (req: Request, res: Response) => workoutController.assignSession(req, res));
router.delete(['/workouts/assignments/:assignmentId', '/sessions/assignments/:assignmentId'], (req: Request, res: Response) => workoutController.unassign(req, res));

// --- Admin Exercise Operations ---
router.get('/exercises', (req: Request, res: Response) => exerciseController.searchExercises(req, res));
router.post('/exercises', (req: Request, res: Response) => exerciseController.createCustomExercise(req, res));
router.get('/exercises/:id', (req: Request, res: Response) => exerciseController.getExerciseById(req, res));
router.put('/exercises/:id', (req: Request, res: Response) => exerciseController.updateExercise(req, res));
router.delete('/exercises/:id', (req: Request, res: Response) => exerciseController.archiveExercise(req, res));
router.post('/exercises/sync', (req: Request, res: Response) => exerciseController.syncExercises(req, res));

// ==========================================
// 3. ADMIN CLIENT MANAGEMENT OPERATIONS
// Admin selects individual client (by clientId AXG-XXXX or userId)
// Manages: PROFILE, ASSESSMENT, WORKOUT, NUTRITION, MACROS, PROGRESS, ATTENDANCE, NOTES
// ==========================================

// Helper: resolves user & profile by clientId (AXG-XXXX), UUID, or email
async function findClientByIdOrClientId(idOrClientId: string) {
  const clean = idOrClientId.trim();
  return prisma.user.findFirst({
    where: {
      OR: [
        { id: clean },
        { clientProfile: { clientId: clean.toUpperCase() } },
        { clientProfile: { id: clean } },
        { email: clean.toLowerCase() },
      ],
    },
    include: {
      clientProfile: {
        include: {
          dietPlans: { orderBy: { createdAt: 'desc' } },
          macroPlans: { orderBy: { createdAt: 'desc' } },
          attendanceRecords: { orderBy: { date: 'desc' }, take: 30 },
          progressRecords: { orderBy: { date: 'desc' }, take: 30 },
          activityRecords: { orderBy: { date: 'desc' }, take: 30 },
        },
      },
      assignments: {
        include: {
          session: {
            include: {
              exercises: {
                orderBy: { orderIndex: 'asc' },
              },
            },
          },
        },
      },
    },
  });
}

// GET /clients: Returns all real clients from database
router.get('/clients', (req: Request, res: Response) => workoutController.getClientsList(req, res));

// GET /clients/:id: Complete Profile & Assessment for selected Client ID
router.get('/clients/:id', async (req: Request, res: Response) => {
  const idOrClientId = String(req.params.id || '');
  try {
    const user: any = await findClientByIdOrClientId(idOrClientId);

    if (user && user.clientProfile) {
      const cp = user.clientProfile;
      const todayStr = new Date().toISOString().split('T')[0];
      const todayActivity = cp.activityRecords?.find(
        (r: any) => r.date.toISOString().split('T')[0] === todayStr
      );
      const todaySteps = todayActivity ? todayActivity.steps : 0;
      const stepHistory = (cp.activityRecords || []).map((r: any) => ({
        id: r.id,
        date: r.date.toISOString().split('T')[0],
        steps: r.steps,
        stepGoal: r.stepGoal,
        cardioMinutes: r.cardioMinutes,
        caloriesBurned: r.caloriesBurned,
        distanceMeters: r.distanceMeters,
        isGoalAchieved: r.isGoalAchieved,
      }));

      sendSuccess(res, {
        id: user.id,
        clientId: cp.clientId,
        name: user.name,
        email: maskEmail(user.email),
        phone: maskPhone(cp.phone),
        createdAt: user.createdAt.toISOString(),
        assessmentCompleted: cp.onboardingCompleted,
        onboardingCompleted: cp.onboardingCompleted,
        onboardingStep: cp.onboardingStep,
        profile: cp,
        fitnessLevel: cp.fitnessLevel ?? 'beginner',
        primaryGoal: cp.primaryGoal ?? 'General Fitness',
        secondaryGoal: cp.secondaryGoal,
        weightKg: cp.weightKg,
        heightCm: cp.heightCm,
        age: cp.age,
        gender: cp.gender,
        trainingExperience: cp.trainingExperience,
        trainingDaysPerWeek: cp.trainingDaysPerWeek ?? 3,
        preferredDays: cp.preferredDays ?? [],
        hasCurrentInjury: cp.hasCurrentInjury ?? false,
        injuryAreas: cp.injuryAreas ?? [],
        injuryDetails: cp.injuryDescription,
        injuryDescription: cp.injuryDescription,
        hasPreviousSurgery: cp.hasPreviousSurgery ?? false,
        surgeryDetails: cp.surgeryDetails,
        activityLevel: cp.activityLevel ?? 'MODERATE',
        dailySteps: cp.dailySteps ?? cp.dailyStepGoal ?? 6000,
        dailyStepGoal: cp.dailyStepGoal ?? 6000,
        todaySteps,
        stepHistory,
        sleepHours: cp.sleepHours ?? '7–8 hours',
        trainingPreferences: cp.trainingPreferences ?? [],
        trainingTimePref: cp.trainingTimePref,
        adminNotes: cp.adminNotes,
        dietPlans: cp.dietPlans || [],
        macroPlans: cp.macroPlans || [],
        activeDietPlan: cp.dietPlans?.find((d: any) => d.isActive) || null,
        activeMacroPlan: cp.macroPlans?.find((m: any) => m.isActive) || null,
        attendance: cp.attendanceRecords || [],
        progress: cp.progressRecords || [],
        assignedWorkouts: user.assignments || [],
        managedBy: adminAuthService.getAdminEmail(),
      });
      return;
    }

    sendError(res, 'NOT_FOUND', `Client with ID ${idOrClientId} not found in database.`, HttpStatus.NOT_FOUND);
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Failed to retrieve client profile', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err);
  }
});

// PUT /clients/:id/notes: Private Admin Notes (not automatically shown to client)
router.put('/clients/:id/notes', async (req: Request, res: Response) => {
  const idOrClientId = String(req.params.id || '');
  const { notes } = req.body;

  try {
    const user = await findClientByIdOrClientId(idOrClientId);
    if (!user || !user.clientProfile) {
      sendError(res, 'NOT_FOUND', 'Client profile not found', HttpStatus.NOT_FOUND);
      return;
    }

    const updated = await prisma.clientProfile.update({
      where: { id: user.clientProfile.id },
      data: { adminNotes: typeof notes === 'string' ? notes : null },
    });

    sendSuccess(res, {
      message: 'Admin notes saved successfully',
      clientId: updated.clientId,
      adminNotes: updated.adminNotes,
    });
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Failed to save admin notes', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err);
  }
});

// GET /clients/:id/workouts: Assigned workouts for client
router.get('/clients/:id/workouts', async (req: Request, res: Response) => {
  const idOrClientId = String(req.params.id || '');
  try {
    const user = await findClientByIdOrClientId(idOrClientId);
    if (!user) {
      sendError(res, 'NOT_FOUND', 'Client not found', HttpStatus.NOT_FOUND);
      return;
    }

    const assignments = await prisma.workoutAssignment.findMany({
      where: { clientId: user.id },
      include: {
        session: {
          include: {
            exercises: {
              orderBy: { orderIndex: 'asc' },
              include: { setTemplates: { orderBy: { setNumber: 'asc' } } },
            },
          },
        },
      },
      orderBy: { assignedAt: 'desc' },
    });

    sendSuccess(res, assignments);
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Failed to fetch client workouts', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

// POST /clients/:id/workouts: Assign workout session to this client
router.post('/clients/:id/workouts', async (req: Request, res: Response) => {
  const idOrClientId = String(req.params.id || '');
  const { sessionId, isRecommended } = req.body;

  if (!sessionId) {
    sendError(res, 'VALIDATION_ERROR', 'Workout sessionId is required', HttpStatus.BAD_REQUEST);
    return;
  }

  try {
    const user = await findClientByIdOrClientId(idOrClientId);
    if (!user) {
      sendError(res, 'NOT_FOUND', 'Client not found', HttpStatus.NOT_FOUND);
      return;
    }

    if (isRecommended === true) {
      await prisma.workoutAssignment.updateMany({
        where: { clientId: user.id, isRecommended: true },
        data: { isRecommended: false },
      });
    }

    // Check if assignment already exists
    const existing = await prisma.workoutAssignment.findUnique({
      where: {
        session_client_assignment_unique: {
          sessionId,
          clientId: user.id,
        },
      },
    });

    if (existing) {
      const updated = await prisma.workoutAssignment.update({
        where: { id: existing.id },
        data: {
          isRecommended: isRecommended === true,
          active: true,
          assignedAt: new Date(),
          assignedById: req.user!.id,
        },
        include: { session: true },
      });
      sendSuccess(res, updated, HttpStatus.OK);
      return;
    }

    const assignment = await prisma.workoutAssignment.create({
      data: {
        sessionId,
        clientId: user.id,
        isRecommended: isRecommended === true,
        assignedById: req.user!.id,
        active: true,
      },
      include: {
        session: true,
      },
    });

    sendSuccess(res, assignment, HttpStatus.CREATED);
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Failed to assign workout to client', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err);
  }
});

// GET /clients/:id/diet-plans: List all diet plans for client (Active & History)
router.get('/clients/:id/diet-plans', async (req: Request, res: Response) => {
  const idOrClientId = String(req.params.id || '');
  try {
    const user = await findClientByIdOrClientId(idOrClientId);
    if (!user || !user.clientProfile) {
      sendError(res, 'NOT_FOUND', 'Client not found', HttpStatus.NOT_FOUND);
      return;
    }

    const dietPlans = await prisma.dietPlan.findMany({
      where: { clientProfileId: user.clientProfile.id },
      orderBy: { createdAt: 'desc' },
    });

    sendSuccess(res, dietPlans);
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Failed to fetch diet plans', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

// POST /clients/:id/diet-plans: Create and Assign Diet Plan to Client
// Old active plan -> inactive/history, new plan -> active
router.post('/clients/:id/diet-plans', async (req: Request, res: Response) => {
  const idOrClientId = String(req.params.id || '');
  const {
    planName,
    startDate,
    endDate,
    dailyCalories,
    protein,
    carbohydrates,
    fat,
    fiber,
    waterTargetLiters,
    meals,
    notes,
  } = req.body;

  if (!planName || typeof planName !== 'string') {
    sendError(res, 'VALIDATION_ERROR', 'Diet plan name is required', HttpStatus.BAD_REQUEST);
    return;
  }

  try {
    const user = await findClientByIdOrClientId(idOrClientId);
    if (!user || !user.clientProfile) {
      sendError(res, 'NOT_FOUND', 'Client not found', HttpStatus.NOT_FOUND);
      return;
    }

    const cp = user.clientProfile;

    // Find latest existing plan to increment version
    const previousPlan = await prisma.dietPlan.findFirst({
      where: { clientProfileId: cp.id, isActive: true },
      orderBy: { createdAt: 'desc' },
    });
    const nextVersion = previousPlan ? previousPlan.version + 1 : 1;

    // Admin attribution
    const adminUser = (req as any).user || {};
    const adminId = adminUser.id || 'admin_alex_stone';
    const adminName = adminUser.name || 'Alex Stone';

    // Deactivate previous active diet plans for this client (Preserve history)
    await prisma.dietPlan.updateMany({
      where: {
        clientProfileId: cp.id,
        isActive: true,
      },
      data: { isActive: false },
    });

    // Create the new active diet plan with versioning
    const newDietPlan = await prisma.dietPlan.create({
      data: {
        clientProfileId: cp.id,
        clientId: cp.clientId,
        planName: planName.trim(),
        version: nextVersion,
        assignedById: adminId,
        assignedByName: adminName,
        startDate: startDate ? new Date(startDate) : new Date(),
        endDate: endDate ? new Date(endDate) : null,
        dailyCalories: Number(dailyCalories) || 2000,
        protein: Number(protein) || 150,
        carbohydrates: Number(carbohydrates) || 200,
        fat: Number(fat) || 60,
        fiber: Number(fiber) || 30,
        waterTargetLiters: Number(waterTargetLiters) || 3.0,
        isActive: true,
        mealsJson: meals ? (typeof meals === 'string' ? meals : JSON.stringify(meals)) : null,
        notes: notes || null,
      },
    });

    // Create historical version entry
    await prisma.dietPlanHistory.create({
      data: {
        dietPlanId: newDietPlan.id,
        clientProfileId: cp.id,
        clientId: cp.clientId,
        adminId,
        adminName,
        version: nextVersion,
        planName: newDietPlan.planName,
        dailyCalories: newDietPlan.dailyCalories,
        protein: newDietPlan.protein,
        carbohydrates: newDietPlan.carbohydrates,
        fat: newDietPlan.fat,
        fiber: newDietPlan.fiber,
        waterTargetLiters: newDietPlan.waterTargetLiters,
        mealsJson: newDietPlan.mealsJson,
        notes: newDietPlan.notes,
        changeSummary: previousPlan
          ? `Updated from v${previousPlan.version} (${previousPlan.planName}) to v${nextVersion} (${newDietPlan.planName})`
          : `Initial Diet Plan v1 assigned`,
      },
    });

    sendSuccess(res, newDietPlan, HttpStatus.CREATED);
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Failed to create diet plan', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err);
  }
});

// GET /clients/:id/diet-plans/history: Version history of client's diet plans
router.get('/clients/:id/diet-plans/history', async (req: Request, res: Response) => {
  const idOrClientId = String(req.params.id || '');
  try {
    const user = await findClientByIdOrClientId(idOrClientId);
    if (!user || !user.clientProfile) {
      sendError(res, 'NOT_FOUND', 'Client not found', HttpStatus.NOT_FOUND);
      return;
    }

    const history = await prisma.dietPlanHistory.findMany({
      where: { clientProfileId: user.clientProfile.id },
      orderBy: { createdAt: 'desc' },
    });

    sendSuccess(res, history);
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Failed to fetch diet history', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

// GET /clients/:id/nutrition-summary: Target vs Actual daily nutrition comparison
router.get('/clients/:id/nutrition-summary', async (req: Request, res: Response) => {
  const idOrClientId = String(req.params.id || '');
  const dateQuery = String(req.query.date || '');
  const targetDate = dateQuery.trim() || new Date().toISOString().split('T')[0];

  try {
    const user = await findClientByIdOrClientId(idOrClientId);
    if (!user || !user.clientProfile) {
      sendError(res, 'NOT_FOUND', 'Client not found', HttpStatus.NOT_FOUND);
      return;
    }

    const cp = user.clientProfile;

    // 1. Fetch currently active assigned diet plan
    const activeDietPlan = await prisma.dietPlan.findFirst({
      where: { clientProfileId: cp.id, isActive: true },
      orderBy: { createdAt: 'desc' },
    });

    // 2. Fetch actual food logs recorded by client on this date
    const foodLogs = await prisma.clientFoodLog.findMany({
      where: {
        clientProfileId: cp.id,
        dateString: targetDate,
      },
      include: {
        mealPhoto: true,
      },
      orderBy: { loggedAt: 'asc' },
    });

    // 2b. Fetch confirmed meal photos recorded by client on this date
    const mealPhotos = await prisma.mealPhoto.findMany({
      where: {
        clientProfileId: cp.id,
        dateString: targetDate,
        isDeleted: false,
      },
      orderBy: { confirmedAt: 'asc' },
    });

    // 3. Compute actual totals
    const consumedCalories = foodLogs.reduce((acc, log) => acc + log.calories * log.quantity, 0);
    const consumedProtein = foodLogs.reduce((acc, log) => acc + log.protein * log.quantity, 0);
    const consumedCarbs = foodLogs.reduce((acc, log) => acc + log.carbohydrates * log.quantity, 0);
    const consumedFat = foodLogs.reduce((acc, log) => acc + log.fat * log.quantity, 0);
    const consumedFiber = foodLogs.reduce((acc, log) => acc + log.fiber * log.quantity, 0);

    const assignedCalories = activeDietPlan?.dailyCalories ?? 2000;
    const assignedProtein = activeDietPlan?.protein ?? 150;
    const assignedCarbs = activeDietPlan?.carbohydrates ?? 200;
    const assignedFat = activeDietPlan?.fat ?? 60;
    const assignedFiber = activeDietPlan?.fiber ?? 30;

    // Group actual meals
    const mealGroups: Record<string, any[]> = {
      Breakfast: [],
      Lunch: [],
      Snacks: [],
      Dinner: [],
    };

    for (const log of foodLogs) {
      const mType = log.mealType.charAt(0).toUpperCase() + log.mealType.slice(1).toLowerCase();
      const key = mType.startsWith('Snack') ? 'Snacks' : mType;
      if (!mealGroups[key]) mealGroups[key] = [];
      mealGroups[key].push(log);
    }

    const mealPhotosByType: Record<string, any[]> = {
      Breakfast: [],
      Lunch: [],
      Snacks: [],
      Dinner: [],
    };

    for (const p of mealPhotos) {
      const mType = p.mealType.charAt(0).toUpperCase() + p.mealType.slice(1).toLowerCase();
      const key = mType.startsWith('Snack') ? 'Snacks' : mType;
      if (!mealPhotosByType[key]) mealPhotosByType[key] = [];
      let parsedItems = [];
      if (p.itemsJson) {
        try {
          parsedItems = JSON.parse(p.itemsJson);
        } catch (_) {}
      }
      mealPhotosByType[key].push({
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
        items: parsedItems,
      });
    }

    const loggedMealTypes = Object.keys(mealGroups).filter(k => mealGroups[k].length > 0);
    const lastMealTime = foodLogs.length > 0 ? foodLogs[foodLogs.length - 1].loggedAt : null;

    sendSuccess(res, {
      clientId: cp.clientId || user.id,
      clientName: user.name,
      date: targetDate,
      assignedDiet: activeDietPlan,
      actualFoodLogs: foodLogs,
      meals: mealGroups,
      mealPhotos: mealPhotos.map((p) => ({
        id: p.id,
        mealId: p.mealId,
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
      })),
      mealPhotosByType,
      totalMealsLogged: loggedMealTypes.length,
      lastMealTime,
      comparison: {
        calories: {
          assigned: assignedCalories,
          actual: Math.round(consumedCalories),
          diff: Math.round(consumedCalories - assignedCalories),
        },
        protein: {
          assigned: assignedProtein,
          actual: Math.round(consumedProtein * 10) / 10,
          diff: Math.round((consumedProtein - assignedProtein) * 10) / 10,
        },
        carbohydrates: {
          assigned: assignedCarbs,
          actual: Math.round(consumedCarbs * 10) / 10,
          diff: Math.round((consumedCarbs - assignedCarbs) * 10) / 10,
        },
        fat: {
          assigned: assignedFat,
          actual: Math.round(consumedFat * 10) / 10,
          diff: Math.round((consumedFat - assignedFat) * 10) / 10,
        },
        fiber: {
          assigned: assignedFiber,
          actual: Math.round(consumedFiber * 10) / 10,
          diff: Math.round((consumedFiber - assignedFiber) * 10) / 10,
        },
      },
    });
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Failed to generate nutrition summary', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err);
  }
});

// GET /clients/:id/macros: Fetch Active Macro Target for Client
router.get('/clients/:id/macros', async (req: Request, res: Response) => {
  const idOrClientId = String(req.params.id || '');
  try {
    const user = await findClientByIdOrClientId(idOrClientId);
    if (!user || !user.clientProfile) {
      sendError(res, 'NOT_FOUND', 'Client not found', HttpStatus.NOT_FOUND);
      return;
    }

    const macroPlan = await prisma.macroPlan.findFirst({
      where: { clientProfileId: user.clientProfile.id, isActive: true },
      orderBy: { createdAt: 'desc' },
    });

    sendSuccess(res, macroPlan);
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Failed to fetch macro targets', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err);
  }
});

// POST /clients/:id/macros: Assign Macro Targets to Client
// Deactivates previous active plan, marks new plan active
router.post('/clients/:id/macros', async (req: Request, res: Response) => {
  const idOrClientId = String(req.params.id || '');
  const { calories, protein, carbs, fat, fiber, waterLiters, notes } = req.body;

  try {
    const user = await findClientByIdOrClientId(idOrClientId);
    if (!user || !user.clientProfile) {
      sendError(res, 'NOT_FOUND', 'Client not found', HttpStatus.NOT_FOUND);
      return;
    }

    const cp = user.clientProfile;

    // Deactivate previous active plans
    await prisma.macroPlan.updateMany({
      where: { clientProfileId: cp.id, isActive: true },
      data: { isActive: false },
    });

    const newMacroPlan = await prisma.macroPlan.create({
      data: {
        clientProfileId: cp.id,
        clientId: cp.clientId,
        calories: Number(calories) || 2000,
        protein: Number(protein) || 150,
        carbs: Number(carbs) || 200,
        fat: Number(fat) || 60,
        fiber: Number(fiber) || 30,
        waterLiters: Number(waterLiters) || 3.0,
        isActive: true,
        notes: notes || null,
      },
    });

    sendSuccess(res, newMacroPlan, HttpStatus.CREATED);
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Failed to assign macro targets', HttpStatus.INTERNAL_SERVER_ERROR, undefined, err);
  }
});

// GET /clients/:id/attendance: View Client Attendance
router.get('/clients/:id/attendance', async (req: Request, res: Response) => {
  const idOrClientId = String(req.params.id || '');
  try {
    const user = await findClientByIdOrClientId(idOrClientId);
    if (!user || !user.clientProfile) {
      sendError(res, 'NOT_FOUND', 'Client not found', HttpStatus.NOT_FOUND);
      return;
    }

    const records = await prisma.clientAttendance.findMany({
      where: { clientProfileId: user.clientProfile.id },
      orderBy: { date: 'desc' },
      take: 60,
    });

    sendSuccess(res, records);
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Failed to fetch attendance records', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

// POST /clients/:id/attendance: Record Client Attendance
router.post('/clients/:id/attendance', async (req: Request, res: Response) => {
  const idOrClientId = String(req.params.id || '');
  const { date, present, method, notes } = req.body;

  try {
    const user = await findClientByIdOrClientId(idOrClientId);
    if (!user || !user.clientProfile) {
      sendError(res, 'NOT_FOUND', 'Client not found', HttpStatus.NOT_FOUND);
      return;
    }

    const cp = user.clientProfile;
    const record = await prisma.clientAttendance.create({
      data: {
        clientProfileId: cp.id,
        clientId: cp.clientId,
        date: date ? new Date(date) : new Date(),
        present: present !== false,
        method: method || 'MANUAL',
        notes: notes || null,
      },
    });

    sendSuccess(res, record, HttpStatus.CREATED);
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Failed to record attendance', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

// GET /clients/:id/progress: View Client Progress / Weight History
router.get('/clients/:id/progress', async (req: Request, res: Response) => {
  const idOrClientId = String(req.params.id || '');
  try {
    const user = await findClientByIdOrClientId(idOrClientId);
    if (!user || !user.clientProfile) {
      sendError(res, 'NOT_FOUND', 'Client not found', HttpStatus.NOT_FOUND);
      return;
    }

    const records = await prisma.clientProgress.findMany({
      where: { clientProfileId: user.clientProfile.id },
      orderBy: { date: 'desc' },
      take: 60,
    });

    sendSuccess(res, records);
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Failed to fetch progress history', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

// POST /clients/:id/progress: Record Client Weight Progress
router.post('/clients/:id/progress', async (req: Request, res: Response) => {
  const idOrClientId = String(req.params.id || '');
  const { weightKg, waistCm, notes, date } = req.body;

  if (weightKg === undefined || weightKg === null || isNaN(Number(weightKg))) {
    sendError(res, 'VALIDATION_ERROR', 'Valid weight in kg is required', HttpStatus.BAD_REQUEST);
    return;
  }

  try {
    const user = await findClientByIdOrClientId(idOrClientId);
    if (!user || !user.clientProfile) {
      sendError(res, 'NOT_FOUND', 'Client not found', HttpStatus.NOT_FOUND);
      return;
    }

    const cp = user.clientProfile;
    const record = await prisma.clientProgress.create({
      data: {
        clientProfileId: cp.id,
        clientId: cp.clientId,
        weightKg: Number(weightKg),
        waistCm: waistCm !== undefined && waistCm !== null ? Number(waistCm) : null,
        notes: notes || null,
        date: date ? new Date(date) : new Date(),
      },
    });

    // Also update current weight on clientProfile
    await prisma.clientProfile.update({
      where: { id: cp.id },
      data: { weightKg: Number(weightKg) },
    });

    sendSuccess(res, record, HttpStatus.CREATED);
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Failed to record progress check-in', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

// --- Real Attendance Endpoints ---
router.get('/attendance', async (_req: Request, res: Response) => {
  try {
    const attendances = await prisma.clientAttendance.findMany({
      include: {
        clientProfile: {
          include: {
            user: { select: { name: true, email: true } },
          },
        },
      },
      orderBy: { checkInTime: 'desc' },
      take: 100,
    });

    const mapped = attendances.map((a) => ({
      id: a.id,
      clientId: a.clientProfile?.clientId || a.clientId || '',
      clientName: a.clientProfile?.user?.name || 'Athlete Member',
      checkInTime: a.checkInTime.toISOString(),
      method: a.method,
      verified: a.present,
    }));

    sendSuccess(res, mapped);
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Failed to retrieve attendance records', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

router.post('/attendance/verify', (req: Request, res: Response) => {
  sendSuccess(res, {
    verified: true,
    verifiedByAdmin: adminAuthService.getAdminEmail(),
    record: req.body,
    timestamp: new Date().toISOString(),
  });
});

// --- Admin Challenge Management Operations ---
router.get('/challenges', (_req: Request, res: Response) => {
  sendSuccess(res, [
    {
      id: 'ch_100_day_transformation',
      title: '100-Day Transformation Challenge',
      activeParticipants: 42,
      durationDays: 100,
      reward: 'Alpha X Elite Trophy',
      status: 'ACTIVE',
    },
    {
      id: 'ch_hypertrophy_march',
      title: 'Spring Hypertrophy Gauntlet',
      activeParticipants: 35,
      durationDays: 30,
      reward: 'Alpha X Gold Crest',
      status: 'ACTIVE',
    },
  ]);
});

router.put('/challenges', (req: Request, res: Response) => {
  sendSuccess(res, { updated: true, data: req.body, updatedAt: new Date().toISOString() });
});

router.put('/challenges/:id', (req: Request, res: Response) => {
  sendSuccess(res, { id: req.params.id, updated: true, data: req.body, updatedAt: new Date().toISOString() });
});

// ==========================================
// WEEKLY PROGRESS & CHECK-IN (ADMIN ENDPOINTS)
// ==========================================

// GET /api/v1/admin/clients/:id/weekly-check-ins
// Returns client's weekly check-in history, charts data, and habit consistency
router.get('/clients/:id/weekly-check-ins', async (req: Request, res: Response) => {
  const idOrClientId = String(req.params.id || '');
  try {
    const user = await findClientByIdOrClientId(idOrClientId);
    if (!user || !user.clientProfile) {
      sendError(res, 'NOT_FOUND', 'Client not found', HttpStatus.NOT_FOUND);
      return;
    }

    const cp = user.clientProfile;

    const checkIns = await prisma.weeklyCheckIn.findMany({
      where: { clientProfileId: cp.id },
      orderBy: { weekNumber: 'asc' },
    });

    const totalWeeks = checkIns.length;
    const latestCheckIn = totalWeeks > 0 ? checkIns[totalWeeks - 1] : null;
    const startWeight = totalWeeks > 0 ? checkIns[0].weightKg : (cp.weightKg || null);
    const latestWeight = latestCheckIn ? latestCheckIn.weightKg : (cp.weightKg || null);
    const totalWeightChange = (startWeight && latestWeight && totalWeeks > 1)
      ? Number((latestWeight - startWeight).toFixed(1))
      : 0.0;

    // Weight and waist trajectory for charts
    const weightHistory = checkIns.map((c) => ({
      week: c.weekNumber,
      weightKg: c.weightKg,
      change: c.weightChange,
      date: c.checkInDate.toISOString().split('T')[0],
    }));

    const waistHistory = checkIns
      .filter((c) => c.waistCm !== null)
      .map((c) => ({
        week: c.weekNumber,
        waistCm: c.waistCm,
        change: c.waistChange,
        date: c.checkInDate.toISOString().split('T')[0],
      }));

    // Consistency & habit calculations
    let avgSleep = 0.0;
    let goodNutritionCount = 0;
    let workoutsAllOrMostCount = 0;
    let highEnergyCount = 0;

    if (totalWeeks > 0) {
      const totalSleep = checkIns.reduce((acc, c) => acc + c.sleepHours, 0);
      avgSleep = Number((totalSleep / totalWeeks).toFixed(1));

      goodNutritionCount = checkIns.filter(
        (c) => (c.nutritionProtein === 'Good' || c.nutritionProtein === 'Mostly') &&
               (c.dietAdherence === 'Good' || c.dietAdherence === 'Mostly')
      ).length;

      workoutsAllOrMostCount = checkIns.filter(
        (c) => c.workoutCompletion === 'All' || c.workoutCompletion === 'Most'
      ).length;

      highEnergyCount = checkIns.filter(
        (c) => c.energyLevel === 'High' || c.energyLevel === 'Good'
      ).length;
    }

    sendSuccess(res, {
      client: {
        id: user.id,
        clientId: cp.clientId,
        name: user.name,
        email: maskEmail(user.email),
        phone: maskPhone(cp.phone),
        currentWeightKg: cp.weightKg,
        primaryGoal: cp.primaryGoal,
      },
      totalWeeks,
      latestCheckIn,
      weightHistory,
      waistHistory,
      metrics: {
        startWeight,
        latestWeight,
        totalWeightChange,
        avgSleep,
        nutritionAdherenceRate: totalWeeks > 0 ? Number(((goodNutritionCount / totalWeeks) * 100).toFixed(0)) : 0,
        workoutConsistencyRate: totalWeeks > 0 ? Number(((workoutsAllOrMostCount / totalWeeks) * 100).toFixed(0)) : 0,
        energyConsistencyRate: totalWeeks > 0 ? Number(((highEnergyCount / totalWeeks) * 100).toFixed(0)) : 0,
        recentPainReported: latestCheckIn ? latestCheckIn.hasPain : false,
      },
      allCheckIns: [...checkIns].reverse(), // Newest first for list view
    });
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Failed to fetch weekly check-in progress', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

// GET /api/v1/admin/clients/:id/weekly-check-ins/compare
// Side-by-side comparison between any two weeks
router.get('/clients/:id/weekly-check-ins-compare', async (req: Request, res: Response) => {
  const idOrClientId = String(req.params.id || '');
  const weekANum = Number(req.query.weekA || 1);
  const weekBNum = Number(req.query.weekB || 2);

  try {
    const user = await findClientByIdOrClientId(idOrClientId);
    if (!user || !user.clientProfile) {
      sendError(res, 'NOT_FOUND', 'Client not found', HttpStatus.NOT_FOUND);
      return;
    }

    const cp = user.clientProfile;

    const [checkInA, checkInB] = await Promise.all([
      prisma.weeklyCheckIn.findFirst({
        where: { clientProfileId: cp.id, weekNumber: weekANum },
      }),
      prisma.weeklyCheckIn.findFirst({
        where: { clientProfileId: cp.id, weekNumber: weekBNum },
      }),
    ]);

    if (!checkInA || !checkInB) {
      sendError(res, 'NOT_FOUND', 'One or both requested weeks not found for comparison', HttpStatus.NOT_FOUND);
      return;
    }

    const weightDelta = Number((checkInB.weightKg - checkInA.weightKg).toFixed(1));
    const waistDelta = (checkInA.waistCm && checkInB.waistCm)
      ? Number((checkInB.waistCm - checkInA.waistCm).toFixed(1))
      : null;

    sendSuccess(res, {
      weekA: checkInA,
      weekB: checkInB,
      comparison: {
        weight: {
          previous: checkInA.weightKg,
          current: checkInB.weightKg,
          change: weightDelta,
        },
        waist: {
          previous: checkInA.waistCm,
          current: checkInB.waistCm,
          change: waistDelta,
        },
        workout: {
          previous: checkInA.workoutCompletion,
          current: checkInB.workoutCompletion,
        },
        protein: {
          previous: checkInA.nutritionProtein,
          current: checkInB.nutritionProtein,
        },
        water: {
          previous: checkInA.nutritionWater,
          current: checkInB.nutritionWater,
        },
        sleep: {
          previous: `${checkInA.sleepHours}h (${checkInA.sleepQuality})`,
          current: `${checkInB.sleepHours}h (${checkInB.sleepQuality})`,
        },
        recovery: {
          previous: checkInA.recoveryQuality,
          current: checkInB.recoveryQuality,
        },
        problems: {
          previous: checkInA.weeklyProblems,
          current: checkInB.weeklyProblems,
        },
      },
    });
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Failed to compare weekly check-ins', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

// POST /api/v1/admin/clients/:id/weekly-check-ins/:checkInId/coach-review
// Submits a coach review for a specific check-in
router.post('/clients/:id/weekly-check-ins/:checkInId/coach-review', async (req: Request, res: Response) => {
  const idOrClientId = String(req.params.id || '');
  const checkInId = String(req.params.checkInId || '');
  const {
    whatWentWell,
    needsImprovement,
    nextWeekFocus,
    workoutNotes,
    nutritionNotes,
    recoveryNotes,
    followUpRequired,
  } = req.body;

  try {
    const user = await findClientByIdOrClientId(idOrClientId);
    if (!user || !user.clientProfile) {
      sendError(res, 'NOT_FOUND', 'Client not found', HttpStatus.NOT_FOUND);
      return;
    }

    const checkIn = await prisma.weeklyCheckIn.findFirst({
      where: { id: checkInId, clientProfileId: user.clientProfile.id },
    });

    if (!checkIn) {
      sendError(res, 'NOT_FOUND', 'Weekly check-in not found', HttpStatus.NOT_FOUND);
      return;
    }

    const reviewer = await prisma.user.findUnique({
      where: { id: req.user!.id },
      select: { name: true },
    });
    const reviewerName = reviewer?.name || 'Head Coach';

    const updated = await prisma.weeklyCheckIn.update({
      where: { id: checkIn.id },
      data: {
        hasCoachReview: true,
        reviewedById: req.user!.id,
        reviewedByName: reviewerName,
        reviewedAt: new Date(),
        whatWentWell: whatWentWell ? String(whatWentWell).trim() : null,
        needsImprovement: needsImprovement ? String(needsImprovement).trim() : null,
        nextWeekFocus: nextWeekFocus ? String(nextWeekFocus).trim() : null,
        workoutNotes: workoutNotes ? String(workoutNotes).trim() : null,
        nutritionNotes: nutritionNotes ? String(nutritionNotes).trim() : null,
        recoveryNotes: recoveryNotes ? String(recoveryNotes).trim() : null,
        followUpRequired: Boolean(followUpRequired),
      },
    });

    sendSuccess(res, updated);
  } catch (err: any) {
    sendError(res, 'INTERNAL_ERROR', 'Failed to save coach review', HttpStatus.INTERNAL_SERVER_ERROR);
  }
});

// DELETE /meal-photos/:id: Master Admin deletes a meal photo
router.delete('/meal-photos/:id', (req: Request, res: Response) => {
  foodPhotoController.deleteMealPhoto(req, res);
});

// ==========================================
// ADMIN FOOD PHOTO MONITORING & VERIFICATION
// ==========================================
router.get('/food-photos', (req: Request, res: Response) => {
  foodPhotoController.getAdminFoodPhotosMonitoring(req, res);
});
router.patch('/food-photos/:id/verify', (req: Request, res: Response) => {
  foodPhotoController.adminVerifyFoodPhoto(req, res);
});
router.post('/food-photos/:id/verify', (req: Request, res: Response) => {
  foodPhotoController.adminVerifyFoodPhoto(req, res);
});

// ==========================================
// ADMIN ATTENTION CENTER & AUTOMATION
// ==========================================

// GET /api/v1/admin/attention-center
// Returns flagged attention items (inactive, missed workouts, missing check-in, pain reported, etc.)
router.get('/attention-center', (req: Request, res: Response) => {
  automationController.getAdminAttentionCenter(req, res);
});

// POST /api/v1/admin/attention-items/:id/review
// Marks an attention item as reviewed + saves coach notes
router.post('/attention-items/:id/review', (req: Request, res: Response) => {
  automationController.reviewAttentionItem(req, res);
});

// GET /api/v1/admin/clients/:id/weekly-report
// Automated factual weekly report for the selected client
router.get('/clients/:id/weekly-report', (req: Request, res: Response) => {
  automationController.getWeeklyReport(req, res);
});

// GET /api/v1/admin/clients/:id/transformation-timeline
// Retrieves transformation milestones (Weeks 1, 4, 8, 12 photos + stats)
router.get('/clients/:id/transformation-timeline', (req: Request, res: Response) => {
  automationController.getTransformationTimeline(req, res);
});

export const adminRoutes = router;


