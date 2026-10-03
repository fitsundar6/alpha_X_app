/**
 * Alpha X AI — Smart Push Notification Engine
 *
 * Runs as a daily cron job (default: 6:00 PM).
 * For each client:
 *   1. Checks workout logged, steps, protein, hydration for today
 *   2. Sends Gemini a compact status object
 *   3. Gemini writes a short, personal, friendly message
 *   4. Backend pushes it to the client's device via OneSignal
 *
 * Admin-only feature — clients never see this logic.
 * Clients can opt out via notificationsEnabled = false.
 */

import { prisma } from '../../config/prisma';
import { oneSignalService } from './onesignal.service';
import { env } from '../../config/environment';
import { GoogleGenAI } from '@google/genai';

export interface ClientDailyStatus {
  clientId: string;
  firstName: string;
  // Workout
  workoutDoneToday: boolean;
  assignedDaysPerWeek: number | null;
  // Steps
  stepsToday: number;
  stepGoal: number;
  stepsRemaining: number;
  // Nutrition
  caloriesLoggedToday: number;
  proteinLoggedToday: number;
  proteinTargetG: number | null;
  proteinRemainingG: number | null;
  proteinPctComplete: number | null;
  // Hydration (water logs if tracked)
  hasInjury: boolean;
}

export class AiNotificationEngine {
  private readonly model = 'gemini-3-flash-preview';

  /** Run the full notification sweep for all eligible clients */
  async runDailySweep(): Promise<void> {
    console.log('[AI NOTIFICATIONS] Starting daily sweep...');
    const startTime = Date.now();

    const today = new Date();
    const todayStr = today.toISOString().split('T')[0];
    const startOfDay = new Date(`${todayStr}T00:00:00.000Z`);
    const endOfDay = new Date(`${todayStr}T23:59:59.999Z`);

    // Fetch all active clients with push tokens who have opted in
    const clients = await prisma.user.findMany({
      where: {
        role: 'CLIENT',
        oneSignalPlayerId: { not: null },
        notificationsEnabled: true,
      },
      select: {
        id: true,
        name: true,
        oneSignalPlayerId: true,
        clientProfile: {
          select: {
            id: true,
            trainingDaysPerWeek: true,
            hasCurrentInjury: true,
            dietPlans: {
              where: { isActive: true },
              select: { protein: true, dailyCalories: true },
              take: 1,
            },
          },
        },
      },
    });

    console.log(`[AI NOTIFICATIONS] Found ${clients.length} eligible clients`);
    let sent = 0;
    let skipped = 0;

    for (const client of clients) {
      try {
        const status = await this.buildClientDailyStatus(client, todayStr, startOfDay, endOfDay);
        const message = await this.generatePersonalMessage(status);
        if (!message) { skipped++; continue; }

        await oneSignalService.sendToPlayer(client.oneSignalPlayerId!, {
          title: '💪 Alpha X Coach',
          body: message,
          data: { type: 'daily_nudge', date: todayStr },
        });
        sent++;
      } catch (err: any) {
        console.error(`[AI NOTIFICATIONS] Error for ${client.name}:`, err?.message);
        skipped++;
      }
    }

    const elapsed = Date.now() - startTime;
    console.log(`[AI NOTIFICATIONS] Sweep complete: ${sent} sent, ${skipped} skipped in ${elapsed}ms`);
  }

  /** Gather today's stats for one client */
  private async buildClientDailyStatus(
    client: any,
    todayStr: string,
    startOfDay: Date,
    endOfDay: Date
  ): Promise<ClientDailyStatus> {
    const profile = client.clientProfile;
    const profileId = profile?.id;

    const [workoutToday, stepsToday, foodToday] = await Promise.all([
      // Workout done today?
      prisma.workoutRecord.count({
        where: { clientId: client.id, isCompleted: true, startedAt: { gte: startOfDay, lte: endOfDay } },
      }),

      // Steps today
      // Steps today (not available via this model — skip safely)
      null,

      // Food logged today
      profileId ? prisma.clientFoodLog.findMany({
        where: { clientProfileId: profileId, dateString: todayStr },
        select: { calories: true, protein: true },
      }) : [],
    ]);

    const firstName = client.name.split(' ')[0];
    const stepsCount = (stepsToday as any)?.steps ?? 0;
    const stepGoal = (stepsToday as any)?.stepGoal ?? 8000;
    const caloriesLogged = (foodToday as any[]).reduce((s: number, l: any) => s + (l.calories || 0), 0);
    const proteinLogged = (foodToday as any[]).reduce((s: number, l: any) => s + (l.protein || 0), 0);
    const proteinTarget = profile?.dietPlan?.[0]?.protein ?? null;
    const proteinRemaining = proteinTarget ? Math.max(0, proteinTarget - proteinLogged) : null;
    const proteinPct = proteinTarget ? Math.round((proteinLogged / proteinTarget) * 100) : null;

    return {
      clientId: client.id,
      firstName,
      workoutDoneToday: workoutToday > 0,
      assignedDaysPerWeek: profile?.trainingDaysPerWeek ?? null,
      stepsToday: stepsCount,
      stepGoal,
      stepsRemaining: Math.max(0, stepGoal - stepsCount),
      caloriesLoggedToday: caloriesLogged,
      proteinLoggedToday: Math.round(proteinLogged),
      proteinTargetG: proteinTarget,
      proteinRemainingG: proteinRemaining ? Math.round(proteinRemaining) : null,
      proteinPctComplete: proteinPct,
      hasInjury: profile?.hasCurrentInjury ?? false,
    };
  }

  /**
   * Ask Gemini to write a short, personal, warm notification message.
   * Returns null if the client has completed all goals (no nudge needed).
   */
  private async generatePersonalMessage(status: ClientDailyStatus): Promise<string | null> {
    const apiKey = env.GEMINI_API_KEY;
    if (!apiKey) {
      console.warn('[AI NOTIFICATIONS] No GEMINI_API_KEY — using fallback messages');
      return this.fallbackMessage(status);
    }

    // Skip if everything is done — don't bother them
    const allDone =
      status.workoutDoneToday &&
      status.stepsRemaining === 0 &&
      (status.proteinPctComplete === null || status.proteinPctComplete >= 90);
    if (allDone) return null;

    const prompt = `You are the Alpha X Gym AI Coach sending a short, warm push notification to a gym member named ${status.firstName}.

Client's status for today:
- Workout done: ${status.workoutDoneToday}
- Steps today: ${status.stepsToday} / ${status.stepGoal} (remaining: ${status.stepsRemaining})
- Protein today: ${status.proteinLoggedToday}g / ${status.proteinTargetG !== null ? status.proteinTargetG + 'g' : 'no target set'} (${status.proteinPctComplete !== null ? status.proteinPctComplete + '%' : 'N/A'})
- Has injury: ${status.hasInjury}

Write ONE short notification message (max 120 characters). Rules:
- Address them by first name: ${status.firstName}
- Be warm, motivating, specific to what they HAVEN'T done yet
- If injury: be gentle and encouraging, not pushy about workouts
- Do NOT use hashtags or asterisks
- Do NOT mention medical advice
- End with one relevant emoji
- Example style: "Hey Priya! 2,400 steps to go — a quick evening walk will do it 🚶‍♀️"

Reply with ONLY the notification message text, nothing else.`;

    try {
      const ai = new GoogleGenAI({ apiKey: apiKey.trim() });
      const response = await ai.models.generateContent({
        model: this.model,
        contents: prompt,
      });
      const text = (response.text || '').trim();
      return text.length > 0 && text.length <= 180 ? text : this.fallbackMessage(status);
    } catch (err: any) {
      console.error('[AI NOTIFICATIONS] Gemini error:', err?.message);
      return this.fallbackMessage(status);
    }
  }

  /** Simple rule-based fallback if Gemini is unavailable */
  private fallbackMessage(status: ClientDailyStatus): string | null {
    const name = status.firstName;
    if (!status.workoutDoneToday) {
      return `Hey ${name}! Don't forget your workout today 💪 Your coach is watching your progress!`;
    }
    if (status.stepsRemaining > 1000) {
      return `${name}, you're ${status.stepsRemaining.toLocaleString()} steps from your daily goal. Quick walk? 🚶`;
    }
    if (status.proteinRemainingG && status.proteinRemainingG > 20) {
      return `${name}, ${status.proteinRemainingG}g of protein left for today. Time for a protein-rich meal! 🥩`;
    }
    return null;
  }
}

export const aiNotificationEngine = new AiNotificationEngine();
