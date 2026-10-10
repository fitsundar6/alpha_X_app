import 'dart:async';
import 'package:alpha_x_gym/features/activity/domain/models/activity_models.dart';

enum StepSource { unavailable }

/// Production Health Data Service
/// Step tracking has been completely decommissioned and removed.
class HealthService {
  StepSource get activeSource => StepSource.unavailable;
  String get stepSourceLabel => 'Disabled';

  void Function(int steps)? onLiveStepUpdate;

  Future<void> initialize() async {}

  Future<bool> isHealthConnectAvailable() async => false;
  Future<void> installHealthConnect() async {}

  void stopPedometerStream() {}

  Future<int> fetchTodaySteps({DateTime? since}) async => 0;
  Future<int> fetchStepsForInterval(DateTime startTime, DateTime endTime) async => 0;

  Future<Map<String, dynamic>> fetchDailyMetrics(DateTime date) async => {
    'calories': 0.0,
    'distance': 0.0,
    'cardioMinutes': 0,
  };

  Future<List<DailyActivityRecord>> fetchHistoricalDays({
    required String clientId,
    required int stepGoal,
    DateTime? since,
    int daysCount = 30,
  }) async => [];

  Future<bool> isHealthServiceAvailable() async => false;
  Future<bool> requestPermissions() async => false;
  Future<bool> hasPermissions() async => false;
  Future<void> revokePermissions() async {}

  DateTime getLocalStartOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 0, 0, 0, 0);

  DateTime getLocalEndOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
}
