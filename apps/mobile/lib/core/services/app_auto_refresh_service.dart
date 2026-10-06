import 'dart:async';
import 'package:flutter/widgets.dart';

import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/macro_planner/data/repositories/macro_repository.dart';
import 'package:alpha_x_gym/features/progress/data/repositories/weekly_progress_repository.dart';
import 'package:alpha_x_gym/features/notifications/data/repositories/notification_repository.dart';

/// Centralized, intelligent auto-refresh engine for the entire Alpha X Gym app.
///
/// Ensures any updates assigned by admin (diet plans, workout sessions, macro
/// targets, notifications, check-in reviews) are reflected IMMEDIATELY in the app
/// without requiring the user to close and reopen it.
///
/// Features:
/// 1. Foreground periodic heartbeat polling (every 8 seconds while app is active).
/// 2. Instant app lifecycle resume sync (triggers immediately when returning from background).
/// 3. Immediate manual triggers (on tab switch, admin assignment action, push notification, pull-to-refresh).
/// 4. Concurrency lock to prevent overlapping HTTP requests.
/// 5. Automatic battery conservation (pauses timer when app is paused/backgrounded).
class AppAutoRefreshService with WidgetsBindingObserver {
  static final AppAutoRefreshService _instance = AppAutoRefreshService._internal();
  static AppAutoRefreshService get instance => _instance;
  factory AppAutoRefreshService() => _instance;
  AppAutoRefreshService._internal();

  WorkoutRepository? _workoutRepository;
  MacroRepository? _macroRepository;
  WeeklyProgressRepository? _weeklyProgressRepository;
  NotificationRepository? _notificationRepository;

  Timer? _pollingTimer;
  bool _isInitialized = false;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  /// Observable notifiers for any UI element needing sync state
  final ValueNotifier<bool> isSyncingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<DateTime?> lastSyncTimeNotifier = ValueNotifier<DateTime?>(null);

  /// Heartbeat cadence when app is active in foreground
  static const Duration defaultPollingInterval = Duration(seconds: 8);

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Initialize the auto-refresh coordinator with all repositories
  void initialize({
    required WorkoutRepository workoutRepository,
    required MacroRepository macroRepository,
    required WeeklyProgressRepository weeklyProgressRepository,
    required NotificationRepository notificationRepository,
  }) {
    _workoutRepository = workoutRepository;
    _macroRepository = macroRepository;
    _weeklyProgressRepository = weeklyProgressRepository;
    _notificationRepository = notificationRepository;

    if (!_isInitialized) {
      _isInitialized = true;
      WidgetsBinding.instance.addObserver(this);
      AuthService().addListener(_onAuthStatusChanged);
      _checkAndStartPolling();
    }
  }

  void _onAuthStatusChanged() {
    _checkAndStartPolling();
  }

  void _checkAndStartPolling() {
    if (AuthService().isAuthenticated) {
      startPolling();
    } else {
      stopPolling();
    }
  }

  /// Start periodic background polling while active
  void startPolling({Duration interval = defaultPollingInterval}) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(interval, (_) {
      triggerImmediateSync(reason: 'Periodic Heartbeat');
    });

    // Fire an immediate sync on activation
    triggerImmediateSync(reason: 'Polling Activated');
  }

  /// Stop periodic polling
  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // User switched back to the app (from another app, screen lock, etc.)
      // Immediately pull fresh assignments from server!
      triggerImmediateSync(reason: 'App Resumed');
      _checkAndStartPolling();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // Pause timer when in background to preserve device battery
      _pollingTimer?.cancel();
      _pollingTimer = null;
    }
  }

  /// Manually or programmatically trigger an immediate synchronization pass.
  ///
  /// Can be called after admin assignment actions, on tab changes, on pull-to-refresh,
  /// or when OneSignal push notifications arrive.
  Future<void> triggerImmediateSync({
    String reason = 'Direct Trigger',
    bool force = false,
  }) async {
    // Only sync if user is authenticated with a valid token
    final token = AuthService().currentToken;
    if (token.isEmpty) return;

    // Prevent concurrent overlapping requests
    if (_isSyncing) return;
    _isSyncing = true;
    isSyncingNotifier.value = true;

    try {
      final isAdmin = AuthService().isAdmin;

      if (!isAdmin) {
        // CLIENT SYNC: Pull latest coach assigned diet plan, workouts, check-in status, and notifications
        final todayStr = _macroRepository?.getTodayDateString();

        final futures = <Future<dynamic>>[];

        if (_macroRepository != null) {
          futures.add(_macroRepository!.fetchAssignedDietPlan());
          if (todayStr != null) {
            futures.add(_macroRepository!.fetchFoodLogsFromBackend(todayStr));
          }
        }

        if (_workoutRepository != null) {
          futures.add(_workoutRepository!.fetchClientWorkouts(forceRefresh: true));
        }

        if (_weeklyProgressRepository != null) {
          futures.add(_weeklyProgressRepository!.fetchCheckInStatus(forceRefresh: force, silent: !force));
        }

        if (_notificationRepository != null) {
          futures.add(_notificationRepository!.fetchNotifications(silent: !force));
        }

        await Future.wait(futures);
      } else {
        // ADMIN SYNC: Refresh client records and admin reviews
        final futures = <Future<dynamic>>[];

        if (_workoutRepository != null) {
          futures.add(_workoutRepository!.fetchClientsList(forceRefresh: true));
        }

        // Note: Admin accounts do not have athlete client profiles.
        // Client notifications are not polled in the admin sync loop.

        await Future.wait(futures);
      }

      _lastSyncTime = DateTime.now();
      lastSyncTimeNotifier.value = _lastSyncTime;
    } catch (e) {
      debugPrint('[AppAutoRefreshService] Sync exception ($reason): $e');
    } finally {
      _isSyncing = false;
      isSyncingNotifier.value = false;
    }
  }

  /// Clean up listeners
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AuthService().removeListener(_onAuthStatusChanged);
    stopPolling();
  }
}
