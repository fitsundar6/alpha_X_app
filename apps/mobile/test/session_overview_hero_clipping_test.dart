import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_x_gym/core/widgets/alpha_x_hero.dart';
import 'package:alpha_x_gym/core/widgets/alpha_x_button.dart';
import 'package:alpha_x_gym/features/workout/domain/models/workout_models.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/workout/presentation/client/client_session_overview_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  WorkoutSession buildSession({
    required String title,
    String workoutType = 'Hypertrophy',
    String targetMuscleGroup = 'Back, Biceps, Rear Delts',
    int durationMinutes = 50,
  }) {
    return WorkoutSession(
      id: 'session_test_hero',
      title: title,
      workoutType: workoutType,
      targetMuscleGroup: targetMuscleGroup,
      difficulty: 'Intermediate',
      estimatedDurationMinutes: durationMinutes,
      description: 'Prescribed gym routine',
      isActive: true,
      availabilityType: 'INDIVIDUAL',
      exercises: [
        WorkoutExercise(
          id: 'ex_1',
          exerciseId: 'ex_row',
          exerciseName: 'Barbell Bent-Over Row',
          category: 'Back',
          primaryMusclesDisplay: 'Latissimus Dorsi',
          secondaryMusclesDisplay: 'Biceps, Rear Delts',
          trainerNote: 'Tempo 3-1-1-0. Prioritize strict range of motion and form.',
          tempo: '3-1-1-0',
          restSeconds: 90,
          sets: [
            const ExerciseSet(
              id: 'set_1',
              setNumber: 1,
              targetWeight: 75.0,
              targetRepsMin: 6,
              targetRepsMax: 8,
              targetRir: 2,
              isCompleted: false,
            ),
          ],
        ),
      ],
    );
  }

  group('Session Overview Hero Card & START WORKOUT Button Clipping Tests', () {
    testWidgets('1. Exact Bug Reproduction Case: 2-line title ("Pull Day — Back, Rear Delts & Biceps") does not clip button', (tester) async {
      tester.view.physicalSize = const Size(393, 852); // iPhone 15 / 16
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final session = buildSession(title: 'Pull Day — Back, Rear Delts & Biceps');
      final repo = WorkoutRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: ClientSessionOverviewScreen(
            session: session,
            workoutRepository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the AlphaXHero widget and START WORKOUT button
      final heroFinder = find.byType(AlphaXHero);
      expect(heroFinder, findsOneWidget);

      final buttonFinder = find.widgetWithText(AlphaXButton, 'START WORKOUT');
      expect(buttonFinder, findsOneWidget);

      // Verify geometry: button must be completely inside the hero card
      final heroRect = tester.getRect(heroFinder);
      final buttonRect = tester.getRect(buttonFinder);

      expect(buttonRect.top, greaterThanOrEqualTo(heroRect.top),
          reason: 'Button top must be inside hero card');
      expect(buttonRect.bottom, lessThanOrEqualTo(heroRect.bottom),
          reason: 'Button bottom must be strictly inside hero card, never clipped');

      // Verify full button height is intact (at least 50px)
      expect(buttonRect.height, greaterThanOrEqualTo(50.0),
          reason: 'Button full height must not be truncated');

      // Verify bottom padding between button and hero card bottom edge is >= 16px
      final bottomPadding = heroRect.bottom - buttonRect.bottom;
      expect(bottomPadding, greaterThanOrEqualTo(16.0),
          reason: 'Hero card must provide bottom padding under the button');
    });

    testWidgets('2. Small Android Screen (360x640): Button is fully visible without clipping or overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final session = buildSession(title: 'Pull Day — Back, Rear Delts & Biceps');
      final repo = WorkoutRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: ClientSessionOverviewScreen(
            session: session,
            workoutRepository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final heroFinder = find.byType(AlphaXHero);
      final buttonFinder = find.widgetWithText(AlphaXButton, 'START WORKOUT');

      final heroRect = tester.getRect(heroFinder);
      final buttonRect = tester.getRect(buttonFinder);

      expect(buttonRect.bottom, lessThanOrEqualTo(heroRect.bottom));
      expect(buttonRect.height, greaterThanOrEqualTo(50.0));
      expect(heroRect.bottom - buttonRect.bottom, greaterThanOrEqualTo(16.0));
    });

    testWidgets('3. Long 3-Line Title: Card grows dynamically to accommodate title wrapping without pushing button out', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final session = buildSession(
        title: 'Advanced Hypertrophy Upper Body Push Pull Volume Progressive Overload Specialization',
      );
      final repo = WorkoutRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: ClientSessionOverviewScreen(
            session: session,
            workoutRepository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final heroFinder = find.byType(AlphaXHero);
      final buttonFinder = find.widgetWithText(AlphaXButton, 'START WORKOUT');

      final heroRect = tester.getRect(heroFinder);
      final buttonRect = tester.getRect(buttonFinder);

      // Hero height should have dynamically grown beyond the 220px baseline
      expect(heroRect.height, greaterThan(220.0),
          reason: 'Hero card must grow with long 3-line title');
      expect(buttonRect.bottom, lessThanOrEqualTo(heroRect.bottom),
          reason: 'Button must remain fully inside the expanded card');
      expect(buttonRect.height, greaterThanOrEqualTo(50.0));
      expect(heroRect.bottom - buttonRect.bottom, greaterThanOrEqualTo(16.0));
    });

    testWidgets('4. Large Font Scaling (textScaleFactor = 1.3): Card adapts without clipping button', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final session = buildSession(title: 'Pull Day — Back, Rear Delts & Biceps');
      final repo = WorkoutRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: ClientSessionOverviewScreen(
              session: session,
              workoutRepository: repo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final heroFinder = find.byType(AlphaXHero);
      final buttonFinder = find.widgetWithText(AlphaXButton, 'START WORKOUT');

      final heroRect = tester.getRect(heroFinder);
      final buttonRect = tester.getRect(buttonFinder);

      expect(buttonRect.bottom, lessThanOrEqualTo(heroRect.bottom));
      expect(buttonRect.height, greaterThanOrEqualTo(50.0));
      expect(heroRect.bottom - buttonRect.bottom, greaterThanOrEqualTo(16.0));
    });

    testWidgets('5. iPhone SE (375x667): Button is fully visible and clickable', (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final session = buildSession(title: 'Pull Day — Back, Rear Delts & Biceps');
      final repo = WorkoutRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: ClientSessionOverviewScreen(
            session: session,
            workoutRepository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final buttonFinder = find.widgetWithText(AlphaXButton, 'START WORKOUT');
      expect(buttonFinder, findsOneWidget);

      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();
    });
  });
}
