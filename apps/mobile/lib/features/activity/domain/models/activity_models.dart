import 'package:intl/intl.dart';

/// Status of activity record synchronization with the Alpha X Gym backend
enum SyncStatus {
  synced,
  pending,
  syncing,
  failed,
}

extension SyncStatusExtension on SyncStatus {
  String get displayName {
    switch (this) {
      case SyncStatus.synced:
        return 'Synced';
      case SyncStatus.pending:
        return 'Sync pending';
      case SyncStatus.syncing:
        return 'Syncing...';
      case SyncStatus.failed:
        return 'Sync failed';
    }
  }
}

/// Authorization status for device health platform (HealthKit / Health Connect)
enum HealthConnectionStatus {
  notConfigured,
  authorized,
  denied,
  unavailable,
}

/// Representation of a single local calendar day's aggregated activity
class DailyActivityRecord {
  final String id;
  final String clientId;
  final DateTime date; // Local midnight date (00:00:00.000)
  final int steps;
  final int stepGoal;
  final int cardioMinutes;
  final double caloriesBurned;
  final double distanceMeters;
  final bool isGoalAchieved;
  final SyncStatus syncStatus;
  final DateTime? lastSyncedAt;

  const DailyActivityRecord({
    required this.id,
    required this.clientId,
    required this.date,
    required this.steps,
    required this.stepGoal,
    this.cardioMinutes = 0,
    this.caloriesBurned = 0.0,
    this.distanceMeters = 0.0,
    required this.isGoalAchieved,
    this.syncStatus = SyncStatus.pending,
    this.lastSyncedAt,
  });

  /// Raw progress ratio (e.g. 1.25 for 7500 / 6000) used for internal analytics
  double get rawProgressRatio => stepGoal > 0 ? steps / stepGoal : 0.0;

  /// Visual progress clamped to 1.0 (100%) so progress bars/rings do not exceed 100%
  double get visualProgressClamped => rawProgressRatio.clamp(0.0, 1.0);

  /// Visual progress percentage integer (capped at 100)
  int get visualPercentage => (visualProgressClamped * 100).round();

  /// Actual percentage integer (can exceed 100, e.g. 125%)
  int get actualPercentage => (rawProgressRatio * 100).round();

  /// Steps remaining until goal is reached
  int get remainingSteps => (stepGoal - steps) > 0 ? (stepGoal - steps) : 0;

  /// Whether the user exceeded their daily step goal
  bool get isExceeded => steps > stepGoal;

  /// Excess steps achieved beyond the goal
  int get exceededSteps => isExceeded ? (steps - stepGoal) : 0;

  /// Formatted date string (e.g., 'Sep 23' or 'Today')
  String formattedDate({DateTime? relativeTo}) {
    final now = relativeTo ?? DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final recordMidnight = DateTime(date.year, date.month, date.day);
    final difference = todayMidnight.difference(recordMidnight).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    return DateFormat('MMM d').format(date);
  }

  /// Day of week abbreviation ('Mon', 'Tue', etc.)
  String get dayOfWeekShort => DateFormat('E').format(date);

  /// Formatted number helper (e.g., 5,420)
  String get formattedSteps => NumberFormat('#,###').format(steps);
  String get formattedGoal => NumberFormat('#,###').format(stepGoal);
  String get formattedRemaining => NumberFormat('#,###').format(remainingSteps);
  String get formattedExceeded => NumberFormat('#,###').format(exceededSteps);

  DailyActivityRecord copyWith({
    String? id,
    String? clientId,
    DateTime? date,
    int? steps,
    int? stepGoal,
    int? cardioMinutes,
    double? caloriesBurned,
    double? distanceMeters,
    bool? isGoalAchieved,
    SyncStatus? syncStatus,
    DateTime? lastSyncedAt,
  }) {
    final newSteps = steps ?? this.steps;
    final newGoal = stepGoal ?? this.stepGoal;
    return DailyActivityRecord(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      date: date ?? this.date,
      steps: newSteps,
      stepGoal: newGoal,
      cardioMinutes: cardioMinutes ?? this.cardioMinutes,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      isGoalAchieved: isGoalAchieved ?? (newSteps >= newGoal),
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clientId': clientId,
      'date': DateFormat('yyyy-MM-dd').format(date),
      'steps': steps,
      'stepGoal': stepGoal,
      'cardioMinutes': cardioMinutes,
      'caloriesBurned': caloriesBurned,
      'distanceMeters': distanceMeters,
      'isGoalAchieved': isGoalAchieved,
      'syncStatus': syncStatus.name,
      'lastSyncedAt': lastSyncedAt?.toIso8601String(),
    };
  }

  factory DailyActivityRecord.fromJson(Map<String, dynamic> json) {
    final dateParts = (json['date'] as String).split('-');
    final recordDate = DateTime(
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
    );

    final steps = json['steps'] as int? ?? 0;
    final stepGoal = json['stepGoal'] as int? ?? 6000;

    return DailyActivityRecord(
      id: json['id'] as String? ?? 'rec_${recordDate.millisecondsSinceEpoch}',
      clientId: json['clientId'] as String? ?? 'client_default',
      date: recordDate,
      steps: steps,
      stepGoal: stepGoal,
      cardioMinutes: json['cardioMinutes'] as int? ?? 0,
      caloriesBurned: (json['caloriesBurned'] as num?)?.toDouble() ?? 0.0,
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0.0,
      isGoalAchieved: json['isGoalAchieved'] as bool? ?? (steps >= stepGoal),
      syncStatus: SyncStatus.values.firstWhere(
        (e) => e.name == json['syncStatus'],
        orElse: () => SyncStatus.pending,
      ),
      lastSyncedAt: json['lastSyncedAt'] != null
          ? DateTime.tryParse(json['lastSyncedAt'] as String)
          : null,
    );
  }
}

/// Profile used by trainers and clients to manage individual goals and high-level stats
class ClientActivityProfile {
  final String clientId;
  final String clientName;
  final String avatarUrl;
  final int dailyStepGoal;
  final DateTime effectiveDate;
  final int todaySteps;
  final int weeklyAverage;
  final int goalDaysAchievedWeek;
  final int totalDaysWeek;

  const ClientActivityProfile({
    required this.clientId,
    required this.clientName,
    this.avatarUrl = '',
    required this.dailyStepGoal,
    required this.effectiveDate,
    required this.todaySteps,
    required this.weeklyAverage,
    required this.goalDaysAchievedWeek,
    this.totalDaysWeek = 7,
  });

  double get todayProgress => dailyStepGoal > 0 ? (todaySteps / dailyStepGoal).clamp(0.0, 1.0) : 0.0;
  int get todayPercentage => (todayProgress * 100).round();
  bool get isTodayGoalAchieved => todaySteps >= dailyStepGoal;

  ClientActivityProfile copyWith({
    String? clientId,
    String? clientName,
    String? avatarUrl,
    int? dailyStepGoal,
    DateTime? effectiveDate,
    int? todaySteps,
    int? weeklyAverage,
    int? goalDaysAchievedWeek,
    int? totalDaysWeek,
  }) {
    return ClientActivityProfile(
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      dailyStepGoal: dailyStepGoal ?? this.dailyStepGoal,
      effectiveDate: effectiveDate ?? this.effectiveDate,
      todaySteps: todaySteps ?? this.todaySteps,
      weeklyAverage: weeklyAverage ?? this.weeklyAverage,
      goalDaysAchievedWeek: goalDaysAchievedWeek ?? this.goalDaysAchievedWeek,
      totalDaysWeek: totalDaysWeek ?? this.totalDaysWeek,
    );
  }
}

/// 7-day analytics roll-up
class WeeklyActivitySummary {
  final List<DailyActivityRecord> days;
  final int weeklyAverage;
  final int totalSteps;
  final int daysGoalAchieved;
  final DailyActivityRecord? bestDay;
  final DailyActivityRecord? lowestDay;

  const WeeklyActivitySummary({
    required this.days,
    required this.weeklyAverage,
    required this.totalSteps,
    required this.daysGoalAchieved,
    this.bestDay,
    this.lowestDay,
  });

  factory WeeklyActivitySummary.calculate(List<DailyActivityRecord> records) {
    if (records.isEmpty) {
      return const WeeklyActivitySummary(
        days: [],
        weeklyAverage: 0,
        totalSteps: 0,
        daysGoalAchieved: 0,
      );
    }

    final total = records.fold<int>(0, (sum, r) => sum + r.steps);
    final avg = (total / records.length).round();
    final achievedCount = records.where((r) => r.isGoalAchieved).length;

    DailyActivityRecord? best = records.first;
    DailyActivityRecord? lowest = records.first;

    for (final r in records) {
      if (r.steps > (best?.steps ?? 0)) best = r;
      if (r.steps < (lowest?.steps ?? double.infinity)) lowest = r;
    }

    return WeeklyActivitySummary(
      days: records,
      weeklyAverage: avg,
      totalSteps: total,
      daysGoalAchieved: achievedCount,
      bestDay: best,
      lowestDay: lowest,
    );
  }
}

/// Monthly summary with navigation support
class MonthlyActivitySummary {
  final int year;
  final int month;
  final String monthName;
  final int totalSteps;
  final int averageStepsPerDay;
  final double goalAchievementRate;
  final int daysGoalAchieved;
  final int totalDaysInMonth;
  final DailyActivityRecord? bestDay;

  const MonthlyActivitySummary({
    required this.year,
    required this.month,
    required this.monthName,
    required this.totalSteps,
    required this.averageStepsPerDay,
    required this.goalAchievementRate,
    required this.daysGoalAchieved,
    required this.totalDaysInMonth,
    this.bestDay,
  });

  factory MonthlyActivitySummary.calculate({
    required int year,
    required int month,
    required List<DailyActivityRecord> recordsInMonth,
  }) {
    final monthDate = DateTime(year, month);
    final monthName = DateFormat('MMMM yyyy').format(monthDate);
    final totalDaysInMonth = DateTime(year, month + 1, 0).day;

    if (recordsInMonth.isEmpty) {
      return MonthlyActivitySummary(
        year: year,
        month: month,
        monthName: monthName,
        totalSteps: 0,
        averageStepsPerDay: 0,
        goalAchievementRate: 0.0,
        daysGoalAchieved: 0,
        totalDaysInMonth: totalDaysInMonth,
      );
    }

    final total = recordsInMonth.fold<int>(0, (sum, r) => sum + r.steps);
    final avg = (total / recordsInMonth.length).round();
    final achieved = recordsInMonth.where((r) => r.isGoalAchieved).length;
    final rate = recordsInMonth.isNotEmpty ? (achieved / recordsInMonth.length) : 0.0;

    DailyActivityRecord? best = recordsInMonth.first;
    for (final r in recordsInMonth) {
      if (r.steps > (best?.steps ?? 0)) best = r;
    }

    return MonthlyActivitySummary(
      year: year,
      month: month,
      monthName: monthName,
      totalSteps: total,
      averageStepsPerDay: avg,
      goalAchievementRate: rate,
      daysGoalAchieved: achieved,
      totalDaysInMonth: totalDaysInMonth,
      bestDay: best,
    );
  }
}
