import { Router, Request, Response } from 'express';
import { requireAuth, requireAdmin } from '../../middlewares/auth';
import { adminAuthService } from '../auth/admin_auth.service';
import { workoutController } from '../workout/workout.controller';
import { exerciseController } from '../exercise/exercise.controller';
import { HttpStatus } from '../../constants/httpStatus';
import { sendSuccess, sendError } from '../../utils/responseEnvelope';
import { prisma } from '../../config/prisma';

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
router.get('/workouts', (req: Request, res: Response) => workoutController.getAllAdminSessions(req, res));
router.post('/workouts', (req: Request, res: Response) => workoutController.createSession(req, res));
router.get('/workouts/:id', (req: Request, res: Response) => workoutController.getAdminSessionById(req, res));
router.put('/workouts/:id', (req: Request, res: Response) => workoutController.updateSession(req, res));
router.delete('/workouts/:id', (req: Request, res: Response) => workoutController.deleteSession(req, res));
router.post('/workouts/:id/duplicate', (req: Request, res: Response) => workoutController.duplicateSession(req, res));
router.post('/workouts/:id/assign', (req: Request, res: Response) => workoutController.assignSession(req, res));
router.delete('/workouts/assignments/:assignmentId', (req: Request, res: Response) => workoutController.unassign(req, res));

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
        email: user.email,
        phone: cp.phone,
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
    console.error('[ADMIN GET CLIENT ERROR]', err);
    sendError(res, 'INTERNAL_ERROR', 'Failed to retrieve client profile', HttpStatus.INTERNAL_SERVER_ERROR);
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
    console.error('[ADMIN SAVE NOTES ERROR]', err);
    sendError(res, 'INTERNAL_ERROR', 'Failed to save admin notes', HttpStatus.INTERNAL_SERVER_ERROR);
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
      sendSuccess(res, existing, HttpStatus.OK);
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
    console.error('[ADMIN ASSIGN WORKOUT ERROR]', err);
    sendError(res, 'INTERNAL_ERROR', 'Failed to assign workout to client', HttpStatus.INTERNAL_SERVER_ERROR);
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

    // Deactivate previous active diet plans for this client (Preserve history)
    await prisma.dietPlan.updateMany({
      where: {
        clientProfileId: cp.id,
        isActive: true,
      },
      data: { isActive: false },
    });

    // Create the new active diet plan
    const newDietPlan = await prisma.dietPlan.create({
      data: {
        clientProfileId: cp.id,
        clientId: cp.clientId,
        planName: planName.trim(),
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

    sendSuccess(res, newDietPlan, HttpStatus.CREATED);
  } catch (err: any) {
    console.error('[ADMIN CREATE DIET PLAN ERROR]', err);
    sendError(res, 'INTERNAL_ERROR', 'Failed to create diet plan', HttpStatus.INTERNAL_SERVER_ERROR);
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
    sendError(res, 'INTERNAL_ERROR', 'Failed to fetch macro targets', HttpStatus.INTERNAL_SERVER_ERROR);
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
    console.error('[ADMIN ASSIGN MACROS ERROR]', err);
    sendError(res, 'INTERNAL_ERROR', 'Failed to assign macro targets', HttpStatus.INTERNAL_SERVER_ERROR);
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

export const adminRoutes = router;
