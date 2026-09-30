import 'meal_type.dart';
import 'food_log_entry.dart';

/// Aggregated nutrition for an individual meal
class MealNutritionSummary {
  final MealType mealType;
  final List<FoodLogEntry> entries;

  const MealNutritionSummary({
    required this.mealType,
    required this.entries,
  });

  double get totalCalories => entries.fold(0.0, (sum, e) => sum + e.totalCalories);
  double get totalProtein => entries.fold(0.0, (sum, e) => sum + e.totalProtein);
  double get totalCarbs => entries.fold(0.0, (sum, e) => sum + e.totalCarbs);
  double get totalFat => entries.fold(0.0, (sum, e) => sum + e.totalFat);
  double get totalFiber => entries.fold(0.0, (sum, e) => sum + e.totalFiber);

  String get summaryText =>
      '${totalCalories.round()} kcal • ${FoodLogEntry.formatMacro(totalProtein)} P | ${FoodLogEntry.formatMacro(totalCarbs)} C | ${FoodLogEntry.formatMacro(totalFat)} F';
}

/// Aggregated macro targets vs consumed overview for a single calendar day
class DailyMacroSummary {
  final String dateString;
  final double targetCalories;
  final double targetProtein;
  final double targetCarbs;
  final double targetFat;
  final double targetFiber;

  final double consumedCalories;
  final double consumedProtein;
  final double consumedCarbs;
  final double consumedFat;
  final double consumedFiber;

  final Map<MealType, MealNutritionSummary> mealSummaries;

  const DailyMacroSummary({
    required this.dateString,
    required this.targetCalories,
    required this.targetProtein,
    required this.targetCarbs,
    required this.targetFat,
    this.targetFiber = 30.0,
    required this.consumedCalories,
    required this.consumedProtein,
    required this.consumedCarbs,
    required this.consumedFat,
    this.consumedFiber = 0.0,
    required this.mealSummaries,
  });

  // Raw Remaining calculations (can be negative if over)
  double get remainingCalories => targetCalories - consumedCalories;
  double get remainingProtein => targetProtein - consumedProtein;
  double get remainingCarbs => targetCarbs - consumedCarbs;
  double get remainingFat => targetFat - consumedFat;
  double get remainingFiber => targetFiber - consumedFiber;

  // Safe Remaining calculations (clamped >= 0, never negative)
  double get safeRemainingCalories => remainingCalories > 0 ? remainingCalories : 0.0;
  double get safeRemainingProtein => remainingProtein > 0 ? remainingProtein : 0.0;
  double get safeRemainingCarbs => remainingCarbs > 0 ? remainingCarbs : 0.0;
  double get safeRemainingFat => remainingFat > 0 ? remainingFat : 0.0;
  double get safeRemainingFiber => remainingFiber > 0 ? remainingFiber : 0.0;

  // Percentage progress (clamped between 0.0 and 1.0 for visual bars)
  double get calorieProgress => targetCalories > 0 ? (consumedCalories / targetCalories).clamp(0.0, 1.0) : 0.0;
  double get proteinProgress => targetProtein > 0 ? (consumedProtein / targetProtein).clamp(0.0, 1.0) : 0.0;
  double get carbProgress => targetCarbs > 0 ? (consumedCarbs / targetCarbs).clamp(0.0, 1.0) : 0.0;
  double get fatProgress => targetFat > 0 ? (consumedFat / targetFat).clamp(0.0, 1.0) : 0.0;

  // Percent complete (integer for badges, e.g. 95%)
  int get caloriePercentage => targetCalories > 0 ? ((consumedCalories / targetCalories) * 100).round() : 0;
  int get proteinPercentage => targetProtein > 0 ? ((consumedProtein / targetProtein) * 100).round() : 0;
  int get carbPercentage => targetCarbs > 0 ? ((consumedCarbs / targetCarbs) * 100).round() : 0;
  int get fatPercentage => targetFat > 0 ? ((consumedFat / targetFat) * 100).round() : 0;

  // Over-target detection
  bool get isCaloriesOver => consumedCalories > targetCalories;
  bool get isProteinOver => consumedProtein > targetProtein;
  bool get isCarbsOver => consumedCarbs > targetCarbs;
  bool get isFatOver => consumedFat > targetFat;

  bool get hasOverCalories => isCaloriesOver;
  bool get hasOverProtein => isProteinOver;
  bool get hasOverCarbs => isCarbsOver;
  bool get hasOverFat => isFatOver;

  double get overCalories => isCaloriesOver ? (consumedCalories - targetCalories) : 0.0;
  double get overProtein => isProteinOver ? (consumedProtein - targetProtein) : 0.0;
  double get overCarbs => isCarbsOver ? (consumedCarbs - targetCarbs) : 0.0;
  double get overFat => isFatOver ? (consumedFat - targetFat) : 0.0;

  // Clean UI display strings for cards (Section 10: Never show negative, show "X g over target")
  String get remainingCaloriesStatus => isCaloriesOver
      ? '${overCalories.round()} kcal over target'
      : '${safeRemainingCalories.round()} kcal remaining';

  String get remainingProteinStatus => isProteinOver
      ? '${FoodLogEntry.formatMacro(overProtein)} g over target'
      : '${FoodLogEntry.formatMacro(safeRemainingProtein)} g remaining';

  String get remainingCarbsStatus => isCarbsOver
      ? '${FoodLogEntry.formatMacro(overCarbs)} g over target'
      : '${FoodLogEntry.formatMacro(safeRemainingCarbs)} g remaining';

  String get remainingFatStatus => isFatOver
      ? '${FoodLogEntry.formatMacro(overFat)} g over target'
      : '${FoodLogEntry.formatMacro(safeRemainingFat)} g remaining';

  int get totalMealsLogged => mealSummaries.values.where((m) => m.entries.isNotEmpty).length;
}
