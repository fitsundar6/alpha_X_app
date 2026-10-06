/**
 * Alpha X — Weekly Telemetry Intelligence Engine ("Spotify-Wrapped for Lifting")
 *
 * Computes deep, visual weekly lifting telemetry:
 *  - 3D Muscle Group Heatmap (Sets, Volume, Stimulation Status)
 *  - Total Iron Tonnage with Real-World Physical Comparisons (e.g. 26 Ford F-150s)
 *  - PR Trophy Shelf & Consistency / Adherence Index
 *  - AI Coach Telemetry Review (Gemini LLM)
 *  - Gym-Wide Admin Aggregation & Leaderboard
 */

import { prisma } from '../../config/prisma';
import { env } from '../../config/environment';
import { oneSignalService } from '../notifications/onesignal.service';
import { GoogleGenAI } from '@google/genai';
import {
  WeeklyTelemetryReport,
  MuscleGroupTelemetry,
  PRHighlight,
  PhysicalComparison,
  AdminTelemetryOverview,
  AdminTelemetryClientSummary,
} from './telemetry.types';

export class TelemetryService {
  private readonly defaultModel = 'gemini-flash-lite-latest';
  private readonly fallbackModels = ['gemini-flash-latest', 'gemini-3.8-flash', 'gemini-3.5-flash'];

  /**
   * Calculate a memorable real-world physical comparison for iron volume moved.
   */
  public calculatePhysicalComparison(volumeKg: number): PhysicalComparison {
    const volume = Math.round(volumeKg);

    if (volume < 3000) {
      const bikes = Math.max(1, Math.round(volume / 330));
      return {
        tonnageKg: volume,
        equivalentLabel: `${bikes} Harley-Davidson Fat Boys`,
        itemCount: bikes,
        itemIcon: '🏍️',
        description: `You moved ${volume.toLocaleString()} kg this week — equivalent to ${bikes} heavy Harley-Davidson cruisers!`,
      };
    } else if (volume < 8000) {
      const elephants = Math.max(1, Math.round(volume / 5000));
      return {
        tonnageKg: volume,
        equivalentLabel: `${elephants} African Elephants`,
        itemCount: elephants,
        itemIcon: '🐘',
        description: `You hoisted ${volume.toLocaleString()} kg — equivalent to lifting ${elephants} full-grown African bull elephant${elephants > 1 ? 's' : ''}!`,
      };
    } else if (volume < 18000) {
      const cars = Math.max(1, Math.round(volume / 1850));
      return {
        tonnageKg: volume,
        equivalentLabel: `${cars} Tesla Model 3s`,
        itemCount: cars,
        itemIcon: '🚗',
        description: `You moved ${volume.toLocaleString()} kg of iron — equivalent to benching ${cars} Tesla Model 3s!`,
      };
    } else if (volume < 35000) {
      const dinos = Math.max(1, Math.round(volume / 2500));
      return {
        tonnageKg: volume,
        equivalentLabel: `${dinos} T-Rex Dinosaurs`,
        itemCount: dinos,
        itemIcon: '🦖',
        description: `You moved ${volume.toLocaleString()} kg — equivalent to deadlifting ${dinos} Cretaceous T-Rex apex predators!`,
      };
    } else if (volume < 65000) {
      const trucks = Math.max(1, Math.round(volume / 1850));
      return {
        tonnageKg: volume,
        equivalentLabel: `${trucks} Ford F-150 Trucks`,
        itemCount: trucks,
        itemIcon: '🛻',
        description: `You crushed ${volume.toLocaleString()} kg of volume — equivalent to hoisting ${trucks} Ford F-150 SuperDuty trucks!`,
      };
    } else if (volume < 120000) {
      const jets = Math.max(1, Math.round(volume / 41000));
      return {
        tonnageKg: volume,
        equivalentLabel: `${jets} Boeing 737 Airplane${jets > 1 ? 's' : ''}`,
        itemCount: jets,
        itemIcon: '✈️',
        description: `Staggering output! You lifted ${volume.toLocaleString()} kg — equivalent to ${jets} Boeing 737 commercial jetliner${jets > 1 ? 's' : ''}!`,
      };
    } else {
      const boosters = Math.max(1, Math.round(volume / 85000));
      return {
        tonnageKg: volume,
        equivalentLabel: `${boosters} NASA Rocket Boosters`,
        itemCount: boosters,
        itemIcon: '🚀',
        description: `Legendary iron tonnage! You moved ${volume.toLocaleString()} kg — equivalent to ${boosters} Space Shuttle solid rocket booster${boosters > 1 ? 's' : ''}!`,
      };
    }
  }

  /**
   * Helper to categorize exercises into one of 6 primary muscle groups.
   */
  private classifyMuscleGroup(exerciseName: string): 'CHEST' | 'BACK' | 'LEGS' | 'SHOULDERS' | 'ARMS' | 'CORE' {
    const name = exerciseName.toLowerCase();

    // Chest
    if (name.includes('bench') || name.includes('chest') || name.includes('incline press') || name.includes('push-up') || name.includes('pec')) {
      return 'CHEST';
    }
    // Back
    if (name.includes('deadlift') || name.includes('row') || name.includes('lat') || name.includes('pull-up') || name.includes('chin-up') || name.includes('back')) {
      return 'BACK';
    }
    // Legs
    if (name.includes('squat') || name.includes('leg') || name.includes('lunge') || name.includes('calf') || name.includes('quad') || name.includes('hamstring') || name.includes('glute')) {
      return 'LEGS';
    }
    // Shoulders
    if (name.includes('shoulder') || name.includes('overhead press') || name.includes('military') || name.includes('lateral raise') || name.includes('delt') || name.includes('arnold')) {
      return 'SHOULDERS';
    }
    // Arms
    if (name.includes('bicep') || name.includes('curl') || name.includes('tricep') || name.includes('skull') || name.includes('dip') || name.includes('pushdown')) {
      return 'ARMS';
    }
    // Core
    if (name.includes('abs') || name.includes('plank') || name.includes('crunch') || name.includes('core')) {
      return 'CORE';
    }

    return 'CHEST';
  }

  /**
   * Determine hypertrophy stimulation status from weekly working sets.
   */
  private getStimulationStatus(sets: number): {
    status: 'UNDERSTIMULATED' | 'OPTIMAL' | 'HIGH_VOLUME' | 'DELOAD_RECOMMENDED';
    color: string;
  } {
    if (sets < 6) {
      return { status: 'UNDERSTIMULATED', color: '#718096' };
    }
    if (sets <= 18) {
      return { status: 'OPTIMAL', color: '#00FF87' }; // Neon Green
    }
    if (sets <= 26) {
      return { status: 'HIGH_VOLUME', color: '#00D2FF' }; // Electric Blue
    }
    return { status: 'DELOAD_RECOMMENDED', color: '#FF5722' }; // Vivid Orange
  }

  /**
   * Helper to execute Gemini generation with fallback.
   */
  private async generateAiCommentary(prompt: string, fallback: string): Promise<string> {
    const rawApiKey = env.GEMINI_API_KEY || process.env.GEMINI_API_KEY;
    const apiKey = (rawApiKey || '')
      .trim()
      .replace(/^["']|["']$/g, '')
      .trim();
    if (!apiKey) return fallback;

    const ai = new GoogleGenAI({ apiKey });
    const models = [this.defaultModel, ...this.fallbackModels];

    for (const model of models) {
      try {
        const resp = await ai.models.generateContent({ model, contents: prompt });
        const text = (resp.text || '').trim().replace(/^["']|["']$/g, '');
        if (text.length > 20 && text.length <= 320) {
          return text;
        }
      } catch (err: any) {
        console.warn(`[TELEMETRY] Model ${model} failed, trying next...`);
      }
    }

    return fallback;
  }

  /**
   * Generate Sunday Telemetry Report for a specific client.
   */
  async generateWeeklyTelemetry(clientId: string, referenceDate: Date = new Date()): Promise<WeeklyTelemetryReport> {
    // 1. Calculate Monday 00:00 to Sunday 23:59 range for the given week
    const current = new Date(referenceDate);
    const day = current.getDay();
    const diffToMonday = current.getDate() - day + (day === 0 ? -6 : 1);
    const monday = new Date(current.setDate(diffToMonday));
    monday.setHours(0, 0, 0, 0);

    const sunday = new Date(monday);
    sunday.setDate(monday.getDate() + 6);
    sunday.setHours(23, 59, 59, 999);

    const startDateStr = monday.toISOString().split('T')[0];
    const endDateStr = sunday.toISOString().split('T')[0];

    // Compute ISO week number
    const tempDate = new Date(monday.getTime());
    tempDate.setHours(0, 0, 0, 0);
    tempDate.setDate(tempDate.getDate() + 3 - ((tempDate.getDay() + 6) % 7));
    const week1 = new Date(tempDate.getFullYear(), 0, 4);
    const weekNumber = 1 + Math.round(((tempDate.getTime() - week1.getTime()) / 86400000 - 3 + ((week1.getDay() + 6) % 7)) / 7);
    const year = tempDate.getFullYear();

    // 2. Query user, client profile, and weekly workout records
    const user = await prisma.user.findUnique({
      where: { id: clientId },
      include: {
        clientProfile: true,
        workoutRecords: {
          where: {
            startedAt: { gte: monday, lte: sunday },
            isCompleted: true,
          },
          include: {
            exerciseRecords: {
              include: { setRecords: true },
            },
          },
        },
      },
    });

    if (!user) {
      throw new Error(`Client with ID ${clientId} not found`);
    }

    const firstName = user.name.split(' ')[0] || 'Athlete';
    const profile = user.clientProfile;
    const targetWorkouts = profile?.trainingDaysPerWeek || 4;
    const records = user.workoutRecords || [];
    const completedWorkouts = records.length;
    const adherencePct = Math.min(100, Math.round((completedWorkouts / targetWorkouts) * 100));

    let totalVolumeKg = 0;
    let totalDurationSeconds = 0;
    let totalSets = 0;
    let rpeSum = 0;
    let rpeCount = 0;
    const prHighlights: PRHighlight[] = [];

    // Map for 6 muscle groups
    const muscleMap: Record<'CHEST' | 'BACK' | 'LEGS' | 'SHOULDERS' | 'ARMS' | 'CORE', {
      displayName: string;
      sets: number;
      volume: number;
      exercises: Set<string>;
    }> = {
      CHEST: { displayName: 'Chest & Pecs', sets: 0, volume: 0, exercises: new Set() },
      BACK: { displayName: 'Back & Lats', sets: 0, volume: 0, exercises: new Set() },
      LEGS: { displayName: 'Quads, Hamstrings & Glutes', sets: 0, volume: 0, exercises: new Set() },
      SHOULDERS: { displayName: 'Delts & Shoulders', sets: 0, volume: 0, exercises: new Set() },
      ARMS: { displayName: 'Biceps & Triceps', sets: 0, volume: 0, exercises: new Set() },
      CORE: { displayName: 'Core & Abdominals', sets: 0, volume: 0, exercises: new Set() },
    };

    for (const rec of records) {
      totalVolumeKg += rec.totalVolume || 0;
      totalDurationSeconds += rec.durationSeconds || 0;
      totalSets += rec.completedSetsCount || 0;

      if (rec.averageRpe) {
        rpeSum += rec.averageRpe;
        rpeCount++;
      }

      // Check for PRs in personalRecordsJson
      if (rec.personalRecordsJson) {
        try {
          const prs = JSON.parse(rec.personalRecordsJson);
          if (Array.isArray(prs)) {
            for (const pr of prs) {
              prHighlights.push({
                exerciseName: pr.exerciseName || 'Lift',
                type: pr.type || 'VOLUME',
                value: pr.value || 0,
                weight: pr.weight,
                reps: pr.reps,
                achievedAt: rec.startedAt.toISOString(),
              });
            }
          }
        } catch (_) {}
      }

      // Break down exercises into muscle groups
      for (const ex of rec.exerciseRecords) {
        if (ex.isSkipped) continue;
        const mg = this.classifyMuscleGroup(ex.exerciseName);
        const validSets = ex.setRecords.filter((s) => s.isCompleted);
        const setVol = validSets.reduce((sum, s) => sum + ((s.actualWeight || 0) * (s.actualReps || 0)), 0);

        muscleMap[mg].sets += validSets.length;
        muscleMap[mg].volume += Math.round(setVol);
        muscleMap[mg].exercises.add(ex.exerciseName);
      }
    }

    const physicalComparison = this.calculatePhysicalComparison(totalVolumeKg);

    const muscleHeatmap: MuscleGroupTelemetry[] = (Object.keys(muscleMap) as Array<keyof typeof muscleMap>).map((key) => {
      const data = muscleMap[key];
      const stim = this.getStimulationStatus(data.sets);
      return {
        muscleGroup: key,
        displayName: data.displayName,
        totalSets: data.sets,
        totalVolumeKg: data.volume,
        status: stim.status,
        statusColor: stim.color,
        topExercises: Array.from(data.exercises).slice(0, 3),
      };
    });

    const averageRpe = rpeCount > 0 ? Number((rpeSum / rpeCount).toFixed(1)) : null;

    // AI Coach Telemetry Commentary
    const topMuscle = [...muscleHeatmap].sort((a, b) => b.totalVolumeKg - a.totalVolumeKg)[0];
    const topPrText = prHighlights.length > 0 ? `a new PR on ${prHighlights[0].exerciseName}` : 'consistent progressive overload';

    const fallbackCommentary = `${firstName} moved a monstrous ${Math.round(totalVolumeKg).toLocaleString()} kg across ${completedWorkouts} sessions this week (${physicalComparison.equivalentLabel})! Your ${topMuscle.displayName} volume was top tier with ${topMuscle.totalSets} working sets and ${topPrText}. Continue locking in recovery sleep as we advance next week's split 🏆`;

    const prompt = `You are the Alpha X Gym Head AI Coach writing the Sunday Telemetry Progress Review for gym athlete ${firstName}.
Week stats:
- Total tonnage: ${Math.round(totalVolumeKg)} kg (${physicalComparison.description})
- Sessions: ${completedWorkouts} completed out of ${targetWorkouts} planned (${adherencePct}% adherence)
- Top Muscle Group: ${topMuscle.displayName} (${topMuscle.totalSets} sets, ${topMuscle.totalVolumeKg} kg)
- PRs broken: ${prHighlights.map((p) => `${p.exerciseName} (${p.value}kg)`).join(', ') || 'Solid execution'}

Write a 3-sentence high-octane, elite coaching review (max 280 characters).
Sentence 1: Praise the raw tonnage moved and real-world comparison.
Sentence 2: Highlight the standout muscle group or PR achieved.
Sentence 3: Directive for next week's recovery and progressive overload.
Rules:
- High energy, professional sports science tone
- No hashtags or markdown asterisks
- End with one trophy/flame emoji (🏆, ⚡, 🔥)
Reply with ONLY the text.`;

    const aiCoachCommentary = await this.generateAiCommentary(prompt, fallbackCommentary);

    return {
      id: `tel-${user.id}-${year}-w${weekNumber}`,
      clientId: user.id,
      clientName: user.name,
      weekNumber,
      year,
      startDate: startDateStr,
      endDate: endDateStr,
      totalWorkoutsCompleted: completedWorkouts,
      targetWorkouts,
      adherencePercentage: adherencePct,
      totalDurationMinutes: Math.round(totalDurationSeconds / 60),
      totalVolumeKg: Math.round(totalVolumeKg),
      completedSetsCount: totalSets,
      averageRpe,
      physicalComparison,
      muscleHeatmap,
      personalRecords: prHighlights,
      aiCoachCommentary,
      streakWeeks: completedWorkouts >= targetWorkouts ? 4 : 1,
      generatedAt: new Date().toISOString(),
    };
  }

  /**
   * Admin Overview: Aggregates weekly telemetry across all clients, ranked by tonnage.
   */
  async getAdminWeeklyTelemetryOverview(referenceDate: Date = new Date()): Promise<AdminTelemetryOverview> {
    const clients = await prisma.user.findMany({
      where: { role: 'CLIENT' },
      select: { id: true, name: true, email: true, photoUrl: true },
    });

    const summaries: AdminTelemetryClientSummary[] = [];
    let gymTotalTonnage = 0;
    let gymTotalSessions = 0;
    let adherenceSum = 0;
    const topPrs: { clientName: string; exerciseName: string; value: number }[] = [];

    for (const client of clients) {
      try {
        const report = await this.generateWeeklyTelemetry(client.id, referenceDate);
        const topMuscle = [...report.muscleHeatmap].sort((a, b) => b.totalVolumeKg - a.totalVolumeKg)[0];

        gymTotalTonnage += report.totalVolumeKg;
        gymTotalSessions += report.totalWorkoutsCompleted;
        adherenceSum += report.adherencePercentage;

        for (const pr of report.personalRecords) {
          topPrs.push({
            clientName: client.name,
            exerciseName: pr.exerciseName,
            value: pr.value,
          });
        }

        summaries.push({
          clientId: client.id,
          clientName: client.name,
          email: client.email,
          photoUrl: client.photoUrl,
          totalVolumeKg: report.totalVolumeKg,
          workoutsCompleted: report.totalWorkoutsCompleted,
          adherencePercentage: report.adherencePercentage,
          topMuscleGroup: topMuscle?.displayName || 'Balanced',
          prCount: report.personalRecords.length,
          rank: 0, // Assigned below after sort
          needsEncouragement: report.adherencePercentage < 50 || report.totalWorkoutsCompleted === 0,
          physicalComparisonLabel: report.physicalComparison.equivalentLabel,
        });
      } catch (err: any) {
        console.warn(`[TELEMETRY] Skipping client ${client.id} in overview:`, err?.message);
      }
    }

    // Rank by volume descending
    summaries.sort((a, b) => b.totalVolumeKg - a.totalVolumeKg);
    summaries.forEach((s, idx) => {
      s.rank = idx + 1;
    });

    const current = new Date(referenceDate);
    const day = current.getDay();
    const diffToMonday = current.getDate() - day + (day === 0 ? -6 : 1);
    const monday = new Date(current.setDate(diffToMonday));
    const sunday = new Date(monday);
    sunday.setDate(monday.getDate() + 6);

    return {
      weekNumber: 40,
      year: 2026,
      startDate: monday.toISOString().split('T')[0],
      endDate: sunday.toISOString().split('T')[0],
      totalTonnageMovedKg: Math.round(gymTotalTonnage),
      totalSessionsCompleted: gymTotalSessions,
      averageGymAdherencePct: summaries.length > 0 ? Math.round(adherenceSum / summaries.length) : 0,
      leaderboard: summaries,
      topPrPerformers: topPrs.slice(0, 5),
    };
  }

  /**
   * Autonomous Sunday 8:00 PM Dispatcher:
   * Generates report for each active client, sends OneSignal push, and writes to Notification Center.
   */
  async dispatchSundayTelemetrySweep(): Promise<{ sent: number; skipped: number }> {
    console.log('[TELEMETRY] 📊 Starting Sunday Alpha Telemetry Sweep (8:00 PM)...');

    const clients = await prisma.user.findMany({
      where: {
        role: 'CLIENT',
        oneSignalPlayerId: { not: null },
        notificationsEnabled: true,
      },
      include: { clientProfile: true },
    });

    let sent = 0;
    let skipped = 0;

    for (const client of clients) {
      try {
        const report = await this.generateWeeklyTelemetry(client.id);

        if (report.totalVolumeKg === 0 && report.totalWorkoutsCompleted === 0) {
          skipped++;
          continue;
        }

        const pushTitle = `📊 YOUR ALPHA TELEMETRY IS READY`;
        const pushBody = `You moved ${report.totalVolumeKg.toLocaleString()} kg this week (${report.physicalComparison.equivalentLabel} ${report.physicalComparison.itemIcon})! Tap to view your 3D muscle heatmap.`;

        await oneSignalService.sendToPlayer(client.oneSignalPlayerId!, {
          title: pushTitle,
          body: pushBody,
          data: { type: 'telemetry_report', reportId: report.id },
        });

        if (client.clientProfile?.id) {
          await prisma.notification.create({
            data: {
              clientProfileId: client.clientProfile.id,
              clientId: client.clientProfile.clientId || null,
              title: pushTitle,
              message: pushBody,
              type: 'WORKOUT',
              category: 'ACHIEVEMENT',
              source: 'AI_COACH',
              triggerRule: 'WEEKLY_TELEMETRY',
              sentStatus: 'SENT',
              metadataJson: JSON.stringify({
                totalVolumeKg: report.totalVolumeKg,
                physicalComparison: report.physicalComparison,
                adherencePercentage: report.adherencePercentage,
              }),
            },
          });
        }

        sent++;
      } catch (err: any) {
        console.error(`[TELEMETRY] Error dispatching to ${client.name}:`, err?.message);
        skipped++;
      }
    }

    console.log(`[TELEMETRY] 📊 Sunday Telemetry sweep complete: ${sent} sent, ${skipped} skipped.`);
    return { sent, skipped };
  }
}

export const telemetryService = new TelemetryService();
