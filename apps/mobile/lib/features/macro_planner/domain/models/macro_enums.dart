/// Biological sex used strictly for Mifflin-St Jeor BMR equation
enum BiologicalSex {
  male,
  female;

  String get displayName {
    switch (this) {
      case BiologicalSex.male:
        return 'Male';
      case BiologicalSex.female:
        return 'Female';
    }
  }

  /// Offset applied in Mifflin-St Jeor formula (+5 for male, -161 for female)
  double get bmrOffset {
    switch (this) {
      case BiologicalSex.male:
        return 5.0;
      case BiologicalSex.female:
        return -161.0;
    }
  }
}

/// Physical activity level multiplier for Total Daily Energy Expenditure (TDEE)
enum ActivityLevel {
  sedentary,
  lightlyActive,
  moderatelyActive,
  veryActive,
  extremelyActive;

  String get displayName {
    switch (this) {
      case ActivityLevel.sedentary:
        return 'Sedentary';
      case ActivityLevel.lightlyActive:
        return 'Lightly Active';
      case ActivityLevel.moderatelyActive:
        return 'Moderately Active';
      case ActivityLevel.veryActive:
        return 'Very Active';
      case ActivityLevel.extremelyActive:
        return 'Extremely Active';
    }
  }

  String get description {
    switch (this) {
      case ActivityLevel.sedentary:
        return 'Little or no structured activity';
      case ActivityLevel.lightlyActive:
        return 'Light exercise / activity 1–3 days per week';
      case ActivityLevel.moderatelyActive:
        return 'Moderate exercise 3–5 days per week';
      case ActivityLevel.veryActive:
        return 'Hard training 6–7 days per week';
      case ActivityLevel.extremelyActive:
        return 'Very high activity / physically demanding lifestyle';
    }
  }

  /// Default scientific multiplier
  double get defaultMultiplier {
    switch (this) {
      case ActivityLevel.sedentary:
        return 1.20;
      case ActivityLevel.lightlyActive:
        return 1.375;
      case ActivityLevel.moderatelyActive:
        return 1.55;
      case ActivityLevel.veryActive:
        return 1.725;
      case ActivityLevel.extremelyActive:
        return 1.90;
    }
  }
}

/// Client nutrition and energy balance goal
enum NutritionGoal {
  weightLoss,
  fatLoss,
  maintenance,
  leanBulk,
  weightGain;

  String get displayName {
    switch (this) {
      case NutritionGoal.weightLoss:
        return 'Weight Loss';
      case NutritionGoal.fatLoss:
        return 'Fat Loss';
      case NutritionGoal.maintenance:
        return 'Maintenance';
      case NutritionGoal.leanBulk:
        return 'Lean Bulk';
      case NutritionGoal.weightGain:
        return 'Weight Gain';
    }
  }

  String get description {
    switch (this) {
      case NutritionGoal.weightLoss:
        return 'General reduction in body weight.';
      case NutritionGoal.fatLoss:
        return 'Prioritize reducing body fat while supporting muscle retention.';
      case NutritionGoal.maintenance:
        return 'Maintain approximately current body weight.';
      case NutritionGoal.leanBulk:
        return 'Controlled calorie surplus intended to support muscle gain while limiting unnecessary weight gain.';
      case NutritionGoal.weightGain:
        return 'Higher calorie surplus intended for increasing body weight.';
    }
  }

  /// Default conservative adjustment multiplier relative to estimated maintenance (TDEE)
  double get defaultAdjustmentFactor {
    switch (this) {
      case NutritionGoal.weightLoss:
        return 0.85; // -15%
      case NutritionGoal.fatLoss:
        return 0.82; // -18% (conservative 0.80–0.85 range)
      case NutritionGoal.maintenance:
        return 1.00; // 0%
      case NutritionGoal.leanBulk:
        return 1.08; // +8%
      case NutritionGoal.weightGain:
        return 1.12; // +12%
    }
  }

  /// Default protein recommendation (g / kg bodyweight)
  double get defaultProteinFactor {
    switch (this) {
      case NutritionGoal.weightLoss:
        return 1.8;
      case NutritionGoal.fatLoss:
        return 2.0;
      case NutritionGoal.maintenance:
        return 1.6;
      case NutritionGoal.leanBulk:
        return 1.8;
      case NutritionGoal.weightGain:
        return 1.6;
    }
  }
}
