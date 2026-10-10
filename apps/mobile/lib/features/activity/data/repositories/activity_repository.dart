import 'dart:convert';
import 'dart:io' show SocketException;
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/core/constants/app_constants.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/features/activity/data/services/health_service.dart';
import 'package:alpha_x_gym/features/activity/domain/models/activity_models.dart';

/// Repository managing local activity caching, offline retry queue,
/// health hardware reading, and backend synchronization.
///
/// Strictly enforces REAL step data belonging to the authenticated Client ID.
/// No example, demo, synthetic, or hardcoded step data.
class ActivityRepository extends ChangeNotifier {
  final HealthService _healthService;
  final http.Client _httpClient;

  // Active client ID and Name
  String _currentClientId = '';
  String _currentClientName = '';
  int _currentStepGoal = 6000;
  DateTime? _stepTrackingStartDate;

  // In-memory cache of daily records mapped by YYYY-MM-DD
  final Map<String, DailyActivityRecord> _recordsMap = {};

  // Connection and synchronization state
  HealthConnectionStatus _connectionStatus = HealthConnectionStatus.notConfigured;
  SyncStatus _syncStatus = SyncStatus.synced;
  DateTime? _lastSyncedAt;
  bool _isLoading = false;
  String? _errorMessage;

  // Managed clients for Admin view - populated dynamically
  final List<ClientActivityProfile> _managedClients = [];

  ActivityRepository({
    HealthService? healthService,
    http.Client? httpClient,
  })  : _healthService = healthService ?? HealthService(),
        _httpClient = httpClient ?? http.Client() {
    _initialize();
  }

  @override
  void dispose() {
    AuthService().removeListener(_onAuthChanged);
    super.dispose();
  }

  // Getters
  String get currentClientId => _currentClientId;
  String get currentClientName => _currentClientName;
  int get currentStepGoal => _currentStepGoal;
  DateTime? get stepTrackingStartDate => _stepTrackingStartDate;
  HealthConnectionStatus get connectionStatus => _connectionStatus;
  SyncStatus get syncStatus => _syncStatus;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<ClientActivityProfile> get managedClients => List.unmodifiable(_managedClients);

  /// Which data source is actively counting steps (Health Connect / Pedometer / Manual)
  StepSource get activeStepSource => _healthService.activeSource;

  /// Human-readable label for the active step source
  String get stepSourceLabel => _healthService.stepSourceLabel;

  /// Return Today's activity record.
  /// If no record exists for today yet, returns a clean starting record with 0 steps.
  /// NEVER returns hardcoded/fake step counts.
  DailyActivityRecord get todayRecord {
    final todayKey = _dateToKey(DateTime.now());
    if (_recordsMap.containsKey(todayKey)) {
      return _recordsMap[todayKey]!;
    }
    // Clean initial today record: 0 steps, 0 cardio, 0 calories, 0 distance
    return DailyActivityRecord(
      id: 'rec_${_currentClientId}_$todayKey',
      clientId: _currentClientId,
      date: _healthService.getLocalStartOfDay(DateTime.now()),
      steps: 0,
      stepGoal: _currentStepGoal,
      cardioMinutes: 0,
      caloriesBurned: 0.0,
      distanceMeters: 0.0,
      isGoalAchieved: false,
      syncStatus: _syncStatus,
      lastSyncedAt: _lastSyncedAt,
    );
  }

  /// History of recorded days sorted descending (newest first).
  /// Strictly filters by current clientId and only includes records from
  /// stepTrackingStartDate onward.
  /// If client has no recorded steps, returns an empty list.
  List<DailyActivityRecord> get history30Days {
    final startDay = _stepTrackingStartDate != null
        ? _healthService.getLocalStartOfDay(_stepTrackingStartDate!)
        : null;

    final list = _recordsMap.values.where((r) {
      if (_currentClientId.isNotEmpty && r.clientId != _currentClientId) {
        return false;
      }
      if (startDay != null && r.date.isBefore(startDay)) {
        return false;
      }
      return true;
    }).toList();

    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// Weekly summary (last 7 days or since client joined).
  /// NEVER synthesizes fake step values. Days without records start at 0 steps.
  WeeklyActivitySummary get weeklySummary {
    final now = DateTime.now();
    final List<DailyActivityRecord> weekDays = [];
    final startDay = _stepTrackingStartDate != null
        ? _healthService.getLocalStartOfDay(_stepTrackingStartDate!)
        : null;

    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final dayStart = _healthService.getLocalStartOfDay(day);

      // Do NOT include days before client joined
      if (startDay != null && dayStart.isBefore(startDay)) {
        continue;
      }

      final key = _dateToKey(day);
      if (_recordsMap.containsKey(key)) {
        weekDays.add(_recordsMap[key]!);
      } else {
        // Clean 0-step day (real unrecorded day)
        weekDays.add(DailyActivityRecord(
          id: 'rec_${_currentClientId}_$key',
          clientId: _currentClientId,
          date: dayStart,
          steps: 0,
          stepGoal: _currentStepGoal,
          cardioMinutes: 0,
          caloriesBurned: 0.0,
          distanceMeters: 0.0,
          isGoalAchieved: false,
          syncStatus: SyncStatus.synced,
        ));
      }
    }

    return WeeklyActivitySummary.calculate(weekDays);
  }

  /// Monthly summary for specified year and month.
  /// Strictly filters by authenticated client and joined start date.
  MonthlyActivitySummary getMonthlySummary(int year, int month) {
    final startDay = _stepTrackingStartDate != null
        ? _healthService.getLocalStartOfDay(_stepTrackingStartDate!)
        : null;

    final recordsInMonth = _recordsMap.values.where((r) {
      if (_currentClientId.isNotEmpty && r.clientId != _currentClientId) return false;
      if (startDay != null && r.date.isBefore(startDay)) return false;
      return r.date.year == year && r.date.month == month;
    }).toList();

    return MonthlyActivitySummary.calculate(
      year: year,
      month: month,
      recordsInMonth: recordsInMonth,
    );
  }

  /// Bind activity repository to the authenticated user's permanent Client ID
  void bindToClient(String clientId, String clientName) {
    if (clientId.isEmpty) {
      _currentClientId = '';
      _currentClientName = '';
      _recordsMap.clear();
      _stepTrackingStartDate = null;
      notifyListeners();
      return;
    }

    if (clientId == _currentClientId && _recordsMap.isNotEmpty) {
      return;
    }

    _currentClientId = clientId;
    _currentClientName = clientName;
    _recordsMap.clear();
    _loadLocalCache();
    notifyListeners();

    // Asynchronously pull latest from backend for this client
    fetchClientActivityFromBackend(clientId);
  }

  /// Switch the active client profile (for Admin mode)
  void selectClient(String clientId) {
    if (_managedClients.isEmpty) return;

    final profile = _managedClients.firstWhere(
      (c) => c.clientId == clientId,
      orElse: () => _managedClients.first,
    );
    _currentClientId = profile.clientId;
    _currentClientName = profile.clientName;
    _currentStepGoal = profile.dailyStepGoal;
    _recordsMap.clear();
    _loadLocalCache();
    notifyListeners();
    fetchClientActivityFromBackend(clientId);
  }

  /// Populate managed clients list for Admin inspection
  void setManagedClients(List<ClientActivityProfile> clients) {
    _managedClients.clear();
    _managedClients.addAll(clients);
    notifyListeners();
  }

  /// Loads real clients from backend for Admin view
  Future<void> loadManagedClientsFromBackend() async {
    try {
      final token = await AuthService().getValidToken();
      final res = await _httpClient.get(
        Uri.parse('${AppConstants.apiBaseUrl}/admin/clients'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final List<dynamic>? clientList = decoded['data']?['clients'] as List<dynamic>?;
        if (clientList != null) {
          _managedClients.clear();
          for (final c in clientList) {
            final id = c['clientId']?.toString() ?? c['id']?.toString() ?? '';
            final name = c['name']?.toString() ?? 'Athlete';
            final goal = int.tryParse(c['dailyStepGoal']?.toString() ?? '6000') ?? 6000;
            final todaySteps = int.tryParse(c['todaySteps']?.toString() ?? '0') ?? 0;
            _managedClients.add(ClientActivityProfile(
              clientId: id,
              clientName: name,
              dailyStepGoal: goal,
              effectiveDate: DateTime.now(),
              todaySteps: todaySteps,
              weeklyAverage: todaySteps,
              goalDaysAchievedWeek: todaySteps >= goal ? 1 : 0,
            ));
          }
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  /// Fetch latest activity records from backend for a specific client (Admin or Client)
  Future<List<DailyActivityRecord>> fetchClientActivityFromBackend(String clientId) async {
    if (clientId.isEmpty) return [];

    try {
      final token = await AuthService().getValidToken();
      final isAdmin = AuthService().isAdmin;
      final url = isAdmin
          ? Uri.parse('${AppConstants.apiBaseUrl}/activity/client/$clientId')
          : Uri.parse('${AppConstants.apiBaseUrl}/activity/history?limit=30');

      final response = await _httpClient.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic>? recordsJson = isAdmin
            ? (decoded['data']?['history'] as List<dynamic>?)
            : (decoded['data']?['history'] as List<dynamic>?);

        if (recordsJson != null) {
          final List<DailyActivityRecord> serverRecords = [];
          final startDay = _stepTrackingStartDate != null
              ? _healthService.getLocalStartOfDay(_stepTrackingStartDate!)
              : null;

          for (final item in recordsJson) {
            final rec = DailyActivityRecord.fromJson(item as Map<String, dynamic>);
            if (rec.clientId != clientId) continue;
            if (startDay != null && rec.date.isBefore(startDay)) continue;

            _recordsMap[_dateToKey(rec.date)] = rec.copyWith(syncStatus: SyncStatus.synced);
            serverRecords.add(rec);
          }
          await _persistLocalCache();
          notifyListeners();
          return serverRecords;
        }
      }
    } catch (e) {
      debugPrint('[ActivityRepository] fetchClientActivityFromBackend error: $e');
    }
    return [];
  }

  /// Update client's daily step goal (Admin capability)
  Future<bool> updateClientStepGoal({
    required String clientId,
    required int newGoal,
  }) async {
    if (newGoal <= 0) return false;

    // 1. Update in-memory managed profile
    final index = _managedClients.indexWhere((c) => c.clientId == clientId);
    if (index != -1) {
      final old = _managedClients[index];
      _managedClients[index] = old.copyWith(
        dailyStepGoal: newGoal,
        effectiveDate: DateTime.now(),
      );
    }

    // 2. If it is current client, update current goal
    if (clientId == _currentClientId) {
      _currentStepGoal = newGoal;
      final todayKey = _dateToKey(DateTime.now());
      if (_recordsMap.containsKey(todayKey)) {
        final existing = _recordsMap[todayKey]!;
        _recordsMap[todayKey] = existing.copyWith(
          stepGoal: newGoal,
          isGoalAchieved: existing.steps >= newGoal,
          syncStatus: SyncStatus.pending,
        );
      }
    }

    // 3. Persist goal to local storage
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('alpha_x_goal_$clientId', newGoal);
    } catch (e) {
      debugPrint('[ActivityRepository] save goal error: $e');
    }

    notifyListeners();

    // 4. Asynchronously attempt backend persistence
    _syncGoalWithBackend(clientId, newGoal);
    return true;
  }

  /// Connect to device health tracking platform
  Future<bool> connectHealthTracking() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _healthService.initialize();
      final hasPerm = await _healthService.hasPermissions();
      if (hasPerm) {
        _connectionStatus = HealthConnectionStatus.authorized;
      } else {
        final granted = await _healthService.requestPermissions();
        _connectionStatus = granted
            ? HealthConnectionStatus.authorized
            : HealthConnectionStatus.denied;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('alpha_x_health_enabled', _connectionStatus == HealthConnectionStatus.authorized);

      if (_connectionStatus == HealthConnectionStatus.authorized) {
        await refreshActivityData();
      }
    } catch (e) {
      _errorMessage = 'Could not connect health platform: $e';
      _connectionStatus = HealthConnectionStatus.unavailable;
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    return _connectionStatus == HealthConnectionStatus.authorized;
  }

  /// Disconnect health data tracking
  Future<void> disconnectHealthTracking() async {
    try {
      await _healthService.revokePermissions();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('alpha_x_health_enabled', false);
      _connectionStatus = HealthConnectionStatus.notConfigured;
      notifyListeners();
    } catch (e) {
      debugPrint('[ActivityRepository] disconnect error: $e');
    }
  }

  /// Core data refresh: persists cache and triggers backend sync for workout records.
  Future<void> refreshActivityData() async {
    _syncStatus = SyncStatus.syncing;
    notifyListeners();

    try {
      await _persistLocalCache();
      await _syncPendingRecordsWithBackend();

      _syncStatus = SyncStatus.synced;
      _lastSyncedAt = DateTime.now();
      if (_currentClientId.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('alpha_x_last_sync_$_currentClientId', _lastSyncedAt!.toIso8601String());
      }
    } on SocketException catch (_) {
      _syncStatus = SyncStatus.pending;
    } catch (e) {
      _syncStatus = SyncStatus.failed;
      _errorMessage = 'Synchronization failed: $e';
    } finally {
      notifyListeners();
    }
  }

  // --- Private Helpers ---

  Future<void> _initialize() async {
    // Listen to AuthService for automatic client switching and logout cleanup
    AuthService().addListener(_onAuthChanged);
    _syncWithAuth();

    try {
      final prefs = await SharedPreferences.getInstance();

      // ── FIX: Always attempt health initialization on startup, not just when ──
      // ── previously enabled. Health Connect requires initialization before    ──
      // ── hasPermissions() can return correct results.                         ──
      debugPrint('[STEP] Initializing health service on app startup...');
      await _healthService.initialize();

      final hasPerm = await _healthService.hasPermissions();
      debugPrint('[STEP] Health Connect / HealthKit availability: ${_healthService.activeSource.name}');
      debugPrint('[STEP] Permission status: ${hasPerm ? "GRANTED" : "DENIED or not yet requested"}');

      if (hasPerm) {
        _connectionStatus = HealthConnectionStatus.authorized;
        await prefs.setBool('alpha_x_health_enabled', true);
        debugPrint('[STEP] Health tracking auto-authorized from stored permissions');
      } else {
        // Still check saved pref for UI state
        final wasEnabled = prefs.getBool('alpha_x_health_enabled') ?? false;
        _connectionStatus = wasEnabled
            ? HealthConnectionStatus.notConfigured
            : HealthConnectionStatus.notConfigured;
      }

      final lastSyncStr = prefs.getString('alpha_x_last_sync_$_currentClientId');
      if (lastSyncStr != null) {
        _lastSyncedAt = DateTime.tryParse(lastSyncStr);
      }
    } catch (e) {
      debugPrint('[STEP] ActivityRepository init error: $e');
    }
    notifyListeners();
  }

  void _onAuthChanged() {
    final auth = AuthService();
    if (!auth.isAuthenticated || auth.currentClientId.isEmpty) {
      if (_currentClientId.isNotEmpty) {
        _currentClientId = '';
        _currentClientName = '';
        _recordsMap.clear();
        _stepTrackingStartDate = null;
        notifyListeners();
      }
    } else if (auth.currentClientId != _currentClientId) {
      bindToClient(auth.currentClientId, auth.currentUserName);
    }
  }

  void _syncWithAuth() {
    final auth = AuthService();
    if (auth.currentClientId.isNotEmpty) {
      _currentClientId = auth.currentClientId;
      _currentClientName = auth.currentUserName.isNotEmpty ? auth.currentUserName : 'Athlete';
      _loadLocalCache();
    }
  }

  String _dateToKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _loadLocalCache() async {
    if (_currentClientId.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Establish client join / step tracking start date
      await _loadStepTrackingStartDate(prefs);

      // 2. Restore custom goal
      final savedGoal = prefs.getInt('alpha_x_goal_$_currentClientId');
      if (savedGoal != null && savedGoal > 0) {
        _currentStepGoal = savedGoal;
      }

      // 3. Restore records from local disk cache
      final jsonStr = prefs.getString('alpha_x_records_$_currentClientId');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonStr) as List<dynamic>;

        // Clean purge of any legacy demo seeds from previous app versions (30 seeded days)
        final isLegacyDemoSeed = decoded.length == 30 &&
            decoded.any((r) => r['steps'] == 5420 || r['steps'] == 8900 || r['steps'] == 7420);

        if (isLegacyDemoSeed) {
          await prefs.remove('alpha_x_records_$_currentClientId');
        } else {
          final startDay = _stepTrackingStartDate != null
              ? _healthService.getLocalStartOfDay(_stepTrackingStartDate!)
              : null;

          for (final item in decoded) {
            final record = DailyActivityRecord.fromJson(item as Map<String, dynamic>);
            if (record.clientId != _currentClientId) continue;
            if (startDay != null && record.date.isBefore(startDay)) continue;

            _recordsMap[_dateToKey(record.date)] = record;
          }
        }
      }
    } catch (e) {
      debugPrint('[ActivityRepository] loadLocalCache error: $e');
    }
  }

  Future<void> _loadStepTrackingStartDate(SharedPreferences prefs) async {
    final savedDate = prefs.getString('alpha_x_step_start_date_$_currentClientId');
    if (savedDate != null && savedDate.isNotEmpty) {
      _stepTrackingStartDate = DateTime.tryParse(savedDate);
    } else {
      final authProfile = AuthService().clientProfile;
      final raw = authProfile['stepTrackingStartDate'] ?? authProfile['createdAt'];
      if (raw != null) {
        _stepTrackingStartDate = DateTime.tryParse(raw.toString());
      }
      if (_stepTrackingStartDate == null && _currentClientId.isNotEmpty) {
        _stepTrackingStartDate = DateTime.now();
        await prefs.setString(
          'alpha_x_step_start_date_$_currentClientId',
          _stepTrackingStartDate!.toIso8601String(),
        );
      }
    }
  }

  /// Baseline handling: Health Connect and HealthKit return steps-for-today (not cumulative),
  /// so we do NOT subtract any baseline for those sources.
  /// Baseline subtraction is only needed for raw pedometer which is cumulative since boot.
  ///
  Future<void> _persistLocalCache() async {
    if (_currentClientId.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _recordsMap.values
          .where((r) => r.clientId == _currentClientId)
          .map((r) => r.toJson())
          .toList();
      await prefs.setString('alpha_x_records_$_currentClientId', jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[ActivityRepository] persistLocalCache error: $e');
    }
  }

  /// Public trigger to sync pending records with backend immediately
  Future<void> syncWithBackend() async {
    await _syncPendingRecordsWithBackend();
  }

  /// Automatically update daily cardio/workout minutes & calories when a workout is completed
  Future<void> recordCompletedWorkoutActivity({
    required int durationMinutes,
    double? caloriesBurned,
  }) async {
    final todayKey = _dateToKey(DateTime.now());
    final current = todayRecord;
    final estCalories = caloriesBurned ?? (durationMinutes * 6.5);
    final updated = current.copyWith(
      cardioMinutes: current.cardioMinutes + durationMinutes,
      caloriesBurned: current.caloriesBurned + estCalories,
      syncStatus: SyncStatus.pending,
    );
    _recordsMap[todayKey] = updated;
    await _persistLocalCache();
    notifyListeners();
    await _syncPendingRecordsWithBackend();
  }

  Future<void> _syncPendingRecordsWithBackend() async {
    final pendingRecords = _recordsMap.values
        .where((r) => r.clientId == _currentClientId && r.syncStatus == SyncStatus.pending)
        .toList();

    if (pendingRecords.isEmpty) return;

    try {
      final authClientId = AuthService().currentClientId;
      final targetClientId = authClientId.isNotEmpty ? authClientId : _currentClientId;

      final todayPending = pendingRecords.where((r) => _dateToKey(r.date) == _dateToKey(DateTime.now()));
      for (final r in todayPending) {
        debugPrint('[STEP] API synchronization — sending steps=${r.steps} for date=${_dateToKey(r.date)} clientId=$targetClientId');
      }

      final url = Uri.parse('${AppConstants.apiBaseUrl}/activity/sync');
      final body = jsonEncode({
        'clientId': targetClientId,
        'records': pendingRecords.map((r) => r.toJson()).toList(),
      });

      final validToken = await AuthService().getValidToken();
      final token = validToken.isNotEmpty ? validToken : 'alpha_x_mock_token_for_client';

      final response = await _httpClient
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 4));

      debugPrint('[STEP] Backend sync response: HTTP ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Mark as synced
        for (final r in pendingRecords) {
          final key = _dateToKey(r.date);
          _recordsMap[key] = r.copyWith(
            syncStatus: SyncStatus.synced,
            lastSyncedAt: DateTime.now(),
          );
        }
        await _persistLocalCache();
        debugPrint('[STEP] Database saved step count: OK (${pendingRecords.length} record(s) synced)');
      } else {
        debugPrint('[STEP] Backend sync failed: HTTP ${response.statusCode} — ${response.body}');
      }
    } catch (e) {
      // Offline: keep as pending for next automatic sync retry without losing steps
      debugPrint('[STEP] Backend sync exception (will retry): $e');
    }
  }

  Future<void> _syncGoalWithBackend(String clientId, int newGoal) async {
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/activity/client/$clientId/goal');
      final token = await AuthService().getValidToken();

      await _httpClient
          .put(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'stepGoal': newGoal}),
          )
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      // Handled silently; local storage preserves the goal
    }
  }
}
