import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/meal_type.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/food_item.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/food_log_entry.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/daily_macro_summary.dart';
import 'package:alpha_x_gym/features/macro_planner/data/food_database.dart';
import 'package:alpha_x_gym/features/macro_planner/data/repositories/macro_repository.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('FoodDatabase Catalog Tests', () {
    test('Contains standard Indian breakfast and fitness staples', () {
      final foods = FoodDatabase.defaultFoods;
      expect(foods.length, greaterThanOrEqualTo(35));

      final names = foods.map((f) => f.name.toLowerCase()).toList();
      expect(names.any((n) => n.contains('dosa')), isTrue);
      expect(names.any((n) => n.contains('idli')), isTrue);
      expect(names.any((n) => n.contains('chapati')), isTrue);
      expect(names.any((n) => n.contains('poori')), isTrue);
      expect(names.any((n) => n.contains('pongal')), isTrue);
      expect(names.any((n) => n.contains('upma')), isTrue);
      expect(names.any((n) => n.contains('egg')), isTrue);
      expect(names.any((n) => n.contains('rice')), isTrue);
      expect(names.any((n) => n.contains('chicken')), isTrue);
      expect(names.any((n) => n.contains('whey')), isTrue);
      expect(names.any((n) => n.contains('paneer')), isTrue);
      expect(names.any((n) => n.contains('banana')), isTrue);
    });

    test('Foods have appropriate non-rigid serving units', () {
      final dosa = FoodDatabase.defaultFoods.firstWhere((f) => f.name.contains('Plain Dosa'));
      expect(dosa.servingUnit, 'piece');

      final rice = FoodDatabase.defaultFoods.firstWhere((f) => f.name.contains('White Rice'));
      expect(rice.servingUnit.isNotEmpty, isTrue);

      final whey = FoodDatabase.defaultFoods.firstWhere((f) => f.name.toLowerCase().contains('whey'));
      expect(whey.servingUnit.isNotEmpty, isTrue);

      final chicken = FoodDatabase.defaultFoods.firstWhere((f) => f.name.contains('Chicken Breast'));
      expect(chicken.servingUnit, 'grams');
    });
  });

  group('Smart Food Search Tests', () {
    late MacroRepository repository;

    setUp(() {
      repository = MacroRepository();
    });

    test('Partial search for "dosa" returns all dosa variations', () {
      final results = repository.searchFoods('dosa');
      expect(results.length, greaterThanOrEqualTo(3));
      for (final r in results) {
        expect(r.name.toLowerCase(), contains('dosa'));
      }
    });

    test('Case-insensitive search returns matching items', () {
      final lower = repository.searchFoods('egg');
      final upper = repository.searchFoods('EGG');
      expect(lower.length, equals(upper.length));
    });

    test('Category filtering narrows search results', () {
      final breakfastFoods = repository.searchFoods('', category: 'Breakfast');
      for (final f in breakfastFoods) {
        expect(f.category, equals('Breakfast'));
      }
    });
  });

  group('Dynamic Nutrition Multiplier Tests', () {
    test('Calculates exact nutrition based on quantity for Dosa (Prompt Example)', () {
      const dosa = FoodItem(
        id: 'test_dosa',
        name: 'Dosa',
        servingSize: 1,
        servingUnit: 'piece',
        calories: 130,
        protein: 3.0,
        carbs: 18.0,
        fat: 5.0,
      );

      // Quantity 1
      final single = FoodLogEntry.fromFoodItem(
        clientId: 'client_01',
        dateString: '2026-09-25',
        mealType: MealType.breakfast,
        food: dosa,
        quantity: 1.0,
      );
      expect(single.totalCalories, equals(130.0));
      expect(single.totalProtein, equals(3.0));
      expect(single.totalCarbs, equals(18.0));
      expect(single.totalFat, equals(5.0));

      // Quantity 3 (Prompt Requirement 6: 390 kcal, 9g protein, 54g carbs, 15g fat)
      final triple = single.copyWith(quantity: 3.0);
      expect(triple.totalCalories, equals(390.0));
      expect(triple.totalProtein, equals(9.0));
      expect(triple.totalCarbs, equals(54.0));
      expect(triple.totalFat, equals(15.0));
    });
  });

  group('Meal Totals and Daily Summary Tests', () {
    late MacroRepository repository;
    const testDate = '2026-10-01';
    const testClient = 'test_athlete_01';

    setUp(() {
      repository = MacroRepository();
    });

    test('Calculates independent meal totals and aggregates daily dashboard', () {
      const dosa = FoodItem(
        id: 'test_dosa',
        name: 'Dosa',
        servingSize: 1,
        servingUnit: 'piece',
        calories: 130,
        protein: 3.0,
        carbs: 18.0,
        fat: 5.0,
      );

      const boiledEgg = FoodItem(
        id: 'test_egg',
        name: 'Boiled Egg',
        servingSize: 1,
        servingUnit: 'large egg',
        calories: 74,
        protein: 6.3,
        carbs: 0.4,
        fat: 5.0,
      );

      // Log 3 Dosa and 3 Boiled Eggs for Breakfast
      repository.logFoodEntry(FoodLogEntry.fromFoodItem(
        clientId: testClient,
        dateString: testDate,
        mealType: MealType.breakfast,
        food: dosa,
        quantity: 3.0,
      ));

      repository.logFoodEntry(FoodLogEntry.fromFoodItem(
        clientId: testClient,
        dateString: testDate,
        mealType: MealType.breakfast,
        food: boiledEgg,
        quantity: 3.0,
      ));

      final breakfastSummary = repository.getMealSummary(testDate, MealType.breakfast, clientId: testClient);
      // 390 + 222 = 612 kcal
      expect(breakfastSummary.totalCalories, closeTo(612.0, 0.1));
      // 9 + 18.9 = 27.9 g
      expect(breakfastSummary.totalProtein, closeTo(27.9, 0.1));
      // 54 + 1.2 = 55.2 g
      expect(breakfastSummary.totalCarbs, closeTo(55.2, 0.1));
      // 15 + 15 = 30.0 g
      expect(breakfastSummary.totalFat, closeTo(30.0, 0.1));

      // Daily summary should reflect the same
      final dailySummary = repository.getDailyMacroSummary(testDate, clientId: testClient);
      expect(dailySummary.consumedCalories, closeTo(612.0, 0.1));
      expect(dailySummary.consumedProtein, closeTo(27.9, 0.1));
    });

    test('Updating food quantity modifies meal and daily totals immediately', () {
      const dosa = FoodItem(
        id: 'test_dosa',
        name: 'Dosa',
        servingSize: 1,
        servingUnit: 'piece',
        calories: 130,
        protein: 3.0,
        carbs: 18.0,
        fat: 5.0,
      );

      final entry = FoodLogEntry.fromFoodItem(
        clientId: testClient,
        dateString: testDate,
        mealType: MealType.dinner,
        food: dosa,
        quantity: 1.0,
      );

      repository.logFoodEntry(entry);

      var summary = repository.getMealSummary(testDate, MealType.dinner, clientId: testClient);
      expect(summary.totalCalories, equals(130.0));

      // Client changes 1 -> 3
      repository.updateFoodEntryQuantity(entry.id, 3.0);
      summary = repository.getMealSummary(testDate, MealType.dinner, clientId: testClient);
      expect(summary.totalCalories, equals(390.0));
      expect(summary.totalProtein, equals(9.0));
    });

    test('Deleting an item removes only that entry and preserves other items in meal', () {
      const dosa = FoodItem(
        id: 'test_dosa',
        name: 'Dosa',
        servingSize: 1,
        servingUnit: 'piece',
        calories: 130,
        protein: 3.0,
        carbs: 18.0,
        fat: 5.0,
      );

      const milk = FoodItem(
        id: 'test_milk',
        name: 'Milk',
        servingSize: 250,
        servingUnit: 'ml',
        calories: 150,
        protein: 8.0,
        carbs: 12.0,
        fat: 8.0,
      );

      final entryKeep = FoodLogEntry.fromFoodItem(
        clientId: testClient,
        dateString: testDate,
        mealType: MealType.snack,
        food: milk,
        quantity: 1.0,
      );

      final entryDelete = FoodLogEntry.fromFoodItem(
        clientId: testClient,
        dateString: testDate,
        mealType: MealType.snack,
        food: dosa,
        quantity: 2.0,
      );

      repository.logFoodEntry(entryKeep);
      repository.logFoodEntry(entryDelete);

      expect(repository.getMealEntries(testDate, MealType.snack, clientId: testClient).length, equals(2));

      // Delete only the dosa
      repository.deleteFoodEntry(entryDelete.id);

      final remainingEntries = repository.getMealEntries(testDate, MealType.snack, clientId: testClient);
      expect(remainingEntries.length, equals(1));
      expect(remainingEntries.first.id, equals(entryKeep.id));
      expect(remainingEntries.first.foodName, equals('Milk'));
    });
  });

  group('Remaining Macros and Overages Tests', () {
    test('Accurately computes remaining macros and flags overages (Prompt Requirement 8)', () {
      final summary = DailyMacroSummary(
        dateString: '2026-09-25',
        targetCalories: 2200.0,
        targetProtein: 160.0,
        targetCarbs: 250.0,
        targetFat: 70.0,
        consumedCalories: 1450.0,
        consumedProtein: 175.0, // Over target!
        consumedCarbs: 180.0,
        consumedFat: 45.0,
        mealSummaries: {},
      );

      // Remaining Calories: 2200 - 1450 = 750
      expect(summary.remainingCalories, equals(750.0));
      expect(summary.hasOverCalories, isFalse);

      // Remaining Carbs: 250 - 180 = 70
      expect(summary.remainingCarbs, equals(70.0));
      expect(summary.hasOverCarbs, isFalse);

      // Remaining Fat: 70 - 45 = 25
      expect(summary.remainingFat, equals(25.0));
      expect(summary.hasOverFat, isFalse);

      // Protein: 175 / 160 -> +15 g over!
      expect(summary.hasOverProtein, isTrue);
      expect(summary.overProtein, equals(15.0));
    });
  });

  group('Custom Food Tests', () {
    late MacroRepository repository;

    setUp(() {
      repository = MacroRepository();
    });

    test('Creates, searches, and preserves custom food item (Prompt Requirement 5)', () {
      const customChickenCurry = FoodItem(
        id: 'custom_curry_01',
        name: 'Homemade Chicken Curry',
        servingSize: 100,
        servingUnit: 'g',
        calories: 180,
        protein: 20.0,
        carbs: 5.0,
        fat: 8.0,
        category: 'Custom',
      );

      repository.addCustomFood(customChickenCurry);

      final searchResults = repository.searchFoods('curry');
      expect(searchResults.any((f) => f.name == 'Homemade Chicken Curry'), isTrue);

      final saved = searchResults.firstWhere((f) => f.name == 'Homemade Chicken Curry');
      expect(saved.isCustom, isTrue);
      expect(saved.calories, equals(180));
      expect(saved.protein, equals(20.0));
      expect(saved.carbs, equals(5.0));
      expect(saved.fat, equals(8.0));
    });
  });

  group('Date Tracking and Isolation Tests', () {
    late MacroRepository repository;
    const client = 'test_athlete_02';

    setUp(() {
      repository = MacroRepository();
    });

    test('Maintains separate logs per date without overwriting', () {
      const apple = FoodItem(
        id: 'apple_01',
        name: 'Apple',
        servingSize: 1,
        servingUnit: 'medium piece',
        calories: 95,
        protein: 0.5,
        carbs: 25.0,
        fat: 0.3,
      );

      // Day 1
      repository.logFoodEntry(FoodLogEntry.fromFoodItem(
        clientId: client,
        dateString: '2026-09-24',
        mealType: MealType.snack,
        food: apple,
        quantity: 1.0,
      ));

      // Day 2
      repository.logFoodEntry(FoodLogEntry.fromFoodItem(
        clientId: client,
        dateString: '2026-09-25',
        mealType: MealType.snack,
        food: apple,
        quantity: 3.0,
      ));

      final day1Summary = repository.getDailyMacroSummary('2026-09-24', clientId: client);
      final day2Summary = repository.getDailyMacroSummary('2026-09-25', clientId: client);
      final day3Summary = repository.getDailyMacroSummary('2026-09-26', clientId: client);

      expect(day1Summary.consumedCalories, equals(95.0));
      expect(day2Summary.consumedCalories, equals(285.0));
      expect(day3Summary.consumedCalories, equals(0.0));
    });
  });
}
