import 'meal_type.dart';
import 'food_item.dart';

/// Represents a client's logged food record in a meal
class FoodLogEntry {
  final String id;
  final String clientId;
  final String dateString; // 'yyyy-MM-dd'
  final MealType mealType;
  final String foodId;
  final String foodName;
  final double quantity;
  final String servingUnit;
  final double servingSize;
  final double baseCalories; // per 1 serving
  final double baseProtein;
  final double baseCarbs;
  final double baseFat;
  final double baseFiber;
  final String source; // 'AI_CAMERA', 'FOOD_LIBRARY', 'CUSTOM_FOOD'
  final bool isAiConfirmed;
  final String category;
  final DateTime? loggedAt;
  final DateTime createdAt;

  const FoodLogEntry({
    required this.id,
    required this.clientId,
    required this.dateString,
    required this.mealType,
    required this.foodId,
    required this.foodName,
    required this.quantity,
    required this.servingUnit,
    required this.servingSize,
    required this.baseCalories,
    required this.baseProtein,
    required this.baseCarbs,
    required this.baseFat,
    this.baseFiber = 0.0,
    this.source = 'FOOD_LIBRARY',
    this.isAiConfirmed = true,
    this.category = 'General',
    this.loggedAt,
    required this.createdAt,
  });

  /// Factory to create an entry from a FoodItem and desired quantity
  factory FoodLogEntry.fromFoodItem({
    required String clientId,
    required String dateString,
    required MealType mealType,
    required FoodItem food,
    required double quantity,
    String? source,
  }) {
    final now = DateTime.now();
    return FoodLogEntry(
      id: 'flog_${now.millisecondsSinceEpoch}_${food.id}',
      clientId: clientId,
      dateString: dateString,
      mealType: mealType,
      foodId: food.id,
      foodName: food.name,
      quantity: quantity,
      servingUnit: food.servingUnit,
      servingSize: food.servingSize,
      baseCalories: food.calories,
      baseProtein: food.protein,
      baseCarbs: food.carbs,
      baseFat: food.fat,
      baseFiber: food.fiber,
      source: source ?? (food.isCustom ? 'CUSTOM_FOOD' : 'FOOD_LIBRARY'),
      isAiConfirmed: true,
      category: food.category,
      loggedAt: now,
      createdAt: now,
    );
  }

  // Calculated totals scaling dynamically with quantity
  double get totalCalories => baseCalories * quantity;
  double get totalProtein => baseProtein * quantity;
  double get totalCarbs => baseCarbs * quantity;
  double get totalFat => baseFat * quantity;
  double get totalFiber => baseFiber * quantity;

  static String formatCalories(double val) {
    if (val.abs() < 0.001) return '0';
    if (val % 1 == 0) return val.toInt().toString();
    return val.toStringAsFixed(1);
  }

  static String formatMacro(double val) {
    if (val.abs() < 0.001) return '0';
    if (val % 1 == 0) return val.toInt().toString();
    // If fractional part is very close to integer
    if ((val - val.round()).abs() < 0.05) return val.round().toString();
    return val.toStringAsFixed(1);
  }

  String get caloriesDisplay => '${formatCalories(totalCalories)} kcal';
  String get proteinDisplay => '${formatMacro(totalProtein)}g';
  String get carbsDisplay => '${formatMacro(totalCarbs)}g';
  String get fatDisplay => '${formatMacro(totalFat)}g';
  String get fiberDisplay => '${formatMacro(totalFiber)}g';

  String get macrosSummary =>
      '${formatCalories(totalCalories)} kcal • P: ${formatMacro(totalProtein)}g  C: ${formatMacro(totalCarbs)}g  F: ${formatMacro(totalFat)}g';

  String get quantityDisplay {
    final unitLower = servingUnit.toLowerCase().trim();
    final qStr = quantity % 1 == 0 ? quantity.toInt().toString() : quantity.toStringAsFixed(1);

    if (unitLower == 'piece' || unitLower == 'pieces') {
      return '$qStr piece${quantity == 1 ? '' : 's'}';
    }
    if (unitLower == 'scoop' || unitLower == 'scoops') {
      return '$qStr scoop${quantity == 1 ? '' : 's'}';
    }
    if (unitLower == 'cup' || unitLower == 'cups') {
      return '$qStr cup${quantity == 1 ? '' : 's'}';
    }
    if (unitLower == 'slice' || unitLower == 'slices') {
      return '$qStr slice${quantity == 1 ? '' : 's'}';
    }
    if (unitLower == 'tablespoon' || unitLower == 'tbsp') {
      return '$qStr tbsp';
    }
    if (unitLower == 'g' || unitLower == 'grams' || unitLower == 'gram') {
      if (servingSize > 1) {
        final totalGrams = servingSize * quantity;
        final gStr = totalGrams % 1 == 0 ? totalGrams.toInt().toString() : totalGrams.toStringAsFixed(1);
        return '$gStr g';
      }
      return '$qStr g';
    }
    if (unitLower == 'ml') {
      if (servingSize > 1) {
        final totalMl = servingSize * quantity;
        final mlStr = totalMl % 1 == 0 ? totalMl.toInt().toString() : totalMl.toStringAsFixed(1);
        return '$mlStr ml';
      }
      return '$qStr ml';
    }
    return '$qStr $servingUnit';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'clientId': clientId,
    'dateString': dateString,
    'mealType': mealType.name,
    'foodId': foodId,
    'foodName': foodName,
    'quantity': quantity,
    'servingUnit': servingUnit,
    'servingSize': servingSize,
    'baseCalories': baseCalories,
    'baseProtein': baseProtein,
    'baseCarbs': baseCarbs,
    'baseFat': baseFat,
    'baseFiber': baseFiber,
    'source': source,
    'isAiConfirmed': isAiConfirmed,
    'category': category,
    'loggedAt': (loggedAt ?? createdAt).toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory FoodLogEntry.fromJson(Map<String, dynamic> json) => FoodLogEntry(
    id: json['id'] as String,
    clientId: json['clientId'] as String,
    dateString: json['dateString'] as String,
    mealType: MealType.fromString(json['mealType'] as String),
    foodId: json['foodId'] as String? ?? '',
    foodName: json['foodName'] as String,
    quantity: (json['quantity'] as num).toDouble(),
    servingUnit: json['servingUnit'] as String,
    servingSize: (json['servingSize'] as num).toDouble(),
    baseCalories: (json['baseCalories'] as num).toDouble(),
    baseProtein: (json['baseProtein'] as num).toDouble(),
    baseCarbs: (json['baseCarbs'] as num).toDouble(),
    baseFat: (json['baseFat'] as num).toDouble(),
    baseFiber: (json['baseFiber'] as num?)?.toDouble() ?? 0.0,
    source: json['source'] as String? ?? 'FOOD_LIBRARY',
    isAiConfirmed: json['isAiConfirmed'] as bool? ?? true,
    category: json['category'] as String? ?? 'General',
    loggedAt: DateTime.tryParse(json['loggedAt'] as String? ?? ''),
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
  );

  FoodLogEntry copyWith({
    String? id,
    String? clientId,
    String? dateString,
    MealType? mealType,
    String? foodId,
    String? foodName,
    double? quantity,
    String? servingUnit,
    double? servingSize,
    double? baseCalories,
    double? baseProtein,
    double? baseCarbs,
    double? baseFat,
    double? baseFiber,
    String? source,
    bool? isAiConfirmed,
    String? category,
    DateTime? loggedAt,
    DateTime? createdAt,
  }) {
    return FoodLogEntry(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      dateString: dateString ?? this.dateString,
      mealType: mealType ?? this.mealType,
      foodId: foodId ?? this.foodId,
      foodName: foodName ?? this.foodName,
      quantity: quantity ?? this.quantity,
      servingUnit: servingUnit ?? this.servingUnit,
      servingSize: servingSize ?? this.servingSize,
      baseCalories: baseCalories ?? this.baseCalories,
      baseProtein: baseProtein ?? this.baseProtein,
      baseCarbs: baseCarbs ?? this.baseCarbs,
      baseFat: baseFat ?? this.baseFat,
      baseFiber: baseFiber ?? this.baseFiber,
      source: source ?? this.source,
      isAiConfirmed: isAiConfirmed ?? this.isAiConfirmed,
      category: category ?? this.category,
      loggedAt: loggedAt ?? this.loggedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
