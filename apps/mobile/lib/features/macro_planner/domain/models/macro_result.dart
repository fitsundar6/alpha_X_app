import 'macro_enums.dart';

/// Practical intake range acknowledging real-world metabolic variability
class TargetRange {
  final int min;
  final int max;

  const TargetRange({required this.min, required this.max});

  String get display => '$min–$max g';
}

/// Validation result verifying scientific correctness and energy balance consistency
class MacroValidation {
  final bool isValid;
  final double macroCaloriesTotal;
  final double calorieDifference;
  final List<String> warnings;

  const MacroValidation({
    required this.isValid,
    required this.macroCaloriesTotal,
    required this.calorieDifference,
    required this.warnings,
  });
}

/// Detailed calculation breakdown for complete user transparency
class CalculationBreakdown {
  final double bmrRaw;
  final double tdeeRaw;
  final double goalAdjustmentPercent;
  final double targetCaloriesRaw;
  final double proteinGramsRaw;
  final double proteinCaloriesRaw;
  final double fatGramsRaw;
  final double fatCaloriesRaw;
  final double remainingCaloriesRaw;
  final double carbGramsRaw;
  final double carbCaloriesRaw;
  final double fiberGramsRaw;
  final bool wasCarbRebalanced;

  const CalculationBreakdown({
    required this.bmrRaw,
    required this.tdeeRaw,
    required this.goalAdjustmentPercent,
    required this.targetCaloriesRaw,
    required this.proteinGramsRaw,
    required this.proteinCaloriesRaw,
    required this.fatGramsRaw,
    required this.fatCaloriesRaw,
    required this.remainingCaloriesRaw,
    required this.carbGramsRaw,
    required this.carbCaloriesRaw,
    required this.fiberGramsRaw,
    this.wasCarbRebalanced = false,
  });
}

/// The final computed daily nutrition targets
class MacroResult {
  final int bmr;
  final int maintenanceCalories;
  final int targetCalories;
  final int proteinGrams;
  final int carbGrams;
  final int fatGrams;
  final int fiberGrams;
  final NutritionGoal goal;
  final DateTime calculatedAt;
  final String formulaVersion;

  // Practical Target Ranges
  final TargetRange proteinRange;
  final TargetRange carbRange;
  final TargetRange fatRange;
  final TargetRange fiberRange;

  // Safeguards & Validation
  final bool isBelowSafeguardThreshold;
  final String? safeguardWarning;
  final MacroValidation validation;
  final CalculationBreakdown breakdown;

  const MacroResult({
    required this.bmr,
    required this.maintenanceCalories,
    required this.targetCalories,
    required this.proteinGrams,
    required this.carbGrams,
    required this.fatGrams,
    required this.fiberGrams,
    required this.goal,
    required this.calculatedAt,
    required this.formulaVersion,
    required this.proteinRange,
    required this.carbRange,
    required this.fatRange,
    required this.fiberRange,
    required this.isBelowSafeguardThreshold,
    this.safeguardWarning,
    required this.validation,
    required this.breakdown,
  });

  /// Convenient alias for targetCalories
  int get calories => targetCalories;

  /// Calorie percentages from macronutrients
  double get proteinCaloriePercent => targetCalories > 0 ? (proteinGrams * 4 / targetCalories) * 100 : 0;
  double get carbCaloriePercent => targetCalories > 0 ? (carbGrams * 4 / targetCalories) * 100 : 0;
  double get fatCaloriePercent => targetCalories > 0 ? (fatGrams * 9 / targetCalories) * 100 : 0;

  int get proteinMin => proteinRange.min;
  int get proteinMax => proteinRange.max;
  int get carbMin => carbRange.min;
  int get carbMax => carbRange.max;
  int get fatMin => fatRange.min;
  int get fatMax => fatRange.max;
  int get fiberMin => fiberRange.min;
  int get fiberMax => fiberRange.max;

  Map<String, dynamic> toJson() {
    return {
      'bmr': bmr,
      'maintenanceCalories': maintenanceCalories,
      'targetCalories': targetCalories,
      'proteinGrams': proteinGrams,
      'carbGrams': carbGrams,
      'fatGrams': fatGrams,
      'fiberGrams': fiberGrams,
      'goal': goal.name,
      'calculatedAt': calculatedAt.toIso8601String(),
      'formulaVersion': formulaVersion,
      'proteinRangeMin': proteinRange.min,
      'proteinRangeMax': proteinRange.max,
      'carbRangeMin': carbRange.min,
      'carbRangeMax': carbRange.max,
      'fatRangeMin': fatRange.min,
      'fatRangeMax': fatRange.max,
      'fiberRangeMin': fiberRange.min,
      'fiberRangeMax': fiberRange.max,
      'isBelowSafeguardThreshold': isBelowSafeguardThreshold,
      'safeguardWarning': safeguardWarning,
    };
  }

  factory MacroResult.fromJson(Map<String, dynamic> json) {
    final bmr = json['bmr'] as int;
    final maintenanceCalories = json['maintenanceCalories'] as int;
    final targetCalories = json['targetCalories'] as int;
    final proteinGrams = json['proteinGrams'] as int;
    final carbGrams = json['carbGrams'] as int;
    final fatGrams = json['fatGrams'] as int;
    final fiberGrams = json['fiberGrams'] as int;
    final goal = NutritionGoal.values.firstWhere(
      (g) => g.name == json['goal'],
      orElse: () => NutritionGoal.fatLoss,
    );
    final calculatedAt = DateTime.tryParse(json['calculatedAt'] as String? ?? '') ?? DateTime.now();
    final formulaVersion = json['formulaVersion'] as String? ?? '1.0.0';

    final proteinRange = TargetRange(
      min: json['proteinRangeMin'] as int? ?? (proteinGrams * 0.95).round(),
      max: json['proteinRangeMax'] as int? ?? (proteinGrams * 1.05).round(),
    );
    final carbRange = TargetRange(
      min: json['carbRangeMin'] as int? ?? (carbGrams * 0.92).round(),
      max: json['carbRangeMax'] as int? ?? (carbGrams * 1.08).round(),
    );
    final fatRange = TargetRange(
      min: json['fatRangeMin'] as int? ?? (fatGrams * 0.92).round(),
      max: json['fatRangeMax'] as int? ?? (fatGrams * 1.08).round(),
    );
    final fiberRange = TargetRange(
      min: json['fiberRangeMin'] as int? ?? (fiberGrams * 0.90).round(),
      max: json['fiberRangeMax'] as int? ?? (fiberGrams * 1.10).round(),
    );

    final isBelowSafeguardThreshold = json['isBelowSafeguardThreshold'] as bool? ?? false;
    final safeguardWarning = json['safeguardWarning'] as String?;

    return MacroResult(
      bmr: bmr,
      maintenanceCalories: maintenanceCalories,
      targetCalories: targetCalories,
      proteinGrams: proteinGrams,
      carbGrams: carbGrams,
      fatGrams: fatGrams,
      fiberGrams: fiberGrams,
      goal: goal,
      calculatedAt: calculatedAt,
      formulaVersion: formulaVersion,
      proteinRange: proteinRange,
      carbRange: carbRange,
      fatRange: fatRange,
      fiberRange: fiberRange,
      isBelowSafeguardThreshold: isBelowSafeguardThreshold,
      safeguardWarning: safeguardWarning,
      validation: MacroValidation(
        isValid: true,
        macroCaloriesTotal: (proteinGrams * 4 + carbGrams * 4 + fatGrams * 9).toDouble(),
        calorieDifference: 0,
        warnings: [],
      ),
      breakdown: CalculationBreakdown(
        bmrRaw: bmr.toDouble(),
        tdeeRaw: maintenanceCalories.toDouble(),
        goalAdjustmentPercent: 0,
        targetCaloriesRaw: targetCalories.toDouble(),
        proteinGramsRaw: proteinGrams.toDouble(),
        proteinCaloriesRaw: (proteinGrams * 4).toDouble(),
        fatGramsRaw: fatGrams.toDouble(),
        fatCaloriesRaw: (fatGrams * 9).toDouble(),
        remainingCaloriesRaw: (carbGrams * 4).toDouble(),
        carbGramsRaw: carbGrams.toDouble(),
        carbCaloriesRaw: (carbGrams * 4).toDouble(),
        fiberGramsRaw: fiberGrams.toDouble(),
      ),
    );
  }
}
