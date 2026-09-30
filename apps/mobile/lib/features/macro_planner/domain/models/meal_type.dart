/// Enumeration of daily meal categories
enum MealType {
  breakfast('Breakfast', '🍳'),
  lunch('Lunch', '🍛'),
  snack('Snack', '🍌'),
  dinner('Dinner', '🍽');

  final String displayName;
  final String iconEmoji;

  const MealType(this.displayName, this.iconEmoji);

  static MealType fromString(String val) {
    return MealType.values.firstWhere(
      (m) => m.name.toLowerCase() == val.toLowerCase() || m.displayName.toLowerCase() == val.toLowerCase(),
      orElse: () => MealType.breakfast,
    );
  }
}
