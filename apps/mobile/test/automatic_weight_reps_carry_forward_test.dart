import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/core/constants/app_constants.dart';
import 'package:alpha_x_gym/core/constants/user_role.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/features/workout/domain/models/workout_models.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/workout/presentation/client/client_workout_execution_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WorkoutRepository repository;
  late List<Map<String, dynamic>> capturedBackendCalls;

  WorkoutSession createMultiExerciseSession() {
    return WorkoutSession(
      id: 'ws_carry_forward_test',
      title: 'Strength Progression Session',
      workoutType: 'Hypertrophy',
      targetMuscleGroup: 'Chest • Biceps',
      difficulty: 'Intermediate',
      estimatedDurationMinutes: 60,
      description: 'Carry forward test workout',
      isActive: true,
      availabilityType: 'INDIVIDUAL',
      exercises: [
        WorkoutExercise(
          id: 'ex_bench',
          exerciseId: 'ex_bench_press',
          exerciseName: 'Barbell Bench Press',
          category: 'Chest',
          primaryMusclesDisplay: 'Pectoralis Major',
          secondaryMusclesDisplay: 'Triceps',
          trainerNote: '',
          restSeconds: 60,
          sets: [
            const ExerciseSet(
              id: 'set_bench_1',
              setNumber: 1,
              targetWeight: 80.0,
              targetRepsMin: 8,
              targetRepsMax: 10,
              isCompleted: false,
            ),
            const ExerciseSet(
              id: 'set_bench_2',
              setNumber: 2,
              targetWeight: 80.0,
              targetRepsMin: 8,
              targetRepsMax: 10,
              isCompleted: false,
            ),
            const ExerciseSet(
              id: 'set_bench_3',
              setNumber: 3,
              targetWeight: 80.0,
              targetRepsMin: 8,
              targetRepsMax: 10,
              isCompleted: false,
            ),
            const ExerciseSet(
              id: 'set_bench_4',
              setNumber: 4,
              targetWeight: 80.0,
              targetRepsMin: 8,
              targetRepsMax: 10,
              isCompleted: false,
            ),
          ],
        ),
        WorkoutExercise(
          id: 'ex_curl',
          exerciseId: 'ex_db_curl',
          exerciseName: 'Incline Dumbbell Curl',
          category: 'Arms',
          primaryMusclesDisplay: 'Biceps Brachii',
          secondaryMusclesDisplay: 'Forearms',
          trainerNote: '',
          restSeconds: 60,
          sets: [
            const ExerciseSet(
              id: 'set_curl_1',
              setNumber: 1,
              targetWeight: 14.0,
              targetRepsMin: 10,
              targetRepsMax: 12,
              isCompleted: false,
            ),
            const ExerciseSet(
              id: 'set_curl_2',
              setNumber: 2,
              targetWeight: 14.0,
              targetRepsMin: 10,
              targetRepsMax: 12,
              isCompleted: false,
            ),
          ],
        ),
      ],
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    capturedBackendCalls = [];

    final mockClient = MockClient((request) async {
      if (request.url.path.contains('/set-completion')) {
        capturedBackendCalls.add({
          'method': request.method,
          'url': request.url.toString(),
          'body': jsonDecode(request.body),
        });
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'sessionId': 'ws_carry_forward_test',
              'exerciseId': 'ex_bench_press',
              'setNumber': 1,
              'isCompleted': true,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
    });

    repository = WorkoutRepository(httpClient: mockClient);
    AuthService().setAuthenticatedSessionForTesting(
      role: UserRole.client,
      email: 'alex@alphaxgym.com',
      userId: 'client_alex',
    );
  });

  group('Automatic Weight & Reps Carry-Forward Tests', () {
    testWidgets('1 & 8: First set initial state has empty fields with empty-field hint "-"', (tester) async {
      final session = createMultiExerciseSession();
      repository.startSession(session, clientId: 'client_alex');

      await tester.pumpWidget(
        MaterialApp(
          home: ClientWorkoutExecutionScreen(
            workoutRepository: repository,
            session: session,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find all TextFields
      final textFields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(textFields.isNotEmpty, isTrue);

      // Set 1 weight and reps fields start empty
      final set1WeightField = textFields[0];
      final set1RepsField = textFields[1];
      expect(set1WeightField.controller?.text, equals(''));
      expect(set1RepsField.controller?.text, equals(''));
      expect(set1WeightField.decoration?.hintText, equals('-'));
      expect(set1RepsField.decoration?.hintText, equals('-'));
    });

    testWidgets('1 & 5: Entering weight & reps on Set 1 shows grey placeholders on next incomplete Set 2, without altering Set 2 controller text', (tester) async {
      final session = createMultiExerciseSession();
      repository.startSession(session, clientId: 'client_alex');

      await tester.pumpWidget(
        MaterialApp(
          home: ClientWorkoutExecutionScreen(
            workoutRepository: repository,
            session: session,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Client enters 80 kg and 10 reps into Set 1
      await tester.enterText(find.byType(TextField).at(0), '80');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), '10');
      await tester.pumpAndSettle();

      // Inspect Set 2's text fields (index 2 and 3)
      final set2WeightField = tester.widget<TextField>(find.byType(TextField).at(2));
      final set2RepsField = tester.widget<TextField>(find.byType(TextField).at(3));

      // Controller text must remain empty (not saved data yet)
      expect(set2WeightField.controller?.text, equals(''));
      expect(set2RepsField.controller?.text, equals(''));

      // Placeholder hints must carry forward Set 1's values as grey suggestions
      expect(set2WeightField.decoration?.hintText, equals('80'));
      expect(set2RepsField.decoration?.hintText, equals('10'));

      // Set 3 (not the immediate next incomplete set) should not show Set 1's suggestion prematurely
      final set3WeightField = tester.widget<TextField>(find.byType(TextField).at(4));
      expect(set3WeightField.decoration?.hintText, equals('-'));
    });

    testWidgets('2: Tapping Set 2 completion tick automatically uses suggested values, saves to API and updates UI', (tester) async {
      final session = createMultiExerciseSession();
      repository.startSession(session, clientId: 'client_alex');

      await tester.pumpWidget(
        MaterialApp(
          home: ClientWorkoutExecutionScreen(
            workoutRepository: repository,
            session: session,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), '82.5');
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(1), '9');
      await tester.pump();

      // Complete Set 1
      final set1Checkbox = find.byKey(const ValueKey('set_checkbox_0_0'));
      await tester.tap(set1Checkbox);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(repository.activeSession.exercises[0].sets[0].isCompleted, isTrue);
      expect(repository.activeSession.exercises[0].sets[0].actualWeight, equals(82.5));
      expect(repository.activeSession.exercises[0].sets[0].actualReps, equals(9));

      // Now tap Set 2 completion tick without typing in Set 2
      final set2Checkbox = find.byKey(const ValueKey('set_checkbox_0_1'));
      await tester.tap(set2Checkbox);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Set 2 must be automatically completed with the suggested 82.5 kg and 9 reps
      expect(repository.activeSession.exercises[0].sets[1].isCompleted, isTrue);
      expect(repository.activeSession.exercises[0].sets[1].actualWeight, equals(82.5));
      expect(repository.activeSession.exercises[0].sets[1].actualReps, equals(9));

      // UI text controllers for Set 2 must immediately show the applied values
      final updatedWeightField = tester.widget<TextField>(find.byType(TextField).at(2));
      final updatedRepsField = tester.widget<TextField>(find.byType(TextField).at(3));
      expect(updatedWeightField.controller?.text, equals('82.5'));
      expect(updatedRepsField.controller?.text, equals('9'));

      // Verify backend sync received the completed values
      await tester.pump(const Duration(milliseconds: 50));
      expect(capturedBackendCalls.any((c) =>
        c['body']['setNumber'] == 2 &&
        c['body']['actualWeight'] == 82.5 &&
        c['body']['actualReps'] == 9 &&
        c['body']['isCompleted'] == true
      ), isTrue);
    });

    testWidgets('3: Entering different custom values preserves them and never overwrites with suggestions', (tester) async {
      final session = createMultiExerciseSession();
      repository.startSession(session, clientId: 'client_alex');

      await tester.pumpWidget(
        MaterialApp(
          home: ClientWorkoutExecutionScreen(
            workoutRepository: repository,
            session: session,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Set 1: 80kg x 10
      await tester.enterText(find.byType(TextField).at(0), '80');
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(1), '10');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('set_checkbox_0_0')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Set 2 shows suggestion 80 x 10, but client enters custom 85kg x 8 reps
      await tester.enterText(find.byType(TextField).at(2), '85');
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(3), '8');
      await tester.pump();

      // Tap Set 2 completion tick
      await tester.tap(find.byKey(const ValueKey('set_checkbox_0_1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Set 2 must save 85kg x 8, NOT the suggested 80kg x 10
      expect(repository.activeSession.exercises[0].sets[1].isCompleted, isTrue);
      expect(repository.activeSession.exercises[0].sets[1].actualWeight, equals(85.0));
      expect(repository.activeSession.exercises[0].sets[1].actualReps, equals(8));

      // And Set 3 must now suggest the updated 85kg x 8
      final set3WeightField = tester.widget<TextField>(find.byType(TextField).at(4));
      final set3RepsField = tester.widget<TextField>(find.byType(TextField).at(5));
      expect(set3WeightField.decoration?.hintText, equals('85'));
      expect(set3RepsField.decoration?.hintText, equals('8'));
    });

    testWidgets('6: History isolation: never copy carry-forward suggestions between different exercises', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final session = createMultiExerciseSession();
      repository.startSession(session, clientId: 'client_alex');

      await tester.pumpWidget(
        MaterialApp(
          home: ClientWorkoutExecutionScreen(
            workoutRepository: repository,
            session: session,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Complete Set 1 on Bench Press with 100kg x 6 reps
      await tester.enterText(find.byType(TextField).at(0), '100');
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(1), '6');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('set_checkbox_0_0')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Expand Exercise 2 (Incline Dumbbell Curl)
      final expandChevron = find.byIcon(Icons.keyboard_arrow_down_rounded);
      expect(expandChevron, findsOneWidget);
      await tester.tap(expandChevron);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Find Curl Set 1 fields (Bench Press has 4 sets = 8 TextFields, Curl Set 1 is at index 8 and 9)
      final curlSet1Weight = tester.widget<TextField>(find.byType(TextField).at(8));
      final curlSet1Reps = tester.widget<TextField>(find.byType(TextField).at(9));

      // Curl Set 1 must have EMPTY controller and '-' hint, NEVER copying Bench Press's 100kg
      expect(curlSet1Weight.controller?.text, equals(''));
      expect(curlSet1Reps.controller?.text, equals(''));
      expect(curlSet1Weight.decoration?.hintText, equals('-'));
      expect(curlSet1Reps.decoration?.hintText, equals('-'));
    });

    testWidgets('7: Untick/Edit set, preserve entered values, and prevent duplicate saves', (tester) async {
      final session = createMultiExerciseSession();
      repository.startSession(session, clientId: 'client_alex');

      await tester.pumpWidget(
        MaterialApp(
          home: ClientWorkoutExecutionScreen(
            workoutRepository: repository,
            session: session,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), '70');
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(1), '12');
      await tester.pump();

      final set1Checkbox = find.byKey(const ValueKey('set_checkbox_0_0'));
      await tester.tap(set1Checkbox);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(repository.activeSession.exercises[0].sets[0].isCompleted, isTrue);

      // Untick Set 1
      await tester.tap(set1Checkbox);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Must be incomplete, but controller text must be preserved
      expect(repository.activeSession.exercises[0].sets[0].isCompleted, isFalse);
      expect(tester.widget<TextField>(find.byType(TextField).at(0)).controller?.text, equals('70'));
      expect(tester.widget<TextField>(find.byType(TextField).at(1)).controller?.text, equals('12'));

      // Edit to 72.5kg
      await tester.enterText(find.byType(TextField).at(0), '72.5');
      await tester.pump();

      // Re-tick
      await tester.tap(set1Checkbox);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(repository.activeSession.exercises[0].sets[0].isCompleted, isTrue);
      expect(repository.activeSession.exercises[0].sets[0].actualWeight, equals(72.5));
    });

    testWidgets('8: Invalid inputs (negative, non-numeric, zero) are safely rejected from suggestions', (tester) async {
      final session = createMultiExerciseSession();
      repository.startSession(session, clientId: 'client_alex');

      await tester.pumpWidget(
        MaterialApp(
          home: ClientWorkoutExecutionScreen(
            workoutRepository: repository,
            session: session,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter zero weight and 0 reps
      await tester.enterText(find.byType(TextField).at(0), '0');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), '0');
      await tester.pumpAndSettle();

      // Set 2 must not display 0 as suggestion; fallback to '-'
      final set2WeightField = tester.widget<TextField>(find.byType(TextField).at(2));
      final set2RepsField = tester.widget<TextField>(find.byType(TextField).at(3));
      expect(set2WeightField.decoration?.hintText, equals('-'));
      expect(set2RepsField.decoration?.hintText, equals('-'));
    });
  });
}
