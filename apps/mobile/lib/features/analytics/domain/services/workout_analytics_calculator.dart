import 'package:alpha_x_gym/features/analytics/domain/models/workout_analytics_models.dart';
import 'package:alpha_x_gym/features/exercise/data/repositories/exercise_repository.dart';
import 'package:alpha_x_gym/features/exercise/domain/models/exercise_model.dart';
import 'package:alpha_x_gym/features/workout/domain/models/workout_models.dart';

/// Pure, deterministic calculator for all Workout Analytics metrics.
class WorkoutAnalyticsCalculator {
  /// Brzycki 1RM Estimation Formula:
  /// 1RM = Weight × 36 / (37 − Reps)
  ///
  /// Boundary & Safety Rules:
  /// - Weight must be positive and realistic (> 0 and <= 10000).
  /// - Reps must be between 1 and 36 inclusive.
  /// - Reps == 1 returns Weight exactly.
  /// - Reps >= 37 is rejected (division by zero / negative denominator).
  /// - Reps < 1 or Weight <= 0 is rejected.
  /// - Non-finite values (NaN, Infinity) are rejected.
  static double? calculateBrzycki1RM(double weight, int reps) {
    if (weight <= 0 || weight.isNaN || weight.isInfinite || weight > 10000) {
      return null;
    }
    if (reps < 1 || reps >= 37) {
      return null;
    }
    if (reps == 1) {
      return (weight * 10).round() / 10.0;
    }
    final estimated = weight * 36.0 / (37.0 - reps);
    if (estimated.isNaN || estimated.isInfinite || estimated <= 0) {
      return null;
    }
    return (estimated * 10).round() / 10.0;
  }

  /// Calculates training volume for a single set: Weight × Reps
  /// Only completed sets with valid positive values are counted.
  static double calculateSetVolume(ExerciseSet set) {
    if (!set.isCompleted) return 0.0;
    final w = set.actualWeight;
    final r = set.actualReps;
    if (w == null || w <= 0 || r == null || r <= 0) return 0.0;
    if (w.isNaN || w.isInfinite || w > 10000 || r > 10000) return 0.0;
    return w * r;
  }

  /// Calculates total training volume for a list of exercises
  static double calculateExercisesVolume(List<WorkoutExercise> exercises) {
    double total = 0.0;
    for (final ex in exercises) {
      if (ex.isSkipped) continue;
      for (final set in ex.sets) {
        total += calculateSetVolume(set);
      }
    }
    return total;
  }

  /// A. Weekly Overview Calculation
  static WeeklyOverviewData calculateWeeklyOverview(
    List<WorkoutRecord> records, {
    DateTime? now,
    int targetDays = 4,
  }) {
    final refDate = now ?? DateTime.now();
    final weekStart = refDate.subtract(const Duration(days: 7));
    final prevWeekStart = refDate.subtract(const Duration(days: 14));

    // Filter completed records
    final completedRecords = records.where((r) => r.isCompleted).toList();

    // Current Week (Last 7 Days)
    final currWeekRecords = completedRecords.where((r) {
      final date = r.completedAt ?? r.startedAt;
      return date.isAfter(weekStart) && !date.isAfter(refDate);
    }).toList();

    // Previous Week (Days 8 to 14 ago)
    final prevWeekRecords = completedRecords.where((r) {
      final date = r.completedAt ?? r.startedAt;
      return date.isAfter(prevWeekStart) && !date.isAfter(weekStart);
    }).toList();

    // Current week metrics
    final completedSessions = currWeekRecords.length;
    double totalVolumeKg = 0.0;
    int prsAchieved = 0;
    final trainedDaysSet = <String>{};

    for (final r in currWeekRecords) {
      totalVolumeKg += calculateExercisesVolume(r.exercises);
      prsAchieved += r.personalRecords.length;
      final d = r.completedAt ?? r.startedAt;
      trainedDaysSet.add('${d.year}-${d.month}-${d.day}');
    }

    final daysTrained = trainedDaysSet.length;
    final consistencyRate = targetDays > 0
        ? (daysTrained / targetDays).clamp(0.0, 1.0)
        : (daysTrained / 7.0).clamp(0.0, 1.0);

    // Previous week metrics
    final prevWeekSessions = prevWeekRecords.length;
    double prevWeekVolumeKg = 0.0;
    int prevWeekPRs = 0;

    for (final r in prevWeekRecords) {
      prevWeekVolumeKg += calculateExercisesVolume(r.exercises);
      prevWeekPRs += r.personalRecords.length;
    }

    // Comparison diffs
    final sessionsDiff = completedSessions - prevWeekSessions;
    final prsDiff = prsAchieved - prevWeekPRs;
    double? volumeChangePercent;
    if (prevWeekVolumeKg > 0) {
      volumeChangePercent =
          ((totalVolumeKg - prevWeekVolumeKg) / prevWeekVolumeKg) * 100.0;
      volumeChangePercent = (volumeChangePercent * 10).round() / 10.0;
    } else if (prevWeekVolumeKg == 0 && totalVolumeKg > 0) {
      volumeChangePercent = null; // Baseline
    } else {
      volumeChangePercent = 0.0;
    }

    return WeeklyOverviewData(
      completedSessions: completedSessions,
      totalVolumeKg: totalVolumeKg,
      prsAchieved: prsAchieved,
      consistencyRate: consistencyRate,
      daysTrained: daysTrained,
      targetDays: targetDays,
      prevWeekSessions: prevWeekSessions,
      prevWeekVolumeKg: prevWeekVolumeKg,
      prevWeekPRs: prevWeekPRs,
      volumeChangePercent: volumeChangePercent,
      sessionsDiff: sessionsDiff,
      prsDiff: prsDiff,
    );
  }

  /// B. Weekly Report Calculation
  static WeeklyReportData calculateWeeklyReport(
    List<WorkoutRecord> records, {
    DateTime? now,
    int plannedWorkouts = 4,
  }) {
    final refDate = now ?? DateTime.now();
    final weekStart = refDate.subtract(const Duration(days: 7));

    final currWeekRecords = records.where((r) {
      if (!r.isCompleted) return false;
      final date = r.completedAt ?? r.startedAt;
      return date.isAfter(weekStart) && !date.isAfter(refDate);
    }).toList();

    int totalCompletedSets = 0;
    int totalReps = 0;
    double totalVolumeKg = 0.0;
    final prDetails = <PersonalRecord>[];
    final muscleGroupsSet = <String>{};

    for (final r in currWeekRecords) {
      totalVolumeKg += calculateExercisesVolume(r.exercises);
      prDetails.addAll(r.personalRecords);

      for (final ex in r.exercises) {
        if (ex.isSkipped) continue;

        // Collect muscle groups
        final region = _resolveMuscleRegion(ex);
        if (region.isNotEmpty) muscleGroupsSet.add(region);

        for (final s in ex.sets) {
          if (s.isCompleted && (s.actualReps ?? 0) > 0) {
            totalCompletedSets++;
            totalReps += s.actualReps!;
          }
        }
      }
    }

    final completedWorkouts = currWeekRecords.length;
    final planned = plannedWorkouts > 0 ? plannedWorkouts : 4;
    final completionPercentage =
        ((completedWorkouts / planned) * 100.0).clamp(0.0, 100.0);
    final prsAchieved = prDetails.length;
    final muscleGroupsTrained = muscleGroupsSet.toList()..sort();

    // Generate dynamic factual summary narrative
    final String summaryNarrative;
    if (completedWorkouts == 0) {
      summaryNarrative =
          'No completed workout sessions recorded in the past 7 days. Complete your planned sessions to track your volume, sets, and Personal Records.';
    } else {
      final volStr = totalVolumeKg >= 1000
          ? '${(totalVolumeKg / 1000).toStringAsFixed(1)}k kg'
          : '${totalVolumeKg.toInt()} kg';
      final musclesStr = muscleGroupsTrained.isNotEmpty
          ? muscleGroupsTrained.join(', ')
          : 'Full Body';
      final prSentence = prsAchieved > 0
          ? ' You unlocked $prsAchieved new Personal Record${prsAchieved > 1 ? "s" : ""}!'
          : '';

      summaryNarrative =
          'Outstanding work! You completed $completedWorkouts of $planned planned sessions (${completionPercentage.toInt()}%). '
          'You lifted a total volume of $volStr across $totalCompletedSets completed sets and $totalReps reps, targeting $musclesStr.$prSentence';
    }

    return WeeklyReportData(
      completedWorkouts: completedWorkouts,
      plannedWorkouts: planned,
      completionPercentage: completionPercentage,
      totalCompletedSets: totalCompletedSets,
      totalReps: totalReps,
      totalVolumeKg: totalVolumeKg,
      prsAchieved: prsAchieved,
      prDetails: prDetails,
      muscleGroupsTrained: muscleGroupsTrained,
      summaryNarrative: summaryNarrative,
    );
  }

  /// C. Muscle Tracker Calculation
  static MuscleTrackerData calculateMuscleTracker(
    List<WorkoutRecord> records, {
    required AnalyticsPeriod period,
    DateTime? now,
  }) {
    final refDate = now ?? DateTime.now();
    final cutoff = refDate.subtract(Duration(days: period.daysCount));

    final filteredRecords = records.where((r) {
      if (!r.isCompleted) return false;
      final date = r.completedAt ?? r.startedAt;
      return date.isAfter(cutoff) && !date.isAfter(refDate);
    }).toList();

    // Core anatomical regions
    const coreRegions = ['Chest', 'Back', 'Shoulders', 'Arms', 'Legs', 'Core'];
    final setsMap = <String, int>{for (final m in coreRegions) m: 0};
    final volumeMap = <String, double>{for (final m in coreRegions) m: 0.0};
    final daysMap = <String, Set<String>>{for (final m in coreRegions) m: <String>{}};

    double totalVolumeKg = 0.0;
    int totalSets = 0;

    for (final r in filteredRecords) {
      final recordDateStr =
          '${(r.completedAt ?? r.startedAt).year}-${(r.completedAt ?? r.startedAt).month}-${(r.completedAt ?? r.startedAt).day}';

      for (final ex in r.exercises) {
        if (ex.isSkipped) continue;
        final region = _resolveMuscleRegion(ex);
        if (!coreRegions.contains(region)) continue;

        for (final s in ex.sets) {
          if (s.isCompleted && (s.actualReps ?? 0) > 0) {
            final vol = calculateSetVolume(s);
            setsMap[region] = (setsMap[region] ?? 0) + 1;
            volumeMap[region] = (volumeMap[region] ?? 0.0) + vol;
            daysMap[region]!.add(recordDateStr);

            totalSets++;
            totalVolumeKg += vol;
          }
        }
      }
    }

    final stats = coreRegions.map((region) {
      final s = setsMap[region] ?? 0;
      final v = volumeMap[region] ?? 0.0;
      final f = daysMap[region]?.length ?? 0;
      final share = totalSets > 0 ? (s / totalSets) * 100.0 : 0.0;

      return MuscleGroupStat(
        muscleGroup: region,
        totalSets: s,
        frequencyDays: f,
        totalVolumeKg: v,
        relativeSharePercent: (share * 10).round() / 10.0,
      );
    }).toList();

    return MuscleTrackerData(
      period: period,
      stats: stats,
      totalVolumeKg: totalVolumeKg,
      totalSets: totalSets,
    );
  }

  /// D. Exercise Analytics Calculation
  static ExerciseAnalyticsData calculateExerciseAnalytics(
    List<WorkoutRecord> records, {
    required String exerciseId,
    required String exerciseName,
    required AnalyticsPeriod period,
    DateTime? now,
  }) {
    final refDate = now ?? DateTime.now();
    final cutoff = refDate.subtract(Duration(days: period.daysCount));

    final filteredRecords = records.where((r) {
      if (!r.isCompleted) return false;
      final date = r.completedAt ?? r.startedAt;
      return date.isAfter(cutoff) && !date.isAfter(refDate);
    }).toList()
      ..sort((a, b) =>
          (a.completedAt ?? a.startedAt).compareTo(b.completedAt ?? b.startedAt));

    double bestRecordedWeight = 0.0;
    int bestWeightReps = 0;
    double peakEstimated1RM = 0.0;

    // Map each date to the highest estimated 1RM on that day
    final dateToPeak1RM = <DateTime, Exercise1RMTrendPoint>{};

    for (final r in filteredRecords) {
      final sessionDate = r.completedAt ?? r.startedAt;
      final normalizedDate =
          DateTime(sessionDate.year, sessionDate.month, sessionDate.day);

      for (final ex in r.exercises) {
        if (ex.exerciseId != exerciseId && ex.id != exerciseId) continue;
        if (ex.isSkipped) continue;

        for (final s in ex.sets) {
          if (!s.isCompleted) continue;
          final w = s.actualWeight ?? 0.0;
          final reps = s.actualReps ?? 0;

          if (w <= 0 || reps <= 0) continue;

          // Track best raw weight lifted
          if (w > bestRecordedWeight) {
            bestRecordedWeight = w;
            bestWeightReps = reps;
          } else if (w == bestRecordedWeight && reps > bestWeightReps) {
            bestWeightReps = reps;
          }

          // Compute Brzycki 1RM
          final est1RM = calculateBrzycki1RM(w, reps);
          if (est1RM == null) continue;

          if (est1RM > peakEstimated1RM) {
            peakEstimated1RM = est1RM;
          }

          // Keep highest 1RM of the session/day for smooth trend line
          final existing = dateToPeak1RM[normalizedDate];
          if (existing == null || est1RM > existing.estimated1RM) {
            dateToPeak1RM[normalizedDate] = Exercise1RMTrendPoint(
              date: sessionDate,
              estimated1RM: est1RM,
              weight: w,
              reps: reps,
            );
          }
        }
      }
    }

    final trendPoints = dateToPeak1RM.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    // Calculate progress % from earliest recorded 1RM to latest
    double? progressPercent;
    if (trendPoints.length >= 2) {
      final first1RM = trendPoints.first.estimated1RM;
      final latest1RM = trendPoints.last.estimated1RM;
      if (first1RM > 0) {
        progressPercent = ((latest1RM - first1RM) / first1RM) * 100.0;
        progressPercent = (progressPercent * 10).round() / 10.0;
      }
    }

    return ExerciseAnalyticsData(
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      period: period,
      trendPoints: trendPoints,
      bestRecordedWeight: bestRecordedWeight,
      bestWeightReps: bestWeightReps,
      peakEstimated1RM: peakEstimated1RM,
      progressPercent: progressPercent,
    );
  }

  /// Extracts distinct exercises that have completed sets in client history
  static List<Map<String, String>> extractRecordedExercises(
    List<WorkoutRecord> records,
  ) {
    final Map<String, String> exercises = {};
    for (final r in records.where((r) => r.isCompleted)) {
      for (final ex in r.exercises) {
        if (ex.isSkipped) continue;
        if (ex.sets.any((s) => s.isCompleted && (s.actualReps ?? 0) > 0)) {
          exercises[ex.exerciseId] = ex.exerciseName;
        }
      }
    }
    return exercises.entries
        .map((e) => {'id': e.key, 'name': e.value})
        .toList()
      ..sort((a, b) => a['name']!.compareTo(b['name']!));
  }

  /// Maps an exercise to one of the 6 core anatomical regions:
  /// Chest, Back, Shoulders, Arms, Legs, Core.
  static String _resolveMuscleRegion(WorkoutExercise exercise) {
    // 1. Try ExerciseRepository catalog lookup
    try {
      final catalog = ExerciseRepository().getExerciseById(exercise.exerciseId);
      if (catalog != null && catalog.primaryMuscles.isNotEmpty) {
        final pm = catalog.primaryMuscles.first;
        final mapped = _mapMuscleGroupToRegion(pm);
        if (mapped != null) return mapped;
      }
    } catch (_) {}

    // 2. Try primaryMusclesDisplay text
    final display = exercise.primaryMusclesDisplay.toLowerCase();
    if (display.contains('chest') || display.contains('pec')) return 'Chest';
    if (display.contains('lat') ||
        display.contains('back') ||
        display.contains('trap') ||
        display.contains('rhomboid')) {
      return 'Back';
    }
    if (display.contains('delt') || display.contains('shoulder')) {
      return 'Shoulders';
    }
    if (display.contains('bicep') ||
        display.contains('tricep') ||
        display.contains('arm') ||
        display.contains('forearm')) {
      return 'Arms';
    }
    if (display.contains('quad') ||
        display.contains('hamstring') ||
        display.contains('glute') ||
        display.contains('leg') ||
        display.contains('calve') ||
        display.contains('calf')) {
      return 'Legs';
    }
    if (display.contains('core') ||
        display.contains('ab') ||
        display.contains('oblique')) {
      return 'Core';
    }

    // 3. Fallback to category
    final cat = exercise.category.toLowerCase();
    if (cat.contains('chest')) return 'Chest';
    if (cat.contains('back')) return 'Back';
    if (cat.contains('shoulder')) return 'Shoulders';
    if (cat.contains('arm') || cat.contains('bicep') || cat.contains('tricep')) {
      return 'Arms';
    }
    if (cat.contains('leg') || cat.contains('quad') || cat.contains('glute')) {
      return 'Legs';
    }
    if (cat.contains('core') || cat.contains('abs')) return 'Core';

    return 'Chest';
  }

  static String? _mapMuscleGroupToRegion(MuscleGroup group) {
    switch (group) {
      case MuscleGroup.upperChest:
      case MuscleGroup.midChest:
      case MuscleGroup.lowerChest:
        return 'Chest';
      case MuscleGroup.lats:
      case MuscleGroup.rhomboids:
      case MuscleGroup.traps:
      case MuscleGroup.lowerBack:
        return 'Back';
      case MuscleGroup.frontDelts:
      case MuscleGroup.sideDelts:
      case MuscleGroup.rearDelts:
      case MuscleGroup.shoulders:
        return 'Shoulders';
      case MuscleGroup.biceps:
      case MuscleGroup.triceps:
      case MuscleGroup.forearms:
        return 'Arms';
      case MuscleGroup.quads:
      case MuscleGroup.hamstrings:
      case MuscleGroup.glutes:
      case MuscleGroup.calves:
        return 'Legs';
      case MuscleGroup.coreAbs:
        return 'Core';
      case MuscleGroup.fullBody:
        return 'Back';
    }
  }
}
