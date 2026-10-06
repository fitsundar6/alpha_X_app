import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/features/macro_planner/presentation/screens/macro_planner_screen.dart';
import 'package:alpha_x_gym/features/macro_planner/presentation/widgets/daily_macro_progress_dashboard.dart';
import 'package:alpha_x_gym/features/macro_planner/data/repositories/macro_repository.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/meal_type.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/food_item.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/food_log_entry.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/assigned_diet_plan.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/macro_input.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/macro_enums.dart';
import 'package:alpha_x_gym/core/theme/client_theme_service.dart';
import 'package:alpha_x_gym/core/theme/app_theme.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('Macro Option UX Optimization Tests', () {
    late MacroRepository repository;

    setUp(() {
      repository = MacroRepository();
      // Ensure baseline setup exists
      final input = MacroInput(
        age: 28,
        sex: BiologicalSex.male,
        heightCm: 178,
        weightKg: 80,
        activityLevel: ActivityLevel.moderatelyActive,
        goal: NutritionGoal.leanBulk,
      );
      repository.calculateAndSave(input);
    });

    testWidgets('1. Hero Dashboard displays Calories, Protein, Carbs, Fat, Fiber in one compact view', (tester) async {
      final summary = repository.getDailyMacroSummary(repository.getTodayDateString());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: DailyMacroProgressDashboard(summary: summary),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Calories Headline
      expect(find.text('CALORIES'), findsOneWidget);
      expect(find.textContaining('kcal'), findsWidgets);

      // Verify 4-Column Macros
      expect(find.text('PROTEIN'), findsOneWidget);
      expect(find.text('CARBS'), findsOneWidget);
      expect(find.text('FAT'), findsOneWidget);
      expect(find.text('FIBER'), findsOneWidget);
    });

    testWidgets('2. MacroPlannerScreen renders without overflow in Dark Mode', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      ClientThemeService().setThemeMode(ClientThemeMode.dark);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: MacroPlannerScreen(repository: repository),
        ),
      );
      await tester.pumpAndSettle();

      // Check date navigation
      expect(find.textContaining('TODAY'), findsWidgets);

      // Check meal sections exist
      expect(find.text('BREAKFAST'), findsOneWidget);
      expect(find.text('LUNCH'), findsOneWidget);

      // Drag down to check Weekly Body Check-in and Action shortcuts
      await tester.drag(find.byType(ListView).first, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(find.text('WEEKLY BODY CHECK-IN'), findsOneWidget);
      expect(find.text('RECALCULATE'), findsOneWidget);
      expect(find.text('HISTORY'), findsOneWidget);
    });

    testWidgets('3. MacroPlannerScreen renders cleanly without overflow in Light Mode', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      ClientThemeService().setThemeMode(ClientThemeMode.light);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MacroPlannerScreen(repository: repository),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('BREAKFAST'), findsOneWidget);
      await tester.drag(find.byType(ListView).first, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(find.text('WEEKLY BODY CHECK-IN'), findsOneWidget);
    });

    testWidgets('4. Adding food updates meal row and hero dashboard instantly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: MacroPlannerScreen(repository: repository),
        ),
      );
      await tester.pumpAndSettle();

      // Log a food entry to Breakfast
      final today = repository.getTodayDateString();
      final oats = repository.allFoods.firstWhere((f) => f.name.toLowerCase().contains('oats'));
      final entry = FoodLogEntry.fromFoodItem(
        clientId: repository.resolveClientId(null),
        dateString: today,
        mealType: MealType.breakfast,
        food: oats,
        quantity: 1.5,
      );
      repository.logFoodEntry(entry);
      await tester.pumpAndSettle();

      // Verify the food entry is shown under Breakfast
      expect(find.text(oats.name), findsOneWidget);

      // Verify meal count badge matches current logged meals
      final totalLogged = repository.getDailyMacroSummary(today).totalMealsLogged;
      expect(find.text('$totalLogged/4 logged'), findsOneWidget);
    });

    testWidgets('5. Coach Assigned Diet Plan displays Coach badge and opens Prescribed Meals sheet', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final plan = AssignedDietPlan(
        id: 'plan_test_01',
        clientId: 'client_1',
        planName: 'Hypertrophy Phase 1',
        version: 1,
        dailyCalories: 2600,
        protein: 180,
        carbs: 300,
        fat: 75,
        fiber: 35,
        assignedByName: 'Coach Alex',
        notes: 'Drink 4L water daily.',
        createdAt: DateTime.now(),
        meals: [
          PrescribedMeal(
            name: 'Breakfast',
            order: 1,
            timing: '8:00 AM',
            items: [
              PrescribedFoodItem(
                name: 'Eggs',
                quantity: 4,
                unit: 'eggs',
                calories: 280,
                protein: 24,
                carbs: 2,
                fat: 20,
              ),
            ],
          ),
        ],
      );
      repository.setAssignedDietPlan(plan);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: MacroPlannerScreen(repository: repository),
        ),
      );
      await tester.pumpAndSettle();

      // Coach badge should be in the dashboard
      expect(find.textContaining('Hypertrophy Phase 1'), findsWidgets);

      // Tap the Prescribed Meals button to open sheet
      final prescribedButton = find.textContaining('Coach Prescribed Meals & Timings');
      expect(prescribedButton, findsOneWidget);
      await tester.tap(prescribedButton);
      await tester.pumpAndSettle();

      // Verify the sheet opened with meal and food item
      expect(find.text('Eggs'), findsOneWidget);
      expect(find.text('8:00 AM'), findsOneWidget);
    });

    testWidgets('6. Weekly Check-In expands and allows updating body weight', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: MacroPlannerScreen(repository: repository),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to Weekly Body Check-In
      await tester.scrollUntilVisible(
        find.text('WEEKLY BODY CHECK-IN'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Initially collapsed: input fields not visible
      expect(find.text('UPDATE WEIGHT & RECALCULATE'), findsNothing);

      // Tap to expand
      await tester.tap(find.text('WEEKLY BODY CHECK-IN'));
      await tester.pumpAndSettle();

      // Scroll to reveal the expanded form
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -350));
      await tester.pumpAndSettle();

      // Now expanded: input fields and button visible
      expect(find.text('UPDATE WEIGHT & RECALCULATE'), findsOneWidget);
      expect(find.text('Current Weight'), findsOneWidget);
    });
  });
}
