/**
 * Alpha X Gym — Fitness Engagement Push Notification Service
 *
 * Keeps gym clients engaged, motivated, hydrated, and consistent with their workout
 * and nutrition goals without sending payment or membership expiry notifications.
 *
 * Supported Engagement Categories:
 *   1. HYDRATION: "Stay Hydrated 💧 Time to drink some water!"
 *   2. PROTEIN_GOAL: "Protein Check 🥚 How close are you to your daily protein goal?"
 *   3. WORKOUT_MOTIVATION: "Ready to Grind? 💪 Let's make today's workout count!"
 *   4. CONSISTENCY: "Consistency beats motivation. Show up for yourself today 🔥"
 *   5. RECOVERY: "Recovery matters 😴 Get enough rest and come back stronger."
 *   6. GOAL_CHECK_IN: "Small steps. Strong habits. Keep moving toward your goal!"
 *
 * Scheduling & Targeting Rules:
 *   - Configurable timings in Asia/Kolkata timezone (IST / UTC+05:30).
 *   - Hydration reminders are spaced and capped (max 2 per day during active hours).
 *   - Workout motivation is customized using client's assigned workout schedule when available.
 *   - Protein check-ins are sent ONLY to users who have an active nutrition/protein goal.
 *   - Target eligible clients using existing OneSignal External ID (user.id).
 *   - Strictly excludes admins (Role: ADMIN) and clients who opted out.
 *   - Atomic Postgres deduplication via dedupKey prevents duplicate sends.
 *   - Quiet hours (21:00 - 07:00 IST) and user category preferences are strictly respected.
 *   - If step/activity data is unavailable, does NOT fabricate metrics.
 */

import { prisma } from '../../config/prisma';
import { notificationPolicyService } from './notification_policy.service';

export type EngagementCategory =
  | 'HYDRATION'
  | 'PROTEIN_GOAL'
  | 'WORKOUT_MOTIVATION'
  | 'CONSISTENCY'
  | 'RECOVERY'
  | 'GOAL_CHECK_IN';

export interface CategoryConfig {
  enabled: boolean;
  scheduleHoursIST: number[]; // e.g. [11, 15] for 11:00 AM and 3:00 PM IST
  frequency: 'ONCE_DAILY' | 'TWICE_DAILY' | 'TRAINING_DAYS_ONLY' | 'WEEKLY';
}

export interface FitnessEngagementSettings {
  enabled: boolean;
  timezone: string;
  categories: {
    HYDRATION: CategoryConfig;
    PROTEIN_GOAL: CategoryConfig;
    WORKOUT_MOTIVATION: CategoryConfig;
    CONSISTENCY: CategoryConfig;
    RECOVERY: CategoryConfig;
    GOAL_CHECK_IN: CategoryConfig;
  };
}

export interface EngagementSweepResult {
  category: EngagementCategory | 'ALL';
  evaluated: number;
  sent: number;
  skipped: number;
  duplicate: number;
  dryRun: boolean;
  timestamp: string;
}

export interface TestEngagementResult {
  success: boolean;
  category: EngagementCategory;
  clientId: string;
  clientName: string;
  externalId: string;
  title: string;
  message: string;
  notificationId?: string;
  status: string;
  error?: string;
}

export const DEFAULT_ENGAGEMENT_SETTINGS: FitnessEngagementSettings = {
  enabled: true,
  timezone: 'Asia/Kolkata',
  categories: {
    HYDRATION: {
      enabled: true,
      scheduleHoursIST: [11, 15], // 11:00 AM and 3:00 PM IST
      frequency: 'TWICE_DAILY',
    },
    PROTEIN_GOAL: {
      enabled: true,
      scheduleHoursIST: [17], // 5:00 PM IST
      frequency: 'ONCE_DAILY',
    },
    WORKOUT_MOTIVATION: {
      enabled: true,
      scheduleHoursIST: [9], // 9:00 AM IST
      frequency: 'TRAINING_DAYS_ONLY',
    },
    CONSISTENCY: {
      enabled: true,
      scheduleHoursIST: [12], // 12:00 PM IST
      frequency: 'ONCE_DAILY',
    },
    RECOVERY: {
      enabled: true,
      scheduleHoursIST: [20], // 8:00 PM IST (before 21:00 quiet hours)
      frequency: 'ONCE_DAILY',
    },
    GOAL_CHECK_IN: {
      enabled: true,
      scheduleHoursIST: [18], // 6:00 PM IST
      frequency: 'WEEKLY',
    },
  },
};

export class FitnessEngagementService {
  private inMemorySettings: FitnessEngagementSettings = JSON.parse(JSON.stringify(DEFAULT_ENGAGEMENT_SETTINGS));

  // Varied friendly message pools (deterministic rotation based on day-of-year)
  private readonly messagePools: Record<EngagementCategory, Array<{ title: string; body: string }>> = {
    HYDRATION: [
      {
        title: 'Stay Hydrated 💧',
        body: 'Stay Hydrated 💧 Time to drink some water!',
      },
      {
        title: 'Hydration Check 💧',
        body: 'Hydration Check 💧 Grab a glass of water to keep your energy and metabolism high!',
      },
      {
        title: 'Water Break 💧',
        body: 'Water Break 💧 Muscles are 75% water—stay fueled and hydrated today!',
      },
      {
        title: 'Hydrate & Refuel 💧',
        body: 'Quick reminder to sip some water 💧 Optimal recovery starts with hydration.',
      },
      {
        title: 'Midday Hydration 💧',
        body: 'Halfway through the day! Keep that water bottle close and take a sip 💧',
      },
    ],
    PROTEIN_GOAL: [
      {
        title: 'Protein Check 🥚',
        body: 'Protein Check 🥚 How close are you to your daily protein goal?',
      },
      {
        title: 'Fuel Your Muscles 🥩',
        body: 'Fuel Your Muscles 🥩 Did you hit your protein target today?',
      },
      {
        title: 'Protein Reminder 🍳',
        body: 'Protein Time 🍳 Rebuild and recover strong by locking in your protein target!',
      },
      {
        title: 'Daily Nutrition Check 🍗',
        body: "Check-in: How's your protein looking today? Fuel up and stay on track 🍗",
      },
      {
        title: 'Recovery Nutrition 🥚',
        body: 'Nutrition reminder: Meeting your protein goal is key to muscle repair and growth 🥚',
      },
    ],
    WORKOUT_MOTIVATION: [
      {
        title: 'Ready to Grind? 💪',
        body: "Ready to Grind? 💪 Let's make today's workout count!",
      },
      {
        title: 'Time to Train 🏋️',
        body: "Today is your day to get stronger 🏋️ Let's crush this session!",
      },
      {
        title: 'Energy Check ⚡',
        body: 'Workout time approaching! Bring your full energy today 💪',
      },
      {
        title: 'Iron Awaits 🔥',
        body: 'The iron is waiting ⚡ Lock in, show up, and make progress today!',
      },
      {
        title: 'Daily Progress 👊',
        body: "Every rep counts toward your transformation. Let's get after it today 🔥",
      },
    ],
    CONSISTENCY: [
      {
        title: 'Stay Consistent 🔥',
        body: 'Consistency beats motivation. Show up for yourself today 🔥',
      },
      {
        title: 'Discipline Over Motivation ⚡',
        body: 'Discipline is doing what needs to be done. Keep your streak alive! ⚡',
      },
      {
        title: 'Keep Showing Up 👊',
        body: "You don't have to be extreme, just consistent. Proud of your commitment 👊",
      },
      {
        title: 'Momentum Matters 🎯',
        body: 'Great results come from showing up day after day. Keep going strong! 🎯',
      },
      {
        title: 'Daily Discipline 🔥',
        body: 'Small daily actions create massive long-term results. Stay consistent 🔥',
      },
    ],
    RECOVERY: [
      {
        title: 'Recovery Matters 😴',
        body: 'Recovery matters 😴 Get enough rest and come back stronger.',
      },
      {
        title: 'Rest & Grow 🌙',
        body: 'Growth happens while you rest 🌙 Prioritize quality sleep tonight!',
      },
      {
        title: 'Recharge Tonight 🧘',
        body: 'Great work today! Take time to stretch, hydrate, and recharge 🧘',
      },
      {
        title: 'Rebuilding Hours 😴',
        body: 'Your body rebuilds while you sleep. Aim for 7-8 hours of quality rest tonight 😴',
      },
      {
        title: 'Wind Down 🌿',
        body: 'Rest is an essential part of the program. Unwind and recharge for tomorrow 🌿',
      },
    ],
    GOAL_CHECK_IN: [
      {
        title: 'Goal Check-In 🎯',
        body: 'Small steps. Strong habits. Keep moving toward your goal!',
      },
      {
        title: 'Celebrate Your Progress ⭐',
        body: "Every day is progress. What is one fitness win you're proud of today? ⭐",
      },
      {
        title: 'Remember Your Why 🚀',
        body: "Remember why you started. You're closer today than you were yesterday 🚀",
      },
      {
        title: 'Keep Moving Forward 🏆',
        body: 'Keep your eyes on your goal. Your dedication is building something great! 🏆',
      },
      {
        title: 'Habit Power ✨',
        body: "Progress isn't always loud, but consistency always pays off. Keep at it! ✨",
      },
    ],
  };

  /**
   * Retrieves current configuration.
   * Checks database (AIAuditLog storage) first so admin changes persist across serverless instances.
   */
  async getSettings(): Promise<FitnessEngagementSettings> {
    try {
      const persisted = await prisma.aIAuditLog.findFirst({
        where: { action: 'FITNESS_ENGAGEMENT_SETTINGS' },
        orderBy: { createdAt: 'desc' },
      });

      if (persisted && persisted.metadataJson) {
        const parsed = JSON.parse(persisted.metadataJson);
        this.inMemorySettings = {
          ...DEFAULT_ENGAGEMENT_SETTINGS,
          ...parsed,
          categories: {
            ...DEFAULT_ENGAGEMENT_SETTINGS.categories,
            ...(parsed.categories || {}),
          },
        };
      }
    } catch (err: any) {
      console.warn('[ENGAGEMENT] Failed to load persisted settings, using in-memory:', err?.message);
    }

    return this.inMemorySettings;
  }

  /**
   * Updates configuration and persists to PostgreSQL.
   */
  async updateSettings(
    newSettings: Partial<FitnessEngagementSettings>,
    adminId: string = 'master-admin'
  ): Promise<FitnessEngagementSettings> {
    const current = await this.getSettings();

    const merged: FitnessEngagementSettings = {
      ...current,
      ...newSettings,
      categories: {
        ...current.categories,
        ...(newSettings.categories || {}),
      },
    };

    this.inMemorySettings = merged;

    try {
      await prisma.aIAuditLog.create({
        data: {
          adminId,
          action: 'FITNESS_ENGAGEMENT_SETTINGS',
          details: 'Updated Automated Fitness Engagement Notification Settings',
          metadataJson: JSON.stringify(merged),
        },
      });
      console.log('[ENGAGEMENT] ✅ Saved updated fitness engagement settings to PostgreSQL');
    } catch (err: any) {
      console.error('[ENGAGEMENT] ❌ Failed to persist settings to DB:', err?.message);
    }

    return merged;
  }

  /**
   * Selects message copy for a category with deterministic daily rotation.
   */
  getMessageForCategory(
    category: EngagementCategory,
    clientName: string,
    scheduledSessionTitle?: string,
    proteinTargetG?: number
  ): { title: string; message: string } {
    const pool = this.messagePools[category] || this.messagePools.WORKOUT_MOTIVATION;
    const now = new Date();
    const startOfYear = new Date(now.getFullYear(), 0, 0);
    const dayOfYear = Math.floor((now.getTime() - startOfYear.getTime()) / (1000 * 60 * 60 * 24));
    const index = dayOfYear % pool.length;
    const item = pool[index];

    let message = item.body;

    // Tailor workout motivation with assigned session title if available
    if (category === 'WORKOUT_MOTIVATION' && scheduledSessionTitle) {
      message = `Ready to Grind, ${clientName}? 💪 "${scheduledSessionTitle}" is scheduled for today. Let's make it count!`;
    }

    // Tailor protein check with actual target if available
    if (category === 'PROTEIN_GOAL' && proteinTargetG && proteinTargetG > 0) {
      message = `Protein Check, ${clientName} 🥚 Daily target is ${proteinTargetG}g. How close are you today?`;
    }

    return {
      title: item.title,
      message,
    };
  }

  /**
   * Sends a targeted test engagement notification to ONE explicitly selected test client.
   * Strictly prevents broadcast to all clients.
   */
  async sendTestEngagementNotification(
    adminId: string,
    clientIdOrIdentifier: string,
    category: EngagementCategory,
    force: boolean = false
  ): Promise<TestEngagementResult> {
    const user = await prisma.user.findFirst({
      where: {
        role: 'CLIENT',
        OR: [
          { id: clientIdOrIdentifier },
          { email: clientIdOrIdentifier.toLowerCase() },
          { clientProfile: { clientId: clientIdOrIdentifier.toUpperCase() } },
          { clientProfile: { id: clientIdOrIdentifier } },
        ],
      },
      include: {
        clientProfile: {
          include: {
            dietPlans: { where: { isActive: true }, take: 1 },
            notificationPref: true,
          },
        },
        assignments: {
          where: { active: true },
          include: { session: true },
          take: 1,
        },
      },
    });

    if (!user || !user.clientProfile) {
      return {
        success: false,
        category,
        clientId: clientIdOrIdentifier,
        clientName: 'Unknown',
        externalId: clientIdOrIdentifier,
        title: '',
        message: '',
        status: 'CLIENT_NOT_FOUND',
        error: `Client "${clientIdOrIdentifier}" not found. Verify athlete UUID, AXG-ID, or email.`,
      };
    }

    const firstName = user.name.split(' ')[0] || 'Athlete';
    const diet = user.clientProfile.dietPlans[0];
    const proteinTarget = diet?.protein ? Math.round(diet.protein) : undefined;
    const todaySession = user.assignments[0]?.session?.title;

    const { title, message } = this.getMessageForCategory(
      category,
      firstName,
      todaySession,
      proteinTarget
    );

    const tz = user.clientProfile.notificationPref?.timezone || 'Asia/Kolkata';
    const { dateStr } = notificationPolicyService.getLocalTimeParts(tz);
    // Unique test dedupKey allowing immediate re-testing
    const dedupKey = `TEST_ENGAGEMENT:${category}:${user.clientProfile.id}:${Date.now()}`;

    // Map category to policy type & preference
    const { type, preferenceKey } = this.mapCategoryToPolicyFields(category);

    const dispatchResult = await notificationPolicyService.dispatch({
      userId: user.id,
      clientProfileId: user.clientProfile.id,
      clientId: user.clientProfile.clientId,
      title,
      message,
      type,
      category,
      priority: 'NORMAL',
      source: 'ADMIN',
      triggerRule: `ENGAGEMENT_${category}`,
      tier: 'PROACTIVE',
      preferenceKey,
      dedupKey,
      ignoreQuietHours: force, // Force option allows admin to test even during quiet hours
      ignoreRateLimit: force,
      data: {
        type: 'fitness_engagement',
        category,
        clientId: user.clientProfile.clientId || '',
        isTest: 'true',
      },
    });

    return {
      success: dispatchResult.success,
      category,
      clientId: user.clientProfile.clientId || user.id,
      clientName: user.name,
      externalId: user.id,
      title,
      message,
      notificationId: dispatchResult.notificationId,
      status: dispatchResult.status,
      error: dispatchResult.error,
    };
  }

  /**
   * Executes scheduled engagement sweep for a specific category or automatically based on current hour.
   * Timezone: Asia/Kolkata (IST).
   */
  async runEngagementSweep(
    specificCategory?: EngagementCategory,
    dryRun: boolean = false,
    force: boolean = false
  ): Promise<EngagementSweepResult> {
    const settings = await this.getSettings();

    if (!settings.enabled && !specificCategory) {
      console.log('[ENGAGEMENT] Master engagement switch is disabled.');
      return {
        category: specificCategory || 'ALL',
        evaluated: 0,
        sent: 0,
        skipped: 0,
        duplicate: 0,
        dryRun,
        timestamp: new Date().toISOString(),
      };
    }

    const tz = settings.timezone || 'Asia/Kolkata';
    const { hour, dateStr, weekday } = notificationPolicyService.getLocalTimeParts(tz);

    // Determine eligible categories for this execution
    let targetCategories: EngagementCategory[] = [];
    if (specificCategory) {
      targetCategories = [specificCategory];
    } else {
      // Find categories configured for the current hour
      for (const [catKey, catConfig] of Object.entries(settings.categories)) {
        const cat = catKey as EngagementCategory;
        if (catConfig.enabled && catConfig.scheduleHoursIST.includes(hour)) {
          targetCategories.push(cat);
        }
      }
    }

    if (targetCategories.length === 0) {
      console.log(`[ENGAGEMENT] No categories scheduled for ${hour}:00 IST.`);
      return {
        category: 'ALL',
        evaluated: 0,
        sent: 0,
        skipped: 0,
        duplicate: 0,
        dryRun,
        timestamp: new Date().toISOString(),
      };
    }

    // Fetch all active clients
    const clients = await prisma.user.findMany({
      where: {
        role: 'CLIENT',
        notificationsEnabled: true,
      },
      include: {
        clientProfile: {
          include: {
            dietPlans: { where: { isActive: true }, take: 1 },
            notificationPref: true,
          },
        },
        assignments: {
          where: { active: true },
          include: { session: true },
        },
      },
    });

    let totalSent = 0;
    let totalSkipped = 0;
    let totalDuplicate = 0;

    for (const client of clients) {
      const profile = client.clientProfile;
      if (!profile) {
        totalSkipped++;
        continue;
      }

      for (const category of targetCategories) {
        const catConfig = settings.categories[category];
        if (!catConfig.enabled && !specificCategory) {
          totalSkipped++;
          continue;
        }

        // --- RULE 1: PROTEIN CHECK-IN ONLY IF NUTRITION/PROTEIN GOAL CONFIGURED ---
        const activeDiet = profile.dietPlans[0];
        const hasProteinGoal = Boolean(activeDiet && activeDiet.protein && activeDiet.protein > 0);
        if (category === 'PROTEIN_GOAL' && !hasProteinGoal) {
          // Client has not configured a protein goal — skip per explicit requirements
          totalSkipped++;
          continue;
        }

        // --- RULE 2: WORKOUT MOTIVATION BASED ON ASSIGNED SCHEDULE WHEN AVAILABLE ---
        const todayAssignment = client.assignments.find(
          (a) => a.active && a.session && (a.scheduledDate === dateStr || !a.scheduledDate)
        );
        const preferredDays = profile.preferredDays || [];
        const isPreferredDay = preferredDays.some((d) => d.toLowerCase() === weekday.toLowerCase());
        const isTrainingDay = Boolean(todayAssignment) || isPreferredDay;

        if (category === 'WORKOUT_MOTIVATION' && catConfig.frequency === 'TRAINING_DAYS_ONLY' && !isTrainingDay) {
          totalSkipped++;
          continue;
        }

        // --- RULE 3: WEEKLY GOAL CHECK-IN DAYS ---
        if (category === 'GOAL_CHECK_IN' && catConfig.frequency === 'WEEKLY') {
          // Default to Sunday or Friday
          const isCheckInDay = weekday === 'Sunday' || weekday === 'Friday';
          if (!isCheckInDay && !specificCategory) {
            totalSkipped++;
            continue;
          }
        }

        const firstName = client.name.split(' ')[0] || 'Athlete';
        const sessionTitle = todayAssignment?.session?.title;
        const proteinTarget = activeDiet?.protein ? Math.round(activeDiet.protein) : undefined;

        const { title, message } = this.getMessageForCategory(
          category,
          firstName,
          sessionTitle,
          proteinTarget
        );

        // Deduplication key: e.g. ENGAGEMENT:HYDRATION:uuid:2026-10-18:11
        // For twice-daily hydration, slot by hour; for once-daily, slot by dateStr
        const slot = catConfig.frequency === 'TWICE_DAILY' ? `H${hour}` : 'DAILY';
        const dedupKey = `ENGAGEMENT:${category}:${profile.id}:${dateStr}:${slot}`;

        if (dryRun) {
          console.log(`[ENGAGEMENT DRY-RUN] Would dispatch ${category} to ${client.name} (${profile.clientId})`);
          totalSent++;
          continue;
        }

        const { type, preferenceKey } = this.mapCategoryToPolicyFields(category);

        const dedupKeyToUse = force ? `${dedupKey}:${Date.now()}` : dedupKey;
        const dispatchRes = await notificationPolicyService.dispatch({
          userId: client.id,
          clientProfileId: profile.id,
          clientId: profile.clientId,
          title,
          message,
          type,
          category,
          priority: 'NORMAL',
          source: force ? 'ADMIN' : 'AI_COACH',
          triggerRule: `ENGAGEMENT_${category}`,
          tier: 'PROACTIVE',
          preferenceKey,
          dedupKey: dedupKeyToUse,
          ignoreQuietHours: force,
          ignoreRateLimit: force,
          data: {
            type: 'fitness_engagement',
            category,
            clientId: profile.clientId || '',
            date: dateStr,
          },
        });

        console.log(
          `[ENGAGEMENT LIVE] Dispatch ${category} to ${client.name} (${profile.clientId}) -> ${dispatchRes.status} ${
            dispatchRes.status === 'SENT' ? '✅' : '⚠️'
          }`
        );

        if (dispatchRes.status === 'SENT') {
          totalSent++;
        } else if (dispatchRes.status === 'DUPLICATE') {
          totalDuplicate++;
        } else {
          totalSkipped++;
        }
      }
    }

    console.log(
      `[ENGAGEMENT] Sweep complete: ${totalSent} sent, ${totalSkipped} skipped, ${totalDuplicate} duplicates (Dry-run: ${dryRun})`
    );

    return {
      category: specificCategory || 'ALL',
      evaluated: clients.length,
      sent: totalSent,
      skipped: totalSkipped,
      duplicate: totalDuplicate,
      dryRun,
      timestamp: new Date().toISOString(),
    };
  }

  private mapCategoryToPolicyFields(category: EngagementCategory): {
    type: 'WORKOUT' | 'NUTRITION' | 'CHECK_IN' | 'ACTIVITY' | 'SYSTEM';
    preferenceKey?: 'workoutReminders' | 'nutritionReminders' | 'weeklyCheckInReminders' | 'activityReminders' | 'aiEngagementEnabled';
  } {
    switch (category) {
      case 'HYDRATION':
        return { type: 'NUTRITION', preferenceKey: 'nutritionReminders' };
      case 'PROTEIN_GOAL':
        return { type: 'NUTRITION', preferenceKey: 'nutritionReminders' };
      case 'WORKOUT_MOTIVATION':
        return { type: 'WORKOUT', preferenceKey: 'workoutReminders' };
      case 'CONSISTENCY':
        return { type: 'WORKOUT', preferenceKey: 'workoutReminders' };
      case 'RECOVERY':
        return { type: 'WORKOUT', preferenceKey: 'workoutReminders' };
      case 'GOAL_CHECK_IN':
        return { type: 'CHECK_IN', preferenceKey: 'weeklyCheckInReminders' };
      default:
        return { type: 'WORKOUT', preferenceKey: 'aiEngagementEnabled' };
    }
  }
}

export const fitnessEngagementService = new FitnessEngagementService();
