import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:alpha_x_gym/features/activity/domain/models/activity_models.dart';

/// Production Health Data Service interfacing with Android Health Connect & iOS HealthKit
class HealthService {
  final Health _health = Health();

  static const List<HealthDataType> _requestedTypes = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.WORKOUT,
  ];

  static const List<HealthDataAccess> _permissions = [
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
  ];

  /// Initialize health configuration if on Android (Health Connect)
  Future<void> initialize() async {
    if (kIsWeb) return;
    try {
      if (Platform.isAndroid) {
        await _health.configure();
      }
    } catch (e) {
      debugPrint('[HealthService] initialize error: $e');
    }
  }

  /// Check whether health platform is available on the current device
  Future<bool> isHealthServiceAvailable() async {
    if (kIsWeb) return false;
    try {
      if (Platform.isAndroid) {
        final status = await _health.getHealthConnectSdkStatus();
        return status == HealthConnectSdkStatus.sdkAvailable;
      } else if (Platform.isIOS) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[HealthService] isHealthServiceAvailable error: $e');
      return false;
    }
  }

  /// Request permissions from Android Health Connect / iOS HealthKit
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    try {
      final available = await isHealthServiceAvailable();
      if (!available && Platform.isAndroid) {
        // Prompt to install Health Connect if missing on Android
        await _health.installHealthConnect();
        return false;
      }

      final granted = await _health.requestAuthorization(
        _requestedTypes,
        permissions: _permissions,
      );

      return granted;
    } catch (e) {
      debugPrint('[HealthService] requestPermissions error: $e');
      return false;
    }
  }

  /// Check whether permissions are currently granted
  Future<bool> hasPermissions() async {
    if (kIsWeb) return false;
    try {
      final has = await _health.hasPermissions(
        _requestedTypes,
        permissions: _permissions,
      );
      return has ?? false;
    } catch (e) {
      debugPrint('[HealthService] hasPermissions error: $e');
      return false;
    }
  }

  /// Revoke / disconnect health data
  Future<void> revokePermissions() async {
    if (kIsWeb) return;
    try {
      await _health.revokePermissions();
    } catch (e) {
      debugPrint('[HealthService] revokePermissions error: $e');
    }
  }

  /// Calculate the exact local calendar day start (00:00:00.000)
  DateTime getLocalStartOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 0, 0, 0, 0);
  }

  /// Calculate the exact local calendar day end (23:59:59.999)
  DateTime getLocalEndOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }

  /// Read aggregated steps for today (midnight to current moment, or from [since] if client joined today)
  Future<int> fetchTodaySteps({DateTime? since}) async {
    final now = DateTime.now();
    DateTime startOfToday = getLocalStartOfDay(now);
    if (since != null && since.isAfter(startOfToday)) {
      startOfToday = since;
    }
    return fetchStepsForInterval(startOfToday, now);
  }

  /// Read aggregated steps for an arbitrary time interval using the platform's
  /// native step aggregation mechanism to prevent double-counting overlapping records
  Future<int> fetchStepsForInterval(DateTime startTime, DateTime endTime) async {
    if (kIsWeb) return 0;
    try {
      final totalSteps = await _health.getTotalStepsInInterval(startTime, endTime);
      return totalSteps ?? 0;
    } catch (e) {
      debugPrint('[HealthService] fetchStepsForInterval error: $e');
      return 0;
    }
  }

  /// Fetch additional metrics (cardio minutes, calories, distance) for a single day
  Future<Map<String, dynamic>> fetchDailyMetrics(DateTime date) async {
    final start = getLocalStartOfDay(date);
    final end = getLocalEndOfDay(date);

    double totalCalories = 0.0;
    double totalDistance = 0.0;
    int cardioMinutes = 0;

    if (kIsWeb) {
      return {
        'calories': totalCalories,
        'distance': totalDistance,
        'cardioMinutes': cardioMinutes,
      };
    }

    try {
      final dataPoints = await _health.getHealthDataFromTypes(
        types: [
          HealthDataType.ACTIVE_ENERGY_BURNED,
          HealthDataType.DISTANCE_DELTA,
          HealthDataType.WORKOUT,
        ],
        startTime: start,
        endTime: end,
      );

      // De-duplicate points based on UUID or start-end timestamp intervals
      final seenIds = <String>{};
      for (final point in dataPoints) {
        final pointKey = '${point.typeString}_${point.dateFrom.millisecondsSinceEpoch}_${point.dateTo.millisecondsSinceEpoch}';
        if (seenIds.contains(pointKey)) continue;
        seenIds.add(pointKey);

        if (point.type == HealthDataType.ACTIVE_ENERGY_BURNED) {
          final val = point.value;
          if (val is NumericHealthValue) {
            totalCalories += val.numericValue.toDouble();
          }
        } else if (point.type == HealthDataType.DISTANCE_DELTA) {
          final val = point.value;
          if (val is NumericHealthValue) {
            totalDistance += val.numericValue.toDouble();
          }
        } else if (point.type == HealthDataType.WORKOUT) {
          final diff = point.dateTo.difference(point.dateFrom).inMinutes;
          cardioMinutes += diff > 0 ? diff : 0;
        }
      }
    } catch (e) {
      debugPrint('[HealthService] fetchDailyMetrics error: $e');
    }

    return {
      'calories': totalCalories,
      'distance': totalDistance,
      'cardioMinutes': cardioMinutes,
    };
  }

  /// Read historical step records for the specified number of days (default 30 days)
  /// Guaranteed to bucket by exact local calendar day [00:00 to 23:59]
  /// Strictly filters out dates prior to [since] (client joined timestamp).
  Future<List<DailyActivityRecord>> fetchHistoricalDays({
    required String clientId,
    required int stepGoal,
    DateTime? since,
    int daysCount = 30,
  }) async {
    final now = DateTime.now();
    final List<DailyActivityRecord> records = [];
    final startDayLimit = since != null ? getLocalStartOfDay(since) : null;

    for (int i = 0; i < daysCount; i++) {
      final day = now.subtract(Duration(days: i));
      final startOfDay = getLocalStartOfDay(day);

      // Do not query or import days from before the client joined
      if (startDayLimit != null && startOfDay.isBefore(startDayLimit)) {
        break;
      }

      DateTime intervalStart = startOfDay;
      if (since != null && since.isAfter(intervalStart)) {
        intervalStart = since;
      }
      final endOfDay = (i == 0) ? now : getLocalEndOfDay(day);

      final steps = await fetchStepsForInterval(intervalStart, endOfDay);
      final metrics = await fetchDailyMetrics(day);

      final dateMidnight = DateTime(day.year, day.month, day.day);
      final recordId = 'rec_${clientId}_${dateMidnight.year}${dateMidnight.month.toString().padLeft(2, '0')}${dateMidnight.day.toString().padLeft(2, '0')}';

      final calBurned = (metrics['calories'] as double? ?? 0.0);
      final distMeters = (metrics['distance'] as double? ?? 0.0);

      records.add(DailyActivityRecord(
        id: recordId,
        clientId: clientId,
        date: dateMidnight,
        steps: steps,
        stepGoal: stepGoal,
        cardioMinutes: metrics['cardioMinutes'] as int? ?? 0,
        caloriesBurned: steps > 0 ? (calBurned > 0 ? calBurned : steps * 0.045) : 0.0,
        distanceMeters: steps > 0 ? (distMeters > 0 ? distMeters : steps * 0.76) : 0.0,
        isGoalAchieved: steps >= stepGoal,
        syncStatus: SyncStatus.pending,
        lastSyncedAt: null,
      ));
    }

    return records;
  }
}
