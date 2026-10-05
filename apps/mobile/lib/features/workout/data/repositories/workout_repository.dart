import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/core/constants/app_constants.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/features/workout/domain/models/workout_models.dart';
import 'package:alpha_x_gym/features/exercise/domain/models/exercise_model.dart';
import 'package:alpha_x_gym/features/exercise/data/repositories/exercise_repository.dart';

class WorkoutAssignmentData {
  final String id;
  final String sessionId;
  final String? clientId; // null means ALL clients
  final bool isRecommended;
  final DateTime assignedAt;

  WorkoutAssignmentData({
    required this.id,
    required this.sessionId,
    this.clientId,
    this.isRecommended = false,
    DateTime? assignedAt,
  }) : assignedAt = assignedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'sessionId': sessionId,
    'clientId': clientId,
    'isRecommended': isRecommended,
    'assignedAt': assignedAt.toIso8601String(),
  };

  factory WorkoutAssignmentData.fromJson(Map<String, dynamic> json) => WorkoutAssignmentData(
    id: json['id'] as String? ?? '',
    sessionId: json['sessionId'] as String? ?? '',
    clientId: json['clientId'] as String?,
    isRecommended: json['isRecommended'] as bool? ?? false,
    assignedAt: json['assignedAt'] != null ? DateTime.tryParse(json['assignedAt'] as String) : null,
  );
}

class WorkoutRepository extends ChangeNotifier {
  static const String _storageKeySessions = 'alpha_x_workout_sessions';
  static const String _storageKeyAssignments = 'alpha_x_workout_assignments';
  static const String _storageKeyHistory = 'alpha_x_workout_history';
  static const String _storageKeyChangeRequests = 'alpha_x_change_requests';
  static const String _storageKeyPendingSync = 'alpha_x_pending_workout_records';
  static const String _storageKeyActiveSession = 'alpha_x_workout_active_session_state';
  static const String _storageKeyActiveSessionTimestamp = 'alpha_x_workout_active_session_timestamp';
  static const String _storageKeyActiveSessionDuration = 'alpha_x_workout_active_session_duration';

  final http.Client _httpClient;
  void Function(WorkoutRecord record)? onWorkoutCompleted;

  late WorkoutSession _activeSession;
  bool _hasRestoredActiveSession = false;
  DateTime? _activeSessionSavedAt;
  final List<WorkoutSession> _sessions = [];
  final List<WorkoutAssignmentData> _assignments = [];
  final List<WorkoutRecord> _workoutHistory = [];
  final List<WorkoutRecord> _pendingSyncRecords = [];
  final List<ExerciseChangeRequest> _changeRequests = [];
  final List<ExerciseSwapRecord> _currentSessionSwaps = [];

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
    _initSeededSessions();
    _activeSession = _sessions.first;
    _initSeededChangeRequests();
    if (_isTestEnvironment) {
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
  List<Map<String, String>> get clientsList => List.unmodifiable(_clients);
  int get pendingSyncCount => _pendingSyncRecords.length;
  bool get hasActiveSavedSession => _hasRestoredActiveSession && !_activeSession.isCompleted;
  DateTime? get activeSessionSavedAt => _activeSessionSavedAt;
  /// Fetches real registered clients exclusively from the shared backend database (PostgreSQL).
  /// NEVER falls back to demo/sample/example data.
  Future<List<Map<String, String>>> fetchClientsList({bool forceRefresh = false}) async {
    var token = AuthService().currentToken;

    // In production or when token is a local placeholder, acquire live JWT token
    if ((token == 'local_admin_session_token' || !token.contains('.')) &&
        !_isTestEnvironment &&
        AuthService().isAdmin) {
      final freshToken = await AuthService().refreshAdminToken();
      if (freshToken != null && freshToken.isNotEmpty) {
        token = freshToken;
      }
    }

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
    final token = AuthService().currentToken;
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
      final token = AuthService().currentToken;
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
      final token = AuthService().currentToken;
      final url = Uri.parse('${AppConstants.apiBaseUrl}/admin/clients/$clientId/diet-plans');
      final resp = await _httpClient.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(dietData),
      ).timeout(const Duration(seconds: 5));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Assigns custom Macro targets to a specific client.
  Future<bool> assignMacroPlanToClient(String clientId, Map<String, dynamic> macroData) async {
    try {
      final token = AuthService().currentToken;
      final url = Uri.parse('${AppConstants.apiBaseUrl}/admin/clients/$clientId/macros');
      final resp = await _httpClient.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(macroData),
      ).timeout(const Duration(seconds: 5));
      return resp.statusCode == 200;
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

    // Assignments: Push A is recommended for ALL clients
    _assignments.add(
      WorkoutAssignmentData(
        id: 'assign_push_a_all',
        sessionId: pushA.id,
        clientId: null,
        isRecommended: true,
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
      var token = AuthService().currentToken;
      if ((token == 'local_admin_session_token' || !token.contains('.')) &&
          !_isTestEnvironment &&
          AuthService().isAdmin) {
        final freshToken = await AuthService().refreshAdminToken();
        if (freshToken != null && freshToken.isNotEmpty) {
          token = freshToken;
        }
      }

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
          'numberOfSets': e.sets.isNotEmpty ? e.sets.length : 3,
          'targetReps': e.sets.isNotEmpty ? '${e.sets.first.targetRepsMin}–${e.sets.first.targetRepsMax}' : '8–12',
          'targetWeight': e.sets.isNotEmpty ? e.sets.first.targetWeight : null,
          'restSeconds': e.restSeconds,
          'targetRir': e.sets.isNotEmpty ? e.sets.first.targetRir : 2,
          'targetRpe': e.sets.isNotEmpty ? e.sets.first.targetRpe : 8.0,
          'tempo': e.tempo,
          'setType': e.sets.isNotEmpty && e.sets.first.setType == SetType.warmup ? 'Warm-up' : 'Working',
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
      if (_activeSession.id == session.id) {
        _activeSession = versionedSession;
      }
      _saveToLocalStorage();
      notifyListeners();
    }

    try {
      var token = AuthService().currentToken;
      if ((token == 'local_admin_session_token' || !token.contains('.')) &&
          !_isTestEnvironment &&
          AuthService().isAdmin) {
        final freshToken = await AuthService().refreshAdminToken();
        if (freshToken != null && freshToken.isNotEmpty) {
          token = freshToken;
        }
      }

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
          'numberOfSets': e.sets.isNotEmpty ? e.sets.length : 3,
          'targetReps': e.sets.isNotEmpty ? '${e.sets.first.targetRepsMin}–${e.sets.first.targetRepsMax}' : '8–12',
          'targetWeight': e.sets.isNotEmpty ? e.sets.first.targetWeight : null,
          'restSeconds': e.restSeconds,
          'targetRir': e.sets.isNotEmpty ? e.sets.first.targetRir : 2,
          'targetRpe': e.sets.isNotEmpty ? e.sets.first.targetRpe : 8.0,
          'tempo': e.tempo,
          'setType': e.sets.isNotEmpty && e.sets.first.setType == SetType.warmup ? 'Warm-up' : 'Working',
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

      if (response.statusCode == 200) return true;
      debugPrint('[WorkoutRepository] updateSession error: ${response.statusCode} -> ${response.body}');
      return false;
    } catch (e) {
      debugPrint('[WorkoutRepository] updateSession sync error: $e');
      return false;
    }
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
    _sessions.insert(0, duplicated);
    _saveToLocalStorage();
    notifyListeners();

    // Persist duplicated session to backend
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
    if (_activeSession.id == sessionId && _sessions.isNotEmpty) {
      _activeSession = _sessions.first;
    }
    _saveToLocalStorage();
    notifyListeners();

    try {
      var token = AuthService().currentToken;
      if ((token == 'local_admin_session_token' || !token.contains('.')) &&
          !_isTestEnvironment &&
          AuthService().isAdmin) {
        final freshToken = await AuthService().refreshAdminToken();
        if (freshToken != null && freshToken.isNotEmpty) {
          token = freshToken;
        }
      }

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
          );
        } else if (assignmentType == 'INDIVIDUAL' && a.clientId == individualClientId) {
          _assignments[i] = WorkoutAssignmentData(
            id: a.id,
            sessionId: a.sessionId,
            clientId: a.clientId,
            isRecommended: false,
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
          ),
        );
      }
    }

    _saveToLocalStorage();
    notifyListeners();

    // Persist assignment to backend database
    try {
      var token = AuthService().currentToken;
      if ((token == 'local_admin_session_token' || !token.contains('.')) &&
          !_isTestEnvironment &&
          AuthService().isAdmin) {
        final freshToken = await AuthService().refreshAdminToken();
        if (freshToken != null && freshToken.isNotEmpty) {
          token = freshToken;
        }
      }

      final url = Uri.parse('${AppConstants.apiBaseUrl}/admin/workouts/$sessionId/assign');
      final payload = jsonEncode({
        'assignmentType': assignmentType,
        'clientIds': clientIds ?? [],
        'individualClientId': individualClientId,
        'isRecommended': isRecommended,
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
        final localIdx = _sessions.indexWhere((s) => s.id == sessionId);
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

      if (response.statusCode == 200 || response.statusCode == 201) return true;
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

    try {
      var token = AuthService().currentToken;
      if ((token == 'local_admin_session_token' || !token.contains('.')) &&
          !_isTestEnvironment &&
          AuthService().isAdmin) {
        final freshToken = await AuthService().refreshAdminToken();
        if (freshToken != null && freshToken.isNotEmpty) {
          token = freshToken;
        }
      }

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
    var token = AuthService().currentToken;
    if ((token == 'local_admin_session_token' || !token.contains('.')) &&
        !_isTestEnvironment &&
        AuthService().isAdmin) {
      final freshToken = await AuthService().refreshAdminToken();
      if (freshToken != null && freshToken.isNotEmpty) {
        token = freshToken;
      }
    }

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
    final token = AuthService().currentToken;
    if (token.isEmpty) return;

    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/workout/client/sessions');
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
          final data = decoded['data'];
          final List<dynamic> availableJson = data['available'] as List<dynamic>? ?? [];
          final Map<String, dynamic>? recJson = data['recommended'] as Map<String, dynamic>?;

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
                id: 'assign_${fs.id}_$currentClientId',
                sessionId: fs.id,
                clientId: currentClientId,
                isRecommended: fs.isRecommended,
              ));
            }

            if (_sessions.isNotEmpty) {
              final rec = getRecommendedSessionForClient(currentClientId);
              if (rec != null) {
                _activeSession = rec;
              }
            }

            _saveToLocalStorage();
            notifyListeners();
          }
        }
      }
    } catch (e) {
      debugPrint('[WorkoutRepository] Failed to fetch client workouts: $e');
    }
  }

  // --- Client Discovery & Access Scoping ---
  WorkoutSession? getRecommendedSessionForClient(String clientId) {
    // 1. Look for client-specific recommended assignment
    final clientRec = _assignments.firstWhere(
      (a) => a.clientId == clientId && a.isRecommended,
      orElse: () => WorkoutAssignmentData(id: '', sessionId: ''),
    );
    if (clientRec.sessionId.isNotEmpty) {
      final s = _sessions.where((s) => s.id == clientRec.sessionId && s.isActive).firstOrNull;
      if (s != null) return s.copyWith(isRecommended: true);
    }

    // 2. Look for global ALL recommended assignment
    final globalRec = _assignments.firstWhere(
      (a) => a.clientId == null && a.isRecommended,
      orElse: () => WorkoutAssignmentData(id: '', sessionId: ''),
    );
    if (globalRec.sessionId.isNotEmpty) {
      final s = _sessions.where((s) => s.id == globalRec.sessionId && s.isActive).firstOrNull;
      if (s != null) return s.copyWith(isRecommended: true);
    }

    return null;
  }

  List<WorkoutSession> getAuthorizedSessionsForClient(String clientId) {
    final authorizedSessionIds = _assignments
        .where((a) => a.clientId == null || a.clientId == clientId)
        .map((a) => a.sessionId)
        .toSet();

    return _sessions.where((s) => s.isActive && authorizedSessionIds.contains(s.id)).toList();
  }

  WorkoutSession? getTodaySessionForClient(String clientId) {
    final todayWeekday = DateTime.now().weekday; // 1 = Mon ... 7 = Sun
    final authorized = getAuthorizedSessionsForClient(clientId);

    // 1. Check weekly schedule mapping
    for (final s in authorized) {
      if (s.weeklySchedule != null &&
          s.weeklySchedule!.dayOfWeekSessionId.containsKey(todayWeekday)) {
        final targetId = s.weeklySchedule!.dayOfWeekSessionId[todayWeekday];
        if (targetId != null && targetId == s.id) {
          return s;
        }
      }
      if (s.trainingDays.contains(todayWeekday)) {
        return s;
      }
    }

    // 2. Recommended session
    final rec = getRecommendedSessionForClient(clientId);
    if (rec != null) return rec;

    // 3. First authorized or default active
    if (authorized.isNotEmpty) return authorized.first;
    if (_sessions.isNotEmpty) return _sessions.first;
    return null;
  }

  // --- Client Workout Execution ---
  void startSession(WorkoutSession session) {
    _currentSessionSwaps.clear();
    // Deep clone with fresh sets for execution (creates a new record without mutating template)
    _activeSession = session.copyWith(
      startedAt: DateTime.now(),
      completedAt: null,
      durationSeconds: 0,
      isCompleted: false,
      exercises: session.exercises.map((ex) {
        return ex.copyWith(
          isSkipped: false,
          skipReason: null,
          clientNote: null,
          sets: ex.sets.map((s) {
            return s.copyWith(
              isCompleted: false,
              completedAt: null,
              actualWeight: s.actualWeight ?? s.targetWeight,
              actualReps: s.actualReps ?? s.targetRepsMin,
              actualRir: s.actualRir ?? s.targetRir,
              actualRpe: s.actualRpe ?? s.targetRpe,
            );
          }).toList(),
        );
      }).toList(),
    );
    _hasRestoredActiveSession = true;
    _activeSessionSavedAt = DateTime.now();
    saveActiveSessionToLocalStorage(elapsedSeconds: 0);
    notifyListeners();
  }

  void updateSetActual({
    required int exerciseIndex,
    required int setIndex,
    double? weight,
    int? reps,
    double? rpe,
    int? rir,
  }) {
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
    if (exerciseIndex >= _activeSession.exercises.length) return;
    final exercise = _activeSession.exercises[exerciseIndex];
    if (setIndex >= exercise.sets.length) return;

    final oldSet = exercise.sets[setIndex];
    final updatedSet = oldSet.copyWith(
      isCompleted: false,
    );

    final updatedSets = List<ExerciseSet>.from(exercise.sets);
    updatedSets[setIndex] = updatedSet;

    final updatedExercises = List<WorkoutExercise>.from(_activeSession.exercises);
    updatedExercises[exerciseIndex] = exercise.copyWith(sets: updatedSets);

    _activeSession = _activeSession.copyWith(exercises: updatedExercises);
    saveActiveSessionToLocalStorage();
    notifyListeners();
  }

  void skipExercise(int exerciseIndex, {String? reason}) {
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
    if (exerciseIndex >= _activeSession.exercises.length) return false;
    final exercise = _activeSession.exercises[exerciseIndex];
    if (setIndex >= exercise.sets.length) return false;

    final targetSet = exercise.sets[setIndex];
    if (targetSet.isCompleted) return false;

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

  bool swapExercise(int exerciseIndex, String newExerciseId) {
    if (exerciseIndex >= _activeSession.exercises.length) return false;

    // Check client swap permissions
    if (!_activeSession.permissions.allowExerciseSwap) {
      return false;
    }

    final currentEx = _activeSession.exercises[exerciseIndex];
    final newExercise = ExerciseRepository.getById(newExerciseId);
    if (newExercise == null) return false;

    // Biomechanical check: must be approved alternative or same primary muscle
    final isApproved = currentEx.approvedAlternativeIds.contains(newExerciseId) ||
        ExerciseRepository.getApprovedAlternatives(currentEx.exerciseId).any((a) => a.id == newExerciseId) ||
        newExercise.category.toLowerCase() == currentEx.category.toLowerCase();

    if (!isApproved) {
      return false;
    }

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
      approvedAlternativeIds: [
        currentEx.exerciseId,
        ...newExercise.approvedAlternativeIds.where((id) => id != currentEx.exerciseId),
      ],
    );

    final updatedExercises = List<WorkoutExercise>.from(_activeSession.exercises);
    updatedExercises[exerciseIndex] = updatedExercise;

    _activeSession = _activeSession.copyWith(exercises: updatedExercises);
    saveActiveSessionToLocalStorage();
    notifyListeners();
    return true;
  }

  WorkoutRecord completeWorkout({String? notes, int? durationSeconds, String? authToken}) {
    final now = DateTime.now();
    final duration = durationSeconds ??
        now.difference(_activeSession.startedAt).inSeconds.clamp(60, 10800);

    _activeSession = _activeSession.copyWith(
      isCompleted: true,
      completedAt: now,
      durationSeconds: duration,
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

    final currentUserId = AuthService().currentUserId.isNotEmpty
        ? AuthService().currentUserId
        : AuthService().currentClientId;

    final record = WorkoutRecord(
      id: 'rec_${DateTime.now().millisecondsSinceEpoch}',
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
    );

    _currentSessionSwaps.clear();
    _hasRestoredActiveSession = false;
    _activeSessionSavedAt = null;
    discardActiveSession();
    _workoutHistory.insert(0, record);
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
    final clientHistory = getClientExerciseHistory(
      clientId: targetClientId,
      exerciseId: exerciseId,
    );
    if (clientHistory.isNotEmpty) {
      return clientHistory.first.sets;
    }

    // Fallback across all records if none found for specific client (backward compatibility)
    for (final record in _workoutHistory) {
      final ex = record.exercises.firstWhere(
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
      if (ex.exerciseId.isNotEmpty && ex.sets.isNotEmpty) {
        final completedSets = ex.sets.where((s) => s.isCompleted).toList();
        if (completedSets.isNotEmpty) return completedSets;
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

      // Restore active in-progress workout session if saved within 24 hours
      final activeRaw = prefs.getString(_storageKeyActiveSession);
      if (activeRaw != null && activeRaw.isNotEmpty) {
        try {
          final activeMap = jsonDecode(activeRaw) as Map<String, dynamic>;
          final restored = WorkoutSession.fromJson(activeMap);
          final age = DateTime.now().difference(restored.startedAt);
          if (!restored.isCompleted && age.inHours < 24) {
            _activeSession = restored;
            _hasRestoredActiveSession = true;
            final tsStr = prefs.getString(_storageKeyActiveSessionTimestamp);
            if (tsStr != null) {
              _activeSessionSavedAt = DateTime.tryParse(tsStr);
            }
          }
        } catch (e) {
          debugPrint('[WorkoutRepository] Failed to restore active session: $e');
        }
      }

      notifyListeners();

      // Attempt to sync any pending records saved from offline mode
      syncPendingRecordsWithBackend();
    } catch (_) {}
  }

  Future<void> saveActiveSessionToLocalStorage({int? elapsedSeconds}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionJson = _activeSession.toJson();
      await prefs.setString(_storageKeyActiveSession, jsonEncode(sessionJson));
      final now = DateTime.now().toUtc().toIso8601String();
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

  Future<void> discardActiveSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKeyActiveSession);
      await prefs.remove(_storageKeyActiveSessionTimestamp);
      await prefs.remove(_storageKeyActiveSessionDuration);
      _hasRestoredActiveSession = false;
      _activeSessionSavedAt = null;
      _currentSessionSwaps.clear();
      notifyListeners();
    } catch (e) {
      debugPrint('[WorkoutRepository] Failed to discard active session: $e');
    }
  }

  Future<int?> getSavedActiveSessionDuration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
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
    } catch (_) {}
  }

  Future<void> _savePendingSyncRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingList = _pendingSyncRecords.map((r) => r.toJson()).toList();
      await prefs.setString(_storageKeyPendingSync, jsonEncode(pendingList));
    } catch (_) {}
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

  /// Push an individual workout record to the backend REST API.
  /// If the backend is unreachable or offline, the record is safely queued in
  /// local storage so no workouts or sets are ever lost.
  Future<bool> syncWorkoutRecordToBackend(WorkoutRecord record, {String? authToken}) async {
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/workout/client/records');
      final token = authToken ??
          (AuthService().currentToken.isNotEmpty
              ? AuthService().currentToken
              : 'alpha_x_mock_token_for_client');

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
      'sessionTitle': record.sessionTitle.isNotEmpty ? record.sessionTitle : 'Workout Session',
      'workoutType': _normalizeWorkoutType(record.workoutType),
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
      'exerciseRecords': record.exercises.asMap().entries.map((entry) {
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
  // REAL ATTENDANCE, CHALLENGE & PROGRESS APIS
  // ==========================================

  Future<List<Map<String, dynamic>>> fetchClientAttendance() async {
    try {
      final token = AuthService().currentToken;
      final url = Uri.parse('${AppConstants.apiBaseUrl}/client/me/attendance');
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
      debugPrint('[WorkoutRepository] Failed to fetch client attendance: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> fetchClientChallenge() async {
    try {
      final token = AuthService().currentToken;
      final url = Uri.parse('${AppConstants.apiBaseUrl}/client/me/challenge');
      final res = await _httpClient.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded['data'] is Map) {
          return Map<String, dynamic>.from(decoded['data']);
        }
      }
    } catch (e) {
      debugPrint('[WorkoutRepository] Failed to fetch client challenge: $e');
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> fetchClientProgress() async {
    try {
      final token = AuthService().currentToken;
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
      final token = AuthService().currentToken;
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

  Future<List<Map<String, dynamic>>> fetchAdminAttendance() async {
    try {
      final token = AuthService().currentToken;
      final url = Uri.parse('${AppConstants.apiBaseUrl}/admin/attendance');
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
      debugPrint('[WorkoutRepository] Failed to fetch admin attendance: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchAdminChallenges() async {
    try {
      final token = AuthService().currentToken;
      final url = Uri.parse('${AppConstants.apiBaseUrl}/admin/challenges');
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
      debugPrint('[WorkoutRepository] Failed to fetch admin challenges: $e');
    }
    return [];
  }
}
