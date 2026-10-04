import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Alpha X Gym Basement-Proof Offline-First Workout Logger Tests', () {
    test('startSession immediately persists active session state to local storage', () async {
      final repo = WorkoutRepository(httpClient: MockClient((_) async => http.Response('{}', 200)));
      final targetSession = repo.adminSessions.first;

      repo.startSession(targetSession);

      expect(repo.hasActiveSavedSession, isTrue);
      expect(repo.activeSession.title, equals(targetSession.title));

      final prefs = await SharedPreferences.getInstance();
      final savedActiveRaw = prefs.getString('alpha_x_workout_active_session_state');
      expect(savedActiveRaw, isNotNull);
      expect(savedActiveRaw, isNotEmpty);

      final decoded = jsonDecode(savedActiveRaw!) as Map<String, dynamic>;
      expect(decoded['id'], equals(targetSession.id));
      expect(decoded['isCompleted'], isFalse);
    });

    test('completing and updating sets automatically saves progress to device storage', () async {
      final repo = WorkoutRepository(httpClient: MockClient((_) async => http.Response('{}', 200)));
      repo.startSession(repo.adminSessions.first);

      // Log set 1: 85kg x 10 reps
      repo.updateSetActual(
        exerciseIndex: 0,
        setIndex: 0,
        weight: 85.0,
        reps: 10,
        rpe: 8.5,
        rir: 1,
      );

      // Mark set 1 complete
      repo.completeSet(exerciseIndex: 0, setIndex: 0);

      expect(repo.activeSession.exercises[0].sets[0].isCompleted, isTrue);
      expect(repo.activeSession.exercises[0].sets[0].actualWeight, equals(85.0));
      expect(repo.activeSession.exercises[0].sets[0].actualReps, equals(10));

      final prefs = await SharedPreferences.getInstance();
      final savedActiveRaw = prefs.getString('alpha_x_workout_active_session_state');
      final decoded = jsonDecode(savedActiveRaw!) as Map<String, dynamic>;
      final exercises = decoded['exercises'] as List<dynamic>;
      final firstSet = exercises[0]['sets'][0] as Map<String, dynamic>;

      expect(firstSet['isCompleted'], isTrue);
      expect(firstSet['actualWeight'], equals(85.0));
      expect(firstSet['actualReps'], equals(10));
    });

    test('cold start restores active in-progress workout with all logged sets intact', () async {
      // 1. First session simulates user logging sets in a gym basement before phone restarts
      final repo1 = WorkoutRepository(httpClient: MockClient((_) async => http.Response('{}', 200)));
      repo1.startSession(repo1.adminSessions.first);
      repo1.updateSetActual(
        exerciseIndex: 0,
        setIndex: 0,
        weight: 100.0,
        reps: 6,
      );
      repo1.completeSet(exerciseIndex: 0, setIndex: 0);
      await repo1.saveActiveSessionToLocalStorage(elapsedSeconds: 1540);

      // 2. Second repository instance simulates app restart / reopening
      final repo2 = WorkoutRepository(httpClient: MockClient((_) async => http.Response('{}', 200)));
      // Allow async SharedPreferences load to complete
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(repo2.hasActiveSavedSession, isTrue);
      expect(repo2.activeSession.exercises[0].sets[0].isCompleted, isTrue);
      expect(repo2.activeSession.exercises[0].sets[0].actualWeight, equals(100.0));
      expect(repo2.activeSession.exercises[0].sets[0].actualReps, equals(6));

      final savedDuration = await repo2.getSavedActiveSessionDuration();
      expect(savedDuration, equals(1540));
    });

    test('completing workout clears active session from local storage and queues record for backend sync', () async {
      bool backendCalled = false;
      final mockClient = MockClient((request) async {
        backendCalled = true;
        // Simulate network failure in gym basement
        return http.Response('No Internet', 503);
      });

      final repo = WorkoutRepository(httpClient: mockClient);
      repo.startSession(repo.adminSessions.first);
      repo.completeSet(exerciseIndex: 0, setIndex: 0);

      expect(repo.hasActiveSavedSession, isTrue);

      final record = repo.completeWorkout(durationSeconds: 2400, notes: 'Basement PR session');
      expect(record.isCompleted, isTrue);
      expect(repo.hasActiveSavedSession, isFalse);

      // Active session storage is cleared
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('alpha_x_workout_active_session_state'), isNull);

      // Wait for async fire-and-forget sync to process network response
      await Future<void>.delayed(const Duration(milliseconds: 60));

      // Offline pending queue retains record
      expect(repo.pendingSyncCount, greaterThanOrEqualTo(1));
      expect(repo.pendingSyncRecords.any((r) => r.id == record.id), isTrue);
      expect(backendCalled, isTrue);
    });

    test('discardActiveSession wipes active progress cleanly upon user request', () async {
      final repo = WorkoutRepository(httpClient: MockClient((_) async => http.Response('{}', 200)));
      repo.startSession(repo.adminSessions.first);
      expect(repo.hasActiveSavedSession, isTrue);

      await repo.discardActiveSession();

      expect(repo.hasActiveSavedSession, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('alpha_x_workout_active_session_state'), isNull);
    });
  });
}
