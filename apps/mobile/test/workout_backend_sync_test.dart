import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/activity/data/repositories/activity_repository.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Workout & Activity Backend Synchronization Tests', () {
    test('WorkoutRepository successfully syncs completed workout when backend responds 201', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/workout/client/records'));
        expect(request.headers['Authorization'], contains('Bearer'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['sessionTitle'], isNotEmpty);
        expect(body['exerciseRecords'], isNotEmpty);

        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'id': 'rec_server_123', 'isCompleted': true},
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final workoutRepo = WorkoutRepository(httpClient: mockClient);
      workoutRepo.startSession(workoutRepo.adminSessions.first);

      final record = workoutRepo.completeWorkout(notes: 'Mock backend sync test');
      expect(record.isCompleted, isTrue);

      final success = await workoutRepo.syncWorkoutRecordToBackend(record);
      expect(success, isTrue);
      expect(workoutRepo.pendingSyncRecords.isEmpty, isTrue);
    });

    test('WorkoutRepository queues record locally when backend returns error (offline guarantee)', () async {
      final failingClient = MockClient((request) async {
        return http.Response('Internal error', 500);
      });

      final workoutRepo = WorkoutRepository(httpClient: failingClient);
      workoutRepo.startSession(workoutRepo.adminSessions.first);

      final record = workoutRepo.completeWorkout(notes: 'Failing network test');
      final success = await workoutRepo.syncWorkoutRecordToBackend(record);

      expect(success, isFalse);
      expect(workoutRepo.pendingSyncRecords.any((r) => r.id == record.id), isTrue);
    });

    test('ActivityRepository updates cardio minutes and calories burned upon workout completion', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'success': true, 'data': {'syncedCount': 1}}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final activityRepo = ActivityRepository(httpClient: mockClient);
      final initialCardio = activityRepo.todayRecord.cardioMinutes;

      await activityRepo.recordCompletedWorkoutActivity(
        durationMinutes: 45,
        caloriesBurned: 420.0,
      );

      expect(activityRepo.todayRecord.cardioMinutes, equals(initialCardio + 45));
      expect(activityRepo.todayRecord.caloriesBurned, greaterThan(400.0));
    });

    test('AuthService provides valid mock client token when unauthenticated', () {
      expect(AuthService().isClient, isTrue);
      expect(AuthService().currentToken, isNotEmpty);
    });
  });
}
