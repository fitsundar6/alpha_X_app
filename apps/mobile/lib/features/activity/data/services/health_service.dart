import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:alpha_x_gym/features/activity/domain/models/activity_models.dart';

/// Step data source in use
enum StepSource { healthConnect, pedometer, manual, unavailable }

/// Production Health Data Service
///
/// Priority order for steps:
///   1. Android Health Connect (includes smartwatch data — Wear OS, Galaxy Watch, Fitbit)
///   2. Pedometer (phone's built-in accelerometer — no smartwatch needed)
///   3. Manual entry (user types steps — for web or when sensors are denied)
class HealthService {
  final Health _health = Health();

  /// Which source is currently active
  StepSource _activeSource = StepSource.unavailable;
  StepSource get activeSource => _activeSource;

  /// Live pedometer stream — cumulative steps since phone boot
  StreamSubscription<StepCount>? _pedometerSub;
  StreamSubscription<PedestrianStatus>? _pedestrianStatusSub;
  int _pedometerBootSteps = 0;       // Steps at midnight (boot baseline)
  int _pedometerTodaySteps = 0;      // Steps just for today
  bool _pedometerBaselineSet = false;
  DateTime? _pedometerBaselineDate;

  /// Callback notified whenever live step count updates
  void Function(int steps)? onLiveStepUpdate;

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

  // ─────────────────────────────────────────────────────────────────────────
  // INITIALIZATION
  // ─────────────────────────────────────────────────────────────────────────

  /// Initialize — try Health Connect first, then pedometer as fallback.
  Future<void> initialize() async {
    if (kIsWeb) {
      _activeSource = StepSource.manual;
      return;
    }

    if (Platform.isAndroid) {
      // Try Health Connect first
      final hcOk = await _tryInitHealthConnect();
      if (hcOk) {
        _activeSource = StepSource.healthConnect;
        debugPrint('[HealthService] ✅ Source: Health Connect (includes smartwatch)');
        return;
      }

      // Fallback: phone pedometer
      final pedOk = await _tryInitPedometer();
      if (pedOk) {
        _activeSource = StepSource.pedometer;
        debugPrint('[HealthService] ✅ Source: Phone Pedometer (built-in sensor)');
        return;
      }

      _activeSource = StepSource.manual;
      debugPrint('[HealthService] ⚠️ Source: Manual entry (no sensor available)');
    } else if (Platform.isIOS) {
      // iOS always uses HealthKit (includes Apple Watch automatically)
      final hcOk = await _tryInitHealthConnect();
      _activeSource = hcOk ? StepSource.healthConnect : StepSource.manual;
      debugPrint('[HealthService] Source: ${_activeSource.name}');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HEALTH CONNECT (Android) / HEALTHKIT (iOS) — includes smartwatch data
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> _tryInitHealthConnect() async {
    try {
      if (Platform.isAndroid) {
        final status = await _health.getHealthConnectSdkStatus();
        if (status != HealthConnectSdkStatus.sdkAvailable) {
          debugPrint('[HealthService] Health Connect not available (status: $status)');
          return false;
        }
        await _health.configure();
      }

      final granted = await _health.requestAuthorization(
        _requestedTypes,
        permissions: _permissions,
      );
      return granted;
    } catch (e) {
      debugPrint('[HealthService] Health Connect init error: $e');
      return false;
    }
  }

  Future<bool> isHealthConnectAvailable() async {
    if (kIsWeb) return false;
    try {
      if (Platform.isAndroid) {
        final status = await _health.getHealthConnectSdkStatus();
        return status == HealthConnectSdkStatus.sdkAvailable;
      }
      return Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  Future<void> installHealthConnect() async {
    try {
      await _health.installHealthConnect();
    } catch (e) {
      debugPrint('[HealthService] installHealthConnect error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PEDOMETER — Direct phone sensor (no smartwatch, no Health Connect needed)
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> _tryInitPedometer() async {
    try {
      // Request activity recognition permission (required on Android 10+)
      final status = await Permission.activityRecognition.request();
      if (!status.isGranted) {
        debugPrint('[HealthService] Activity recognition permission denied');
        return false;
      }

      // Start listening to live step stream
      _startPedometerStream();
      return true;
    } catch (e) {
      debugPrint('[HealthService] Pedometer init error: $e');
      return false;
    }
  }

  void _startPedometerStream() {
    _pedometerSub?.cancel();

    _pedometerSub = Pedometer.stepCountStream.listen(
      (StepCount event) {
        final newTotal = event.steps;

        // Set baseline at first reading of the day
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        if (!_pedometerBaselineSet ||
            _pedometerBaselineDate == null ||
            _pedometerBaselineDate!.day != todayDate.day) {
          // New day — reset baseline
          _pedometerBootSteps = newTotal;
          _pedometerBaselineSet = true;
          _pedometerBaselineDate = todayDate;
          _pedometerTodaySteps = 0;
        }

        _pedometerTodaySteps = newTotal - _pedometerBootSteps;
        if (_pedometerTodaySteps < 0) _pedometerTodaySteps = 0;

        debugPrint('[HealthService] 🦶 Pedometer: today=$_pedometerTodaySteps (total since boot=$newTotal)');
        onLiveStepUpdate?.call(_pedometerTodaySteps);
      },
      onError: (error) {
        debugPrint('[HealthService] Pedometer stream error: $error');
      },
    );

    _pedestrianStatusSub = Pedometer.pedestrianStatusStream.listen(
      (PedestrianStatus event) {
        debugPrint('[HealthService] Pedestrian status: ${event.status}');
      },
      onError: (_) {},
    );
  }

  void stopPedometerStream() {
    _pedometerSub?.cancel();
    _pedestrianStatusSub?.cancel();
    _pedometerSub = null;
    _pedestrianStatusSub = null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UNIFIED STEP READING — uses active source automatically
  // ─────────────────────────────────────────────────────────────────────────

  /// Get today's step count using whatever source is available
  Future<int> fetchTodaySteps({DateTime? since}) async {
    if (kIsWeb) return 0;

    switch (_activeSource) {
      case StepSource.healthConnect:
        return _fetchTodayStepsFromHealthConnect(since: since);
      case StepSource.pedometer:
        return _pedometerTodaySteps;
      case StepSource.manual:
      case StepSource.unavailable:
        return 0;
    }
  }

  Future<int> _fetchTodayStepsFromHealthConnect({DateTime? since}) async {
    final now = DateTime.now();
    DateTime start = getLocalStartOfDay(now);
    if (since != null && since.isAfter(start)) {
      start = since;
    }
    return fetchStepsForInterval(start, now);
  }

  Future<int> fetchStepsForInterval(DateTime startTime, DateTime endTime) async {
    if (kIsWeb) return 0;
    if (_activeSource == StepSource.pedometer) {
      return _pedometerTodaySteps;
    }
    try {
      final totalSteps = await _health.getTotalStepsInInterval(startTime, endTime);
      return totalSteps ?? 0;
    } catch (e) {
      debugPrint('[HealthService] fetchStepsForInterval error: $e');
      // Auto-fallback to pedometer if Health Connect fails mid-session
      if (_pedometerTodaySteps > 0) return _pedometerTodaySteps;
      return 0;
    }
  }

  /// Fetch additional metrics (calories, distance, cardio)
  Future<Map<String, dynamic>> fetchDailyMetrics(DateTime date) async {
    final start = getLocalStartOfDay(date);
    final end = getLocalEndOfDay(date);
    double totalCalories = 0.0;
    double totalDistance = 0.0;
    int cardioMinutes = 0;

    if (kIsWeb || _activeSource == StepSource.manual) {
      return {'calories': 0.0, 'distance': 0.0, 'cardioMinutes': 0};
    }

    if (_activeSource == StepSource.pedometer) {
      // Estimate from step count (no calorie/distance sensor in pedometer)
      final steps = _pedometerTodaySteps;
      return {
        'calories': steps * 0.045,   // ~0.045 kcal/step
        'distance': steps * 0.00076, // ~0.76m/step in km
        'cardioMinutes': 0,
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

      final seenIds = <String>{};
      for (final point in dataPoints) {
        final pointKey =
            '${point.typeString}_${point.dateFrom.millisecondsSinceEpoch}_${point.dateTo.millisecondsSinceEpoch}';
        if (seenIds.contains(pointKey)) continue;
        seenIds.add(pointKey);

        if (point.type == HealthDataType.ACTIVE_ENERGY_BURNED) {
          final val = point.value;
          if (val is NumericHealthValue) totalCalories += val.numericValue.toDouble();
        } else if (point.type == HealthDataType.DISTANCE_DELTA) {
          final val = point.value;
          if (val is NumericHealthValue) totalDistance += val.numericValue.toDouble();
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

  /// Read historical step records for the specified number of days
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

      if (startDayLimit != null && startOfDay.isBefore(startDayLimit)) break;

      DateTime intervalStart = startOfDay;
      if (since != null && since.isAfter(intervalStart)) intervalStart = since;
      final endOfDay = (i == 0) ? now : getLocalEndOfDay(day);

      final steps = (i == 0 && _activeSource == StepSource.pedometer)
          ? _pedometerTodaySteps
          : await fetchStepsForInterval(intervalStart, endOfDay);

      final metrics = await fetchDailyMetrics(day);
      final dateMidnight = DateTime(day.year, day.month, day.day);
      final recordId =
          'rec_${clientId}_${dateMidnight.year}${dateMidnight.month.toString().padLeft(2, '0')}${dateMidnight.day.toString().padLeft(2, '0')}';

      records.add(DailyActivityRecord(
        id: recordId,
        clientId: clientId,
        date: dateMidnight,
        steps: steps,
        stepGoal: stepGoal,
        cardioMinutes: metrics['cardioMinutes'] as int? ?? 0,
        caloriesBurned: steps > 0
            ? ((metrics['calories'] as double? ?? 0.0) > 0
                ? metrics['calories'] as double
                : steps * 0.045)
            : 0.0,
        distanceMeters: steps > 0
            ? ((metrics['distance'] as double? ?? 0.0) > 0
                ? metrics['distance'] as double
                : steps * 0.76)
            : 0.0,
        isGoalAchieved: steps >= stepGoal,
        syncStatus: SyncStatus.pending,
        lastSyncedAt: null,
      ));
    }

    return records;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PERMISSIONS & UTILITIES
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> isHealthServiceAvailable() async {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      try {
        final status = await _health.getHealthConnectSdkStatus();
        return status == HealthConnectSdkStatus.sdkAvailable;
      } catch (_) {
        return false;
      }
    }
    return Platform.isIOS;
  }

  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    return _tryInitHealthConnect();
  }

  Future<bool> hasPermissions() async {
    if (kIsWeb) return false;
    if (_activeSource == StepSource.pedometer) {
      final status = await Permission.activityRecognition.status;
      return status.isGranted;
    }
    try {
      final has = await _health.hasPermissions(
        _requestedTypes,
        permissions: _permissions,
      );
      return has ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> revokePermissions() async {
    if (kIsWeb) return;
    stopPedometerStream();
    try {
      await _health.revokePermissions();
    } catch (_) {}
  }

  /// Returns a human-readable description of the active step source
  String get stepSourceLabel {
    switch (_activeSource) {
      case StepSource.healthConnect:
        return 'Health Connect (Smartwatch Ready)';
      case StepSource.pedometer:
        return 'Phone Sensor (Built-in Pedometer)';
      case StepSource.manual:
        return 'Manual Entry';
      case StepSource.unavailable:
        return 'Unavailable';
    }
  }

  DateTime getLocalStartOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 0, 0, 0, 0);

  DateTime getLocalEndOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
}
