/**
 * Alpha X AI — Deterministic Calculation Service
 * Phase 8 — Deterministic Fitness Calculation Engine
 *
 * Coordinates data retrieval from the Alpha X Prisma database and passes raw records
 * into pure mathematical calculators. Returns structured, deterministic CalculationResult objects.
 */

import { prisma } from '../../../config/prisma';
import { clientDataService } from '../tools/definitions/client/client_data.service';
import {
  CalculationDateRangeOptions,
  CalculationResult,
  WeightSummaryValue,
  WaistSummaryValue,
  NutritionSummaryValue,
  NutritionTargetComparisonValue,
  ActivitySummaryValue,
  WorkoutSummaryValue,
  CheckInSummaryValue,
} from './calculation.types';
import { validateDateRange } from './calculation.validation';
import { weightCalculator } from './weight.calculator';
import { waistCalculator } from './waist.calculator';
import { nutritionCalculator } from './nutrition.calculator';
import { activityCalculator } from './activity.calculator';
import { workoutCalculator } from './workout.calculator';
import { checkInCalculator } from './checkin.calculator';

export class CalculationService {
  /**
   * Deterministically calculates weight summary and changes for a verified client.
   */
  public async calculateWeightSummary(
    clientIdOrName: string,
    options: CalculationDateRangeOptions = {}
  ): Promise<CalculationResult<WeightSummaryValue> | any> {
    const resolution = await clientDataService.resolveClient(clientIdOrName);
    if (resolution.status !== 'FOUND' || !resolution.client) {
      return {
        source: 'ALPHA_X_DATABASE',
        status: resolution.status === 'AMBIGUOUS' ? 'MULTIPLE_CLIENTS_FOUND' : 'CLIENT_NOT_FOUND',
        matches: resolution.matches,
        message: resolution.message,
      };
    }

    const { start, end, startDateStr, endDateStr } = validateDateRange(options.startDate, options.endDate);
    const limit = Math.min(Math.max(Number(options.limit) || 100, 1), 365);

    const where: any = { clientProfileId: resolution.client.profileId };
    if (start || end) {
      where.date = {};
      if (start) where.date.gte = start;
      if (end) where.date.lte = end;
    }

    const records = await prisma.clientProgress.findMany({
      where,
      select: {
        date: true,
        weightKg: true,
        waistCm: true,
      },
      orderBy: { date: 'asc' },
      take: limit,
    });

    return weightCalculator.calculateWeightSummary(records, startDateStr, endDateStr);
  }

  /**
   * Deterministically calculates waist circumference summary and changes for a verified client.
   */
  public async calculateWaistSummary(
    clientIdOrName: string,
    options: CalculationDateRangeOptions = {}
  ): Promise<CalculationResult<WaistSummaryValue> | any> {
    const resolution = await clientDataService.resolveClient(clientIdOrName);
    if (resolution.status !== 'FOUND' || !resolution.client) {
      return {
        source: 'ALPHA_X_DATABASE',
        status: resolution.status === 'AMBIGUOUS' ? 'MULTIPLE_CLIENTS_FOUND' : 'CLIENT_NOT_FOUND',
        matches: resolution.matches,
        message: resolution.message,
      };
    }

    const { start, end, startDateStr, endDateStr } = validateDateRange(options.startDate, options.endDate);
    const limit = Math.min(Math.max(Number(options.limit) || 100, 1), 365);

    const where: any = {
      clientProfileId: resolution.client.profileId,
      waistCm: { not: null },
    };
    if (start || end) {
      where.date = {};
      if (start) where.date.gte = start;
      if (end) where.date.lte = end;
    }

    const records = await prisma.clientProgress.findMany({
      where,
      select: {
        date: true,
        waistCm: true,
      },
      orderBy: { date: 'asc' },
      take: limit,
    });

    return waistCalculator.calculateWaistSummary(records, startDateStr, endDateStr);
  }

  /**
   * Deterministically calculates aggregated nutrition summary and daily averages from food logs.
   */
  public async calculateNutritionSummary(
    clientIdOrName: string,
    options: CalculationDateRangeOptions = {}
  ): Promise<CalculationResult<NutritionSummaryValue> | any> {
    const resolution = await clientDataService.resolveClient(clientIdOrName);
    if (resolution.status !== 'FOUND' || !resolution.client) {
      return {
        source: 'ALPHA_X_DATABASE',
        status: resolution.status === 'AMBIGUOUS' ? 'MULTIPLE_CLIENTS_FOUND' : 'CLIENT_NOT_FOUND',
        matches: resolution.matches,
        message: resolution.message,
      };
    }

    const { start, end, startDateStr, endDateStr } = validateDateRange(options.startDate, options.endDate);
    const limit = Math.min(Math.max(Number(options.limit) || 200, 1), 500);

    const where: any = { clientProfileId: resolution.client.profileId };
    if (start || end) {
      where.date = {};
      if (start) where.date.gte = start;
      if (end) where.date.lte = end;
    }

    const logs = await prisma.clientFoodLog.findMany({
      where,
      select: {
        dateString: true,
        calories: true,
        protein: true,
        carbohydrates: true,
        fat: true,
        fiber: true,
      },
      orderBy: { date: 'asc' },
      take: limit,
    });

    return nutritionCalculator.calculateNutritionSummary(logs, startDateStr, endDateStr);
  }

  /**
   * Deterministically compares actual logged nutrition averages with active assigned coach diet target.
   */
  public async calculateNutritionTargetComparison(
    clientIdOrName: string,
    options: CalculationDateRangeOptions = {}
  ): Promise<CalculationResult<NutritionTargetComparisonValue> | any> {
    const resolution = await clientDataService.resolveClient(clientIdOrName);
    if (resolution.status !== 'FOUND' || !resolution.client) {
      return {
        source: 'ALPHA_X_DATABASE',
        status: resolution.status === 'AMBIGUOUS' ? 'MULTIPLE_CLIENTS_FOUND' : 'CLIENT_NOT_FOUND',
        matches: resolution.matches,
        message: resolution.message,
      };
    }

    // 1. Fetch active assigned diet plan
    const activeDiet = await prisma.dietPlan.findFirst({
      where: {
        clientProfileId: resolution.client.profileId,
        isActive: true,
      },
      select: {
        planName: true,
        dailyCalories: true,
        protein: true,
        carbohydrates: true,
        fat: true,
        fiber: true,
      },
      orderBy: { updatedAt: 'desc' },
    });

    if (!activeDiet) {
      return {
        metric: 'NUTRITION_TARGET_COMPARISON',
        source: 'ALPHA_X_DATABASE',
        status: 'DATA_NOT_AVAILABLE',
        message: 'No active assigned diet plan found for this client to compare with actual intake.',
      };
    }

    // 2. Fetch actual food logs summary
    const actualResult = await this.calculateNutritionSummary(clientIdOrName, options);
    if (actualResult.status !== 'SUCCESS') {
      return actualResult;
    }

    return nutritionCalculator.compareTargetVsActual(
      {
        planName: activeDiet.planName,
        dailyCalories: activeDiet.dailyCalories,
        protein: activeDiet.protein,
        carbohydrates: activeDiet.carbohydrates,
        fat: activeDiet.fat,
        fiber: activeDiet.fiber,
      },
      actualResult.value
    );
  }

  /**
   * Deterministically calculates activity and step metrics over recorded activity entries.
   */
  public async calculateActivitySummary(
    clientIdOrName: string,
    options: CalculationDateRangeOptions = {}
  ): Promise<CalculationResult<ActivitySummaryValue> | any> {
    const resolution = await clientDataService.resolveClient(clientIdOrName);
    if (resolution.status !== 'FOUND' || !resolution.client) {
      return {
        source: 'ALPHA_X_DATABASE',
        status: resolution.status === 'AMBIGUOUS' ? 'MULTIPLE_CLIENTS_FOUND' : 'CLIENT_NOT_FOUND',
        matches: resolution.matches,
        message: resolution.message,
      };
    }

    const { start, end, startDateStr, endDateStr } = validateDateRange(options.startDate, options.endDate);
    const limit = Math.min(Math.max(Number(options.limit) || 60, 1), 365);

    const where: any = { clientId: resolution.client.profileId };
    if (start || end) {
      where.date = {};
      if (start) where.date.gte = start;
      if (end) where.date.lte = end;
    }

    // Fetch client daily step goal from profile
    const profile = await prisma.clientProfile.findUnique({
      where: { id: resolution.client.profileId },
      select: { dailyStepGoal: true },
    });

    const records = await prisma.activityRecord.findMany({
      where,
      select: {
        date: true,
        steps: true,
        stepGoal: true,
        cardioMinutes: true,
        caloriesBurned: true,
        distanceMeters: true,
        isGoalAchieved: true,
      },
      orderBy: { date: 'asc' },
      take: limit,
    });

    return activityCalculator.calculateActivitySummary(
      records,
      profile?.dailyStepGoal || 6000,
      startDateStr,
      endDateStr
    );
  }

  /**
   * Deterministically calculates workout volume, duration, and intensity metrics over recorded sessions.
   */
  public async calculateWorkoutSummary(
    clientIdOrName: string,
    options: CalculationDateRangeOptions = {}
  ): Promise<CalculationResult<WorkoutSummaryValue> | any> {
    const resolution = await clientDataService.resolveClient(clientIdOrName);
    if (resolution.status !== 'FOUND' || !resolution.client) {
      return {
        source: 'ALPHA_X_DATABASE',
        status: resolution.status === 'AMBIGUOUS' ? 'MULTIPLE_CLIENTS_FOUND' : 'CLIENT_NOT_FOUND',
        matches: resolution.matches,
        message: resolution.message,
      };
    }

    const { start, end, startDateStr, endDateStr } = validateDateRange(options.startDate, options.endDate);
    const limit = Math.min(Math.max(Number(options.limit) || 30, 1), 100);

    const where: any = { clientId: resolution.client.userId };
    if (start || end) {
      where.startedAt = {};
      if (start) where.startedAt.gte = start;
      if (end) where.startedAt.lte = end;
    }

    const workouts = await prisma.workoutRecord.findMany({
      where,
      select: {
        startedAt: true,
        completedAt: true,
        durationSeconds: true,
        totalVolume: true,
        completedSetsCount: true,
        averageRpe: true,
        averageRir: true,
        isCompleted: true,
      },
      orderBy: { startedAt: 'asc' },
      take: limit,
    });

    return workoutCalculator.calculateWorkoutSummary(workouts, startDateStr, endDateStr);
  }


  /**
   * Deterministically calculates check-in summaries over recorded weekly check-in entries.
   */
  public async calculateCheckInSummary(
    clientIdOrName: string,
    options: CalculationDateRangeOptions = {}
  ): Promise<CalculationResult<CheckInSummaryValue> | any> {
    const resolution = await clientDataService.resolveClient(clientIdOrName);
    if (resolution.status !== 'FOUND' || !resolution.client) {
      return {
        source: 'ALPHA_X_DATABASE',
        status: resolution.status === 'AMBIGUOUS' ? 'MULTIPLE_CLIENTS_FOUND' : 'CLIENT_NOT_FOUND',
        matches: resolution.matches,
        message: resolution.message,
      };
    }

    const { start, end, startDateStr, endDateStr } = validateDateRange(options.startDate, options.endDate);
    const limit = Math.min(Math.max(Number(options.limit) || 20, 1), 52);

    const where: any = { clientProfileId: resolution.client.profileId };
    if (start || end) {
      where.checkInDate = {};
      if (start) where.checkInDate.gte = start;
      if (end) where.checkInDate.lte = end;
    }

    const checkIns = await prisma.weeklyCheckIn.findMany({
      where,
      select: {
        weekNumber: true,
        year: true,
        checkInDate: true,
        sleepHours: true,
        sleepQuality: true,
        recoveryQuality: true,
        dietAdherence: true,
        workoutCompletion: true,
        hasPain: true,
        painLevel: true,
        painLocation: true,
        painDescription: true,
      },
      orderBy: { checkInDate: 'asc' },
      take: limit,
    });

    return checkInCalculator.calculateCheckInSummary(checkIns, startDateStr, endDateStr);
  }
}

export const calculationService = new CalculationService();
