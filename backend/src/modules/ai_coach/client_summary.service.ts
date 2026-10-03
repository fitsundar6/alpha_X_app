/**
 * Alpha X AI Coach - Client Summary Builder
 * Step 1: Compact Client Summary
 *
 * Collects one client's data for a date range and returns a token-efficient
 * JSON summary ready for Gemini analysis.
 *
 * Privacy rules (never sent to Gemini):
 *   - No email addresses
 *   - No phone numbers
 *   - No password hashes
 *   - Uses first name + AXG-XXXX client ID only
 */

import { prisma } from '../../config/prisma';
import { clientDataService } from './tools/definitions/client/client_data.service';

export interface ClientSummaryOptions {
  startDate?: string;
  endDate?: string;
}

export interface PersonalRecord {
  exercise: string;
  record: string;
}

export interface ClientSummary {
  clientId: string;
  firstName: string;
  dateRangeStart: string;
  dateRangeEnd: string;
  generatedAt: string;
  profile: {
    primaryGoal: string | null;
    fitnessLevel: string | null;
    age: number | null;
    gender: string | null;
    trainingDaysPerWeek: number | null;
    membershipStatus: string;
    hasInjury: boolean;
    injuryNote: string | null;
  };
  workouts: {
    planned: number;
    completed: number;
    missed: number;
    completionRatePct: number;
    totalVolumeKg: number;
    avgRpe: number | null;
    avgRir: number | null;
    personalRecords: PersonalRecord[];
  };
  bodyMetrics: {
    startWeightKg: number | null;
    latestWeightKg: number | null;
    weightChangeKg: number | null;
    startWaistCm: number | null;
    latestWaistCm: number | null;
    waistChangeCm: number | null;
  };
  nutrition: {
    daysLogged: number;
    avgDailyCalories: number;
    avgDailyProteinG: number;
    avgDailyCarbsG: number;
    avgDailyFatG: number;
  };
  dietAdherence: {
    hasPlan: boolean;
    planName: string | null;
    targetCalories: number | null;
    targetProteinG: number | null;
    calorieAdherencePct: number | null;
    proteinAdherencePct: number | null;
  };
  requiresMedicalDisclaimer: boolean;
}

export type ClientSummaryError = {
  status: 'CLIENT_NOT_FOUND' | 'AMBIGUOUS' | 'INVALID_DATE';
  error: string;
};

function round2(n: number): number {
  return Math.round(n * 100) / 100;
}

export class ClientSummaryService {
  public async buildClientSummary(
    clientIdentifier: string,
    options: ClientSummaryOptions = {}
  ): Promise<ClientSummary | ClientSummaryError> {

    const resolution = await clientDataService.resolveClient(clientIdentifier);
    if (resolution.status !== 'FOUND' || !resolution.client) {
      return {
        status: resolution.status === 'AMBIGUOUS' ? 'AMBIGUOUS' : 'CLIENT_NOT_FOUND',
        error: resolution.message || `Client not found: ${clientIdentifier}`,
      };
    }
    const { profileId, userId, clientId, name } = resolution.client;
    const firstName = name.split(' ')[0];

    const endDate = options.endDate
      ? new Date(`${options.endDate}T23:59:59.999Z`)
      : new Date();
    const startDate = options.startDate
      ? new Date(`${options.startDate}T00:00:00.000Z`)
      : new Date(endDate.getTime() - 7 * 24 * 60 * 60 * 1000);

    if (isNaN(startDate.getTime()) || isNaN(endDate.getTime())) {
      return { status: 'INVALID_DATE', error: 'Invalid date format — expected YYYY-MM-DD' };
    }
    if (startDate > endDate) {
      return { status: 'INVALID_DATE', error: 'startDate cannot be after endDate' };
    }

    const startStr = startDate.toISOString().split('T')[0];
    const endStr = endDate.toISOString().split('T')[0];

    const [profile, workoutRecords, progressRecords, foodLogs, activeDietPlan] = await Promise.all([
      prisma.clientProfile.findUnique({
        where: { id: profileId },
        select: {
          primaryGoal: true, fitnessLevel: true, age: true, gender: true,
          trainingDaysPerWeek: true, membershipStatus: true,
          hasCurrentInjury: true, injuryAreas: true, injuryDescription: true,
        },
      }),
      prisma.workoutRecord.findMany({
        where: { clientId: userId, startedAt: { gte: startDate, lte: endDate } },
        select: { isCompleted: true, totalVolume: true, averageRpe: true, averageRir: true, personalRecordsJson: true },
      }),
      prisma.clientProgress.findMany({
        where: { clientProfileId: profileId, date: { gte: startDate, lte: endDate } },
        select: { date: true, weightKg: true, waistCm: true },
        orderBy: { date: 'asc' },
      }),
      prisma.clientFoodLog.findMany({
        where: { clientProfileId: profileId, date: { gte: startDate, lte: endDate } },
        select: { dateString: true, calories: true, protein: true, carbohydrates: true, fat: true },
      }),
      prisma.dietPlan.findFirst({
        where: { clientProfileId: profileId, isActive: true },
        select: { planName: true, dailyCalories: true, protein: true, carbohydrates: true, fat: true },
        orderBy: { updatedAt: 'desc' },
      }),
    ]);

    const completed = workoutRecords.filter((w) => w.isCompleted);
    const totalVolumeKg = round2(completed.reduce((s, w) => s + w.totalVolume, 0));
    const rpeVals = completed.filter((w) => w.averageRpe !== null).map((w) => w.averageRpe!);
    const rirVals = completed.filter((w) => w.averageRir !== null).map((w) => w.averageRir!);
    const avgRpe = rpeVals.length > 0 ? round2(rpeVals.reduce((s, v) => s + v, 0) / rpeVals.length) : null;
    const avgRir = rirVals.length > 0 ? round2(rirVals.reduce((s, v) => s + v, 0) / rirVals.length) : null;

    const personalRecords: PersonalRecord[] = [];
    for (const r of completed) {
      if (r.personalRecordsJson) {
        try {
          const prs = JSON.parse(r.personalRecordsJson);
          if (Array.isArray(prs)) {
            for (const pr of prs) {
              personalRecords.push({
                exercise: pr.exerciseName || pr.exercise || 'Unknown',
                record: pr.description || pr.record || JSON.stringify(pr),
              });
            }
          }
        } catch (_) {}
      }
    }

    const dayCount = Math.ceil((endDate.getTime() - startDate.getTime()) / (1000 * 60 * 60 * 24)) + 1;
    const daysPerWeek = profile?.trainingDaysPerWeek ?? 3;
    const planned = Math.round((dayCount / 7) * daysPerWeek);
    const missed = Math.max(0, planned - completed.length);
    const completionRatePct = planned > 0 ? Math.round((completed.length / planned) * 100) : 0;

    const weightRecs = progressRecords.filter((r) => r.weightKg !== null);
    const waistRecs = progressRecords.filter((r) => r.waistCm !== null);
    const startWeightKg = weightRecs[0]?.weightKg ?? null;
    const latestWeightKg = weightRecs[weightRecs.length - 1]?.weightKg ?? null;
    const weightChangeKg = startWeightKg !== null && latestWeightKg !== null ? round2(latestWeightKg - startWeightKg) : null;
    const startWaistCm = waistRecs[0]?.waistCm ?? null;
    const latestWaistCm = waistRecs[waistRecs.length - 1]?.waistCm ?? null;
    const waistChangeCm = startWaistCm !== null && latestWaistCm !== null ? round2(latestWaistCm - startWaistCm) : null;

    const byDay: Record<string, { calories: number; protein: number; carbs: number; fat: number }> = {};
    for (const log of foodLogs) {
      if (!byDay[log.dateString]) byDay[log.dateString] = { calories: 0, protein: 0, carbs: 0, fat: 0 };
      byDay[log.dateString].calories += log.calories;
      byDay[log.dateString].protein += log.protein;
      byDay[log.dateString].carbs += log.carbohydrates;
      byDay[log.dateString].fat += log.fat;
    }
    const daysLogged = Object.keys(byDay).length;
    const dt = Object.values(byDay);
    const avgCalories = daysLogged > 0 ? round2(dt.reduce((s, d) => s + d.calories, 0) / daysLogged) : 0;
    const avgProtein  = daysLogged > 0 ? round2(dt.reduce((s, d) => s + d.protein, 0) / daysLogged) : 0;
    const avgCarbs    = daysLogged > 0 ? round2(dt.reduce((s, d) => s + d.carbs, 0) / daysLogged) : 0;
    const avgFat      = daysLogged > 0 ? round2(dt.reduce((s, d) => s + d.fat, 0) / daysLogged) : 0;

    const calorieAdherencePct = activeDietPlan && activeDietPlan.dailyCalories > 0 && daysLogged > 0
      ? round2((avgCalories / activeDietPlan.dailyCalories) * 100) : null;
    const proteinAdherencePct = activeDietPlan && activeDietPlan.protein > 0 && daysLogged > 0
      ? round2((avgProtein / activeDietPlan.protein) * 100) : null;

    const requiresMedicalDisclaimer = (profile?.hasCurrentInjury ?? false) || (profile?.injuryAreas?.length ?? 0) > 0;
    const injuryNote = requiresMedicalDisclaimer
      ? [...(profile?.injuryAreas ?? []), profile?.injuryDescription ?? ''].filter(Boolean).join(', ') || 'Injury reported'
      : null;

    return {
      clientId: clientId || userId,
      firstName,
      dateRangeStart: startStr,
      dateRangeEnd: endStr,
      generatedAt: new Date().toISOString(),
      profile: {
        primaryGoal: profile?.primaryGoal ?? null,
        fitnessLevel: profile?.fitnessLevel ?? null,
        age: profile?.age ?? null,
        gender: profile?.gender ?? null,
        trainingDaysPerWeek: profile?.trainingDaysPerWeek ?? null,
        membershipStatus: profile?.membershipStatus ?? 'ACTIVE',
        hasInjury: profile?.hasCurrentInjury ?? false,
        injuryNote,
      },
      workouts: { planned, completed: completed.length, missed, completionRatePct, totalVolumeKg, avgRpe, avgRir, personalRecords },
      bodyMetrics: { startWeightKg, latestWeightKg, weightChangeKg, startWaistCm, latestWaistCm, waistChangeCm },
      nutrition: { daysLogged, avgDailyCalories: avgCalories, avgDailyProteinG: avgProtein, avgDailyCarbsG: avgCarbs, avgDailyFatG: avgFat },
      dietAdherence: {
        hasPlan: activeDietPlan !== null,
        planName: activeDietPlan?.planName ?? null,
        targetCalories: activeDietPlan?.dailyCalories ?? null,
        targetProteinG: activeDietPlan?.protein ?? null,
        calorieAdherencePct,
        proteinAdherencePct,
      },
      requiresMedicalDisclaimer,
    };
  }
}

export const clientSummaryService = new ClientSummaryService();
