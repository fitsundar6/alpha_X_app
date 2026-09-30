import 'package:flutter_test/flutter_test.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/macro_enums.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/macro_input.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/macro_settings.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/services/macro_calculator.dart';
import 'package:alpha_x_gym/features/macro_planner/data/repositories/macro_repository.dart';

void main() {
  group('Mifflin-St Jeor BMR Tests', () {
    test('Calculates exact BMR for Male', () {
      // BMR = 10 * 81 + 6.25 * 174 - 5 * 28 + 5 = 810 + 1087.5 - 140 + 5 = 1762.5
      final bmr = MacroCalculator.calculateBMR(
        sex: BiologicalSex.male,
        weightKg: 81.0,
        heightCm: 174.0,
        age: 28,
      );
      expect(bmr, closeTo(1762.5, 0.01));
    });

    test('Calculates exact BMR for Female', () {
      // BMR = 10 * 60 + 6.25 * 165 - 5 * 25 - 161 = 600 + 1031.25 - 125 - 161 = 1345.25
      final bmr = MacroCalculator.calculateBMR(
        sex: BiologicalSex.female,
        weightKg: 60.0,
        heightCm: 165.0,
        age: 25,
      );
      expect(bmr, closeTo(1345.25, 0.01));
    });
  });

  group('TDEE Activity Multipliers Tests', () {
    const bmr = 1762.5;

    test('Sedentary multiplier (1.200)', () {
      final tdee = MacroCalculator.calculateTDEE(bmr: bmr, activity: ActivityLevel.sedentary);
      expect(tdee, closeTo(1762.5 * 1.2, 0.01));
    });

    test('Lightly active multiplier (1.375)', () {
      final tdee = MacroCalculator.calculateTDEE(bmr: bmr, activity: ActivityLevel.lightlyActive);
      expect(tdee, closeTo(1762.5 * 1.375, 0.01));
    });

    test('Moderately active multiplier (1.550)', () {
      final tdee = MacroCalculator.calculateTDEE(bmr: bmr, activity: ActivityLevel.moderatelyActive);
      expect(tdee, closeTo(1762.5 * 1.55, 0.01));
    });

    test('Very active multiplier (1.725)', () {
      final tdee = MacroCalculator.calculateTDEE(bmr: bmr, activity: ActivityLevel.veryActive);
      expect(tdee, closeTo(1762.5 * 1.725, 0.01));
    });

    test('Extremely active multiplier (1.900)', () {
      final tdee = MacroCalculator.calculateTDEE(bmr: bmr, activity: ActivityLevel.extremelyActive);
      expect(tdee, closeTo(1762.5 * 1.9, 0.01));
    });
  });

  group('Deterministic Macro Calculation Engine Tests', () {
    test('Calculates complete targets for reference profile: Male, 28y, 174cm, 81kg, Very Active, Fat Loss', () {
      const input = MacroInput(
        sex: BiologicalSex.male,
        age: 28,
        heightCm: 174.0,
        weightKg: 81.0,
        activityLevel: ActivityLevel.veryActive,
        goal: NutritionGoal.fatLoss,
      );

      final result = MacroCalculator.calculate(input: input);

      // Verify BMR & TDEE
      expect(result.bmr, 1763);
      expect(result.maintenanceCalories, 3040);

      // Target calories: 3040.3125 * 0.82 = 2493.05 -> 2493 kcal
      expect(result.calories, 2493);

      // Protein: 81kg * 2.0g/kg = 162g
      expect(result.proteinGrams, 162);

      // Fat: 81kg * 0.8g/kg = 64.8g -> 65g
      expect(result.fatGrams, 65);

      // Carbs: Remaining calories / 4 = (2493 - 162*4 - 65*9) / 4 = 1260 / 4 = 315g
      expect(result.carbGrams, 315);

      // Fiber: (2493 / 1000) * 14 = 34.90 -> 35g
      expect(result.fiberGrams, 35);

      // No safety safeguard triggered for healthy calorie level
      expect(result.safeguardWarning, isNull);

      // Verify Target Ranges
      expect(result.proteinRange.min, lessThan(result.proteinGrams));
      expect(result.proteinRange.max, greaterThan(result.proteinGrams));
      expect(result.carbRange.min, lessThan(result.carbGrams));
      expect(result.carbRange.max, greaterThan(result.carbGrams));
      expect(result.fatRange.min, lessThan(result.fatGrams));
      expect(result.fatRange.max, greaterThan(result.fatGrams));

      // Verify Macro validation passes
      expect(result.validation.isValid, isTrue);
    });

    test('Calorie safeguards activate for extreme deficit (Male minimum 1500 kcal)', () {
      const lowInput = MacroInput(
        sex: BiologicalSex.male,
        age: 65,
        heightCm: 150.0,
        weightKg: 45.0,
        activityLevel: ActivityLevel.sedentary,
        goal: NutritionGoal.weightLoss, // -20%
      );

      final result = MacroCalculator.calculate(input: lowInput);

      // Calculated would be well below 1500 kcal, so safeguard clamps to 1500 kcal
      expect(result.calories, 1500);
      expect(result.safeguardWarning, isNotNull);
      expect(result.isBelowSafeguardThreshold, isTrue);
    });

    test('Calorie safeguards activate for extreme deficit (Female minimum 1200 kcal)', () {
      const lowInput = MacroInput(
        sex: BiologicalSex.female,
        age: 60,
        heightCm: 145.0,
        weightKg: 40.0,
        activityLevel: ActivityLevel.sedentary,
        goal: NutritionGoal.weightLoss, // -20%
      );

      final result = MacroCalculator.calculate(input: lowInput);

      // Safeguard clamps to 1200 kcal
      expect(result.calories, 1200);
      expect(result.safeguardWarning, isNotNull);
      expect(result.isBelowSafeguardThreshold, isTrue);
    });

    test('Negative carbohydrate prevention ensures positive carb floor even under high protein/fat loads', () {
      final customSettings = MacroSettings.defaults().copyWith(
        minimumCalorieSafeguardMale: 1000,
        minimumCalorieSafeguardFemale: 1000,
        minimumCarbFloorGrams: 50.0,
      );

      const lowInput = MacroInput(
        sex: BiologicalSex.male,
        age: 70,
        heightCm: 140.0,
        weightKg: 80.0,
        activityLevel: ActivityLevel.sedentary,
        goal: NutritionGoal.weightLoss,
      );

      final result = MacroCalculator.calculate(input: lowInput, settings: customSettings);

      // Carbohydrates must be at or above min carb floor (50g)
      expect(result.carbGrams, greaterThanOrEqualTo(50));
      expect(result.proteinGrams, greaterThan(0));
      expect(result.fatGrams, greaterThan(0));
      expect(result.validation.isValid, isTrue);
    });
  });

  group('MacroRepository State & Review Flow Tests', () {
    test('Initializes with default inputs and calculated result', () {
      final repo = MacroRepository();
      expect(repo.currentInput, isNotNull);
      expect(repo.activeResult, isNotNull);
      expect(repo.activeResult!.calories, greaterThan(0));
      expect(repo.history.isNotEmpty, isTrue);
    });

    test('Recalculates when new input is submitted and saves to history', () {
      final repo = MacroRepository();
      final initialHistoryLength = repo.history.length;

      const newInput = MacroInput(
        sex: BiologicalSex.female,
        age: 26,
        heightCm: 168.0,
        weightKg: 62.0,
        activityLevel: ActivityLevel.moderatelyActive,
        goal: NutritionGoal.leanBulk,
      );

      final newResult = repo.calculateAndSave(newInput);

      expect(repo.currentInput?.sex, BiologicalSex.female);
      expect(repo.activeResult?.calories, newResult.calories);
      expect(repo.history.length, initialHistoryLength + 1);
      expect(repo.history.first.input.goal, NutritionGoal.leanBulk);
    });

    test('Updates admin settings and triggers listener notification', () {
      final repo = MacroRepository();
      var notificationReceived = false;
      repo.addListener(() => notificationReceived = true);

      final updatedSettings = repo.settings.copyWith(
        fatFactor: 0.9,
      );

      repo.updateSettings(updatedSettings);

      expect(repo.settings.fatFactor, 0.9);
      expect(notificationReceived, isTrue);
    });

    test('Target review provides contextual guidance', () {
      final repo = MacroRepository();
      final review = repo.reviewProgress(currentWeightKg: 80.5, currentWaistCm: 83.0);

      expect(review.advice, isNotEmpty);
      expect(review.fluctuationNote, contains('natural daily weight fluctuations'));
    });
  });
}
