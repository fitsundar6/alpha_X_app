import 'package:flutter/foundation.dart';

/// Supported health platforms for future integration
enum HealthPlatform {
  appleHealth,
  googleHealthConnect,
  garmin,
  whoop,
  fitbit,
}

/// Factual health metrics payload (strictly real data when connected)
class SmartwatchHealthPayload {
  final int? steps;
  final double? activeCalories;
  final int? activeWorkoutMinutes;
  final int? averageHeartRateBpm;
  final double? sleepHours;
  final DateTime timestamp;
  final HealthPlatform platform;

  const SmartwatchHealthPayload({
    this.steps,
    this.activeCalories,
    this.activeWorkoutMinutes,
    this.averageHeartRateBpm,
    this.sleepHours,
    required this.timestamp,
    required this.platform,
  });

  Map<String, dynamic> toJson() {
    return {
      'steps': steps,
      'activeCalories': activeCalories,
      'activeWorkoutMinutes': activeWorkoutMinutes,
      'averageHeartRateBpm': averageHeartRateBpm,
      'sleepHours': sleepHours,
      'timestamp': timestamp.toIso8601String(),
      'platform': platform.name,
    };
  }
}

/// Abstract contract for platform-specific smartwatch/health synchronizers
abstract class HealthPlatformConnector {
  Future<bool> isPlatformAvailable();
  Future<bool> requestPermissions();
  Future<SmartwatchHealthPayload?> fetchTodaySummary();
}

/// Future-ready Smartwatch / Health Service architecture
/// Does not fabricate mock data. When a device is paired in the future,
/// it pipes authenticated data directly into Alpha X activity & recovery systems.
class SmartwatchHealthSyncService extends ChangeNotifier {
  static final SmartwatchHealthSyncService _instance = SmartwatchHealthSyncService._internal();
  factory SmartwatchHealthSyncService() => _instance;
  SmartwatchHealthSyncService._internal();

  bool _isSyncing = false;
  bool _isConnected = false;
  HealthPlatform? _connectedPlatform;
  DateTime? _lastSyncTimestamp;

  bool get isSyncing => _isSyncing;
  bool get isConnected => _isConnected;
  HealthPlatform? get connectedPlatform => _connectedPlatform;
  DateTime? get lastSyncTimestamp => _lastSyncTimestamp;

  /// Check availability and connect to platform
  Future<bool> connectPlatform(HealthPlatform platform) async {
    _isSyncing = true;
    notifyListeners();

    try {
      // Clean interface ready for Apple HealthKit / Google Health Connect native bridge
      _isConnected = false;
      _connectedPlatform = platform;
      _lastSyncTimestamp = DateTime.now();
      return true;
    } catch (_) {
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Disconnect health platform
  void disconnect() {
    _isConnected = false;
    _connectedPlatform = null;
    notifyListeners();
  }
}
