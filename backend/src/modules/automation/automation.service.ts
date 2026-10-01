import { prisma } from '../../config/prisma';
import { aiEngagementService, NotificationTriggerRule, ClientContext } from './ai_engagement.service';

export interface DailyAutomationResult {
  clientsEvaluated: number;
  notificationsCreated: number;
  attentionItemsCreated: number;
  timestamp: string;
}

export class AutomationService {
  /**
   * Evaluates all active clients once daily.
   * Identifies attention indicators for coaches and dispatches personalized engagement notifications.
   */
  public async runDailyAutomationCycle(specificClientId?: string): Promise<DailyAutomationResult> {
    const today = new Date();
    const todayStr = today.toISOString().split('T')[0];
    const twentyFourHoursAgo = new Date(today.getTime() - 24 * 60 * 60 * 1000);
    const eighteenHoursAgo = new Date(today.getTime() - 18 * 60 * 60 * 1000);

    const clientFilter: any = {};
    if (specificClientId) {
      clientFilter.OR = [
        { id: specificClientId },
        { clientId: specificClientId.toUpperCase() },
        { userId: specificClientId },
      ];
    }

    const clients = await prisma.clientProfile.findMany({
      where: clientFilter,
      include: {
        user: { select: { id: true, name: true, email: true } },
        dietPlans: { where: { isActive: true }, take: 1 },
        activityRecords: { where: { date: new Date(todayStr) } },
        foodLogs: { where: { dateString: todayStr } },
        weeklyCheckIns: { orderBy: { checkInDate: 'desc' }, take: 2 },
        notificationPref: true,
        notifications: {
          where: { createdAt: { gte: twentyFourHoursAgo } },
          orderBy: { createdAt: 'desc' },
        },
      },
    });

    let notificationsCreated = 0;
    let attentionItemsCreated = 0;

    for (const client of clients) {
      const prefs = client.notificationPref || {
        workoutReminders: true,
        nutritionReminders: true,
        weeklyCheckInReminders: true,
        activityReminders: true,
        membershipAlerts: true,
        aiEngagementEnabled: true,
      };

      // 1. Calculate Activity & Inactivity Days
      const lastActiveDate = client.lastAppOpenAt || client.createdAt;
      const msSinceActive = today.getTime() - new Date(lastActiveDate).getTime();
      const daysInactive = Math.floor(msSinceActive / (1000 * 60 * 60 * 24));

      // 2. Calculate Today's Steps
      const todayActivity = client.activityRecords[0];
      const stepsToday = todayActivity ? todayActivity.steps : 0;
      const stepGoal = client.dailyStepGoal || 6000;

      // 3. Calculate Today's Nutrition Progress
      const foodLoggedToday = client.foodLogs.length > 0;
      let proteinConsumed = 0;
      for (const item of client.foodLogs) {
        proteinConsumed += (item.protein || 0) * (item.quantity || 1.0);
      }
      const activeDiet = client.dietPlans[0];
      const proteinTarget = activeDiet ? activeDiet.protein : 150;

      // 4. Calculate Workout Progress Today
      const workoutRecordToday = await prisma.workoutRecord.findFirst({
        where: {
          clientId: client.user.id,
          startedAt: { gte: new Date(`${todayStr}T00:00:00.000Z`) },
        },
      });
      const workoutCompletedToday = Boolean(workoutRecordToday?.isCompleted);

      // Check if client has an assigned workout
      const assignment = await prisma.workoutAssignment.findFirst({
        where: {
          OR: [{ clientId: client.user.id }, { clientId: null }],
          active: true,
        },
        include: { session: true },
      });
      const assignedWorkoutTitle = assignment?.session?.title;

      // 5. Weekly Check-In Status
      const latestCheckIn = client.weeklyCheckIns[0];
      const checkInAvailable = !latestCheckIn || today >= latestCheckIn.nextCheckInDate;
      const checkInOverdue = latestCheckIn && (today.getTime() - latestCheckIn.nextCheckInDate.getTime()) > (3 * 24 * 60 * 60 * 1000);

      // 6. Membership Status
      let membershipDaysRemaining: number | undefined;
      let isMembershipExpiringSoon = false;
      let isMembershipExpired = false;
      if (client.membershipExpiresAt) {
        const msRemaining = new Date(client.membershipExpiresAt).getTime() - today.getTime();
        membershipDaysRemaining = Math.ceil(msRemaining / (1000 * 60 * 60 * 24));
        if (membershipDaysRemaining <= 0) {
          isMembershipExpired = true;
        } else if (membershipDaysRemaining <= 7) {
          isMembershipExpiringSoon = true;
        }
      }

      // ==========================================
      // A. ADMIN ATTENTION CENTER ITEMS
      // ==========================================
      const attentionTriggers: Array<{
        type: string;
        severity: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';
        title: string;
        details: string;
        data?: any;
      }> = [];

      // Critical: Pain reported in check-in within last 7 days
      if (latestCheckIn?.hasPain) {
        const daysSinceCheckIn = Math.floor((today.getTime() - new Date(latestCheckIn.checkInDate).getTime()) / (1000 * 60 * 60 * 24));
        if (daysSinceCheckIn <= 7) {
          attentionTriggers.push({
            type: 'PAIN_REPORTED',
            severity: 'CRITICAL',
            title: `Pain Reported: ${latestCheckIn.painLocation || 'General'}`,
            details: `Pain level ${latestCheckIn.painLevel || 'N/A'}/10 during ${latestCheckIn.painExercise || 'exercise'}. "${latestCheckIn.painDescription || 'No description provided'}"`,
            data: { checkInId: latestCheckIn.id, painLevel: latestCheckIn.painLevel, location: latestCheckIn.painLocation },
          });
        }
      }

      // Inactivity attention
      if (daysInactive >= 3) {
        attentionTriggers.push({
          type: 'INACTIVE',
          severity: 'HIGH',
          title: `Inactive for ${daysInactive} Days`,
          details: `Client has not opened Alpha X since ${new Date(lastActiveDate).toLocaleDateString()}.`,
        });
      }

      // Check-in overdue
      if (checkInOverdue) {
        attentionTriggers.push({
          type: 'MISSING_CHECKIN',
          severity: 'HIGH',
          title: 'Weekly Check-In Missing',
          details: `Check-in unlocked on ${new Date(latestCheckIn!.nextCheckInDate).toLocaleDateString()} but has not been submitted.`,
        });
      }

      // Missed workout today
      if (assignedWorkoutTitle && !workoutCompletedToday && today.getHours() >= 18) {
        attentionTriggers.push({
          type: 'MISSED_WORKOUT',
          severity: 'MEDIUM',
          title: `Missed Scheduled Workout`,
          details: `Scheduled session "${assignedWorkoutTitle}" was not completed today.`,
        });
      }

      // Missing food logs today (after 20:00)
      if (!foodLoggedToday && today.getHours() >= 20) {
        attentionTriggers.push({
          type: 'MISSING_FOOD',
          severity: 'MEDIUM',
          title: 'Zero Food Logged Today',
          details: 'Athlete has not logged any meals or snacks for today.',
        });
      }

      // Protein significantly below target (after 20:00)
      if (foodLoggedToday && proteinConsumed < (proteinTarget * 0.7) && today.getHours() >= 20) {
        attentionTriggers.push({
          type: 'LOW_PROTEIN',
          severity: 'MEDIUM',
          title: 'Protein Below Target',
          details: `Consumed ${Math.round(proteinConsumed)}g vs target ${Math.round(proteinTarget)}g (${Math.round(proteinTarget - proteinConsumed)}g gap).`,
        });
      }

      // Steps below target (after 20:00)
      if (stepsToday < (stepGoal * 0.5) && today.getHours() >= 20) {
        attentionTriggers.push({
          type: 'LOW_STEPS',
          severity: 'LOW',
          title: 'Low Step Volume',
          details: `Logged ${stepsToday} steps against ${stepGoal} daily goal (<50%).`,
        });
      }

      // Membership expiring soon or expired
      if (isMembershipExpired) {
        attentionTriggers.push({
          type: 'MEMBERSHIP_EXPIRING',
          severity: 'CRITICAL',
          title: 'Membership Expired',
          details: `Alpha X membership expired on ${client.membershipExpiresAt?.toLocaleDateString()}.`,
        });
      } else if (isMembershipExpiringSoon) {
        attentionTriggers.push({
          type: 'MEMBERSHIP_EXPIRING',
          severity: 'HIGH',
          title: `Membership Expires in ${membershipDaysRemaining} Days`,
          details: `Renewal required before ${client.membershipExpiresAt?.toLocaleDateString()}.`,
        });
      }

      // Upsert attention items in database
      for (const item of attentionTriggers) {
        // Prevent creating identical unreviewed attention item on the same day
        const existing = await prisma.adminAttentionItem.findFirst({
          where: {
            clientProfileId: client.id,
            attentionType: item.type,
            isReviewed: false,
            createdAt: { gte: twentyFourHoursAgo },
          },
        });

        if (!existing) {
          await prisma.adminAttentionItem.create({
            data: {
              clientProfileId: client.id,
              clientId: client.clientId,
              clientName: client.user.name,
              attentionType: item.type,
              severity: item.severity,
              title: item.title,
              details: item.details,
              dataJson: item.data ? JSON.stringify(item.data) : null,
            },
          });
          attentionItemsCreated++;
        }
      }

      // ==========================================
      // B. CLIENT ENGAGEMENT NOTIFICATION RULES
      // ==========================================
      // Evaluate rule priority candidate
      let candidateRule: NotificationTriggerRule | null = null;

      if (isMembershipExpired && prefs.membershipAlerts) {
        candidateRule = 'MEMBERSHIP_EXPIRED';
      } else if (isMembershipExpiringSoon && prefs.membershipAlerts) {
        candidateRule = 'MEMBERSHIP_EXPIRING_SOON';
      } else if (checkInOverdue && prefs.weeklyCheckInReminders) {
        candidateRule = 'CHECK_IN_MISSING';
      } else if (checkInAvailable && prefs.weeklyCheckInReminders) {
        candidateRule = 'CHECK_IN_AVAILABLE';
      } else if (daysInactive >= 3 && prefs.workoutReminders) {
        candidateRule = 'INACTIVE_MULTIPLE_DAYS';
      } else if (daysInactive === 1 && prefs.workoutReminders) {
        candidateRule = 'INACTIVE_1_DAY';
      } else if (workoutCompletedToday && prefs.workoutReminders) {
        candidateRule = 'WORKOUT_COMPLETED';
      } else if (!workoutCompletedToday && assignedWorkoutTitle && prefs.workoutReminders) {
        candidateRule = 'WORKOUT_MISSED';
      } else if (!foodLoggedToday && prefs.nutritionReminders && today.getHours() >= 14) {
        candidateRule = 'FOOD_NOT_LOGGED';
      } else if (foodLoggedToday && (proteinTarget - proteinConsumed >= 30) && prefs.nutritionReminders && today.getHours() >= 17) {
        candidateRule = 'PROTEIN_BELOW_TARGET';
      } else if (stepsToday < stepGoal && prefs.activityReminders && today.getHours() >= 18) {
        candidateRule = 'STEPS_BELOW_TARGET';
      }

      if (candidateRule) {
        // Cooldown and deduplication enforcement:
        // 1. Has client already received ANY notification in the last 18 hours?
        const recentNotif = client.notifications.find((n) => new Date(n.createdAt) >= eighteenHoursAgo);
        // 2. Has client received THIS exact trigger in the last 24 hours?
        const duplicateRule = client.notifications.find((n) => n.triggerRule === candidateRule);

        if (!duplicateRule && (!recentNotif || candidateRule.startsWith('MEMBERSHIP') || candidateRule.startsWith('CHECK_IN'))) {
          const clientContext: ClientContext = {
            firstName: client.user.name.split(' ')[0],
            clientId: client.clientId || undefined,
            primaryGoal: client.primaryGoal || undefined,
            assignedWorkoutTitle: assignedWorkoutTitle || undefined,
            workoutCompletedToday,
            foodLoggedToday,
            proteinConsumedGrams: proteinConsumed,
            proteinTargetGrams: proteinTarget,
            stepsToday,
            stepsGoal: stepGoal,
            daysInactive,
            checkInAvailable,
            membershipDaysRemaining,
          };

          const payload = aiEngagementService.generateEngagementMessage(candidateRule, clientContext);

          await prisma.notification.create({
            data: {
              clientProfileId: client.id,
              clientId: client.clientId,
              title: payload.title,
              message: payload.message,
              type: candidateRule.split('_')[0] || 'SYSTEM',
              category: candidateRule.includes('CHECK_IN') ? 'CHECK_IN' : (candidateRule.includes('WORKOUT') ? 'WORKOUT' : 'NUTRITION'),
              priority: payload.priority,
              source: prefs.aiEngagementEnabled ? 'AI_COACH' : 'AUTOMATION_RULE',
              triggerRule: candidateRule,
              sentStatus: 'SENT',
            },
          });
          notificationsCreated++;
        }
      }
    }

    return {
      clientsEvaluated: clients.length,
      notificationsCreated,
      attentionItemsCreated,
      timestamp: today.toISOString(),
    };
  }

  /**
   * Generates a factual weekly progress report for an athlete.
   * Calculations derive 100% from recorded database entries without invented percentages.
   */
  public async generateFactualWeeklyReport(idOrClientId: string) {
    const clean = idOrClientId.trim();
    const user = await prisma.user.findFirst({
      where: {
        OR: [
          { id: clean },
          { clientProfile: { clientId: clean.toUpperCase() } },
          { clientProfile: { id: clean } },
        ],
      },
      include: {
        clientProfile: {
          include: {
            dietPlans: { where: { isActive: true }, take: 1 },
            weeklyCheckIns: { orderBy: { weekNumber: 'desc' }, take: 2 },
            progressRecords: { orderBy: { date: 'desc' }, take: 30 },
            activityRecords: { orderBy: { date: 'desc' }, take: 14 },
            foodLogs: { orderBy: { date: 'desc' }, take: 50 },
          },
        },
      },
    });

    if (!user || !user.clientProfile) {
      throw new Error(`Client ${idOrClientId} not found`);
    }

    const cp = user.clientProfile;
    const checkIns = cp.weeklyCheckIns;
    const latestCheckIn = checkIns[0] || null;
    const previousCheckIn = checkIns[1] || null;

    // Weight and waist deltas
    let weightCurrent = cp.weightKg || (latestCheckIn ? latestCheckIn.weightKg : null);
    let weightDelta: number | null = null;
    let waistCurrent = latestCheckIn?.waistCm || null;
    let waistDelta: number | null = null;

    if (latestCheckIn && previousCheckIn) {
      weightDelta = Number((latestCheckIn.weightKg - previousCheckIn.weightKg).toFixed(1));
      if (latestCheckIn.waistCm && previousCheckIn.waistCm) {
        waistDelta = Number((latestCheckIn.waistCm - previousCheckIn.waistCm).toFixed(1));
      }
    }

    // Workout completion in last 7 days
    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    const completedWorkouts = await prisma.workoutRecord.findMany({
      where: {
        clientId: user.id,
        isCompleted: true,
        startedAt: { gte: sevenDaysAgo },
      },
    });
    const totalWorkoutVolume = completedWorkouts.reduce((sum, w) => sum + (w.totalVolume || 0), 0);

    // Steps average in last 7 days
    const recentActivity = cp.activityRecords.filter((a) => new Date(a.date) >= sevenDaysAgo);
    const avgSteps = recentActivity.length > 0
      ? Math.round(recentActivity.reduce((sum, a) => sum + a.steps, 0) / recentActivity.length)
      : 0;

    // Food logging consistency in last 7 days
    const uniqueDaysLogged = new Set(
      cp.foodLogs
        .filter((f) => new Date(f.date) >= sevenDaysAgo)
        .map((f) => f.dateString)
    ).size;

    return {
      client: {
        id: user.id,
        clientId: cp.clientId,
        name: user.name,
        email: user.email,
        primaryGoal: cp.primaryGoal,
      },
      reportPeriod: {
        startDate: sevenDaysAgo.toISOString().split('T')[0],
        endDate: new Date().toISOString().split('T')[0],
      },
      metrics: {
        weightKg: weightCurrent,
        weightDeltaKg: weightDelta,
        waistCm: waistCurrent,
        waistDeltaCm: waistDelta,
        workoutsCompleted: completedWorkouts.length,
        totalWorkoutVolumeKg: Math.round(totalWorkoutVolume),
        dailyStepsAverage: avgSteps,
        daysFoodLogged: uniqueDaysLogged,
        totalDaysInPeriod: 7,
      },
      checkInSummary: latestCheckIn
        ? {
            weekNumber: latestCheckIn.weekNumber,
            date: latestCheckIn.checkInDate.toISOString().split('T')[0],
            nutritionAdherence: latestCheckIn.dietAdherence,
            proteinAdherence: latestCheckIn.nutritionProtein,
            sleepHours: latestCheckIn.sleepHours,
            sleepQuality: latestCheckIn.sleepQuality,
            recoveryQuality: latestCheckIn.recoveryQuality,
            hasPain: latestCheckIn.hasPain,
            painDetails: latestCheckIn.hasPain
              ? `${latestCheckIn.painLocation || 'General'} (Level ${latestCheckIn.painLevel || 0}/10)`
              : null,
            clientNotes: latestCheckIn.clientNotes,
            coachReview: latestCheckIn.hasCoachReview
              ? {
                  reviewerName: latestCheckIn.reviewedByName,
                  whatWentWell: latestCheckIn.whatWentWell,
                  needsImprovement: latestCheckIn.needsImprovement,
                  nextWeekFocus: latestCheckIn.nextWeekFocus,
                }
              : null,
          }
        : null,
    };
  }
}

export const automationService = new AutomationService();
