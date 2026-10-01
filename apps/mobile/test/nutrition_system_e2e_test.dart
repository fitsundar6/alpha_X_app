import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/meal_type.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/food_item.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/food_log_entry.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/assigned_diet_plan.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/scanned_food_detection.dart';
import 'package:alpha_x_gym/features/macro_planner/data/repositories/macro_repository.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('Alpha X Nutrition System - Integration & Data Flow Tests', () {
    late MacroRepository repository;

    setUp(() {
      repository = MacroRepository();
    });

    test('1. Admin creates and assigns structured diet plan with versioning', () {
      final v1Plan = AssignedDietPlan(
        id: 'diet_plan_001',
        clientId: 'client_alpha_1',
        planName: 'Alpha X Lean Recomp Protocol v1',
        version: 1,
        dailyCalories: 2200,
        protein: 160.0,
        carbs: 220.0,
        fat: 65.0,
        fiber: 30.0,
        waterTarget: 3.5,
        notes: 'Strict hydration; no processed carbs after 8 PM.',
        assignedByName: 'Coach Master Admin',
        meals: [
          PrescribedMeal(
            name: 'Breakfast',
            order: 1,
            timing: '08:00 AM',
            items: [
              PrescribedFoodItem(
                name: 'Rolled Oats with Whey & Blueberries',
                quantity: 1.0,
                unit: 'bowl',
                calories: 450.0,
                protein: 35.0,
                carbs: 55.0,
                fat: 8.0,
                fiber: 7.0,
              ),
            ],
          ),
          PrescribedMeal(
            name: 'Lunch',
            order: 2,
            timing: '01:30 PM',
            items: [
              PrescribedFoodItem(
                name: 'Grilled Chicken Breast & Jasmine Rice',
                quantity: 1.0,
                unit: 'plate',
                calories: 600.0,
                protein: 50.0,
                carbs: 70.0,
                fat: 12.0,
                fiber: 4.0,
              ),
            ],
          ),
          PrescribedMeal(
            name: 'Snacks',
            order: 3,
            timing: '05:00 PM',
            items: [
              PrescribedFoodItem(
                name: 'Greek Yogurt with Almonds',
                quantity: 1.0,
                unit: 'cup',
                calories: 250.0,
                protein: 20.0,
                carbs: 15.0,
                fat: 10.0,
                fiber: 3.0,
              ),
            ],
          ),
          PrescribedMeal(
            name: 'Dinner',
            order: 4,
            timing: '08:30 PM',
            items: [
              PrescribedFoodItem(
                name: 'Baked Salmon with Sweet Potato',
                quantity: 1.0,
                unit: 'fillet',
                calories: 550.0,
                protein: 42.0,
                carbs: 45.0,
                fat: 18.0,
                fiber: 6.0,
              ),
            ],
          ),
        ],
        createdAt: DateTime.now(),
      );

      repository.setAssignedDietPlan(v1Plan);

      expect(repository.hasAssignedDietPlan, isTrue);
      expect(repository.assignedDietPlan?.version, 1);
      expect(repository.assignedDietPlan?.dailyCalories, 2200);
      expect(repository.assignedDietPlan?.protein, 160.0);
      expect(repository.assignedDietPlan?.meals.length, 4);
      expect(repository.assignedDietPlan?.meals.first.timing, '08:00 AM');
    });

    test('2. Strict separation: Actual Food Logging does NOT overwrite Assigned Diet', () {
      final prescribedPlan = AssignedDietPlan(
        id: 'diet_plan_001',
        clientId: 'client_alpha_1',
        planName: 'Prescribed Recomp Diet',
        version: 1,
        dailyCalories: 2200,
        protein: 160.0,
        carbs: 220.0,
        fat: 65.0,
        fiber: 30.0,
        waterTarget: 3.5,
        meals: const [],
        createdAt: DateTime.now(),
      );

      repository.setAssignedDietPlan(prescribedPlan);

      // Client eats food from Food Library
      final foodFromLib = repository.allFoods.firstWhere((f) => f.name.contains('Chicken Breast') || f.name.contains('Egg'));
      final log1 = FoodLogEntry.fromFoodItem(
        clientId: 'client_alpha_1',
        dateString: '2026-10-01',
        mealType: MealType.lunch,
        food: foodFromLib,
        quantity: 1.5,
        source: 'FOOD_LIBRARY',
      );
      repository.logFoodEntry(log1);

      // Client eats custom snack
      final customSnack = FoodItem(
        id: 'snack_protein_bar',
        name: 'Alpha X Crunchy Protein Bar',
        category: 'Snacks',
        servingUnit: 'bar',
        servingSize: 60.0,
        calories: 220.0,
        protein: 21.0,
        carbs: 22.0,
        fat: 7.0,
        fiber: 10.0,
        isCustom: true,
      );
      final log2 = FoodLogEntry.fromFoodItem(
        clientId: 'client_alpha_1',
        dateString: '2026-10-01',
        mealType: MealType.snack,
        food: customSnack,
        quantity: 1.0,
        source: 'CUSTOM_FOOD',
      );
      repository.logFoodEntry(log2);

      // Client logs food from AI Live Camera
      final scannedMeal = const ScannedFoodItem(
        name: 'Grilled Salmon with Asparagus',
        category: 'Fish & Seafood',
        estimatedGrams: 200.0,
        servingDisplay: '200 g',
        calories: 380.0,
        protein: 40.0,
        carbs: 4.0,
        fat: 20.0,
        fiber: 3.0,
        confidence: 0.94,
        isEstimate: true,
        source: 'AI_CAMERA',
      );
      final log3 = scannedMeal.toFoodLogEntry(
        clientId: 'client_alpha_1',
        dateString: '2026-10-01',
        mealType: MealType.dinner,
      );
      repository.logFoodEntry(log3);

      // VERIFY ASSIGNED DIET IS UNCHANGED & INTACT
      expect(repository.assignedDietPlan?.dailyCalories, 2200, reason: 'Assigned diet must never mutate when actual food is logged');
      expect(repository.assignedDietPlan?.protein, 160.0);
      expect(repository.assignedDietPlan?.version, 1);

      // VERIFY ACTUAL LOGS ARE RECORDED ACCURATELY
      final loggedEntries = repository.getFoodEntriesForDate('2026-10-01', clientId: 'client_alpha_1');
      expect(loggedEntries.length, 3);
      expect(loggedEntries.any((e) => e.source == 'FOOD_LIBRARY'), isTrue);
      expect(loggedEntries.any((e) => e.source == 'CUSTOM_FOOD'), isTrue);
      expect(loggedEntries.any((e) => e.source == 'AI_CAMERA' && e.isAiConfirmed), isTrue);
    });

    test('3. Target-vs-Actual Nutrition Comparison calculates factual deltas', () {
      final prescribedPlan = AssignedDietPlan(
        id: 'diet_plan_001',
        clientId: 'client_alpha_1',
        planName: 'Alpha X Maintenance Protocol',
        version: 1,
        dailyCalories: 2200,
        protein: 160.0,
        carbs: 220.0,
        fat: 65.0,
        fiber: 30.0,
        waterTarget: 3.0,
        meals: const [],
        createdAt: DateTime.now(),
      );
      repository.setAssignedDietPlan(prescribedPlan);

      // Log 142g of actual protein
      final entry = FoodLogEntry(
        id: 'log_prot_1',
        clientId: 'client_alpha_1',
        dateString: '2026-10-01',
        mealType: MealType.lunch,
        foodId: 'f_chicken',
        foodName: 'Chicken Breast Platter',
        quantity: 1.0,
        servingUnit: 'plate',
        servingSize: 400.0,
        baseCalories: 1850.0,
        baseProtein: 142.0,
        baseCarbs: 180.0,
        baseFat: 55.0,
        baseFiber: 22.0,
        source: 'FOOD_LIBRARY',
        isAiConfirmed: true,
        category: 'Protein',
        createdAt: DateTime.now(),
      );
      repository.logFoodEntry(entry);

      final summary = repository.getDailyMacroSummary('2026-10-01', clientId: 'client_alpha_1');

      // Verify Target values come from prescribed diet
      expect(summary.targetCalories, 2200.0);
      expect(summary.targetProtein, 160.0);
      expect(summary.targetCarbs, 220.0);
      expect(summary.targetFat, 65.0);
      expect(summary.targetFiber, 30.0);

      // Verify Actual values come from logged foods
      expect(summary.consumedCalories, 1850.0);
      expect(summary.consumedProtein, 142.0);
      expect(summary.consumedCarbs, 180.0);
      expect(summary.consumedFat, 55.0);
      expect(summary.consumedFiber, 22.0);

      // Verify Factual Comparison Delta: Assigned 160g vs Actual 142g = -18g
      final proteinDelta = summary.consumedProtein - summary.targetProtein;
      expect(proteinDelta, -18.0);

      // Calorie Delta: 1850 - 2200 = -350 kcal
      final calDelta = summary.consumedCalories - summary.targetCalories;
      expect(calDelta, -350.0);
    });

    test('4. Complete Data Isolation between multiple clients', () {
      final clientA = 'client_john_001';
      final clientB = 'client_sarah_002';

      // Log meal for Client A
      final entryA = FoodLogEntry(
        id: 'entry_a_1',
        clientId: clientA,
        dateString: '2026-10-01',
        mealType: MealType.breakfast,
        foodId: 'f_eggs',
        foodName: 'Client A Eggs',
        quantity: 2.0,
        servingUnit: 'egg',
        servingSize: 50.0,
        baseCalories: 78.0,
        baseProtein: 6.3,
        baseCarbs: 0.6,
        baseFat: 5.3,
        source: 'FOOD_LIBRARY',
        createdAt: DateTime.now(),
      );
      repository.logFoodEntry(entryA);

      // Log meal for Client B
      final entryB = FoodLogEntry(
        id: 'entry_b_1',
        clientId: clientB,
        dateString: '2026-10-01',
        mealType: MealType.lunch,
        foodId: 'f_steak',
        foodName: 'Client B Steak',
        quantity: 1.0,
        servingUnit: 'steak',
        servingSize: 250.0,
        baseCalories: 600.0,
        baseProtein: 55.0,
        baseCarbs: 0.0,
        baseFat: 35.0,
        source: 'FOOD_LIBRARY',
        createdAt: DateTime.now(),
      );
      repository.logFoodEntry(entryB);

      // Verify Client A cannot see Client B entries
      final entriesForA = repository.getFoodEntriesForDate('2026-10-01', clientId: clientA);
      expect(entriesForA.length, 1);
      expect(entriesForA.first.clientId, clientA);
      expect(entriesForA.first.foodName, 'Client A Eggs');

      // Verify Client B cannot see Client A entries
      final entriesForB = repository.getFoodEntriesForDate('2026-10-01', clientId: clientB);
      expect(entriesForB.length, 1);
      expect(entriesForB.first.clientId, clientB);
      expect(entriesForB.first.foodName, 'Client B Steak');
    });

    test('5. Admin updates diet plan creates new version and maintains history', () {
      final v1 = AssignedDietPlan(
        id: 'diet_001_v1',
        clientId: 'client_alpha_1',
        planName: 'Bulking Phase 1',
        version: 1,
        dailyCalories: 2800,
        protein: 180.0,
        carbs: 350.0,
        fat: 75.0,
        fiber: 35.0,
        waterTarget: 4.0,
        assignedByName: 'Head Coach',
        meals: const [],
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
      );
      repository.setAssignedDietPlan(v1);

      expect(repository.assignedDietPlan?.version, 1);
      expect(repository.assignedDietPlan?.dailyCalories, 2800);

      // Coach transitions client to Cutting Phase 2
      final v2 = AssignedDietPlan(
        id: 'diet_001_v2',
        clientId: 'client_alpha_1',
        planName: 'Cutting Phase 2',
        version: 2,
        dailyCalories: 2100,
        protein: 190.0,
        carbs: 180.0,
        fat: 60.0,
        fiber: 35.0,
        waterTarget: 4.0,
        assignedByName: 'Head Coach',
        notes: 'Deficit phase: keep protein high, reduce carbs.',
        meals: const [],
        createdAt: DateTime.now(),
      );
      repository.setAssignedDietPlan(v2);

      expect(repository.assignedDietPlan?.version, 2);
      expect(repository.assignedDietPlan?.planName, 'Cutting Phase 2');
      expect(repository.assignedDietPlan?.dailyCalories, 2100);
      expect(repository.assignedDietPlan?.protein, 190.0);
    });
  });
}
