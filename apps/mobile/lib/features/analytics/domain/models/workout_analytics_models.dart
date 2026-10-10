import 'package:alpha_x_gym/features/workout/domain/models/workout_models.dart';

/// Timeframe filter for Workout Analytics
enum AnalyticsPeriod {
  sevenDays,
  thirtyDays,
  ninetyDays,
}

extension AnalyticsPeriodExtension on AnalyticsPeriod {
  String get label {
    switch (this) {
      case AnalyticsPeriod.sevenDays:
        return '7D';
      case AnalyticsPeriod.thirtyDays:
        return '30D';
      case AnalyticsPeriod.ninetyDays:
        return '90D';
    }
  }

  int get daysCount {
    switch (this) {
      case AnalyticsPeriod.sevenDays:
        return 7;
      case AnalyticsPeriod.thirtyDays:
        return 30;
      case AnalyticsPeriod.ninetyDays:
        return 90;
    }
  }
}

/// A. Weekly Overview Data
class WeeklyOverviewData {
  final int completedSessions;
  final double totalVolumeKg;
  final int prsAchieved;
  final double consistencyRate; // 0.0 to 1.0 (or percentage)
  final int daysTrained;
  final int targetDays;

  // Comparison with previous week
  final int prevWeekSessions;
  final double prevWeekVolumeKg;
  final int prevWeekPRs;
  final double? volumeChangePercent; // e.g. +12.5% or -5.0%
  final int sessionsDiff;
  final int prsDiff;

  const WeeklyOverviewData({
    required this.completedSessions,
    required this.totalVolumeKg,
    required this.prsAchieved,
    required this.consistencyRate,
    required this.daysTrained,
    this.targetDays = 4,
    required this.prevWeekSessions,
    required this.prevWeekVolumeKg,
    required this.prevWeekPRs,
    this.volumeChangePercent,
    required this.sessionsDiff,
    required this.prsDiff,
  });

  String get formattedVolume {
    if (totalVolumeKg >= 1000) {
      final k = totalVolumeKg / 1000.0;
      return '${k.toStringAsFixed(1)}k kg';
    }
    return '${totalVolumeKg.toInt()} kg';
  }

  String get volumeChangeText {
    if (volumeChangePercent == null) return 'Baseline';
    final sign = volumeChangePercent! >= 0 ? '+' : '';
    return '$sign${volumeChangePercent!.toStringAsFixed(1)}% vs last wk';
  }

  String get sessionsDiffText {
    if (sessionsDiff > 0) return '+$sessionsDiff vs last wk';
    if (sessionsDiff < 0) return '$sessionsDiff vs last wk';
    return 'Equal to last wk';
  }
}

/// B. Weekly Report Data
class WeeklyReportData {
  final int completedWorkouts;
  final int plannedWorkouts;
  final double completionPercentage; // 0 to 100
  final int totalCompletedSets;
  final int totalReps;
  final double totalVolumeKg;
  final int prsAchieved;
  final List<PersonalRecord> prDetails;
  final List<String> muscleGroupsTrained;
  final String summaryNarrative;

  const WeeklyReportData({
    required this.completedWorkouts,
    required this.plannedWorkouts,
    required this.completionPercentage,
    required this.totalCompletedSets,
    required this.totalReps,
    required this.totalVolumeKg,
    required this.prsAchieved,
    required this.prDetails,
    required this.muscleGroupsTrained,
    required this.summaryNarrative,
  });

  String get formattedVolume {
    if (totalVolumeKg >= 1000) {
      final k = totalVolumeKg / 1000.0;
      return '${k.toStringAsFixed(1)}k kg';
    }
    return '${totalVolumeKg.toInt()} kg';
  }
}

/// Muscle group training metrics
class MuscleGroupStat {
  final String muscleGroup;
  final int totalSets;
  final int frequencyDays; // Distinct workout days targeting this muscle
  final double totalVolumeKg;
  final double relativeSharePercent; // 0 to 100% of total sets

  const MuscleGroupStat({
    required this.muscleGroup,
    required this.totalSets,
    required this.frequencyDays,
    required this.totalVolumeKg,
    required this.relativeSharePercent,
  });

  String get formattedVolume {
    if (totalVolumeKg >= 1000) {
      final k = totalVolumeKg / 1000.0;
      return '${k.toStringAsFixed(1)}k kg';
    }
    return '${totalVolumeKg.toInt()} kg';
  }
}

/// C. Muscle Tracker Data
class MuscleTrackerData {
  final AnalyticsPeriod period;
  final List<MuscleGroupStat> stats;
  final double totalVolumeKg;
  final int totalSets;

  const MuscleTrackerData({
    required this.period,
    required this.stats,
    required this.totalVolumeKg,
    required this.totalSets,
  });

  bool get isEmpty => stats.isEmpty || totalSets == 0;
}

/// A point along the 1RM progression curve
class Exercise1RMTrendPoint {
  final DateTime date;
  final double estimated1RM;
  final double weight;
  final int reps;

  const Exercise1RMTrendPoint({
    required this.date,
    required this.estimated1RM,
    required this.weight,
    required this.reps,
  });
}

/// D. Exercise Analytics Data
class ExerciseAnalyticsData {
  final String exerciseId;
  final String exerciseName;
  final AnalyticsPeriod period;
  final List<Exercise1RMTrendPoint> trendPoints;
  final double bestRecordedWeight;
  final int bestWeightReps;
  final double peakEstimated1RM;
  final double? progressPercent;

  const ExerciseAnalyticsData({
    required this.exerciseId,
    required this.exerciseName,
    required this.period,
    required this.trendPoints,
    required this.bestRecordedWeight,
    required this.bestWeightReps,
    required this.peakEstimated1RM,
    this.progressPercent,
  });

  bool get hasData => trendPoints.isNotEmpty && bestRecordedWeight > 0;

  String get formattedBestWeight {
    if (bestRecordedWeight <= 0) return '—';
    final str = bestRecordedWeight % 1 == 0
        ? bestRecordedWeight.toInt().toString()
        : bestRecordedWeight.toStringAsFixed(1);
    return '$str kg × $bestWeightReps';
  }

  String get formattedPeak1RM {
    if (peakEstimated1RM <= 0) return '—';
    return '${peakEstimated1RM.toStringAsFixed(1)} kg';
  }

  String get formattedProgress {
    if (progressPercent == null) return 'Baseline';
    final sign = progressPercent! >= 0 ? '+' : '';
    return '$sign${progressPercent!.toStringAsFixed(1)}%';
  }
}
