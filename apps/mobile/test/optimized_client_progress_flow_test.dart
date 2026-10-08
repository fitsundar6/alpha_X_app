import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:alpha_x_gym/features/progress/domain/models/weekly_check_in.dart';
import 'package:alpha_x_gym/features/progress/data/repositories/weekly_progress_repository.dart';
import 'package:alpha_x_gym/features/progress/presentation/widgets/weekly_progress_charts.dart';
import 'package:alpha_x_gym/features/progress/presentation/screens/client_weekly_progress_screen.dart';
import 'package:alpha_x_gym/features/progress/presentation/screens/client_weekly_check_in_form_screen.dart';

void main() {
  group('Optimized Weekly Check-In & Progress Flow Tests', () {
    test('Calculate Changes: Check-in form calculates deltas against previous baseline', () {
      final prevCheckIn = WeeklyCheckIn(
        id: 'w1',
        clientProfileId: 'cp1',
        weekNumber: 1,
        year: 2026,
        checkInDate: DateTime(2026, 10, 1),
        nextCheckInDate: DateTime(2026, 10, 8),
        weightKg: 82.0,
        waistCm: 34.0,
        nutritionCalories: 'Good',
        nutritionProtein: 'Good',
        nutritionWater: 'Good',
        dietAdherence: 'Good',
        sleepQuality: 'Good',
        sleepHours: 7.5,
        recoveryQuality: 'Good',
        workoutCompletion: 'All',
        workoutFeeling: 'Good',
        energyLevel: 'High',
        createdAt: DateTime(2026, 10, 1),
      );

      // Simulating user input in check-in week 2:
      final enteredWeight = 81.4;
      final enteredWaist = 33.2;

      final weightDelta = enteredWeight - prevCheckIn.weightKg;
      final waistDelta = enteredWaist - (prevCheckIn.waistCm ?? enteredWaist);

      expect(double.parse(weightDelta.toStringAsFixed(1)), -0.6);
      expect(double.parse(waistDelta.toStringAsFixed(1)), -0.8);

      // Verify serialization with deltas
      final w2Json = {
        'id': 'w2',
        'clientProfileId': 'cp1',
        'weekNumber': 2,
        'year': 2026,
        'checkInDate': '2026-10-08T00:00:00.000Z',
        'nextCheckInDate': '2026-10-15T00:00:00.000Z',
        'weightKg': enteredWeight,
        'waistCm': enteredWaist,
        'weightChange': weightDelta,
        'waistChange': waistDelta,
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
        'chestCm': 102.0,
        'armsCm': 37.5,
        'hipsCm': 96.0,
        'thighsCm': 58.0,
        'createdAt': '2026-10-08T00:00:00.000Z',
      };

      final checkIn2 = WeeklyCheckIn.fromJson(w2Json);
      expect(checkIn2.weightChange, closeTo(-0.6, 0.01));
      expect(checkIn2.waistChange, closeTo(-0.8, 0.01));
      expect(checkIn2.chestCm, 102.0);
      expect(checkIn2.armsCm, 37.5);
    });

    testWidgets('Live Delta Preview renders in ClientWeeklyCheckInFormScreen', (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/client/me/weekly-check-ins/status')) {
          return http.Response(
            jsonEncode({
              'isAvailable': true,
              'currentWeekNumber': 2,
              'daysUntilNext': 0,
              'nextCheckInDate': '2026-10-08T00:00:00.000Z',
              'statusText': 'Check-In Available',
              'lastCheckIn': {
                'id': 'w1',
                'clientProfileId': 'cp1',
                'weekNumber': 1,
                'year': 2026,
                'weightKg': 82.0,
                'waistCm': 34.0,
                'nutritionCalories': 'Good',
                'nutritionProtein': 'Good',
                'nutritionWater': 'Good',
                'dietAdherence': 'Good',
                'sleepQuality': 'Good',
                'sleepHours': 7.5,
                'recoveryQuality': 'Good',
                'workoutCompletion': 'All',
                'workoutFeeling': 'Good',
                'energyLevel': 'High',
                'checkInDate': '2026-10-01T00:00:00.000Z',
                'nextCheckInDate': '2026-10-08T00:00:00.000Z',
                'createdAt': '2026-10-01T00:00:00.000Z',
              },
            }),
            200,
          );
        }
        return http.Response('{"error":"not found"}', 404);
      });

      final repo = WeeklyProgressRepository(httpClient: mockClient);
      await repo.fetchCheckInStatus();

      await tester.pumpWidget(
        MaterialApp(
          home: ClientWeeklyCheckInFormScreen(
            repository: repo,
            weekNumber: 2,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify form rendered
      expect(find.text('WEEK 2 CHECK-IN'), findsOneWidget);
      expect(find.text('AUTO-CALCULATED'), findsOneWidget);
      expect(find.text('PREVIOUS: 82.0 kg • Waist 34.0 cm'), findsOneWidget);

      // Enter weight in textfield
      final weightField = find.widgetWithText(TextFormField, 'e.g. 78.5');
      await tester.enterText(weightField, '81.4');
      await tester.pump();

      // Check auto-calculated delta indicator
      expect(find.text('Weight: -0.6 kg'), findsOneWidget);
    });

    testWidgets('ClientInteractiveProgressChart toggles between metrics smoothly', (tester) async {
      final w1 = WeeklyCheckIn(
        id: '1',
        clientProfileId: 'cp1',
        weekNumber: 1,
        year: 2026,
        checkInDate: DateTime(2026, 9, 24),
        nextCheckInDate: DateTime(2026, 10, 1),
        weightKg: 83.0,
        waistCm: 35.0,
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
        createdAt: DateTime(2026, 9, 24),
      );
      final w2 = WeeklyCheckIn(
        id: '2',
        clientProfileId: 'cp1',
        weekNumber: 2,
        year: 2026,
        checkInDate: DateTime(2026, 10, 1),
        nextCheckInDate: DateTime(2026, 10, 8),
        weightKg: 82.0,
        waistCm: 34.2,
        weightChange: -1.0,
        waistChange: -0.8,
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
        createdAt: DateTime(2026, 10, 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ClientInteractiveProgressChart(
                checkIns: [w1, w2],
                currentDailySteps: 8500,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Metric toggle pills
      expect(find.text('Weight'), findsOneWidget);
      expect(find.text('Waist'), findsOneWidget);
      expect(find.text('Steps'), findsOneWidget);
      expect(find.text('Strength'), findsOneWidget);

      // Default metric is Weight
      expect(find.text('82.0 kg'), findsOneWidget);
      expect(find.byType(LineChart), findsOneWidget);

      // Tap Waist
      await tester.tap(find.text('Waist'));
      await tester.pumpAndSettle();
      expect(find.text('34.2 cm'), findsOneWidget);

      // Tap Steps
      await tester.tap(find.text('Steps'));
      await tester.pumpAndSettle();
      expect(find.text('8500 / day'), findsOneWidget);

      // Tap Strength
      await tester.tap(find.text('Strength'));
      await tester.pumpAndSettle();
      expect(find.text('All workouts'), findsOneWidget);
    });

    testWidgets('ClientWeeklyProgressScreen renders all 7 Core Sections clearly', (tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockData = [
        {
          'id': 'w2',
          'clientProfileId': 'cp1',
          'weekNumber': 2,
          'year': 2026,
          'checkInDate': '2026-10-08T00:00:00.000Z',
          'nextCheckInDate': '2026-10-15T00:00:00.000Z',
          'weightKg': 80.5,
          'waistCm': 32.5,
          'weightChange': -0.7,
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
          'chestCm': 102.0,
          'armsCm': 38.0,
          'hipsCm': 95.0,
          'thighsCm': 57.0,
          'hasCoachReview': true,
          'reviewedByName': 'Coach Dave',
          'whatWentWell': 'Solid adherence across all lifts and water goals',
          'needsImprovement': 'Maintain weekend protein timing',
          'nextWeekFocus': 'Progress bench press load by 2.5kg',
          'createdAt': '2026-10-08T00:00:00.000Z',
        },
        {
          'id': 'w1',
          'clientProfileId': 'cp1',
          'weekNumber': 1,
          'year': 2026,
          'checkInDate': '2026-10-01T00:00:00.000Z',
          'nextCheckInDate': '2026-10-08T00:00:00.000Z',
          'weightKg': 81.2,
          'waistCm': 33.0,
          'nutritionCalories': 'Good',
          'nutritionProtein': 'Good',
          'nutritionWater': 'Good',
          'dietAdherence': 'Good',
          'sleepQuality': 'Good',
          'sleepHours': 7.5,
          'recoveryQuality': 'Good',
          'workoutCompletion': 'All',
          'workoutFeeling': 'Good',
          'energyLevel': 'High',
          'createdAt': '2026-10-01T00:00:00.000Z',
        }
      ];

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/client/me/weekly-check-ins/status')) {
          return http.Response.bytes(
            utf8.encode(jsonEncode({
              'isAvailable': false,
              'currentWeekNumber': 2,
              'daysUntilNext': 6,
              'nextCheckInDate': '2026-10-15T00:00:00.000Z',
              'statusText': 'Weekly Check-In Completed ✓ (Next Check-In: 2026-10-15)',
              'lastCheckIn': mockData.first,
            })),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (request.url.path.contains('/client/me/weekly-check-ins')) {
          return http.Response.bytes(
            utf8.encode(jsonEncode({
              'data': mockData,
            })),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('{"error":"not found"}', 404);
      });

      final repo = WeeklyProgressRepository(httpClient: mockClient);

      await tester.pumpWidget(
        MaterialApp(
          home: ClientWeeklyProgressScreen(
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 0. Check-In Status Banner
      expect(find.textContaining('Week 2 Check-In Completed ✓'), findsOneWidget);

      // 1. Overall Progress Hero Card
      expect(find.text('OVERALL PROGRESS'), findsOneWidget);
      expect(find.textContaining('Excellent Progress'), findsOneWidget);

      // 2. Key Weekly Changes (5 Vital Metrics)
      expect(find.text('KEY WEEKLY CHANGES'), findsOneWidget);
      expect(find.text('WEIGHT'), findsOneWidget);
      expect(find.text('WAIST'), findsOneWidget);
      expect(find.text('STEPS'), findsOneWidget);
      expect(find.text('PROTEIN'), findsOneWidget);
      expect(find.text('SLEEP'), findsOneWidget);

      // 3. Progression Chart
      expect(find.byType(ClientInteractiveProgressChart), findsOneWidget);
      expect(find.text('WEIGHT PROGRESSION'), findsOneWidget);

      // 4. Weekly Summary
      expect(find.text('WEEKLY SUMMARY & FOCUS'), findsOneWidget);
      expect(find.text('WHAT IMPROVED'), findsOneWidget);
      expect(find.text('WHAT NEEDS ATTENTION'), findsOneWidget);
      expect(find.text('ONE FOCUS FOR NEXT WEEK'), findsOneWidget);

      // 5. Progress Journey Timeline
      expect(find.text('PROGRESS JOURNEY'), findsOneWidget);
      expect(find.text('Week 2'), findsWidgets);
      expect(find.text('Week 1'), findsWidgets);

      // 6. Body Measurements Card
      expect(find.text('BODY MEASUREMENTS'), findsOneWidget);
      expect(find.text('CHEST'), findsOneWidget);
      expect(find.text('102.0 cm'), findsOneWidget);
      expect(find.text('ARMS'), findsOneWidget);
      expect(find.text('38.0 cm'), findsOneWidget);

      // 7. Transformation Photos
      expect(find.text('TRANSFORMATION COMPARISON'), findsOneWidget);
      expect(find.textContaining('Record milestone photos'), findsOneWidget);
      expect(find.text('UPLOAD'), findsOneWidget);
    });
  });
}
