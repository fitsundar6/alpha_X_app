import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/meal_type.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/food_log_entry.dart';
import 'package:alpha_x_gym/features/macro_planner/data/repositories/macro_repository.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('Section 24 Exact Specification Test', () {
    late MacroRepository repository;
    const testDate = '2026-09-26';

    setUp(() {
      repository = MacroRepository();
      // Clear entries for clean test isolation
      repository.clearEntriesForDate(testDate);
    });

    test('All required foods exist in database with correct per-serving nutrition', () {
      final dosa = repository.allFoods.firstWhere((f) => f.name.toLowerCase() == 'dosa');
      expect(dosa.calories, 130.0);
      expect(dosa.protein, 3.0);
      expect(dosa.carbs, 18.0);
      expect(dosa.fat, 5.0);
      expect(dosa.fiber, 1.0);
      expect(dosa.servingUnit, 'piece');

      final egg = repository.allFoods.firstWhere((f) => f.name.toLowerCase() == 'egg');
      expect(egg.calories, 70.0);
      expect(egg.protein, 6.0);
      expect(egg.fat, 5.0);
      expect(egg.servingUnit, 'piece');

      final chicken = repository.allFoods.firstWhere((f) => f.name.toLowerCase() == 'chicken');
      expect(chicken.calories, 165.0);
      expect(chicken.protein, 31.0);
      expect(chicken.carbs, 0.0);
      expect(chicken.fat, 3.6);
      expect(chicken.servingSize, 100.0);
      expect(chicken.servingUnit, 'g');

      final rice = repository.allFoods.firstWhere((f) => f.name.toLowerCase() == 'rice');
      expect(rice.calories, 130.0);
      expect(rice.protein, 2.7);
      expect(rice.carbs, 28.0);
      expect(rice.fat, 0.3);
      expect(rice.servingSize, 100.0);
      expect(rice.servingUnit, 'g');

      final banana = repository.allFoods.firstWhere((f) => f.name.toLowerCase() == 'banana');
      expect(banana.calories, 105.0);
      expect(banana.protein, 1.3);
      expect(banana.carbs, 27.0);
      expect(banana.fat, 0.3);

      final whey = repository.allFoods.firstWhere((f) => f.name.toLowerCase() == 'whey');
      expect(whey.calories, 120.0);
      expect(whey.protein, 24.0);
      expect(whey.servingUnit, 'scoop');
    });

    test('Add exact meals from Section 24 and verify food, meal, and daily totals', () {
      final clientId = repository.resolveClientId(null);
      final dosa = repository.allFoods.firstWhere((f) => f.name.toLowerCase() == 'dosa');
      final egg = repository.allFoods.firstWhere((f) => f.name.toLowerCase() == 'egg');
      final rice = repository.allFoods.firstWhere((f) => f.name.toLowerCase() == 'rice');
      final chicken = repository.allFoods.firstWhere((f) => f.name.toLowerCase() == 'chicken');
      final banana = repository.allFoods.firstWhere((f) => f.name.toLowerCase() == 'banana');
      final whey = repository.allFoods.firstWhere((f) => f.name.toLowerCase() == 'whey');

      // 1. BREAKFAST: Dosa × 3, Egg × 3
      final bDosa = FoodLogEntry.fromFoodItem(
        clientId: clientId,
        dateString: testDate,
        mealType: MealType.breakfast,
        food: dosa,
        quantity: 3.0,
      );
      final bEgg = FoodLogEntry.fromFoodItem(
        clientId: clientId,
        dateString: testDate,
        mealType: MealType.breakfast,
        food: egg,
        quantity: 3.0,
      );
      repository.logFoodEntry(bDosa);
      repository.logFoodEntry(bEgg);

      // Verify Food Level for Breakfast
      expect(bDosa.totalCalories, 390.0);
      expect(bDosa.totalProtein, 9.0);
      expect(bDosa.totalCarbs, 54.0);
      expect(bDosa.totalFat, 15.0);
      expect(bDosa.totalFiber, 3.0);

      expect(bEgg.totalCalories, 210.0);
      expect(bEgg.totalProtein, 18.0);
      expect(bEgg.totalCarbs, closeTo(1.0, 0.1));
      expect(bEgg.totalFat, 15.0);

      // Verify Breakfast Meal Total
      final breakfastSummary = repository.getMealSummary(testDate, MealType.breakfast);
      expect(breakfastSummary.totalCalories, 600.0);
      expect(breakfastSummary.totalProtein, 27.0);
      expect(breakfastSummary.totalCarbs, closeTo(55.0, 0.1));
      expect(breakfastSummary.totalFat, 30.0);

      // 2. LUNCH: Rice × 200 g (qty: 2), Chicken × 150 g (qty: 1.5)
      final lRice = FoodLogEntry.fromFoodItem(
        clientId: clientId,
        dateString: testDate,
        mealType: MealType.lunch,
        food: rice,
        quantity: 2.0, // 2 x 100g = 200g
      );
      final lChicken = FoodLogEntry.fromFoodItem(
        clientId: clientId,
        dateString: testDate,
        mealType: MealType.lunch,
        food: chicken,
        quantity: 1.5, // 1.5 x 100g = 150g
      );
      repository.logFoodEntry(lRice);
      repository.logFoodEntry(lChicken);

      // Verify Food Level for Lunch
      expect(lRice.quantityDisplay, '200 g');
      expect(lRice.totalCalories, 260.0);
      expect(lRice.totalProtein, closeTo(5.4, 0.05));
      expect(lRice.totalCarbs, 56.0);
      expect(lRice.totalFat, closeTo(0.6, 0.05));

      expect(lChicken.quantityDisplay, '150 g');
      expect(lChicken.totalCalories, 247.5);
      expect(lChicken.totalProtein, 46.5);
      expect(lChicken.totalCarbs, 0.0);
      expect(lChicken.totalFat, closeTo(5.4, 0.05));

      // Verify Lunch Meal Total
      final lunchSummary = repository.getMealSummary(testDate, MealType.lunch);
      expect(lunchSummary.totalCalories, closeTo(507.5, 0.5));
      expect(lunchSummary.totalProtein, closeTo(51.9, 0.1));
      expect(lunchSummary.totalCarbs, 56.0);
      expect(lunchSummary.totalFat, closeTo(6.0, 0.1));

      // 3. SNACK: Banana × 1, Whey × 1 scoop
      final sBanana = FoodLogEntry.fromFoodItem(
        clientId: clientId,
        dateString: testDate,
        mealType: MealType.snack,
        food: banana,
        quantity: 1.0,
      );
      final sWhey = FoodLogEntry.fromFoodItem(
        clientId: clientId,
        dateString: testDate,
        mealType: MealType.snack,
        food: whey,
        quantity: 1.0,
      );
      repository.logFoodEntry(sBanana);
      repository.logFoodEntry(sWhey);

      // Verify Snack Meal Total
      final snackSummary = repository.getMealSummary(testDate, MealType.snack);
      expect(snackSummary.totalCalories, 225.0);
      expect(snackSummary.totalProtein, closeTo(25.3, 0.1));
      expect(snackSummary.totalCarbs, closeTo(29.5, 0.1));
      expect(snackSummary.totalFat, closeTo(1.8, 0.1));

      // 4. DINNER: Dosa × 2, Egg × 2
      final dDosa = FoodLogEntry.fromFoodItem(
        clientId: clientId,
        dateString: testDate,
        mealType: MealType.dinner,
        food: dosa,
        quantity: 2.0,
      );
      final dEgg = FoodLogEntry.fromFoodItem(
        clientId: clientId,
        dateString: testDate,
        mealType: MealType.dinner,
        food: egg,
        quantity: 2.0,
      );
      repository.logFoodEntry(dDosa);
      repository.logFoodEntry(dEgg);

      // Verify Dinner Meal Total
      final dinnerSummary = repository.getMealSummary(testDate, MealType.dinner);
      expect(dinnerSummary.totalCalories, 400.0);
      expect(dinnerSummary.totalProtein, 18.0);
      expect(dinnerSummary.totalCarbs, closeTo(36.7, 0.1));
      expect(dinnerSummary.totalFat, 20.0);

      // 5. DAILY TOTAL & TARGET / CONSUMED / REMAINING
      final dailySummary = repository.getDailyMacroSummary(testDate);

      // Daily Targets
      expect(dailySummary.targetCalories, 2200.0);
      expect(dailySummary.targetProtein, 160.0);
      expect(dailySummary.targetCarbs, 250.0);
      expect(dailySummary.targetFat, 70.0);

      // Consumed
      expect(dailySummary.consumedCalories, closeTo(1732.5, 0.5));
      expect(dailySummary.consumedProtein, closeTo(122.2, 0.2));
      expect(dailySummary.consumedCarbs, closeTo(177.2, 0.2));
      expect(dailySummary.consumedFat, closeTo(57.8, 0.2));

      // Remaining
      expect(dailySummary.safeRemainingCalories, closeTo(467.5, 0.5));
      expect(dailySummary.safeRemainingProtein, closeTo(37.8, 0.2));
      expect(dailySummary.safeRemainingCarbs, closeTo(72.8, 0.2));
      expect(dailySummary.safeRemainingFat, closeTo(12.2, 0.2));

      // Verification that Remaining status strings never show negative
      expect(dailySummary.remainingCaloriesStatus.contains('remaining'), isTrue);
      expect(dailySummary.remainingProteinStatus.contains('remaining'), isTrue);
      expect(dailySummary.remainingCarbsStatus.contains('remaining'), isTrue);
      expect(dailySummary.remainingFatStatus.contains('remaining'), isTrue);

      // Progress percentages
      expect(dailySummary.caloriePercentage, 79);
      expect(dailySummary.proteinPercentage, 76);
      expect(dailySummary.carbPercentage, 71);
      expect(dailySummary.fatPercentage, 83);
    });

    test('Section 10: Target Exceeded does not display negative remaining and shows over target', () {
      final clientId = repository.resolveClientId(null);
      final whey = repository.allFoods.firstWhere((f) => f.name.toLowerCase() == 'whey');

      // Add 8 scoops of whey: 8 * 24g = 192g protein (exceeds 160g target)
      final massiveWhey = FoodLogEntry.fromFoodItem(
        clientId: clientId,
        dateString: testDate,
        mealType: MealType.snack,
        food: whey,
        quantity: 8.0,
      );
      repository.logFoodEntry(massiveWhey);

      final summary = repository.getDailyMacroSummary(testDate);
      expect(summary.consumedProtein, 192.0);
      expect(summary.isProteinOver, isTrue);
      expect(summary.safeRemainingProtein, 0.0); // Never negative
      expect(summary.overProtein, 32.0);
      expect(summary.remainingProteinStatus, '32 g over target');
    });

    test('Real-time Updates: modifying and deleting food immediately recalculates all levels', () {
      final clientId = repository.resolveClientId(null);
      final dosa = repository.allFoods.firstWhere((f) => f.name.toLowerCase() == 'dosa');

      final entry = FoodLogEntry.fromFoodItem(
        clientId: clientId,
        dateString: testDate,
        mealType: MealType.breakfast,
        food: dosa,
        quantity: 1.0,
      );
      repository.logFoodEntry(entry);

      var summary = repository.getDailyMacroSummary(testDate);
      expect(summary.consumedCalories, 130.0);

      // Change quantity to 3
      repository.updateFoodEntryQuantity(entry.id, 3.0);
      summary = repository.getDailyMacroSummary(testDate);
      expect(summary.consumedCalories, 390.0);

      // Delete entry
      repository.deleteFoodEntry(entry.id);
      summary = repository.getDailyMacroSummary(testDate);
      expect(summary.consumedCalories, 0.0);
    });

    test('Date isolation: foods logged for date A do not spill into date B', () {
      final clientId = repository.resolveClientId(null);
      final dosa = repository.allFoods.firstWhere((f) => f.name.toLowerCase() == 'dosa');

      final day1 = '2026-09-25';
      final day2 = '2026-09-26';

      repository.clearEntriesForDate(day1);
      repository.clearEntriesForDate(day2);

      final entry1 = FoodLogEntry.fromFoodItem(
        clientId: clientId,
        dateString: day1,
        mealType: MealType.breakfast,
        food: dosa,
        quantity: 2.0,
      );
      repository.logFoodEntry(entry1);

      final summary1 = repository.getDailyMacroSummary(day1);
      final summary2 = repository.getDailyMacroSummary(day2);

      expect(summary1.consumedCalories, 260.0);
      expect(summary2.consumedCalories, 0.0); // Day 2 has 0 consumed
    });
  });
}
