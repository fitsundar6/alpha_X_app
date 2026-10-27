import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/core/constants/user_role.dart';
import 'package:alpha_x_gym/core/utils/ist_date_utils.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/workout/domain/models/workout_models.dart';
import 'package:alpha_x_gym/features/macro_planner/data/repositories/macro_repository.dart';
import 'package:alpha_x_gym/features/dashboard/admin_client_detail_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Ralph Loop: Admin Release Locked Workout Session Tests', () {
    late WorkoutRepository repo;
    late AuthService auth;

    final todayDate = IstDateUtils.getTodayISTString();
    final yesterdayDate = IstDateUtils.toISTDateString(
      IstDateUtils.nowInIST().subtract(const Duration(days: 1)),
    );

    final pushWorkout = WorkoutSession(
      id: 'ws_push_day_1',
      title: 'Push Day A (Chest & Triceps)',
      workoutType: 'Hypertrophy',
      targetMuscleGroup: 'Chest',
      difficulty: 'Intermediate',
      estimatedDurationMinutes: 50,
      isActive: true,
      exercises: [
        const WorkoutExercise(
          id: 'we_bench',
          exerciseId: 'ex_bench_press',
          exerciseName: 'Barbell Flat Bench Press',
          category: 'Chest',
          primaryMusclesDisplay: 'Chest',
          secondaryMusclesDisplay: 'Triceps',
          trainerNote: '4 sets heavy',
          sets: [
            ExerciseSet(id: 's_p1', setNumber: 1, targetRepsMin: 8, targetRepsMax: 10, targetRpe: 8.0, targetWeight: 80.0),
            ExerciseSet(id: 's_p2', setNumber: 2, targetRepsMin: 8, targetRepsMax: 10, targetRpe: 8.0, targetWeight: 80.0),
          ],
        ),
      ],
    );

    final pullWorkout = WorkoutSession(
      id: 'ws_pull_day_2',
      title: 'Pull Day B (Back & Biceps)',
      workoutType: 'Strength',
      targetMuscleGroup: 'Back',
      difficulty: 'Advanced',
      estimatedDurationMinutes: 55,
      isActive: true,
      exercises: [
        const WorkoutExercise(
          id: 'we_lat',
          exerciseId: 'ex_lat_pulldown',
          exerciseName: 'Lat Pulldown',
          category: 'Back',
          primaryMusclesDisplay: 'Lats',
          secondaryMusclesDisplay: 'Biceps',
          trainerNote: 'Strict form',
          sets: [
            ExerciseSet(id: 's_l1', setNumber: 1, targetRepsMin: 10, targetRepsMax: 12, targetRpe: 8.0, targetWeight: 65.0),
          ],
        ),
      ],
    );

    setUp(() {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/workout/admin/unlock-session')) {
          final body = jsonDecode(request.body);
          return http.Response(
            jsonEncode({
              'success': true,
              'message': 'Workout session successfully unlocked by administrator.',
              'data': {
                'recordId': body['recordId'],
                'adminId': body['adminId'],
                'reason': body['reason'],
                'unlockedAt': DateTime.now().toIso8601String(),
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (request.url.path.contains('workout-history')) {
          final segments = request.url.pathSegments;
          final cId = segments.contains('clients') && segments.indexOf('clients') + 1 < segments.length
              ? segments[segments.indexOf('clients') + 1]
              : '';
          final list = repo.getClientWorkoutHistory(cId);
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'history': list.map((r) => r.toJson()).toList(),
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response(
          jsonEncode({'success': true, 'data': {}}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      auth = AuthService();
      auth.setHttpClientForTesting(mockClient);

      repo = WorkoutRepository(httpClient: mockClient);
      repo.createSession(pushWorkout);
      repo.createSession(pullWorkout);
    });

    test('1. Accidental Completion Lock: Session is automatically completed and locked', () async {
      const clientId = 'client_athlete_1';
      await repo.assignSession(
        sessionId: pushWorkout.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: clientId,
        scheduledDate: todayDate,
      );

      // Client starts session
      repo.startSession(pushWorkout, clientId: clientId);
      expect(repo.hasActiveSavedSession, true);
      expect(repo.activeSession.isLocked, false);

      // Client performs 1 set
      repo.updateSetActual(exerciseIndex: 0, setIndex: 0, weight: 80.0, reps: 10);
      repo.completeSet(exerciseIndex: 0, setIndex: 0);

      // Client accidentally completes workout prematurely
      final completedRecord = repo.completeWorkout(durationSeconds: 300);
      expect(completedRecord.isCompleted, true);
      expect(completedRecord.isLocked, true);

      // Session is now locked for client
      final todaySession = repo.getTodaySessionForClient(clientId);
      expect(todaySession, isNotNull);
      expect(todaySession!.isLocked, true);
      expect(todaySession.status, 'COMPLETED');

      // Attempting to restart locked session is blocked
      repo.startSession(pushWorkout, clientId: clientId);
      // Active session should not be active since it was completed and locked
      expect(repo.hasActiveSavedSession, false);
    });

    test('2. Admin Release/Unlock: Authorized admin releases locked session with audit trail', () async {
      const clientId = 'client_athlete_1';
      const adminId = 'admin_coach_alpha';
      const unlockReason = 'Client accidentally clicked complete workout on set 1. Released to continue.';

      await repo.assignSession(
        sessionId: pushWorkout.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: clientId,
        scheduledDate: todayDate,
      );

      repo.startSession(pushWorkout, clientId: clientId);
      repo.updateSetActual(exerciseIndex: 0, setIndex: 0, weight: 80.0, reps: 10);
      repo.completeSet(exerciseIndex: 0, setIndex: 0);
      final lockedRecord = repo.completeWorkout(durationSeconds: 300);
      expect(lockedRecord.isLocked, true);

      // Admin unlocks session
      final unlockSuccess = await repo.unlockSession(
        recordId: lockedRecord.id,
        adminId: adminId,
        reason: unlockReason,
        reopenSession: true,
        clientId: clientId,
        sessionId: pushWorkout.id,
      );
      expect(unlockSuccess, true);

      // Verify audit persistence on the record
      final clientHistory = repo.getClientWorkoutHistory(clientId);
      final unlockedRecord = clientHistory.firstWhere((r) => r.id == lockedRecord.id);
      expect(unlockedRecord.isLocked, false);
      expect(unlockedRecord.unlockedAt, isNotNull);
      expect(unlockedRecord.unlockedById, adminId);
      expect(unlockedRecord.unlockReason, unlockReason);
      // Historical sets are fully preserved
      expect(unlockedRecord.exercises[0].sets[0].actualWeight, 80.0);
    });

    test('3. Client Access Restoration: Client can access, resume, and modify the released session', () async {
      const clientId = 'client_athlete_1';
      const adminId = 'admin_coach_alpha';

      await repo.assignSession(
        sessionId: pushWorkout.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: clientId,
        scheduledDate: todayDate,
      );

      repo.startSession(pushWorkout, clientId: clientId);
      repo.updateSetActual(exerciseIndex: 0, setIndex: 0, weight: 80.0, reps: 10);
      repo.completeSet(exerciseIndex: 0, setIndex: 0);
      final lockedRecord = repo.completeWorkout(durationSeconds: 300);

      // Admin unlocks
      await repo.unlockSession(
        recordId: lockedRecord.id,
        adminId: adminId,
        reason: 'Correction of workout',
        reopenSession: true,
        clientId: clientId,
        sessionId: pushWorkout.id,
      );

      // Client queries today's session again
      final todaySession = repo.getTodaySessionForClient(clientId);
      expect(todaySession, isNotNull);
      expect(todaySession!.isLocked, false);
      expect(todaySession.status, 'IN_PROGRESS');

      // Client active session is restored and accessible
      expect(repo.hasActiveSavedSession, true);
      expect(repo.activeSession.isLocked, false);

      // Client can log next set successfully
      repo.updateSetActual(exerciseIndex: 0, setIndex: 1, weight: 85.0, reps: 8);
      repo.completeSet(exerciseIndex: 0, setIndex: 1);
      expect(repo.activeSession.exercises[0].sets[1].actualWeight, 85.0);
      expect(repo.activeSession.exercises[0].sets[1].actualReps, 8);
      expect(repo.activeSession.exercises[0].sets[1].isCompleted, true);

      // Client finishes workout properly; automatic locking re-engages
      final finalCompleted = repo.completeWorkout(durationSeconds: 2400);
      expect(finalCompleted.isCompleted, true);
      expect(finalCompleted.isLocked, true);
      expect(repo.getTodaySessionForClient(clientId)!.isLocked, true);
    });

    test('4. Session Isolation: Releasing one session does NOT unlock other sessions or clients', () async {
      const client1 = 'client_athlete_1';
      const client2 = 'client_athlete_2';
      const adminId = 'admin_coach_alpha';

      // Client 1 completed yesterday's workout
      await repo.assignSession(
        sessionId: pushWorkout.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: client1,
        scheduledDate: yesterdayDate,
      );
      repo.startSession(pushWorkout, clientId: client1);
      final client1Record = repo.completeWorkout(durationSeconds: 1800);
      expect(client1Record.isLocked, true);

      // Client 2 completed today's workout
      await repo.assignSession(
        sessionId: pullWorkout.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: client2,
        scheduledDate: todayDate,
      );
      repo.startSession(pullWorkout, clientId: client2);
      final client2Record = repo.completeWorkout(durationSeconds: 2000);
      expect(client2Record.isLocked, true);

      // Admin unlocks ONLY Client 1's workout
      final unlockRes = await repo.unlockSession(
        recordId: client1Record.id,
        adminId: adminId,
        reason: 'Client 1 correction',
        clientId: client1,
        sessionId: pushWorkout.id,
      );
      expect(unlockRes, true);

      // Client 1 record is unlocked
      final c1History = repo.getClientWorkoutHistory(client1);
      expect(c1History.firstWhere((r) => r.id == client1Record.id).isLocked, false);

      // Client 2 record MUST REMAIN LOCKED
      final c2History = repo.getClientWorkoutHistory(client2);
      expect(c2History.firstWhere((r) => r.id == client2Record.id).isLocked, true);
    });

    testWidgets('5. Admin UI Integration: Locked session displays Release/Unlock option and dialog works', (tester) async {
      const clientId = 'client_athlete_ui_test';
      const clientName = 'Rahul Sharma';

      // 1. Athlete Member session
      auth.setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'athlete@alphaxgym.com',
        userId: clientId,
      );

      // Create and complete workout for client
      await repo.assignSession(
        sessionId: pushWorkout.id,
        assignmentType: 'INDIVIDUAL',
        individualClientId: clientId,
        scheduledDate: todayDate,
      );
      repo.startSession(pushWorkout, clientId: clientId);
      repo.updateSetActual(exerciseIndex: 0, setIndex: 0, weight: 80.0, reps: 10);
      repo.completeSet(exerciseIndex: 0, setIndex: 0);
      final lockedRecord = repo.completeWorkout(durationSeconds: 300);
      expect(lockedRecord.isLocked, true);
      expect(lockedRecord.clientId, clientId);

      // 2. Coach / Admin logs in to Admin Client Hub
      auth.setAuthenticatedSessionForTesting(
        role: UserRole.admin,
        email: 'admin@alphaxgym.com',
        userId: 'admin_test_1',
      );

      // Pump AdminClientDetailScreen
      final clientMap = {
        'id': clientId,
        'clientId': 'AXG-0088',
        'name': clientName,
        'status': 'APPROVED',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: AdminClientDetailScreen(
            client: clientMap,
            workoutRepository: repo,
            macroRepository: MacroRepository.clean(),
            initialTabIndex: 1, // WORKOUT tab
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the workout record title
      expect(find.text(lockedRecord.sessionTitle), findsOneWidget);

      // Tap on the ExpansionTile to expand the record details
      await tester.tap(find.text(lockedRecord.sessionTitle));
      await tester.pumpAndSettle();

      // Verify the Locked Session banner and Release/Unlock button are visible
      expect(find.text('Session Locked & Completed'), findsOneWidget);
      final unlockBtn = find.byKey(const Key('admin_release_unlock_button'));
      expect(unlockBtn, findsOneWidget);

      // Tap "Release / Unlock"
      await tester.tap(unlockBtn);
      await tester.pumpAndSettle();

      // Verify the dialog appeared
      expect(find.text('Release & Unlock Session'), findsOneWidget);
      expect(find.text('Confirm Release'), findsOneWidget);

      // Tap "Confirm Release"
      await tester.tap(find.text('Confirm Release'));
      await tester.pumpAndSettle();

      // Verify SnackBar with success message is displayed
      expect(find.text('Session "${lockedRecord.sessionTitle}" released and unlocked for $clientName.'), findsOneWidget);

      // Verify the record is now unlocked in repository
      final updatedHistory = repo.getClientWorkoutHistory(clientId);
      expect(updatedHistory.firstWhere((r) => r.id == lockedRecord.id).isLocked, false);
    });
  });
}
