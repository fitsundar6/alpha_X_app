import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/assigned_diet_plan.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/food_item.dart';

void main() {
  group('Admin Diet Assignment — Quantity & Serving Calculations', () {
    test('1. Oats 60g calculation (base 100g: 389 kcal, 16.9g P, 66.3g C, 6.9g F)', () {
      const oats = FoodItem(
        id: 'food_oats',
        name: 'Oats',
        servingSize: 100,
        servingUnit: 'g',
        calories: 389.0,
        protein: 16.9,
        carbs: 66.3,
        fat: 6.9,
        fiber: 10.6,
      );

      final nutrition = PrescribedFoodItem.calculateNutrition(
        food: oats,
        quantity: 60.0,
        unit: 'g',
        servings: 1.0,
      );

      // 389 * 0.6 = 233.4
      expect(nutrition['calories']!, closeTo(233.4, 0.1));
      // 16.9 * 0.6 = 10.14
      expect(nutrition['protein']!, closeTo(10.14, 0.1));
      // 66.3 * 0.6 = 39.78
      expect(nutrition['carbs']!, closeTo(39.78, 0.1));
      // 6.9 * 0.6 = 4.14
      expect(nutrition['fat']!, closeTo(4.14, 0.1));

      final display = PrescribedFoodItem.formatServingDisplay(
        quantity: 60.0,
        unit: 'g',
        servings: 1.0,
      );
      expect(display, '60 g — 1 serving');
    });

    test('2. Chicken Breast 150g calculation (base 100g: 165 kcal, 31g P, 0g C, 3.6g F)', () {
      const chicken = FoodItem(
        id: 'food_chicken',
        name: 'Chicken Breast',
        servingSize: 100,
        servingUnit: 'g',
        calories: 165.0,
        protein: 31.0,
        carbs: 0.0,
        fat: 3.6,
        fiber: 0.0,
      );

      final nutrition = PrescribedFoodItem.calculateNutrition(
        food: chicken,
        quantity: 150.0,
        unit: 'g',
        servings: 1.0,
      );

      // 165 * 1.5 = 247.5 (~248 kcal)
      expect(nutrition['calories']!.round(), 248);
      // 31 * 1.5 = 46.5
      expect(nutrition['protein']!, closeTo(46.5, 0.1));
      // 0 * 1.5 = 0.0
      expect(nutrition['carbs']!, 0.0);
      // 3.6 * 1.5 = 5.4
      expect(nutrition['fat']!, closeTo(5.4, 0.1));
    });

    test('3. Piece-based food: Eggs 2 pieces (base 1 piece: 70 kcal, 6g P, 0.33g C, 5g F)', () {
      const egg = FoodItem(
        id: 'food_egg',
        name: 'Egg',
        servingSize: 1,
        servingUnit: 'piece',
        calories: 70.0,
        protein: 6.0,
        carbs: 0.33,
        fat: 5.0,
      );

      final nutrition = PrescribedFoodItem.calculateNutrition(
        food: egg,
        quantity: 2.0,
        unit: 'piece',
        servings: 2.0,
      );

      expect(nutrition['calories']!, 140.0);
      expect(nutrition['protein']!, 12.0);
      expect(nutrition['carbs']!, closeTo(0.66, 0.01));
      expect(nutrition['fat']!, 10.0);

      final display = PrescribedFoodItem.formatServingDisplay(
        quantity: 2.0,
        unit: 'piece',
        servings: 2.0,
      );
      expect(display, '2 pieces');
    });

    test('4. Liquid-based food: Milk 250ml (base 100ml: 60 kcal, 3.2g P, 4.8g C, 3.2g F)', () {
      const milk = FoodItem(
        id: 'food_milk',
        name: 'Milk',
        servingSize: 100,
        servingUnit: 'ml',
        calories: 60.0,
        protein: 3.2,
        carbs: 4.8,
        fat: 3.2,
      );

      final nutrition = PrescribedFoodItem.calculateNutrition(
        food: milk,
        quantity: 250.0,
        unit: 'ml',
        servings: 1.0,
      );

      // 60 * 2.5 = 150
      expect(nutrition['calories']!, 150.0);
      // 3.2 * 2.5 = 8.0
      expect(nutrition['protein']!, 8.0);
      // 4.8 * 2.5 = 12.0
      expect(nutrition['carbs']!, 12.0);
      // 3.2 * 2.5 = 8.0
      expect(nutrition['fat']!, 8.0);

      final display = PrescribedFoodItem.formatServingDisplay(
        quantity: 250.0,
        unit: 'ml',
        servings: 1.0,
      );
      expect(display, '250 ml — 1 serving');
    });

    test('5. Multi-food meal prescription with Breakfast, Lunch, Snack, Dinner', () {
      final breakfast = PrescribedMeal(
        mealType: 'Breakfast',
        timing: '8:00 AM',
        foods: [
          const PrescribedFoodItem(
            name: 'Oats',
            quantity: 60.0,
            unit: 'g',
            servings: 1.0,
            calories: 233.4,
            protein: 10.1,
            carbs: 39.8,
            fat: 4.1,
            servingDisplay: '60 g — 1 serving',
          ),
          const PrescribedFoodItem(
            name: 'Eggs',
            quantity: 3.0,
            unit: 'piece',
            servings: 3.0,
            calories: 210.0,
            protein: 18.0,
            carbs: 1.0,
            fat: 15.0,
            servingDisplay: '3 pieces',
          ),
          const PrescribedFoodItem(
            name: 'Milk',
            quantity: 250.0,
            unit: 'ml',
            servings: 1.0,
            calories: 150.0,
            protein: 8.0,
            carbs: 12.0,
            fat: 8.0,
            servingDisplay: '250 ml — 1 serving',
          ),
        ],
      );

      expect(breakfast.foods.length, 3);
      expect(breakfast.totalCalories, closeTo(593.4, 0.1));
      expect(breakfast.totalProtein, closeTo(36.1, 0.1));

      // Client display verification
      expect(breakfast.foods[0].simpleQuantityDisplay, '60 g');
      expect(breakfast.foods[1].simpleQuantityDisplay, '3 pieces');
      expect(breakfast.foods[2].simpleQuantityDisplay, '250 ml');

      // Emojis
      expect(PrescribedFoodItem.getFoodEmoji('Oats'), '🥣');
      expect(PrescribedFoodItem.getFoodEmoji('Eggs'), '🥚');
      expect(PrescribedFoodItem.getFoodEmoji('Milk'), '🥛');
      expect(PrescribedFoodItem.getFoodEmoji('Chicken Breast'), '🍗');
      expect(PrescribedFoodItem.getFoodEmoji('Rice'), '🍚');
      expect(PrescribedFoodItem.getFoodEmoji('Banana'), '🍌');
      expect(PrescribedFoodItem.getFoodEmoji('Dosa'), '🥞');
    });

    test('6. Full JSON serialization and deserialization roundtrip', () {
      final originalItem = PrescribedFoodItem(
        foodId: 'food_chicken',
        name: 'Chicken Breast',
        quantity: 150.0,
        unit: 'g',
        servings: 1.0,
        servingSize: 100.0,
        baseUnit: 'g',
        calories: 247.5,
        protein: 46.5,
        carbs: 0.0,
        fat: 5.4,
        fiber: 0.0,
        baseCalories: 165.0,
        baseProtein: 31.0,
        baseCarbs: 0.0,
        baseFat: 3.6,
        baseFiber: 0.0,
        servingDisplay: '150 g — 1 serving',
      );

      final json = originalItem.toJson();
      expect(json['quantity'], 150.0);
      expect(json['unit'], 'g');
      expect(json['servings'], 1.0);
      expect(json['calories'], 247.5);
      expect(json['protein'], 46.5);

      final restoredItem = PrescribedFoodItem.fromJson(json);
      expect(restoredItem.name, 'Chicken Breast');
      expect(restoredItem.quantity, 150.0);
      expect(restoredItem.unit, 'g');
      expect(restoredItem.servings, 1.0);
      expect(restoredItem.calories, 247.5);
      expect(restoredItem.protein, 46.5);
      expect(restoredItem.effectiveServingDisplay, '150 g — 1 serving');
    });

    test('7. Editing quantity recalculates accurately from base values', () {
      final item = PrescribedFoodItem(
        foodId: 'food_chicken',
        name: 'Chicken Breast',
        quantity: 100.0,
        unit: 'g',
        servings: 1.0,
        servingSize: 100.0,
        baseUnit: 'g',
        calories: 165.0,
        protein: 31.0,
        carbs: 0.0,
        fat: 3.6,
        fiber: 0.0,
        baseCalories: 165.0,
        baseProtein: 31.0,
        baseCarbs: 0.0,
        baseFat: 3.6,
        baseFiber: 0.0,
      );

      // Admin edits from 100g to 150g
      final updatedNutrition = PrescribedFoodItem.calculateNutritionFromBase(
        baseCalories: item.baseCalories!,
        baseProtein: item.baseProtein!,
        baseCarbs: item.baseCarbs!,
        baseFat: item.baseFat!,
        baseFiber: item.baseFiber!,
        baseServingSize: item.servingSize,
        baseServingUnit: item.baseUnit,
        quantity: 150.0,
        unit: 'g',
        servings: 1.0,
      );

      final updatedItem = item.copyWith(
        quantity: 150.0,
        calories: updatedNutrition['calories'],
        protein: updatedNutrition['protein'],
        carbs: updatedNutrition['carbs'],
        fat: updatedNutrition['fat'],
        fiber: updatedNutrition['fiber'],
        servingDisplay: PrescribedFoodItem.formatServingDisplay(
          quantity: 150.0,
          unit: 'g',
          servings: 1.0,
        ),
      );

      expect(updatedItem.quantity, 150.0);
      expect(updatedItem.calories.round(), 248);
      expect(updatedItem.protein, closeTo(46.5, 0.1));
      expect(updatedItem.effectiveServingDisplay, '150 g — 1 serving');
    });

    test('8. Decimal quantities (0.5 serving, 150.5 g) calculation and display', () {
      const chicken = FoodItem(
        id: 'food_chicken',
        name: 'Chicken Breast',
        servingSize: 100,
        servingUnit: 'g',
        calories: 165.0,
        protein: 31.0,
        carbs: 0.0,
        fat: 3.6,
        fiber: 0.0,
      );

      final nutrition = PrescribedFoodItem.calculateNutrition(
        food: chicken,
        quantity: 150.5,
        unit: 'g',
        servings: 1.0,
      );

      // 165 * (150.5 / 100) = 248.325
      expect(nutrition['calories']!, closeTo(248.3, 0.1));
      // 31 * (150.5 / 100) = 46.655
      expect(nutrition['protein']!, closeTo(46.65, 0.1));

      final display = PrescribedFoodItem.formatServingDisplay(
        quantity: 150.5,
        unit: 'g',
        servings: 1.0,
      );
      expect(display, '150.5 g — 1 serving');

      final displayHalfServing = PrescribedFoodItem.formatServingDisplay(
        quantity: 0.5,
        unit: 'serving',
        servings: 0.5,
      );
      expect(displayHalfServing, '0.5 servings');
    });

    test('9. Full Multi-Meal Prescription Test (Prompt Section 14 Foods)', () {
      // Breakfast: Oats 60g, Eggs 3 pieces, Milk 250ml
      // Lunch: Rice 200g, Chicken 150g
      // Snack: Banana 1 piece
      // Dinner: Dosa 2 pieces, Eggs 2 pieces
      final breakfast = PrescribedMeal(
        mealType: 'Breakfast',
        timing: '8:00 AM',
        foods: [
          const PrescribedFoodItem(
            name: 'Oats',
            quantity: 60,
            unit: 'g',
            servings: 1,
            calories: 233.4,
            protein: 10.1,
            carbs: 39.8,
            fat: 4.1,
            servingDisplay: '60 g — 1 serving',
          ),
          const PrescribedFoodItem(
            name: 'Eggs',
            quantity: 3,
            unit: 'piece',
            servings: 3,
            calories: 210.0,
            protein: 18.0,
            carbs: 1.0,
            fat: 15.0,
            servingDisplay: '3 pieces',
          ),
          const PrescribedFoodItem(
            name: 'Milk',
            quantity: 250,
            unit: 'ml',
            servings: 1,
            calories: 150.0,
            protein: 8.0,
            carbs: 12.0,
            fat: 8.0,
            servingDisplay: '250 ml — 1 serving',
          ),
        ],
      );

      final lunch = PrescribedMeal(
        mealType: 'Lunch',
        timing: '1:30 PM',
        foods: [
          const PrescribedFoodItem(
            name: 'Rice',
            quantity: 200,
            unit: 'g',
            servings: 1,
            calories: 260.0,
            protein: 5.4,
            carbs: 56.0,
            fat: 0.6,
            servingDisplay: '200 g — 1 serving',
          ),
          const PrescribedFoodItem(
            name: 'Chicken',
            quantity: 150,
            unit: 'g',
            servings: 1,
            calories: 247.5,
            protein: 46.5,
            carbs: 0.0,
            fat: 5.4,
            servingDisplay: '150 g — 1 serving',
          ),
        ],
      );

      final snack = PrescribedMeal(
        mealType: 'Snack',
        timing: '5:00 PM',
        foods: [
          const PrescribedFoodItem(
            name: 'Banana',
            quantity: 1,
            unit: 'piece',
            servings: 1,
            calories: 105.0,
            protein: 1.3,
            carbs: 27.0,
            fat: 0.3,
            servingDisplay: '1 piece',
          ),
        ],
      );

      final dinner = PrescribedMeal(
        mealType: 'Dinner',
        timing: '8:30 PM',
        foods: [
          const PrescribedFoodItem(
            name: 'Dosa',
            quantity: 2,
            unit: 'piece',
            servings: 2,
            calories: 260.0,
            protein: 6.0,
            carbs: 36.0,
            fat: 10.0,
            servingDisplay: '2 pieces',
          ),
          const PrescribedFoodItem(
            name: 'Eggs',
            quantity: 2,
            unit: 'piece',
            servings: 2,
            calories: 140.0,
            protein: 12.0,
            carbs: 0.7,
            fat: 10.0,
            servingDisplay: '2 pieces',
          ),
        ],
      );

      final plan = AssignedDietPlan(
        id: 'diet_plan_test',
        clientId: 'AX-1001',
        planName: 'Championship Cut Protocol',
        dailyCalories: 2000,
        protein: 160,
        carbohydrates: 200,
        fat: 60,
        prescribedMeals: [breakfast, lunch, snack, dinner],
        createdAt: DateTime(2026, 10, 2),
      );

      expect(plan.prescribedMeals.length, 4);

      // Verify serialization and backend wire compatibility
      final planJson = plan.toJson();
      expect(planJson['meals'], isA<List>());
      expect((planJson['meals'] as List).length, 4);

      // Verify deserialization
      final restoredPlan = AssignedDietPlan.fromJson(planJson);
      expect(restoredPlan.meals.length, 4);
      expect(restoredPlan.meals[0].foods[0].name, 'Oats');
      expect(restoredPlan.meals[0].foods[0].simpleQuantityDisplay, '60 g');
      expect(restoredPlan.meals[0].foods[1].name, 'Eggs');
      expect(restoredPlan.meals[0].foods[1].simpleQuantityDisplay, '3 pieces');
      expect(restoredPlan.meals[0].foods[2].name, 'Milk');
      expect(restoredPlan.meals[0].foods[2].simpleQuantityDisplay, '250 ml');

      expect(restoredPlan.meals[1].foods[0].name, 'Rice');
      expect(restoredPlan.meals[1].foods[0].simpleQuantityDisplay, '200 g');
      expect(restoredPlan.meals[1].foods[1].name, 'Chicken');
      expect(restoredPlan.meals[1].foods[1].simpleQuantityDisplay, '150 g');

      expect(restoredPlan.meals[2].foods[0].name, 'Banana');
      expect(restoredPlan.meals[2].foods[0].simpleQuantityDisplay, '1 piece');

      expect(restoredPlan.meals[3].foods[0].name, 'Dosa');
      expect(restoredPlan.meals[3].foods[0].simpleQuantityDisplay, '2 pieces');
      expect(restoredPlan.meals[3].foods[1].name, 'Eggs');
      expect(restoredPlan.meals[3].foods[1].simpleQuantityDisplay, '2 pieces');
    });
  });
}
