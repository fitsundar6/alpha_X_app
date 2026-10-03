/**
 * Alpha X AI — Pure Deterministic Workout Intelligence Calculator
 * Phase 9 — Workout Intelligence Engine
 *
 * Implements pure mathematical analysis over workout sessions, sets, volumes,
 * exercise progression, personal bests, intensity, frequency, and period comparisons.
 * Zero database queries or side-effects.
 */

import {
  RawWorkoutSessionEntry,
  WorkoutSessionAnalysis,
  WorkoutVolumeAnalysis,
  ExerciseVolumeContribution,
  WorkoutTypeVolumeContribution,
  MuscleGroupVolumeContribution,
  ExercisePerformanceAnalysis,
  ExercisePerformanceDataPoint,
  PersonalBestRecord,
  WorkoutIntensityAnalysis,
  PeriodComparisonAnalysis,
  TrainingFrequencyAnalysis,
} from './workout_intelligence.types';
import { round2, safeAverage, safeMin, safeMax, PeriodComparisonDateSpans } from './workout_intelligence.validation';
import { InsufficientWorkoutDataError } from './workout_intelligence.errors';

export class WorkoutIntelligenceCalculator {
  /**
   * Deterministically analyzes session counts, weekly/monthly frequencies, gaps, and training days.
   */
  public analyzeSessions(
    workouts: RawWorkoutSessionEntry[],
    startDateFilter?: string | null,
    endDateFilter?: string | null
  ): WorkoutSessionAnalysis {
    if (!workouts || workouts.length === 0) {
      return {
        completedSessionsCount: 0,
        sessionsPerWeek: 0,
        sessionsPerMonth: 0,
        averageWeeklySessions: 0,
        trainingDaysCount: 0,
        longestGapDays: 0,
        averageGapDays: 0,
        mostRecentSessionDate: null,
        oldestSessionDate: null,
        dateRange: {
          startDate: startDateFilter || null,
          endDate: endDateFilter || null,
        },
      };
    }

    // Sort chronologically ascending
    const sorted = [...workouts].sort((a, b) => {
      const timeA = a.startedAt instanceof Date ? a.startedAt.getTime() : new Date(a.startedAt).getTime();
      const timeB = b.startedAt instanceof Date ? b.startedAt.getTime() : new Date(b.startedAt).getTime();
      return timeA - timeB;
    });

    const completedSessionsCount = sorted.length;
    const trainingDatesSet = new Set<string>();

    for (const w of sorted) {
      const d = new Date(w.startedAt);
      trainingDatesSet.add(d.toISOString().split('T')[0]);
    }

    const trainingDaysCount = trainingDatesSet.size;

    const earliestDate = new Date(sorted[0].startedAt);
    const latestDate = new Date(sorted[sorted.length - 1].startedAt);

    const oldestSessionDate = earliestDate.toISOString().split('T')[0];
    const mostRecentSessionDate = latestDate.toISOString().split('T')[0];

    // Compute timespan in days and weeks
    const spanDays = Math.max(1, Math.ceil((latestDate.getTime() - earliestDate.getTime()) / (1000 * 60 * 60 * 24)) + 1);
    const totalWeeks = Math.max(1, spanDays / 7);
    const totalMonths = Math.max(1, spanDays / 30.4375);

    const averageWeeklySessions = round2(completedSessionsCount / totalWeeks);
    const sessionsPerWeek = averageWeeklySessions;
    const sessionsPerMonth = round2(completedSessionsCount / totalMonths);

    // Compute gaps between consecutive recorded sessions
    let longestGapDays = 0;
    const gaps: number[] = [];

    if (sorted.length >= 2) {
      for (let i = 1; i < sorted.length; i++) {
        const prevTime = new Date(sorted[i - 1].startedAt).getTime();
        const currTime = new Date(sorted[i].startedAt).getTime();
        const diffDays = Math.max(0, Math.floor((currTime - prevTime) / (1000 * 60 * 60 * 24)));
        gaps.push(diffDays);
        if (diffDays > longestGapDays) {
          longestGapDays = diffDays;
        }
      }
    }

    const averageGapDays = gaps.length > 0 ? round2(gaps.reduce((acc, c) => acc + c, 0) / gaps.length) : 0;

    return {
      completedSessionsCount,
      sessionsPerWeek,
      sessionsPerMonth,
      averageWeeklySessions,
      trainingDaysCount,
      longestGapDays,
      averageGapDays,
      mostRecentSessionDate,
      oldestSessionDate,
      dateRange: {
        startDate: startDateFilter || oldestSessionDate,
        endDate: endDateFilter || mostRecentSessionDate,
      },
    };
  }

  /**
   * Deterministically calculates training volume load, breakdown by exercise, workout type, and muscle groups.
   */
  public analyzeVolume(
    workouts: RawWorkoutSessionEntry[],
    exerciseToMuscleMap: Map<string, string[]> = new Map()
  ): WorkoutVolumeAnalysis {
    if (!workouts || workouts.length === 0) {
      return {
        totalVolumeKg: 0,
        averageSessionVolumeKg: 0,
        minSessionVolumeKg: 0,
        maxSessionVolumeKg: 0,
        volumeByExercise: [],
        volumeByWorkoutType: [],
        volumeByMuscleGroup: [],
        unit: 'kg',
      };
    }

    const sessionVolumes = workouts.map((w) => Math.max(Number(w.totalVolume) || 0, 0));
    const totalVolumeKg = round2(sessionVolumes.reduce((acc, c) => acc + c, 0));
    const averageSessionVolumeKg = round2(totalVolumeKg / workouts.length);
    const minSessionVolumeKg = Math.min(...sessionVolumes);
    const maxSessionVolumeKg = Math.max(...sessionVolumes);

    // 1. Volume by Exercise
    const exerciseVolMap = new Map<string, { totalVol: number; count: number }>();

    for (const w of workouts) {
      for (const ex of w.exerciseRecords || []) {
        if (ex.isSkipped) continue;
        const normName = ex.exerciseName.trim();
        let exVol = 0;
        for (const s of ex.setRecords || []) {
          const wgt = Number(s.actualWeight) || 0;
          const rps = Number(s.actualReps) || 0;
          exVol += wgt * rps;
        }

        const current = exerciseVolMap.get(normName) || { totalVol: 0, count: 0 };
        current.totalVol += exVol;
        current.count += 1;
        exerciseVolMap.set(normName, current);
      }
    }

    const volumeByExercise: ExerciseVolumeContribution[] = Array.from(exerciseVolMap.entries())
      .map(([name, data]) => {
        const roundedVol = round2(data.totalVol);
        const percentage = totalVolumeKg > 0 ? round2((roundedVol / totalVolumeKg) * 100) : 0;
        return {
          exerciseName: name,
          totalVolumeKg: roundedVol,
          percentageOfTotal: percentage,
          occurrences: data.count,
        };
      })
      .sort((a, b) => b.totalVolumeKg - a.totalVolumeKg);

    // 2. Volume by Workout Type
    const typeVolMap = new Map<string, { totalVol: number; count: number }>();
    for (const w of workouts) {
      const type = (w.workoutType || 'General').trim();
      const vol = Math.max(Number(w.totalVolume) || 0, 0);
      const current = typeVolMap.get(type) || { totalVol: 0, count: 0 };
      current.totalVol += vol;
      current.count += 1;
      typeVolMap.set(type, current);
    }

    const volumeByWorkoutType: WorkoutTypeVolumeContribution[] = Array.from(typeVolMap.entries())
      .map(([type, data]) => ({
        workoutType: type,
        totalVolumeKg: round2(data.totalVol),
        sessionCount: data.count,
      }))
      .sort((a, b) => b.totalVolumeKg - a.totalVolumeKg);

    // 3. Volume by Muscle Group (strictly based on authoritative Exercise model mapping)
    const muscleVolMap = new Map<string, number>();
    for (const [exName, data] of exerciseVolMap.entries()) {
      const muscles = exerciseToMuscleMap.get(exName.toLowerCase()) || [];
      if (muscles.length > 0) {
        // Distribute volume evenly across mapped primary muscles
        const share = data.totalVol / muscles.length;
        for (const m of muscles) {
          muscleVolMap.set(m, (muscleVolMap.get(m) || 0) + share);
        }
      }
    }

    const volumeByMuscleGroup: MuscleGroupVolumeContribution[] = Array.from(muscleVolMap.entries())
      .map(([muscle, vol]) => {
        const roundedVol = round2(vol);
        const percentage = totalVolumeKg > 0 ? round2((roundedVol / totalVolumeKg) * 100) : 0;
        return {
          muscleGroup: muscle,
          totalVolumeKg: roundedVol,
          percentageOfTotal: percentage,
        };
      })
      .sort((a, b) => b.totalVolumeKg - a.totalVolumeKg);

    return {
      totalVolumeKg,
      averageSessionVolumeKg,
      minSessionVolumeKg,
      maxSessionVolumeKg,
      volumeByExercise,
      volumeByWorkoutType,
      volumeByMuscleGroup,
      unit: 'kg',
    };
  }

  /**
   * Deterministically calculates exercise-specific performance, progression, and deltas across workouts.
   */
  public analyzeExercise(
    exerciseName: string,
    workouts: RawWorkoutSessionEntry[]
  ): ExercisePerformanceAnalysis {
    const cleanTarget = exerciseName.trim().toLowerCase();

    // Chronological order
    const sorted = [...workouts].sort((a, b) => {
      const timeA = a.startedAt instanceof Date ? a.startedAt.getTime() : new Date(a.startedAt).getTime();
      const timeB = b.startedAt instanceof Date ? b.startedAt.getTime() : new Date(b.startedAt).getTime();
      return timeA - timeB;
    });

    const occurrences: ExercisePerformanceDataPoint[] = [];
    const allWeights: number[] = [];
    const allReps: number[] = [];
    let totalSets = 0;
    let totalVolume = 0;
    const rpes: number[] = [];
    const rirs: number[] = [];

    let canonicalName = exerciseName.trim();

    for (const w of sorted) {
      for (const ex of w.exerciseRecords || []) {
        if (ex.exerciseName.trim().toLowerCase() === cleanTarget) {
          canonicalName = ex.exerciseName.trim();
          if (ex.isSkipped) continue;

          let sessionExVolume = 0;
          let sessionTopWeight = 0;
          let sessionTotalReps = 0;
          let sessionSetsCount = 0;

          for (const s of ex.setRecords || []) {
            sessionSetsCount++;
            totalSets++;

            const wgt = Number(s.actualWeight) || 0;
            const rps = Number(s.actualReps) || 0;

            if (wgt > 0) {
              allWeights.push(wgt);
              if (wgt > sessionTopWeight) sessionTopWeight = wgt;
            }
            if (rps > 0) {
              allReps.push(rps);
              sessionTotalReps += rps;
            }

            sessionExVolume += wgt * rps;

            if (s.actualRpe !== null && s.actualRpe !== undefined && s.actualRpe > 0) {
              rpes.push(Number(s.actualRpe));
            }
            if (s.actualRir !== null && s.actualRir !== undefined && s.actualRir >= 0) {
              rirs.push(Number(s.actualRir));
            }
          }

          totalVolume += sessionExVolume;

          const dateStr = w.startedAt instanceof Date ? w.startedAt.toISOString().split('T')[0] : String(w.startedAt).split('T')[0];

          occurrences.push({
            date: dateStr,
            sessionTitle: w.sessionTitle,
            topWeightKg: round2(sessionTopWeight),
            totalReps: sessionTotalReps,
            totalSets: sessionSetsCount,
            volumeKg: round2(sessionExVolume),
            averageRpe: w.averageRpe || null,
            averageRir: w.averageRir || null,
          });
        }
      }
    }

    if (occurrences.length === 0) {
      return {
        exerciseName: canonicalName,
        totalSessions: 0,
        totalSets: 0,
        totalReps: 0,
        averageWeightKg: 0,
        maxWeightKg: 0,
        averageReps: 0,
        maxReps: 0,
        totalVolumeKg: 0,
        averageVolumePerSessionKg: 0,
        averageRpe: null,
        averageRir: null,
        latestPerformance: null,
        previousPerformance: null,
        performanceDifference: null,
        unit: 'kg, reps, sets',
      };
    }

    const totalSessions = occurrences.length;
    const averageWeightKg = safeAverage(allWeights) || 0;
    const maxWeightKg = safeMax(allWeights) || 0;
    const averageReps = safeAverage(allReps) || 0;
    const maxReps = safeMax(allReps) || 0;
    const totalVolumeKg = round2(totalVolume);
    const averageVolumePerSessionKg = round2(totalVolumeKg / totalSessions);
    const averageRpe = safeAverage(rpes);
    const averageRir = safeAverage(rirs);

    // Latest and previous performance comparison
    const latestPerformance = occurrences[occurrences.length - 1];
    let previousPerformance: ExercisePerformanceDataPoint | null = null;
    let performanceDifference: any = null;

    if (occurrences.length >= 2) {
      previousPerformance = occurrences[occurrences.length - 2];
      const weightDeltaKg = round2(latestPerformance.topWeightKg - previousPerformance.topWeightKg);
      const repsDelta = latestPerformance.totalReps - previousPerformance.totalReps;
      const volumeDeltaKg = round2(latestPerformance.volumeKg - previousPerformance.volumeKg);
      const percentageVolumeChange = previousPerformance.volumeKg > 0
        ? round2(((latestPerformance.volumeKg - previousPerformance.volumeKg) / previousPerformance.volumeKg) * 100)
        : null;

      let direction: 'INCREASED' | 'DECREASED' | 'UNCHANGED' = 'UNCHANGED';
      if (volumeDeltaKg > 0 || weightDeltaKg > 0) {
        direction = 'INCREASED';
      } else if (volumeDeltaKg < 0 && weightDeltaKg <= 0) {
        direction = 'DECREASED';
      }

      performanceDifference = {
        weightDeltaKg,
        repsDelta,
        volumeDeltaKg,
        percentageVolumeChange,
        direction,
      };
    }

    return {
      exerciseName: canonicalName,
      totalSessions,
      totalSets,
      totalReps: allReps.reduce((acc, c) => acc + c, 0),
      averageWeightKg,
      maxWeightKg,
      averageReps,
      maxReps,
      totalVolumeKg,
      averageVolumePerSessionKg,
      averageRpe,
      averageRir,
      latestPerformance,
      previousPerformance,
      performanceDifference,
      unit: 'kg, reps, sets',
    };
  }

  /**
   * Deterministically calculates personal-best records (highest weight, highest reps at weight, highest session volume).
   */
  public calculatePersonalBests(
    workouts: RawWorkoutSessionEntry[],
    targetExerciseName?: string
  ): PersonalBestRecord[] {
    const pbs: PersonalBestRecord[] = [];
    const exerciseMap = new Map<string, {
      topWeight: { weight: number; reps: number; date: string; sessionTitle: string };
      topSessionVolume: { volume: number; date: string; sessionTitle: string };
    }>();

    for (const w of workouts) {
      const dateStr = w.startedAt instanceof Date ? w.startedAt.toISOString().split('T')[0] : String(w.startedAt).split('T')[0];

      for (const ex of w.exerciseRecords || []) {
        if (ex.isSkipped) continue;
        const normName = ex.exerciseName.trim();

        if (targetExerciseName && normName.toLowerCase() !== targetExerciseName.trim().toLowerCase()) {
          continue;
        }

        let current = exerciseMap.get(normName);
        if (!current) {
          current = {
            topWeight: { weight: 0, reps: 0, date: dateStr, sessionTitle: w.sessionTitle },
            topSessionVolume: { volume: 0, date: dateStr, sessionTitle: w.sessionTitle },
          };
          exerciseMap.set(normName, current);
        }

        let sessionVolume = 0;
        for (const s of ex.setRecords || []) {
          const wgt = Number(s.actualWeight) || 0;
          const rps = Number(s.actualReps) || 0;
          sessionVolume += wgt * rps;

          if (wgt > current.topWeight.weight || (wgt === current.topWeight.weight && rps > current.topWeight.reps)) {
            current.topWeight = {
              weight: wgt,
              reps: rps,
              date: dateStr,
              sessionTitle: w.sessionTitle,
            };
          }
        }

        if (sessionVolume > current.topSessionVolume.volume) {
          current.topSessionVolume = {
            volume: sessionVolume,
            date: dateStr,
            sessionTitle: w.sessionTitle,
          };
        }
      }
    }

    for (const [name, data] of exerciseMap.entries()) {
      if (data.topWeight.weight > 0) {
        pbs.push({
          exerciseName: name,
          metric: 'HIGHEST_WEIGHT',
          metricLabel: 'Highest Recorded Weight',
          value: round2(data.topWeight.weight),
          unit: 'kg',
          secondaryMetric: `${data.topWeight.reps} reps`,
          date: data.topWeight.date,
          sessionTitle: data.topWeight.sessionTitle,
          source: 'ALPHA_X_DATABASE',
        });
      }

      if (data.topSessionVolume.volume > 0) {
        pbs.push({
          exerciseName: name,
          metric: 'HIGHEST_SESSION_VOLUME',
          metricLabel: 'Highest Single-Session Volume',
          value: round2(data.topSessionVolume.volume),
          unit: 'kg',
          date: data.topSessionVolume.date,
          sessionTitle: data.topSessionVolume.sessionTitle,
          source: 'ALPHA_X_DATABASE',
        });
      }
    }

    return pbs;
  }

  /**
   * Deterministically calculates overall and exercise-specific intensity (RPE and RIR).
   */
  public analyzeIntensity(workouts: RawWorkoutSessionEntry[]): WorkoutIntensityAnalysis {
    const validRpes: number[] = [];
    const validRirs: number[] = [];

    const exMap = new Map<string, { rpes: number[]; rirs: number[]; sets: number }>();

    for (const w of workouts) {
      if (w.averageRpe !== null && w.averageRpe !== undefined && w.averageRpe > 0) {
        validRpes.push(Number(w.averageRpe));
      }
      if (w.averageRir !== null && w.averageRir !== undefined && w.averageRir >= 0) {
        validRirs.push(Number(w.averageRir));
      }

      for (const ex of w.exerciseRecords || []) {
        if (ex.isSkipped) continue;
        const normName = ex.exerciseName.trim();
        const current = exMap.get(normName) || { rpes: [], rirs: [], sets: 0 };

        for (const s of ex.setRecords || []) {
          current.sets++;
          if (s.actualRpe !== null && s.actualRpe !== undefined && s.actualRpe > 0) {
            current.rpes.push(Number(s.actualRpe));
          }
          if (s.actualRir !== null && s.actualRir !== undefined && s.actualRir >= 0) {
            current.rirs.push(Number(s.actualRir));
          }
        }
        exMap.set(normName, current);
      }
    }

    const averageRpe = safeAverage(validRpes);
    const minRpe = safeMin(validRpes);
    const maxRpe = safeMax(validRpes);

    const averageRir = safeAverage(validRirs);
    const minRir = safeMin(validRirs);
    const maxRir = safeMax(validRirs);

    const exerciseIntensities = Array.from(exMap.entries()).map(([name, data]) => ({
      exerciseName: name,
      averageRpe: safeAverage(data.rpes),
      averageRir: safeAverage(data.rirs),
      setsCount: data.sets,
    }));

    return {
      averageRpe,
      minRpe,
      maxRpe,
      averageRir,
      minRir,
      maxRir,
      rpeRecordCount: validRpes.length,
      rirRecordCount: validRirs.length,
      exerciseIntensities,
      units: {
        rpe: 'RPE (1-10)',
        rir: 'RIR',
      },
      note: 'Descriptive perceived effort metrics based on recorded logs. Does not diagnose fatigue or clinical recovery.',
    };
  }

  /**
   * Deterministically compares workout volume, sessions, and intensity between two time periods.
   */
  public comparePeriods(
    currentWorkouts: RawWorkoutSessionEntry[],
    previousWorkouts: RawWorkoutSessionEntry[],
    dateSpans: PeriodComparisonDateSpans
  ): PeriodComparisonAnalysis {
    const curVolList = currentWorkouts.map((w) => Math.max(Number(w.totalVolume) || 0, 0));
    const curTotalVol = round2(curVolList.reduce((acc, c) => acc + c, 0));
    const curAvgVol = currentWorkouts.length > 0 ? round2(curTotalVol / currentWorkouts.length) : 0;
    const curRpe = safeAverage(currentWorkouts.map((w) => w.averageRpe).filter((r): r is number => typeof r === 'number'));
    const curRir = safeAverage(currentWorkouts.map((w) => w.averageRir).filter((r): r is number => typeof r === 'number'));

    const prevVolList = previousWorkouts.map((w) => Math.max(Number(w.totalVolume) || 0, 0));
    const prevTotalVol = round2(prevVolList.reduce((acc, c) => acc + c, 0));
    const prevAvgVol = previousWorkouts.length > 0 ? round2(prevTotalVol / previousWorkouts.length) : 0;
    const prevRpe = safeAverage(previousWorkouts.map((w) => w.averageRpe).filter((r): r is number => typeof r === 'number'));
    const prevRir = safeAverage(previousWorkouts.map((w) => w.averageRir).filter((r): r is number => typeof r === 'number'));

    const volumeDeltaKg = round2(curTotalVol - prevTotalVol);
    const volumePercentageChange = prevTotalVol > 0
      ? round2(((curTotalVol - prevTotalVol) / prevTotalVol) * 100)
      : null;
    const sessionCountDelta = currentWorkouts.length - previousWorkouts.length;
    const rpeDelta = curRpe !== null && prevRpe !== null ? round2(curRpe - prevRpe) : null;

    let direction: 'INCREASED' | 'DECREASED' | 'UNCHANGED' = 'UNCHANGED';
    if (volumeDeltaKg > 0) direction = 'INCREASED';
    else if (volumeDeltaKg < 0) direction = 'DECREASED';

    return {
      currentPeriod: {
        startDate: dateSpans.current.startDateStr,
        endDate: dateSpans.current.endDateStr,
        daysCount: dateSpans.current.days,
        sessionCount: currentWorkouts.length,
        totalVolumeKg: curTotalVol,
        averageSessionVolumeKg: curAvgVol,
        averageRpe: curRpe,
        averageRir: curRir,
      },
      previousPeriod: {
        startDate: dateSpans.previous.startDateStr,
        endDate: dateSpans.previous.endDateStr,
        daysCount: dateSpans.previous.days,
        sessionCount: previousWorkouts.length,
        totalVolumeKg: prevTotalVol,
        averageSessionVolumeKg: prevAvgVol,
        averageRpe: prevRpe,
        averageRir: prevRir,
      },
      comparison: {
        volumeDeltaKg,
        volumePercentageChange,
        sessionCountDelta,
        rpeDelta,
        direction,
      },
    };
  }

  /**
   * Deterministically calculates training frequency, consistency, active weeks, and exercise occurrences.
   */
  public analyzeFrequency(
    workouts: RawWorkoutSessionEntry[],
    exerciseToMuscleMap: Map<string, string[]> = new Map(),
    plannedSessionsCount?: number
  ): TrainingFrequencyAnalysis {
    const sessionAnalysis = this.analyzeSessions(workouts);

    // Active calendar weeks count
    const weekMap = new Map<string, number>();
    for (const w of workouts) {
      const d = w.startedAt instanceof Date ? w.startedAt : new Date(w.startedAt);
      const year = d.getUTCFullYear();
      const oneJan = new Date(Date.UTC(year, 0, 1));
      const weekNum = Math.ceil(((d.getTime() - oneJan.getTime()) / 86400000 + oneJan.getUTCDay() + 1) / 7);
      const key = `${year}-W${weekNum}`;
      weekMap.set(key, (weekMap.get(key) || 0) + 1);
    }

    const activeWeeksCount = weekMap.size;
    const totalPossibleWeeks = Math.max(activeWeeksCount, Math.ceil(sessionAnalysis.trainingDaysCount / 7));
    const inactiveWeeksCount = Math.max(0, totalPossibleWeeks - activeWeeksCount);

    // Exercise frequency occurrences
    const exCountMap = new Map<string, number>();
    for (const w of workouts) {
      const seenInSession = new Set<string>();
      for (const ex of w.exerciseRecords || []) {
        if (ex.isSkipped) continue;
        seenInSession.add(ex.exerciseName.trim());
      }
      for (const name of seenInSession) {
        exCountMap.set(name, (exCountMap.get(name) || 0) + 1);
      }
    }

    const exerciseFrequencies = Array.from(exCountMap.entries())
      .map(([name, count]) => ({
        exerciseName: name,
        frequencyCount: count,
        frequencyPercentage: workouts.length > 0 ? round2((count / workouts.length) * 100) : 0,
      }))
      .sort((a, b) => b.frequencyCount - a.frequencyCount);

    // Muscle group frequency
    const muscleCountMap = new Map<string, number>();
    for (const [name, count] of exCountMap.entries()) {
      const muscles = exerciseToMuscleMap.get(name.toLowerCase()) || [];
      for (const m of muscles) {
        muscleCountMap.set(m, (muscleCountMap.get(m) || 0) + count);
      }
    }

    const totalMuscleOccurrences = Array.from(muscleCountMap.values()).reduce((a, b) => a + b, 0);
    const muscleGroupFrequencies = Array.from(muscleCountMap.entries())
      .map(([m, count]) => ({
        muscleGroup: m,
        sessionCount: count,
        percentage: totalMuscleOccurrences > 0 ? round2((count / totalMuscleOccurrences) * 100) : 0,
      }))
      .sort((a, b) => b.sessionCount - a.sessionCount);

    let plannedVsCompleted: any = undefined;
    if (typeof plannedSessionsCount === 'number' && plannedSessionsCount > 0) {
      plannedVsCompleted = {
        plannedSessionsCount,
        completedSessionsCount: sessionAnalysis.completedSessionsCount,
        completionPercentage: round2((sessionAnalysis.completedSessionsCount / plannedSessionsCount) * 100),
      };
    }

    return {
      averageSessionsPerWeek: sessionAnalysis.averageWeeklySessions,
      sessionsPerMonth: sessionAnalysis.sessionsPerMonth,
      trainingDaysCount: sessionAnalysis.trainingDaysCount,
      activeWeeksCount,
      inactiveWeeksCount,
      averageDaysBetweenSessions: sessionAnalysis.averageGapDays,
      longestGapDays: sessionAnalysis.longestGapDays,
      exerciseFrequencies,
      muscleGroupFrequencies,
      plannedVsCompleted,
    };
  }
}

export const workoutIntelligenceCalculator = new WorkoutIntelligenceCalculator();
