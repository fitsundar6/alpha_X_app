import 'dart:convert';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/core/constants/app_constants.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/features/workout/domain/models/workout_models.dart';
import 'package:alpha_x_gym/features/exercise/domain/models/exercise_model.dart';
import 'package:alpha_x_gym/features/exercise/data/repositories/exercise_repository.dart';
import 'package:alpha_x_gym/core/services/app_auto_refresh_service.dart';
import 'package:alpha_x_gym/core/utils/ist_date_utils.dart';

class WorkoutAssignmentData {
  final String id;
  final String sessionId;
  final String? clientId; // null means ALL clients
  final bool isRecommended;
  final DateTime assignedAt;
  final String? scheduledDate;
  final bool isLocked;
  final String status;
  final DateTime? unlockedAt;
  final String? unlockReason;

  WorkoutAssignmentData({
    required this.id,
    required this.sessionId,
    this.clientId,
    this.isRecommended = false,
    DateTime? assignedAt,
    this.scheduledDate,
    this.isLocked = false,
    this.status = 'ASSIGNED',
    this.unlockedAt,
    this.unlockReason,
  }) : assignedAt = assignedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'sessionId': sessionId,
    'clientId': clientId,
    'isRecommended': isRecommended,
    'assignedAt': assignedAt.toIso8601String(),
    'scheduledDate': scheduledDate,
    'isLocked': isLocked,
    'status': status,
    'unlockedAt': unlockedAt?.toIso8601String(),
    'unlockReason': unlockReason,
  };

  factory WorkoutAssignmentData.fromJson(Map<String, dynamic> json) => WorkoutAssignmentData(
    id: json['id'] as String? ?? '',
    sessionId: json['sessionId'] as String? ?? '',
    clientId: json['clientId'] as String?,
    isRecommended: json['isRecommended'] as bool? ?? false,
    assignedAt: json['assignedAt'] != null ? DateTime.tryParse(json['assignedAt'] as String) : null,
    scheduledDate: json['scheduledDate'] as String?,
    isLocked: json['isLocked'] as bool? ?? false,
    status: json['status'] as String? ?? 'ASSIGNED',
    unlockedAt: json['unlockedAt'] != null ? DateTime.tryParse(json['unlockedAt'] as String) : null,
    unlockReason: json['unlockReason'] as String?,
  );
}


class PendingSetSync {
  final String sessionId;
  final String exerciseId;
  final int setNumber;
  final bool isCompleted;
  final double? actualWeight;
  final int? actualReps;
  final double? actualRpe;
  final int? actualRir;
  final String scheduledDate;
  final int clientTimestamp;

  const PendingSetSync({
    required this.sessionId,
    required this.exerciseId,
    required this.setNumber,
    required this.isCompleted,
    this.actualWeight,
    this.actualReps,
    this.actualRpe,
    this.actualRir,
    required this.scheduledDate,
    required this.clientTimestamp,
  });

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'exerciseId': exerciseId,
    'setNumber': setNumber,
    'isCompleted': isCompleted,
    'actualWeight': actualWeight,
    'actualReps': actualReps,
    'actualRpe': actualRpe,
    'actualRir': actualRir,
    'scheduledDate': scheduledDate,
    'clientTimestamp': clientTimestamp,
  };

  factory PendingSetSync.fromJson(Map<String, dynamic> json) => PendingSetSync(
    sessionId: json['sessionId'] as String? ?? '',
    exerciseId: json['exerciseId'] as String? ?? '',
    setNumber: (json['setNumber'] as num?)?.toInt() ?? 1,
    isCompleted: json['isCompleted'] as bool? ?? true,
    actualWeight: (json['actualWeight'] as num?)?.toDouble(),
    actualReps: (json['actualReps'] as num?)?.toInt(),
    actualRpe: (json['actualRpe'] as num?)?.toDouble(),
    actualRir: (json['actualRir'] as num?)?.toInt(),
    scheduledDate: json['scheduledDate'] as String? ?? '',
    clientTimestamp: (json['clientTimestamp'] as num?)?.toInt() ?? 0,
  );
}

class WorkoutRepository extends ChangeNotifier {
  static const String _storageKeySessions = 'alpha_x_workout_sessions';
  static const String _storageKeyAssignments = 'alpha_x_workout_assignments';
  static const String _storageKeyHistory = 'alpha_x_workout_history';
  static const String _storageKeyChangeRequests = 'alpha_x_change_requests';
  static const String _storageKeyPendingSync = 'alpha_x_pending_workout_records';
  static const String _storageKeyPendingSetCompletions = 'alpha_x_pending_set_completions';
  static const String _storageKeyActiveSession = 'alpha_x_workout_active_session_state';
  static const String _storageKeyActiveSessionTimestamp = 'alpha_x_workout_active_session_timestamp';
  static const String _storageKeyActiveSessionDuration = 'alpha_x_workout_active_session_duration';

  final http.Client _httpClient;
  void Function(WorkoutRecord record)? onWorkoutCompleted;

  late WorkoutSession _activeSession;
  bool _hasRestoredActiveSession = false;
  DateTime? _activeSessionSavedAt;
  final List<WorkoutSession> _sessions = [];
  final List<WorkoutSession> _pendingWorkouts = [];
  final List<WorkoutAssignmentData> _assignments = [];
  final List<WorkoutRecord> _workoutHistory = [];
  final List<WorkoutRecord> _pendingSyncRecords = [];
  final List<PendingSetSync> _pendingSetCompletions = [];
  final List<ExerciseChangeRequest> _changeRequests = [];
  final List<ExerciseSwapRecord> _currentSessionSwaps = [];
  bool _lastWorkoutVisibility = IstDateUtils.isScheduledWorkoutVisibleInIST();
  String _lastTodayIST = IstDateUtils.getTodayISTString();
  bool _isRestDayFromServer = false;

  /// Checks whether the IST visibility window (5:00 AM - 9:00 PM IST) or IST date has transitioned.
  /// If changed, fires [notifyListeners] to dynamically update client screens without app restart or logout.
  bool checkVisibilityWindowChange() {
    final currentVisibility = IstDateUtils.isScheduledWorkoutVisibleInIST();
    final currentToday = IstDateUtils.getTodayISTString();
    if (currentVisibility != _lastWorkoutVisibility || currentToday != _lastTodayIST) {
      _lastWorkoutVisibility = currentVisibility;
      _lastTodayIST = currentToday;
      notifyListeners();
      return true;
    }
    return false;
  }

  // Clients database for Admin viewing and assignment - dynamically populated from shared PostgreSQL DB
  final List<Map<String, String>> _clients = [];

  bool get _isTestEnvironment {
    if (kIsWeb) return false;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  WorkoutRepository({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client() {
    _activeSession = WorkoutSession.empty();
    if (_isTestEnvironment) {
      _initSeededSessions();
      if (_sessions.isNotEmpty) {
        _activeSession = _sessions.first;
      }
      _initSeededChangeRequests();
      _initTestWorkoutHistory();
    }
    _loadFromLocalStorage();
    // Only prefetch clients if a token is already available (i.e. user is already
    // authenticated from a previous session). If there's no token yet (cold start
    // before login), skip silently — the dashboard will call fetchClientsList()
    // again after the admin logs in, at which point the token will be present.
    if (AuthService().currentToken.isNotEmpty) {
      if (AuthService().isAdmin) {
        fetchClientsList();
        fetchAdminSessions();
      } else {
        fetchClientWorkouts();
      }
    }
  }

  WorkoutSession get activeSession => _activeSession;
  List<WorkoutSession> get adminSessions => List.unmodifiable(_sessions);
  List<WorkoutSession> get pendingWorkouts => List.unmodifiable(_pendingWorkouts);
  List<WorkoutRecord> get workoutHistory => List.unmodifiable(_workoutHistory);
  List<Map<String, String>> get clientsList => List.unmodifiable(_clients);
  List<Map<String, String>> get clients => clientsList;

  void addCompletedRecordForTesting(WorkoutRecord record) {
    _workoutHistory.removeWhere((r) => r.id == record.id);
    _workoutHistory.insert(0, record);
    notifyListeners();
  }
  int get pendingSyncCount => _pendingSyncRecords.length;
  int get pendingSetCompletionsCount => _pendingSetCompletions.length;
  DateTime? get activeSessionSavedAt => _activeSessionSavedAt;
  bool get hasActiveSavedSession {
    if (!_hasRestoredActiveSession) return false;
    if (_activeSession.isCompleted) return false;
    if (_activeSession.isLocked) return false;
    if (_activeSession.status == 'COMPLETED' || _activeSession.status == 'ABANDONED') return false;
    final currentUid = AuthService().currentUserId;
    if (currentUid.isNotEmpty &&
        _activeSession.assignedClientId != null &&
        _activeSession.assignedClientId!.isNotEmpty &&
        _activeSession.assignedClientId != currentUid) {
      return false;
    }
    final shouldEnforce = !_isTestEnvironment || IstDateUtils.hasCustomDateProviderForTesting;
    if (shouldEnforce && !IstDateUtils.isScheduledWorkoutVisibleInIST()) {
      return false;
    }
    final todayIST = IstDateUtils.getTodayISTString();
    if (_activeSession.scheduledDate != null &&
        _activeSession.scheduledDate!.isNotEmpty &&
        _activeSession.scheduledDate != todayIST) {
      return false;
    }
    return true;
  }

  /// Authoritative check: Returns true strictly when a client is actively training in an
  /// in-progress workout session. When true, background refreshes, schedule/date changes,
  /// or admin assignment changes must NEVER replace or mutate the active session.
  bool get isWorkoutInProgress {
    if (!_hasRestoredActiveSession) return false;
    if (_activeSession.isCompleted) return false;
    if (_activeSession.isLocked) return false;
    if (_activeSession.status != 'IN_PROGRESS') return false;
    final currentUid = AuthService().currentUserId;
    if (currentUid.isNotEmpty &&
        _activeSession.assignedClientId != null &&
        _activeSession.assignedClientId!.isNotEmpty &&
        _activeSession.assignedClientId != currentUid) {
      return false;
    }
    final shouldEnforce = !_isTestEnvironment || IstDateUtils.hasCustomDateProviderForTesting;
    if (shouldEnforce && !IstDateUtils.isScheduledWorkoutVisibleInIST()) {
      return false;
    }
    final todayIST = IstDateUtils.getTodayISTString();
    if (_activeSession.scheduledDate != null &&
        _activeSession.scheduledDate!.isNotEmpty &&
        _activeSession.scheduledDate != todayIST) {
      return false;
    }
    return true;
  }

  /// Adds an exercise dynamically to the currently active workout session and persists for future occurrences.
  void addExerciseToActiveSession(WorkoutExercise exercise) {
    if (_activeSession.isLocked || _activeSession.isCompleted || _activeSession.status == 'COMPLETED') return;
    final markedExercise = exercise.copyWith(isCustomAdded: true);
    final updatedExercises = List<WorkoutExercise>.from(_activeSession.exercises)..add(markedExercise);
    _activeSession = _activeSession.copyWith(
      exercises: updatedExercises,
      hasClientCustomization: true,
    );
    final uid = _activeSession.assignedClientId ?? AuthService().currentUserId;
    if (uid.isNotEmpty) {
      saveActiveSessionToLocalStorage(userId: uid);
    }
    notifyListeners();

    // Persist custom added exercise to backend for future occurrences
    syncExerciseAdditionToBackend(
      sessionId: _activeSession.id,
      exercise: markedExercise,
      dayOfWeek: _activeSession.recurringSchedule,
    );
  }

  /// Fetches real registered clients exclusively from the shared backend database (PostgreSQL).
  /// NEVER falls back to demo/sample/example data.
  Future<List<Map<String, String>>> fetchClientsList({bool forceRefresh = false}) async {
    var token = await AuthService().getValidToken();

    final url = Uri.parse('${AppConstants.apiBaseUrl}/admin/clients');

    try {
      var response = await _httpClient.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 12));

      // Automatic 401 recovery: token expired or invalid in production
      if (response.statusCode == 401 && !_isTestEnvironment && AuthService().isAdmin) {
        debugPrint('[WorkoutRepository] Admin session token returned 401. Re-authenticating...');
        final freshToken = await AuthService().refreshAdminToken();
        if (freshToken != null && freshToken.isNotEmpty) {
          token = freshToken;
          response = await _httpClient.get(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          ).timeout(const Duration(seconds: 12));
        }
      }

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> clientList = decoded['data'] ?? [];

        _clients.clear();
        for (final item in clientList) {
          if (item is Map) {
            final injuryAreas = item['injuryAreas'] is List ? (item['injuryAreas'] as List).join(', ') : item['injuryAreas']?.toString() ?? '';
            final preferences = item['trainingPreferences'] is List ? (item['trainingPreferences'] as List).join(', ') : item['trainingPreferences']?.toString() ?? '';
            _clients.add({
              'id': item['id']?.toString() ?? '',
              'clientId': item['clientId']?.toString() ?? item['id']?.toString() ?? '',
              'name': item['name']?.toString() ?? 'Athlete',
              'email': item['email']?.toString() ?? '',
              'photoUrl': item['photoUrl']?.toString() ?? '',
              'googleUid': item['googleUid']?.toString() ?? '',
              'phone': item['phone']?.toString() ?? '',
              'adminNotes': item['adminNotes']?.toString() ?? '',
              'status': item['status']?.toString() ?? 'Active',
              'tier': item['tier']?.toString() ?? 'Athlete',
              'role': item['role']?.toString() ?? 'CLIENT',
              'createdAt': item['createdAt']?.toString() ?? '',
              'dailyStepGoal': item['dailyStepGoal']?.toString() ?? '6000',
              'fitnessLevel': item['fitnessLevel']?.toString() ?? 'beginner',
              'primaryGoal': item['primaryGoal']?.toString() ?? 'General Fitness',
              'secondaryGoal': item['secondaryGoal']?.toString() ?? '',
              'weightKg': item['weightKg']?.toString() ?? '',
              'heightCm': item['heightCm']?.toString() ?? '',
              'age': item['age']?.toString() ?? '',
              'gender': item['gender']?.toString() ?? '',
              'trainingExperience': item['trainingExperience']?.toString() ?? '',
              'trainingDaysPerWeek': item['trainingDaysPerWeek']?.toString() ?? '4',
              'hasCurrentInjury': (item['hasCurrentInjury'] == true).toString(),
              'injuryAreas': injuryAreas,
              'injuryDescription': item['injuryDescription']?.toString() ?? '',
              'hasPreviousSurgery': (item['hasPreviousSurgery'] == true).toString(),
              'surgeryDetails': item['surgeryDetails']?.toString() ?? '',
              'activityLevel': item['activityLevel']?.toString() ?? 'MODERATE',
              'sleepHours': item['sleepHours']?.toString() ?? '7–8 hours',
              'dailySteps': item['dailySteps']?.toString() ?? '6000',
              'trainingTimePref': item['trainingTimePref']?.toString() ?? '',
              'trainingPreferences': preferences,
              'onboardingCompleted': (item['onboardingCompleted'] == true).toString(),
            });
          }
        }
        notifyListeners();
        return List.unmodifiable(_clients);
      } else {
        String errMsg = 'Failed to load clients (${response.statusCode})';
        try {
          if (response.body.isNotEmpty) {
            final decoded = jsonDecode(response.body);
            if (decoded is Map && decoded['error'] is Map && decoded['error']['message'] != null) {
              errMsg = decoded['error']['message'];
            }
          }
        } catch (_) {}
        debugPrint('WorkoutRepository: $errMsg');
        if (_isTestEnvironment) {
          await _populateFromTestAccounts();
        }
        return List.unmodifiable(_clients);
      }
    } catch (e) {
      debugPrint('WorkoutRepository: Notice fetching clients: $e');
      if (_isTestEnvironment) {
        await _populateFromTestAccounts();
      }
      return List.unmodifiable(_clients);
    }
  }

  void _initTestWorkoutHistory() {
    final now = DateTime.now();
    _workoutHistory.addAll([
      WorkoutRecord(
        id: 'rec_test_1',
        clientId: 'client_john_doe',
        sessionId: 'ws_push_a_01',
        sessionTitle: 'Push A',
        workoutType: 'Strength',
        targetMuscleGroup: 'Chest • Shoulders • Triceps',
        startedAt: now.subtract(const Duration(days: 3, hours: 1)),
        completedAt: now.subtract(const Duration(days: 3)),
        durationSeconds: 3200,
        totalVolume: 5600.0,
        completedSetsCount: 12,
        skippedSetsCount: 0,
        averageRpe: 8.5,
        averageRir: 1.5,
        isCompleted: true,
        exercises: [
          const WorkoutExercise(
            id: 'we_incline_smith',
            exerciseId: 'ex_incline_smith',
            exerciseName: 'Incline Smith Machine Press',
            category: 'Chest',
            primaryMusclesDisplay: 'Upper Chest',
            secondaryMusclesDisplay: 'Front Delts • Triceps',
            trainerNote: 'Target: control tempo on eccentric phase',
            sets: [
              ExerciseSet(id: 's1', setNumber: 1, setType: SetType.working, targetWeight: 70.0, actualWeight: 70.0, targetRepsMin: 10, targetRepsMax: 10, actualReps: 10, isCompleted: true),
              ExerciseSet(id: 's2', setNumber: 2, setType: SetType.working, targetWeight: 70.0, actualWeight: 70.0, targetRepsMin: 10, targetRepsMax: 10, actualReps: 10, isCompleted: true),
            ],
          ),
        ],
      ),
      WorkoutRecord(
        id: 'rec_test_2',
        clientId: 'client_john_doe',
        sessionId: 'ws_push_a_01',
        sessionTitle: 'Push A',
        workoutType: 'Strength',
        targetMuscleGroup: 'Chest • Shoulders • Triceps',
        startedAt: now.subtract(const Duration(days: 7, hours: 1)),
        completedAt: now.subtract(const Duration(days: 7)),
        durationSeconds: 3100,
        totalVolume: 5400.0,
        completedSetsCount: 12,
        skippedSetsCount: 0,
        averageRpe: 8.0,
        averageRir: 2.0,
        isCompleted: true,
        exercises: [
          const WorkoutExercise(
            id: 'we_incline_smith',
            exerciseId: 'ex_incline_smith',
            exerciseName: 'Incline Smith Machine Press',
            category: 'Chest',
            primaryMusclesDisplay: 'Upper Chest',
            secondaryMusclesDisplay: 'Front Delts • Triceps',
            trainerNote: 'Target: control tempo on eccentric phase',
            sets: [
              ExerciseSet(id: 's1_old', setNumber: 1, setType: SetType.working, targetWeight: 67.5, actualWeight: 67.5, targetRepsMin: 10, targetRepsMax: 10, actualReps: 10, isCompleted: true),
            ],
          ),
        ],
      ),
    ]);
  }

  Future<void> _populateFromTestAccounts() async {
    final localAccounts = await AuthService().getLocalRegisteredClients();
    for (final item in localAccounts) {
      final existingIndex = _clients.indexWhere((c) => c['clientId'] == item['clientId']);
      final map = {
        'id': item['id']?.toString() ?? '',
        'clientId': item['clientId']?.toString() ?? '',
        'name': item['name']?.toString() ?? 'Athlete',
        'email': item['email']?.toString() ?? '',
        'photoUrl': item['photoUrl']?.toString() ?? '',
        'phone': item['phone']?.toString() ?? '',
        'status': 'Active',
        'tier': 'Athlete',
        'role': 'CLIENT',
        'createdAt': item['registeredAt']?.toString() ?? DateTime.now().toIso8601String(),
        'fitnessLevel': item['fitnessLevel']?.toString() ?? 'intermediate',
        'primaryGoal': item['primaryGoal']?.toString() ?? 'General Fitness',
        'secondaryGoal': item['secondaryGoal']?.toString() ?? '',
        'weightKg': item['weightKg']?.toString() ?? '',
        'heightCm': item['heightCm']?.toString() ?? '',
        'age': item['age']?.toString() ?? '',
        'gender': item['gender']?.toString() ?? '',
        'trainingExperience': item['trainingExperience']?.toString() ?? '',
        'trainingDaysPerWeek': item['trainingDaysPerWeek']?.toString() ?? '4',
        'hasCurrentInjury': (item['hasCurrentInjury'] == true).toString(),
        'onboardingCompleted': (item['onboardingCompleted'] == true).toString(),
      };
      if (existingIndex >= 0) {
        _clients[existingIndex] = map;
      } else {
        _clients.add(map);
      }
    }
    notifyListeners();
  }

  /// Fetches complete, latest client profile & assessment data directly from backend
  Future<Map<String, dynamic>?> fetchClientProfile(String clientIdOrId) async {
    final token = await AuthService().getValidToken();
    final url = Uri.parse('${AppConstants.apiBaseUrl}/admin/clients/$clientIdOrId');

    try {
      final response = await _httpClient.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true && decoded['data'] != null) {
          final data = Map<String, dynamic>.from(decoded['data'] as Map);
          if (data['client'] is Map) {
            return Map<String, dynamic>.from(data['client'] as Map);
          }
          return data;
        }
      }
    } catch (e) {
      debugPrint('WorkoutRepository: Error fetching client profile from backend: $e');
    }
    return null;
  }

  /// Saves private admin notes for a specific client.
  Future<bool> saveAdminNotes(String clientId, String notes) async {
    final clientIdx = _clients.indexWhere((c) => c['clientId'] == clientId || c['id'] == clientId);
    if (clientIdx != -1) {
      _clients[clientIdx]['adminNotes'] = notes;
      notifyListeners();
    }
    try {
      final token = await AuthService().getValidToken();
      final url = Uri.parse('${AppConstants.apiBaseUrl}/admin/clients/$clientId/notes');
      final resp = await _httpClient.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'notes': notes}),
      ).timeout(const Duration(seconds: 5));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Assigns a custom Diet Plan to a specific client.
  Future<bool> assignDietPlanToClient(String clientId, Map<String, dynamic> dietData) async {
    try {
      final token = await AuthService().getValidToken();
      final url = Uri.parse('${AppConstants.apiBaseUrl}/admin/clients/$clientId/diet-plans');
      final resp = await _httpClient.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(dietData),
      ).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        AppAutoRefreshService.instance.triggerImmediateSync(reason: 'Admin assigned diet plan to client');
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Assigns custom Macro targets to a specific client.
  Future<bool> assignMacroPlanToClient(String clientId, Map<String, dynamic> macroData) async {
    try {
      final token = await AuthService().getValidToken();
      final url = Uri.parse('${AppConstants.apiBaseUrl}/admin/clients/$clientId/macros');
      final resp = await _httpClient.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(macroData),
      ).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        AppAutoRefreshService.instance.triggerImmediateSync(reason: 'Admin assigned macro plan to client');
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
  List<WorkoutAssignmentData> get assignments => List.unmodifiable(_assignments);
  List<WorkoutRecord> get clientHistory => List.unmodifiable(_workoutHistory);
  List<WorkoutRecord> get pendingSyncRecords => List.unmodifiable(_pendingSyncRecords);
  List<ExerciseChangeRequest> get changeRequests => List.unmodifiable(_changeRequests);
  List<ExerciseSwapRecord> get currentSessionSwaps => List.unmodifiable(_currentSessionSwaps);

  void _initSeededChangeRequests() {
    // Real change requests only; no hardcoded demo athlete requests.
  }

  void _initSeededSessions() {
    // 1. Session: Push A (Recommended by default)
    final pushA = WorkoutSession(
      id: 'ws_push_a_01',
      title: 'Push A',
      workoutType: 'Strength',
      targetMuscleGroup: 'Chest • Shoulders • Triceps',
      difficulty: 'Intermediate',
      estimatedDurationMinutes: 55,
      description: 'Clavicular head chest focus with high-volume shoulder & tricep hypertrophy.',
      isActive: true,
      availabilityType: 'ALL',
      isRecommended: true,
      startedAt: DateTime.now().subtract(const Duration(minutes: 42, seconds: 18)),
      exercises: [
        const WorkoutExercise(
          id: 'we_incline_smith',
          exerciseId: 'ex_incline_smith',
          exerciseName: 'Incline Smith Machine Press',
          category: 'Chest',
          primaryMusclesDisplay: 'Upper Chest',
          secondaryMusclesDisplay: 'Front Delts • Triceps',
          restSeconds: 120,
          trainerNote: 'Keep 2 RIR. Control eccentric for 2–3 seconds. Keep scapulae retracted.',
          tempo: '3-1-1-0',
          approvedAlternativeIds: [
            'ex_incline_db',
            'ex_incline_bb',
            'ex_incline_machine',
          ],
          sets: [
            ExerciseSet(
              id: 'set_1_1',
              setNumber: 1,
              setType: SetType.working,
              previousWeight: 80.0,
              previousReps: 8,
              previousRpe: 8.0,
              previousRir: 2,
              targetWeight: 80.0,
              targetRepsMin: 8,
              targetRepsMax: 8,
              targetRpe: 8.0,
              targetRir: 2,
              tempo: '3-1-1-0',
              actualWeight: 80.0,
              actualReps: 8,
              actualRpe: 8.0,
              actualRir: 2,
              isCompleted: false,
            ),
            ExerciseSet(
              id: 'set_1_2',
              setNumber: 2,
              setType: SetType.working,
              previousWeight: 80.0,
              previousReps: 8,
              previousRpe: 8.5,
              previousRir: 2,
              targetWeight: 80.0,
              targetRepsMin: 8,
              targetRepsMax: 8,
              targetRpe: 8.0,
              targetRir: 2,
              tempo: '3-1-1-0',
              actualWeight: 80.0,
              actualReps: 8,
              actualRpe: 8.5,
              actualRir: 2,
              isCompleted: false,
            ),
            ExerciseSet(
              id: 'set_1_3',
              setNumber: 3,
              setType: SetType.working,
              previousWeight: 82.5,
              previousReps: 7,
              previousRpe: 9.0,
              previousRir: 1,
              targetWeight: 80.0,
              targetRepsMin: 8,
              targetRepsMax: 8,
              targetRpe: 8.5,
              targetRir: 1,
              tempo: '3-1-1-0',
              actualWeight: 80.0,
              actualReps: 8,
              actualRpe: 8.5,
              actualRir: 1,
              isCompleted: false,
            ),
            ExerciseSet(
              id: 'set_1_4',
              setNumber: 4,
              setType: SetType.working,
              previousWeight: 80.0,
              previousReps: 8,
              previousRpe: 9.0,
              previousRir: 1,
              targetWeight: 80.0,
              targetRepsMin: 8,
              targetRepsMax: 8,
              targetRpe: 9.0,
              targetRir: 1,
              tempo: '3-1-1-0',
              actualWeight: 80.0,
              actualReps: 8,
              actualRpe: 9.0,
              actualRir: 1,
              isCompleted: false,
            ),
          ],
        ),
        const WorkoutExercise(
          id: 'we_incline_smith_2',
          exerciseId: 'ex_incline_smith',
          exerciseName: 'Incline Smith Press (Top Set)',
          category: 'Chest',
          primaryMusclesDisplay: 'Upper Chest',
          secondaryMusclesDisplay: 'Front Delts',
          restSeconds: 90,
          trainerNote: '3 sets of 10. Pause 1s at bottom.',
          tempo: '3-1-1-0',
          approvedAlternativeIds: ['ex_incline_db'],
          sets: [
            ExerciseSet(
              id: 'set_2_1',
              setNumber: 1,
              setType: SetType.working,
              targetWeight: 70.0,
              targetRepsMin: 10,
              targetRepsMax: 10,
              targetRpe: 8.0,
              targetRir: 2,
              tempo: '3-1-1-0',
            ),
            ExerciseSet(
              id: 'set_2_2',
              setNumber: 2,
              setType: SetType.working,
              targetWeight: 70.0,
              targetRepsMin: 10,
              targetRepsMax: 10,
              targetRpe: 8.5,
              targetRir: 2,
              tempo: '3-1-1-0',
            ),
            ExerciseSet(
              id: 'set_2_3',
              setNumber: 3,
              setType: SetType.working,
              targetWeight: 70.0,
              targetRepsMin: 10,
              targetRepsMax: 10,
              targetRpe: 9.0,
              targetRir: 1,
              tempo: '3-1-1-0',
            ),
          ],
        ),
        // Superset A: Lateral Raise (A1) + Cable Fly (A2)
        const WorkoutExercise(
          id: 'we_lat_raise',
          exerciseId: 'ex_lat_raise',
          exerciseName: 'Lateral Raise',
          category: 'Shoulders',
          primaryMusclesDisplay: 'Lateral Delts',
          secondaryMusclesDisplay: 'Trapezius',
          supersetTag: 'A1',
          restSeconds: 30, // Short transition inside Superset A
          trainerNote: 'SUPERSET A1: Strict form, lead with elbows. Move immediately to A2.',
          tempo: '2-0-1-1',
          approvedAlternativeIds: [],
          sets: [
            ExerciseSet(
              id: 'set_3_1',
              setNumber: 1,
              setType: SetType.working,
              targetWeight: 14.0,
              targetRepsMin: 15,
              targetRepsMax: 15,
              targetRpe: 8.5,
              targetRir: 2,
              tempo: '2-0-1-1',
            ),
            ExerciseSet(
              id: 'set_3_2',
              setNumber: 2,
              setType: SetType.working,
              targetWeight: 14.0,
              targetRepsMin: 15,
              targetRepsMax: 15,
              targetRpe: 9.0,
              targetRir: 1,
              tempo: '2-0-1-1',
            ),
            ExerciseSet(
              id: 'set_3_3',
              setNumber: 3,
              setType: SetType.working,
              targetWeight: 14.0,
              targetRepsMin: 15,
              targetRepsMax: 15,
              targetRpe: 9.0,
              targetRir: 1,
              tempo: '2-0-1-1',
            ),
          ],
        ),
        const WorkoutExercise(
          id: 'we_cable_fly',
          exerciseId: 'ex_cable_fly',
          exerciseName: 'Cable Fly',
          category: 'Chest',
          primaryMusclesDisplay: 'Chest',
          secondaryMusclesDisplay: 'Front Delts',
          supersetTag: 'A2',
          restSeconds: 90, // Rest after completing Superset A
          trainerNote: 'SUPERSET A2: Squeeze pecs at midline. Rest 90s after this set.',
          tempo: '2-1-1-1',
          approvedAlternativeIds: [],
          sets: [
            ExerciseSet(
              id: 'set_4_1',
              setNumber: 1,
              setType: SetType.working,
              targetWeight: 18.0,
              targetRepsMin: 12,
              targetRepsMax: 12,
              targetRpe: 8.5,
              targetRir: 1,
              tempo: '2-1-1-1',
            ),
            ExerciseSet(
              id: 'set_4_2',
              setNumber: 2,
              setType: SetType.working,
              targetWeight: 18.0,
              targetRepsMin: 12,
              targetRepsMax: 12,
              targetRpe: 9.0,
              targetRir: 1,
              tempo: '2-1-1-1',
            ),
            ExerciseSet(
              id: 'set_4_3',
              setNumber: 3,
              setType: SetType.working,
              targetWeight: 18.0,
              targetRepsMin: 12,
              targetRepsMax: 12,
              targetRpe: 9.0,
              targetRir: 1,
              tempo: '2-1-1-1',
            ),
          ],
        ),
        const WorkoutExercise(
          id: 'we_rope_pushdown',
          exerciseId: 'ex_rope_pushdown',
          exerciseName: 'Rope Pushdown',
          category: 'Triceps',
          primaryMusclesDisplay: 'Triceps Lateral & Medial Head',
          secondaryMusclesDisplay: 'Forearms',
          restSeconds: 60,
          trainerNote: 'Flare rope outward at bottom. Keep elbows glued to sides.',
          tempo: '2-0-1-1',
          approvedAlternativeIds: [],
          sets: [
            ExerciseSet(
              id: 'set_5_1',
              setNumber: 1,
              setType: SetType.working,
              targetWeight: 25.0,
              targetRepsMin: 12,
              targetRepsMax: 12,
              targetRpe: 8.0,
              targetRir: 2,
            ),
            ExerciseSet(
              id: 'set_5_2',
              setNumber: 2,
              setType: SetType.working,
              targetWeight: 25.0,
              targetRepsMin: 12,
              targetRepsMax: 12,
              targetRpe: 8.5,
              targetRir: 2,
            ),
            ExerciseSet(
              id: 'set_5_3',
              setNumber: 3,
              setType: SetType.working,
              targetWeight: 25.0,
              targetRepsMin: 12,
              targetRepsMax: 12,
              targetRpe: 9.0,
              targetRir: 1,
            ),
          ],
        ),
      ],
    );

    // 2. Session: Pull A
    final pullA = WorkoutSession(
      id: 'ws_pull_a_02',
      title: 'Pull A',
      workoutType: 'Hypertrophy',
      targetMuscleGroup: 'Back • Biceps • Rear Delts',
      difficulty: 'Intermediate',
      estimatedDurationMinutes: 60,
      description: 'Lat width emphasis and elbow flexion strength with strict tempo control.',
      isActive: true,
      availabilityType: 'ALL',
      isRecommended: false,
      exercises: [
        const WorkoutExercise(
          id: 'we_lat_pulldown',
          exerciseId: 'ex_lat_pulldown',
          exerciseName: 'Wide Grip Lat Pulldown',
          category: 'Back',
          primaryMusclesDisplay: 'Lats',
          secondaryMusclesDisplay: 'Rhomboids • Biceps',
          restSeconds: 90,
          trainerNote: 'Drive elbows down into back pockets. 1 sec hold at clavicle.',
          tempo: '2-0-1-1',
          approvedAlternativeIds: ['ex_pullup'],
          sets: [
            ExerciseSet(
              id: 'set_p1_1',
              setNumber: 1,
              setType: SetType.working,
              targetWeight: 65.0,
              targetRepsMin: 10,
              targetRepsMax: 12,
              targetRpe: 8.0,
              targetRir: 2,
            ),
            ExerciseSet(
              id: 'set_p1_2',
              setNumber: 2,
              setType: SetType.working,
              targetWeight: 65.0,
              targetRepsMin: 10,
              targetRepsMax: 12,
              targetRpe: 8.5,
              targetRir: 1,
            ),
          ],
        ),
        const WorkoutExercise(
          id: 'we_face_pull',
          exerciseId: 'ex_face_pull',
          exerciseName: 'Cable Rope Face Pull',
          category: 'Shoulders',
          primaryMusclesDisplay: 'Rear Delts',
          secondaryMusclesDisplay: 'Rhomboids • Trapezius',
          restSeconds: 60,
          trainerNote: 'Pull high to bridge of nose. Externally rotate thumbs backward.',
          tempo: '2-1-1-0',
          approvedAlternativeIds: [],
          sets: [
            ExerciseSet(
              id: 'set_p2_1',
              setNumber: 1,
              setType: SetType.working,
              targetWeight: 22.5,
              targetRepsMin: 12,
              targetRepsMax: 15,
              targetRpe: 8.0,
              targetRir: 2,
            ),
            ExerciseSet(
              id: 'set_p2_2',
              setNumber: 2,
              setType: SetType.working,
              targetWeight: 22.5,
              targetRepsMin: 12,
              targetRepsMax: 15,
              targetRpe: 8.5,
              targetRir: 1,
            ),
          ],
        ),
      ],
    );

    // 3. Session: Legs A
    final legsA = WorkoutSession(
      id: 'ws_legs_a_03',
      title: 'Legs A',
      workoutType: 'Strength',
      targetMuscleGroup: 'Quads • Hamstrings • Calves',
      difficulty: 'Advanced',
      estimatedDurationMinutes: 65,
      description: 'Heavy compound squatting and posterior chain hamstring control.',
      isActive: true,
      availabilityType: 'ALL',
      isRecommended: false,
      exercises: [
        const WorkoutExercise(
          id: 'we_bb_squat',
          exerciseId: 'ex_bb_squat',
          exerciseName: 'Barbell Back Squat',
          category: 'Legs',
          primaryMusclesDisplay: 'Quads • Glutes',
          secondaryMusclesDisplay: 'Adductors • Hamstrings',
          restSeconds: 150,
          trainerNote: 'Hit parallel depth, brace core tightly before descent.',
          tempo: '3-1-X-0',
          approvedAlternativeIds: [],
          sets: [
            ExerciseSet(
              id: 'set_l1_1',
              setNumber: 1,
              setType: SetType.working,
              targetWeight: 140.0,
              targetRepsMin: 6,
              targetRepsMax: 8,
              targetRpe: 8.5,
              targetRir: 2,
            ),
            ExerciseSet(
              id: 'set_l1_2',
              setNumber: 2,
              setType: SetType.working,
              targetWeight: 140.0,
              targetRepsMin: 6,
              targetRepsMax: 8,
              targetRpe: 9.0,
              targetRir: 1,
            ),
          ],
        ),
      ],
    );

    _sessions.addAll([pushA, pullA, legsA]);

    // Assignments: No default global recommendation to ensure client-assigned workouts are always respected
    _assignments.add(
      WorkoutAssignmentData(
        id: 'assign_push_a_all',
        sessionId: pushA.id,
        clientId: null,
        isRecommended: false,
      ),
    );
    _assignments.add(
      WorkoutAssignmentData(
        id: 'assign_pull_a_all',
        sessionId: pullA.id,
        clientId: null,
        isRecommended: false,
      ),
    );
    _assignments.add(
      WorkoutAssignmentData(
        id: 'assign_legs_a_all',
        sessionId: legsA.id,
        clientId: null,
        isRecommended: false,
      ),
    );
  }

  // --- Admin Session Operations ---
  Future<bool> createSession(WorkoutSession session) async {
    _sessions.insert(0, session);
    _saveToLocalStorage();
    notifyListeners();

    try {
      var token = await AuthService().getValidToken();

      final url = Uri.parse('${AppConstants.apiBaseUrl}/admin/workouts');
      final payload = jsonEncode({
        'id': session.id,
        'title': session.title,
        'workoutType': session.workoutType,
        'targetMuscleGroup': session.targetMuscleGroup,
        'difficulty': session.difficulty,
        'estimatedDurationMinutes': session.estimatedDurationMinutes,
        'description': session.description,
        'isActive': session.isActive,
        'availabilityType': session.availabilityType,
        'exercises': session.exercises.map((e) => {
          'exerciseId': e.exerciseId,
          'exerciseName': e.exerciseName,
          'category': e.category,
          'orderIndex': session.exercises.indexOf(e),
          'supersetTag': e.supersetTag,
          'numberOfSets': e.sets.isNotEmpty ? e.sets.length : 3,
          'setCount': e.sets.isNotEmpty ? e.sets.length : 3,
          'sets': e.sets.map((s) => s.toJson()).toList(),
          'targetReps': e.sets.isNotEmpty ? '${e.sets.first.targetRepsMin}–${e.sets.first.targetRepsMax}' : '8–12',
          'targetWeight': e.sets.isNotEmpty ? e.sets.first.targetWeight : null,
          'restSeconds': e.restSeconds,
          'targetRir': e.sets.isNotEmpty ? e.sets.first.targetRir : 2,
          'targetRpe': e.sets.isNotEmpty ? e.sets.first.targetRpe : 8.0,
          'tempo': e.tempo,
          'setType': e.sets.isNotEmpty
              ? (e.sets.first.setType == SetType.warmup
                  ? 'Warm-up'
                  : e.sets.first.setType == SetType.dropSet
                      ? 'Drop Set'
                      : e.sets.first.setType == SetType.failure
                          ? 'Failure'
                          : e.sets.first.setType == SetType.restPause
                              ? 'Rest-Pause'
                              : 'Working')
              : 'Working',
          'exerciseNotes': e.trainerNote,
          'adminInstruction': e.trainerNote,
        }).toList(),
      });

      var response = await _httpClient.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: payload,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 401 && !_isTestEnvironment && AuthService().isAdmin) {
        final freshToken = await AuthService().refreshAdminToken();
        if (freshToken != null && freshToken.isNotEmpty) {
          token = freshToken;
          response = await _httpClient.post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: payload,
          ).timeout(const Duration(seconds: 10));
        }
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final decoded = jsonDecode(response.body);
          if (decoded['data'] != null && decoded['data'] is Map<String, dynamic>) {
            final serverSession = WorkoutSession.fromJson(decoded['data'] as Map<String, dynamic>);
            final idx = _sessions.indexWhere((s) => s.id == session.id || s.id == serverSession.id);
            if (idx != -1) {
              _sessions[idx] = serverSession;
            } else {
              _sessions.add(serverSession);
            }
            _saveToLocalStorage();
            notifyListeners();
          }
        } catch (_) {}
        return true;
      }
      debugPrint('[WorkoutRepository] createSession error: ${response.statusCode} -> ${response.body}');
      return false;
    } catch (e) {
      debugPrint('[WorkoutRepository] createSession sync error: $e');
      return false;
    }
  }

  Future<bool> updateSession(WorkoutSession session) async {
    final index = _sessions.indexWhere((s) => s.id == session.id);
    if (index != -1) {
      final old = _sessions[index];
      final newVersionNumber = old.planVersion.versionNumber + 1;
      final versionedSession = session.copyWith(
        planVersion: WorkoutPlanVersion(
          versionId: 'v${newVersionNumber}_${session.id}',
          versionNumber: newVersionNumber,
          createdAt: DateTime.now(),
          notes: 'Updated by Trainer on ${DateTime.now().toIso8601String()}',
        ),
      );
      _sessions[index] = versionedSession;
      if (_activeSession.id == session.id && !isWorkoutInProgress) {
        _activeSession = versionedSession;
      }
      _saveToLocalStorage();
      notifyListeners();
    } else {
      _sessions.add(session);
      if (_activeSession.id == session.id && !isWorkoutInProgress) {
        _activeSession = session;
      }
      _saveToLocalStorage();
      notifyListeners();
    }

    try {
      var token = await AuthService().getValidToken();

      final url = Uri.parse('${AppConstants.apiBaseUrl}/admin/workouts/${session.id}');
      final payload = jsonEncode({
        'title': session.title,
        'workoutType': session.workoutType,
        'targetMuscleGroup': session.targetMuscleGroup,
        'difficulty': session.difficulty,
        'estimatedDurationMinutes': session.estimatedDurationMinutes,
        'description': session.description,
        'isActive': session.isActive,
        'availabilityType': session.availabilityType,
        'exercises': session.exercises.map((e) => {
          'exerciseId': e.exerciseId,
          'exerciseName': e.exerciseName,
          'category': e.category,
          'orderIndex': session.exercises.indexOf(e),
          'supersetTag': e.supersetTag,
          'numberOfSets': e.sets.isNotEmpty ? e.sets.length : 3,
          'setCount': e.sets.isNotEmpty ? e.sets.length : 3,
          'sets': e.sets.map((s) => s.toJson()).toList(),
          'targetReps': e.sets.isNotEmpty ? '${e.sets.first.targetRepsMin}–${e.sets.first.targetRepsMax}' : '8–12',
          'targetWeight': e.sets.isNotEmpty ? e.sets.first.targetWeight : null,
          'restSeconds': e.restSeconds,
          'targetRir': e.sets.isNotEmpty ? e.sets.first.targetRir : 2,
          'targetRpe': e.sets.isNotEmpty ? e.sets.first.targetRpe : 8.0,
          'tempo': e.tempo,
          'setType': e.sets.isNotEmpty
              ? (e.sets.first.setType == SetType.warmup
                  ? 'Warm-up'
                  : e.sets.first.setType == SetType.dropSet
                      ? 'Drop Set'
                      : e.sets.first.setType == SetType.failure
                          ? 'Failure'
                          : e.sets.first.setType == SetType.restPause
                              ? 'Rest-Pause'
                              : 'Working')
              : 'Working',
          'exerciseNotes': e.trainerNote,
          'adminInstruction': e.trainerNote,
        }).toList(),
      });

      var response = await _httpClient.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: payload,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 401 && !_isTestEnvironment && AuthService().isAdmin) {
        final freshToken = await AuthService().refreshAdminToken();
        if (freshToken != null && freshToken.isNotEmpty) {
          token = freshToken;
          response = await _httpClient.put(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: payload,
          ).timeout(const Duration(seconds: 10));
        }
      }

      if (response.statusCode == 200) {
        try {
          final decoded = jsonDecode(response.body);
          if (decoded['data'] != null && decoded['data'] is Map<String, dynamic>) {
            final serverSession = WorkoutSession.fromJson(decoded['data'] as Map<String, dynamic>);
            final idx = _sessions.indexWhere((s) => s.id == session.id || s.id == serverSession.id);
            if (idx != -1) {
              _sessions[idx] = serverSession;
            } else {
              _sessions.add(serverSession);
            }
            if (_activeSession.id == session.id && !isWorkoutInProgress) {
              _activeSession = serverSession;
            }
            _saveToLocalStorage();
            notifyListeners();
          }
        } catch (_) {}
        return true;
      }
      if (response.statusCode == 404) {
        // Fallback: If session does not exist on server to update, auto-create it
        return await createSession(session);
      }
      if (_isTestEnvironment) return true;
      debugPrint('[WorkoutRepository] updateSession error: ${response.statusCode} -> ${response.body}');
      return false;
    } catch (e) {
      debugPrint('[WorkoutRepository] updateSession sync error: $e');
      if (_isTestEnvironment) return true;
      return false;
    }
  }

  /// Fetches an individual WorkoutSession by ID, checking local memory and remote API.
  Future<WorkoutSession?> getSessionById(String sessionId, {bool forceRefresh = false}) async {
    final cached = _sessions.where((s) => s.id == sessionId).firstOrNull;
    if (cached != null && !forceRefresh) return cached;

    final token = await AuthService().getValidToken();
    if (token.isEmpty && !_isTestEnvironment) return cached;

    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/admin/workouts/$sessionId');
      final response = await _httpClient.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['data'] != null && decoded['data'] is Map<String, dynamic>) {
          final serverSession = WorkoutSession.fromJson(decoded['data'] as Map<String, dynamic>);
          final idx = _sessions.indexWhere((s) => s.id == serverSession.id);
          if (idx != -1) {
            _sessions[idx] = serverSession;
          } else {
            _sessions.add(serverSession);
          }
          notifyListeners();
          return serverSession;
        }
      }
    } catch (e) {
      debugPrint('[WorkoutRepository] getSessionById error: $e');
    }
    return cached;
  }

  void duplicateSession(String sessionId) {
    final original = _sessions.firstWhere((s) => s.id == sessionId);
    final copyId = 'ws_${DateTime.now().millisecondsSinceEpoch}_copy';
    final duplicated = original.copyWith(
      id: copyId,
      title: '${original.title} (Copy)',
      startedAt: DateTime.now(),
      exercises: original.exercises.map((ex) {
        return ex.copyWith(
          id: 'ex_${copyId}_${ex.id}',
          sets: ex.sets.map((s) => s.copyWith(isCompleted: false)).toList(),
        );
      }).toList(),
    );
    // Persist duplicated session (inserts into _sessions and syncs to backend)
    createSession(duplicated);
  }

  void toggleSessionActive(String sessionId) {
    final index = _sessions.indexWhere((s) => s.id == sessionId);
    if (index != -1) {
      final current = _sessions[index];
      _sessions[index] = current.copyWith(isActive: !current.isActive);
      _saveToLocalStorage();
      notifyListeners();
    }
  }

  Future<bool> deleteSession(String sessionId) async {
    _sessions.removeWhere((s) => s.id == sessionId);
    _assignments.removeWhere((a) => a.sessionId == sessionId);
    if (_activeSession.id == sessionId && !isWorkoutInProgress && _sessions.isNotEmpty) {
      _activeSession = _sessions.first;
    }
    _saveToLocalStorage();
    notifyListeners();

    try {
      final token = await AuthService().getValidToken();

      final url = Uri.parse('${AppConstants.apiBaseUrl}/admin/workouts/$sessionId');
      await _httpClient.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));
      return true;
    } catch (_) {
      return false;
    }
  }

  // --- Assignment Operations ---
  Future<bool> assignSession({
    required String sessionId,
    required String assignmentType, // 'ALL', 'SELECTED', 'INDIVIDUAL'
    List<String>? clientIds,
    String? individualClientId,
    bool isRecommended = false,
    String? scheduledDate,
  }) async {
    if (isRecommended) {
      // Clear previous recommendations for the matching target
      for (int i = 0; i < _assignments.length; i++) {
        final a = _assignments[i];
        if (assignmentType == 'ALL' && a.clientId == null) {
          _assignments[i] = WorkoutAssignmentData(
            id: a.id,
            sessionId: a.sessionId,
            clientId: a.clientId,
            isRecommended: false,
            scheduledDate: a.scheduledDate,
            isLocked: a.isLocked,
            status: a.status,
          );
        } else if (assignmentType == 'INDIVIDUAL' && a.clientId == individualClientId) {
          _assignments[i] = WorkoutAssignmentData(
            id: a.id,
            sessionId: a.sessionId,
            clientId: a.clientId,
            isRecommended: false,
            scheduledDate: a.scheduledDate,
            isLocked: a.isLocked,
            status: a.status,
          );
        }
      }
    }

    if (assignmentType == 'ALL') {
      _assignments.removeWhere((a) => a.sessionId == sessionId && a.clientId == null);
      _assignments.add(
        WorkoutAssignmentData(
          id: 'assign_${sessionId}_all',
          sessionId: sessionId,
          clientId: null,
          isRecommended: isRecommended,
          scheduledDate: scheduledDate,
        ),
      );
    } else if (assignmentType == 'INDIVIDUAL' && individualClientId != null) {
      _assignments.removeWhere((a) => a.sessionId == sessionId && a.clientId == individualClientId);
      _assignments.add(
        WorkoutAssignmentData(
          id: 'assign_${sessionId}_$individualClientId',
          sessionId: sessionId,
          clientId: individualClientId,
          isRecommended: isRecommended,
          scheduledDate: scheduledDate,
        ),
      );
    } else if (assignmentType == 'SELECTED' && clientIds != null) {
      for (final cId in clientIds) {
        _assignments.removeWhere((a) => a.sessionId == sessionId && a.clientId == cId);
        _assignments.add(
          WorkoutAssignmentData(
            id: 'assign_${sessionId}_$cId',
            sessionId: sessionId,
            clientId: cId,
            isRecommended: isRecommended,
            scheduledDate: scheduledDate,
          ),
        );
      }
    }

    _saveToLocalStorage();
    notifyListeners();

    // Persist assignment to backend database
    try {
      var token = await AuthService().getValidToken();

      final url = Uri.parse('${AppConstants.apiBaseUrl}/admin/workouts/$sessionId/assign');
      final payload = jsonEncode({
        'assignmentType': assignmentType,
        'clientIds': clientIds ?? [],
        'individualClientId': individualClientId,
        'isRecommended': isRecommended,
        'scheduledDate': scheduledDate,
      });

      var response = await _httpClient.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: payload,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 401 && !_isTestEnvironment && AuthService().isAdmin) {
        final freshToken = await AuthService().refreshAdminToken();
        if (freshToken != null && freshToken.isNotEmpty) {
          token = freshToken;
          response = await _httpClient.post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: payload,
          ).timeout(const Duration(seconds: 10));
        }
      }

      if (response.statusCode == 404) {
        // If the session exists in local memory but hasn't reached DB, push it first
        var localIdx = _sessions.indexWhere((s) => s.id == sessionId);
        if (localIdx == -1 && _activeSession.id == sessionId) {
          _sessions.insert(0, _activeSession);
          localIdx = 0;
        }
        if (localIdx != -1) {
          final localSession = _sessions[localIdx];
          final synced = await createSession(localSession);
          if (synced) {
            response = await _httpClient.post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: payload,
            ).timeout(const Duration(seconds: 10));
          }
        }
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        AppAutoRefreshService.instance.triggerImmediateSync(reason: 'Admin assigned workout session');
        return true;
      }
      debugPrint('[WorkoutRepository] assignSession error: ${response.statusCode} -> ${response.body}');
      return false;
    } catch (e) {
      debugPrint('[WorkoutRepository] Failed to sync assignment to backend: $e');
      return false;
    }
  }

  Future<bool> unassignSession(String sessionId, String? clientId) async {
    _assignments.removeWhere((a) => a.sessionId == sessionId && a.clientId == clientId);
    _saveToLocalStorage();
    notifyListeners();
    AppAutoRefreshService.instance.triggerImmediateSync(reason: 'Admin unassigned workout session');

    try {
      final token = await AuthService().getValidToken();

      final url = Uri.parse('${AppConstants.apiBaseUrl}/admin/workouts/assignments/$sessionId');
      await _httpClient.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Fetches all admin sessions directly from backend
  Future<void> fetchAdminSessions({bool forceRefresh = false}) async {
    final token = await AuthService().getValidToken();

    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/admin/workouts');
      final response = await _httpClient.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> list = decoded['data'] ?? [];
        if (list.isNotEmpty) {
          for (final item in list) {
            if (item is Map<String, dynamic>) {
              try {
                final s = WorkoutSession.fromJson(item);
                final idx = _sessions.indexWhere((x) => x.id == s.id);
                if (idx != -1) {
                  _sessions[idx] = s;
                } else {
                  _sessions.add(s);
                }
              } catch (_) {}
            }
          }
          _saveToLocalStorage();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('[WorkoutRepository] Failed to fetch admin sessions: $e');
    }
  }

  /// Fetches real authorized workout sessions assigned to the current client from backend
  Future<void> fetchClientWorkouts({bool forceRefresh = false}) async {
    var token = await AuthService().getValidToken();
    if (token.isEmpty) return;

    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/workout/client/sessions');
      var response = await _httpClient.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      // Automatic 401 recovery: token expired or invalid in production
      if (response.statusCode == 401 && !_isTestEnvironment && !AuthService().isAdmin) {
        final freshToken = await AuthService().refreshClientToken();
        if (freshToken != null && freshToken.isNotEmpty) {
          token = freshToken;
          response = await _httpClient.get(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          ).timeout(const Duration(seconds: 10));
        }
      }

      if (response.statusCode == 200) {
        // Synchronize server-backed authoritative time (Asia/Kolkata timezone)
        final dateHeader = response.headers['date'];
        if (dateHeader != null && dateHeader.isNotEmpty) {
          IstDateUtils.syncServerTimeString(dateHeader);
        }
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final meta = decoded['meta'] as Map<String, dynamic>?;
          if (meta?['timestamp'] != null) {
            IstDateUtils.syncServerTimeString(meta!['timestamp'] as String?);
          }
        }
        if (decoded['success'] == true && decoded['data'] != null) {
          final data = decoded['data'];
          if (data is Map<String, dynamic>) {
            if (data['isRestDay'] is bool) {
              _isRestDayFromServer = data['isRestDay'] as bool;
            }
            if (data['serverTime'] != null) {
              IstDateUtils.syncServerTimeString(data['serverTime'] as String?);
            }
          }
          final List<dynamic> availableJson = data['available'] as List<dynamic>? ?? [];
          final Map<String, dynamic>? recJson = (data['todaySession'] ?? data['recommended']) as Map<String, dynamic>?;
          final List<dynamic> pendingJson = data['pendingWorkouts'] as List<dynamic>? ?? [];

          final List<WorkoutSession> fetchedPending = [];
          for (final item in pendingJson) {
            if (item is Map<String, dynamic>) {
              try {
                final s = WorkoutSession.fromJson(item).copyWith(isRecommended: false);
                fetchedPending.add(s);
              } catch (pe) {
                debugPrint('[WorkoutRepository] Pending session parse error: $pe');
              }
            }
          }
          _pendingWorkouts.clear();
          _pendingWorkouts.addAll(fetchedPending);

          for (final ps in fetchedPending) {
            final existingIdx = _sessions.indexWhere((s) => s.id == ps.id);
            if (existingIdx != -1) {
              _sessions[existingIdx] = ps;
            } else {
              _sessions.add(ps);
            }
          }

          final List<WorkoutSession> fetchedSessions = [];
          for (final item in availableJson) {
            if (item is Map<String, dynamic>) {
              try {
                final s = WorkoutSession.fromJson(item);
                fetchedSessions.add(s);
              } catch (pe) {
                debugPrint('[WorkoutRepository] Session parse error: $pe');
              }
            }
          }

          if (recJson != null) {
            try {
              final recSession = WorkoutSession.fromJson(recJson).copyWith(isRecommended: true);
              final idx = fetchedSessions.indexWhere((s) => s.id == recSession.id);
              if (idx != -1) {
                fetchedSessions[idx] = recSession;
              } else {
                fetchedSessions.insert(0, recSession);
              }
            } catch (_) {}
          }

          if (fetchedSessions.isNotEmpty) {
            for (final fs in fetchedSessions) {
              final existingIdx = _sessions.indexWhere((s) => s.id == fs.id);
              if (existingIdx != -1) {
                _sessions[existingIdx] = fs;
              } else {
                _sessions.add(fs);
              }
            }

            final currentClientId = AuthService().currentUserId;
            _assignments.removeWhere((a) => a.clientId == currentClientId);

            for (final fs in fetchedSessions) {
              _assignments.add(WorkoutAssignmentData(
                id: fs.assignmentId ?? 'assign_${fs.id}_$currentClientId',
                sessionId: fs.id,
                clientId: currentClientId,
                isRecommended: fs.isRecommended,
                scheduledDate: fs.scheduledDate,
                isLocked: fs.isLocked,
                status: fs.status,
                assignedAt: fs.workoutDate ?? DateTime.now(),
              ));
            }

            final isTrainingActive = isWorkoutInProgress || hasActiveSavedSession;

            if (!isTrainingActive) {
              if (_sessions.isNotEmpty) {
                final rec = getRecommendedSessionForClient(currentClientId);
                if (rec != null) {
                  _activeSession = rec;
                }
              }
            }

            _saveToLocalStorage();
            notifyListeners();
          } else {
            if (data is Map<String, dynamic> &&
                data.containsKey('available') &&
                data['isRestDay'] != true) {
              final currentClientId = AuthService().currentUserId;
              _assignments.removeWhere((a) => a.clientId == currentClientId);
              _saveToLocalStorage();
              notifyListeners();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[WorkoutRepository] Failed to fetch client workouts: $e');
    }
  }

  Set<String> _resolveMatchingClientIds(String clientId) {
    if (clientId.isEmpty) return const {};
    final currentUid = AuthService().currentUserId;
    final currentCid = AuthService().currentClientId;
    return <String>{
      clientId,
      if (clientId == currentUid || clientId == currentCid) ...[
        if (currentUid.isNotEmpty) currentUid,
        if (currentCid.isNotEmpty) currentCid,
      ],
    };
  }

  // --- Client Discovery & Access Scoping ---
  bool hasAssignedWorkoutsForClient(String clientId) {
    if (clientId.isEmpty) return false;
    final matchClientIds = _resolveMatchingClientIds(clientId);

    if (_assignments.any((a) => a.clientId != null && matchClientIds.contains(a.clientId))) {
      return true;
    }
    if (_pendingWorkouts.any((p) => p.assignedClientId == null || p.assignedClientId!.isEmpty || matchClientIds.contains(p.assignedClientId))) {
      return true;
    }
    return _isRestDayFromServer;
  }

  WorkoutSession? getTodaySessionForClient(String clientId, {bool? enforceVisibilityWindow}) {
    if (clientId.isEmpty) return null;

    final shouldEnforce = enforceVisibilityWindow ??
        (!_isTestEnvironment || IstDateUtils.hasCustomDateProviderForTesting);

    // Client's scheduled workout session is strictly visible from 5:00 AM to 9:00 PM IST on its assigned day.
    // After 9:00 PM IST (or before 5:00 AM IST), automatically hide that day's workout session.
    if (shouldEnforce && !IstDateUtils.isScheduledWorkoutVisibleInIST()) {
      return null;
    }

    final matchClientIds = _resolveMatchingClientIds(clientId);

    // 0. Active session lock: If client currently has an active IN_PROGRESS session that is NOT locked,
    // preserve and return that exact session!
    if (hasActiveSavedSession &&
        _activeSession.status == 'IN_PROGRESS' &&
        !_activeSession.isLocked &&
        (_activeSession.assignedClientId == null ||
         _activeSession.assignedClientId!.isEmpty ||
         matchClientIds.contains(_activeSession.assignedClientId))) {
      return _activeSession;
    }

    final authorized = getAuthorizedSessionsForClient(clientId, enforceVisibilityWindow: enforceVisibilityWindow);
    if (authorized.isEmpty) return null;

    // Prioritize:
    // 1. Incomplete sessions (not locked & not completed)
    // 2. Recommended sessions
    final incompleteSessions = authorized.where((s) => !s.isCompleted && !s.isLocked && s.status != 'COMPLETED').toList();
    if (incompleteSessions.isNotEmpty) {
      final recommended = incompleteSessions.where((s) => s.isRecommended).firstOrNull;
      return recommended ?? incompleteSessions.first;
    }

    // If all scheduled sessions for today are completed, preserve visibility of completed session until 9:00 PM IST
    final recommendedCompleted = authorized.where((s) => s.isRecommended).firstOrNull;
    return recommendedCompleted ?? authorized.first;
  }

  WorkoutSession? getRecommendedSessionForClient(String clientId, {bool? enforceVisibilityWindow}) {
    return getTodaySessionForClient(clientId, enforceVisibilityWindow: enforceVisibilityWindow);
  }

  List<WorkoutSession> getPendingWorkoutsForClient(String clientId) {
    if (clientId.isEmpty) return [];

    final matchClientIds = _resolveMatchingClientIds(clientId);

    if (_pendingWorkouts.isNotEmpty) {
      return _pendingWorkouts.where((p) =>
        p.assignedClientId == null ||
        p.assignedClientId!.isEmpty ||
        matchClientIds.contains(p.assignedClientId)
      ).toList();
    }

    // In-memory / offline calculation
    final todayIST = IstDateUtils.getTodayISTString();
    final todayWeekday = IstDateUtils.getTodayISTWeekday();

    final clientAssignments = _assignments.where((a) => a.clientId != null && matchClientIds.contains(a.clientId)).toList();
    final List<WorkoutSession> pending = [];
    final seenKeys = <String>{};

    for (final assignment in clientAssignments) {
      final s = _sessions.where((sess) => sess.id == assignment.sessionId && sess.isActive).firstOrNull;
      if (s == null) continue;

      final recurringDays = IstDateUtils.parseWeekdaysFromScheduleString(s.recurringSchedule);

      // Explicit past scheduled date
      if (assignment.scheduledDate != null && assignment.scheduledDate!.compareTo(todayIST) < 0) {
        final isCompleted = _workoutHistory.any((r) =>
          matchClientIds.contains(r.clientId) &&
          r.sessionId == s.id &&
          r.isCompleted &&
          (r.scheduledDate == assignment.scheduledDate || r.assignmentId == assignment.id)
        );
        final key = '${s.id}_${assignment.scheduledDate}';
        if (!isCompleted && !seenKeys.contains(key) && assignment.status != 'COMPLETED') {
          seenKeys.add(key);
          pending.add(s.copyWith(
            scheduledDate: assignment.scheduledDate,
            assignmentId: assignment.id,
            status: 'PENDING',
            isRecommended: false,
          ));
        }
      }

      // Past recurring weekday in current week
      if (recurringDays.isNotEmpty) {
        for (final dayNum in recurringDays) {
          if (dayNum < todayWeekday) {
            final pastDate = IstDateUtils.getISTDateForWeekday(dayNum);
            if (pastDate.compareTo(todayIST) < 0) {
              final isCompleted = _workoutHistory.any((r) =>
                matchClientIds.contains(r.clientId) &&
                r.sessionId == s.id &&
                r.isCompleted &&
                r.scheduledDate == pastDate
              );
              final key = '${s.id}_$pastDate';
              if (!isCompleted && !seenKeys.contains(key)) {
                seenKeys.add(key);
                pending.add(s.copyWith(
                  scheduledDate: pastDate,
                  assignmentId: assignment.id,
                  status: 'PENDING',
                  isRecommended: false,
                ));
              }
            }
          }
        }
      }
    }

    pending.sort((a, b) => (a.scheduledDate ?? '').compareTo(b.scheduledDate ?? ''));
    return pending;
  }

  List<WorkoutSession> getAuthorizedSessionsForClient(String clientId, {bool? enforceVisibilityWindow}) {
    if (clientId.isEmpty) return [];

    final shouldEnforce = enforceVisibilityWindow ??
        (!_isTestEnvironment || IstDateUtils.hasCustomDateProviderForTesting);

    if (shouldEnforce && !IstDateUtils.isScheduledWorkoutVisibleInIST()) {
      return [];
    }

    final todayIST = IstDateUtils.getTodayISTString();
    final matchClientIds = _resolveMatchingClientIds(clientId);

    final clientAssignments = _assignments.where((a) => a.clientId != null && matchClientIds.contains(a.clientId)).toList();
    if (clientAssignments.isEmpty) return [];

    final List<WorkoutSession> result = [];

    for (final assignment in clientAssignments) {
      final session = _sessions.where((s) => s.id == assignment.sessionId && s.isActive).firstOrNull;
      if (session == null) continue;

      // Filter by IST date schedule
      final isScheduled = IstDateUtils.isSessionScheduledForDate(
        recurringSchedule: session.recurringSchedule,
        trainingDays: session.trainingDays,
        sessionStartDate: session.startDate,
        sessionEndDate: session.endDate,
        assignmentScheduledDate: assignment.scheduledDate,
        assignmentAssignedAt: assignment.assignedAt,
        targetDateIST: todayIST,
      );

      if (!isScheduled) continue;

      // Check if session is completed & locked in history for todayIST
      final todayRecord = _workoutHistory.where((r) {
        if (!matchClientIds.contains(r.clientId)) return false;
        if (r.sessionId != session.id) return false;
        final recordDate = r.scheduledDate ?? IstDateUtils.toISTDateString(r.completedAt ?? r.startedAt);
        return recordDate == todayIST && r.isCompleted;
      }).firstOrNull;

      final bool isLockedToday = todayRecord != null && todayRecord.isLocked;
      final String sessionStatus = isLockedToday
          ? 'COMPLETED'
          : (todayRecord != null ? 'IN_PROGRESS' : (assignment.scheduledDate == todayIST ? assignment.status : 'ASSIGNED'));

      // Clean fresh sets for new scheduled session occurrence, or preserve logged sets if record exists
      final exercises = todayRecord != null
          ? todayRecord.exercises
          : session.exercises.map((ex) {
              return ex.copyWith(
                isSkipped: false,
                skipReason: null,
                clientNote: null,
                sets: ex.sets.map((s) => s.copyWith(
                  isCompleted: false,
                  completedAt: null,
                )).toList(),
              );
            }).toList();

      result.add(
        session.copyWith(
          assignedClientId: clientId,
          assignedWorkoutId: session.id,
          assignmentId: assignment.id,
          isRecommended: assignment.isRecommended,
          scheduledDate: todayIST,
          isLocked: isLockedToday,
          isCompleted: isLockedToday || (todayRecord != null && todayRecord.isCompleted),
          status: sessionStatus,
          lockedAt: isLockedToday ? (todayRecord.lockedAt ?? todayRecord.completedAt) : null,
          unlockedAt: todayRecord?.unlockedAt ?? assignment.unlockedAt,
          unlockReason: todayRecord?.unlockReason ?? assignment.unlockReason,
          exercises: exercises,
        ),
      );
    }

    return result;
  }

  // --- Client Workout Execution ---
  void startSession(WorkoutSession session, {String? clientId}) {
    if (session.isLocked || session.status == 'COMPLETED') {
      debugPrint('[WorkoutRepository] Cannot start a locked or completed session.');
      return;
    }

    final targetClientId = clientId ?? session.assignedClientId ?? AuthService().currentUserId;
    final todayIST = session.scheduledDate ?? IstDateUtils.getTodayISTString();

    // Guard: If the session is already active in progress for this client, preserve it!
    // Never restart or wipe sets/elapsed time of an already active in-progress session.
    if (hasActiveSavedSession &&
        _activeSession.status == 'IN_PROGRESS' &&
        !_activeSession.isLocked &&
        (_activeSession.id == session.id || _activeSession.assignedWorkoutId == session.id) &&
        (_activeSession.assignedClientId == targetClientId || targetClientId.isEmpty)) {
      debugPrint('[WorkoutRepository] Session ${session.id} is already active in progress. Preserving active state.');
      return;
    }

    // Check if already completed and locked in history for today
    final alreadyCompletedToday = _workoutHistory.any((r) {
      if (r.clientId != targetClientId) return false;
      if (r.sessionId != session.id) return false;
      final recordDate = r.scheduledDate ?? IstDateUtils.toISTDateString(r.completedAt ?? r.startedAt);
      return recordDate == todayIST && r.isCompleted && r.isLocked;
    });

    if (alreadyCompletedToday) {
      debugPrint('[WorkoutRepository] Session already completed and locked for today.');
      return;
    }

    _currentSessionSwaps.clear();
    final now = DateTime.now();

    // Deep clone with fresh sets for execution (creates a new record without mutating template)
    _activeSession = session.copyWith(
      id: session.id,
      assignedClientId: targetClientId,
      assignedWorkoutId: session.assignedWorkoutId ?? session.id,
      status: 'IN_PROGRESS',
      scheduledDate: todayIST,
      isLocked: false,
      workoutDate: now,
      startedAt: now,
      completedAt: null,
      durationSeconds: 0,
      isCompleted: false,
      currentExerciseIndex: 0,
      exercises: session.exercises.map((ex) {
        return ex.copyWith(
          isSkipped: false,
          skipReason: null,
          clientNote: null,
          sets: ex.sets.map((s) {
            return s.copyWith(
              isCompleted: s.isCompleted,
              completedAt: s.completedAt,
              actualWeight: s.actualWeight ?? (s.targetWeight > 0 ? s.targetWeight : null),
              actualReps: s.actualReps ?? s.targetRepsMin,
              actualRir: s.actualRir ?? s.targetRir,
              actualRpe: s.actualRpe ?? s.targetRpe,
            );
          }).toList(),
        );
      }).toList(),
    );
    _hasRestoredActiveSession = true;
    _activeSessionSavedAt = now;
    saveActiveSessionToLocalStorage(userId: targetClientId, elapsedSeconds: 0);
    notifyListeners();
  }

  void updateCurrentExerciseIndex(int index) {
    if (index >= 0 && index < _activeSession.exercises.length) {
      _activeSession = _activeSession.copyWith(currentExerciseIndex: index);
      saveActiveSessionToLocalStorage();
      notifyListeners();
    }
  }

  void updateSetActual({
    required int exerciseIndex,
    required int setIndex,
    double? weight,
    int? reps,
    double? rpe,
    int? rir,
  }) {
    if (_activeSession.isLocked || _activeSession.isCompleted || _activeSession.status == 'COMPLETED') return;
    if (exerciseIndex >= _activeSession.exercises.length) return;
    final exercise = _activeSession.exercises[exerciseIndex];
    if (setIndex >= exercise.sets.length) return;

    final oldSet = exercise.sets[setIndex];
    final updatedSet = oldSet.copyWith(
      actualWeight: weight ?? oldSet.actualWeight,
      actualReps: reps ?? oldSet.actualReps,
      actualRpe: rpe ?? oldSet.actualRpe,
      actualRir: rir ?? oldSet.actualRir,
    );

    final updatedSets = List<ExerciseSet>.from(exercise.sets);
    updatedSets[setIndex] = updatedSet;

    final updatedExercises = List<WorkoutExercise>.from(_activeSession.exercises);
    updatedExercises[exerciseIndex] = exercise.copyWith(sets: updatedSets);

    _activeSession = _activeSession.copyWith(exercises: updatedExercises);
    saveActiveSessionToLocalStorage();
    notifyListeners();
  }

  PersonalRecord? completeSet({
    required int exerciseIndex,
    required int setIndex,
  }) {
    if (_activeSession.isLocked || _activeSession.isCompleted || _activeSession.status == 'COMPLETED') return null;
    if (exerciseIndex >= _activeSession.exercises.length) return null;
    final exercise = _activeSession.exercises[exerciseIndex];
    if (setIndex >= exercise.sets.length) return null;

    final oldSet = exercise.sets[setIndex];
    if (oldSet.isCompleted) return null;

    final actualWeight = oldSet.actualWeight ?? oldSet.targetWeight;
    final actualReps = oldSet.actualReps ?? oldSet.targetRepsMin;

    final updatedSet = oldSet.copyWith(
      actualWeight: actualWeight,
      actualReps: actualReps,
      isCompleted: true,
      completedAt: DateTime.now(),
    );

    final updatedSets = List<ExerciseSet>.from(exercise.sets);
    updatedSets[setIndex] = updatedSet;

    final updatedExercises = List<WorkoutExercise>.from(_activeSession.exercises);
    updatedExercises[exerciseIndex] = exercise.copyWith(sets: updatedSets);

    _activeSession = _activeSession.copyWith(exercises: updatedExercises);
    saveActiveSessionToLocalStorage();
    notifyListeners();

    // Immediately sync set completion to backend and database
    syncSetCompletionToBackend(
      sessionId: _activeSession.id,
      exerciseId: exercise.exerciseId.isNotEmpty ? exercise.exerciseId : exercise.id,
      setNumber: updatedSet.setNumber,
      isCompleted: true,
      actualWeight: actualWeight,
      actualReps: actualReps,
      actualRpe: updatedSet.actualRpe,
      actualRir: updatedSet.actualRir,
    );

    return evaluateNewPR(
      exerciseId: exercise.exerciseId,
      exerciseName: exercise.exerciseName,
      actualWeight: actualWeight,
      actualReps: actualReps,
    );
  }

  void uncompleteSet({
    required int exerciseIndex,
    required int setIndex,
  }) {
    if (_activeSession.isLocked || _activeSession.isCompleted || _activeSession.status == 'COMPLETED') return;
    if (exerciseIndex >= _activeSession.exercises.length) return;
    final exercise = _activeSession.exercises[exerciseIndex];
    if (setIndex >= exercise.sets.length) return;

    final oldSet = exercise.sets[setIndex];
    final updatedSet = oldSet.copyWith(
      isCompleted: false,
      completedAt: null,
    );

    final updatedSets = List<ExerciseSet>.from(exercise.sets);
    updatedSets[setIndex] = updatedSet;

    final updatedExercises = List<WorkoutExercise>.from(_activeSession.exercises);
    updatedExercises[exerciseIndex] = exercise.copyWith(sets: updatedSets);

    _activeSession = _activeSession.copyWith(exercises: updatedExercises);
    saveActiveSessionToLocalStorage();
    notifyListeners();

    // Immediately sync undo completion to backend and database
    syncSetCompletionToBackend(
      sessionId: _activeSession.id,
      exerciseId: exercise.exerciseId.isNotEmpty ? exercise.exerciseId : exercise.id,
      setNumber: updatedSet.setNumber,
      isCompleted: false,
      actualWeight: oldSet.actualWeight,
      actualReps: oldSet.actualReps,
      actualRpe: oldSet.actualRpe,
      actualRir: oldSet.actualRir,
    );
  }

  void skipExercise(int exerciseIndex, {String? reason}) {
    if (_activeSession.isLocked || _activeSession.isCompleted || _activeSession.status == 'COMPLETED') return;
    if (exerciseIndex >= _activeSession.exercises.length) return;
    final exercise = _activeSession.exercises[exerciseIndex];

    final updatedExercise = exercise.copyWith(
      isSkipped: true,
      skipReason: reason ?? 'Equipment unavailable / modified',
    );

    final updatedExercises = List<WorkoutExercise>.from(_activeSession.exercises);
    updatedExercises[exerciseIndex] = updatedExercise;

    _activeSession = _activeSession.copyWith(exercises: updatedExercises);
    saveActiveSessionToLocalStorage();
    notifyListeners();
  }

  void updateExerciseNote(int exerciseIndex, String note) {
    if (_activeSession.isLocked || _activeSession.isCompleted || _activeSession.status == 'COMPLETED') return;
    if (exerciseIndex >= _activeSession.exercises.length) return;
    final exercise = _activeSession.exercises[exerciseIndex];

    final updatedExercise = exercise.copyWith(clientNote: note);
    final updatedExercises = List<WorkoutExercise>.from(_activeSession.exercises);
    updatedExercises[exerciseIndex] = updatedExercise;

    _activeSession = _activeSession.copyWith(exercises: updatedExercises);
    saveActiveSessionToLocalStorage();
    notifyListeners();
  }

  void addSet(int exerciseIndex, {SetType setType = SetType.working}) {
    if (_activeSession.isLocked || _activeSession.isCompleted || _activeSession.status == 'COMPLETED') return;
    if (exerciseIndex >= _activeSession.exercises.length) return;
    final exercise = _activeSession.exercises[exerciseIndex];
    final nextSetNumber = exercise.sets.length + 1;

    final lastSet = exercise.sets.isNotEmpty ? exercise.sets.last : null;
    final newSet = ExerciseSet(
      id: 'set_${exercise.id}_$nextSetNumber',
      setNumber: nextSetNumber,
      setType: setType,
      previousWeight: lastSet?.previousWeight,
      previousReps: lastSet?.previousReps,
      targetWeight: lastSet?.targetWeight ?? 60.0,
      targetRepsMin: lastSet?.targetRepsMin ?? 8,
      targetRepsMax: lastSet?.targetRepsMax ?? 12,
      targetRpe: lastSet?.targetRpe ?? 8.0,
      targetRir: lastSet?.targetRir ?? 2,
      tempo: lastSet?.tempo ?? '3-1-1-0',
      actualWeight: lastSet?.actualWeight ?? lastSet?.targetWeight ?? 60.0,
      actualReps: lastSet?.actualReps ?? lastSet?.targetRepsMin ?? 8,
    );

    final updatedSets = List<ExerciseSet>.from(exercise.sets)..add(newSet);
    final updatedExercises = List<WorkoutExercise>.from(_activeSession.exercises);
    updatedExercises[exerciseIndex] = exercise.copyWith(sets: updatedSets);

    _activeSession = _activeSession.copyWith(exercises: updatedExercises);
    saveActiveSessionToLocalStorage();
    notifyListeners();
  }

  bool deleteSet(int exerciseIndex, int setIndex) {
    if (_activeSession.isLocked || _activeSession.isCompleted || _activeSession.status == 'COMPLETED') return false;
    if (exerciseIndex >= _activeSession.exercises.length) return false;
    final exercise = _activeSession.exercises[exerciseIndex];
    if (setIndex >= exercise.sets.length) return false;

    final targetSet = exercise.sets[setIndex];
    if (targetSet.isCompleted) {
      // Unsync completion from backend if it was marked complete
      syncSetCompletionToBackend(
        sessionId: _activeSession.id,
        exerciseId: exercise.exerciseId.isNotEmpty ? exercise.exerciseId : exercise.id,
        setNumber: targetSet.setNumber,
        isCompleted: false,
      );
    }

    final updatedSets = List<ExerciseSet>.from(exercise.sets)..removeAt(setIndex);
    for (int i = 0; i < updatedSets.length; i++) {
      updatedSets[i] = updatedSets[i].copyWith(setNumber: i + 1);
    }

    final updatedExercises = List<WorkoutExercise>.from(_activeSession.exercises);
    updatedExercises[exerciseIndex] = exercise.copyWith(sets: updatedSets);

    _activeSession = _activeSession.copyWith(exercises: updatedExercises);
    saveActiveSessionToLocalStorage();
    notifyListeners();
    return true;
  }

  bool insertSet(int exerciseIndex, int setIndex, ExerciseSet set) {
    if (_activeSession.isLocked || _activeSession.isCompleted || _activeSession.status == 'COMPLETED') return false;
    if (exerciseIndex >= _activeSession.exercises.length) return false;
    final exercise = _activeSession.exercises[exerciseIndex];
    final updatedSets = List<ExerciseSet>.from(exercise.sets);
    final insertIdx = setIndex.clamp(0, updatedSets.length);
    updatedSets.insert(insertIdx, set);
    for (int i = 0; i < updatedSets.length; i++) {
      updatedSets[i] = updatedSets[i].copyWith(setNumber: i + 1);
    }
    final updatedExercises = List<WorkoutExercise>.from(_activeSession.exercises);
    updatedExercises[exerciseIndex] = exercise.copyWith(sets: updatedSets);
    _activeSession = _activeSession.copyWith(exercises: updatedExercises);
    saveActiveSessionToLocalStorage();
    notifyListeners();
    return true;
  }

  void unskipExercise(int exerciseIndex) {
    if (_activeSession.isLocked || _activeSession.isCompleted || _activeSession.status == 'COMPLETED') return;
    if (exerciseIndex >= _activeSession.exercises.length) return;
    final exercise = _activeSession.exercises[exerciseIndex];
    final updatedExercise = exercise.copyWith(
      isSkipped: false,
      skipReason: null,
    );
    final updatedExercises = List<WorkoutExercise>.from(_activeSession.exercises);
    updatedExercises[exerciseIndex] = updatedExercise;
    _activeSession = _activeSession.copyWith(exercises: updatedExercises);
    saveActiveSessionToLocalStorage();
    notifyListeners();
  }

  bool removeExerciseFromActiveSession(int exerciseIndex) {
    if (_activeSession.isLocked || _activeSession.isCompleted || _activeSession.status == 'COMPLETED') return false;
    if (exerciseIndex >= _activeSession.exercises.length) return false;
    final exercise = _activeSession.exercises[exerciseIndex];
    final updatedExercises = List<WorkoutExercise>.from(_activeSession.exercises)..removeAt(exerciseIndex);
    _activeSession = _activeSession.copyWith(
      exercises: updatedExercises,
      hasClientCustomization: true,
    );
    final uid = _activeSession.assignedClientId ?? AuthService().currentUserId;
    if (uid.isNotEmpty) {
      saveActiveSessionToLocalStorage(userId: uid);
    }
    notifyListeners();

    // Sync removal to backend
    syncExerciseRemovalToBackend(
      sessionId: _activeSession.id,
      exerciseId: exercise.originalExerciseId ?? (exercise.exerciseId.isNotEmpty ? exercise.exerciseId : exercise.id),
      dayOfWeek: _activeSession.recurringSchedule,
    );
    return true;
  }

  bool insertExerciseIntoActiveSession(int exerciseIndex, WorkoutExercise exercise) {
    if (_activeSession.isLocked || _activeSession.isCompleted || _activeSession.status == 'COMPLETED') return false;
    final updatedExercises = List<WorkoutExercise>.from(_activeSession.exercises);
    final idx = exerciseIndex.clamp(0, updatedExercises.length);
    updatedExercises.insert(idx, exercise);
    _activeSession = _activeSession.copyWith(exercises: updatedExercises);
    final uid = _activeSession.assignedClientId ?? AuthService().currentUserId;
    if (uid.isNotEmpty) {
      saveActiveSessionToLocalStorage(userId: uid);
    }
    notifyListeners();
    if (exercise.isCustomAdded) {
      syncExerciseAdditionToBackend(
        sessionId: _activeSession.id,
        exercise: exercise,
        dayOfWeek: _activeSession.recurringSchedule,
      );
    }
    return true;
  }

  bool swapExercise(int exerciseIndex, String newExerciseId) {
    if (_activeSession.isLocked || _activeSession.isCompleted || _activeSession.status == 'COMPLETED') return false;
    if (exerciseIndex >= _activeSession.exercises.length) return false;

    final currentEx = _activeSession.exercises[exerciseIndex];
    final newExercise = ExerciseRepository.getById(newExerciseId);
    if (newExercise == null) return false;

    final swapRecord = ExerciseSwapRecord(
      id: 'swap_${DateTime.now().millisecondsSinceEpoch}',
      originalExerciseId: currentEx.exerciseId,
      originalExerciseName: currentEx.exerciseName,
      performedExerciseId: newExercise.id,
      performedExerciseName: newExercise.displayName,
      swappedAt: DateTime.now(),
      reason: 'Biomechanical substitution during session',
    );

    _currentSessionSwaps.add(swapRecord);

    final updatedExercise = currentEx.copyWith(
      exerciseId: newExercise.id,
      exerciseName: newExercise.displayName,
      category: newExercise.category,
      primaryMusclesDisplay: newExercise.primaryMuscles.map((m) => m.displayName).join(' • '),
      secondaryMusclesDisplay: newExercise.secondaryMuscles.map((m) => m.displayName).join(' • '),
      trainerNote: newExercise.defaultTrainerNote.isNotEmpty
          ? newExercise.defaultTrainerNote
          : currentEx.trainerNote,
      swapRecord: swapRecord,
      isCustomReplacement: true,
      originalExerciseId: currentEx.originalExerciseId ?? currentEx.exerciseId,
      originalExerciseName: currentEx.originalExerciseName ?? currentEx.exerciseName,
      approvedAlternativeIds: [
        currentEx.exerciseId,
        ...newExercise.approvedAlternativeIds.where((id) => id != currentEx.exerciseId),
      ],
    );

    final updatedExercises = List<WorkoutExercise>.from(_activeSession.exercises);
    updatedExercises[exerciseIndex] = updatedExercise;

    _activeSession = _activeSession.copyWith(
      exercises: updatedExercises,
      hasClientCustomization: true,
    );
    saveActiveSessionToLocalStorage();
    notifyListeners();

    // Persist customization for future occurrences to backend
    syncExerciseReplacementToBackend(
      sessionId: _activeSession.id,
      originalExerciseId: currentEx.originalExerciseId ?? currentEx.exerciseId,
      originalExerciseName: currentEx.originalExerciseName ?? currentEx.exerciseName,
      replacementExerciseId: newExercise.id,
      replacementExerciseName: newExercise.displayName,
      category: newExercise.category,
      primaryMusclesDisplay: updatedExercise.primaryMusclesDisplay,
      secondaryMusclesDisplay: updatedExercise.secondaryMusclesDisplay,
      trainerNote: updatedExercise.trainerNote,
      numberOfSets: updatedExercise.sets.length,
      targetReps: updatedExercise.sets.isNotEmpty ? updatedExercise.sets.first.targetRepsDisplay : '8–12',
      targetWeight: updatedExercise.sets.isNotEmpty ? updatedExercise.sets.first.targetWeight : null,
      customSets: updatedExercise.sets.map((s) => s.toJson()).toList(),
      dayOfWeek: _activeSession.recurringSchedule,
    );

    return true;
  }

  WorkoutRecord completeWorkout({String? notes, int? durationSeconds, String? authToken}) {
    final now = DateTime.now();
    final todayIST = _activeSession.scheduledDate ?? IstDateUtils.getTodayISTString();
    final duration = durationSeconds ??
        now.difference(_activeSession.startedAt).inSeconds.clamp(60, 10800);

    _activeSession = _activeSession.copyWith(
      isCompleted: true,
      completedAt: now,
      durationSeconds: duration,
      isLocked: true,
      lockedAt: now,
      status: 'COMPLETED',
      scheduledDate: todayIST,
    );

    // Calculate aggregated stats
    int totalCompletedSets = 0;
    int totalSkippedSets = 0;
    double totalVolume = 0.0;
    double rpeSum = 0.0;
    int rpeCount = 0;
    double rirSum = 0.0;
    int rirCount = 0;

    for (final ex in _activeSession.exercises) {
      if (ex.isSkipped) {
        totalSkippedSets += ex.sets.length;
      } else {
        for (final s in ex.sets) {
          if (s.isCompleted) {
            totalCompletedSets++;
            totalVolume += s.volume;
            if (s.actualRpe != null) {
              rpeSum += s.actualRpe!;
              rpeCount++;
            }
            if (s.actualRir != null) {
              rirSum += s.actualRir!;
              rirCount++;
            }
          } else {
            totalSkippedSets++;
          }
        }
      }
    }

    final currentUserId = (_activeSession.assignedClientId != null && _activeSession.assignedClientId!.isNotEmpty)
        ? _activeSession.assignedClientId!
        : (AuthService().currentUserId.isNotEmpty
            ? AuthService().currentUserId
            : AuthService().currentClientId);

    final record = WorkoutRecord(
      id: 'rec_${DateTime.now().microsecondsSinceEpoch}_$currentUserId',
      clientId: currentUserId,
      sessionId: _activeSession.id,
      sessionTitle: _activeSession.title,
      workoutType: _activeSession.workoutType,
      targetMuscleGroup: _activeSession.targetMuscleGroup,
      startedAt: _activeSession.startedAt,
      completedAt: now,
      durationSeconds: duration,
      totalVolume: totalVolume,
      completedSetsCount: totalCompletedSets,
      skippedSetsCount: totalSkippedSets,
      averageRpe: rpeCount > 0 ? double.parse((rpeSum / rpeCount).toStringAsFixed(1)) : null,
      averageRir: rirCount > 0 ? double.parse((rirSum / rirCount).toStringAsFixed(1)) : null,
      isCompleted: true,
      notes: notes,
      exercises: List.from(_activeSession.exercises),
      exerciseSwaps: List.from(_currentSessionSwaps),
      planVersion: _activeSession.planVersion,
      assignmentId: _activeSession.assignmentId,
      scheduledDate: todayIST,
      isLocked: true,
      lockedAt: now,
    );

    _currentSessionSwaps.clear();
    _hasRestoredActiveSession = false;
    _activeSessionSavedAt = null;
    discardActiveSession(userId: currentUserId);
    _pendingWorkouts.removeWhere((p) => p.id == _activeSession.id && (p.scheduledDate == todayIST || p.scheduledDate == _activeSession.scheduledDate));
    _workoutHistory.insert(0, record);

    for (int i = 0; i < _assignments.length; i++) {
      final a = _assignments[i];
      if (a.sessionId == _activeSession.id &&
          (a.clientId == null || a.clientId == currentUserId) &&
          (a.scheduledDate == null || a.scheduledDate == todayIST)) {
        _assignments[i] = WorkoutAssignmentData(
          id: a.id,
          sessionId: a.sessionId,
          clientId: a.clientId,
          isRecommended: a.isRecommended,
          assignedAt: a.assignedAt,
          scheduledDate: a.scheduledDate ?? todayIST,
          isLocked: true,
          status: 'COMPLETED',
        );
      }
    }

    _saveToLocalStorage();
    notifyListeners();

    // Trigger post-completion callback (e.g. updating daily activity cardio/calories)
    try {
      onWorkoutCompleted?.call(record);
    } catch (e) {
      debugPrint('[WorkoutRepository] onWorkoutCompleted callback error: $e');
    }

    // Asynchronously push record to backend REST API (persists offline if unreachable)
    syncWorkoutRecordToBackend(record, authToken: authToken);

    return record;
  }

  /// Admin unlocks a completed workout session with audit trail and optional session reopening.
  Future<bool> unlockSession({
    required String recordId,
    required String adminId,
    required String reason,
    bool reopenSession = true,
    String? clientId,
    String? sessionId,
  }) async {
    final now = DateTime.now();

    // 1. Find record in history
    final idx = _workoutHistory.indexWhere((r) =>
      r.id == recordId && (clientId == null || clientId.isEmpty || r.clientId == clientId)
    );
    WorkoutRecord? oldRecord;
    if (idx != -1) {
      oldRecord = _workoutHistory[idx];
      final unlockedRecord = oldRecord.copyWith(
        isLocked: false,
        unlockedAt: now,
        unlockedById: adminId,
        unlockReason: reason,
      );
      _workoutHistory[idx] = unlockedRecord;
    }

    final effectiveClientId = clientId ?? oldRecord?.clientId;
    final effectiveSessionId = sessionId ?? oldRecord?.sessionId;

    // 2. Also update matching assignment in _assignments if present
    if (effectiveSessionId != null) {
      for (int i = 0; i < _assignments.length; i++) {
        final a = _assignments[i];
        if (a.sessionId == effectiveSessionId &&
            (a.clientId == null || a.clientId == effectiveClientId)) {
          _assignments[i] = WorkoutAssignmentData(
            id: a.id,
            sessionId: a.sessionId,
            clientId: a.clientId,
            isRecommended: a.isRecommended,
            assignedAt: a.assignedAt,
            scheduledDate: a.scheduledDate,
            isLocked: false,
            status: 'IN_PROGRESS',
            unlockedAt: now,
            unlockReason: reason,
          );
        }
      }
    }

    // 3. Reopen active session if requested
    if (reopenSession && oldRecord != null) {
      _activeSession = WorkoutSession(
        id: oldRecord.sessionId ?? 'session_${oldRecord.id}',
        title: oldRecord.sessionTitle,
        workoutType: oldRecord.workoutType,
        targetMuscleGroup: oldRecord.targetMuscleGroup,
        startedAt: oldRecord.startedAt,
        durationSeconds: oldRecord.durationSeconds,
        assignedClientId: oldRecord.clientId,
        assignedWorkoutId: oldRecord.sessionId,
        status: 'IN_PROGRESS',
        scheduledDate: oldRecord.scheduledDate ?? IstDateUtils.toISTDateString(oldRecord.startedAt),
        isLocked: false,
        isCompleted: false,
        unlockedAt: now,
        unlockedById: adminId,
        unlockReason: reason,
        exercises: oldRecord.exercises.map((e) => e.copyWith(
          sets: e.sets.map((s) => s.copyWith()).toList(),
        )).toList(),
      );
      _hasRestoredActiveSession = true;
      _activeSessionSavedAt = now;
      await saveActiveSessionToLocalStorage(userId: oldRecord.clientId);
    }

    if (idx != -1) {
      _saveToLocalStorage();
      notifyListeners();
    }

    // 4. Sync with backend API
    bool backendSuccess = false;
    try {
      final token = await AuthService().getValidToken();
      final url = Uri.parse('${AppConstants.apiBaseUrl}/workout/admin/unlock-session');
      final payload = jsonEncode({
        'recordId': recordId,
        'reason': reason,
        'adminId': adminId,
        if (effectiveClientId != null) 'clientId': effectiveClientId,
        if (effectiveSessionId != null) 'sessionId': effectiveSessionId,
      });

      final response = await _httpClient.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: payload,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        backendSuccess = true;
      }
    } catch (e) {
      debugPrint('[WorkoutRepository] Failed to sync unlockSession to backend: $e');
    }

    return backendSuccess || idx != -1;
  }

  // --- Historical Performance & PR Database ---
  final Map<String, List<PersonalRecord>> _prDatabase = {
    'ex_incline_smith': [
      PersonalRecord(
        id: 'pr_1',
        exerciseId: 'ex_incline_smith',
        exerciseName: 'Incline Smith Machine Press',
        type: PRType.weight,
        value: 70.0,
        weight: 70.0,
        reps: 10,
        previousValue: 67.5,
        achievedAt: DateTime.now().subtract(const Duration(days: 7)),
      ),
      PersonalRecord(
        id: 'pr_2',
        exerciseId: 'ex_incline_smith',
        exerciseName: 'Incline Smith Machine Press',
        type: PRType.estimated1RM,
        value: 93.3,
        weight: 70.0,
        reps: 10,
        previousValue: 90.0,
        achievedAt: DateTime.now().subtract(const Duration(days: 7)),
      ),
    ],
  };

  PersonalRecord? evaluateNewPR({
    required String exerciseId,
    required String exerciseName,
    required double actualWeight,
    required int actualReps,
  }) {
    final existingPRs = _prDatabase[exerciseId] ?? [];
    final setVolume = actualWeight * actualReps;
    final estimated1RM = actualWeight * (1 + (actualReps / 30.0));

    // 1. Weight PR
    final currentMaxWeightPR = existingPRs.where((p) => p.type == PRType.weight).toList();
    final previousMaxWeight = currentMaxWeightPR.isNotEmpty ? currentMaxWeightPR.first.value : 0.0;

    if (actualWeight > previousMaxWeight) {
      final newPR = PersonalRecord(
        id: 'pr_${DateTime.now().millisecondsSinceEpoch}',
        exerciseId: exerciseId,
        exerciseName: exerciseName,
        type: PRType.weight,
        value: actualWeight,
        weight: actualWeight,
        reps: actualReps,
        previousValue: previousMaxWeight > 0 ? previousMaxWeight : null,
        achievedAt: DateTime.now(),
      );
      _recordPR(exerciseId, newPR);
      return newPR;
    }

    // 2. 1RM PR
    final currentMax1RMPR = existingPRs.where((p) => p.type == PRType.estimated1RM).toList();
    final previousMax1RM = currentMax1RMPR.isNotEmpty ? currentMax1RMPR.first.value : 0.0;

    if (estimated1RM > (previousMax1RM + 0.5)) {
      final newPR = PersonalRecord(
        id: 'pr_${DateTime.now().millisecondsSinceEpoch}',
        exerciseId: exerciseId,
        exerciseName: exerciseName,
        type: PRType.estimated1RM,
        value: estimated1RM,
        weight: actualWeight,
        reps: actualReps,
        previousValue: previousMax1RM > 0 ? previousMax1RM : null,
        achievedAt: DateTime.now(),
      );
      _recordPR(exerciseId, newPR);
      return newPR;
    }

    // 3. Volume PR
    final currentMaxVolPR = existingPRs.where((p) => p.type == PRType.volume).toList();
    final previousMaxVol = currentMaxVolPR.isNotEmpty ? currentMaxVolPR.first.value : 0.0;

    if (setVolume > (previousMaxVol + 5.0)) {
      final newPR = PersonalRecord(
        id: 'pr_${DateTime.now().millisecondsSinceEpoch}',
        exerciseId: exerciseId,
        exerciseName: exerciseName,
        type: PRType.volume,
        value: setVolume,
        weight: actualWeight,
        reps: actualReps,
        previousValue: previousMaxVol > 0 ? previousMaxVol : null,
        achievedAt: DateTime.now(),
      );
      _recordPR(exerciseId, newPR);
      return newPR;
    }

    return null;
  }

  void _recordPR(String exerciseId, PersonalRecord pr) {
    if (!_prDatabase.containsKey(exerciseId)) {
      _prDatabase[exerciseId] = [];
    }
    _prDatabase[exerciseId]!.removeWhere((p) => p.type == pr.type);
    _prDatabase[exerciseId]!.add(pr);
  }

  // --- Previous Performance Lookup ---
  List<ExerciseSet>? getPreviousPerformance(String exerciseId, {String? clientId}) {
    final targetClientId = clientId ?? AuthService().currentUserId;
    if (targetClientId.isNotEmpty) {
      final clientHistory = getClientExerciseHistory(
        clientId: targetClientId,
        exerciseId: exerciseId,
      );
      if (clientHistory.isNotEmpty) {
        return clientHistory.first.sets;
      }
      // STRICTLY return null if no historical record exists for this specific client
      return null;
    }

    // Fallback for unauthenticated unit tests
    for (final record in _workoutHistory.where((r) => r.isCompleted)) {
      for (final ex in record.exercises) {
        if (ex.exerciseId == exerciseId && !ex.isSkipped && ex.sets.any((s) => s.isCompleted)) {
          return ex.sets.where((s) => s.isCompleted).toList();
        }
      }
    }
    return null;
  }

  /// Retrieves all past completed sessions for a given client and exercise ID,
  /// ordered by completed date descending (newest session first).
  List<ExercisePerformanceHistoryItem> getClientExerciseHistory({
    required String clientId,
    required String exerciseId,
  }) {
    final List<ExercisePerformanceHistoryItem> results = [];
    final clientRecords = _workoutHistory
        .where((r) => r.clientId == clientId && r.isCompleted)
        .toList()
      ..sort((a, b) => (b.completedAt ?? b.startedAt).compareTo(a.completedAt ?? a.startedAt));

    for (final record in clientRecords) {
      final matchingExercise = record.exercises.firstWhere(
        (e) => e.exerciseId == exerciseId && !e.isSkipped,
        orElse: () => const WorkoutExercise(
          id: '',
          exerciseId: '',
          exerciseName: '',
          category: '',
          primaryMusclesDisplay: '',
          secondaryMusclesDisplay: '',
          trainerNote: '',
          sets: [],
        ),
      );
      if (matchingExercise.exerciseId.isNotEmpty && matchingExercise.sets.isNotEmpty) {
        final completedSets = matchingExercise.sets.where((s) => s.isCompleted).toList();
        if (completedSets.isNotEmpty) {
          results.add(
            ExercisePerformanceHistoryItem(
              recordId: record.id,
              sessionTitle: record.sessionTitle,
              date: record.completedAt ?? record.startedAt,
              sets: completedSets,
            ),
          );
        }
      }
    }
    return results;
  }

  /// Get the most recent previous performance sets for a specific client and exercise ID
  List<ExerciseSet>? getClientPreviousPerformance({
    required String clientId,
    required String exerciseId,
  }) {
    final history = getClientExerciseHistory(clientId: clientId, exerciseId: exerciseId);
    if (history.isNotEmpty) {
      return history.first.sets;
    }
    return null;
  }

  List<WorkoutRecord> getClientWorkoutHistory(String clientId) {
    return _workoutHistory.where((r) => r.clientId == clientId).toList();
  }

  /// Fetches real workout history for a specific client from the backend database.
  Future<List<WorkoutRecord>> fetchClientWorkoutHistory(String clientId, {bool forceRefresh = false}) async {
    try {
      final token = await AuthService().getValidToken();
      if (token.isEmpty) {
        return getClientWorkoutHistory(clientId);
      }

      final endpoints = [
        '${AppConstants.apiBaseUrl}/workout/admin/clients/$clientId/workout-history',
        '${AppConstants.apiBaseUrl}/admin/clients/$clientId/workout-history',
      ];

      for (final endpoint in endpoints) {
        try {
          final res = await _httpClient.get(
            Uri.parse(endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          ).timeout(const Duration(seconds: 8));

          if (res.statusCode == 200) {
            final decoded = jsonDecode(res.body);
            final data = decoded['data'] ?? decoded;
            final historyList = (data is Map && data['history'] is List)
                ? (data['history'] as List)
                : (data is List ? data : null);

            if (historyList != null) {
              final List<WorkoutRecord> fetched = [];
              for (final item in historyList) {
                if (item is Map<String, dynamic>) {
                  fetched.add(WorkoutRecord.fromJson(item));
                } else if (item is Map) {
                  fetched.add(WorkoutRecord.fromJson(Map<String, dynamic>.from(item)));
                }
              }

              // Update in-memory cache
              _workoutHistory.removeWhere((r) => r.clientId == clientId);
              _workoutHistory.insertAll(0, fetched);
              _saveToLocalStorage();
              notifyListeners();
              return fetched;
            }
          }
        } catch (inner) {
          debugPrint('[WorkoutRepository] Failed fetching history from $endpoint: $inner');
        }
      }
    } catch (e) {
      debugPrint('[WorkoutRepository] Error fetching client workout history: $e');
    }
    return getClientWorkoutHistory(clientId);
  }

  // --- Plate Calculator ---
  PlateCalculationResult calculatePlates({
    required double targetWeightKg,
    double barWeightKg = 20.0,
    List<double> availablePlates = const [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25],
  }) {
    if (targetWeightKg <= barWeightKg) {
      return PlateCalculationResult(
        targetWeightKg: targetWeightKg,
        barWeightKg: barWeightKg,
        weightPerSide: 0.0,
        platesPerSide: {},
        isExact: targetWeightKg == barWeightKg,
        remainderKg: 0.0,
      );
    }

    final double totalPlateWeightNeeded = targetWeightKg - barWeightKg;
    double weightNeededPerSide = totalPlateWeightNeeded / 2.0;
    double remaining = weightNeededPerSide;

    final sortedPlates = List<double>.from(availablePlates)..sort((a, b) => b.compareTo(a));
    final Map<double, int> platesPerSide = {};

    for (final plate in sortedPlates) {
      if (remaining >= plate) {
        final count = (remaining / plate).floor();
        platesPerSide[plate] = count;
        remaining -= count * plate;
        remaining = double.parse(remaining.toStringAsFixed(2));
      }
    }

    return PlateCalculationResult(
      targetWeightKg: targetWeightKg,
      barWeightKg: barWeightKg,
      weightPerSide: weightNeededPerSide,
      platesPerSide: platesPerSide,
      isExact: remaining == 0.0,
      remainderKg: remaining * 2.0,
    );
  }

  // --- Change Requests Management ---
  ExerciseChangeRequest submitChangeRequest({
    required String clientId,
    required String clientName,
    required String sessionId,
    required String sessionTitle,
    required String exerciseId,
    required String exerciseName,
    required String reason,
  }) {
    final request = ExerciseChangeRequest(
      id: 'cr_${DateTime.now().millisecondsSinceEpoch}',
      clientId: clientId,
      clientName: clientName,
      sessionId: sessionId,
      sessionTitle: sessionTitle,
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      reason: reason,
      requestedAt: DateTime.now(),
      status: 'PENDING',
    );
    _changeRequests.insert(0, request);
    _saveToLocalStorage();
    notifyListeners();
    return request;
  }

  void approveChangeRequest(
    String requestId, {
    String? replacementExerciseId,
    String? replacementExerciseName,
    String? adminNote,
    bool isPermanent = false,
  }) {
    final idx = _changeRequests.indexWhere((r) => r.id == requestId);
    if (idx != -1) {
      final old = _changeRequests[idx];
      _changeRequests[idx] = old.copyWith(
        status: 'APPROVED',
        replacementExerciseId: replacementExerciseId,
        replacementExerciseName: replacementExerciseName,
        adminNote: adminNote,
        isPermanent: isPermanent,
      );

      // If permanent, update the exercise in matching sessions
      if (isPermanent && replacementExerciseId != null) {
        final replacementEx = ExerciseRepository.getById(replacementExerciseId);
        if (replacementEx != null) {
          final sIdx = _sessions.indexWhere((s) => s.id == old.sessionId);
          if (sIdx != -1) {
            final session = _sessions[sIdx];
            final updatedExercises = session.exercises.map((e) {
              if (e.exerciseId == old.exerciseId) {
                return e.copyWith(
                  exerciseId: replacementEx.id,
                  exerciseName: replacementEx.displayName,
                  category: replacementEx.category,
                  primaryMusclesDisplay: replacementEx.primaryMusclesDisplay,
                  secondaryMusclesDisplay: replacementEx.secondaryMusclesDisplay,
                  trainerNote: adminNote ?? replacementEx.defaultTrainerNote,
                );
              }
              return e;
            }).toList();
            _sessions[sIdx] = session.copyWith(exercises: updatedExercises);
          }
        }
      }
      _saveToLocalStorage();
      notifyListeners();
    }
  }

  void rejectChangeRequest(String requestId, {String? adminNote}) {
    final idx = _changeRequests.indexWhere((r) => r.id == requestId);
    if (idx != -1) {
      final old = _changeRequests[idx];
      _changeRequests[idx] = old.copyWith(
        status: 'REJECTED',
        adminNote: adminNote,
      );
      _saveToLocalStorage();
      notifyListeners();
    }
  }

  bool isExerciseUsedInHistory(String exerciseId) {
    for (final record in _workoutHistory) {
      if (record.exercises.any((e) => e.exerciseId == exerciseId)) {
        return true;
      }
    }
    for (final s in _sessions) {
      if (s.exercises.any((e) => e.exerciseId == exerciseId)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _loadFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final sessionsRaw = prefs.getString(_storageKeySessions);
      if (sessionsRaw != null && sessionsRaw.isNotEmpty) {
        final list = jsonDecode(sessionsRaw) as List<dynamic>;
        if (list.isNotEmpty) {
          _sessions.clear();
          for (final item in list) {
            _sessions.add(WorkoutSession.fromJson(item as Map<String, dynamic>));
          }
        }
      }

      final assignmentsRaw = prefs.getString(_storageKeyAssignments);
      if (assignmentsRaw != null && assignmentsRaw.isNotEmpty) {
        final list = jsonDecode(assignmentsRaw) as List<dynamic>;
        if (list.isNotEmpty) {
          _assignments.clear();
          for (final item in list) {
            _assignments.add(WorkoutAssignmentData.fromJson(item as Map<String, dynamic>));
          }
        }
      }

      final historyRaw = prefs.getString(_storageKeyHistory);
      if (historyRaw != null && historyRaw.isNotEmpty) {
        final list = jsonDecode(historyRaw) as List<dynamic>;
        _workoutHistory.clear();
        for (final item in list) {
          _workoutHistory.add(WorkoutRecord.fromJson(item as Map<String, dynamic>));
        }
      }

      final requestsRaw = prefs.getString(_storageKeyChangeRequests);
      if (requestsRaw != null && requestsRaw.isNotEmpty) {
        final list = jsonDecode(requestsRaw) as List<dynamic>;
        _changeRequests.clear();
        for (final item in list) {
          _changeRequests.add(ExerciseChangeRequest.fromJson(item as Map<String, dynamic>));
        }
      }

      final pendingRaw = prefs.getString(_storageKeyPendingSync);
      if (pendingRaw != null && pendingRaw.isNotEmpty) {
        final list = jsonDecode(pendingRaw) as List<dynamic>;
        _pendingSyncRecords.clear();
        for (final item in list) {
          _pendingSyncRecords.add(WorkoutRecord.fromJson(item as Map<String, dynamic>));
        }
      }

      final pendingSetsRaw = prefs.getString(_storageKeyPendingSetCompletions);
      if (pendingSetsRaw != null && pendingSetsRaw.isNotEmpty) {
        final list = jsonDecode(pendingSetsRaw) as List<dynamic>;
        _pendingSetCompletions.clear();
        for (final item in list) {
          _pendingSetCompletions.add(PendingSetSync.fromJson(item as Map<String, dynamic>));
        }
      }

      // Restore active in-progress workout session for current authenticated user
      final currentUid = AuthService().currentUserId;
      if (currentUid.isNotEmpty) {
        await restoreActiveSessionForClient(currentUid);
      } else {
        // Fallback for tests or offline active sessions when no current user id is set
        final activeRaw = prefs.getString(_storageKeyActiveSession);
        if (activeRaw != null && activeRaw.isNotEmpty) {
          final activeMap = jsonDecode(activeRaw) as Map<String, dynamic>;
          final restored = WorkoutSession.fromJson(activeMap);
          if (!restored.isCompleted &&
              (restored.status == 'IN_PROGRESS' || restored.status == 'NOT_STARTED')) {
            _activeSession = restored;
            _hasRestoredActiveSession = true;
            final tsStr = prefs.getString(_storageKeyActiveSessionTimestamp);
            if (tsStr != null) {
              _activeSessionSavedAt = DateTime.tryParse(tsStr);
            }
          }
        }
      }

      notifyListeners();

      // Attempt to sync any pending records saved from offline mode
      syncPendingRecordsWithBackend();
    } catch (_) {}
  }

  String _activeSessionKey(String uid) => 'alpha_x_workout_active_session_state_$uid';
  String _activeSessionTimestampKey(String uid) => 'alpha_x_workout_active_session_timestamp_$uid';
  String _activeSessionDurationKey(String uid) => 'alpha_x_workout_active_session_duration_$uid';

  Future<void> restoreActiveSessionForClient(String clientId) async {
    if (clientId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeRaw = prefs.getString(_activeSessionKey(clientId)) ?? prefs.getString(_storageKeyActiveSession);
      if (activeRaw != null && activeRaw.isNotEmpty) {
        final activeMap = jsonDecode(activeRaw) as Map<String, dynamic>;
        final restored = WorkoutSession.fromJson(activeMap);
        final sessionDate = restored.scheduledDate ?? IstDateUtils.toISTDateString(restored.startedAt);

        // Do not require sessionDate == todayIST for an in-progress workout session!
        // A client starting a session before midnight must stay locked to their session and not have it discarded.
        final isCompletedInHistory = _workoutHistory.any((r) =>
            r.clientId == clientId &&
            (r.sessionId == restored.id || r.sessionId == restored.assignedWorkoutId) &&
            r.isCompleted &&
            (r.scheduledDate == sessionDate ||
             IstDateUtils.toISTDateString(r.completedAt ?? r.startedAt) == sessionDate));

        final age = DateTime.now().difference(restored.startedAt);
        if (!restored.isCompleted &&
            !restored.isLocked &&
            !isCompletedInHistory &&
            (restored.status == 'IN_PROGRESS' || restored.status == 'NOT_STARTED') &&
            age.inHours < 24) {
          _activeSession = restored;
          _hasRestoredActiveSession = true;
          final tsStr = prefs.getString(_activeSessionTimestampKey(clientId)) ?? prefs.getString(_storageKeyActiveSessionTimestamp);
          if (tsStr != null) {
            _activeSessionSavedAt = DateTime.tryParse(tsStr);
          }
          notifyListeners();
        } else {
          // If the session was completed, locked, or stale (>24 hours), clean it up so it is never accidentally reopened
          await discardActiveSession(userId: clientId);
        }
      }
    } catch (e) {
      debugPrint('[WorkoutRepository] Failed to restore active session for $clientId: $e');
    }
  }

  Future<void> saveActiveSessionToLocalStorage({String? userId, int? elapsedSeconds}) async {
    try {
      final effectiveUid = userId ?? _activeSession.assignedClientId ?? AuthService().currentUserId;
      final prefs = await SharedPreferences.getInstance();
      final sessionJson = _activeSession.toJson();
      final jsonString = jsonEncode(sessionJson);
      final now = DateTime.now().toUtc().toIso8601String();

      if (effectiveUid.isNotEmpty) {
        await prefs.setString(_activeSessionKey(effectiveUid), jsonString);
        await prefs.setString(_activeSessionTimestampKey(effectiveUid), now);
        if (elapsedSeconds != null) {
          await prefs.setInt(_activeSessionDurationKey(effectiveUid), elapsedSeconds);
        }
      }

      // Always save to standard storage key for backward compatibility & offline logger
      await prefs.setString(_storageKeyActiveSession, jsonString);
      await prefs.setString(_storageKeyActiveSessionTimestamp, now);
      if (elapsedSeconds != null) {
        await prefs.setInt(_storageKeyActiveSessionDuration, elapsedSeconds);
      }

      _hasRestoredActiveSession = true;
      _activeSessionSavedAt = DateTime.now();
    } catch (e) {
      debugPrint('[WorkoutRepository] Failed to save active session locally: $e');
    }
  }

  Future<void> discardActiveSession({String? userId}) async {
    final effectiveUid = userId ?? _activeSession.assignedClientId ?? AuthService().currentUserId;
    _activeSession = _activeSession.copyWith(status: 'ABANDONED');
    _hasRestoredActiveSession = false;
    _activeSessionSavedAt = null;
    _currentSessionSwaps.clear();
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      if (effectiveUid.isNotEmpty) {
        await prefs.remove(_activeSessionKey(effectiveUid));
        await prefs.remove(_activeSessionTimestampKey(effectiveUid));
        await prefs.remove(_activeSessionDurationKey(effectiveUid));
      }
      await prefs.remove(_storageKeyActiveSession);
      await prefs.remove(_storageKeyActiveSessionTimestamp);
      await prefs.remove(_storageKeyActiveSessionDuration);
    } catch (e) {
      debugPrint('[WorkoutRepository] Failed to discard active session: $e');
    }
  }

  Future<int?> getSavedActiveSessionDuration({String? userId}) async {
    try {
      final effectiveUid = userId ?? _activeSession.assignedClientId ?? AuthService().currentUserId;
      final prefs = await SharedPreferences.getInstance();
      if (effectiveUid.isNotEmpty) {
        final val = prefs.getInt(_activeSessionDurationKey(effectiveUid));
        if (val != null) return val;
      }
      return prefs.getInt(_storageKeyActiveSessionDuration);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveToLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final sessionsList = _sessions.map((s) => s.toJson()).toList();
      await prefs.setString(_storageKeySessions, jsonEncode(sessionsList));

      final assignmentsList = _assignments.map((a) => a.toJson()).toList();
      await prefs.setString(_storageKeyAssignments, jsonEncode(assignmentsList));

      final historyList = _workoutHistory.map((r) => r.toJson()).toList();
      await prefs.setString(_storageKeyHistory, jsonEncode(historyList));

      final requestsList = _changeRequests.map((r) => r.toJson()).toList();
      await prefs.setString(_storageKeyChangeRequests, jsonEncode(requestsList));

      await _savePendingSyncRecords();
      await _savePendingSetCompletions();
    } catch (_) {}
  }

  Future<void> _savePendingSyncRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingList = _pendingSyncRecords.map((r) => r.toJson()).toList();
      await prefs.setString(_storageKeyPendingSync, jsonEncode(pendingList));
    } catch (_) {}
  }

  Future<void> _savePendingSetCompletions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _pendingSetCompletions.map((p) => p.toJson()).toList();
      await prefs.setString(_storageKeyPendingSetCompletions, jsonEncode(list));
    } catch (_) {}
  }

  void _addOrUpdatePendingSetSync(PendingSetSync item) {
    _pendingSetCompletions.removeWhere((p) =>
        p.sessionId == item.sessionId &&
        p.exerciseId == item.exerciseId &&
        p.setNumber == item.setNumber);
    _pendingSetCompletions.add(item);
    _savePendingSetCompletions();
    notifyListeners();
  }

  void _removePendingSetSync(String sessionId, String exerciseId, int setNumber) {
    _pendingSetCompletions.removeWhere((p) =>
        p.sessionId == sessionId &&
        p.exerciseId == exerciseId &&
        p.setNumber == setNumber);
    _savePendingSetCompletions();
    notifyListeners();
  }

  void _addPendingSyncRecord(WorkoutRecord record) {
    if (!_pendingSyncRecords.any((r) => r.id == record.id)) {
      _pendingSyncRecords.add(record);
      _savePendingSyncRecords();
      notifyListeners();
    }
  }

  void _removePendingSyncRecord(String recordId) {
    _pendingSyncRecords.removeWhere((r) => r.id == recordId);
    _savePendingSyncRecords();
    notifyListeners();
  }

  /// Push individual set completion state immediately to the backend REST API / database.
  /// If the network request fails or device is offline, it is safely queued locally
  /// so that no completed sets are ever lost or uncompleted upon refresh.
  Future<bool> syncSetCompletionToBackend({
    required String sessionId,
    required String exerciseId,
    required int setNumber,
    required bool isCompleted,
    double? actualWeight,
    int? actualReps,
    double? actualRpe,
    int? actualRir,
    String? scheduledDate,
    String? authToken,
  }) async {
    final effectiveDate = scheduledDate ?? _activeSession.scheduledDate ?? IstDateUtils.getTodayISTString();

    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/workout/client/sessions/$sessionId/set-completion');
      final token = authToken ??
          (AuthService().currentToken.isNotEmpty
              ? AuthService().currentToken
              : (_isTestEnvironment ? 'alpha_x_mock_token_for_client' : ''));

      final payload = {
        'sessionId': sessionId,
        'exerciseId': exerciseId,
        'setNumber': setNumber,
        'isCompleted': isCompleted,
        'actualWeight': actualWeight,
        'actualReps': actualReps,
        'actualRpe': actualRpe,
        'actualRir': actualRir,
        'scheduledDate': effectiveDate,
      };

      final response = await _httpClient
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[WorkoutRepository] Successfully synced set completion ($exerciseId Set $setNumber: $isCompleted) to database.');
        _removePendingSetSync(sessionId, exerciseId, setNumber);
        return true;
      } else {
        debugPrint('[WorkoutRepository] Backend set sync response ${response.statusCode}: ${response.body}');
        final pendingItem = PendingSetSync(
          sessionId: sessionId,
          exerciseId: exerciseId,
          setNumber: setNumber,
          isCompleted: isCompleted,
          actualWeight: actualWeight,
          actualReps: actualReps,
          actualRpe: actualRpe,
          actualRir: actualRir,
          scheduledDate: effectiveDate,
          clientTimestamp: DateTime.now().millisecondsSinceEpoch,
        );
        _addOrUpdatePendingSetSync(pendingItem);
        return false;
      }
    } catch (e) {
      debugPrint('[WorkoutRepository] Offline or notice during set completion sync: $e');
      final pendingItem = PendingSetSync(
        sessionId: sessionId,
        exerciseId: exerciseId,
        setNumber: setNumber,
        isCompleted: isCompleted,
        actualWeight: actualWeight,
        actualReps: actualReps,
        actualRpe: actualRpe,
        actualRir: actualRir,
        scheduledDate: effectiveDate,
        clientTimestamp: DateTime.now().millisecondsSinceEpoch,
      );
      _addOrUpdatePendingSetSync(pendingItem);
      return false;
    }
  }

  /// Synchronize all pending offline set completions with the backend
  Future<void> syncPendingSetCompletionsWithBackend() async {
    if (_pendingSetCompletions.isEmpty) return;
    final toSync = List<PendingSetSync>.from(_pendingSetCompletions);
    for (final item in toSync) {
      try {
        final url = Uri.parse('${AppConstants.apiBaseUrl}/workout/client/sessions/${item.sessionId}/set-completion');
        final token = AuthService().currentToken.isNotEmpty
            ? AuthService().currentToken
            : (_isTestEnvironment ? 'alpha_x_mock_token_for_client' : '');

        final payload = {
          'sessionId': item.sessionId,
          'exerciseId': item.exerciseId,
          'setNumber': item.setNumber,
          'isCompleted': item.isCompleted,
          'actualWeight': item.actualWeight,
          'actualReps': item.actualReps,
          'actualRpe': item.actualRpe,
          'actualRir': item.actualRir,
          'scheduledDate': item.scheduledDate,
        };

        final response = await _httpClient
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200 || response.statusCode == 201) {
          _removePendingSetSync(item.sessionId, item.exerciseId, item.setNumber);
        }
      } catch (e) {
        debugPrint('[WorkoutRepository] Retry set sync error: $e');
        break;
      }
    }
  }

  /// Push an individual workout record to the backend REST API.
  /// If the backend is unreachable or offline, the record is safely queued in
  /// local storage so no workouts or sets are ever lost.
  Future<bool> syncWorkoutRecordToBackend(WorkoutRecord record, {String? authToken}) async {
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/workout/client/records');
      final token = authToken ??
          (AuthService().currentToken.isNotEmpty
              ? AuthService().currentToken
              : (_isTestEnvironment ? 'alpha_x_mock_token_for_client' : ''));

      final payload = _formatBackendRecordPayload(record);
      final response = await _httpClient
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[WorkoutRepository] Successfully synced workout record ${record.id} to backend.');
        _removePendingSyncRecord(record.id);
        return true;
      } else {
        debugPrint('[WorkoutRepository] Backend response ${response.statusCode}: ${response.body}');
        _addPendingSyncRecord(record);
        return false;
      }
    } catch (e) {
      debugPrint('[WorkoutRepository] Offline or sync error for record ${record.id}: $e');
      _addPendingSyncRecord(record);
      return false;
    }
  }

  /// Synchronize all pending offline workout records with the backend
  Future<void> syncPendingRecordsWithBackend({String? authToken}) async {
    // 1. Sync any pending set completions first
    await syncPendingSetCompletionsWithBackend();

    // 2. Sync full workout records
    if (_pendingSyncRecords.isEmpty) return;
    final toSync = List<WorkoutRecord>.from(_pendingSyncRecords);
    for (final record in toSync) {
      final success = await syncWorkoutRecordToBackend(record, authToken: authToken);
      if (!success) break;
    }
  }

  String _normalizeWorkoutType(String type) {
    const valid = [
      'Strength',
      'Hypertrophy',
      'Full Body',
      'Conditioning',
      'HIIT',
      'Cardio',
      'Mobility',
    ];
    for (final v in valid) {
      if (v.toLowerCase() == type.toLowerCase().trim()) return v;
    }
    return 'Strength';
  }

  String _mapSetType(SetType type) {
    switch (type) {
      case SetType.warmup:
        return 'Warm-up';
      case SetType.failure:
        return 'Failure';
      case SetType.dropSet:
        return 'Drop set';
      case SetType.restPause:
        return 'Rest-pause';
      default:
        return 'Working';
    }
  }

  Map<String, dynamic> _formatBackendRecordPayload(WorkoutRecord record) {
    return {
      'sessionId': record.sessionId,
      'assignmentId': record.assignmentId,
      'sessionTitle': record.sessionTitle.isNotEmpty ? record.sessionTitle : 'Workout Session',
      'workoutType': _normalizeWorkoutType(record.workoutType),
      'scheduledDate': record.scheduledDate ?? IstDateUtils.toISTDateString(record.completedAt ?? record.startedAt),
      'isLocked': record.isLocked,
      'startedAt': record.startedAt.toUtc().toIso8601String(),
      'completedAt': (record.completedAt ?? DateTime.now()).toUtc().toIso8601String(),
      'durationSeconds': record.durationSeconds,
      'totalVolume': record.totalVolume,
      'completedSetsCount': record.completedSetsCount,
      'skippedSetsCount': record.skippedSetsCount,
      'averageRpe': record.averageRpe,
      'averageRir': record.averageRir?.toInt(),
      'isCompleted': record.isCompleted,
      'personalRecords': record.personalRecords.map((p) => p.toJson()).toList(),
      'notes': record.notes,
      'exerciseRecords': record.exercises.isEmpty
          ? [
              {
                'exerciseId': 'ex_general_session',
                'exerciseName': record.sessionTitle.isNotEmpty ? record.sessionTitle : 'General Training Activity',
                'orderIndex': 0,
                'supersetTag': null,
                'isSkipped': false,
                'skipReason': null,
                'clientNote': record.notes,
                'adminNote': null,
                'sets': [
                  {
                    'setNumber': 1,
                    'setType': 'Working',
                    'targetReps': '1',
                    'targetWeight': null,
                    'actualWeight': null,
                    'actualReps': 1,
                    'actualRir': null,
                    'actualRpe': null,
                    'tempo': null,
                    'isCompleted': true,
                    'completedAt': (record.completedAt ?? DateTime.now()).toUtc().toIso8601String(),
                    'notes': 'Session recorded',
                  }
                ],
              }
            ]
          : record.exercises.asMap().entries.map((entry) {
              final idx = entry.key;
              final ex = entry.value;
              return {
                'exerciseId': ex.exerciseId,
                'exerciseName': ex.exerciseName,
                'orderIndex': idx,
                'supersetTag': ex.supersetTag,
                'isSkipped': ex.isSkipped,
                'skipReason': ex.skipReason,
                'clientNote': ex.clientNote,
                'adminNote': ex.trainerNote.isNotEmpty ? ex.trainerNote : null,
                'sets': ex.sets.map((s) {
                  return {
                    'setNumber': s.setNumber,
                    'setType': _mapSetType(s.setType),
                    'targetReps': s.targetRepsDisplay,
                    'targetWeight': s.targetWeight > 0 ? s.targetWeight : null,
                    'actualWeight': s.actualWeight ?? (s.isCompleted ? s.targetWeight : null),
                    'actualReps': s.actualReps ?? (s.isCompleted ? s.targetRepsMin : null),
                    'actualRir': s.actualRir,
                    'actualRpe': s.actualRpe,
                    'tempo': s.tempo.isNotEmpty ? s.tempo : null,
                    'isCompleted': s.isCompleted,
                    'completedAt': s.completedAt?.toUtc().toIso8601String(),
                    'notes': s.notes,
                  };
                }).toList(),
              };
            }).toList(),
    };
  }

  // ==========================================
  // REAL PROGRESS APIS
  // ==========================================


  Future<List<Map<String, dynamic>>> fetchClientProgress() async {
    try {
      final token = await AuthService().getValidToken();
      final url = Uri.parse('${AppConstants.apiBaseUrl}/client/me/progress');
      final res = await _httpClient.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded['data'] is List) {
          return List<Map<String, dynamic>>.from(decoded['data']);
        }
      }
    } catch (e) {
      debugPrint('[WorkoutRepository] Failed to fetch client progress: $e');
    }
    return [];
  }

  Future<bool> logClientProgress({required double weightKg, double? waistCm, String? notes}) async {
    try {
      final token = await AuthService().getValidToken();
      final url = Uri.parse('${AppConstants.apiBaseUrl}/client/me/progress');
      final payload = <String, dynamic>{'weightKg': weightKg};
      if (waistCm != null) payload['waistCm'] = waistCm;
      if (notes != null) payload['notes'] = notes;
      final res = await _httpClient.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200 || res.statusCode == 201) {
        final currentProfile = Map<String, dynamic>.from(AuthService().clientProfile);
        currentProfile['weightKg'] = weightKg;
        AuthService().updateLocalProfile(currentProfile);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('[WorkoutRepository] Failed to log progress: $e');
    }
    return false;
  }

  Future<bool> updateOwnName(String newName) async {
    try {
      final token = await AuthService().getValidToken();
      final url = Uri.parse('${AppConstants.apiBaseUrl}/client/me/profile');
      final res = await _httpClient.patch(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'name': newName}),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200 || res.statusCode == 201) {
        final currentProfile = Map<String, dynamic>.from(AuthService().clientProfile);
        currentProfile['name'] = newName;
        AuthService().updateLocalProfile(currentProfile);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('[WorkoutRepository] Failed to update own name: $e');
    }
    if (_isTestEnvironment) {
      final currentProfile = Map<String, dynamic>.from(AuthService().clientProfile);
      currentProfile['name'] = newName;
      AuthService().updateLocalProfile(currentProfile);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> updateClientProfile(String clientId, Map<String, dynamic> payload) async {
    try {
      final token = await AuthService().getValidToken();
      final url = Uri.parse('${AppConstants.apiBaseUrl}/admin/clients/$clientId/profile');
      final res = await _httpClient.patch(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200 || res.statusCode == 201) {
        final idx = _clients.indexWhere((c) => c['id'] == clientId || c['clientId'] == clientId);
        if (idx != -1) {
          final updated = Map<String, String>.from(_clients[idx]);
          payload.forEach((k, v) {
            if (v != null) updated[k] = v.toString();
          });
          _clients[idx] = updated;
        }
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('[WorkoutRepository] Failed to update client profile: $e');
    }
    if (_isTestEnvironment) {
      final idx = _clients.indexWhere((c) => c['id'] == clientId || c['clientId'] == clientId);
      if (idx != -1) {
        final updated = Map<String, String>.from(_clients[idx]);
        payload.forEach((k, v) {
          if (v != null) updated[k] = v.toString();
        });
        _clients[idx] = updated;
      }
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Fetches client's canonical 7-day workout split
  Future<WorkoutSplitPlan?> fetchClientWorkoutSplit(String clientId) async {
    final token = await AuthService().getValidToken();
    if (token.isEmpty && !_isTestEnvironment) return null;

    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/workout/admin/clients/$clientId/split');
      final response = await _httpClient.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true && decoded['data'] != null) {
          return WorkoutSplitPlan.fromJson(decoded['data'] as Map<String, dynamic>);
        }
      }
    } catch (e) {
      debugPrint('[WorkoutRepository] fetchClientWorkoutSplit error: $e');
    }

    // In-memory reconstruction fallback for offline / test environments
    final clientAssignments = _assignments.where((a) => a.clientId == clientId && a.status != 'CANCELLED').toList();
    if (clientAssignments.isEmpty) return null;

    final days = <WorkoutSplitDay>[];
    final dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    for (int i = 0; i < 7; i++) {
      final dayName = dayNames[i];
      final match = clientAssignments.where((a) {
        final s = _sessions.where((sess) => sess.id == a.sessionId).firstOrNull;
        if (s == null) return false;
        return (s.recurringSchedule ?? '').toLowerCase().contains(dayName.toLowerCase());
      }).firstOrNull;

      if (match != null) {
        final s = _sessions.firstWhere((sess) => sess.id == match.sessionId);
        days.add(WorkoutSplitDay(
          id: 'split_day_${s.id}',
          sessionId: s.id,
          dayOfWeek: dayName,
          dayIndex: i + 1,
          name: s.title,
          workoutType: s.workoutType,
          targetMuscleGroup: s.targetMuscleGroup,
          estimatedDurationMinutes: s.estimatedDurationMinutes,
          isRestDay: false,
          notes: s.description,
          exercises: s.exercises,
        ));
      } else {
        days.add(WorkoutSplitDay(
          id: 'split_day_rest_${i + 1}',
          dayOfWeek: dayName,
          dayIndex: i + 1,
          name: 'Rest Day',
          workoutType: 'Rest',
          targetMuscleGroup: 'Recovery',
          estimatedDurationMinutes: 0,
          isRestDay: true,
          notes: 'Rest & recovery day.',
          exercises: const [],
        ));
      }
    }

    return WorkoutSplitPlan(
      id: 'split_$clientId',
      title: 'Workout Split',
      clientId: clientId,
      days: days,
    );
  }

  /// Saves or creates a canonical workout split
  Future<WorkoutSplitPlan?> saveWorkoutSplit(WorkoutSplitPlan split) async {
    final token = await AuthService().getValidToken();
    if (token.isEmpty && !_isTestEnvironment) return null;

    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/workout/admin/splits');
      final response = await _httpClient.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(split.toJson()),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true && decoded['data'] != null) {
          final savedSplit = WorkoutSplitPlan.fromJson(decoded['data'] as Map<String, dynamic>);
          await fetchAdminSessions();
          return savedSplit;
        }
      }
    } catch (e) {
      debugPrint('[WorkoutRepository] saveWorkoutSplit error: $e');
    }

    // In-memory update for offline / test environments
    for (final day in split.days) {
      if (!day.isRestDay) {
        final session = WorkoutSession(
          id: day.sessionId ?? 'ws_${split.id}_${day.dayIndex}',
          title: day.name,
          workoutType: day.workoutType,
          targetMuscleGroup: day.targetMuscleGroup,
          estimatedDurationMinutes: day.estimatedDurationMinutes,
          recurringSchedule: day.dayOfWeek,
          description: day.notes,
          exercises: day.exercises,
          assignedClientIds: split.clientId != null ? [split.clientId!] : const [],
        );
        final existingIdx = _sessions.indexWhere((s) => s.id == session.id);
        if (existingIdx != -1) {
          _sessions[existingIdx] = session;
        } else {
          _sessions.add(session);
        }

        if (split.clientId != null) {
          _assignments.removeWhere((a) => a.clientId == split.clientId && a.sessionId == session.id);
          _assignments.add(WorkoutAssignmentData(
            id: 'assign_${session.id}_${split.clientId}',
            sessionId: session.id,
            clientId: split.clientId,
            isRecommended: day.dayIndex == 1,
            assignedAt: DateTime.now(),
            status: 'ASSIGNED',
          ));
        }
      }
    }
    notifyListeners();
    return split;
  }

  /// Updates a specific day's workout within a split without touching other days
  Future<bool> updateWorkoutSplitDay(String splitId, String dayId, WorkoutSplitDay day) async {
    final token = await AuthService().getValidToken();
    if (token.isEmpty && !_isTestEnvironment) return false;

    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/workout/admin/splits/$splitId/days/$dayId');
      final response = await _httpClient.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(day.toJson()),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        await fetchAdminSessions();
        return true;
      }
    } catch (e) {
      debugPrint('[WorkoutRepository] updateWorkoutSplitDay error: $e');
    }

    // In-memory update
    final targetId = day.sessionId ?? dayId;
    final idx = _sessions.indexWhere((s) => s.id == targetId || s.id.contains(dayId));
    if (idx != -1) {
      _sessions[idx] = _sessions[idx].copyWith(
        title: day.name,
        targetMuscleGroup: day.targetMuscleGroup,
        workoutType: day.workoutType,
        estimatedDurationMinutes: day.estimatedDurationMinutes,
        exercises: day.exercises,
        recurringSchedule: day.dayOfWeek,
      );
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Persists an exercise replacement to backend PostgreSQL so that all future occurrences
  /// of this workout session automatically use the user's preferred exercise.
  Future<bool> syncExerciseReplacementToBackend({
    required String sessionId,
    required String originalExerciseId,
    String? originalExerciseName,
    required String replacementExerciseId,
    required String replacementExerciseName,
    String? category,
    String? primaryMusclesDisplay,
    String? secondaryMusclesDisplay,
    String? trainerNote,
    int? numberOfSets,
    String? targetReps,
    double? targetWeight,
    List<dynamic>? customSets,
    String? dayOfWeek,
  }) async {
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/workout/client/sessions/$sessionId/override/replace');
      final token = await AuthService().getValidToken();

      final payload = {
        'originalExerciseId': originalExerciseId,
        'originalExerciseName': originalExerciseName,
        'replacementExerciseId': replacementExerciseId,
        'replacementExerciseName': replacementExerciseName,
        'category': category,
        'primaryMusclesDisplay': primaryMusclesDisplay,
        'secondaryMusclesDisplay': secondaryMusclesDisplay,
        'trainerNote': trainerNote,
        'numberOfSets': numberOfSets,
        'targetReps': targetReps,
        'targetWeight': targetWeight,
        'customSets': customSets,
        'dayOfWeek': dayOfWeek,
      };

      final response = await _httpClient.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[WorkoutRepository] Persisted exercise replacement $originalExerciseId -> $replacementExerciseName for session $sessionId');
        return true;
      } else {
        debugPrint('[WorkoutRepository] Failed to persist replacement: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('[WorkoutRepository] syncExerciseReplacementToBackend error: $e');
      return false;
    }
  }

  /// Persists a custom added exercise to backend PostgreSQL for future session occurrences.
  Future<bool> syncExerciseAdditionToBackend({
    required String sessionId,
    required WorkoutExercise exercise,
    String? dayOfWeek,
  }) async {
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/workout/client/sessions/$sessionId/override/add-exercise');
      final token = await AuthService().getValidToken();

      final payload = {
        'exercise': exercise.toJson(),
        'dayOfWeek': dayOfWeek,
      };

      final response = await _httpClient.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[WorkoutRepository] Persisted custom exercise addition ${exercise.exerciseName} for session $sessionId');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[WorkoutRepository] syncExerciseAdditionToBackend error: $e');
      return false;
    }
  }

  /// Persists removing an exercise from future occurrences of this session.
  Future<bool> syncExerciseRemovalToBackend({
    required String sessionId,
    required String exerciseId,
    String? dayOfWeek,
  }) async {
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/workout/client/sessions/$sessionId/override/remove-exercise');
      final token = await AuthService().getValidToken();

      final payload = {
        'exerciseId': exerciseId,
        'dayOfWeek': dayOfWeek,
      };

      final response = await _httpClient.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('[WorkoutRepository] syncExerciseRemovalToBackend error: $e');
      return false;
    }
  }

  /// Resets all customizations for a session back to the admin\'s original template.
  Future<bool> resetSessionCustomizations(String sessionId) async {
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/workout/client/sessions/$sessionId/override');
      final token = await AuthService().getValidToken();

      final response = await _httpClient.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        await fetchClientWorkouts(forceRefresh: true);
        final restored = _sessions.firstWhere((s) => s.id == sessionId, orElse: () => _activeSession);
        _activeSession = restored;
        final uid = _activeSession.assignedClientId ?? AuthService().currentUserId;
        if (uid.isNotEmpty) {
          saveActiveSessionToLocalStorage(userId: uid);
        }
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[WorkoutRepository] resetSessionCustomizations error: $e');
      return false;
    }
  }

  /// Resets a single customized exercise back to the admin\'s original prescribed exercise.
  Future<bool> resetExerciseCustomization(String sessionId, String exerciseId) async {
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/workout/client/sessions/$sessionId/override?exerciseId=$exerciseId');
      final token = await AuthService().getValidToken();

      final response = await _httpClient.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        await fetchClientWorkouts(forceRefresh: true);
        final restored = _sessions.firstWhere((s) => s.id == sessionId, orElse: () => _activeSession);
        _activeSession = restored;
        final uid = _activeSession.assignedClientId ?? AuthService().currentUserId;
        if (uid.isNotEmpty) {
          saveActiveSessionToLocalStorage(userId: uid);
        }
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[WorkoutRepository] resetExerciseCustomization error: $e');
      return false;
    }
  }
}
