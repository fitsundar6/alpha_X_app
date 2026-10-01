import 'dart:convert';

/// Represents a single food item in an assigned meal prescription
class PrescribedFoodItem {
  final String name;
  final String servingDisplay;
  final double quantity;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;

  const PrescribedFoodItem({
    required this.name,
    String? servingDisplay,
    String? unit,
    this.quantity = 1.0,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.fiber = 0.0,
  }) : servingDisplay = servingDisplay ?? unit ?? '1 serving';

  String get unit => servingDisplay;
  String get quantityDisplay => quantity % 1 == 0 ? quantity.toInt().toString() : quantity.toStringAsFixed(1);

  Map<String, dynamic> toJson() => {
    'name': name,
    'servingDisplay': servingDisplay,
    'quantity': quantity,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'fiber': fiber,
  };

  factory PrescribedFoodItem.fromJson(Map<String, dynamic> json) => PrescribedFoodItem(
    name: json['name'] as String? ?? 'Food',
    servingDisplay: (json['servingDisplay'] ?? json['unit']) as String? ?? '1 serving',
    quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
    calories: (json['calories'] as num?)?.toDouble() ?? 0.0,
    protein: (json['protein'] as num?)?.toDouble() ?? 0.0,
    carbs: (json['carbs'] as num?)?.toDouble() ?? 0.0,
    fat: (json['fat'] as num?)?.toDouble() ?? 0.0,
    fiber: (json['fiber'] as num?)?.toDouble() ?? 0.0,
  );
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

  double get totalCalories => foods.fold(0.0, (acc, f) => acc + f.calories * f.quantity);
  double get totalProtein => foods.fold(0.0, (acc, f) => acc + f.protein * f.quantity);
  double get totalCarbs => foods.fold(0.0, (acc, f) => acc + f.carbs * f.quantity);
  double get totalFat => foods.fold(0.0, (acc, f) => acc + f.fat * f.quantity);
  double get totalFiber => foods.fold(0.0, (acc, f) => acc + f.fiber * f.quantity);

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
