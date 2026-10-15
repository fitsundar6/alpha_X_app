import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_x_gym/features/ai_coach/domain/models/ai_coach_models.dart';
import 'package:alpha_x_gym/features/ai_coach/data/repositories/ai_coach_repository.dart';
import 'package:alpha_x_gym/features/ai_coach/presentation/widgets/admin_three_step_plan_config_dialog.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Admin AI Coach: Three-Step Plan Configuration Tests', () {
    late AiCoachRepository aiCoachRepo;
    late WorkoutRepository workoutRepo;

    setUp(() {
      aiCoachRepo = AiCoachRepository();
      workoutRepo = WorkoutRepository();
    });

    test('1. Workout split templates contains all 20 required templates with correct keys & metadata', () {
      expect(allWorkoutSplits.length, 20);

      final splitIds = allWorkoutSplits.map((s) => s.id).toSet();
      final expectedIds = [
        'full_body',
        'upper_lower',
        'push_pull_legs',
        'ppl_x2',
        'bro_split',
        'chest_back_shoulders_arms_legs',
        'arnold_split',
        'antagonist_split',
        'powerlifting_split',
        'sbd_focus',
        'five_three_one',
        'upper_lower_strength',
        'hypertrophy_specialization',
        'weak_point_focus',
        'upper_lower_arms',
        'full_body_conditioning',
        'strength_conditioning',
        'circuit_training',
        'sports_performance',
        'custom_split',
      ];

      for (final id in expectedIds) {
        expect(splitIds.contains(id), isTrue, reason: 'Missing split id: $id');
      }

      // Check minDays and maxDays
      final ppl = allWorkoutSplits.firstWhere((s) => s.id == 'push_pull_legs');
      expect(ppl.minDays, 3);
      expect(ppl.maxDays, 6);

      final arnold = allWorkoutSplits.firstWhere((s) => s.id == 'arnold_split');
      expect(arnold.displayName, 'Arnold Split');
      expect(arnold.minDays, 3);
      expect(arnold.maxDays, 6);
    });

    testWidgets('2. Step 1: Client selection displays assessment, experience, goals, injuries', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminThreeStepPlanConfigDialog(
              aiCoachRepository: aiCoachRepo,
              workoutRepository: workoutRepo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Step 1 header and clients list
      expect(find.text('PLAN CONFIGURATION ENGINE'), findsOneWidget);
      expect(find.text('STEP 1: SELECT ATHLETE'), findsOneWidget);

      // Verify client search bar
      expect(find.byType(TextField), findsAtLeastNWidgets(1));

      // Tap on an athlete (e.g. Kumar)
      final athleteTile = find.text('Kumar').first;
      expect(athleteTile, findsOneWidget);
      await tester.tap(athleteTile);
      await tester.pumpAndSettle();

      // Verify selected client assessment card is rendered with actual data
      expect(find.textContaining('Kumar'), findsWidgets);
      expect(find.textContaining('Goal'), findsWidgets);
      expect(find.textContaining('Level'), findsWidgets);
      expect(find.textContaining('Equipment'), findsWidgets);
    });

    testWidgets('3. Step 2: Exactly two plan types (AI Workout Proposal & AI Diet / Macro Proposal)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminThreeStepPlanConfigDialog(
              aiCoachRepository: aiCoachRepo,
              workoutRepository: workoutRepo,
              initialClientId: 'AXG-0001',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to Step 2 using continue button
      final continueBtn = find.byKey(const Key('admin_plan_config_continue_button'));
      expect(continueBtn, findsOneWidget);
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      expect(find.text('STEP 2: SELECT PLAN TYPE'), findsOneWidget);

      // Verify EXACTLY two plan types
      expect(find.text('AI Workout Proposal'), findsOneWidget);
      expect(find.text('AI Diet / Macro Proposal'), findsOneWidget);

      // Check cards details
      expect(find.textContaining('Personalized training split'), findsOneWidget);
      expect(find.textContaining('Full meal-by-meal food plan'), findsOneWidget);
    });

    testWidgets('4. Step 3 (Workout): Searchable split selector filters all 20 splits dynamically', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminThreeStepPlanConfigDialog(
              aiCoachRepository: aiCoachRepo,
              workoutRepository: workoutRepo,
              initialClientId: 'AXG-0001',
              initialPlanType: AiProposalType.workout,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Since initialPlanType was supplied, it initialized directly into Step 3
      expect(find.text('STEP 3: CONFIGURE WORKOUT PLAN'), findsOneWidget);

      // Check split selector search field
      final splitSearchField = find.byKey(const Key('admin_split_search_input'));
      expect(splitSearchField, findsOneWidget);

      // Filter splits: type "Arnold"
      await tester.enterText(splitSearchField, 'Arnold');
      await tester.pumpAndSettle();

      expect(find.text('Arnold Split'), findsOneWidget);
      expect(find.text('Full Body'), findsNothing);

      // Tap Arnold Split
      await tester.tap(find.text('Arnold Split'));
      await tester.pumpAndSettle();

      // Clear search
      await tester.enterText(splitSearchField, '');
      await tester.pumpAndSettle();

      // Verify days per week slider and live schedule preview
      expect(find.textContaining('TRAINING DAYS PER WEEK'), findsOneWidget);
      expect(find.textContaining('PRIMARY GOAL'), findsOneWidget);
      expect(find.textContaining('EXPERIENCE'), findsOneWidget);
      expect(find.textContaining('FOCUS MUSCLES & WEAK POINTS'), findsOneWidget);
      expect(find.textContaining('LIVE SCHEDULE PREVIEW'), findsOneWidget);
    });

    testWidgets('5. Step 3 (Workout): Full Proposal Generation and PENDING Staging', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      AiProposal? stagedProposal;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminThreeStepPlanConfigDialog(
              aiCoachRepository: aiCoachRepo,
              workoutRepository: workoutRepo,
              initialClientId: 'AXG-0001',
              onProposalCreated: (p) => stagedProposal = p,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate from Step 1 to Step 2
      final continueBtn = find.byKey(const Key('admin_plan_config_continue_button'));
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      // Step 2: Select AI Workout Proposal (selected by default) and Continue to Step 3
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      expect(find.text('STEP 3: CONFIGURE WORKOUT PLAN'), findsOneWidget);

      // Generate proposal
      final generateBtn = find.byKey(const Key('admin_generate_plan_proposal_button'));
      expect(generateBtn, findsOneWidget);
      await tester.tap(generateBtn);
      await tester.pumpAndSettle();

      // Verify proposal was returned and staged
      expect(stagedProposal, isNotNull);
      expect(stagedProposal!.type, AiProposalType.workout);
      expect(stagedProposal!.status, AiProposalStatus.pending);
      expect(stagedProposal!.payload['weeklySchedule'], isNotNull);
    });

    testWidgets('6. Step 3 (Diet): Full Diet vs Macro-Only plan options and generation', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      AiProposal? stagedProposal;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminThreeStepPlanConfigDialog(
              aiCoachRepository: aiCoachRepo,
              workoutRepository: workoutRepo,
              initialClientId: 'AXG-0001',
              onProposalCreated: (p) => stagedProposal = p,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate from Step 1 to Step 2
      final continueBtn = find.byKey(const Key('admin_plan_config_continue_button'));
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      // Step 2: Select AI Diet / Macro Proposal
      await tester.tap(find.byKey(const Key('plan_type_diet_card')));
      await tester.pumpAndSettle();

      // Navigate to Step 3
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      expect(find.text('STEP 3: CONFIGURE DIET & MACRO PLAN'), findsOneWidget);

      // Verify Full meal-by-meal vs Macro-only toggle
      expect(find.byKey(const Key('toggle_full_diet_plan')), findsOneWidget);
      expect(find.byKey(const Key('toggle_macro_only_plan')), findsOneWidget);

      // Verify Calorie & Macro Target fields
      expect(find.byKey(const Key('diet_calories_input')), findsOneWidget);

      // Toggle to Macro-Only Plan
      await tester.tap(find.byKey(const Key('toggle_macro_only_plan')));
      await tester.pumpAndSettle();

      // Generate Diet proposal
      final generateBtn = find.byKey(const Key('admin_generate_plan_proposal_button'));
      expect(generateBtn, findsOneWidget);
      await tester.tap(generateBtn);
      await tester.pumpAndSettle();

      expect(stagedProposal, isNotNull);
      expect(stagedProposal!.type, AiProposalType.diet);
      expect(stagedProposal!.status, AiProposalStatus.pending);
    });

    testWidgets('7. Step 3 (Diet): Changing nutrition goal dynamically recalculates calories, protein, carbs, fat', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminThreeStepPlanConfigDialog(
              aiCoachRepository: aiCoachRepo,
              workoutRepository: workoutRepo,
              initialClientId: 'AXG-0001',
              initialPlanType: AiProposalType.diet,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('STEP 3: CONFIGURE DIET & MACRO PLAN'), findsOneWidget);

      final caloriesInputFinder = find.byKey(const Key('diet_calories_input'));
      final proteinInputFinder = find.byKey(const Key('diet_protein_input'));
      final carbsInputFinder = find.byKey(const Key('diet_carbs_input'));
      final fatInputFinder = find.byKey(const Key('diet_fat_input'));

      expect(caloriesInputFinder, findsOneWidget);
      expect(proteinInputFinder, findsOneWidget);
      expect(carbsInputFinder, findsOneWidget);
      expect(fatInputFinder, findsOneWidget);

      // Helper to read integer values from input widgets
      int getCalories() => int.parse((tester.widget(caloriesInputFinder) as TextField).controller!.text);
      int getProtein() => int.parse((tester.widget(proteinInputFinder) as TextField).controller!.text);
      int getCarbs() => int.parse((tester.widget(carbsInputFinder) as TextField).controller!.text);
      int getFat() => int.parse((tester.widget(fatInputFinder) as TextField).controller!.text);

      // Initial state: Kumar has Hypertrophy goal -> Lean Muscle Gain / Bulking
      final initialCal = getCalories();
      final initialPro = getProtein();
      final initialCarb = getCarbs();
      final initialFat = getFat();

      // Energy balance verification for initial state
      expect((initialPro * 4 + initialCarb * 4 + initialFat * 9 - initialCal).abs(), lessThanOrEqualTo(2));
      expect(initialCal, greaterThan(2800)); // Lean bulk surplus

      // Helper to change goal in dropdown
      Future<void> selectGoal(String goalName) async {
        final dropdownFinder = find.byType(DropdownButton<String>).first;
        await tester.tap(dropdownFinder);
        await tester.pumpAndSettle();

        final itemFinder = find.text(goalName).last;
        await tester.tap(itemFinder);
        await tester.pumpAndSettle();
      }

      // 1. Switch to 'Fat Loss'
      await selectGoal('Fat Loss');
      final fatLossCal = getCalories();
      final fatLossPro = getProtein();
      final fatLossCarb = getCarbs();
      final fatLossFat = getFat();

      expect(fatLossCal, lessThan(initialCal), reason: 'Fat Loss calories must be lower than Lean Bulk');
      expect(fatLossPro, greaterThanOrEqualTo(initialPro), reason: 'Fat Loss preserves muscle with higher protein ratio');
      expect((fatLossPro * 4 + fatLossCarb * 4 + fatLossFat * 9 - fatLossCal).abs(), lessThanOrEqualTo(2));

      // 2. Switch to 'Athletic Performance'
      await selectGoal('Athletic Performance');
      final athleticCal = getCalories();
      final athleticPro = getProtein();
      final athleticCarb = getCarbs();
      final athleticFat = getFat();

      expect(athleticCarb, greaterThan(fatLossCarb), reason: 'Athletic Performance must prescribe higher carbohydrates');
      expect(athleticCal, greaterThan(fatLossCal), reason: 'Athletic Performance must have higher energy than Fat Loss');
      expect((athleticPro * 4 + athleticCarb * 4 + athleticFat * 9 - athleticCal).abs(), lessThanOrEqualTo(2));

      // 3. Switch to 'Maintenance'
      await selectGoal('Maintenance');
      final maintCal = getCalories();
      final maintPro = getProtein();
      final maintCarb = getCarbs();
      final maintFat = getFat();

      expect(maintCal, greaterThan(fatLossCal), reason: 'Maintenance must be higher than deficit');
      expect(maintCal, lessThan(initialCal), reason: 'Maintenance must be lower than surplus');
      expect((maintPro * 4 + maintCarb * 4 + maintFat * 9 - maintCal).abs(), lessThanOrEqualTo(2));
    });
  });
}
