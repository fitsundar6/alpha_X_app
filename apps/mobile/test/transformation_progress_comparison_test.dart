import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_x_gym/core/constants/app_constants.dart';
import 'package:alpha_x_gym/features/progress/presentation/screens/client_transformation_timeline_screen.dart';

void main() {
  group('Before & After Transformation Progress & Comparison Tests', () {
    test('TEST 1: AppConstants.resolveImageUrl correctly formats relative URLs with auth token', () {
      const relativeUrl = '/api/v1/transformation-photos/milestone-123/front';
      const token = 'sample_jwt_token_xyz';

      final resolved = AppConstants.resolveImageUrl(relativeUrl, authToken: token);

      expect(resolved, contains('/api/v1/transformation-photos/milestone-123/front'));
      expect(resolved, contains('token=sample_jwt_token_xyz'));
      expect(resolved, isNot(contains('/api/v1/api/v1'))); // Ensures no duplicate /api/v1

      // Absolute URL should remain unchanged
      final absolute = AppConstants.resolveImageUrl('https://alphaxgym.com/cdn/photo.jpg');
      expect(absolute, equals('https://alphaxgym.com/cdn/photo.jpg'));

      // Empty or null returns empty string
      expect(AppConstants.resolveImageUrl(null), isEmpty);
      expect(AppConstants.resolveImageUrl(''), isEmpty);
    });

    testWidgets('TEST 2: Empty state guidance is rendered when no transformation photos exist', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ClientTransformationTimelineScreen(
            initialMilestones: [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header title
      expect(find.text('TRANSFORMATION TIMELINE'), findsOneWidget);

      // Empty state guidance
      expect(find.text('BEFORE & AFTER COMPARISON'), findsOneWidget);
      expect(find.text('RECORD WEEK 1 BASELINE PHOTO'), findsOneWidget);
      expect(find.text('PROGRESSION PROTOCOL HISTORY'), findsOneWidget);
      expect(find.text('WEEK 1 BASELINE'), findsOneWidget);
    });

    testWidgets('TEST 3: Renders Side-by-Side Comparison card with metrics and angle selectors', (tester) async {
      final sampleMilestones = [
        {
          'id': 'm-week-1',
          'weekNumber': 1,
          'date': '2026-09-01T08:00:00.000Z',
          'frontPhotoUrl': '/api/v1/transformation-photos/m-week-1/front',
          'sidePhotoUrl': '/api/v1/transformation-photos/m-week-1/side',
          'backPhotoUrl': '/api/v1/transformation-photos/m-week-1/back',
          'weightKg': 85.0,
          'waistCm': 90.0,
          'notes': 'Starting baseline protocol.',
        },
        {
          'id': 'm-week-8',
          'weekNumber': 8,
          'date': '2026-10-27T08:00:00.000Z',
          'frontPhotoUrl': '/api/v1/transformation-photos/m-week-8/front',
          'sidePhotoUrl': '/api/v1/transformation-photos/m-week-8/side',
          'backPhotoUrl': '/api/v1/transformation-photos/m-week-8/back',
          'weightKg': 80.2,
          'waistCm': 82.0,
          'notes': 'Noticeable hypertrophy and waist reduction.',
        },
      ];

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: ClientTransformationTimelineScreen(
            initialMilestones: sampleMilestones,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top Side-by-Side comparison title
      expect(find.text('SIDE-BY-SIDE TRANSFORMATION'), findsOneWidget);

      // Angle chips
      expect(find.text('FRONT'), findsWidgets);
      expect(find.text('SIDE'), findsWidgets);
      expect(find.text('BACK'), findsWidgets);

      // Before & After labels in comparison
      expect(find.text('BEFORE (WEEK 1)'), findsOneWidget);
      expect(find.text('AFTER (WEEK 8)'), findsOneWidget);

      // Delta Metrics Bar: Weight Change (-4.8 kg), Waist Change (-8.0 cm)
      expect(find.text('WEIGHT CHANGE'), findsOneWidget);
      expect(find.text('-4.8 kg'), findsOneWidget);
      expect(find.text('WAIST CHANGE'), findsOneWidget);
      expect(find.text('-8.0 cm'), findsOneWidget);
      expect(find.text('DURATION'), findsOneWidget);
      expect(find.text('7 Weeks'), findsOneWidget);

      // Protocol history section
      expect(find.text('PROGRESSION PROTOCOL HISTORY'), findsOneWidget);
      expect(find.text('WEEK 1 BASELINE'), findsOneWidget);
      expect(find.text('WEEK 8 PROTOCOL'), findsOneWidget);
    });

    testWidgets('TEST 4: Tapping angle chip switches active comparison view', (tester) async {
      final sampleMilestones = [
        {
          'id': 'm-week-1',
          'weekNumber': 1,
          'date': '2026-09-01T08:00:00.000Z',
          'frontPhotoUrl': '/api/v1/transformation-photos/m-week-1/front',
          'sidePhotoUrl': '/api/v1/transformation-photos/m-week-1/side',
          'backPhotoUrl': null,
          'weightKg': 80.0,
          'waistCm': 85.0,
        },
        {
          'id': 'm-week-4',
          'weekNumber': 4,
          'date': '2026-09-29T08:00:00.000Z',
          'frontPhotoUrl': '/api/v1/transformation-photos/m-week-4/front',
          'sidePhotoUrl': '/api/v1/transformation-photos/m-week-4/side',
          'backPhotoUrl': null,
          'weightKg': 78.5,
          'waistCm': 83.0,
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ClientTransformationTimelineScreen(
            initialMilestones: sampleMilestones,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 'SIDE' angle chip
      final sideChip = find.widgetWithText(GestureDetector, 'SIDE').first;
      await tester.tap(sideChip);
      await tester.pumpAndSettle();

      // Still renders side-by-side comparison without crashes
      expect(find.text('SIDE-BY-SIDE TRANSFORMATION'), findsOneWidget);
      expect(find.text('-1.5 kg'), findsOneWidget);
    });

    testWidgets('TEST 5: Admin Mode displays target athlete name and isolated data', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ClientTransformationTimelineScreen(
            adminTargetClientId: 'AXG-0007',
            athleteName: 'John Doe',
            initialMilestones: [
              {
                'id': 'm-admin-1',
                'weekNumber': 1,
                'weightKg': 92.0,
                'waistCm': 96.0,
                'notes': 'Initial athlete assessment photos pending.',
              }
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Custom Admin title bar
      expect(find.text('JOHN DOE • TRANSFORMATION'), findsOneWidget);
      expect(find.text('WEEK 1 BASELINE'), findsOneWidget);
      expect(find.text('92.0 kg'), findsOneWidget);
      expect(find.text('96.0 cm'), findsOneWidget);

      // In admin view, self-service upload button is not cluttering athlete screen
      expect(find.byIcon(Icons.add_photo_alternate_outlined), findsNothing);
    });

    testWidgets('TEST 6: Selectable Check-In Weeks (Week 1 vs Week 4) with dates and metrics', (tester) async {
      final sampleMilestones = [
        {
          'id': 'm-week-1',
          'weekNumber': 1,
          'date': '2026-08-01T08:00:00.000Z',
          'frontPhotoUrl': '/api/v1/transformation-photos/m-week-1/front',
          'weightKg': 88.0,
          'waistCm': 94.0,
        },
        {
          'id': 'm-week-4',
          'weekNumber': 4,
          'date': '2026-08-29T08:00:00.000Z',
          'frontPhotoUrl': '/api/v1/transformation-photos/m-week-4/front',
          'weightKg': 84.5,
          'waistCm': 89.0,
        },
        {
          'id': 'm-week-12',
          'weekNumber': 12,
          'date': '2026-10-24T08:00:00.000Z',
          'frontPhotoUrl': '/api/v1/transformation-photos/m-week-12/front',
          'weightKg': 80.0,
          'waistCm': 82.0,
        },
      ];

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: ClientTransformationTimelineScreen(
            initialMilestones: sampleMilestones,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // By default automatic comparison chose Week 1 vs Week 12
      expect(find.text('COMPARE FROM'), findsOneWidget);
      expect(find.text('COMPARE WITH'), findsOneWidget);
      expect(find.text('COMPARE'), findsOneWidget);

      // Select Week 4 in COMPARE WITH dropdown
      final compareWithDropdown = find.byType(DropdownButton<int>).last;
      await tester.tap(compareWithDropdown);
      await tester.pumpAndSettle();

      // Tap Week 4 item from dropdown menu
      final week4Item = find.textContaining('Week 4').last;
      await tester.tap(week4Item);
      await tester.pumpAndSettle();

      // Tap COMPARE button
      await tester.tap(find.text('COMPARE'));
      await tester.pumpAndSettle();

      // Verifies comparison updated to Week 1 vs Week 4
      expect(find.text('BEFORE (WEEK 1)'), findsOneWidget);
      expect(find.text('AFTER (WEEK 4)'), findsOneWidget);
      expect(find.text('-3.5 kg'), findsOneWidget); // 84.5 - 88.0
      expect(find.text('-5.0 cm'), findsOneWidget); // 89.0 - 94.0
      expect(find.text('3 Weeks'), findsOneWidget);
    });

    testWidgets('TEST 7: Handles missing weeks and irregular check-in dates (Week 2 vs Week 8)', (tester) async {
      final sampleMilestones = [
        {
          'id': 'm-week-2',
          'weekNumber': 2,
          'date': '2026-08-10T08:00:00.000Z',
          'frontPhotoUrl': '/api/v1/transformation-photos/m-week-2/front',
          'weightKg': 82.0,
          'waistCm': 86.0,
        },
        {
          'id': 'm-week-8',
          'weekNumber': 8,
          'date': '2026-09-21T08:00:00.000Z',
          'frontPhotoUrl': '/api/v1/transformation-photos/m-week-8/front',
          'weightKg': 77.0,
          'waistCm': 80.0,
        },
      ];

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: ClientTransformationTimelineScreen(
            initialMilestones: sampleMilestones,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('BEFORE (WEEK 2)'), findsOneWidget);
      expect(find.text('AFTER (WEEK 8)'), findsOneWidget);
      expect(find.text('-5.0 kg'), findsOneWidget);
      expect(find.text('-6.0 cm'), findsOneWidget);
      expect(find.text('6 Weeks'), findsOneWidget);
    });

    testWidgets('TEST 8: Swap button swaps selected comparison weeks (reversed selection)', (tester) async {
      final sampleMilestones = [
        {
          'id': 'm-week-1',
          'weekNumber': 1,
          'date': '2026-08-01T08:00:00.000Z',
          'frontPhotoUrl': '/api/v1/transformation-photos/m-week-1/front',
          'weightKg': 80.0,
        },
        {
          'id': 'm-week-8',
          'weekNumber': 8,
          'date': '2026-09-26T08:00:00.000Z',
          'frontPhotoUrl': '/api/v1/transformation-photos/m-week-8/front',
          'weightKg': 75.0,
        },
      ];

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: ClientTransformationTimelineScreen(
            initialMilestones: sampleMilestones,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially Week 1 vs Week 8
      expect(find.text('BEFORE (WEEK 1)'), findsOneWidget);
      expect(find.text('AFTER (WEEK 8)'), findsOneWidget);
      expect(find.text('-5.0 kg'), findsOneWidget);

      // Tap Swap button
      final swapButton = find.byTooltip('Swap comparison weeks');
      expect(swapButton, findsOneWidget);
      await tester.tap(swapButton);
      await tester.pumpAndSettle();

      // Now reversed: Week 8 vs Week 1
      expect(find.text('BEFORE (WEEK 8)'), findsOneWidget);
      expect(find.text('AFTER (WEEK 1)'), findsOneWidget);
      expect(find.text('+5.0 kg'), findsOneWidget); // 80.0 - 75.0 = +5.0 kg
    });

    testWidgets('TEST 9: One-photo-only state prompts client to upload another before comparing', (tester) async {
      final oneMilestone = [
        {
          'id': 'm-week-1',
          'weekNumber': 1,
          'date': '2026-08-01T08:00:00.000Z',
          'frontPhotoUrl': '/api/v1/transformation-photos/m-week-1/front',
          'weightKg': 85.0,
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ClientTransformationTimelineScreen(
            initialMilestones: oneMilestone,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Shows 1 check-in recorded guidance
      expect(find.text('1 CHECK-IN RECORDED'), findsOneWidget);
      expect(find.text('Upload another check-in photo to compare'), findsOneWidget);
      expect(find.text('UPLOAD NEXT CHECK-IN PHOTO'), findsOneWidget);

      // Does not render side-by-side comparison with single photo
      expect(find.text('BEFORE (WEEK 1)'), findsNothing);
    });

    testWidgets('TEST 10: Prevents selecting the same check-in twice', (tester) async {
      final sampleMilestones = [
        {
          'id': 'm-week-1',
          'weekNumber': 1,
          'date': '2026-08-01T08:00:00.000Z',
          'frontPhotoUrl': '/api/v1/transformation-photos/m-week-1/front',
        },
        {
          'id': 'm-week-4',
          'weekNumber': 4,
          'date': '2026-08-29T08:00:00.000Z',
          'frontPhotoUrl': '/api/v1/transformation-photos/m-week-4/front',
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ClientTransformationTimelineScreen(
            initialMilestones: sampleMilestones,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open Compare From dropdown
      final compareFromDropdown = find.byType(DropdownButton<int>).first;
      await tester.tap(compareFromDropdown);
      await tester.pumpAndSettle();

      // Week 4 should be marked as (Selected) in Compare From dropdown menu
      expect(find.textContaining('Week 4'), findsWidgets);
    });

    testWidgets('TEST 11: Before/After Slider toggle displays interactive slider view', (tester) async {
      final sampleMilestones = [
        {
          'id': 'm-week-1',
          'weekNumber': 1,
          'date': '2026-08-01T08:00:00.000Z',
          'frontPhotoUrl': '/api/v1/transformation-photos/m-week-1/front',
        },
        {
          'id': 'm-week-4',
          'weekNumber': 4,
          'date': '2026-08-29T08:00:00.000Z',
          'frontPhotoUrl': '/api/v1/transformation-photos/m-week-4/front',
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ClientTransformationTimelineScreen(
            initialMilestones: sampleMilestones,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap SLIDER toggle
      final sliderToggle = find.text('SLIDER');
      expect(sliderToggle, findsOneWidget);
      await tester.tap(sliderToggle);
      await tester.pumpAndSettle();

      // Slider hint is visible
      expect(find.text('◀ Drag handle left or right to compare ▶'), findsOneWidget);
      expect(find.byIcon(Icons.compare_arrows), findsWidgets);
    });

    testWidgets('TEST 12: App restart/reload validates available photos when previous photo was deleted', (tester) async {
      // Step 1: Client has Week 1 and Week 8
      final initialMilestones = [
        {
          'id': 'm-week-1',
          'weekNumber': 1,
          'date': '2026-08-01T08:00:00.000Z',
          'frontPhotoUrl': '/api/v1/transformation-photos/m-week-1/front',
        },
        {
          'id': 'm-week-8',
          'weekNumber': 8,
          'date': '2026-09-26T08:00:00.000Z',
          'frontPhotoUrl': '/api/v1/transformation-photos/m-week-8/front',
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ClientTransformationTimelineScreen(
            initialMilestones: initialMilestones,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('BEFORE (WEEK 1)'), findsOneWidget);
      expect(find.text('AFTER (WEEK 8)'), findsOneWidget);

      // Step 2: Simulate app reload where Week 8 photo was deleted
      final reloadedMilestones = [
        {
          'id': 'm-week-1',
          'weekNumber': 1,
          'date': '2026-08-01T08:00:00.000Z',
          'frontPhotoUrl': '/api/v1/transformation-photos/m-week-1/front',
        },
        {
          'id': 'm-week-8',
          'weekNumber': 8,
          'date': '2026-09-26T08:00:00.000Z',
          'frontPhotoUrl': null, // photo was deleted
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ClientTransformationTimelineScreen(
            initialMilestones: reloadedMilestones,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Since only 1 photo remains (Week 1), it cleanly falls back to 1-photo guidance
      expect(find.text('1 CHECK-IN RECORDED'), findsOneWidget);
      expect(find.text('Upload another check-in photo to compare'), findsOneWidget);
    });
  });
}
