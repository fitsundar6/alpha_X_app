import 'dart:typed_data';
import 'food_item.dart';
import 'food_log_entry.dart';
import 'meal_type.dart';

/// Represents a single food item detected in a live camera photo by AI
class ScannedFoodItem {
  final String name;
  final String? matchedFoodId;
  final String category;
  final double estimatedGrams;
  final String servingDisplay;
  final double confidence;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final bool isEstimate;
  final String source; // 'ALPHA_X_LIBRARY' or 'AI_ESTIMATE'
  final String weightSource; // 'AI_ESTIMATE', 'SMART_SCALE_BLE', 'CLIENT_ENTERED'

  const ScannedFoodItem({
    required this.name,
    this.matchedFoodId,
    this.category = 'General',
    required this.estimatedGrams,
    required this.servingDisplay,
    this.confidence = 0.85,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.fiber = 0.0,
    this.isEstimate = true,
    this.source = 'AI_ESTIMATE',
    this.weightSource = 'AI_ESTIMATE',
  });

  bool get isFromFoodLibrary => source == 'ALPHA_X_LIBRARY';
  bool get isAiEstimated => weightSource == 'AI_ESTIMATE';
  bool get isSmartScale => weightSource == 'SMART_SCALE_BLE';
  bool get isClientEntered => weightSource == 'CLIENT_ENTERED';

  ScannedFoodItem copyWith({
    String? name,
    String? matchedFoodId,
    String? category,
    double? estimatedGrams,
    String? servingDisplay,
    double? confidence,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    double? fiber,
    bool? isEstimate,
    String? source,
    String? weightSource,
  }) {
    return ScannedFoodItem(
      name: name ?? this.name,
      matchedFoodId: matchedFoodId ?? this.matchedFoodId,
      category: category ?? this.category,
      estimatedGrams: estimatedGrams ?? this.estimatedGrams,
      servingDisplay: servingDisplay ?? this.servingDisplay,
      confidence: confidence ?? this.confidence,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      fiber: fiber ?? this.fiber,
      isEstimate: isEstimate ?? this.isEstimate,
      source: source ?? this.source,
      weightSource: weightSource ?? this.weightSource,
    );
  }

  /// Recalculate nutrition proportionally when user edits portion size in grams
  ScannedFoodItem updatePortionGrams(double newGrams, {String? newWeightSource}) {
    if (estimatedGrams <= 0 || newGrams <= 0) return this;
    final ratio = newGrams / estimatedGrams;
    final newDisplay = newGrams % 1 == 0
        ? '${newGrams.toInt()} g'
        : '${newGrams.toStringAsFixed(1)} g';

    return copyWith(
      estimatedGrams: newGrams,
      servingDisplay: newDisplay,
      calories: double.parse((calories * ratio).toStringAsFixed(1)),
      protein: double.parse((protein * ratio).toStringAsFixed(1)),
      carbs: double.parse((carbs * ratio).toStringAsFixed(1)),
      fat: double.parse((fat * ratio).toStringAsFixed(1)),
      fiber: double.parse((fiber * ratio).toStringAsFixed(1)),
      isEstimate: false,
      weightSource: newWeightSource ?? 'CLIENT_ENTERED',
    );
  }

  /// Convert into standard FoodLogEntry for logging into the client's Food Log
  FoodLogEntry toFoodLogEntry({
    required String clientId,
    required String dateString,
    required MealType mealType,
    String? mealId,
    String? mealPhotoId,
    bool photoAvailable = false,
  }) {
    final entryId = 'fscan_${DateTime.now().millisecondsSinceEpoch}_${name.replaceAll(RegExp(r'\s+'), '_').toLowerCase()}';
    return FoodLogEntry(
      id: entryId,
      clientId: clientId,
      dateString: dateString,
      mealType: mealType,
      foodId: matchedFoodId ?? 'ai_detected_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
      foodName: name,
      quantity: 1.0,
      servingUnit: 'grams',
      servingSize: estimatedGrams,
      baseCalories: calories,
      baseProtein: protein,
      baseCarbs: carbs,
      baseFat: fat,
      baseFiber: fiber,
      source: 'AI_CAMERA',
      isAiConfirmed: true,
      category: category,
      photoAvailable: photoAvailable,
      mealPhotoId: mealPhotoId,
      weightSource: weightSource,
      mealId: mealId,
      loggedAt: DateTime.now(),
      createdAt: DateTime.now(),
    );
  }

  /// Convert into a FoodItem representation
  FoodItem toFoodItem() {
    return FoodItem(
      id: matchedFoodId ?? 'ai_detected_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
      name: name,
      servingSize: estimatedGrams,
      servingUnit: 'grams',
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      fiber: fiber,
      isCustom: true,
      category: category,
      source: isFromFoodLibrary ? 'SYSTEM' : 'USER',
      isPublic: false,
    );
  }

  factory ScannedFoodItem.fromJson(Map<String, dynamic> json) {
    return ScannedFoodItem(
      name: json['name'] as String? ?? 'Detected Food',
      matchedFoodId: json['matchedFoodId'] as String?,
      category: json['category'] as String? ?? 'General',
      estimatedGrams: (json['estimatedGrams'] as num?)?.toDouble() ?? 100.0,
      servingDisplay: json['servingDisplay'] as String? ?? '100 g',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.8,
      calories: (json['calories'] as num?)?.toDouble() ?? 0.0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0.0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0.0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0.0,
      fiber: (json['fiber'] as num?)?.toDouble() ?? 0.0,
      isEstimate: json['isEstimate'] as bool? ?? true,
      source: json['source'] as String? ?? 'AI_ESTIMATE',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'matchedFoodId': matchedFoodId,
    'category': category,
    'estimatedGrams': estimatedGrams,
    'servingDisplay': servingDisplay,
    'confidence': confidence,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'fiber': fiber,
    'isEstimate': isEstimate,
    'source': source,
  };
}

/// Represents the complete analysis response of a scanned meal
class AiMealScanResult {
  final String scanId;
  final String mealName;
  final DateTime detectedAt;
  final List<ScannedFoodItem> foods;
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final double totalFiber;
  final bool isLowConfidence;
  final String disclaimer;
  final String? capturedPhotoPath;
  final Uint8List? capturedPhotoBytes;
  final String weightSource;
  final String? mealPhotoId;

  const AiMealScanResult({
    required this.scanId,
    required this.mealName,
    required this.detectedAt,
    required this.foods,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    required this.totalFiber,
    this.isLowConfidence = false,
    this.disclaimer = 'Nutritional values are AI visual estimates based on visible portion sizes. Confirm or edit before logging.',
    this.capturedPhotoPath,
    this.capturedPhotoBytes,
    this.weightSource = 'AI_ESTIMATE',
    this.mealPhotoId,
  });

  bool get hasCapturedPhoto =>
      (capturedPhotoPath != null && capturedPhotoPath!.isNotEmpty) ||
      (capturedPhotoBytes != null && capturedPhotoBytes!.isNotEmpty);

  // Dynamic totals that recalculate automatically if foods are edited or removed
  double get liveCalories => foods.fold(0.0, (acc, f) => acc + f.calories);
  double get liveProtein => foods.fold(0.0, (acc, f) => acc + f.protein);
  double get liveCarbs => foods.fold(0.0, (acc, f) => acc + f.carbs);
  double get liveFat => foods.fold(0.0, (acc, f) => acc + f.fat);
  double get liveFiber => foods.fold(0.0, (acc, f) => acc + f.fiber);

  AiMealScanResult copyWith({
    String? scanId,
    String? mealName,
    DateTime? detectedAt,
    List<ScannedFoodItem>? foods,
    double? totalCalories,
    double? totalProtein,
    double? totalCarbs,
    double? totalFat,
    double? totalFiber,
    bool? isLowConfidence,
    String? disclaimer,
    String? capturedPhotoPath,
    Uint8List? capturedPhotoBytes,
    String? weightSource,
    String? mealPhotoId,
  }) {
    final updatedFoods = foods ?? this.foods;
    return AiMealScanResult(
      scanId: scanId ?? this.scanId,
      mealName: mealName ?? this.mealName,
      detectedAt: detectedAt ?? this.detectedAt,
      foods: updatedFoods,
      totalCalories: totalCalories ?? updatedFoods.fold(0.0, (acc, f) => acc + f.calories),
      totalProtein: totalProtein ?? updatedFoods.fold(0.0, (acc, f) => acc + f.protein),
      totalCarbs: totalCarbs ?? updatedFoods.fold(0.0, (acc, f) => acc + f.carbs),
      totalFat: totalFat ?? updatedFoods.fold(0.0, (acc, f) => acc + f.fat),
      totalFiber: totalFiber ?? updatedFoods.fold(0.0, (acc, f) => acc + f.fiber),
      isLowConfidence: isLowConfidence ?? this.isLowConfidence,
      disclaimer: disclaimer ?? this.disclaimer,
      capturedPhotoPath: capturedPhotoPath ?? this.capturedPhotoPath,
      capturedPhotoBytes: capturedPhotoBytes ?? this.capturedPhotoBytes,
      weightSource: weightSource ?? this.weightSource,
      mealPhotoId: mealPhotoId ?? this.mealPhotoId,
    );
  }

  factory AiMealScanResult.fromJson(Map<String, dynamic> json) {
    final rawFoods = (json['foods'] as List<dynamic>? ?? [])
        .map((f) => ScannedFoodItem.fromJson(f as Map<String, dynamic>))
        .toList();

    return AiMealScanResult(
      scanId: json['scanId'] as String? ?? 'scan_${DateTime.now().millisecondsSinceEpoch}',
      mealName: json['mealName'] as String? ?? 'Detected Meal',
      detectedAt: json['detectedAt'] != null
          ? DateTime.tryParse(json['detectedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      foods: rawFoods,
      totalCalories: (json['totalCalories'] as num?)?.toDouble() ?? 0.0,
      totalProtein: (json['totalProtein'] as num?)?.toDouble() ?? 0.0,
      totalCarbs: (json['totalCarbs'] as num?)?.toDouble() ?? 0.0,
      totalFat: (json['totalFat'] as num?)?.toDouble() ?? 0.0,
      totalFiber: (json['totalFiber'] as num?)?.toDouble() ?? 0.0,
      isLowConfidence: json['isLowConfidence'] as bool? ?? false,
      disclaimer: json['disclaimer'] as String? ??
          'Nutritional values are AI visual estimates based on visible portion sizes. Confirm or edit before logging.',
      capturedPhotoPath: json['capturedPhotoPath'] as String?,
      weightSource: json['weightSource'] as String? ?? 'AI_ESTIMATE',
      mealPhotoId: json['mealPhotoId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'scanId': scanId,
    'mealName': mealName,
    'detectedAt': detectedAt.toIso8601String(),
    'foods': foods.map((f) => f.toJson()).toList(),
    'totalCalories': liveCalories,
    'totalProtein': liveProtein,
    'totalCarbs': liveCarbs,
    'totalFat': liveFat,
    'totalFiber': liveFiber,
    'isLowConfidence': isLowConfidence,
    'disclaimer': disclaimer,
    'weightSource': weightSource,
    'mealPhotoId': mealPhotoId,
  };
}
