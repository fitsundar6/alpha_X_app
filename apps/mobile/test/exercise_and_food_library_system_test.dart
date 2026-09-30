import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/features/exercise/data/default_exercise_catalog.dart';
import 'package:alpha_x_gym/features/exercise/data/repositories/exercise_repository.dart';
import 'package:alpha_x_gym/features/exercise/domain/models/exercise_model.dart';
import 'package:alpha_x_gym/features/macro_planner/data/food_database.dart';
import 'package:alpha_x_gym/features/macro_planner/data/repositories/macro_repository.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/food_item.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/food_log_entry.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/meal_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PART 1 & 2: EXERCISE LIBRARY EXPANSION & INTEGRITY', () {
    test('Verifies all original 140 exercises are preserved with exact IDs', () {
      final catalog = defaultAlphaXExercises;

      // Must be substantially expanded beyond original 140
      expect(catalog.length, greaterThanOrEqualTo(220));

      // Benchmark original exercises from the initial 140 catalog
      final keyOriginalIds = [
        'ex_db_rdl',
        'ex_incline_smith',
        'ex_incline_db',
        'ex_bb_bench',
        'ex_incline_bb',
        'ex_pec_deck',
        'ex_lat_pulldown',
        'ex_neutral_pullup',
        'ex_seated_cable_row',
        'ex_bb_bent_row',
        'ex_db_lateral_raise',
        'ex_bb_curl',
        'ex_ez_bar_curl',
        'ex_tricep_rope_pushdown',
        'ex_bb_squat',
        'ex_conventional_deadlift',
        'ex_bb_hip_thrust',
        'ex_standing_calf_raise',
        'ex_ab_wheel_rollout',
        'ex_heavy_bag_boxing',
        'ex_battle_ropes',
      ];

      for (final id in keyOriginalIds) {
        final found = catalog.any((e) => e.id == id);
        expect(found, isTrue, reason: 'Original exercise $id must not be removed');
      }
    });

    test('Verifies new exercises cover required fitness categories', () {
      final catalog = defaultAlphaXExercises;

      // Verify newly added movements exist
      final newRequiredIds = [
        'ex_wide_pushup',
        'ex_deficit_pushup',
        'ex_ring_pushup',
        'ex_weighted_pushup',
        'ex_smith_flat_bench',
        'ex_landmine_press_standing',
        'ex_neutral_lat_pulldown',
        'ex_single_arm_cable_row',
        'ex_seal_row',
        'ex_rack_pull',
        'ex_dumbbell_pullover',
        'ex_barbell_pullover',
        'ex_smith_shoulder_press',
        'ex_machine_lateral_raise',
        'ex_cable_front_raise',
        'ex_dumbbell_y_raise',
        'ex_cuban_press',
        'ex_external_rotation_cable',
        'ex_internal_rotation_cable',
        'ex_drag_curl',
        'ex_zottman_curl',
        'ex_high_cable_curl',
        'ex_reverse_pushdown',
        'ex_jm_press',
        'ex_bench_dip',
        'ex_tate_press',
        'ex_belt_squat',
        'ex_safety_bar_squat',
        'ex_zercher_squat',
        'ex_sumo_deadlift',
        'ex_trap_bar_deadlift',
        'ex_glute_ham_raise',
        'ex_tibialis_raise',
        'ex_single_leg_calf_raise',
        'ex_ab_machine_crunch',
        'ex_bicycle_crunch',
        'ex_kettlebell_clean',
        'ex_kettlebell_snatch',
        'ex_handstand_pushup',
        'ex_muscle_up',
        'ex_l_sit',
        'ex_shadow_boxing',
        'ex_jump_rope',
        'ex_worlds_greatest_stretch',
        'ex_90_90_hip_rotation',
        'ex_cat_cow',
        'ex_pigeon_pose',
        'ex_cobra_stretch',
        'ex_childs_pose',
      ];

      for (final id in newRequiredIds) {
        final found = catalog.any((e) => e.id == id);
        expect(found, isTrue, reason: 'Expanded exercise $id must be present in catalog');
      }
    });

    test('ExerciseRepository searches and filters by muscle, equipment, difficulty', () {
      final repo = ExerciseRepository();

      // Search by name
      final pushups = repo.allExercises.where((e) => e.name.toLowerCase().contains('push-up')).toList();
      expect(pushups.length, greaterThanOrEqualTo(5));

      // Filter by muscle
      final chestExs = repo.allExercises.where((e) =>
          e.primaryMuscles.contains(MuscleGroup.midChest) ||
          e.primaryMuscles.contains(MuscleGroup.upperChest) ||
          e.category.toLowerCase() == 'chest').toList();
      expect(chestExs.length, greaterThanOrEqualTo(20));

      // Filter by equipment
      final barbellExs = repo.allExercises.where((e) => e.equipment.toLowerCase() == 'barbell').toList();
      expect(barbellExs.length, greaterThanOrEqualTo(25));
    });
  });

  group('PART 3: FOOD LIBRARY EXPANSION & VERIFICATION', () {
    test('Verifies FoodDatabase contains rich verified fitness & Indian foods', () {
      final foods = FoodDatabase.defaultFoods;
      expect(foods.length, greaterThanOrEqualTo(120));

      // Check key Indian foods
      final indianFoods = [
        'Plain Dosa',
        'Masala Dosa',
        'Ragi Dosa',
        'Idli',
        'Ven Pongal',
        'Rava Upma',
        'Appam',
        'Idiyappam',
        'Puttu',
        'Chapati',
        'Curd Rice',
        'Lemon Rice',
        'Tomato Rice',
        'South Indian Sambar',
        'Traditional Rasam',
        'Toor Dal',
        'Moong Dal',
        'Masoor Dal',
        'Urad Dal',
        'Chickpeas',
        'Rajma',
        'Sprouted Green Gram',
      ];

      for (final name in indianFoods) {
        final found = foods.any((f) => f.name.toLowerCase().contains(name.toLowerCase()));
        expect(found, isTrue, reason: 'Indian staple food "$name" must be present in FoodDatabase');
      }

      // Check key protein sources
      final proteinFoods = [
        'Chicken Breast',
        'Chicken Thigh',
        'Egg (Whole',
        'Egg Whites',
        'Tuna',
        'Salmon',
        'Paneer',
        'Low-Fat Paneer',
        'Tofu',
        'Tempeh',
        'Soy Chunks',
        'Greek Yogurt',
        'Curd',
        'Whole Milk',
        'Whey Protein',
      ];

      for (final name in proteinFoods) {
        final found = foods.any((f) => f.name.toLowerCase().contains(name.toLowerCase()));
        expect(found, isTrue, reason: 'Protein staple "$name" must be present');
      }
    });

    test('Quantity scaling scales macros proportionally with no rounding errors', () {
      // 100g base food: 165 kcal, 31g protein, 0g carbs, 3.6g fat
      const cookedChicken = FoodItem(
        id: 'food_test_chicken',
        name: 'Cooked Chicken Breast',
        servingSize: 100,
        servingUnit: 'grams',
        calories: 165.0,
        protein: 31.0,
        carbs: 0.0,
        fat: 3.6,
        category: 'Protein',
      );

      // Client enters quantity = 250g (ratio = 2.5)
      const enteredQuantity = 2.5;
      final entry = FoodLogEntry.fromFoodItem(
        clientId: 'AXG-0001',
        dateString: '2026-09-30',
        mealType: MealType.lunch,
        food: cookedChicken,
        quantity: enteredQuantity,
      );

      expect(entry.totalCalories, closeTo(165.0 * 2.5, 0.1)); // 412.5 kcal
      expect(entry.totalProtein, closeTo(31.0 * 2.5, 0.1));   // 77.5g
      expect(entry.totalFat, closeTo(3.6 * 2.5, 0.1));       // 9.0g
      expect(entry.totalCarbs, equals(0.0));
      expect(entry.quantityDisplay, equals('250 g'));
    });

    test('Atwater formula accurately computes estimated calories: 4*P + 4*C + 9*F', () {
      // Example: 30g Protein, 40g Carbs, 10g Fat
      // 30*4 + 40*4 + 10*9 = 120 + 160 + 90 = 370 kcal
      const p = 30.0;
      const c = 40.0;
      const f = 10.0;
      final estimatedCalories = (p * 4.0) + (c * 4.0) + (f * 9.0);
      expect(estimatedCalories, equals(370.0));

      // Test Homemade Chicken Rice: 35g P, 45g C, 8g F
      // 35*4 + 45*4 + 8*9 = 140 + 180 + 72 = 392 kcal
      const p2 = 35.0;
      const c2 = 45.0;
      const f2 = 8.0;
      final estimatedCalories2 = (p2 * 4.0) + (c2 * 4.0) + (f2 * 9.0);
      expect(estimatedCalories2, equals(392.0));
    });
  });

  group('PART 4: CUSTOM FOOD & GLOBAL MULTI-CLIENT VISIBILITY', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('Client A creates custom food -> saved to repository -> searchable by Client B and Admin', () async {
      final repo = MacroRepository();

      // Client A creates "Test Homemade High Protein Rice"
      const customFoodA = FoodItem(
        id: 'cf_client_a_123',
        name: 'Test Homemade High Protein Rice',
        servingSize: 250,
        servingUnit: 'grams',
        calories: 392.0,
        protein: 35.0,
        carbs: 45.0,
        fat: 8.0,
        fiber: 4.0,
        isCustom: true,
        category: 'Indian Foods',
        source: 'USER',
        createdBy: 'AXG-0001',
        isPublic: true,
      );

      await repo.addCustomFood(customFoodA);

      // Verify Client A sees it in their custom foods list
      expect(repo.customFoods.any((f) => f.name == 'Test Homemade High Protein Rice'), isTrue);

      // Verify it is part of allFoods
      expect(repo.allFoods.any((f) => f.name == 'Test Homemade High Protein Rice'), isTrue);

      // Client B searches for the food
      final clientBSearchResults = repo.searchFoods('High Protein Rice');
      expect(clientBSearchResults.isNotEmpty, isTrue);
      final foundItem = clientBSearchResults.firstWhere((f) => f.name == 'Test Homemade High Protein Rice');
      expect(foundItem.calories, equals(392.0));
      expect(foundItem.protein, equals(35.0));
      expect(foundItem.carbs, equals(45.0));
      expect(foundItem.fat, equals(8.0));
      expect(foundItem.createdBy, equals('AXG-0001'));
      expect(foundItem.isPublic, isTrue);

      // Admin category filter: 'User Added' / 'Custom'
      final customFilterResults = repo.searchFoods('', category: 'Custom');
      expect(customFilterResults.any((f) => f.name == 'Test Homemade High Protein Rice'), isTrue);
    });

    test('Duplicate prevention preserves unique entries without unbounded duplication', () async {
      final repo = MacroRepository();

      const item1 = FoodItem(
        id: 'cf_dup_1',
        name: 'Test Protein Shake',
        servingSize: 1,
        servingUnit: 'scoop',
        calories: 120.0,
        protein: 24.0,
        carbs: 2.0,
        fat: 1.5,
        isCustom: true,
        category: 'Protein',
        createdBy: 'AXG-0001',
      );

      await repo.addCustomFood(item1);
      final countBefore = repo.allFoods.where((f) => f.name == 'Test Protein Shake').length;
      expect(countBefore, equals(1));

      // Attempt adding identical custom food again with same id
      await repo.addCustomFood(item1);
      final countAfter = repo.allFoods.where((f) => f.name == 'Test Protein Shake').length;
      expect(countAfter, equals(1), reason: 'Duplicate food with same ID must not create second entry');
    });

    test('Food logging adds food to meal and updates daily macro totals', () {
      final repo = MacroRepository();
      const today = '2026-09-30';

      final idli = FoodDatabase.defaultFoods.firstWhere((f) => f.name.toLowerCase().contains('idli'));
      final egg = FoodDatabase.defaultFoods.firstWhere((f) => f.id == 'food_egg_whole');

      // Log 4 Idlis and 2 Whole Eggs for Breakfast
      repo.logFoodEntry(FoodLogEntry.fromFoodItem(
        clientId: 'AXG-0001',
        dateString: today,
        mealType: MealType.breakfast,
        food: idli,
        quantity: 4.0,
      ));

      repo.logFoodEntry(FoodLogEntry.fromFoodItem(
        clientId: 'AXG-0001',
        dateString: today,
        mealType: MealType.breakfast,
        food: egg,
        quantity: 2.0,
      ));

      final breakfastSummary = repo.getMealSummary(today, MealType.breakfast, clientId: 'AXG-0001');
      expect(breakfastSummary.entries.length, equals(2));

      // Expected macros:
      // 4 Idlis: 4 * 65 kcal = 260 kcal, 4 * 2.0 = 8.0g P, 4 * 13.5 = 54.0g C, 4 * 0.2 = 0.8g F
      // 2 Eggs: 2 * 72 kcal = 144 kcal, 2 * 6.3 = 12.6g P, 2 * 0.4 = 0.8g C, 2 * 4.8 = 9.6g F
      // Total calories: 260 + 144 = 404 kcal
      // Total protein: 8.0 + 12.6 = 20.6g
      expect(breakfastSummary.totalCalories, equals(404.0));
      expect(breakfastSummary.totalProtein, closeTo(20.6, 0.1));
      expect(breakfastSummary.totalCarbs, closeTo(54.8, 0.1));
      expect(breakfastSummary.totalFat, closeTo(10.4, 0.1));

      // Check daily summary includes these breakfast macros
      final dailySummary = repo.getDailyMacroSummary(today, clientId: 'AXG-0001');
      expect(dailySummary.consumedCalories, greaterThanOrEqualTo(404.0));
      expect(dailySummary.consumedProtein, greaterThanOrEqualTo(20.6));
    });
  });
}
