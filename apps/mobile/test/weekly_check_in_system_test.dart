import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:alpha_x_gym/features/progress/domain/models/weekly_check_in.dart';
import 'package:alpha_x_gym/features/progress/domain/models/weekly_check_in_status.dart';
import 'package:alpha_x_gym/features/progress/presentation/widgets/motivational_quote_card.dart';
import 'package:alpha_x_gym/features/progress/presentation/widgets/weekly_progress_charts.dart';
import 'package:alpha_x_gym/features/progress/presentation/widgets/coach_review_card.dart';
import 'package:alpha_x_gym/features/progress/presentation/widgets/weekly_comparison_sheet.dart';

void main() {
  group('WeeklyCheckIn Domain & Serialization Tests', () {
    test('Correctly deserializes backend WeeklyCheckIn JSON with deltas & review', () {
      final json = {
        'id': 'checkin-w1-123',
        'clientProfileId': 'cp-456',
        'weekNumber': 1,
        'year': 2026,
        'checkInDate': '2026-10-01T06:00:00.000Z',
        'nextCheckInDate': '2026-10-08T06:00:00.000Z',
        'weightKg': 82.5,
        'waistCm': 34.0,
        'weightChange': null,
        'waistChange': null,
        'nutritionCalories': 'Good',
        'nutritionProtein': 'Mostly',
        'nutritionWater': 'Good',
        'dietAdherence': 'Good',
        'sleepQuality': 'Good',
        'sleepHours': 7.5,
        'recoveryQuality': 'Good',
        'workoutCompletion': 'All',
        'workoutFeeling': 'Very Good',
        'energyLevel': 'High',
        'hasPain': true,
        'painLocation': 'Left shoulder',
        'painExercise': 'Overhead press',
        'painLevel': 4,
        'painDescription': 'Mild pinching near lockout',
        'weeklyProblems': ['Stress/busy schedule'],
        'clientNotes': 'Looking forward to next block',
        'hasCoachReview': true,
        'reviewedById': 'trainer-1',
        'reviewedByName': 'Coach Marcus',
        'reviewedAt': '2026-10-02T10:00:00.000Z',
        'whatWentWell': 'Consistent hydration and heavy volume adherence',
        'needsImprovement': 'Watch tempo on overhead pressing',
        'nextWeekFocus': 'Deload overhead press by 10% to let shoulder settle',
        'workoutNotes': 'Swap barbell OHP to neutral grip dumbbell press',
        'nutritionNotes': 'Protein targets were well matched',
        'recoveryNotes': 'Aim for 8 hours before leg day',
        'followUpRequired': true,
        'createdAt': '2026-10-01T06:00:00.000Z',
      };

      final checkIn = WeeklyCheckIn.fromJson(json);

      expect(checkIn.id, 'checkin-w1-123');
      expect(checkIn.weekNumber, 1);
      expect(checkIn.weightKg, 82.5);
      expect(checkIn.waistCm, 34.0);
      expect(checkIn.weightDisplay, '82.5 kg');
      expect(checkIn.waistDisplay, '34.0 cm');
      expect(checkIn.weightChangeDisplay, 'Baseline');
      expect(checkIn.waistChangeDisplay, 'Baseline');

      // Nutrition & Sleep
      expect(checkIn.nutritionCalories, 'Good');
      expect(checkIn.nutritionProtein, 'Mostly');
      expect(checkIn.sleepHours, 7.5);

      // Pain
      expect(checkIn.hasPain, true);
      expect(checkIn.painLocation, 'Left shoulder');
      expect(checkIn.painLevel, 4);

      // Problems
      expect(checkIn.weeklyProblems, contains('Stress/busy schedule'));

      // Coach Review
      expect(checkIn.hasCoachReview, true);
      expect(checkIn.reviewedByName, 'Coach Marcus');
      expect(checkIn.followUpRequired, true);
      expect(checkIn.whatWentWell, 'Consistent hydration and heavy volume adherence');
    });

    test('Computes week-to-week deltas accurately (Weight: 82.5 -> 81.9, Change: -0.6 kg)', () {
      final jsonW2 = {
        'id': 'checkin-w2-789',
        'clientProfileId': 'cp-456',
        'weekNumber': 2,
        'year': 2026,
        'checkInDate': '2026-10-08T06:00:00.000Z',
        'nextCheckInDate': '2026-10-15T06:00:00.000Z',
        'weightKg': 81.9,
        'waistCm': 33.5,
        'weightChange': -0.6,
        'waistChange': -0.5,
        'nutritionCalories': 'Good',
        'nutritionProtein': 'Good',
        'nutritionWater': 'Good',
        'dietAdherence': 'Good',
        'sleepQuality': 'Good',
        'sleepHours': 8.0,
        'recoveryQuality': 'Good',
        'workoutCompletion': 'All',
        'workoutFeeling': 'Very Good',
        'energyLevel': 'High',
        'hasPain': false,
        'weeklyProblems': ['No major problems'],
        'hasCoachReview': false,
        'createdAt': '2026-10-08T06:00:00.000Z',
      };

      final checkInW2 = WeeklyCheckIn.fromJson(jsonW2);

      expect(checkInW2.weightKg, 81.9);
      expect(checkInW2.weightChange, -0.6);
      expect(checkInW2.weightChangeDisplay, '-0.6 kg');
      expect(checkInW2.waistCm, 33.5);
      expect(checkInW2.waistChange, -0.5);
      expect(checkInW2.waistChangeDisplay, '-0.5 cm');
      expect(checkInW2.hasPain, false);
    });

    test('WeeklyCheckInStatus parses lock state, next check-in date, and countdown', () {
      final lockedJson = {
        'isAvailable': false,
        'currentWeekNumber': 2,
        'daysUntilNext': 6,
        'nextCheckInDate': '2026-10-08T06:00:00.000Z',
        'statusText': 'Weekly Check-In Completed ✓ (Next Check-In: 2026-10-08)',
        'lastCheckIn': {
          'id': 'checkin-w1',
          'clientProfileId': 'cp-1',
          'weekNumber': 1,
          'year': 2026,
          'weightKg': 80.0,
          'nutritionCalories': 'Good',
          'nutritionProtein': 'Good',
          'nutritionWater': 'Good',
          'dietAdherence': 'Good',
          'sleepQuality': 'Good',
          'sleepHours': 7.0,
          'recoveryQuality': 'Good',
          'workoutCompletion': 'All',
          'workoutFeeling': 'Good',
          'energyLevel': 'Good',
          'checkInDate': '2026-10-01T06:00:00.000Z',
          'nextCheckInDate': '2026-10-08T06:00:00.000Z',
          'createdAt': '2026-10-01T06:00:00.000Z',
        },
      };

      final status = WeeklyCheckInStatus.fromJson(lockedJson);

      expect(status.isAvailable, false);
      expect(status.currentWeekNumber, 2);
      expect(status.daysUntilNext, 6);
      expect(status.statusText, contains('Weekly Check-In Completed ✓'));
      expect(status.lastCheckIn, isNotNull);
      expect(status.lastCheckIn!.weekNumber, 1);
    });
  });

  group('Weekly Progress Widgets Tests', () {
    testWidgets('MotivationalQuoteCard displays quote and rotates on tap', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MotivationalQuoteCard(),
          ),
        ),
      );

      expect(find.text('WEEKLY MOTIVATION'), findsOneWidget);
      expect(find.byIcon(Icons.format_quote_rounded), findsOneWidget);

      // Tap quote card to rotate
      await tester.tap(find.byType(MotivationalQuoteCard));
      await tester.pump();

      expect(find.text('WEEKLY MOTIVATION'), findsOneWidget);
    });

    testWidgets('WeightProgressChartCard renders LineChart with multiple weeks', (tester) async {
      final w1 = WeeklyCheckIn(
        id: '1',
        clientProfileId: 'c1',
        weekNumber: 1,
        year: 2026,
        checkInDate: DateTime.now().subtract(const Duration(days: 7)),
        nextCheckInDate: DateTime.now(),
        weightKg: 82.5,
        nutritionCalories: 'Good',
        nutritionProtein: 'Good',
        nutritionWater: 'Good',
        dietAdherence: 'Good',
        sleepQuality: 'Good',
        sleepHours: 7.5,
        recoveryQuality: 'Good',
        workoutCompletion: 'All',
        workoutFeeling: 'Good',
        energyLevel: 'Good',
        createdAt: DateTime.now().subtract(const Duration(days: 7)),
      );

      final w2 = WeeklyCheckIn(
        id: '2',
        clientProfileId: 'c1',
        weekNumber: 2,
        year: 2026,
        checkInDate: DateTime.now(),
        nextCheckInDate: DateTime.now().add(const Duration(days: 7)),
        weightKg: 81.9,
        weightChange: -0.6,
        nutritionCalories: 'Good',
        nutritionProtein: 'Good',
        nutritionWater: 'Good',
        dietAdherence: 'Good',
        sleepQuality: 'Good',
        sleepHours: 8.0,
        recoveryQuality: 'Good',
        workoutCompletion: 'All',
        workoutFeeling: 'Very Good',
        energyLevel: 'High',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeightProgressChartCard(checkIns: [w1, w2]),
          ),
        ),
      );

      expect(find.text('WEIGHT PROGRESS'), findsOneWidget);
      expect(find.text('Latest: 81.9 kg'), findsOneWidget);
      expect(find.byType(LineChart), findsOneWidget);
    });

    testWidgets('WorkoutConsistencyCard renders completed vs planned and energy', (tester) async {
      final checkIn = WeeklyCheckIn(
        id: '1',
        clientProfileId: 'c1',
        weekNumber: 1,
        year: 2026,
        checkInDate: DateTime.now(),
        nextCheckInDate: DateTime.now().add(const Duration(days: 7)),
        weightKg: 75.0,
        nutritionCalories: 'Good',
        nutritionProtein: 'Good',
        nutritionWater: 'Good',
        dietAdherence: 'Good',
        sleepQuality: 'Good',
        sleepHours: 8.0,
        recoveryQuality: 'Good',
        workoutCompletion: 'All',
        workoutFeeling: 'Very Good',
        energyLevel: 'High',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkoutConsistencyCard(checkIn: checkIn),
          ),
        ),
      );

      expect(find.text('WORKOUT CONSISTENCY'), findsOneWidget);
      expect(find.text('Planned Workouts'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Workout Feeling'), findsOneWidget);
      expect(find.text('Very Good'), findsOneWidget);
      expect(find.text('Energy Level'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);
    });

    testWidgets('WeeklyHabitOverviewCard dynamically displays all 5 habits', (tester) async {
      final checkIn = WeeklyCheckIn(
        id: '1',
        clientProfileId: 'c1',
        weekNumber: 1,
        year: 2026,
        checkInDate: DateTime.now(),
        nextCheckInDate: DateTime.now().add(const Duration(days: 7)),
        weightKg: 75.0,
        nutritionCalories: 'Good',
        nutritionProtein: 'Good',
        nutritionWater: 'Good',
        dietAdherence: 'Good',
        sleepQuality: 'Good',
        sleepHours: 8.0,
        recoveryQuality: 'Good',
        workoutCompletion: 'All',
        workoutFeeling: 'Good',
        energyLevel: 'Good',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeeklyHabitOverviewCard(checkIn: checkIn),
          ),
        ),
      );

      expect(find.text('WEEKLY HABIT OVERVIEW'), findsOneWidget);
      expect(find.text('Protein'), findsOneWidget);
      expect(find.text('Water'), findsOneWidget);
      expect(find.text('Sleep'), findsOneWidget);
      expect(find.text('Workout'), findsOneWidget);
      expect(find.text('Recovery'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(5));
    });

    testWidgets('CoachReviewCard shows review sections and follow-up pill', (tester) async {
      final reviewedCheckIn = WeeklyCheckIn(
        id: '1',
        clientProfileId: 'c1',
        weekNumber: 1,
        year: 2026,
        checkInDate: DateTime.now(),
        nextCheckInDate: DateTime.now().add(const Duration(days: 7)),
        weightKg: 75.0,
        nutritionCalories: 'Good',
        nutritionProtein: 'Good',
        nutritionWater: 'Good',
        dietAdherence: 'Good',
        sleepQuality: 'Good',
        sleepHours: 8.0,
        recoveryQuality: 'Good',
        workoutCompletion: 'All',
        workoutFeeling: 'Good',
        energyLevel: 'Good',
        hasCoachReview: true,
        reviewedByName: 'Coach Alex',
        reviewedAt: DateTime.parse('2026-10-01'),
        whatWentWell: 'Superb dedication to compound lifts',
        needsImprovement: 'Increase hydration on rest days',
        nextWeekFocus: 'Add 2.5kg to back squat',
        followUpRequired: true,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CoachReviewCard(checkIn: reviewedCheckIn),
          ),
        ),
      );

      expect(find.text('WEEKLY COACH REVIEW'), findsOneWidget);
      expect(find.text('Reviewed by Coach Alex'), findsOneWidget);
      expect(find.text('Follow-up Required'), findsOneWidget);
      expect(find.text('Superb dedication to compound lifts'), findsOneWidget);
      expect(find.text('Increase hydration on rest days'), findsOneWidget);
      expect(find.text('Add 2.5kg to back squat'), findsOneWidget);
    });

    testWidgets('WeeklyComparisonSheet displays side-by-side comparison & non-diagnostic note', (tester) async {
      final w1 = WeeklyCheckIn(
        id: '1',
        clientProfileId: 'c1',
        weekNumber: 1,
        year: 2026,
        checkInDate: DateTime.parse('2026-09-24'),
        nextCheckInDate: DateTime.parse('2026-10-01'),
        weightKg: 82.5,
        waistCm: 34.0,
        nutritionCalories: 'Good',
        nutritionProtein: 'Good',
        nutritionWater: 'Good',
        dietAdherence: 'Good',
        sleepQuality: 'Good',
        sleepHours: 7.0,
        recoveryQuality: 'Good',
        workoutCompletion: 'All',
        workoutFeeling: 'Good',
        energyLevel: 'Good',
        createdAt: DateTime.now(),
      );

      final w2 = WeeklyCheckIn(
        id: '2',
        clientProfileId: 'c1',
        weekNumber: 2,
        year: 2026,
        checkInDate: DateTime.parse('2026-10-01'),
        nextCheckInDate: DateTime.parse('2026-10-08'),
        weightKg: 81.9,
        waistCm: 33.5,
        nutritionCalories: 'Good',
        nutritionProtein: 'Good',
        nutritionWater: 'Good',
        dietAdherence: 'Good',
        sleepQuality: 'Good',
        sleepHours: 8.0,
        recoveryQuality: 'Good',
        workoutCompletion: 'All',
        workoutFeeling: 'Very Good',
        energyLevel: 'High',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeeklyComparisonSheet(
              history: [w1, w2],
              initialWeekA: w1,
              initialWeekB: w2,
            ),
          ),
        ),
      );

      expect(find.text('WEEK-TO-WEEK COMPARISON'), findsOneWidget);
      expect(find.text('BODY WEIGHT'), findsOneWidget);
      expect(find.text('WAIST MEASUREMENT'), findsOneWidget);
      expect(find.text('-0.6 kg'), findsOneWidget);
      expect(find.text('-0.5 cm'), findsOneWidget);
      expect(
        find.text('Note: Observations are purely descriptive measurements and do not constitute health or medical conclusions.'),
        findsOneWidget,
      );
    });
  });
}
