import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/core/constants/user_role.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/core/widgets/alpha_x_logo.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/workout/domain/models/workout_models.dart';
import 'package:alpha_x_gym/features/workout/presentation/client/client_workout_completion_screen.dart';
import 'package:alpha_x_gym/features/workout/presentation/client/client_workout_execution_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WorkoutRepository workoutRepo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    workoutRepo = WorkoutRepository();
    ClientWorkoutCompletionScreen.resetLastMessageForTesting();
    AuthService().setAuthenticatedSessionForTesting(
      role: UserRole.client,
      email: 'alex.athlete@alphax.com',
      userName: 'Alex Athlete',
      clientId: 'AXG-0081',
      onboardingCompleted: true,
    );
  });

  WorkoutRecord createMockRecord({
    String id = 'rec_test_1',
    String clientId = 'AXG-0081',
    String title = 'Hypertrophy Phase 2 • Week 4 Day 2',
  }) {
    return WorkoutRecord(
      id: id,
      clientId: clientId,
      sessionId: 'ws_test_1',
      sessionTitle: title,
      workoutType: 'Hypertrophy',
      targetMuscleGroup: 'Chest & Shoulders',
      startedAt: DateTime(2026, 10, 9, 8, 0),
      completedAt: DateTime(2026, 10, 9, 9, 15),
      durationSeconds: 4500,
      totalVolume: 8450.0,
      completedSetsCount: 6,
      skippedSetsCount: 0,
      isCompleted: true,
      exercises: [
        WorkoutExercise(
          id: 'we_1',
          exerciseId: 'ex_barbell_bench_press',
          exerciseName: 'Barbell Bench Press',
          category: 'Chest',
          primaryMusclesDisplay: 'Chest',
          secondaryMusclesDisplay: 'Triceps',
          trainerNote: '',
          sets: [
            ExerciseSet(
              id: 's_1',
              setNumber: 1,
              targetWeight: 80.0,
              targetRepsMin: 10,
              targetRepsMax: 12,
              actualWeight: 80.0,
              actualReps: 10,
              isCompleted: true,
            ),
          ],
        ),
      ],
    );
  }

  WorkoutSession createTestSession() {
    return WorkoutSession(
      id: 'session_flow_test',
      title: 'Chest & Delts Hypertrophy',
      workoutType: 'Hypertrophy',
      targetMuscleGroup: 'Chest',
      difficulty: 'Intermediate',
      estimatedDurationMinutes: 45,
      description: 'Test workout session',
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
          trainerNote: 'Arch upper back and brace core',
          tempo: '3-1-1-0',
          restSeconds: 90,
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
          ],
        ),
      ],
    );
  }

  group('Curated Motivational Fitness Messages & Selection Algorithm', () {
    test('Curated list contains all required short powerful messages', () {
      final messages = ClientWorkoutCompletionScreen.motivationalMessages;
      expect(messages.length, greaterThanOrEqualTo(10));
      expect(messages, contains('Beast Mode Activated!'));
      expect(messages, contains('Another Step Closer to Your Goal!'));
      expect(messages, contains('You Showed Up. You Won!'));
      expect(messages, contains('Discipline Beats Motivation!'));
      expect(messages, contains('Stronger Than Yesterday!'));
      expect(messages, contains('Champions Are Built, Not Born!'));
      expect(messages, contains('One Workout. One Step Forward!'));
      expect(messages, contains('Your Future Self Thanks You!'));
      expect(messages, contains('Progress Over Perfection!'));
      expect(messages, contains('You Earned This Victory!'));
    });

    test('Selection algorithm changes every time and avoids immediately previous message', () {
      ClientWorkoutCompletionScreen.resetLastMessageForTesting();
      String? prev;
      for (int i = 0; i < 50; i++) {
        final current = ClientWorkoutCompletionScreen.selectNextMotivationalMessage();
        expect(ClientWorkoutCompletionScreen.motivationalMessages, contains(current));
        if (prev != null) {
          expect(current, isNot(equals(prev)),
              reason: 'Selected message should not repeat immediately consecutive predecessor at iteration $i');
        }
        prev = current;
      }
    });

    test('selectNextMotivationalMessage with explicit previousMessage excludes it', () {
      const explicitPrev = 'Beast Mode Activated!';
      for (int i = 0; i < 20; i++) {
        final current = ClientWorkoutCompletionScreen.selectNextMotivationalMessage(
          previousMessage: explicitPrev,
        );
        expect(current, isNot(equals(explicitPrev)));
      }
    });
  });

  group('Simplified Workout Completion Screen UI & Aesthetics', () {
    testWidgets('1. Shows only ONE motivational message and zero detailed summary statistics', (tester) async {
      final record = createMockRecord();

      await tester.pumpWidget(
        MaterialApp(
          home: ClientWorkoutCompletionScreen(
            workoutRepository: workoutRepo,
            completedRecord: record,
            durationSeconds: 4500,
            motivationalMessage: 'Discipline Beats Motivation!',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Only one motivational message prominently in the center
      expect(find.byKey(const ValueKey('completion_motivational_message')), findsOneWidget);
      expect(find.text('Discipline Beats Motivation!'), findsOneWidget);

      // Category and branding
      expect(find.text('WORKOUT COMPLETED'), findsOneWidget);
      expect(find.text('ALPHA X GYM'), findsOneWidget);
      expect(find.byType(AlphaXLogo), findsWidgets);
      expect(find.byIcon(Icons.emoji_events_rounded), findsOneWidget);

      // Verify removal of detailed metrics: NO muscle groups or anatomical muscle map
      expect(find.text('Trained Muscle Groups:'), findsNothing);
      expect(find.text('MUSCLE LOAD DISTRIBUTION'), findsNothing);
      expect(find.text('Chest'), findsNothing);
      expect(find.text('Shoulders'), findsNothing);

      // Verify removal of detailed exercise lists, sets, reps, weights, volume
      expect(find.text('EXERCISES DONE'), findsNothing);
      expect(find.text('Barbell Bench Press'), findsNothing);
      expect(find.text('VOLUME LIFTED'), findsNothing);
      expect(find.text('COMPLETED SETS'), findsNothing);
      expect(find.text('TOTAL REPS'), findsNothing);
      expect(find.text('PERFORMANCE SUMMARY'), findsNothing);

      // Verify removal of multi-page carousel, PageView, stories, save, share
      expect(find.byType(PageView), findsNothing);
      expect(find.text('Stories'), findsNothing);
      expect(find.text('Save'), findsNothing);
      expect(find.text('Save All'), findsNothing);
      expect(find.text('Share'), findsNothing);
      expect(find.text('Text'), findsNothing);
    });

    testWidgets('2. Displays different motivational message across consecutive completions', (tester) async {
      ClientWorkoutCompletionScreen.setLastMessageForTesting('Champions Are Built, Not Born!');
      final record = createMockRecord();

      await tester.pumpWidget(
        MaterialApp(
          home: ClientWorkoutCompletionScreen(
            key: const ValueKey('completion_screen_instance_1'),
            workoutRepository: workoutRepo,
            completedRecord: record,
            durationSeconds: 3600,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final firstScreenFinder = find.byKey(const ValueKey('completion_motivational_message'));
      expect(firstScreenFinder, findsOneWidget);
      final firstText = (tester.widget(firstScreenFinder) as Text).data!;
      expect(firstText, isNot(equals('Champions Are Built, Not Born!')));

      // Now create another completion screen and ensure consecutive difference
      await tester.pumpWidget(
        MaterialApp(
          home: ClientWorkoutCompletionScreen(
            key: const ValueKey('completion_screen_instance_2'),
            workoutRepository: workoutRepo,
            completedRecord: record,
            durationSeconds: 3600,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final secondScreenFinder = find.byKey(const ValueKey('completion_motivational_message'));
      final secondText = (tester.widget(secondScreenFinder) as Text).data!;
      expect(secondText, isNot(equals(firstText)));
    });

    testWidgets('3. One simple action to return to dashboard without duplicating history', (tester) async {
      final record = createMockRecord();
      workoutRepo.addCompletedRecordForTesting(record);
      final initialCount = workoutRepo.workoutHistory.length;

      bool didPop = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Navigator(
            onPopPage: (route, result) {
              didPop = true;
              return route.didPop(result);
            },
            pages: [
              const MaterialPage(child: Scaffold(body: Text('Client Dashboard Screen'))),
              MaterialPage(
                child: ClientWorkoutCompletionScreen(
                  workoutRepository: workoutRepo,
                  completedRecord: record,
                  durationSeconds: 4500,
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Button exists and provides simple action
      final button = find.byKey(const ValueKey('completion_done_button'));
      expect(button, findsOneWidget);
      expect(find.text('Return to Dashboard'), findsOneWidget);

      // Also backwards compatible with completion_done_button_top key
      expect(find.byKey(const ValueKey('completion_done_button_top')), findsOneWidget);

      // Tap action
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(didPop, isTrue);
      expect(workoutRepo.workoutHistory.length, equals(initialCount));
    });

    testWidgets('4. Prevents duplicate completion actions on rapid taps', (tester) async {
      final record = createMockRecord();
      workoutRepo.addCompletedRecordForTesting(record);
      int popCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Navigator(
            onPopPage: (route, result) {
              popCount++;
              return route.didPop(result);
            },
            pages: [
              const MaterialPage(child: Scaffold(body: Text('Client Dashboard Screen'))),
              MaterialPage(
                child: ClientWorkoutCompletionScreen(
                  workoutRepository: workoutRepo,
                  completedRecord: record,
                  durationSeconds: 4500,
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final button = find.byKey(const ValueKey('completion_done_button'));

      // Rapidly tap multiple times
      await tester.tap(button);
      await tester.tap(button, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(popCount, equals(1));
    });
  });

  group('Full Flow Integration Test', () {
    testWidgets('Full flow: start workout -> complete all required sets -> finish workout -> display motivational message -> return to dashboard', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final session = createTestSession();
      workoutRepo.startSession(session, clientId: 'AXG-0081');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const ValueKey('start_workout_button'),
                onPressed: () {
                  Navigator.of(ctx).push(
                    MaterialPageRoute(
                      builder: (c) => ClientWorkoutExecutionScreen(
                        workoutRepository: workoutRepo,
                        session: session,
                      ),
                    ),
                  );
                },
                child: const Text('Start Workout'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Start Workout
      await tester.tap(find.byKey(const ValueKey('start_workout_button')));
      await tester.pumpAndSettle();

      expect(find.byType(ClientWorkoutExecutionScreen), findsOneWidget);

      // 2. Complete all required exercises/sets
      final set1Checkbox = find.byKey(const ValueKey('set_checkbox_0_0'));
      final set2Checkbox = find.byKey(const ValueKey('set_checkbox_0_1'));

      await tester.tap(set1Checkbox);
      await tester.pumpAndSettle();

      await tester.tap(set2Checkbox);
      await tester.pumpAndSettle();

      expect(workoutRepo.activeSession.exercises[0].isAllSetsCompleted, isTrue);

      // 3. Finish Workout via header Finish button pill
      final finishPill = find.text('Finish');
      expect(finishPill, findsOneWidget);
      await tester.tap(finishPill);
      await tester.pumpAndSettle();

      // Finish confirmation dialog is shown
      expect(find.text('Finish Workout?'), findsOneWidget);
      final finishConfirmButton = find.text('Finish Workout');
      expect(finishConfirmButton, findsOneWidget);
      await tester.tap(finishConfirmButton);
      await tester.pumpAndSettle();

      // 4. ClientWorkoutCompletionScreen is displayed with motivational message
      expect(find.byType(ClientWorkoutCompletionScreen), findsOneWidget);

      final motivationalMsgFinder = find.byKey(const ValueKey('completion_motivational_message'));
      expect(motivationalMsgFinder, findsOneWidget);

      final msgText = (tester.widget(motivationalMsgFinder) as Text).data!;
      expect(ClientWorkoutCompletionScreen.motivationalMessages, contains(msgText));

      // Detailed summaries are not displayed
      expect(find.text('Trained Muscle Groups:'), findsNothing);
      expect(find.text('MUSCLE LOAD DISTRIBUTION'), findsNothing);
      expect(find.text('VOLUME LIFTED'), findsNothing);
      expect(find.text('COMPLETED SETS'), findsNothing);
      expect(find.byType(PageView), findsNothing);

      // 5. Return to Dashboard
      final returnButton = find.byKey(const ValueKey('completion_done_button'));
      expect(returnButton, findsOneWidget);
      await tester.tap(returnButton);
      await tester.pumpAndSettle();

      // Returned to dashboard
      expect(find.byType(ClientWorkoutCompletionScreen), findsNothing);
      expect(find.byKey(const ValueKey('start_workout_button')), findsOneWidget);

      // Workout record is saved in history
      expect(workoutRepo.workoutHistory, isNotEmpty);
      expect(workoutRepo.workoutHistory.first.isCompleted, isTrue);
    });
  });
}
