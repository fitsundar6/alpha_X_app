import { prisma } from '../../config/prisma';

export interface DataCompletenessReport {
  scorePercentage: number;
  missingItems: string[];
  summary: string;
}

export interface ClientContextSummary {
  user: {
    id: string;
    name: string;
    email: string;
    createdAt: Date;
  };
  profile: {
    id: string;
    clientId: string | null;
    primaryGoal: string | null;
    fitnessLevel: string | null;
    weightKg: number | null;
    heightCm: number | null;
    age: number | null;
    gender: string | null;
    trainingExperience: string | null;
    trainingDaysPerWeek: number | null;
    hasCurrentInjury: boolean;
    injuryAreas: string[];
    injuryDescription: string | null;
    sleepHours: string | null;
    adminNotes: string | null;
  };
  activeWorkoutSession: any | null;
  recentWorkoutHistory: any[];
  activeDietPlan: any | null;
  dietHistory: any[];
  recentFoodLogs: any[];
  mealPhotos: any[];
  weeklyCheckIns: any[];
  latestCheckIn: any | null;
  progressRecords: any[];
  activityRecords: any[];
  attentionItems: any[];
  completeness: DataCompletenessReport;
}

export class AiTools {
  /**
   * Retrieves all clients authorized for Admin management.
   */
  async getAuthorizedClients() {
    return prisma.user.findMany({
      where: { role: 'CLIENT' },
      select: {
        id: true,
        name: true,
        email: true,
        createdAt: true,
        clientProfile: {
          select: {
            id: true,
            clientId: true,
            primaryGoal: true,
            fitnessLevel: true,
            weightKg: true,
            heightCm: true,
            age: true,
            hasCurrentInjury: true,
            injuryAreas: true,
            adminNotes: true,
          },
        },
      },
      orderBy: { name: 'asc' },
    });
  }

  /**
   * Resolves client by name, ID, or clientId (AXG-XXXX).
   */
  async findClient(identifier: string) {
    const clean = identifier.trim();
    return prisma.user.findFirst({
      where: {
        role: 'CLIENT',
        OR: [
          { id: clean },
          { name: { contains: clean, mode: 'insensitive' } },
          { clientProfile: { clientId: { equals: clean.toUpperCase() } } },
          { clientProfile: { id: clean } },
          { email: { equals: clean.toLowerCase() } },
        ],
      },
      include: {
        clientProfile: true,
      },
    });
  }

  /**
   * Retrieves comprehensive context for a specific client.
   */
  async getClientContext(identifier: string, dateRange?: { start?: Date; end?: Date }): Promise<ClientContextSummary | null> {
    const client = await this.findClient(identifier);
    if (!client || !client.clientProfile) return null;

    const cp = client.clientProfile;
    const now = new Date();
    const defaultStart = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000); // 30 days ago
    const startDate = dateRange?.start || defaultStart;
    const endDate = dateRange?.end || now;

    // 1. Active Workout Assignment & Session
    const assignment = await prisma.workoutAssignment.findFirst({
      where: {
        clientId: client.id,
        active: true,
      },
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

    // 2. Workout History with sets
    const recentWorkoutHistory = await prisma.workoutRecord.findMany({
      where: {
        clientId: client.id,
        createdAt: { gte: startDate, lte: endDate },
      },
      include: {
        exerciseRecords: {
          include: {
            setRecords: { orderBy: { setNumber: 'asc' } },
          },
        },
      },
      orderBy: { startedAt: 'desc' },
      take: 20,
    });

    // 3. Active Diet Plan & History
    const [activeDietPlan, dietHistory] = await Promise.all([
      prisma.dietPlan.findFirst({
        where: { clientProfileId: cp.id, isActive: true },
        orderBy: { createdAt: 'desc' },
      }),
      prisma.dietPlanHistory.findMany({
        where: { clientProfileId: cp.id },
        orderBy: { createdAt: 'desc' },
        take: 10,
      }),
    ]);

    // 4. Actual Food Logs
    const recentFoodLogs = await prisma.clientFoodLog.findMany({
      where: {
        clientProfileId: cp.id,
        createdAt: { gte: startDate, lte: endDate },
      },
      include: { mealPhoto: true },
      orderBy: { loggedAt: 'desc' },
      take: 100,
    });

    // 5. Meal Photos
    const mealPhotos = await prisma.mealPhoto.findMany({
      where: {
        clientProfileId: cp.id,
        capturedAt: { gte: startDate, lte: endDate },
        isDeleted: false,
      },
      orderBy: { capturedAt: 'desc' },
      take: 20,
    });

    // 6. Weekly Check-Ins
    const weeklyCheckIns = await prisma.weeklyCheckIn.findMany({
      where: { clientProfileId: cp.id },
      orderBy: { weekNumber: 'desc' },
      take: 12,
    });

    // 7. Weight & Waist Progress
    const progressRecords = await prisma.clientProgress.findMany({
      where: {
        clientProfileId: cp.id,
        date: { gte: startDate, lte: endDate },
      },
      orderBy: { date: 'desc' },
      take: 30,
    });

    // 8. Steps & Activity
    const activityRecords = await prisma.activityRecord.findMany({
      where: {
        clientId: cp.id,
        date: { gte: startDate, lte: endDate },
      },
      orderBy: { date: 'desc' },
      take: 30,
    });

    // 9. Attention items
    const attentionItems = await prisma.adminAttentionItem.findMany({
      where: {
        clientProfileId: cp.id,
      },
      orderBy: { createdAt: 'desc' },
      take: 10,
    });

    // 11. Calculate Data Completeness
    const missing: string[] = [];
    let checks = 0;
    let passed = 0;

    // Check: Weekly check-in within last 14 days
    checks++;
    const hasRecentCheckIn = weeklyCheckIns.length > 0 &&
      (now.getTime() - new Date(weeklyCheckIns[0].checkInDate).getTime()) < 14 * 24 * 60 * 60 * 1000;
    if (hasRecentCheckIn) {
      passed++;
    } else {
      missing.push('Weekly check-in missing in past 14 days');
    }

    // Check: Food logs recorded in last 7 days
    checks++;
    const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    const hasRecentFoodLogs = recentFoodLogs.some(log => new Date(log.loggedAt) >= sevenDaysAgo);
    if (hasRecentFoodLogs) {
      passed++;
    } else {
      missing.push('No food logs recorded in last 7 days');
    }

    // Check: Weight progress record recorded in last 30 days
    checks++;
    const hasRecentWeight = progressRecords.length > 0 || cp.weightKg !== null;
    if (hasRecentWeight) {
      passed++;
    } else {
      missing.push('No bodyweight recorded in last 30 days');
    }

    // Check: Active workout plan assigned
    checks++;
    if (assignment) {
      passed++;
    } else {
      missing.push('No active workout session currently assigned');
    }

    // Check: Active diet plan assigned
    checks++;
    if (activeDietPlan) {
      passed++;
    } else {
      missing.push('No active diet plan currently assigned');
    }

    // Check: Steps activity recorded in last 7 days
    checks++;
    const hasRecentSteps = activityRecords.some(r => new Date(r.date) >= sevenDaysAgo && r.steps > 0);
    if (hasRecentSteps) {
      passed++;
    } else {
      missing.push('Step activity not recorded for the past week');
    }

    const scorePercentage = Math.round((passed / checks) * 100);

    return {
      user: {
        id: client.id,
        name: client.name,
        email: client.email,
        createdAt: client.createdAt,
      },
      profile: {
        id: cp.id,
        clientId: cp.clientId,
        primaryGoal: cp.primaryGoal,
        fitnessLevel: cp.fitnessLevel,
        weightKg: cp.weightKg,
        heightCm: cp.heightCm,
        age: cp.age,
        gender: cp.gender,
        trainingExperience: cp.trainingExperience,
        trainingDaysPerWeek: cp.trainingDaysPerWeek,
        hasCurrentInjury: cp.hasCurrentInjury,
        injuryAreas: cp.injuryAreas,
        injuryDescription: cp.injuryDescription,
        sleepHours: cp.sleepHours,
        adminNotes: cp.adminNotes,
      },
      activeWorkoutSession: assignment?.session || null,
      recentWorkoutHistory,
      activeDietPlan,
      dietHistory,
      recentFoodLogs,
      mealPhotos,
      weeklyCheckIns,
      latestCheckIn: weeklyCheckIns.length > 0 ? weeklyCheckIns[0] : null,
      progressRecords,
      activityRecords,
      attentionItems,
      completeness: {
        scorePercentage,
        missingItems: missing,
        summary: `Data Completeness: ${scorePercentage}% (${missing.length > 0 ? 'Missing: ' + missing.join('; ') : 'Complete profile tracking'})`,
      },
    };
  }

  /**
   * Evaluates historical performance for a given exercise and proposes progressive overload.
   */
  async calculateProgressiveOverload(clientId: string, exerciseNameOrId: string) {
    const client = await this.findClient(clientId);
    if (!client) throw new Error(`Client not found: ${clientId}`);

    const cleanExercise = exerciseNameOrId.trim();

    // Query recent workout records for this exercise
    const records = await prisma.workoutRecord.findMany({
      where: {
        clientId: client.id,
        isCompleted: true,
        exerciseRecords: {
          some: {
            exerciseName: { contains: cleanExercise, mode: 'insensitive' },
          },
        },
      },
      include: {
        exerciseRecords: {
          where: {
            exerciseName: { contains: cleanExercise, mode: 'insensitive' },
          },
          include: {
            setRecords: {
              where: { isCompleted: true },
              orderBy: { setNumber: 'asc' },
            },
          },
        },
      },
      orderBy: { startedAt: 'desc' },
      take: 4,
    });

    if (records.length === 0) {
      return {
        exercise: cleanExercise,
        hasHistory: false,
        message: `No completed historical workout records found for "${cleanExercise}". Proposing initial baseline standard sets.`,
        current: null,
        previous: null,
        proposal: {
          exerciseName: cleanExercise,
          sets: 3,
          targetReps: '8-10',
          targetWeight: 50.0,
          targetRir: 2,
          targetRpe: 8.0,
          reason: 'Initial baseline Prescribed based on client fitness level without prior recorded sets.',
        },
      };
    }

    // Extract latest and previous session sets
    const latestRecord = records[0];
    const previousRecord = records.length > 1 ? records[1] : null;

    const latestSets = latestRecord.exerciseRecords[0]?.setRecords || [];
    const previousSets = previousRecord?.exerciseRecords[0]?.setRecords || [];

    const latestWorkingSet = latestSets.filter(s => s.setType === 'WORKING')[0] || latestSets[0];
    const previousWorkingSet = previousSets.filter(s => s.setType === 'WORKING')[0] || previousSets[0];

    const currentWeight = latestWorkingSet?.actualWeight ?? latestWorkingSet?.targetWeight ?? 60.0;
    const currentReps = latestWorkingSet?.actualReps ?? 8;
    const currentRpe = latestWorkingSet?.actualRpe ?? 8.0;
    const currentRir = latestWorkingSet?.actualRir ?? 2;

    const prevWeight = previousWorkingSet?.actualWeight ?? currentWeight;
    const prevReps = previousWorkingSet?.actualReps ?? currentReps;

    // Progressive Overload Rule Engine:
    // If client completed all target reps with RPE <= 8 or RIR >= 2 -> increment weight (+2.5kg for upper, +5kg for lower)
    // If client performed same weight with higher reps (e.g. 8 reps -> 10 reps) -> ready for weight bump.
    // If RPE was high (>= 9.5) or reps dropped -> propose consolidation (+1 rep at same weight or maintain).
    let proposedWeight = currentWeight;
    let proposedReps = currentReps;
    let reason = '';

    const isLowerBody = /squat|deadlift|leg press|lunge|hip thrust/i.test(cleanExercise);
    const weightIncrement = isLowerBody ? 5.0 : 2.5;

    if (currentRpe <= 8.0 && currentRir >= 2) {
      if (currentReps >= 10) {
        proposedWeight = currentWeight + weightIncrement;
        proposedReps = 8;
        reason = `Client completed ${currentWeight} kg × ${currentReps} reps with solid RPE ${currentRpe} (RIR ${currentRir}). Proposing weight increase to ${proposedWeight} kg × ${proposedReps} reps.`;
      } else {
        proposedWeight = currentWeight;
        proposedReps = currentReps + 1;
        reason = `Client recorded ${currentWeight} kg × ${currentReps} reps with RPE ${currentRpe}. Proposing rep progression to ${proposedReps} reps at ${proposedWeight} kg before increasing load.`;
      }
    } else if (currentRpe >= 9.0) {
      proposedWeight = currentWeight;
      proposedReps = currentReps;
      reason = `Client recorded high effort (RPE ${currentRpe}) on ${currentWeight} kg × ${currentReps} reps. Proposing load consolidation at ${currentWeight} kg to build technical mastery.`;
    } else {
      proposedWeight = currentWeight + (currentReps >= 8 ? weightIncrement : 0);
      proposedReps = currentReps >= 8 ? 8 : currentReps + 1;
      reason = `Based on performance trajectory across previous sessions (${prevWeight} kg × ${prevReps} → ${currentWeight} kg × ${currentReps}), proposing steady progression.`;
    }

    return {
      exercise: cleanExercise,
      hasHistory: true,
      current: {
        weight: currentWeight,
        reps: currentReps,
        rpe: currentRpe,
        rir: currentRir,
        date: latestRecord.startedAt,
      },
      previous: previousWorkingSet ? {
        weight: prevWeight,
        reps: prevReps,
        date: previousRecord?.startedAt,
      } : null,
      proposal: {
        exerciseName: cleanExercise,
        sets: latestSets.length > 0 ? latestSets.length : 3,
        targetWeight: proposedWeight,
        targetReps: `${proposedReps}`,
        targetRir: 2,
        targetRpe: 8.0,
        reason,
      },
    };
  }

  /**
   * Queries existing Food database.
   */
  async queryFoodLibrary(query?: string, category?: string, limit: number = 20) {
    const where: any = { status: { in: ['PUBLISHED', 'APPROVED'] } };
    if (query && query.trim().length > 0) {
      where.OR = [
        { name: { contains: query.trim(), mode: 'insensitive' } },
        { normalizedName: { contains: query.trim().toLowerCase() } },
        { category: { contains: query.trim(), mode: 'insensitive' } },
      ];
    }
    if (category && category !== 'ALL') {
      where.category = { contains: category, mode: 'insensitive' };
    }

    return prisma.food.findMany({
      where,
      take: limit,
      orderBy: { name: 'asc' },
    });
  }

  /**
   * Queries existing Exercise catalog.
   */
  async queryExerciseLibrary(query?: string, bodyPart?: string, limit: number = 20) {
    const where: any = { isActive: true };
    if (query && query.trim().length > 0) {
      where.OR = [
        { name: { contains: query.trim(), mode: 'insensitive' } },
        { primaryMuscles: { hasSome: [query.trim()] } },
      ];
    }
    if (bodyPart && bodyPart !== 'ALL') {
      where.bodyPart = { equals: bodyPart, mode: 'insensitive' };
    }

    return prisma.exercise.findMany({
      where,
      take: limit,
      orderBy: { name: 'asc' },
    });
  }

  /**
   * Generates facility-wide daily summary for Today's Report.
   */
  async getDailyGymSummary(targetDateStr?: string) {
    const todayStr = targetDateStr || new Date().toISOString().split('T')[0];
    const targetDate = new Date(todayStr);

    const [
      totalClients,
      todayFoodLogs,
      todayWorkouts,
      pendingAttention,
      recentCheckIns,
    ] = await Promise.all([
      prisma.user.count({ where: { role: 'CLIENT' } }),
      prisma.clientFoodLog.count({
        where: { dateString: todayStr },
      }),
      prisma.workoutRecord.count({
        where: {
          isCompleted: true,
          startedAt: {
            gte: new Date(`${todayStr}T00:00:00.000Z`),
            lte: new Date(`${todayStr}T23:59:59.999Z`),
          },
        },
      }),
      prisma.adminAttentionItem.findMany({
        where: { isReviewed: false },
        orderBy: { severity: 'desc' },
        take: 10,
      }),
      prisma.weeklyCheckIn.count({
        where: {
          checkInDate: {
            gte: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000),
          },
        },
      }),
    ]);

    // Distinct clients tracking food today
    const distinctFoodClients = await prisma.clientFoodLog.groupBy({
      by: ['clientProfileId'],
      where: { dateString: todayStr },
    });

    const pendingCheckInsCount = Math.max(0, totalClients - recentCheckIns);

    return {
      date: todayStr,
      totalActiveClients: totalClients,
      workoutsCompletedToday: todayWorkouts,
      foodLogsRecordedToday: todayFoodLogs,
      clientsTrackingFoodToday: distinctFoodClients.length,
      weeklyCheckInsPending: pendingCheckInsCount,
      weeklyCheckInsCompletedThisWeek: recentCheckIns,
      clientsNeedingReviewCount: pendingAttention.length,
      attentionItems: pendingAttention.map(a => ({
        id: a.id,
        clientName: a.clientName,
        clientId: a.clientId,
        attentionType: a.attentionType,
        severity: a.severity,
        title: a.title,
        details: a.details,
      })),
    };
  }

  /**
   * Generates facility weekly report (last 7 days).
   */
  async getWeeklyGymSummary(startDateStr?: string, endDateStr?: string) {
    const end = endDateStr ? new Date(endDateStr) : new Date();
    const start = startDateStr ? new Date(startDateStr) : new Date(end.getTime() - 7 * 24 * 60 * 60 * 1000);

    const [
      totalClients,
      weeklyWorkouts,
      weeklyFoodLogs,
      weeklyCheckIns,
      unreviewedAttention,
    ] = await Promise.all([
      prisma.user.findMany({
        where: { role: 'CLIENT' },
        include: { clientProfile: true },
      }),
      prisma.workoutRecord.findMany({
        where: {
          isCompleted: true,
          startedAt: { gte: start, lte: end },
        },
        select: { clientId: true, totalVolume: true },
      }),
      prisma.clientFoodLog.count({
        where: {
          loggedAt: { gte: start, lte: end },
        },
      }),
      prisma.weeklyCheckIn.findMany({
        where: {
          checkInDate: { gte: start, lte: end },
        },
      }),
      prisma.adminAttentionItem.findMany({
        where: { isReviewed: false },
        take: 10,
      }),
    ]);

    const activeClientsCount = totalClients.length;
    const workoutAdherenceRate = activeClientsCount > 0
      ? Math.min(100, Math.round((weeklyWorkouts.length / (activeClientsCount * 3)) * 100))
      : 0;

    const checkInCompletionRate = activeClientsCount > 0
      ? Math.min(100, Math.round((weeklyCheckIns.length / activeClientsCount) * 100))
      : 0;

    return {
      period: {
        start: start.toISOString().split('T')[0],
        end: end.toISOString().split('T')[0],
      },
      totalActiveClients: activeClientsCount,
      workoutsCompleted: weeklyWorkouts.length,
      workoutAdherenceRate,
      totalFoodLogs: weeklyFoodLogs,
      checkInsCompleted: weeklyCheckIns.length,
      checkInCompletionRate,
      attentionItemsCount: unreviewedAttention.length,
      attentionItems: unreviewedAttention,
    };
  }

  /**
   * Generates facility monthly report (last 30 days).
   */
  async getMonthlyGymSummary(startDateStr?: string, endDateStr?: string) {
    const end = endDateStr ? new Date(endDateStr) : new Date();
    const start = startDateStr ? new Date(startDateStr) : new Date(end.getTime() - 30 * 24 * 60 * 60 * 1000);

    const [
      totalClients,
      monthlyWorkouts,
      monthlyFoodLogs,
      monthlyCheckIns,
    ] = await Promise.all([
      prisma.user.count({ where: { role: 'CLIENT' } }),
      prisma.workoutRecord.count({
        where: {
          isCompleted: true,
          startedAt: { gte: start, lte: end },
        },
      }),
      prisma.clientFoodLog.count({
        where: {
          loggedAt: { gte: start, lte: end },
        },
      }),
      prisma.weeklyCheckIn.count({
        where: {
          checkInDate: { gte: start, lte: end },
        },
      }),
    ]);

    return {
      period: {
        start: start.toISOString().split('T')[0],
        end: end.toISOString().split('T')[0],
      },
      totalActiveClients: totalClients,
      monthlyWorkoutsCompleted: monthlyWorkouts,
      monthlyFoodLogs: monthlyFoodLogs,
      monthlyCheckIns: monthlyCheckIns,
      avgWorkoutsPerClient: totalClients > 0 ? Number((monthlyWorkouts / totalClients).toFixed(1)) : 0,
    };
  }

  /**
   * Creates an AI proposal in the database (Status: PENDING).
   */
  async createProposal(data: {
    conversationId?: string;
    clientProfileId: string;
    clientId?: string;
    clientName: string;
    proposalType: 'WORKOUT' | 'DIET' | 'PROGRESSION';
    title: string;
    summary: string;
    reason: string;
    currentDataJson?: string;
    proposedDataJson: string;
  }) {
    return prisma.aIProposal.create({
      data: {
        conversationId: data.conversationId,
        clientProfileId: data.clientProfileId,
        clientId: data.clientId,
        clientName: data.clientName,
        proposalType: data.proposalType,
        status: 'PENDING',
        title: data.title,
        summary: data.summary,
        reason: data.reason,
        currentDataJson: data.currentDataJson || null,
        proposedDataJson: data.proposedDataJson,
      },
    });
  }

  /**
   * Approves an AI proposal and updates the active plan in the database.
   * This is the ONLY pathway for an AI proposal to become active.
   */
  async approveProposal(proposalId: string, adminId: string, adminName: string) {
    const proposal = await prisma.aIProposal.findUnique({
      where: { id: proposalId },
    });

    if (!proposal) throw new Error(`Proposal not found: ${proposalId}`);
    if (proposal.status === 'APPROVED') return proposal;

    const payloadRaw = proposal.finalDataJson || proposal.proposedDataJson;
    const payload = JSON.parse(payloadRaw);

    if (proposal.proposalType === 'DIET') {
      // Deactivate existing active diet plans
      await prisma.dietPlan.updateMany({
        where: {
          clientProfileId: proposal.clientProfileId,
          isActive: true,
        },
        data: { isActive: false },
      });

      // Get latest version
      const latestPlan = await prisma.dietPlan.findFirst({
        where: { clientProfileId: proposal.clientProfileId },
        orderBy: { version: 'desc' },
      });
      const nextVersion = (latestPlan?.version ?? 0) + 1;

      // Create new active diet plan
      const newPlan = await prisma.dietPlan.create({
        data: {
          clientProfileId: proposal.clientProfileId,
          clientId: proposal.clientId,
          planName: payload.planName || 'AI-Engineered Nutrition Plan',
          version: nextVersion,
          assignedById: adminId,
          assignedByName: adminName,
          dailyCalories: Number(payload.dailyCalories) || 2000,
          protein: Number(payload.protein) || 150,
          carbohydrates: Number(payload.carbohydrates) || 200,
          fat: Number(payload.fat) || 60,
          fiber: Number(payload.fiber) || 30,
          waterTargetLiters: Number(payload.waterTargetLiters) || 3.0,
          isActive: true,
          mealsJson: typeof payload.meals === 'string' ? payload.meals : JSON.stringify(payload.meals || []),
          notes: payload.notes || `Approved by Admin from AI Proposal ${proposal.id}`,
        },
      });

      // Record in DietPlanHistory
      await prisma.dietPlanHistory.create({
        data: {
          dietPlanId: newPlan.id,
          clientProfileId: proposal.clientProfileId,
          clientId: proposal.clientId,
          adminId,
          adminName,
          version: nextVersion,
          planName: newPlan.planName,
          dailyCalories: newPlan.dailyCalories,
          protein: newPlan.protein,
          carbohydrates: newPlan.carbohydrates,
          fat: newPlan.fat,
          fiber: newPlan.fiber,
          waterTargetLiters: newPlan.waterTargetLiters,
          mealsJson: newPlan.mealsJson,
          notes: newPlan.notes,
          changeSummary: `AI Nutrition Proposal approved by ${adminName}`,
        },
      });
    } else if (proposal.proposalType === 'WORKOUT') {
      // Find client user ID
      const profile = await prisma.clientProfile.findUnique({
        where: { id: proposal.clientProfileId },
        select: { userId: true },
      });

      if (profile) {
        // Create Workout Session
        const session = await prisma.workoutSession.create({
          data: {
            title: payload.title || 'AI Optimized Training Session',
            workoutType: payload.workoutType || 'Hypertrophy',
            targetMuscleGroup: payload.targetMuscleGroup || 'Full Body',
            difficulty: payload.difficulty || 'Intermediate',
            estimatedDurationMinutes: Number(payload.estimatedDurationMinutes) || 50,
            description: payload.description || 'Custom tailored by Alpha X AI Coach with Admin approval.',
            createdById: adminId,
            isActive: true,
            availabilityType: 'INDIVIDUAL',
          },
        });

        // Add Exercises and Set Templates
        if (Array.isArray(payload.exercises)) {
          for (let i = 0; i < payload.exercises.length; i++) {
            const ex = payload.exercises[i];
            const sessionExercise = await prisma.workoutSessionExercise.create({
              data: {
                sessionId: session.id,
                exerciseId: ex.exerciseId || `ex_custom_${i}`,
                exerciseName: ex.exerciseName,
                category: ex.category || 'Strength',
                orderIndex: i,
                numberOfSets: Number(ex.sets || ex.numberOfSets) || 3,
                targetReps: String(ex.targetReps || '8-12'),
                targetWeight: ex.targetWeight !== undefined ? Number(ex.targetWeight) : null,
                restSeconds: Number(ex.restSeconds) || 90,
                targetRir: ex.targetRir !== undefined ? Number(ex.targetRir) : 2,
                targetRpe: ex.targetRpe !== undefined ? Number(ex.targetRpe) : 8.0,
                tempo: ex.tempo || '3-1-1-0',
                adminInstruction: ex.notes || null,
              },
            });

            // Create set templates
            const numSets = Number(ex.sets || ex.numberOfSets) || 3;
            for (let s = 1; s <= numSets; s++) {
              await prisma.workoutSetTemplate.create({
                data: {
                  sessionExerciseId: sessionExercise.id,
                  setNumber: s,
                  setType: 'WORKING',
                  targetWeight: ex.targetWeight !== undefined ? Number(ex.targetWeight) : null,
                  targetRepsMin: 8,
                  targetRepsMax: 12,
                  targetRir: 2,
                  targetRpe: 8.0,
                },
              });
            }
          }
        }

        // Deactivate previous active assignments for this client
        await prisma.workoutAssignment.updateMany({
          where: { clientId: profile.userId, active: true },
          data: { active: false },
        });

        // Create active assignment for client
        await prisma.workoutAssignment.create({
          data: {
            sessionId: session.id,
            clientId: profile.userId,
            assignedById: adminId,
            isRecommended: true,
            active: true,
          },
        });
      }
    } else if (proposal.proposalType === 'PROGRESSION') {
      // Progression on an active session exercise
      if (payload.exerciseId || payload.exerciseName) {
        // If an active session is assigned, update targetWeight/reps on the session exercise
        const profile = await prisma.clientProfile.findUnique({
          where: { id: proposal.clientProfileId },
          select: { userId: true },
        });

        if (profile) {
          const assignment = await prisma.workoutAssignment.findFirst({
            where: { clientId: profile.userId, active: true },
            include: { session: true },
          });

          if (assignment) {
            await prisma.workoutSessionExercise.updateMany({
              where: {
                sessionId: assignment.sessionId,
                exerciseName: { contains: payload.exerciseName || payload.exercise, mode: 'insensitive' },
              },
              data: {
                targetWeight: Number(payload.targetWeight || payload.weight),
                targetReps: String(payload.targetReps || payload.reps || '8-10'),
              },
            });
          }
        }
      }
    }

    // Update proposal status
    const updatedProposal = await prisma.aIProposal.update({
      where: { id: proposalId },
      data: {
        status: 'APPROVED',
        approvedById: adminId,
        approvedByName: adminName,
        approvedAt: new Date(),
      },
    });

    // Write audit log
    await prisma.aIAuditLog.create({
      data: {
        adminId,
        adminName,
        clientId: proposal.clientId,
        clientName: proposal.clientName,
        action: 'PROPOSAL_APPROVED',
        details: `Approved ${proposal.proposalType} proposal "${proposal.title}" for client ${proposal.clientName}`,
        metadataJson: JSON.stringify({
          proposalId: proposal.id,
          proposalType: proposal.proposalType,
        }),
      },
    });

    return updatedProposal;
  }

  /**
   * Rejects an AI proposal.
   */
  async rejectProposal(proposalId: string, adminId: string, reason?: string) {
    const proposal = await prisma.aIProposal.findUnique({
      where: { id: proposalId },
    });
    if (!proposal) throw new Error(`Proposal not found: ${proposalId}`);

    const updated = await prisma.aIProposal.update({
      where: { id: proposalId },
      data: {
        status: 'REJECTED',
        rejectedById: adminId,
        rejectedAt: new Date(),
        rejectionReason: reason || 'Rejected by Admin',
      },
    });

    await prisma.aIAuditLog.create({
      data: {
        adminId,
        clientId: proposal.clientId,
        clientName: proposal.clientName,
        action: 'PROPOSAL_REJECTED',
        details: `Rejected ${proposal.proposalType} proposal "${proposal.title}" for client ${proposal.clientName}. Reason: ${reason || 'Admin decision'}`,
        metadataJson: JSON.stringify({ proposalId: proposal.id }),
      },
    });

    return updated;
  }

  /**
   * Modifies an AI proposal prior to approval.
   */
  async editProposal(proposalId: string, adminId: string, editedPayload: any) {
    const proposal = await prisma.aIProposal.findUnique({
      where: { id: proposalId },
    });
    if (!proposal) throw new Error(`Proposal not found: ${proposalId}`);

    const updated = await prisma.aIProposal.update({
      where: { id: proposalId },
      data: {
        status: 'EDITED',
        finalDataJson: JSON.stringify(editedPayload),
      },
    });

    await prisma.aIAuditLog.create({
      data: {
        adminId,
        clientId: proposal.clientId,
        clientName: proposal.clientName,
        action: 'PROPOSAL_EDITED',
        details: `Admin modified payload for ${proposal.proposalType} proposal "${proposal.title}"`,
        metadataJson: JSON.stringify({ proposalId: proposal.id }),
      },
    });

    return updated;
  }
}

export const aiTools = new AiTools();
