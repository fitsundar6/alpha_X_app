/**
 * Alpha X AI — Client Data Service
 * Phase 6 — Secure Real Alpha X Client Data Access Layer
 *
 * Implements parameterized, read-only queries with strict data minimization,
 * secret exclusion, date validation, and ambiguity resolution.
 */

import { prisma } from '../../../../../config/prisma';

export interface DateFilterOptions {
  startDate?: string;
  endDate?: string;
  limit?: number;
}

export interface ClientResolutionResult {
  status: 'FOUND' | 'NOT_FOUND' | 'AMBIGUOUS';
  client?: {
    userId: string;
    profileId: string;
    clientId: string | null;
    name: string;
    email: string;
  };
  matches?: Array<{
    userId: string;
    clientId: string | null;
    name: string;
    primaryGoal: string | null;
  }>;
  message?: string;
}

export class ClientDataService {
  /**
   * Resolves a client by identifier (User UUID, ClientProfile AXG-XXXX ID, Profile UUID, email, or name).
   * Detects ambiguity and returns MULTIPLE_CLIENTS_FOUND without picking arbitrarily.
   */
  public async resolveClient(identifier: string): Promise<ClientResolutionResult> {
    if (!identifier || typeof identifier !== 'string' || identifier.trim().length === 0) {
      return { status: 'NOT_FOUND', message: 'Client identifier cannot be empty' };
    }

    const clean = identifier.trim();

    // 1. Direct match on exact ID fields (UUID or AXG-XXXX)
    const exactUser = await prisma.user.findFirst({
      where: {
        role: 'CLIENT',
        OR: [
          { id: clean },
          { email: clean.toLowerCase() },
          { clientProfile: { clientId: clean.toUpperCase() } },
          { clientProfile: { id: clean } },
        ],
      },
      select: {
        id: true,
        name: true,
        email: true,
        clientProfile: {
          select: {
            id: true,
            clientId: true,
            primaryGoal: true,
          },
        },
      },
    });

    if (exactUser && exactUser.clientProfile) {
      return {
        status: 'FOUND',
        client: {
          userId: exactUser.id,
          profileId: exactUser.clientProfile.id,
          clientId: exactUser.clientProfile.clientId,
          name: exactUser.name,
          email: exactUser.email,
        },
      };
    }

    // 2. Name search with potential ambiguity detection
    const nameMatches = await prisma.user.findMany({
      where: {
        role: 'CLIENT',
        name: { contains: clean, mode: 'insensitive' },
      },
      select: {
        id: true,
        name: true,
        clientProfile: {
          select: {
            id: true,
            clientId: true,
            primaryGoal: true,
          },
        },
      },
      take: 10,
    });

    const validMatches = nameMatches.filter((m) => m.clientProfile !== null);

    if (validMatches.length === 0) {
      return {
        status: 'NOT_FOUND',
        message: `No Alpha X client found matching '${clean}'`,
      };
    }

    if (validMatches.length === 1) {
      const match = validMatches[0];
      return {
        status: 'FOUND',
        client: {
          userId: match.id,
          profileId: match.clientProfile!.id,
          clientId: match.clientProfile!.clientId,
          name: match.name,
          email: '', // Minimize PII when resolved via fuzzy name
        },
      };
    }

    // Multiple clients match — DO NOT pick arbitrarily!
    return {
      status: 'AMBIGUOUS',
      matches: validMatches.map((m) => ({
        userId: m.id,
        clientId: m.clientProfile!.clientId,
        name: m.name,
        primaryGoal: m.clientProfile!.primaryGoal,
      })),
      message: `Multiple clients matched '${clean}'. Please specify the exact Client ID (e.g. AXG-XXXX) or full unique name.`,
    };
  }

  /**
   * Searches clients by name, email, or AXG-XXXX ID.
   */
  public async searchClients(query: string, rawLimit: number = 10): Promise<any> {
    if (!query || typeof query !== 'string' || query.trim().length === 0) {
      return {
        source: 'ALPHA_X_DATABASE',
        status: 'INVALID_INPUT',
        error: 'Search query cannot be empty',
      };
    }

    const clean = query.trim();
    const limit = Math.min(Math.max(Number(rawLimit) || 10, 1), 25);

    const users = await prisma.user.findMany({
      where: {
        role: 'CLIENT',
        OR: [
          { name: { contains: clean, mode: 'insensitive' } },
          { email: { contains: clean.toLowerCase() } },
          { clientProfile: { clientId: { contains: clean.toUpperCase() } } },
        ],
      },
      select: {
        id: true,
        name: true,
        createdAt: true,
        clientProfile: {
          select: {
            clientId: true,
            fitnessLevel: true,
            primaryGoal: true,
            weightKg: true,
            membershipStatus: true,
          },
        },
      },
      take: limit,
      orderBy: { name: 'asc' },
    });

    const results = users
      .filter((u) => u.clientProfile !== null)
      .map((u) => ({
        userId: u.id,
        clientId: u.clientProfile!.clientId,
        name: u.name,
        fitnessLevel: u.clientProfile!.fitnessLevel,
        primaryGoal: u.clientProfile!.primaryGoal,
        currentWeightKg: u.clientProfile!.weightKg,
        membershipStatus: u.clientProfile!.membershipStatus,
      }));

    if (results.length === 0) {
      return {
        source: 'ALPHA_X_DATABASE',
        status: 'CLIENT_NOT_FOUND',
        query: clean,
        count: 0,
        results: [],
        message: `No Alpha X clients found matching query '${clean}'`,
      };
    }

    if (results.length > 1) {
      return {
        source: 'ALPHA_X_DATABASE',
        status: 'MULTIPLE_CLIENTS_FOUND',
        query: clean,
        count: results.length,
        results,
        message: `Found ${results.length} clients matching '${clean}'. Please reference the specific Client ID to view full records.`,
      };
    }

    return {
      source: 'ALPHA_X_DATABASE',
      status: 'CLIENT_FOUND',
      query: clean,
      count: 1,
      client: results[0],
    };
  }

  /**
   * Retrieves client profile and assessment data with secrets excluded.
   */
  public async getClientProfile(clientIdOrName: string): Promise<any> {
    const resolution = await this.resolveClient(clientIdOrName);
    if (resolution.status !== 'FOUND' || !resolution.client) {
      return {
        source: 'ALPHA_X_DATABASE',
        status: resolution.status === 'AMBIGUOUS' ? 'MULTIPLE_CLIENTS_FOUND' : 'CLIENT_NOT_FOUND',
        matches: resolution.matches,
        message: resolution.message,
      };
    }

    const user = await prisma.user.findUnique({
      where: { id: resolution.client.userId },
      select: {
        id: true,
        name: true,
        email: true,
        createdAt: true,
        clientProfile: {
          select: {
            clientId: true,
            age: true,
            gender: true,
            heightCm: true,
            weightKg: true,
            fitnessLevel: true,
            primaryGoal: true,
            secondaryGoal: true,
            trainingExperience: true,
            trainingDaysPerWeek: true,
            activityLevel: true,
            sleepHours: true,
            dailyStepGoal: true,
            trainingTimePref: true,
            preferredDays: true,
            hasCurrentInjury: true,
            injuryAreas: true,
            injuryDescription: true,
            hasPreviousSurgery: true,
            surgeryDetails: true,
            membershipStatus: true,
            membershipPlan: true,
            onboardingCompleted: true,
          },
        },
      },
    });

    if (!user || !user.clientProfile) {
      return {
        source: 'ALPHA_X_DATABASE',
        status: 'DATA_NOT_AVAILABLE',
        message: 'Client profile information is not available in Alpha X database',
      };
    }

    const cp = user.clientProfile;

    return {
      source: 'ALPHA_X_DATABASE',
      status: 'SUCCESS',
      profile: {
        userId: user.id,
        clientId: cp.clientId,
        name: user.name,
        age: cp.age,
        gender: cp.gender,
        heightCm: cp.heightCm,
        weightKg: cp.weightKg,
        fitnessLevel: cp.fitnessLevel,
        primaryGoal: cp.primaryGoal,
        secondaryGoal: cp.secondaryGoal,
        trainingExperience: cp.trainingExperience,
        trainingDaysPerWeek: cp.trainingDaysPerWeek,
        activityLevel: cp.activityLevel,
        sleepHours: cp.sleepHours,
        dailyStepGoal: cp.dailyStepGoal,
        trainingTimePreference: cp.trainingTimePref,
        preferredDays: cp.preferredDays,
        hasCurrentInjury: cp.hasCurrentInjury,
        injuryAreas: cp.injuryAreas,
        injuryDescription: cp.injuryDescription,
        hasPreviousSurgery: cp.hasPreviousSurgery,
        surgeryDetails: cp.surgeryDetails,
        membershipStatus: cp.membershipStatus,
        membershipPlan: cp.membershipPlan,
      },
    };
  }

  /**
   * Retrieves weight and body measurement progress history.
   */
  public async getClientWeightHistory(clientIdOrName: string, options: DateFilterOptions = {}): Promise<any> {
    const resolution = await this.resolveClient(clientIdOrName);
    if (resolution.status !== 'FOUND' || !resolution.client) {
      return {
        source: 'ALPHA_X_DATABASE',
        status: resolution.status === 'AMBIGUOUS' ? 'MULTIPLE_CLIENTS_FOUND' : 'CLIENT_NOT_FOUND',
        matches: resolution.matches,
        message: resolution.message,
      };
    }

    const dateFilter = this.validateAndBuildDateFilter(options.startDate, options.endDate);
    if (dateFilter.error) {
      return { source: 'ALPHA_X_DATABASE', status: 'INVALID_INPUT', error: dateFilter.error };
    }

    const limit = Math.min(Math.max(Number(options.limit) || 20, 1), 100);

    const records = await prisma.clientProgress.findMany({
      where: {
        clientProfileId: resolution.client.profileId,
        ...(dateFilter.whereClause ? { date: dateFilter.whereClause } : {}),
      },
      select: {
        id: true,
        date: true,
        weightKg: true,
        waistCm: true,
        notes: true,
      },
      orderBy: { date: 'desc' },
      take: limit,
    });

    if (records.length === 0) {
      return {
        source: 'ALPHA_X_DATABASE',
        status: 'NO_RECORDS_FOUND',
        clientId: resolution.client.clientId || resolution.client.userId,
        name: resolution.client.name,
        recordCount: 0,
        records: [],
        message: 'No recorded weight or progress entries found for this client in the specified period.',
      };
    }

    return {
      source: 'ALPHA_X_DATABASE',
      status: 'SUCCESS',
      clientId: resolution.client.clientId || resolution.client.userId,
      name: resolution.client.name,
      recordCount: records.length,
      records: records.map((r) => ({
        date: r.date.toISOString().split('T')[0],
        weightKg: r.weightKg,
        waistCm: r.waistCm,
        notes: r.notes,
      })),
    };
  }

  /**
   * Retrieves recorded completed workout session records.
   */
  public async getClientWorkoutHistory(clientIdOrName: string, options: DateFilterOptions = {}): Promise<any> {
    const resolution = await this.resolveClient(clientIdOrName);
    if (resolution.status !== 'FOUND' || !resolution.client) {
      return {
        source: 'ALPHA_X_DATABASE',
        status: resolution.status === 'AMBIGUOUS' ? 'MULTIPLE_CLIENTS_FOUND' : 'CLIENT_NOT_FOUND',
        matches: resolution.matches,
        message: resolution.message,
      };
    }

    const dateFilter = this.validateAndBuildDateFilter(options.startDate, options.endDate);
    if (dateFilter.error) {
      return { source: 'ALPHA_X_DATABASE', status: 'INVALID_INPUT', error: dateFilter.error };
    }

    const limit = Math.min(Math.max(Number(options.limit) || 10, 1), 30);

    const workouts = await prisma.workoutRecord.findMany({
      where: {
        clientId: resolution.client.userId,
        ...(dateFilter.whereClause ? { startedAt: dateFilter.whereClause } : {}),
      },
      select: {
        id: true,
        sessionTitle: true,
        workoutType: true,
        startedAt: true,
        completedAt: true,
        durationSeconds: true,
        totalVolume: true,
        completedSetsCount: true,
        averageRpe: true,
        averageRir: true,
        isCompleted: true,
        exerciseRecords: {
          select: {
            exerciseName: true,
            isSkipped: true,
            setRecords: {
              select: {
                setNumber: true,
                actualWeight: true,
                actualReps: true,
                actualRpe: true,
                actualRir: true,
                isCompleted: true,
              },
              orderBy: { setNumber: 'asc' },
            },
          },
          orderBy: { orderIndex: 'asc' },
        },
      },
      orderBy: { startedAt: 'desc' },
      take: limit,
    });

    if (workouts.length === 0) {
      return {
        source: 'ALPHA_X_DATABASE',
        status: 'NO_RECORDS_FOUND',
        clientId: resolution.client.clientId || resolution.client.userId,
        name: resolution.client.name,
        recordCount: 0,
        workouts: [],
        message: 'No completed workout session records found for this client.',
      };
    }

    return {
      source: 'ALPHA_X_DATABASE',
      status: 'SUCCESS',
      clientId: resolution.client.clientId || resolution.client.userId,
      name: resolution.client.name,
      recordCount: workouts.length,
      workouts: workouts.map((w) => ({
        sessionTitle: w.sessionTitle,
        workoutType: w.workoutType,
        date: w.startedAt.toISOString().split('T')[0],
        durationMinutes: Math.round(w.durationSeconds / 60),
        totalVolumeKg: w.totalVolume,
        completedSetsCount: w.completedSetsCount,
        averageRpe: w.averageRpe,
        averageRir: w.averageRir,
        isCompleted: w.isCompleted,
        exercises: w.exerciseRecords.map((e) => ({
          exerciseName: e.exerciseName,
          skipped: e.isSkipped,
          sets: e.setRecords.map((s) => ({
            setNumber: s.setNumber,
            weightKg: s.actualWeight,
            reps: s.actualReps,
            rpe: s.actualRpe,
            rir: s.actualRir,
          })),
        })),
      })),
    };
  }

  /**
   * Retrieves actual client-logged food items (distinct from assigned diet plans).
   */
  public async getClientNutritionLog(clientIdOrName: string, options: DateFilterOptions = {}): Promise<any> {
    const resolution = await this.resolveClient(clientIdOrName);
    if (resolution.status !== 'FOUND' || !resolution.client) {
      return {
        source: 'ALPHA_X_DATABASE',
        status: resolution.status === 'AMBIGUOUS' ? 'MULTIPLE_CLIENTS_FOUND' : 'CLIENT_NOT_FOUND',
        matches: resolution.matches,
        message: resolution.message,
      };
    }

    const dateFilter = this.validateAndBuildDateFilter(options.startDate, options.endDate);
    if (dateFilter.error) {
      return { source: 'ALPHA_X_DATABASE', status: 'INVALID_INPUT', error: dateFilter.error };
    }

    const limit = Math.min(Math.max(Number(options.limit) || 30, 1), 100);

    const logs = await prisma.clientFoodLog.findMany({
      where: {
        clientProfileId: resolution.client.profileId,
        ...(dateFilter.whereClause ? { date: dateFilter.whereClause } : {}),
      },
      select: {
        id: true,
        dateString: true,
        mealType: true,
        foodName: true,
        category: true,
        servingSize: true,
        servingUnit: true,
        quantity: true,
        calories: true,
        protein: true,
        carbohydrates: true,
        fat: true,
        fiber: true,
        loggedAt: true,
      },
      orderBy: { loggedAt: 'desc' },
      take: limit,
    });

    if (logs.length === 0) {
      return {
        source: 'ALPHA_X_DATABASE',
        dataType: 'ACTUAL_CLIENT_FOOD_LOGS',
        status: 'NO_RECORDS_FOUND',
        clientId: resolution.client.clientId || resolution.client.userId,
        name: resolution.client.name,
        recordCount: 0,
        logs: [],
        message: 'No logged food items found for this client in the specified period.',
      };
    }

    return {
      source: 'ALPHA_X_DATABASE',
      dataType: 'ACTUAL_CLIENT_FOOD_LOGS',
      status: 'SUCCESS',
      clientId: resolution.client.clientId || resolution.client.userId,
      name: resolution.client.name,
      recordCount: logs.length,
      logs: logs.map((l) => ({
        date: l.dateString,
        mealType: l.mealType,
        foodName: l.foodName,
        portion: `${l.quantity} × ${l.servingSize}${l.servingUnit}`,
        calories: l.calories,
        proteinGrams: l.protein,
        carbsGrams: l.carbohydrates,
        fatGrams: l.fat,
        fiberGrams: l.fiber,
      })),
    };
  }

  /**
   * Retrieves currently active assigned diet plan (distinct from food logs).
   */
  public async getAssignedDiet(clientIdOrName: string): Promise<any> {
    const resolution = await this.resolveClient(clientIdOrName);
    if (resolution.status !== 'FOUND' || !resolution.client) {
      return {
        source: 'ALPHA_X_DATABASE',
        status: resolution.status === 'AMBIGUOUS' ? 'MULTIPLE_CLIENTS_FOUND' : 'CLIENT_NOT_FOUND',
        matches: resolution.matches,
        message: resolution.message,
      };
    }

    const activeDiet = await prisma.dietPlan.findFirst({
      where: {
        clientProfileId: resolution.client.profileId,
        isActive: true,
      },
      select: {
        id: true,
        planName: true,
        version: true,
        dailyCalories: true,
        protein: true,
        carbohydrates: true,
        fat: true,
        fiber: true,
        waterTargetLiters: true,
        mealsJson: true,
        notes: true,
        startDate: true,
        endDate: true,
        updatedAt: true,
      },
      orderBy: { updatedAt: 'desc' },
    });

    if (!activeDiet) {
      return {
        source: 'ALPHA_X_DATABASE',
        dataType: 'ADMIN_ASSIGNED_PLAN',
        status: 'DATA_NOT_AVAILABLE',
        clientId: resolution.client.clientId || resolution.client.userId,
        name: resolution.client.name,
        message: 'No active assigned diet plan found for this client.',
      };
    }

    let parsedMeals: any = null;
    if (activeDiet.mealsJson) {
      try {
        parsedMeals = JSON.parse(activeDiet.mealsJson);
      } catch {
        parsedMeals = activeDiet.mealsJson;
      }
    }

    return {
      source: 'ALPHA_X_DATABASE',
      dataType: 'ADMIN_ASSIGNED_PLAN',
      status: 'SUCCESS',
      clientId: resolution.client.clientId || resolution.client.userId,
      name: resolution.client.name,
      plan: {
        planName: activeDiet.planName,
        dailyCalories: activeDiet.dailyCalories,
        proteinGrams: activeDiet.protein,
        carbsGrams: activeDiet.carbohydrates,
        fatGrams: activeDiet.fat,
        fiberGrams: activeDiet.fiber,
        waterTargetLiters: activeDiet.waterTargetLiters,
        notes: activeDiet.notes,
        startDate: activeDiet.startDate?.toISOString().split('T')[0],
        endDate: activeDiet.endDate?.toISOString().split('T')[0],
        meals: parsedMeals,
      },
    };
  }

  /**
   * Retrieves recorded weekly check-in entries.
   */
  public async getClientCheckIns(clientIdOrName: string, rawLimit: number = 10): Promise<any> {
    const resolution = await this.resolveClient(clientIdOrName);
    if (resolution.status !== 'FOUND' || !resolution.client) {
      return {
        source: 'ALPHA_X_DATABASE',
        status: resolution.status === 'AMBIGUOUS' ? 'MULTIPLE_CLIENTS_FOUND' : 'CLIENT_NOT_FOUND',
        matches: resolution.matches,
        message: resolution.message,
      };
    }

    const limit = Math.min(Math.max(Number(rawLimit) || 10, 1), 20);

    const checkIns = await prisma.weeklyCheckIn.findMany({
      where: { clientProfileId: resolution.client.profileId },
      select: {
        id: true,
        weekNumber: true,
        year: true,
        checkInDate: true,
        weightKg: true,
        weightChange: true,
        waistCm: true,
        waistChange: true,
        chestCm: true,
        nutritionCalories: true,
        nutritionProtein: true,
        dietAdherence: true,
        sleepQuality: true,
        sleepHours: true,
        recoveryQuality: true,
        workoutCompletion: true,
        energyLevel: true,
        hasPain: true,
        painLocation: true,
        painLevel: true,
        painDescription: true,
        clientNotes: true,
      },
      orderBy: { checkInDate: 'desc' },
      take: limit,
    });

    if (checkIns.length === 0) {
      return {
        source: 'ALPHA_X_DATABASE',
        status: 'NO_RECORDS_FOUND',
        clientId: resolution.client.clientId || resolution.client.userId,
        name: resolution.client.name,
        recordCount: 0,
        checkIns: [],
        message: 'No weekly check-ins recorded for this client.',
      };
    }

    return {
      source: 'ALPHA_X_DATABASE',
      status: 'SUCCESS',
      clientId: resolution.client.clientId || resolution.client.userId,
      name: resolution.client.name,
      recordCount: checkIns.length,
      checkIns: checkIns.map((c) => ({
        week: `Week ${c.weekNumber} (${c.year})`,
        date: c.checkInDate.toISOString().split('T')[0],
        weightKg: c.weightKg,
        weightChangeKg: c.weightChange,
        waistCm: c.waistCm,
        nutritionCaloriesStatus: c.nutritionCalories,
        nutritionProteinStatus: c.nutritionProtein,
        dietAdherence: c.dietAdherence,
        sleepHours: c.sleepHours,
        sleepQuality: c.sleepQuality,
        recoveryQuality: c.recoveryQuality,
        workoutCompletion: c.workoutCompletion,
        energyLevel: c.energyLevel,
        hasPainOrInjury: c.hasPain,
        painDetails: c.hasPain ? `${c.painLocation || 'General'} (Level ${c.painLevel}/10): ${c.painDescription || ''}` : null,
        clientNotes: c.clientNotes,
      })),
    };
  }

  /**
   * Retrieves daily step and cardio activity records.
   */
  public async getClientStepsHistory(clientIdOrName: string, options: DateFilterOptions = {}): Promise<any> {
    const resolution = await this.resolveClient(clientIdOrName);
    if (resolution.status !== 'FOUND' || !resolution.client) {
      return {
        source: 'ALPHA_X_DATABASE',
        status: resolution.status === 'AMBIGUOUS' ? 'MULTIPLE_CLIENTS_FOUND' : 'CLIENT_NOT_FOUND',
        matches: resolution.matches,
        message: resolution.message,
      };
    }

    const dateFilter = this.validateAndBuildDateFilter(options.startDate, options.endDate);
    if (dateFilter.error) {
      return { source: 'ALPHA_X_DATABASE', status: 'INVALID_INPUT', error: dateFilter.error };
    }

    const limit = Math.min(Math.max(Number(options.limit) || 14, 1), 60);

    const activities = await prisma.activityRecord.findMany({
      where: {
        clientId: resolution.client.profileId,
        ...(dateFilter.whereClause ? { date: dateFilter.whereClause } : {}),
      },
      select: {
        date: true,
        steps: true,
        stepGoal: true,
        cardioMinutes: true,
        caloriesBurned: true,
        distanceMeters: true,
        isGoalAchieved: true,
      },
      orderBy: { date: 'desc' },
      take: limit,
    });

    if (activities.length === 0) {
      return {
        source: 'ALPHA_X_DATABASE',
        status: 'NO_RECORDS_FOUND',
        clientId: resolution.client.clientId || resolution.client.userId,
        name: resolution.client.name,
        recordCount: 0,
        activityRecords: [],
        message: 'No activity or step records found for this client in the specified period.',
      };
    }

    return {
      source: 'ALPHA_X_DATABASE',
      status: 'SUCCESS',
      clientId: resolution.client.clientId || resolution.client.userId,
      name: resolution.client.name,
      recordCount: activities.length,
      activityRecords: activities.map((a) => ({
        date: a.date.toISOString().split('T')[0],
        steps: a.steps,
        stepGoal: a.stepGoal,
        goalAchieved: a.isGoalAchieved,
        cardioMinutes: a.cardioMinutes,
        caloriesBurned: a.caloriesBurned,
        distanceKm: Number((a.distanceMeters / 1000).toFixed(2)),
      })),
    };
  }

  /**
   * Retrieves assigned active workout plan and exercise prescription.
   */
  public async getAssignedWorkout(clientIdOrName: string): Promise<any> {
    const resolution = await this.resolveClient(clientIdOrName);
    if (resolution.status !== 'FOUND' || !resolution.client) {
      return {
        source: 'ALPHA_X_DATABASE',
        status: resolution.status === 'AMBIGUOUS' ? 'MULTIPLE_CLIENTS_FOUND' : 'CLIENT_NOT_FOUND',
        matches: resolution.matches,
        message: resolution.message,
      };
    }

    // Check direct assignment or global assignment
    const assignment = await prisma.workoutAssignment.findFirst({
      where: {
        active: true,
        OR: [{ clientId: resolution.client.userId }, { clientId: null }],
      },
      include: {
        session: {
          include: {
            exercises: {
              orderBy: { orderIndex: 'asc' },
            },
          },
        },
      },
      orderBy: { assignedAt: 'desc' },
    });

    if (!assignment || !assignment.session) {
      return {
        source: 'ALPHA_X_DATABASE',
        dataType: 'ADMIN_ASSIGNED_PLAN',
        status: 'DATA_NOT_AVAILABLE',
        clientId: resolution.client.clientId || resolution.client.userId,
        name: resolution.client.name,
        message: 'No active assigned workout plan found for this client.',
      };
    }

    const s = assignment.session;

    return {
      source: 'ALPHA_X_DATABASE',
      dataType: 'ADMIN_ASSIGNED_PLAN',
      status: 'SUCCESS',
      clientId: resolution.client.clientId || resolution.client.userId,
      name: resolution.client.name,
      assignedPlan: {
        sessionTitle: s.title,
        workoutType: s.workoutType,
        targetMuscleGroup: s.targetMuscleGroup,
        difficulty: s.difficulty,
        estimatedDurationMinutes: s.estimatedDurationMinutes,
        description: s.description,
        assignedAt: assignment.assignedAt.toISOString().split('T')[0],
        exercises: s.exercises.map((e) => ({
          exerciseName: e.exerciseName,
          category: e.category,
          sets: e.numberOfSets,
          targetReps: e.targetReps,
          targetWeightKg: e.targetWeight,
          targetRir: e.targetRir,
          targetRpe: e.targetRpe,
          restSeconds: e.restSeconds,
          tempo: e.tempo,
        })),
      },
    };
  }

  /**
   * Helper that validates date strings (YYYY-MM-DD), ensures chronological ordering,
   * and prevents unreasonable historical queries (>365 days).
   */
  private validateAndBuildDateFilter(
    startDateStr?: string,
    endDateStr?: string
  ): { whereClause?: { gte?: Date; lte?: Date }; error?: string } {
    if (!startDateStr && !endDateStr) {
      return {};
    }

    const dateRegex = /^\d{4}-\d{2}-\d{2}$/;

    let start: Date | undefined;
    let end: Date | undefined;

    if (startDateStr) {
      if (!dateRegex.test(startDateStr) || isNaN(Date.parse(startDateStr))) {
        return { error: `Invalid startDate '${startDateStr}'. Format must be YYYY-MM-DD` };
      }
      start = new Date(`${startDateStr}T00:00:00.000Z`);
    }

    if (endDateStr) {
      if (!dateRegex.test(endDateStr) || isNaN(Date.parse(endDateStr))) {
        return { error: `Invalid endDate '${endDateStr}'. Format must be YYYY-MM-DD` };
      }
      end = new Date(`${endDateStr}T23:59:59.999Z`);
    }

    if (start && end) {
      if (start > end) {
        return { error: `startDate (${startDateStr}) cannot be after endDate (${endDateStr})` };
      }

      const diffDays = Math.ceil((end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24));
      if (diffDays > 365) {
        return { error: `Requested date range (${diffDays} days) exceeds maximum allowable span of 365 days` };
      }
    }

    const where: { gte?: Date; lte?: Date } = {};
    if (start) where.gte = start;
    if (end) where.lte = end;

    return { whereClause: where };
  }
}

export const clientDataService = new ClientDataService();
