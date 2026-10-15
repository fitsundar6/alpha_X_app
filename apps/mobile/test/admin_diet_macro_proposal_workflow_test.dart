import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_x_gym/features/ai_coach/domain/models/ai_coach_models.dart';
import 'package:alpha_x_gym/features/ai_coach/data/repositories/ai_coach_repository.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'package:alpha_x_gym/features/workout/presentation/admin/admin_workout_proposals_screen.dart';
import 'package:alpha_x_gym/features/ai_coach/presentation/widgets/admin_ai_proposal_review_dialog.dart';

void main() {
  group('Alpha X Admin Diet / Macro Proposal Workflow Tests', () {
    testWidgets('1. AdminWorkoutProposalsScreen displays type filter tabs and renders Diet card', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final aiRepo = AiCoachRepository();
      final workoutRepo = WorkoutRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: AdminWorkoutProposalsScreen(
            workoutRepository: workoutRepo,
            aiCoachRepository: aiRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Type Tabs
      expect(find.text('All Types'), findsOneWidget);
      expect(find.text('Workouts'), findsOneWidget);
      expect(find.text('Diet & Macros'), findsOneWidget);
    });

    testWidgets('2. AdminAiProposalReviewDialog renders flexible macro protocol banner for macro-only plan', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final macroProposal = AiProposal(
        id: 'prop_macro_test_1',
        title: 'Lean Bulk Macro Targets',
        summary: 'Targeted caloric surplus for lean hypertrophy.',
        type: AiProposalType.diet,
        status: AiProposalStatus.pending,
        reason: 'Optimal macronutrient balance calculated from body weight.',
        createdAt: DateTime.now(),
        clientName: 'Alex Rivera',
        clientId: 'AXG-7088',
        payload: {
          'planKind': 'MACRO_ONLY',
          'dailyCalories': 2850,
          'proteinGrams': 195,
          'carbGrams': 340,
          'fatGrams': 75,
          'fiberGrams': 35,
          'waterTargetLiters': 4.0,
          'meals': [],
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminAiProposalReviewDialog(
              proposal: macroProposal,
              onAccept: () {},
              onEdit: () {},
              onReject: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check athlete info
      expect(find.text('Alex Rivera'), findsOneWidget);
      expect(find.text('ID: AXG-7088'), findsOneWidget);

      // Check nutrition values
      expect(find.text('DAILY TARGET NUTRITION'), findsOneWidget);
      expect(find.text('2850'), findsOneWidget);
      expect(find.text('195g'), findsOneWidget);
      expect(find.text('340g'), findsOneWidget);
      expect(find.text('75g'), findsOneWidget);

      // Check flexible macro-only banner
      expect(find.text('FLEXIBLE MACRO-ONLY TARGET PROTOCOL'), findsOneWidget);

      // Check the 3 admin review actions
      expect(find.text('REJECT'), findsOneWidget);
      expect(find.text('EDIT'), findsOneWidget);
      expect(find.text('ACCEPT & ASSIGN'), findsOneWidget);
    });

    testWidgets('3. AdminAiProposalReviewDialog renders prescribed meals for full diet plan', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final dietProposal = AiProposal(
        id: 'prop_diet_test_1',
        title: 'Cutting Nutrition Protocol',
        summary: 'High-protein caloric deficit plan.',
        type: AiProposalType.diet,
        status: AiProposalStatus.pending,
        reason: 'Fat loss phase with maximum lean tissue retention.',
        createdAt: DateTime.now(),
        clientName: 'Sarah Connor',
        clientId: 'AXG-1099',
        payload: {
          'planKind': 'DIET_PLAN',
          'dailyCalories': 1950,
          'proteinGrams': 170,
          'carbGrams': 165,
          'fatGrams': 50,
          'fiberGrams': 30,
          'waterTargetLiters': 3.5,
          'meals': [
            {
              'mealType': 'Breakfast',
              'timing': '08:00 AM',
              'items': [
                {'foodName': 'Rolled Oats', 'quantity': 60, 'unit': 'g', 'calories': 230, 'protein': 8},
                {'foodName': 'Egg Whites', 'quantity': 200, 'unit': 'ml', 'calories': 100, 'protein': 22},
              ],
            },
          ],
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminAiProposalReviewDialog(
              proposal: dietProposal,
              onAccept: () {},
              onEdit: () {},
              onReject: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sarah Connor'), findsOneWidget);
      expect(find.text('PRESCRIBED MEALS'), findsOneWidget);
      expect(find.text('BREAKFAST'), findsOneWidget);
      expect(find.textContaining('Rolled Oats'), findsOneWidget);
      expect(find.textContaining('Egg Whites'), findsOneWidget);
    });

    testWidgets('4. DietProposalDetailSheet renders client ID, expandable meal cards, and per-meal nutrition', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final aiRepo = AiCoachRepository();
      final dietProposal = AiProposal(
        id: 'prop_diet_sheet_test',
        title: 'Marcus — Hypertrophy Diet Plan',
        summary: 'Targeted caloric surplus with high protein distribution.',
        type: AiProposalType.diet,
        status: AiProposalStatus.pending,
        reason: 'Optimal fuel for strength phase.',
        createdAt: DateTime.now(),
        clientName: 'Marcus Vance',
        clientId: 'AXG-4402',
        payload: {
          'planKind': 'DIET_PLAN',
          'dailyCalories': 2600,
          'protein': 190,
          'carbohydrates': 310,
          'fat': 70,
          'fiber': 35,
          'waterTargetLiters': 4.0,
          'meals': [
            {
              'mealType': 'Breakfast',
              'timing': '08:00 AM',
              'notes': 'Post morning cardio fuel',
              'foods': [
                {
                  'foodId': 'f_1',
                  'foodName': 'Rolled Oats with Honey',
                  'quantity': 100,
                  'unit': 'g',
                  'calories': 380,
                  'protein': 12,
                  'carbs': 70,
                  'fat': 6,
                  'notes': 'Cook with warm water',
                  'substitutions': 'Cream of rice',
                },
                {
                  'foodId': 'f_2',
                  'foodName': 'Liquid Egg Whites',
                  'quantity': 250,
                  'unit': 'ml',
                  'calories': 125,
                  'protein': 26,
                  'carbs': 2,
                  'fat': 0,
                },
              ],
            },
            {
              'mealType': 'Lunch',
              'timing': '01:00 PM',
              'notes': 'Lean recovery meal',
              'foods': [
                {
                  'foodId': 'f_3',
                  'foodName': 'Grilled Chicken Breast',
                  'quantity': 200,
                  'unit': 'g',
                  'calories': 330,
                  'protein': 62,
                  'carbs': 0,
                  'fat': 7,
                  'substitutions': 'White fish or tofu',
                },
                {
                  'foodId': 'f_4',
                  'foodName': 'Jasmine Rice',
                  'quantity': 250,
                  'unit': 'g',
                  'calories': 325,
                  'protein': 6,
                  'carbs': 72,
                  'fat': 1,
                },
              ],
            },
          ],
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DietProposalDetailSheet(
              proposal: dietProposal,
              aiCoachRepository: aiRepo,
              onProposalUpdated: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify Client Name and Client ID in Header
      expect(find.text('Marcus Vance'), findsOneWidget);
      expect(find.text('ID: AXG-4402'), findsOneWidget);
      expect(find.text('DIET & MACRO PROPOSAL'), findsOneWidget);

      // 2. Verify Format Toggle
      expect(find.text('Full Diet Plan (With Meals)'), findsOneWidget);
      expect(find.text('Macro Targets Only'), findsOneWidget);

      // 3. Verify Expandable Meal Cards and Timings
      expect(find.text('Breakfast'), findsOneWidget);
      expect(find.text('Lunch'), findsOneWidget);
      expect(find.text('08:00 AM'), findsOneWidget);
      expect(find.text('01:00 PM'), findsOneWidget);

      // 4. Verify Food Items with Quantities and Units
      expect(find.text('Rolled Oats with Honey'), findsOneWidget);
      expect(find.text('100.0 g • 380 kcal'), findsOneWidget);
      expect(find.text('Liquid Egg Whites'), findsOneWidget);
      expect(find.text('250.0 ml • 125 kcal'), findsOneWidget);
      expect(find.text('Grilled Chicken Breast'), findsOneWidget);
      expect(find.text('200.0 g • 330 kcal'), findsOneWidget);
      expect(find.text('Jasmine Rice'), findsOneWidget);
      expect(find.text('250.0 g • 325 kcal'), findsOneWidget);

      // 5. Verify Food Item Notes & Allowed Substitutions
      expect(find.textContaining('Prep: Cook with warm water'), findsOneWidget);
      expect(find.textContaining('Sub: Cream of rice'), findsOneWidget);
      expect(find.textContaining('Sub: White fish or tofu'), findsOneWidget);

      // 6. Verify Direct Action Buttons
      expect(find.text('Reject'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
      expect(find.text('Approve & Assign'), findsOneWidget);
    });

    testWidgets('5. DietProposalDetailSheet food editing preserves meal details and flags unsaved state', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final aiRepo = AiCoachRepository();
      final dietProposal = AiProposal(
        id: 'prop_diet_edit_test',
        title: 'Elena — Precision Cutting Plan',
        summary: 'Targeted caloric deficit with high protein distribution.',
        type: AiProposalType.diet,
        status: AiProposalStatus.pending,
        reason: 'Optimal fuel for fat loss.',
        createdAt: DateTime.now(),
        clientName: 'Elena Rostova',
        clientId: 'AXG-8819',
        payload: {
          'planKind': 'DIET_PLAN',
          'dailyCalories': 1800,
          'protein': 160,
          'carbohydrates': 170,
          'fat': 45,
          'fiber': 30,
          'waterTargetLiters': 3.5,
          'meals': [
            {
              'mealType': 'Breakfast',
              'timing': '08:00 AM',
              'foods': [
                {
                  'foodId': 'f_elena_1',
                  'foodName': 'Egg Whites',
                  'quantity': 150,
                  'unit': 'ml',
                  'calories': 75,
                  'protein': 16,
                  'carbs': 1,
                  'fat': 0,
                },
              ],
            },
          ],
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DietProposalDetailSheet(
              proposal: dietProposal,
              aiCoachRepository: aiRepo,
              onProposalUpdated: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Egg Whites'), findsOneWidget);
      expect(find.text('150.0 ml • 75 kcal'), findsOneWidget);

      // Tap the edit icon on the food item
      final editIconFinder = find.byIcon(Icons.edit_outlined).first;
      await tester.tap(editIconFinder);
      await tester.pumpAndSettle();

      // Check dialog opened
      expect(find.text('Edit Food Item'), findsOneWidget);
      expect(find.text('Quantity'), findsOneWidget);

      // Enter new quantity (250 ml)
      final qtyInput = find.widgetWithText(TextField, '150');
      await tester.enterText(qtyInput, '250');
      await tester.pumpAndSettle();

      // Save Food in dialog
      final saveFoodBtn = find.text('Save Food');
      await tester.tap(saveFoodBtn);
      await tester.pumpAndSettle();

      // Verify updated quantity displayed and UNSAVED CHANGES badge appears
      expect(find.text('250.0 ml • 75 kcal'), findsOneWidget);
      expect(find.text('UNSAVED CHANGES'), findsOneWidget);
    });
  });
}
