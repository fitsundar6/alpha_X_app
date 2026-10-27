import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/features/workout/presentation/admin/admin_create_edit_session_screen.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/workout/domain/models/workout_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WorkoutRepository workoutRepository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({'success': true, 'data': {}}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    workoutRepository = WorkoutRepository(httpClient: mockClient);
  });

  group('Admin Manual Workout Creation UI — Workout Name Layout & Flow', () {
    testWidgets('1. Typing workout name: Field takes full horizontal width and renders text horizontally', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400); // Standard physical phone size (540dp logical width)
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminCreateEditSessionScreen(
            workoutRepository: workoutRepository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the workout title / plan title field
      final titleFieldFinder = find.widgetWithText(TextFormField, 'Plan Title *');
      expect(titleFieldFinder, findsOneWidget);

      final renderBox = tester.renderObject<RenderBox>(titleFieldFinder);
      // Ensure width is bounded and occupies available screen width (540 - 32 padding = 508)
      expect(renderBox.size.width, closeTo(508.0, 2.0));
      expect(renderBox.size.height, greaterThanOrEqualTo(48.0));

      // Enter workout name
      const testName = 'PUSH DAY — Chest & Shoulders Hypertrophy';
      await tester.enterText(titleFieldFinder, testName);
      await tester.pumpAndSettle();

      expect(find.text(testName), findsOneWidget);

      // Verify the editable text widget width
      final editableFinder = find.descendant(
        of: titleFieldFinder,
        matching: find.byType(EditableText),
      );
      expect(editableFinder, findsOneWidget);
      final editableRenderBox = tester.renderObject<RenderBox>(editableFinder);
      expect(editableRenderBox.size.width, greaterThan(400.0));
    });

    testWidgets('2. Editing workout name: Existing title is properly loaded and modifiable horizontally', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final existingSession = WorkoutSession(
        id: 'sess_edit_001',
        title: 'Initial Workout Name',
        workoutType: 'Strength',
        targetMuscleGroup: 'Chest • Triceps',
        difficulty: 'Intermediate',
        estimatedDurationMinutes: 60,
        exercises: const [
          WorkoutExercise(
            id: 'we_001',
            exerciseId: 'ex_bench',
            exerciseName: 'Flat Barbell Bench Press',
            category: 'Chest',
            primaryMusclesDisplay: 'Chest',
            secondaryMusclesDisplay: 'Triceps',
            trainerNote: 'Eccentric focus',
            sets: [
              ExerciseSet(id: 's1', setNumber: 1, targetRepsMin: 8, targetRepsMax: 10, targetRpe: 8.0, targetWeight: 60.0),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AdminCreateEditSessionScreen(
            workoutRepository: workoutRepository,
            sessionToEdit: existingSession,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify title is pre-filled
      final titleFieldFinder = find.widgetWithText(TextFormField, 'Plan Title *');
      expect(find.text('Initial Workout Name'), findsOneWidget);

      // Edit title
      const updatedName = 'Alpha Chest Dominance (Modified)';
      await tester.enterText(titleFieldFinder, updatedName);
      await tester.pumpAndSettle();

      expect(find.text(updatedName), findsOneWidget);
      final renderBox = tester.renderObject<RenderBox>(titleFieldFinder);
      expect(renderBox.size.width, closeTo(508.0, 2.0));
    });

    testWidgets('3. Saving and reopening workout name: Verifies full round-trip persistence and layout', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      WorkoutSession? savedSession;

      final initialSession = WorkoutSession(
        id: 'sess_roundtrip_001',
        title: 'Initial Plan',
        workoutType: 'Strength',
        targetMuscleGroup: 'Legs • Core',
        difficulty: 'Advanced',
        estimatedDurationMinutes: 55,
        exercises: const [
          WorkoutExercise(
            id: 'we_squat',
            exerciseId: 'ex_barbell_squat',
            exerciseName: 'Barbell Back Squat',
            category: 'Quadriceps',
            primaryMusclesDisplay: 'Quadriceps',
            secondaryMusclesDisplay: 'Glutes',
            trainerNote: 'Deep squats',
            sets: [
              ExerciseSet(id: 's1', setNumber: 1, targetRepsMin: 5, targetRepsMax: 5, targetRpe: 8.5, targetWeight: 100.0),
            ],
          ),
        ],
      );

      final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          home: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  navKey.currentState!.push(
                    MaterialPageRoute(
                      builder: (_) => AdminCreateEditSessionScreen(
                        workoutRepository: workoutRepository,
                        sessionToEdit: initialSession,
                        onSessionSaved: (session) {
                          savedSession = session;
                        },
                      ),
                    ),
                  );
                },
                child: const Text('Open Editor'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open screen
      await tester.tap(find.text('Open Editor'));
      await tester.pumpAndSettle();

      // Edit Title
      const updatedPlanName = 'Legs & Core Explosive Power Protocol';
      final titleFieldFinder = find.widgetWithText(TextFormField, 'Plan Title *');
      await tester.enterText(titleFieldFinder, updatedPlanName);
      await tester.pumpAndSettle();

      // Tap SAVE in AppBar
      final saveButton = find.widgetWithText(TextButton, 'SAVE');
      expect(saveButton, findsOneWidget);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Verify onSessionSaved callback delivered the updated session title and popped
      expect(savedSession, isNotNull);
      expect(savedSession!.title, updatedPlanName);

      // Reopening test: Launch AdminCreateEditSessionScreen with the savedSession
      navKey.currentState!.push(
        MaterialPageRoute(
          builder: (_) => AdminCreateEditSessionScreen(
            workoutRepository: workoutRepository,
            sessionToEdit: savedSession,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify reopened screen displays workout name horizontally
      expect(find.text(updatedPlanName), findsOneWidget);
      final reopenedBox = tester.renderObject<RenderBox>(find.widgetWithText(TextFormField, 'Plan Title *'));
      expect(reopenedBox.size.width, closeTo(508.0, 2.0));
      final editableBox = tester.renderObject<RenderBox>(
        find.descendant(of: find.widgetWithText(TextFormField, 'Plan Title *'), matching: find.byType(EditableText)),
      );
      expect(editableBox.size.width, greaterThan(400.0));
    });

    testWidgets('4. Split Mode Day Switching: Preserves workout name horizontally across days', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminCreateEditSessionScreen(
            workoutRepository: workoutRepository,
            startInSplitMode: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // In split mode, title field defaults to Monday's title
      final titleFieldFinder = find.widgetWithText(TextFormField, 'Plan Title *');
      expect(titleFieldFinder, findsOneWidget);

      const monCustomTitle = 'Alpha Monday Heavy Push Overload';
      await tester.enterText(titleFieldFinder, monCustomTitle);
      await tester.pumpAndSettle();
      expect(find.text(monCustomTitle), findsOneWidget);

      // Tap Tuesday in split selector
      final tueButton = find.text('TUE');
      expect(tueButton, findsOneWidget);
      await tester.tap(tueButton);
      await tester.pumpAndSettle();

      // Tuesday defaults to Tuesday title
      expect(find.text('Tuesday — Pull Day'), findsOneWidget);

      // Switch back to Monday
      final monButton = find.text('MON');
      expect(monButton, findsOneWidget);
      await tester.tap(monButton);
      await tester.pumpAndSettle();

      // Monday preserved custom title horizontally
      expect(find.text(monCustomTitle), findsOneWidget);
      final renderBox = tester.renderObject<RenderBox>(titleFieldFinder);
      expect(renderBox.size.width, closeTo(508.0, 2.0));
    });
  });
}
