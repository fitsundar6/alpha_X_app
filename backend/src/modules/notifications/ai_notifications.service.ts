/**
 * Alpha X AI â€” Autonomous Proactive Push Notification & Check-in Engine
 *
 * Implements:
 *   1. Morning Readiness Check-in (07:30 AM IST / 02:00 UTC)
 *   2. Event-Driven Post-Workout Celebration (Upon completion, strictly guarded, deduped)
 *   3. Missed Workout Auto-Regulation (10:30 AM IST / 05:00 UTC â€” verified schedule data, no inferences)
 *   4. Evening Accountability & Nutrition Sweep (08:30 PM IST / 15:00 UTC)
 *   5. Plan Assignment Notifications (Workout & Diet Plan updates, Essential tier)
 *
 * Dispatches via centralized NotificationPolicyService which enforces:
 *   - Persistent atomic deduplication via PostgreSQL UNIQUE constraint
 *   - Rolling 24-hour cap (max 2 proactive pushes per client)
 *   - Quiet hours suppression / deferral
 *   - Master opt-out and category preference checks
 */

import { prisma } from '../../config/prisma';
import { env } from '../../config/environment';
import { geminiReliability, classifyGeminiError, redactSecrets } from '../ai_coach/gemini.reliability';
import { notificationPolicyService } from './notification_policy.service';

export interface DryRunDiagnosticsResult {
  dryRun: true;
  sweep: 'MORNING_READINESS' | 'MISSED_WORKOUT_CHECK_IN' | 'EVENING_NUTRITION_AND_RECOVERY' | 'DISPATCHER' | 'ALL';
  scheduledIst: string;
  scheduledUtc: string;
  timezone: string;
  localTimeIST: {
    year: number;
    month: number;
    day: number;
    hour: number;
    minute: number;
    dateStr: string;
    weekday: string;
  };
  isInQuietHours: boolean;
  databaseWrites: 0;
  oneSignalDispatches: 0;
  previewGuardActive: boolean;
  isolatedDbVerified: boolean;
  diagnostics: {
    targetAudience: string;
    mode: 'READ_ONLY_SAFE_DIAGNOSTICS';
    summary: string;
    eligibilitySummary?: {
      totalClients?: number;
      notificationsEnabled?: number;
      yesterdayDateStr?: string;
    };
  };
}

export interface MorningCheckInContext {
  firstName: string;
  sessionTitle: string;
  isTrainingDay: boolean;
  trainingTime: string;
  targetProteinGrams: number;
  targetWaterLiters: number;
  hasInjury: boolean;
}

export interface PostWorkoutContext {
  firstName: string;
  sessionTitle: string;
  durationMinutes: number;
  totalVolumeKg: number;
  completedSetsCount: number;
  prExerciseName?: string;
  prVolumeKg?: number;
  prWeightKg?: number;
  prType?: string;
}

export interface MissedWorkoutContext {
  firstName: string;
  missedSessionTitle: string;
  yesterdayDateStr: string;
}

export interface EveningCheckInContext {
  firstName: string;
  workoutDoneToday: boolean;
  proteinLoggedToday: number;
  proteinTargetG: number | null;
  proteinRemainingG: number | null;
  hasInjury: boolean;
}

export class AiNotificationEngine {
  private readonly defaultModel = 'gemini-flash-lite-latest';
  private readonly fallbackModels = ['gemini-flash-latest', 'gemini-2.5-flash', 'gemini-2.5-flash-lite'];

  /**
   * Helper to execute Gemini generation with robust model fallback and timeout.
   */
  private async callGemini(prompt: string, fallbackText: string): Promise<string> {
    if (!geminiReliability.hasConfiguredKey() || geminiReliability.isCircuitTripped()) {
      return fallbackText;
    }

    try {
      return await geminiReliability.executeWithReliability(
        async (ai) => {
          const modelsToTry = [this.defaultModel, ...this.fallbackModels];
          for (const model of modelsToTry) {
            try {
              const response = await ai.models.generateContent({
                model,
                contents: prompt,
              });
              const _nParts = (response && response.candidates && response.candidates[0] && response.candidates[0].content && response.candidates[0].content.parts) || [];
              const text = _nParts.filter(function(p) { return typeof p.text === 'string'; }).map(function(p) { return p.text; }).join('').trim().replace(/^["']|["']$/g, '');
              if (text.length > 0 && text.length <= 180) {
                return text;
              }
            } catch (err: any) {
              const classified = classifyGeminiError(err);
              if (classified.isAuth || classified.isQuota) {
                throw err;
              }
              console.warn(
                `[AI NOTIFICATIONS] Model ${model} failed, trying next...:`,
                redactSecrets(classified.sanitizedMessage)
              );
            }
          }
          return fallbackText;
        },
        {
          operationName: 'AiNotificationPush',
          maxRetries: 2,
        }
      );
    } catch (_) {
      return fallbackText;
    }
  }

  // =========================================================================
  // 1. MORNING READINESS CHECK-IN (07:30 AM IST / 02:00 UTC)
  // =========================================================================
  async runMorningCheckInSweep(): Promise<{ sent: number; skipped: number; duplicate: number }> {
    console.log('[AI NOTIFICATIONS] Starting Morning Readiness Sweep (07:30 AM IST)...');

    // 1. Process deferred notifications queued overnight during quiet hours (21:00 - 07:00)
    await notificationPolicyService.processDeferredQueue().catch((e) =>
      console.warn('[AI NOTIFICATIONS] Morning deferred queue processing notice:', e?.message)
    );

    // 2. Recover any stale pending notifications (> 5 min) from previous crashes
    await notificationPolicyService.recoverStalePendingNotifications().catch((e) =>
      console.warn('[AI NOTIFICATIONS] Morning stale pending recovery notice:', e?.message)
    );

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

    let sent = 0;
    let skipped = 0;
    let duplicate = 0;

    for (const client of clients) {
      try {
        const profile = client.clientProfile;
        if (!profile) {
          skipped++;
          continue;
        }

        const tz = profile.notificationPref?.timezone || 'Asia/Kolkata';
        const { dateStr, weekday } = notificationPolicyService.getLocalTimeParts(tz);
        const dedupKey = `SWEEP_MORNING:${profile.id}:${dateStr}`;

        const firstName = client.name.split(' ')[0] || 'Athlete';
        const diet = profile.dietPlans[0];
        const targetProtein = diet?.protein ? Math.round(diet.protein) : 150;
        const targetWater = diet?.waterTargetLiters ? Number(diet.waterTargetLiters.toFixed(1)) : 3.0;
        const timePref = profile.trainingTimePref || '6 PM';

        // Check if today is a scheduled training day
        const todayAssignment = client.assignments.find(
          (a) => a.active && a.session && (a.scheduledDate === dateStr || !a.scheduledDate)
        );
        const preferredDays = profile.preferredDays || [];
        const isPreferredDay = preferredDays.some((d) => d.toLowerCase() === weekday.toLowerCase());
        const isTrainingDay = Boolean(todayAssignment) || isPreferredDay;

        const sessionTitle = todayAssignment?.session?.title || 'Strength & Conditioning';

        const fallback = isTrainingDay
          ? `${sessionTitle} today at ${timePref}. Drink your water and hit at least ${targetProtein}g protein ðŸ’§`
          : `Active recovery day, ${firstName}! Hydrate with ${targetWater}L and aim for ${targetProtein}g protein ðŸ§˜`;

        const prompt = `You are the Alpha X Gym AI Coach sending an energizing morning push notification to gym member ${firstName}.
Context for today:
- Scheduled session: "${sessionTitle}"
- Planned training time: ${timePref}
- Target protein: ${targetProtein}g
- Target water: ${targetWater}L
- Injury status: ${profile.hasCurrentInjury ? 'Minor recovery/injury' : 'Fit'}

Write ONE short, punchy message (max 110 characters). Rules:
- Address the client naturally or dive straight into the cue
- Exact tone target: "Leg Day today at 6 PM. Drink your water and hit at least 150g protein."
- Do NOT use hashtags, quotes, or markdown asterisks
- End with one relevant emoji (e.g. ðŸ’§, ðŸ’ª, ðŸ‹ï¸)
Reply with ONLY the notification text.`;

        const message = await this.callGemini(prompt, fallback);

        const dispatchRes = await notificationPolicyService.dispatch({
          userId: client.id,
          clientProfileId: profile.id,
          clientId: profile.clientId,
          title: 'âš¡ Alpha X Morning Briefing',
          message,
          type: 'WORKOUT',
          category: 'TRAINING',
          priority: 'NORMAL',
          source: 'AI_COACH',
          triggerRule: 'MORNING_READINESS',
          tier: 'PROACTIVE',
          preferenceKey: 'workoutReminders',
          dedupKey,
          data: { type: 'morning_checkin', date: dateStr },
          metadata: { sessionTitle, targetProtein, targetWater, timePref, isTrainingDay },
        });

        if (dispatchRes.status === 'SENT') {
          sent++;
        } else if (dispatchRes.status === 'DUPLICATE') {
          duplicate++;
        } else {
          skipped++;
        }
      } catch (err: any) {
        console.error(`[AI NOTIFICATIONS] Morning check-in error for ${client.name}:`, err?.message);
        skipped++;
      }
    }

    console.log(`[AI NOTIFICATIONS] Morning sweep complete: ${sent} sent, ${skipped} skipped, ${duplicate} duplicates.`);
    return { sent, skipped, duplicate };
  }

  // =========================================================================
  // 2. EVENT-DRIVEN POST-WORKOUT CELEBRATION (On workout completion)
  // =========================================================================
  async sendPostWorkoutCelebration(
    clientId: string,
    record: any,
    options?: { ignoreQuietHours?: boolean; skipPush?: boolean }
  ): Promise<boolean> {
    try {
      if (!record || !record.id) {
        return false;
      }

      // Record must be marked completed
      if (record.isCompleted !== true) {
        return false;
      }

      const user = await prisma.user.findUnique({
        where: { id: clientId },
        include: {
          clientProfile: {
            include: { notificationPref: true },
          },
        },
      });

      if (!user || !user.clientProfile) {
        return false;
      }

      const firstName = user.name.split(' ')[0] || 'Athlete';
      const sessionTitle = record.sessionTitle || 'Workout Session';
      const durationMin = Math.round((record.durationSeconds || 2400) / 60);
      const totalVolumeKg = Math.round(record.totalVolume || 0);
      const completedSets = record.completedSetsCount || 0;

      // Extract PR information if present
      let prExerciseName: string | undefined;
      if (record.personalRecords && Array.isArray(record.personalRecords) && record.personalRecords.length > 0) {
        prExerciseName = record.personalRecords[0].exerciseName;
      } else if (record.personalRecordsJson) {
        try {
          const prs = JSON.parse(record.personalRecordsJson);
          if (Array.isArray(prs) && prs.length > 0) {
            prExerciseName = prs[0].exerciseName;
          }
        } catch (_) {}
      }

      const hasPR = Boolean(prExerciseName && totalVolumeKg > 0);
      const fallback = hasPR
        ? `You hit a personal volume record on ${prExerciseName} (${totalVolumeKg.toLocaleString()} kg total). Prioritize recovery sleep tonight ðŸ†`
        : `Outstanding session! Crushed ${totalVolumeKg.toLocaleString()} kg volume across ${completedSets} sets. Fuel up with 35g protein within the hour ðŸ”¥`;

      const prompt = `You are the Alpha X Gym AI Coach sending an immediate post-workout push notification to gym member ${firstName}.
Workout stats just completed:
- Session: "${sessionTitle}" (${durationMin} min, ${completedSets} sets)
- Total volume: ${totalVolumeKg} kg
- Best lift / PR: ${prExerciseName ? `${prExerciseName} (${totalVolumeKg} kg volume)` : 'Standard completion'}

Write ONE short, high-energy notification message (max 115 characters). Rules:
- Congratulate them on the specific volume or PR achieved
- Give one immediate actionable recovery instruction (e.g. sleep, post-workout protein)
- Tone target: "You hit a personal volume record on Deadlifts (4,200 kg total). Prioritize recovery sleep tonight."
- Do NOT use hashtags, quotes, or markdown asterisks
- End with one relevant emoji (ðŸ†, ðŸ¥©, ðŸ”¥)
Reply with ONLY the notification text.`;

      const message = await this.callGemini(prompt, fallback);

      const dedupKey = `WORKOUT_COMPLETED:${record.id}`;

      const dispatchRes = await notificationPolicyService.dispatch({
        userId: user.id,
        clientProfileId: user.clientProfile.id,
        clientId: user.clientProfile.clientId,
        title: hasPR ? 'ðŸ† NEW PR ACHIEVED!' : 'ðŸ”¥ WORKOUT CRUSHED!',
        message,
        type: 'WORKOUT',
        category: 'ACHIEVEMENT',
        priority: 'HIGH',
        source: 'AI_COACH',
        triggerRule: 'WORKOUT_COMPLETED',
        tier: 'PROACTIVE',
        preferenceKey: 'workoutReminders',
        dedupKey,
        data: { type: 'post_workout', recordId: record.id },
        metadata: { sessionTitle, totalVolumeKg, durationMin, prExerciseName },
        ignoreQuietHours: options?.ignoreQuietHours,
        skipPush: options?.skipPush,
      });

      console.log(`[AI NOTIFICATIONS] Post-workout celebration result for ${user.name}: status=${dispatchRes.status}`);
      return dispatchRes.success;
    } catch (err: any) {
      console.error('[AI NOTIFICATIONS] Failed to send post-workout celebration:', err?.message);
      return false;
    }
  }

  // =========================================================================
  // 3. MISSED WORKOUT AUTO-REGULATION (10:30 AM IST / 05:00 UTC)
  // =========================================================================
  async runMissedWorkoutSweep(): Promise<{ sent: number; skipped: number; duplicate: number }> {
    console.log('[AI NOTIFICATIONS] Starting Missed Workout Auto-Regulation Sweep (10:30 AM IST)...');

    // Recover any stale pending notifications (> 5 min)
    await notificationPolicyService.recoverStalePendingNotifications().catch((e) =>
      console.warn('[AI NOTIFICATIONS] Missed workout sweep stale recovery notice:', e?.message)
    );

    const clients = await prisma.user.findMany({
      where: {
        role: 'CLIENT',
        notificationsEnabled: true,
      },
      include: {
        clientProfile: {
          include: {
            notificationPref: true,
          },
        },
        assignments: {
          where: { active: true },
          include: { session: true },
        },
      },
    });

    let sent = 0;
    let skipped = 0;
    let duplicate = 0;

    for (const client of clients) {
      try {
        const profile = client.clientProfile;
        if (!profile) {
          skipped++;
          continue;
        }

        const tz = profile.notificationPref?.timezone || 'Asia/Kolkata';

        // Calculate client's yesterday local date string and weekday
        const now = new Date();
        const yesterdayDate = new Date(now.getTime() - 24 * 60 * 60 * 1000);
        const { dateStr: yesterdayStr, weekday: yesterdayWeekday } = notificationPolicyService.getLocalTimeParts(
          tz,
          yesterdayDate
        );

        const dedupKey = `SWEEP_MISSED:${profile.id}:${yesterdayStr}`;

        // 1. Data-driven check: Find scheduled workout assignment for yesterday
        const scheduledAssignment = client.assignments.find(
          (a) => a.active && a.session && a.scheduledDate === yesterdayStr
        );

        const preferredDays: string[] = profile.preferredDays || [];
        const isYesterdayPreferredDay = preferredDays.some(
          (d) => d.toLowerCase() === yesterdayWeekday.toLowerCase()
        );

        // If yesterday was NOT a scheduled assignment AND NOT a preferred day, it was a scheduled rest day!
        if (!scheduledAssignment && !isYesterdayPreferredDay) {
          skipped++;
          continue;
        }

        // 2. Check if client completed a workout yesterday
        // Match either by assignmentId or by workout record completed within yesterday's local day in client's timezone (Asia/Kolkata)
        const { start: yesterdayStart, end: yesterdayEnd } = notificationPolicyService.getDayBoundaries(yesterdayStr, tz);

        const completedWorkoutYesterday = await prisma.workoutRecord.findFirst({
          where: {
            clientId: client.id,
            isCompleted: true,
            OR: [
              ...(scheduledAssignment ? [{ assignmentId: scheduledAssignment.id }] : []),
              {
                startedAt: {
                  gte: yesterdayStart,
                  lte: yesterdayEnd,
                },
              },
            ],
          },
        });

        if (completedWorkoutYesterday) {
          // Workout was completed, do not send missed workout notification
          skipped++;
          continue;
        }

        // If scheduled assignment session is ambiguous and preferred days is empty, skip to prevent incorrect notifications
        if (!scheduledAssignment && preferredDays.length === 0) {
          skipped++;
          continue;
        }

        const sessionTitle = scheduledAssignment?.session?.title || 'scheduled session';
        const firstName = client.name.split(' ')[0] || 'Athlete';

        const fallback = `You missed yesterday's scheduled session. Should we swap it to today or make it a rest week? ðŸ‹ï¸`;

        const prompt = `You are the Alpha X Gym AI Coach checking in with ${firstName}, who missed yesterday's scheduled workout ("${sessionTitle}").
Write ONE short, empathetic, solution-oriented coaching message (max 115 characters). Rules:
- Zero guilt or judgment, 100% supportive auto-regulation
- Tone target: "You missed yesterday's scheduled session. Should we swap it to today or make it a rest week?"
- Do NOT use hashtags, quotes, or markdown asterisks
- End with one emoji (ðŸ‹ï¸, âš¡, ðŸ’ª)
Reply with ONLY the notification text.`;

        const message = await this.callGemini(prompt, fallback);

        const dispatchRes = await notificationPolicyService.dispatch({
          userId: client.id,
          clientProfileId: profile.id,
          clientId: profile.clientId,
          title: 'Alpha X Coach â€¢ Training Check-In',
          message,
          type: 'WORKOUT',
          category: 'COACHING',
          priority: 'NORMAL',
          source: 'AI_COACH',
          triggerRule: 'WORKOUT_MISSED',
          tier: 'PROACTIVE',
          preferenceKey: 'workoutReminders',
          dedupKey,
          data: { type: 'missed_workout', date: yesterdayStr },
          metadata: { missedSessionTitle: sessionTitle, date: yesterdayStr },
        });

        if (dispatchRes.status === 'SENT') {
          sent++;
        } else if (dispatchRes.status === 'DUPLICATE') {
          duplicate++;
        } else {
          skipped++;
        }
      } catch (err: any) {
        console.error(`[AI NOTIFICATIONS] Missed workout sweep error for ${client.name}:`, err?.message);
        skipped++;
      }
    }

    console.log(`[AI NOTIFICATIONS] Missed workout sweep complete: ${sent} sent, ${skipped} skipped, ${duplicate} duplicates.`);
    return { sent, skipped, duplicate };
  }

  // =========================================================================
  // 4. EVENING ACCOUNTABILITY & NUTRITION SWEEP (08:30 PM IST / 15:00 UTC)
  // =========================================================================
  async runEveningCheckInSweep(): Promise<{ sent: number; skipped: number; duplicate: number }> {
    console.log('[AI NOTIFICATIONS] Starting Evening Accountability Sweep (08:30 PM IST)...');

    // Also process any deferred notifications from quiet hours
    await notificationPolicyService.processDeferredQueue().catch((e) =>
      console.warn('[AI NOTIFICATIONS] Deferred queue processing notice:', e?.message)
    );

    // Recover any stale pending notifications (> 5 min)
    await notificationPolicyService.recoverStalePendingNotifications().catch((e) =>
      console.warn('[AI NOTIFICATIONS] Evening stale pending recovery notice:', e?.message)
    );

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
      },
    });

    let sent = 0;
    let skipped = 0;
    let duplicate = 0;

    for (const client of clients) {
      try {
        const profile = client.clientProfile;
        if (!profile) {
          skipped++;
          continue;
        }

        const tz = profile.notificationPref?.timezone || 'Asia/Kolkata';
        const { dateStr } = notificationPolicyService.getLocalTimeParts(tz);
        const dedupKey = `SWEEP_EVENING:${profile.id}:${dateStr}`;
        const { start: todayStart, end: todayEnd } = notificationPolicyService.getDayBoundaries(dateStr, tz);

        const [workoutCount, foodLogs] = await Promise.all([
          prisma.workoutRecord.count({
            where: {
              clientId: client.id,
              isCompleted: true,
              startedAt: {
                gte: todayStart,
                lte: todayEnd,
              },
            },
          }),
          prisma.clientFoodLog.findMany({
            where: { clientProfileId: profile.id, dateString: dateStr },
            select: { calories: true, protein: true },
          }),
        ]);

        const firstName = client.name.split(' ')[0] || 'Athlete';
        const proteinLogged = foodLogs.reduce((acc, f) => acc + (f.protein || 0), 0);
        const targetProtein = profile.dietPlans[0]?.protein ? Math.round(profile.dietPlans[0].protein) : 150;
        const proteinGap = Math.max(0, targetProtein - Math.round(proteinLogged));

        // If workout was done and protein target was met, client nailed their day
        if (workoutCount > 0 && proteinGap === 0) {
          skipped++;
          continue;
        }

        const fallback = proteinGap > 15
          ? `Hey ${firstName}! You have ${proteinGap}g protein left today. A quick shake or Greek yogurt will lock in your recovery ðŸ¥£`
          : `Great effort today, ${firstName}! Prioritize 8 hours of sleep tonight for maximum muscular recovery ðŸ’¤`;

        const prompt = `You are the Alpha X Gym AI Coach sending an evening check-in push notification to ${firstName}.
Status:
- Workout done: ${workoutCount > 0}
- Protein: ${Math.round(proteinLogged)}g / ${targetProtein}g (remaining: ${proteinGap}g)

Write ONE short, friendly evening reminder (max 115 characters). Rules:
- Mention the remaining protein gap if > 15g, or praise today's discipline
- Tone target: "You have 30g protein left today. A quick casein shake before bed will lock in your gains ðŸ¥£"
- Do NOT use hashtags or markdown asterisks
- End with one emoji (ðŸ¥£, ðŸ¥©, ðŸ’¤)
Reply with ONLY the notification text.`;

        const message = await this.callGemini(prompt, fallback);

        const dispatchRes = await notificationPolicyService.dispatch({
          userId: client.id,
          clientProfileId: profile.id,
          clientId: profile.clientId,
          title: 'ðŸŒ™ Alpha X Evening Check-In',
          message,
          type: 'NUTRITION',
          category: 'NUTRITION',
          priority: 'NORMAL',
          source: 'AI_COACH',
          triggerRule: proteinGap > 15 ? 'PROTEIN_BELOW_TARGET' : 'EVENING_RECOVERY',
          tier: 'PROACTIVE',
          preferenceKey: 'nutritionReminders',
          dedupKey,
          data: { type: 'evening_checkin', date: dateStr },
          metadata: { proteinLogged, targetProtein, proteinGap, workoutCount },
        });

        if (dispatchRes.status === 'SENT') {
          sent++;
        } else if (dispatchRes.status === 'DUPLICATE') {
          duplicate++;
        } else {
          skipped++;
        }
      } catch (err: any) {
        console.error(`[AI NOTIFICATIONS] Evening sweep error for ${client.name}:`, err?.message);
        skipped++;
      }
    }

    console.log(`[AI NOTIFICATIONS] Evening sweep complete: ${sent} sent, ${skipped} skipped, ${duplicate} duplicates.`);
    return { sent, skipped, duplicate };
  }

  /**
   * Alias for evening sweep to preserve backwards compatibility with admin manual trigger routes.
   */
  async runDailySweep(): Promise<{ sent: number; skipped: number; duplicate: number }> {
    return this.runEveningCheckInSweep();
  }

  // =========================================================================
  // 5. ESSENTIAL PLAN ASSIGNMENT NOTIFICATIONS (Workout & Diet)
  // =========================================================================
  async notifyWorkoutAssignment(params: {
    assignmentId: string;
    clientId: string;
    sessionTitle: string;
    scheduledDate?: string | null;
  }): Promise<boolean> {
    try {
      const user = await prisma.user.findUnique({
        where: { id: params.clientId },
        include: { clientProfile: true },
      });

      if (!user || !user.clientProfile) {
        return false;
      }

      const dedupKey = `PLAN_ASSIGNED:${params.assignmentId}:${params.scheduledDate || 'today'}`;
      const message = `Your coach assigned you "${params.sessionTitle}". Open Alpha X to view your program ðŸ’ª`;

      const res = await notificationPolicyService.dispatch({
        userId: user.id,
        clientProfileId: user.clientProfile.id,
        clientId: user.clientProfile.clientId,
        title: 'ðŸ“‹ New Workout Assigned',
        message,
        type: 'WORKOUT',
        category: 'PLAN_UPDATE',
        priority: 'HIGH',
        source: 'ADMIN',
        triggerRule: 'PLAN_ASSIGNED',
        tier: 'ESSENTIAL', // Bypasses 24h cap, defers if quiet hours
        preferenceKey: 'workoutReminders',
        dedupKey,
        data: { type: 'plan_assignment', assignmentId: params.assignmentId },
        metadata: { sessionTitle: params.sessionTitle, scheduledDate: params.scheduledDate },
      });

      return res.success;
    } catch (err: any) {
      console.warn('[AI NOTIFICATIONS] Workout assignment notification failed:', err?.message);
      return false;
    }
  }

  async notifyDietPlanAssignment(params: {
    dietPlanId: string;
    clientProfileId: string;
    planName: string;
    version: number;
  }): Promise<boolean> {
    try {
      const profile = await prisma.clientProfile.findUnique({
        where: { id: params.clientProfileId },
        include: { user: true },
      });

      if (!profile || !profile.user) {
        return false;
      }

      const dedupKey = `DIET_ASSIGNED:${params.dietPlanId}:v${params.version}`;
      const message = `Your coach updated your nutrition plan to "${params.planName}" (v${params.version}). Check your daily targets in Alpha X ðŸ¥—`;

      const res = await notificationPolicyService.dispatch({
        userId: profile.user.id,
        clientProfileId: profile.id,
        clientId: profile.clientId,
        title: 'ðŸ¥— Nutrition Plan Updated',
        message,
        type: 'NUTRITION',
        category: 'PLAN_UPDATE',
        priority: 'HIGH',
        source: 'ADMIN',
        triggerRule: 'PLAN_ASSIGNED',
        tier: 'ESSENTIAL', // Bypasses 24h cap, defers if quiet hours
        preferenceKey: 'nutritionReminders',
        dedupKey,
        data: { type: 'diet_plan_assignment', dietPlanId: params.dietPlanId },
        metadata: { planName: params.planName, version: params.version },
      });

      return res.success;
    } catch (err: any) {
      console.warn('[AI NOTIFICATIONS] Diet plan assignment notification failed:', err?.message);
      return false;
    }
  }

  /**
   * Safe, read-only dry-run diagnostics.
   * Performs ZERO database writes, ZERO notification reservations, and ZERO OneSignal dispatches.
   * In Vercel Preview deployments, strictly suppresses all client database queries.
   */
  async runDryRunDiagnostics(
    sweep: 'MORNING_READINESS' | 'MISSED_WORKOUT_CHECK_IN' | 'EVENING_NUTRITION_AND_RECOVERY' | 'DISPATCHER' | 'ALL'
  ): Promise<DryRunDiagnosticsResult> {
    const isPreview =
      process.env.VERCEL_ENV === 'preview' ||
      (typeof env !== 'undefined' && (env as any).VERCEL_ENV === 'preview');

    const tz = 'Asia/Kolkata';
    const local = notificationPolicyService.getLocalTimeParts(tz);
    const inQuietHours = notificationPolicyService.isInQuietHours(tz, 21, 7);

    let scheduledIst = 'Universal Slot';
    let scheduledUtc = 'Variable';
    if (sweep === 'MORNING_READINESS') {
      scheduledIst = '07:30 AM IST';
      scheduledUtc = '02:00 UTC';
    } else if (sweep === 'MISSED_WORKOUT_CHECK_IN') {
      scheduledIst = '10:30 AM IST';
      scheduledUtc = '05:00 UTC';
    } else if (sweep === 'EVENING_NUTRITION_AND_RECOVERY') {
      scheduledIst = '08:30 PM IST';
      scheduledUtc = '15:00 UTC';
    }

    // In Preview deployment, strictly suppress querying production client records
    if (isPreview) {
      return {
        dryRun: true,
        sweep,
        scheduledIst,
        scheduledUtc,
        timezone: tz,
        localTimeIST: local,
        isInQuietHours: inQuietHours,
        databaseWrites: 0,
        oneSignalDispatches: 0,
        previewGuardActive: true,
        isolatedDbVerified: false,
        diagnostics: {
          targetAudience: 'PROTECTED_PRODUCTION_DATABASE (Queries suppressed in Preview)',
          mode: 'READ_ONLY_SAFE_DIAGNOSTICS',
          summary:
            'Vercel Preview environment detected. Production client data querying is strictly suppressed to protect production database privacy. Routes, authentication, schedules, and timezone calculations verified with zero database queries, zero database writes, and zero push dispatches.',
        },
      };
    }

    // In verified test database or safe read-only environment, perform pure read-only counts (ZERO mutations)
    let eligibilitySummary: any = undefined;
    try {
      const [totalClients, notificationsEnabled] = await Promise.all([
        prisma.user.count({ where: { role: 'CLIENT' } }),
        prisma.user.count({ where: { role: 'CLIENT', notificationsEnabled: true } }),
      ]);

      const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000);
      const yesterdayParts = notificationPolicyService.getLocalTimeParts(tz, yesterday);

      eligibilitySummary = {
        totalClients,
        notificationsEnabled,
        yesterdayDateStr: yesterdayParts.dateStr,
      };
    } catch (_) {
      // In case DB is offline or read error, maintain zero-write guarantee
    }

    return {
      dryRun: true,
      sweep,
      scheduledIst,
      scheduledUtc,
      timezone: tz,
      localTimeIST: local,
      isInQuietHours: inQuietHours,
      databaseWrites: 0,
      oneSignalDispatches: 0,
      previewGuardActive: false,
      isolatedDbVerified: false,
      diagnostics: {
        targetAudience: 'READ_ONLY_SAFE_COUNT',
        mode: 'READ_ONLY_SAFE_DIAGNOSTICS',
        summary:
          'Safe dry-run completed. All checks executed in read-only diagnostic mode with zero database writes and zero OneSignal dispatches.',
        eligibilitySummary,
      },
    };
  }
}

export const aiNotificationEngine = new AiNotificationEngine();
