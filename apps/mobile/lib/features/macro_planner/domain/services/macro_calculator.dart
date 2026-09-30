import 'dart:math';
import '../models/macro_enums.dart';
import '../models/macro_input.dart';
import '../models/macro_result.dart';
import '../models/macro_settings.dart';

/// Pure deterministic scientific calculation engine for Alpha X Macro Planner
class MacroCalculator {
  /// Calculate Basal Metabolic Rate using Mifflin-St Jeor formula
  /// Male: 10 * weight(kg) + 6.25 * height(cm) - 5 * age + 5
  /// Female: 10 * weight(kg) + 6.25 * height(cm) - 5 * age - 161
  static double calculateBMR({
    required BiologicalSex sex,
    required double weightKg,
    required double heightCm,
    required int age,
  }) {
    return (10.0 * weightKg) + (6.25 * heightCm) - (5.0 * age) + sex.bmrOffset;
  }

  /// Calculate Total Daily Energy Expenditure (TDEE) / Maintenance
  static double calculateTDEE({
    required double bmr,
    required ActivityLevel activity,
    double? customMultiplier,
  }) {
    return bmr * (customMultiplier ?? activity.defaultMultiplier);
  }

  /// Calculate daily nutrition targets using Mifflin-St Jeor BMR and configurable factors
  static MacroResult calculate({
    required MacroInput input,
    MacroSettings? settings,
  }) {
    final cfg = settings ?? MacroSettings.defaults();

    // 1. Calculate Basal Metabolic Rate (Mifflin-St Jeor)
    final double bmrRaw = calculateBMR(
      sex: input.sex,
      weightKg: input.weightKg,
      heightCm: input.heightCm,
      age: input.age,
    );
    final int bmr = bmrRaw.round();

    // 2. Calculate Total Daily Energy Expenditure (TDEE) / Estimated Maintenance
    final double activityMultiplier = cfg.activityMultipliers[input.activityLevel] ??
        input.activityLevel.defaultMultiplier;
    final double tdeeRaw = calculateTDEE(
      bmr: bmrRaw,
      activity: input.activityLevel,
      customMultiplier: activityMultiplier,
    );
    final int maintenanceCalories = tdeeRaw.round();

    // 3. Goal Calorie Adjustment
    final double goalAdjustmentFactor = cfg.goalAdjustments[input.goal] ??
        input.goal.defaultAdjustmentFactor;
    final double targetCaloriesRaw = tdeeRaw * goalAdjustmentFactor;
    int targetCalories = targetCaloriesRaw.round();

    // Check minimum calorie safeguard
    final double safeguardThreshold = input.sex == BiologicalSex.male
        ? cfg.minimumCalorieSafeguardMale
        : cfg.minimumCalorieSafeguardFemale;

    bool isBelowSafeguardThreshold = false;
    String? safeguardWarning;

    if (targetCalories < safeguardThreshold) {
      isBelowSafeguardThreshold = true;
      safeguardWarning =
          'Your calculated target is unusually low. Please review your target with a qualified nutrition professional before following it.';
      // Clamp to configured safety floor so a dangerously low target is not forced
      targetCalories = safeguardThreshold.round();
    }

    // 4. Protein Calculation (bodyweight * proteinFactor)
    final double proteinFactor = cfg.proteinFactors[input.goal] ??
        input.goal.defaultProteinFactor;
    final double proteinGramsRaw = input.weightKg * proteinFactor;
    int proteinGrams = proteinGramsRaw.round();
    final double proteinCaloriesRaw = proteinGrams * 4.0;

    // 5. Fat Calculation (bodyweight * fatFactor)
    final double fatFactor = cfg.fatFactor;
    final double fatGramsRaw = input.weightKg * fatFactor;
    int fatGrams = fatGramsRaw.round();
    final double fatCaloriesRaw = fatGrams * 9.0;

    // 6. Carbohydrate Calculation from remaining calories
    double remainingCaloriesRaw = targetCalories - proteinCaloriesRaw - fatCaloriesRaw;
    double carbGramsRaw = remainingCaloriesRaw / 4.0;
    int carbGrams = carbGramsRaw.round();
    bool wasCarbRebalanced = false;

    // Safeguard against negative or dangerously low carbohydrates
    if (carbGrams < 0 || remainingCaloriesRaw < (cfg.minimumCarbFloorGrams * 4.0)) {
      wasCarbRebalanced = true;
      // Set to safe minimum carb floor and rebalance fat
      final int minCarbs = cfg.minimumCarbFloorGrams.round();
      final double minCarbCalories = minCarbs * 4.0;
      final double allowableFatCalories = max(
        0.0,
        targetCalories - proteinCaloriesRaw - minCarbCalories,
      );
      fatGrams = max((input.weightKg * 0.5).round(), (allowableFatCalories / 9.0).round());
      remainingCaloriesRaw = targetCalories - (proteinGrams * 4.0) - (fatGrams * 9.0);
      carbGrams = max(0, (remainingCaloriesRaw / 4.0).round());
      carbGramsRaw = carbGrams.toDouble();
    }

    // 7. Fiber Calculation (approx 14g per 1,000 kcal target)
    final double fiberGramsRaw = (targetCalories / 1000.0) * cfg.fiberPer1000Kcal;
    final int fiberGrams = max(15, fiberGramsRaw.round());

    // 8. Practical Target Ranges
    final proteinRange = TargetRange(
      min: (proteinGrams * (1.0 - cfg.proteinRangeTolerancePercent)).round(),
      max: (proteinGrams * (1.0 + cfg.proteinRangeTolerancePercent)).round(),
    );
    final carbRange = TargetRange(
      min: max(0, (carbGrams * (1.0 - cfg.carbRangeTolerancePercent)).round()),
      max: (carbGrams * (1.0 + cfg.carbRangeTolerancePercent)).round(),
    );
    final fatRange = TargetRange(
      min: (fatGrams * (1.0 - cfg.fatRangeTolerancePercent)).round(),
      max: (fatGrams * (1.0 + cfg.fatRangeTolerancePercent)).round(),
    );
    final fiberRange = TargetRange(
      min: (fiberGrams * (1.0 - cfg.fiberRangeTolerancePercent)).round(),
      max: (fiberGrams * (1.0 + cfg.fiberRangeTolerancePercent)).round(),
    );

    // 9. Validation
    final validation = validateMacroTotals(
      targetCalories: targetCalories,
      proteinGrams: proteinGrams,
      carbGrams: carbGrams,
      fatGrams: fatGrams,
      fiberGrams: fiberGrams,
    );

    // 10. Breakdown details
    final breakdown = CalculationBreakdown(
      bmrRaw: bmrRaw,
      tdeeRaw: tdeeRaw,
      goalAdjustmentPercent: ((goalAdjustmentFactor - 1.0) * 100),
      targetCaloriesRaw: targetCaloriesRaw,
      proteinGramsRaw: proteinGramsRaw,
      proteinCaloriesRaw: proteinCaloriesRaw,
      fatGramsRaw: fatGramsRaw,
      fatCaloriesRaw: fatCaloriesRaw,
      remainingCaloriesRaw: remainingCaloriesRaw,
      carbGramsRaw: carbGramsRaw,
      carbCaloriesRaw: (carbGrams * 4.0),
      fiberGramsRaw: fiberGramsRaw,
      wasCarbRebalanced: wasCarbRebalanced,
    );

    return MacroResult(
      bmr: bmr,
      maintenanceCalories: maintenanceCalories,
      targetCalories: targetCalories,
      proteinGrams: proteinGrams,
      carbGrams: carbGrams,
      fatGrams: fatGrams,
      fiberGrams: fiberGrams,
      goal: input.goal,
      calculatedAt: DateTime.now(),
      formulaVersion: cfg.formulaVersion,
      proteinRange: proteinRange,
      carbRange: carbRange,
      fatRange: fatRange,
      fiberRange: fiberRange,
      isBelowSafeguardThreshold: isBelowSafeguardThreshold,
      safeguardWarning: safeguardWarning,
      validation: validation,
      breakdown: breakdown,
    );
  }

  /// Reusable validation function verifying macro totals align with energy target
  static MacroValidation validateMacroTotals({
    required int targetCalories,
    required int proteinGrams,
    required int carbGrams,
    required int fatGrams,
    required int fiberGrams,
  }) {
    final List<String> warnings = [];

    if (targetCalories <= 0) warnings.add('Calories must be greater than 0');
    if (proteinGrams <= 0) warnings.add('Protein must be greater than 0');
    if (fatGrams <= 0) warnings.add('Fat must be greater than 0');
    if (carbGrams < 0) warnings.add('Carbohydrates cannot be negative');
    if (fiberGrams <= 0) warnings.add('Fiber must be greater than 0');

    final double macroCaloriesTotal = (proteinGrams * 4.0) + (carbGrams * 4.0) + (fatGrams * 9.0);
    final double calorieDifference = (targetCalories - macroCaloriesTotal).abs();

    // Rounding difference threshold (typically within 15–20 kcal)
    final bool isConsistent = calorieDifference <= 20.0;
    if (!isConsistent) {
      warnings.add(
        'Macro calories ($macroCaloriesTotal kcal) deviate by ${calorieDifference.toStringAsFixed(1)} kcal from target ($targetCalories kcal).',
      );
    }

    return MacroValidation(
      isValid: warnings.isEmpty || (warnings.length == 1 && warnings.first.contains('deviate')),
      macroCaloriesTotal: macroCaloriesTotal,
      calorieDifference: calorieDifference,
      warnings: warnings,
    );
  }
}
