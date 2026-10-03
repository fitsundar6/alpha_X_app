import 'dart:convert';
import 'food_item.dart';

/// Represents a single food item in an assigned meal prescription
class PrescribedFoodItem {
  final String? foodId;
  final String name;
  final String servingDisplay;
  final double quantity;
  final String unit;
  final double servings;
  final double servingSize;
  final String baseUnit;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double? baseCalories;
  final double? baseProtein;
  final double? baseCarbs;
  final double? baseFat;
  final double? baseFiber;

  const PrescribedFoodItem({
    this.foodId,
    required this.name,
    this.servingDisplay = '',
    this.quantity = 1.0,
    this.unit = 'g',
    this.servings = 1.0,
    this.servingSize = 100.0,
    this.baseUnit = 'g',
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.fiber = 0.0,
    this.baseCalories,
    this.baseProtein,
    this.baseCarbs,
    this.baseFat,
    this.baseFiber,
  });

  String get quantityDisplay => quantity % 1 == 0 ? quantity.toInt().toString() : quantity.toStringAsFixed(1);
  String get servingsDisplay => servings % 1 == 0 ? servings.toInt().toString() : servings.toStringAsFixed(1);

  String get simpleQuantityDisplay {
    final clean = unit.trim().toLowerCase();
    final qStr = quantityDisplay;
    if (clean == 'piece' || clean == 'pieces') {
      return quantity == 1 ? '1 piece' : '$qStr pieces';
    }
    if (clean == 'egg' || clean == 'eggs') {
      return quantity == 1 ? '1 egg' : '$qStr eggs';
    }
    if (clean == 'slice' || clean == 'slices') {
      return quantity == 1 ? '1 slice' : '$qStr slices';
    }
    if (clean == 'bowl' || clean == 'bowls') {
      return quantity == 1 ? '1 bowl' : '$qStr bowls';
    }
    if (clean == 'cup' || clean == 'cups') {
      return quantity == 1 ? '1 cup' : '$qStr cups';
    }
    if (clean == 'serving' || clean == 'servings') {
      final s = servings % 1 == 0 ? servings.toInt().toString() : servings.toStringAsFixed(1);
      return servings == 1 ? '1 serving' : '$s servings';
    }
    return '$qStr $unit';
  }

  String get effectiveServingDisplay {
    if (servingDisplay.isNotEmpty) return servingDisplay;
    return formatServingDisplay(
      quantity: quantity,
      unit: unit,
      servings: servings,
    );
  }

  static String getFoodEmoji(String name) {
    final n = name.toLowerCase();
    if (n.contains('oat')) return '🥣';
    if (n.contains('egg')) return '🥚';
    if (n.contains('milk') || n.contains('dairy')) return '🥛';
    if (n.contains('rice')) return '🍚';
    if (n.contains('chicken') || n.contains('poultry')) return '🍗';
    if (n.contains('beef') || n.contains('steak') || n.contains('meat')) return '🥩';
    if (n.contains('fish') || n.contains('salmon') || n.contains('tuna')) return '🐟';
    if (n.contains('banana')) return '🍌';
    if (n.contains('apple')) return '🍎';
    if (n.contains('dosa') || n.contains('pancake')) return '🥞';
    if (n.contains('roti') || n.contains('chapati') || n.contains('bread') || n.contains('toast')) return '🍞';
    if (n.contains('salad') || n.contains('green')) return '🥗';
    if (n.contains('veg') || n.contains('broccoli') || n.contains('spinach')) return '🥦';
    if (n.contains('paneer') || n.contains('cheese')) return '🧀';
    if (n.contains('dal') || n.contains('curry') || n.contains('soup')) return '🍲';
    if (n.contains('almond') || n.contains('nut') || n.contains('peanut')) return '🥜';
    if (n.contains('shake') || n.contains('smoothie') || n.contains('protein powder') || n.contains('whey')) return '🥤';
    if (n.contains('water')) return '💧';
    return '🍽️';
  }

  static String formatServingDisplay({
    required double quantity,
    required String unit,
    double? servings,
  }) {
    final qtyStr = quantity % 1 == 0 ? quantity.toInt().toString() : quantity.toStringAsFixed(1);
    final srv = servings ?? 1.0;
    final srvStr = srv % 1 == 0 ? srv.toInt().toString() : srv.toStringAsFixed(1);
    final cleanUnit = unit.trim().toLowerCase();

    // Piece-based / count units
    if (cleanUnit == 'piece' || cleanUnit == 'pieces') {
      return quantity == 1 ? '1 piece' : '$qtyStr pieces';
    }
    if (cleanUnit == 'egg' || cleanUnit == 'eggs') {
      return quantity == 1 ? '1 egg' : '$qtyStr eggs';
    }
    if (cleanUnit == 'slice' || cleanUnit == 'slices') {
      return quantity == 1 ? '1 slice' : '$qtyStr slices';
    }
    if (cleanUnit == 'bowl' || cleanUnit == 'bowls') {
      return quantity == 1 ? '1 bowl' : '$qtyStr bowls';
    }
    if (cleanUnit == 'cup' || cleanUnit == 'cups') {
      return quantity == 1 ? '1 cup' : '$qtyStr cups';
    }
    if (cleanUnit == 'serving' || cleanUnit == 'servings') {
      return srv == 1 ? '1 serving' : '$srvStr servings';
    }

    // Weight and volume units (g, kg, ml, L, tbsp, tsp)
    if (srv > 0) {
      final srvLabel = srv == 1 ? '1 serving' : '$srvStr servings';
      return '$qtyStr $unit — $srvLabel';
    }

    return '$qtyStr $unit';
  }

  static Map<String, double> calculateNutritionFromBase({
    required double baseCalories,
    required double baseProtein,
    required double baseCarbs,
    required double baseFat,
    required double baseFiber,
    required double baseServingSize,
    required String baseServingUnit,
    required double quantity,
    required String unit,
    required double servings,
  }) {
    final baseSize = baseServingSize > 0 ? baseServingSize : 100.0;
    final bUnit = baseServingUnit.trim().toLowerCase();
    final selectedUnit = unit.trim().toLowerCase();

    double multiplier = 1.0;

    if (selectedUnit == 'serving' || selectedUnit == 'servings') {
      multiplier = servings > 0 ? servings : (quantity > 0 ? quantity : 1.0);
    } else if (bUnit == 'g' || bUnit == 'grams' || bUnit == 'gram') {
      if (selectedUnit == 'g' || selectedUnit == 'grams' || selectedUnit == 'gram') {
        multiplier = quantity / baseSize;
      } else if (selectedUnit == 'kg') {
        multiplier = (quantity * 1000.0) / baseSize;
      } else if (selectedUnit == 'tbsp') {
        multiplier = (quantity * 15.0) / baseSize;
      } else if (selectedUnit == 'tsp') {
        multiplier = (quantity * 5.0) / baseSize;
      } else if (selectedUnit == 'cup' || selectedUnit == 'cups') {
        multiplier = (quantity * 200.0) / baseSize;
      } else if (selectedUnit == 'bowl' || selectedUnit == 'bowls') {
        multiplier = (quantity * 250.0) / baseSize;
      } else if (selectedUnit == 'slice' || selectedUnit == 'piece') {
        multiplier = (quantity * 30.0) / baseSize;
      } else {
        multiplier = quantity / baseSize;
      }
    } else if (bUnit == 'ml' || bUnit == 'milliliter' || bUnit == 'milliliters') {
      if (selectedUnit == 'ml') {
        multiplier = quantity / baseSize;
      } else if (selectedUnit == 'l' || selectedUnit == 'liter' || selectedUnit == 'liters') {
        multiplier = (quantity * 1000.0) / baseSize;
      } else if (selectedUnit == 'cup' || selectedUnit == 'cups') {
        multiplier = (quantity * 240.0) / baseSize;
      } else if (selectedUnit == 'tbsp') {
        multiplier = (quantity * 15.0) / baseSize;
      } else if (selectedUnit == 'tsp') {
        multiplier = (quantity * 5.0) / baseSize;
      } else {
        multiplier = quantity / baseSize;
      }
    } else {
      // Piece, egg, slice, scoop, etc.
      if (selectedUnit == 'piece' || selectedUnit == 'pieces' ||
          selectedUnit == 'egg' || selectedUnit == 'eggs' ||
          selectedUnit == 'slice' || selectedUnit == 'slices' ||
          selectedUnit == 'scoop' || selectedUnit == 'scoops' ||
          selectedUnit == bUnit) {
        multiplier = quantity / baseSize;
      } else if (selectedUnit == 'serving' || selectedUnit == 'servings') {
        multiplier = servings > 0 ? servings : quantity;
      } else if (selectedUnit == 'g' && baseSize == 1) {
        multiplier = quantity / 50.0;
      } else {
        multiplier = quantity / baseSize;
      }
    }

    if (multiplier < 0) multiplier = 0;

    return {
      'calories': baseCalories * multiplier,
      'protein': baseProtein * multiplier,
      'carbs': baseCarbs * multiplier,
      'fat': baseFat * multiplier,
      'fiber': baseFiber * multiplier,
    };
  }

  static Map<String, double> calculateNutrition({
    required FoodItem food,
    required double quantity,
    required String unit,
    required double servings,
  }) {
    return calculateNutritionFromBase(
      baseCalories: food.calories,
      baseProtein: food.protein,
      baseCarbs: food.carbs,
      baseFat: food.fat,
      baseFiber: food.fiber,
      baseServingSize: food.servingSize,
      baseServingUnit: food.servingUnit,
      quantity: quantity,
      unit: unit,
      servings: servings,
    );
  }

  PrescribedFoodItem copyWith({
    String? foodId,
    String? name,
    String? servingDisplay,
    double? quantity,
    String? unit,
    double? servings,
    double? servingSize,
    String? baseUnit,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    double? fiber,
    double? baseCalories,
    double? baseProtein,
    double? baseCarbs,
    double? baseFat,
    double? baseFiber,
  }) {
    return PrescribedFoodItem(
      foodId: foodId ?? this.foodId,
      name: name ?? this.name,
      servingDisplay: servingDisplay ?? this.servingDisplay,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      servings: servings ?? this.servings,
      servingSize: servingSize ?? this.servingSize,
      baseUnit: baseUnit ?? this.baseUnit,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      fiber: fiber ?? this.fiber,
      baseCalories: baseCalories ?? this.baseCalories,
      baseProtein: baseProtein ?? this.baseProtein,
      baseCarbs: baseCarbs ?? this.baseCarbs,
      baseFat: baseFat ?? this.baseFat,
      baseFiber: baseFiber ?? this.baseFiber,
    );
  }

  Map<String, dynamic> toJson() => {
    'foodId': foodId,
    'name': name,
    'servingDisplay': effectiveServingDisplay,
    'quantity': quantity,
    'unit': unit,
    'servings': servings,
    'servingSize': servingSize,
    'baseUnit': baseUnit,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'fiber': fiber,
    'baseCalories': baseCalories,
    'baseProtein': baseProtein,
    'baseCarbs': baseCarbs,
    'baseFat': baseFat,
    'baseFiber': baseFiber,
  };

  factory PrescribedFoodItem.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? 'Food';
    double qty = 1.0;
    if (json['quantity'] is num) {
      qty = (json['quantity'] as num).toDouble();
    } else if (json['quantity'] is String) {
      qty = double.tryParse((json['quantity'] as String).replaceAll(RegExp(r'[^0-9.]'), '')) ?? 1.0;
    }

    final unitStr = (json['unit'] ?? json['servingUnit'] ?? json['servingDisplay']) as String? ?? 'g';
    final srv = (json['servings'] as num?)?.toDouble() ?? 1.0;
    final srvSize = (json['servingSize'] as num?)?.toDouble() ?? 100.0;
    final bUnit = (json['baseUnit'] as String?) ?? unitStr;
    final cal = (json['calories'] as num?)?.toDouble() ?? 0.0;
    final pro = (json['protein'] as num?)?.toDouble() ?? 0.0;
    final crb = ((json['carbs'] ?? json['carbohydrates']) as num?)?.toDouble() ?? 0.0;
    final ft = (json['fat'] as num?)?.toDouble() ?? 0.0;
    final fib = (json['fiber'] as num?)?.toDouble() ?? 0.0;

    final srvDisplay = (json['servingDisplay'] as String?) ??
        formatServingDisplay(quantity: qty, unit: unitStr, servings: srv);

    return PrescribedFoodItem(
      foodId: json['foodId'] as String?,
      name: name,
      servingDisplay: srvDisplay,
      quantity: qty,
      unit: unitStr,
      servings: srv,
      servingSize: srvSize,
      baseUnit: bUnit,
      calories: cal,
      protein: pro,
      carbs: crb,
      fat: ft,
      fiber: fib,
      baseCalories: (json['baseCalories'] as num?)?.toDouble(),
      baseProtein: (json['baseProtein'] as num?)?.toDouble(),
      baseCarbs: (json['baseCarbs'] as num?)?.toDouble(),
      baseFat: (json['baseFat'] as num?)?.toDouble(),
      baseFiber: (json['baseFiber'] as num?)?.toDouble(),
    );
  }
}

/// Represents a prescribed meal in an assigned diet plan
class PrescribedMeal {
  final String mealType; // Breakfast, Lunch, Snacks, Dinner
  final String timing; // e.g. "8:00 AM"
  final String? notes;
  final List<PrescribedFoodItem> foods;

  const PrescribedMeal({
    String? mealType,
    String? name,
    required this.timing,
    this.notes,
    int? order,
    List<PrescribedFoodItem>? foods,
    List<PrescribedFoodItem>? items,
  })  : mealType = mealType ?? name ?? 'Meal',
        foods = foods ?? items ?? const [];

  String get name => mealType;
  List<PrescribedFoodItem> get items => foods;

  double get totalCalories => foods.fold(0.0, (acc, f) => acc + f.calories);
  double get totalProtein => foods.fold(0.0, (acc, f) => acc + f.protein);
  double get totalCarbs => foods.fold(0.0, (acc, f) => acc + f.carbs);
  double get totalFat => foods.fold(0.0, (acc, f) => acc + f.fat);
  double get totalFiber => foods.fold(0.0, (acc, f) => acc + f.fiber);

  Map<String, dynamic> toJson() => {
    'mealType': mealType,
    'timing': timing,
    'notes': notes,
    'foods': foods.map((f) => f.toJson()).toList(),
  };

  factory PrescribedMeal.fromJson(Map<String, dynamic> json) {
    final rawFoods = (json['foods'] ?? json['items']) as List<dynamic>? ?? [];
    return PrescribedMeal(
      mealType: (json['mealType'] ?? json['name']) as String? ?? 'Meal',
      timing: json['timing'] as String? ?? '12:00 PM',
      notes: json['notes'] as String?,
      foods: rawFoods.map((f) => PrescribedFoodItem.fromJson(f as Map<String, dynamic>)).toList(),
    );
  }
}

/// Represents the Trainer/Admin Assigned Diet Plan for a Client
/// Separate from the client's Actual Food Log
class AssignedDietPlan {
  final String id;
  final String clientId;
  final String planName;
  final int version;
  final String? assignedById;
  final String? assignedByName;
  final DateTime? startDate;
  final DateTime? endDate;
  final double dailyCalories;
  final double protein;
  final double carbohydrates;
  final double fat;
  final double fiber;
  final double waterTargetLiters;
  final bool isActive;
  final String? notes;
  final List<PrescribedMeal> prescribedMeals;
  final DateTime createdAt;

  const AssignedDietPlan({
    required this.id,
    required this.clientId,
    required this.planName,
    this.version = 1,
    this.assignedById,
    this.assignedByName,
    this.startDate,
    this.endDate,
    required this.dailyCalories,
    required this.protein,
    double? carbohydrates,
    double? carbs,
    required this.fat,
    this.fiber = 30.0,
    double? waterTargetLiters,
    double? waterTarget,
    this.isActive = true,
    this.notes,
    List<PrescribedMeal>? prescribedMeals,
    List<PrescribedMeal>? meals,
    required this.createdAt,
  })  : carbohydrates = carbohydrates ?? carbs ?? 200.0,
        waterTargetLiters = waterTargetLiters ?? waterTarget ?? 3.0,
        prescribedMeals = prescribedMeals ?? meals ?? const [];

  double get carbs => carbohydrates;
  double get waterTarget => waterTargetLiters;
  List<PrescribedMeal> get meals => prescribedMeals;

  Map<String, dynamic> toJson() => {
    'id': id,
    'clientId': clientId,
    'planName': planName,
    'version': version,
    'assignedById': assignedById,
    'assignedByName': assignedByName,
    'startDate': startDate?.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'dailyCalories': dailyCalories,
    'protein': protein,
    'carbohydrates': carbohydrates,
    'fat': fat,
    'fiber': fiber,
    'waterTargetLiters': waterTargetLiters,
    'isActive': isActive,
    'notes': notes,
    'meals': prescribedMeals.map((m) => m.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory AssignedDietPlan.fromJson(Map<String, dynamic> json) {
    List<PrescribedMeal> meals = [];
    if (json['mealsJson'] != null) {
      try {
        final dynamic decoded = json['mealsJson'] is String
            ? jsonDecode(json['mealsJson'] as String)
            : json['mealsJson'];
        if (decoded is List) {
          meals = decoded.map((m) => PrescribedMeal.fromJson(m as Map<String, dynamic>)).toList();
        }
      } catch (_) {}
    } else if (json['meals'] is List) {
      meals = (json['meals'] as List).map((m) => PrescribedMeal.fromJson(m as Map<String, dynamic>)).toList();
    }

    return AssignedDietPlan(
      id: json['id'] as String? ?? 'diet_${DateTime.now().millisecondsSinceEpoch}',
      clientId: json['clientId'] as String? ?? '',
      planName: json['planName'] as String? ?? 'Assigned Nutrition Plan',
      version: (json['version'] as num?)?.toInt() ?? 1,
      assignedById: json['assignedById'] as String?,
      assignedByName: json['assignedByName'] as String? ?? 'Trainer Alex Stone',
      startDate: json['startDate'] != null ? DateTime.tryParse(json['startDate'] as String) : null,
      endDate: json['endDate'] != null ? DateTime.tryParse(json['endDate'] as String) : null,
      dailyCalories: (json['dailyCalories'] as num?)?.toDouble() ?? 2000.0,
      protein: (json['protein'] as num?)?.toDouble() ?? 150.0,
      carbohydrates: (json['carbohydrates'] as num?)?.toDouble() ?? 200.0,
      fat: (json['fat'] as num?)?.toDouble() ?? 60.0,
      fiber: (json['fiber'] as num?)?.toDouble() ?? 30.0,
      waterTargetLiters: (json['waterTargetLiters'] as num?)?.toDouble() ?? 3.0,
      isActive: json['isActive'] as bool? ?? true,
      notes: json['notes'] as String?,
      prescribedMeals: meals,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
