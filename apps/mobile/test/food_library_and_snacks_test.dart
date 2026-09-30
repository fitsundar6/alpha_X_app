import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/meal_type.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/food_item.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/food_log_entry.dart';
import 'package:alpha_x_gym/features/macro_planner/data/food_database.dart';
import 'package:alpha_x_gym/features/macro_planner/data/repositories/macro_repository.dart';
import 'package:alpha_x_gym/core/constants/user_role.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/features/macro_planner/presentation/widgets/add_food_bottom_sheet.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('1. Snacks Category and Catalog Verification', () {
    test('Dedicated Snacks category contains all high-protein snacks', () {
      final snacks = FoodDatabase.defaultFoods.where((f) => f.category == 'Snacks').toList();
      expect(snacks.isNotEmpty, isTrue);

      final snackNames = snacks.map((s) => s.name.toLowerCase()).toList();

      // High-Protein snacks
      expect(snackNames.any((n) => n.contains('boiled eggs')), isTrue, reason: 'Boiled eggs');
      expect(snackNames.any((n) => n.contains('egg whites')), isTrue, reason: 'Egg whites');
      expect(snackNames.any((n) => n.contains('greek yogurt')), isTrue, reason: 'Greek yogurt');
      expect(snackNames.any((n) => n.contains('curd')), isTrue, reason: 'Curd');
      expect(snackNames.any((n) => n.contains('paneer') && !n.contains('low-fat')), isTrue, reason: 'Paneer');
      expect(snackNames.any((n) => n.contains('low-fat paneer')), isTrue, reason: 'Low-fat paneer');
      expect(snackNames.any((n) => n.contains('cottage cheese')), isTrue, reason: 'Cottage cheese');
      expect(snackNames.any((n) => n.contains('whey protein shake')), isTrue, reason: 'Whey protein shake');
      expect(snackNames.any((n) => n.contains('milk')), isTrue, reason: 'Milk');
      expect(snackNames.any((n) => n.contains('protein yogurt')), isTrue, reason: 'Protein yogurt');
    });

    test('Dedicated Snacks category contains all Indian snacks', () {
      final snacks = FoodDatabase.defaultFoods.where((f) => f.category == 'Snacks').toList();
      final snackNames = snacks.map((s) => s.name.toLowerCase()).toList();

      // Indian snacks
      expect(snackNames.any((n) => n.contains('roasted peanuts')), isTrue, reason: 'Roasted peanuts');
      expect(snackNames.any((n) => n.contains('roasted chana')), isTrue, reason: 'Roasted chana');
      expect(snackNames.any((n) => n.contains('sundal')), isTrue, reason: 'Sundal');
      expect(snackNames.any((n) => n.contains('boiled chickpeas')), isTrue, reason: 'Boiled chickpeas');
      expect(snackNames.any((n) => n.contains('boiled green gram')), isTrue, reason: 'Boiled green gram');
      expect(snackNames.any((n) => n.contains('sprouts')), isTrue, reason: 'Sprouts');
      expect(snackNames.any((n) => n.contains('peanut chaat')), isTrue, reason: 'Peanut chaat');
      expect(snackNames.any((n) => n.contains('chickpea chaat')), isTrue, reason: 'Chickpea chaat');
      expect(snackNames.any((n) => n.contains('corn') && n.contains('cob')), isTrue, reason: 'Corn');
      expect(snackNames.any((n) => n.contains('sweet corn')), isTrue, reason: 'Sweet corn');
      expect(snackNames.any((n) => n.contains('makhana')), isTrue, reason: 'Makhana');
    });

    test('Dedicated Snacks category contains all Fruit snacks', () {
      final snacks = FoodDatabase.defaultFoods.where((f) => f.category == 'Snacks').toList();
      final snackNames = snacks.map((s) => s.name.toLowerCase()).toList();

      // Fruit snacks
      expect(snackNames.any((n) => n.contains('apple')), isTrue, reason: 'Apple');
      expect(snackNames.any((n) => n.contains('banana')), isTrue, reason: 'Banana');
      expect(snackNames.any((n) => n.contains('orange')), isTrue, reason: 'Orange');
      expect(snackNames.any((n) => n.contains('guava')), isTrue, reason: 'Guava');
      expect(snackNames.any((n) => n.contains('papaya')), isTrue, reason: 'Papaya');
      expect(snackNames.any((n) => n.contains('watermelon')), isTrue, reason: 'Watermelon');
      expect(snackNames.any((n) => n.contains('pomegranate')), isTrue, reason: 'Pomegranate');
      expect(snackNames.any((n) => n.contains('dates')), isTrue, reason: 'Dates');
      expect(snackNames.any((n) => n.contains('grapes')), isTrue, reason: 'Grapes');
    });

    test('Dedicated Snacks category contains other fitness-friendly snacks', () {
      final snacks = FoodDatabase.defaultFoods.where((f) => f.category == 'Snacks').toList();
      final snackNames = snacks.map((s) => s.name.toLowerCase()).toList();

      // Other common snacks
      expect(snackNames.any((n) => n.contains('peanut butter') && !n.contains('toast')), isTrue, reason: 'Peanut butter');
      expect(snackNames.any((n) => n.contains('almonds')), isTrue, reason: 'Almonds');
      expect(snackNames.any((n) => n.contains('cashews')), isTrue, reason: 'Cashews');
      expect(snackNames.any((n) => n.contains('walnuts')), isTrue, reason: 'Walnuts');
      expect(snackNames.any((n) => n.contains('mixed nuts')), isTrue, reason: 'Mixed nuts');
      expect(snackNames.any((n) => n.contains('oats')), isTrue, reason: 'Oats');
      expect(snackNames.any((n) => n.contains('rice cakes')), isTrue, reason: 'Rice cakes');
      expect(snackNames.any((n) => n.contains('whole wheat bread')), isTrue, reason: 'Whole wheat bread');
      expect(snackNames.any((n) => n.contains('peanut butter toast')), isTrue, reason: 'Peanut butter toast');
    });

    test('All snack items have complete, reliable nutritional values', () {
      final snacks = FoodDatabase.defaultFoods.where((f) => f.category == 'Snacks').toList();
      expect(snacks.length, greaterThanOrEqualTo(35));

      for (final snack in snacks) {
        expect(snack.calories, greaterThan(0), reason: '${snack.name} calories must be > 0');
        expect(snack.protein, greaterThanOrEqualTo(0), reason: '${snack.name} protein must be >= 0');
        expect(snack.carbs, greaterThanOrEqualTo(0), reason: '${snack.name} carbs must be >= 0');
        expect(snack.fat, greaterThanOrEqualTo(0), reason: '${snack.name} fat must be >= 0');
        expect(snack.fiber, greaterThanOrEqualTo(0), reason: '${snack.name} fiber must be >= 0');
        expect(snack.servingSize, greaterThan(0), reason: '${snack.name} serving size must be > 0');
        expect(snack.servingUnit.isNotEmpty, isTrue, reason: '${snack.name} serving unit must not be empty');
        expect(snack.category, 'Snacks');
      }
    });
  });

  group('2. Snacks Category Search and Filter Tests', () {
    late MacroRepository repository;

    setUp(() {
      repository = MacroRepository();
    });

    test('Filter by category "Snacks" returns snacks catalog', () {
      final snacks = repository.searchFoods('', category: 'Snacks');
      expect(snacks.isNotEmpty, isTrue);
      expect(snacks.every((s) => s.category.toLowerCase() == 'snacks'), isTrue);
      expect(snacks.any((s) => s.name.contains('Makhana')), isTrue);
      expect(snacks.any((s) => s.name.contains('Sundal')), isTrue);
    });

    test('Query search finds snack items reliably', () {
      final makhanaResults = repository.searchFoods('makhana');
      expect(makhanaResults.any((f) => f.name.contains('Makhana')), isTrue);

      final eggWhiteResults = repository.searchFoods('egg whites');
      expect(eggWhiteResults.any((f) => f.name.contains('Egg Whites')), isTrue);

      final pbToastResults = repository.searchFoods('peanut butter toast');
      expect(pbToastResults.any((f) => f.name.contains('Peanut Butter Toast')), isTrue);
    });
  });

  group('3. Custom Food Creation, Validation, and Isolation', () {
    late MacroRepository repository;

    setUp(() {
      repository = MacroRepository();
    });

    test('Add custom food with user example (Chicken sandwich: 350 kcal, 25g P, 30g C, 12g F, 4g Fiber)', () async {
      const customItem = FoodItem(
        id: 'custom_chicken_sandwich_001',
        name: 'Chicken sandwich',
        servingSize: 1,
        servingUnit: 'sandwich',
        calories: 350.0,
        protein: 25.0,
        carbs: 30.0,
        fat: 12.0,
        fiber: 4.0,
        category: 'Custom',
        isCustom: true,
      );

      final saved = await repository.addCustomFood(customItem);
      expect(saved.name, 'Chicken sandwich');
      expect(saved.calories, 350.0);
      expect(saved.protein, 25.0);
      expect(saved.carbs, 30.0);
      expect(saved.fat, 12.0);
      expect(saved.fiber, 4.0);
      expect(saved.servingSize, 1);
      expect(saved.servingUnit, 'sandwich');

      // Verify custom food appears in customFoods
      final myCustoms = repository.customFoods;
      expect(myCustoms.any((f) => f.name == 'Chicken sandwich'), isTrue);

      // Verify custom food appears in allFoods
      final allFoods = repository.allFoods;
      expect(allFoods.any((f) => f.name == 'Chicken sandwich'), isTrue);

      // Verify custom food is searchable
      final searchResults = repository.searchFoods('chicken sandwich');
      expect(searchResults.any((f) => f.name == 'Chicken sandwich'), isTrue);
    });

    test('User isolation: Custom foods are NOT mixed between different users', () async {
      AuthService().setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'usera@alphaxgym.com',
        userId: 'user_a_123',
        clientId: 'user_a_123',
      );

      // User A creates a private custom food
      const userACustomFood = FoodItem(
        id: 'custom_user_a_bar',
        name: 'User A Secret Energy Bar',
        servingSize: 1,
        servingUnit: 'piece',
        calories: 220.0,
        protein: 20.0,
        carbs: 15.0,
        fat: 7.0,
        fiber: 3.0,
        createdBy: 'user_a_123',
        isCustom: true,
        isPublic: false,
      );

      await repository.addCustomFood(userACustomFood);

      // Verify User A sees it
      final userAFoods = repository.allFoods.where((f) => f.name == 'User A Secret Energy Bar').toList();
      expect(userAFoods.isNotEmpty, isTrue);

      // Switch session to User B
      AuthService().setAuthenticatedSessionForTesting(
        role: UserRole.client,
        email: 'userb@alphaxgym.com',
        userId: 'user_different_id_999',
        clientId: 'user_different_id_999',
      );

      // Verify User B cannot see User A's private food
      final visibleToUserB = repository.allFoods.any((f) => f.id == 'custom_user_a_bar');
      expect(visibleToUserB, isFalse, reason: 'User A items should not be visible to User B');

      // Clear session after test
      await AuthService().logout();
    });

    test('Custom foods persist across app restarts (SharedPreferences)', () async {
      const customFood = FoodItem(
        id: 'custom_persisted_snack',
        name: 'Homemade Protein Brownie',
        servingSize: 1,
        servingUnit: 'piece',
        calories: 180.0,
        protein: 14.0,
        carbs: 18.0,
        fat: 6.0,
        fiber: 3.0,
        category: 'Custom',
        isCustom: true,
      );

      await repository.addCustomFood(customFood);

      // Simulate app restart by creating a new MacroRepository instance
      final newRepository = MacroRepository();
      // Wait for local cache load
      await Future.delayed(const Duration(milliseconds: 50));

      final restored = newRepository.customFoods;
      expect(restored.any((f) => f.name == 'Homemade Protein Brownie'), isTrue);
    });
  });

  group('4. Food Log Integration with Snacks and Custom Foods', () {
    late MacroRepository repository;
    const testDate = '2026-09-30';

    setUp(() {
      repository = MacroRepository();
    });

    test('Add snack to Snacks meal and calculate nutrition correctly', () {
      final boiledEggs = FoodDatabase.defaultFoods.firstWhere((f) => f.id == 'snack_boiled_eggs');

      // Log 2 boiled eggs to Snacks meal
      final entry = FoodLogEntry.fromFoodItem(
        clientId: repository.resolveClientId(null),
        dateString: testDate,
        mealType: MealType.snack,
        food: boiledEggs,
        quantity: 2.0,
      );

      repository.logFoodEntry(entry);

      // Verify nutrition scaling
      expect(entry.totalCalories, closeTo(156.0, 0.1)); // 78 * 2
      expect(entry.totalProtein, closeTo(12.6, 0.1));   // 6.3 * 2
      expect(entry.totalCarbs, closeTo(1.2, 0.1));      // 0.6 * 2
      expect(entry.totalFat, closeTo(10.6, 0.1));       // 5.3 * 2

      final snackEntries = repository.getMealEntries(testDate, MealType.snack);
      expect(snackEntries.length, 1);
      expect(snackEntries.first.foodName, 'Boiled Eggs');
    });

    test('Add custom food (Chicken sandwich) to Lunch and calculate totals', () async {
      const customItem = FoodItem(
        id: 'custom_sandwich_lunch',
        name: 'Chicken sandwich',
        servingSize: 1,
        servingUnit: 'sandwich',
        calories: 350.0,
        protein: 25.0,
        carbs: 30.0,
        fat: 12.0,
        fiber: 4.0,
        category: 'Custom',
        isCustom: true,
      );

      await repository.addCustomFood(customItem);

      // Log 1.5 sandwiches to Lunch
      final entry = FoodLogEntry.fromFoodItem(
        clientId: repository.resolveClientId(null),
        dateString: testDate,
        mealType: MealType.lunch,
        food: customItem,
        quantity: 1.5,
      );

      repository.logFoodEntry(entry);

      expect(entry.totalCalories, closeTo(525.0, 0.1)); // 350 * 1.5
      expect(entry.totalProtein, closeTo(37.5, 0.1));   // 25 * 1.5
      expect(entry.totalCarbs, closeTo(45.0, 0.1));     // 30 * 1.5
      expect(entry.totalFat, closeTo(18.0, 0.1));       // 12 * 1.5
      expect(entry.totalFiber, closeTo(6.0, 0.1));     // 4 * 1.5

      final lunchEntries = repository.getMealEntries(testDate, MealType.lunch);
      expect(lunchEntries.any((e) => e.foodName == 'Chicken sandwich'), isTrue);
    });

    test('Verify full daily log across Breakfast, Lunch, Snacks, Dinner', () {
      final apple = FoodDatabase.defaultFoods.firstWhere((f) => f.id == 'snack_apple_fresh');
      final roastedChana = FoodDatabase.defaultFoods.firstWhere((f) => f.id == 'snack_roasted_chana');

      // Breakfast: 1 Apple
      repository.logFoodEntry(FoodLogEntry.fromFoodItem(
        clientId: repository.resolveClientId(null),
        dateString: testDate,
        mealType: MealType.breakfast,
        food: apple,
        quantity: 1.0,
      ));

      // Snacks: 2 servings roasted chana (60g)
      repository.logFoodEntry(FoodLogEntry.fromFoodItem(
        clientId: repository.resolveClientId(null),
        dateString: testDate,
        mealType: MealType.snack,
        food: roastedChana,
        quantity: 2.0,
      ));

      final summary = repository.getDailyMacroSummary(testDate);
      expect(summary.consumedCalories, greaterThan(0));
      expect(summary.consumedProtein, greaterThan(0));
      expect(summary.consumedCarbs, greaterThan(0));
      expect(summary.consumedFat, greaterThan(0));
      expect(summary.consumedFiber, greaterThan(0));
    });
  });

  group('5. UI Top-Right [+ Custom] Button in Food Library', () {
    testWidgets('Food Library displays "Food Library" title and top-right [+ Custom] button', (tester) async {
      final repository = MacroRepository();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: AddFoodBottomSheet(
              repository: repository,
              mealType: MealType.snack,
              dateString: '2026-09-30',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Food Library title
      expect(find.text('Food Library'), findsOneWidget);

      // Verify top-right [+ Custom] button
      expect(find.byKey(const Key('add_custom_food_top_button')), findsOneWidget);
      expect(find.text('Custom'), findsAtLeastNWidgets(1));

      // Verify Snacks category chip exists
      expect(find.text('Snacks'), findsAtLeastNWidgets(1));
    });
  });
}
