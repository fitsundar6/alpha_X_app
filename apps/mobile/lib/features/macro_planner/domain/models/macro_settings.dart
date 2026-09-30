import 'macro_enums.dart';

/// Central configuration for Alpha X Macro Planner
/// Allows Admins to customize calculation rules, protein factors, and safety thresholds.
class MacroSettings {
  final Map<ActivityLevel, double> activityMultipliers;
  final Map<NutritionGoal, double> goalAdjustments;
  final Map<NutritionGoal, double> proteinFactors;
  final double fatFactor; // grams of fat per kg bodyweight
  final double fiberPer1000Kcal; // grams of fiber per 1,000 kcal target
  final double minimumCalorieSafeguardMale;
  final double minimumCalorieSafeguardFemale;
  final double minimumCarbFloorGrams;
  final double proteinRangeTolerancePercent;
  final double carbRangeTolerancePercent;
  final double fatRangeTolerancePercent;
  final double fiberRangeTolerancePercent;
  final String formulaVersion;

  const MacroSettings({
    required this.activityMultipliers,
    required this.goalAdjustments,
    required this.proteinFactors,
    this.fatFactor = 0.8,
    this.fiberPer1000Kcal = 14.0,
    this.minimumCalorieSafeguardMale = 1500.0,
    this.minimumCalorieSafeguardFemale = 1200.0,
    this.minimumCarbFloorGrams = 50.0,
    this.proteinRangeTolerancePercent = 0.05, // ±5%
    this.carbRangeTolerancePercent = 0.08, // ±8%
    this.fatRangeTolerancePercent = 0.08, // ±8%
    this.fiberRangeTolerancePercent = 0.10, // ±10%
    this.formulaVersion = '1.0.0 (Mifflin-St Jeor)',
  });

  /// Production default scientific settings
  factory MacroSettings.defaults() {
    return MacroSettings(
      activityMultipliers: {
        for (final level in ActivityLevel.values) level: level.defaultMultiplier,
      },
      goalAdjustments: {
        for (final goal in NutritionGoal.values) goal: goal.defaultAdjustmentFactor,
      },
      proteinFactors: {
        for (final goal in NutritionGoal.values) goal: goal.defaultProteinFactor,
      },
      fatFactor: 0.8,
      fiberPer1000Kcal: 14.0,
      minimumCalorieSafeguardMale: 1500.0,
      minimumCalorieSafeguardFemale: 1200.0,
      minimumCarbFloorGrams: 50.0,
      proteinRangeTolerancePercent: 0.05,
      carbRangeTolerancePercent: 0.08,
      fatRangeTolerancePercent: 0.08,
      fiberRangeTolerancePercent: 0.10,
      formulaVersion: '1.0.0 (Mifflin-St Jeor)',
    );
  }

  MacroSettings copyWith({
    Map<ActivityLevel, double>? activityMultipliers,
    Map<NutritionGoal, double>? goalAdjustments,
    Map<NutritionGoal, double>? proteinFactors,
    double? fatFactor,
    double? fiberPer1000Kcal,
    double? minimumCalorieSafeguardMale,
    double? minimumCalorieSafeguardFemale,
    double? minimumCarbFloorGrams,
    double? proteinRangeTolerancePercent,
    double? carbRangeTolerancePercent,
    double? fatRangeTolerancePercent,
    double? fiberRangeTolerancePercent,
    String? formulaVersion,
  }) {
    return MacroSettings(
      activityMultipliers: activityMultipliers ?? this.activityMultipliers,
      goalAdjustments: goalAdjustments ?? this.goalAdjustments,
      proteinFactors: proteinFactors ?? this.proteinFactors,
      fatFactor: fatFactor ?? this.fatFactor,
      fiberPer1000Kcal: fiberPer1000Kcal ?? this.fiberPer1000Kcal,
      minimumCalorieSafeguardMale: minimumCalorieSafeguardMale ?? this.minimumCalorieSafeguardMale,
      minimumCalorieSafeguardFemale: minimumCalorieSafeguardFemale ?? this.minimumCalorieSafeguardFemale,
      minimumCarbFloorGrams: minimumCarbFloorGrams ?? this.minimumCarbFloorGrams,
      proteinRangeTolerancePercent: proteinRangeTolerancePercent ?? this.proteinRangeTolerancePercent,
      carbRangeTolerancePercent: carbRangeTolerancePercent ?? this.carbRangeTolerancePercent,
      fatRangeTolerancePercent: fatRangeTolerancePercent ?? this.fatRangeTolerancePercent,
      fiberRangeTolerancePercent: fiberRangeTolerancePercent ?? this.fiberRangeTolerancePercent,
      formulaVersion: formulaVersion ?? this.formulaVersion,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'activityMultipliers': activityMultipliers.map((k, v) => MapEntry(k.name, v)),
      'goalAdjustments': goalAdjustments.map((k, v) => MapEntry(k.name, v)),
      'proteinFactors': proteinFactors.map((k, v) => MapEntry(k.name, v)),
      'fatFactor': fatFactor,
      'fiberPer1000Kcal': fiberPer1000Kcal,
      'minimumCalorieSafeguardMale': minimumCalorieSafeguardMale,
      'minimumCalorieSafeguardFemale': minimumCalorieSafeguardFemale,
      'minimumCarbFloorGrams': minimumCarbFloorGrams,
      'proteinRangeTolerancePercent': proteinRangeTolerancePercent,
      'carbRangeTolerancePercent': carbRangeTolerancePercent,
      'fatRangeTolerancePercent': fatRangeTolerancePercent,
      'fiberRangeTolerancePercent': fiberRangeTolerancePercent,
      'formulaVersion': formulaVersion,
    };
  }

  factory MacroSettings.fromJson(Map<String, dynamic> json) {
    final defaultSettings = MacroSettings.defaults();

    final activityMap = <ActivityLevel, double>{};
    if (json['activityMultipliers'] is Map) {
      for (final level in ActivityLevel.values) {
        final val = json['activityMultipliers'][level.name];
        activityMap[level] = val != null ? (val as num).toDouble() : level.defaultMultiplier;
      }
    }

    final goalMap = <NutritionGoal, double>{};
    if (json['goalAdjustments'] is Map) {
      for (final goal in NutritionGoal.values) {
        final val = json['goalAdjustments'][goal.name];
        goalMap[goal] = val != null ? (val as num).toDouble() : goal.defaultAdjustmentFactor;
      }
    }

    final proteinMap = <NutritionGoal, double>{};
    if (json['proteinFactors'] is Map) {
      for (final goal in NutritionGoal.values) {
        final val = json['proteinFactors'][goal.name];
        proteinMap[goal] = val != null ? (val as num).toDouble() : goal.defaultProteinFactor;
      }
    }

    return MacroSettings(
      activityMultipliers: activityMap.isNotEmpty ? activityMap : defaultSettings.activityMultipliers,
      goalAdjustments: goalMap.isNotEmpty ? goalMap : defaultSettings.goalAdjustments,
      proteinFactors: proteinMap.isNotEmpty ? proteinMap : defaultSettings.proteinFactors,
      fatFactor: (json['fatFactor'] as num?)?.toDouble() ?? defaultSettings.fatFactor,
      fiberPer1000Kcal: (json['fiberPer1000Kcal'] as num?)?.toDouble() ?? defaultSettings.fiberPer1000Kcal,
      minimumCalorieSafeguardMale: (json['minimumCalorieSafeguardMale'] as num?)?.toDouble() ?? defaultSettings.minimumCalorieSafeguardMale,
      minimumCalorieSafeguardFemale: (json['minimumCalorieSafeguardFemale'] as num?)?.toDouble() ?? defaultSettings.minimumCalorieSafeguardFemale,
      minimumCarbFloorGrams: (json['minimumCarbFloorGrams'] as num?)?.toDouble() ?? defaultSettings.minimumCarbFloorGrams,
      proteinRangeTolerancePercent: (json['proteinRangeTolerancePercent'] as num?)?.toDouble() ?? defaultSettings.proteinRangeTolerancePercent,
      carbRangeTolerancePercent: (json['carbRangeTolerancePercent'] as num?)?.toDouble() ?? defaultSettings.carbRangeTolerancePercent,
      fatRangeTolerancePercent: (json['fatRangeTolerancePercent'] as num?)?.toDouble() ?? defaultSettings.fatRangeTolerancePercent,
      fiberRangeTolerancePercent: (json['fiberRangeTolerancePercent'] as num?)?.toDouble() ?? defaultSettings.fiberRangeTolerancePercent,
      formulaVersion: json['formulaVersion'] as String? ?? defaultSettings.formulaVersion,
    );
  }
}
