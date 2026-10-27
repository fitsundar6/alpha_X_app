import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/core/constants/user_role.dart';
import 'package:alpha_x_gym/core/utils/ist_date_utils.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/workout/domain/models/workout_models.dart';
import 'package:alpha_x_gym/features/workout/presentation/client/client_workout_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IstDateUtils.resetDateProviderForTesting();
  });

  tearDown(() {
    IstDateUtils.resetDateProviderForTesting();
  });

  group('Alpha X Gym — Client Daily Workout Schedule & Pending Workouts UI/Unit Tests', () {
    late WorkoutRepository repo;
    late AuthService auth;

    final pushSession = WorkoutSession(
      id: 'ws_push_mon',
      title: 'Push A — Chest & Triceps',
      workoutType: 'Strength',
      targetMuscleGroup: 'Chest • Shoulders • Triceps',
      difficulty: 'Intermediate',
      estimatedDurationMinutes: 50,
      isActive: true,
      recurringSchedule: 'Monday',
      trainingDays: const [1], // Monday
      exercises: [
        const WorkoutExercise(
          id: 'we_bench',
          exerciseId: 'ex_bench',
          exerciseName: 'Barbell Bench Press',
          category: 'Chest',
          primaryMusclesDisplay: 'Chest',
          secondaryMusclesDisplay: 'Front Delts • Triceps',
          trainerNote: 'Control eccentric',
          sets: [
            ExerciseSet(id: 's1', setNumber: 1, targetRepsMin: 8, targetRepsMax: 10, targetWeight: 80),
          ],
        ),
      ],
    );

    final pullSession = WorkoutSession(
      id: 'ws_pull_tue',
      title: 'Pull A — Back & Biceps',
      workoutType: 'Hypertrophy',
      targetMuscleGroup: 'Back • Biceps',
      difficulty: 'Intermediate',
      estimatedDurationMinutes: 55,
      isActive: true,
      recurringSchedule: 'Tuesday',
      trainingDays: const [2], // Tuesday
      exercises: [
        const WorkoutExercise(
          id: 'we_row',
          exerciseId: 'ex_row',
          exerciseName: 'Bent-Over Row',
          category: 'Back',
          primaryMusclesDisplay: 'Back',
          secondaryMusclesDisplay: 'Biceps',
          trainerNote: 'Squeeze lats',
          sets: [
            ExerciseSet(id: 's2', setNumber: 1, targetRepsMin: 8, targetRepsMax: 10, targetWeight: 70),
          ],
        ),
      ],
    );

    final legsSession = WorkoutSession(
      id: 'ws_legs_wed',
      title: 'Legs A — Quads & Core',
      workoutType: 'Strength',
      targetMuscleGroup: 'Quads • Hamstrings',
      difficulty: 'Advanced',
      estimatedDurationMinutes: 60,
      isActive: true,
      recurringSchedule: 'Wednesday',
      trainingDays: const [3], // Wednesday
      exercises: [
        const WorkoutExercise(
          id: 'we_squat',
          exerciseId: 'ex_squat',
          exerciseName: 'Back Squat',
          category: 'Legs',
          primaryMusclesDisplay: 'Legs',
          secondaryMusclesDisplay: 'Glutes',
          trainerNote: 'Full depth',
          sets: [
            ExerciseSet(id: 's3', setNumber: 1, targetRepsMin: 6, targetRepsMax: 8, targetWeight: 100),
          ],
        ),
      ],
    );

    setUp(() {
      auth = AuthService();
      auth.setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'aravind@alphax.test',
        userId: 'client_test_aravind',
      );

      final client = MockClient((request) async {
        return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
      });

      repo = WorkoutRepository(httpClient: client);
    });

    test('1. Repository correctly isolates today\'s workout based on IST day', () async {
      // Tuesday Oct 13, 2026
      IstDateUtils.setDateProviderForTesting(() => DateTime.utc(2026, 10, 13, 4, 30));

      await repo.createSession(pushSession);
      await repo.createSession(pullSession);
      await repo.createSession(legsSession);

      await repo.assignSession(
        sessionId: pushSession.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: 'client_test_aravind',
        scheduledDate: '2026-10-12',
        isRecommended: false,
      );
      await repo.assignSession(
        sessionId: pullSession.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: 'client_test_aravind',
        scheduledDate: '2026-10-13',
        isRecommended: true,
      );
      await repo.assignSession(
        sessionId: legsSession.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: 'client_test_aravind',
        scheduledDate: '2026-10-14',
        isRecommended: false,
      );

      final today = repo.getTodaySessionForClient('client_test_aravind');
      expect(today, isNotNull);
      expect(today!.id, equals(pullSession.id));
      expect(today.title, equals('Pull A — Back & Biceps'));
    });

    test('2. Missed Monday workout appears in pending workouts on Tuesday', () async {
      // Tuesday Oct 13, 2026
      IstDateUtils.setDateProviderForTesting(() => DateTime.utc(2026, 10, 13, 4, 30));

      await repo.createSession(pushSession);
      await repo.createSession(pullSession);

      await repo.assignSession(
        sessionId: pushSession.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: 'client_test_aravind',
        scheduledDate: '2026-10-12',
      );
      await repo.assignSession(
        sessionId: pullSession.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: 'client_test_aravind',
        scheduledDate: '2026-10-13',
      );

      final pending = repo.getPendingWorkoutsForClient('client_test_aravind');
      expect(pending.length, equals(1));
      expect(pending.first.id, equals(pushSession.id));
      expect(pending.first.scheduledDate, equals('2026-10-12'));
    });

    test('3. Completing Monday pending workout removes it from pending without completing Tuesday', () async {
      // Tuesday Oct 13, 2026
      IstDateUtils.setDateProviderForTesting(() => DateTime.utc(2026, 10, 13, 4, 30));

      await repo.createSession(pushSession);
      await repo.createSession(pullSession);

      await repo.assignSession(
        sessionId: pushSession.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: 'client_test_aravind',
        scheduledDate: '2026-10-12',
      );
      await repo.assignSession(
        sessionId: pullSession.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: 'client_test_aravind',
        scheduledDate: '2026-10-13',
      );

      // Client opens and completes Monday's pending workout
      final mondayPending = repo.getPendingWorkoutsForClient('client_test_aravind').first;
      repo.startSession(mondayPending, clientId: 'client_test_aravind');
      final record = repo.completeWorkout();

      expect(record.sessionId, equals(pushSession.id));
      expect(record.scheduledDate, equals('2026-10-12'));

      // Pending should now be empty
      final pendingAfter = repo.getPendingWorkoutsForClient('client_test_aravind');
      expect(pendingAfter.isEmpty, isTrue);

      // Today's session (Tuesday) remains ASSIGNED and unlocked
      final todayAfter = repo.getTodaySessionForClient('client_test_aravind');
      expect(todayAfter, isNotNull);
      expect(todayAfter!.id, equals(pullSession.id));
      expect(todayAfter.isLocked, isFalse);
    });

    testWidgets('4. ClientWorkoutScreen displays Today\'s Workout and does NOT display previous days\' pending workouts', (tester) async {
      // Tuesday Oct 13, 2026
      IstDateUtils.setDateProviderForTesting(() => DateTime.utc(2026, 10, 13, 4, 30));

      final client = MockClient((request) async {
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'success': true,
            'data': {
              'todaySession': pullSession.copyWith(isRecommended: true).toJson(),
              'pendingWorkouts': [pushSession.copyWith(scheduledDate: '2026-10-12').toJson()],
              'available': [pullSession.toJson()],
              'isRestDay': false,
            }
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final testRepo = WorkoutRepository(httpClient: client);
      await testRepo.fetchClientWorkouts();

      await tester.pumpWidget(
        MaterialApp(
          home: ClientWorkoutScreen(
            workoutRepository: testRepo,
            showAppBar: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Today's workout hero section is rendered
      expect(find.text("⭐ TODAY'S WORKOUT"), findsOneWidget);
      expect(find.text('Pull A — Back & Biceps'), findsOneWidget);

      // Check previous days' pending workouts are NOT shown in the client workout session screen
      expect(find.textContaining('PENDING WORKOUTS'), findsNothing);
      expect(find.text('Push A — Chest & Triceps'), findsNothing);
      expect(find.text('START PENDING WORKOUT'), findsNothing);

      // Verify pending workouts are preserved safely in repository/backend
      final pendingInRepo = testRepo.getPendingWorkoutsForClient('client_test_aravind');
      expect(pendingInRepo.isNotEmpty, isTrue);
      expect(pendingInRepo.first.id, equals(pushSession.id));
    });

    testWidgets('5. ClientWorkoutScreen displays Rest Day card when today has no workout scheduled', (tester) async {
      // Thursday Oct 15, 2026 (Rest day for PPL)
      IstDateUtils.setDateProviderForTesting(() => DateTime.utc(2026, 10, 15, 4, 30));

      final client = MockClient((request) async {
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'success': true,
            'data': {
              'todaySession': null,
              'pendingWorkouts': [pushSession.copyWith(scheduledDate: '2026-10-12').toJson()],
              'available': [],
              'isRestDay': true,
            }
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final testRepo = WorkoutRepository(httpClient: client);
      await testRepo.fetchClientWorkouts();

      await tester.pumpWidget(
        MaterialApp(
          home: ClientWorkoutScreen(
            workoutRepository: testRepo,
            showAppBar: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Rest Day recovery banner is displayed
      expect(find.text('REST & RECOVERY DAY'), findsOneWidget);
      expect(find.text('Active Recovery & Muscle Repair'), findsOneWidget);
      expect(find.textContaining('No workout scheduled for today'), findsOneWidget);
    });
  });
}
