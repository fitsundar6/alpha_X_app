/// Represents a nutritional food item in the Alpha X Food Catalog
class FoodItem {
  final String id;
  final String name;
  final double servingSize;
  final String servingUnit; // 'piece', 'grams', 'cup', 'ml', 'scoop', 'tablespoon'
  final double calories; // kcal per serving
  final double protein; // grams per serving
  final double carbs; // grams per serving
  final double fat; // grams per serving
  final double fiber; // grams per serving
  final double sugar;
  final double sodium;
  final bool isCustom;
  final String category; // 'Breakfast', 'Rice & Meals', 'Protein', 'Fruits', 'Snacks', 'Custom'
  final String source; // 'SYSTEM', 'USDA', 'USER'
  final String? sourceId;
  final String? createdBy;
  final bool isPublic;
  final bool isVerified;
  final String status; // 'APPROVED', 'PENDING', 'REJECTED'

  const FoodItem({
    required this.id,
    required this.name,
    required this.servingSize,
    required this.servingUnit,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.fiber = 0.0,
    this.sugar = 0.0,
    this.sodium = 0.0,
    this.isCustom = false,
    this.category = 'General',
    this.source = 'SYSTEM',
    this.sourceId,
    this.createdBy,
    this.isPublic = true,
    this.isVerified = false,
    this.status = 'APPROVED',
  });

  String get servingDisplay {
    final sizeStr = servingSize % 1 == 0 ? servingSize.toInt().toString() : servingSize.toStringAsFixed(1);
    return '$sizeStr $servingUnit';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'servingSize': servingSize,
    'servingUnit': servingUnit,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'fiber': fiber,
    'sugar': sugar,
    'sodium': sodium,
    'isCustom': isCustom,
    'category': category,
    'source': source,
    'sourceId': sourceId,
    'createdBy': createdBy,
    'isPublic': isPublic,
    'isVerified': isVerified,
    'status': status,
  };

  factory FoodItem.fromJson(Map<String, dynamic> json) => FoodItem(
    id: json['id'] as String,
    name: json['name'] as String,
    servingSize: (json['servingSize'] as num).toDouble(),
    servingUnit: json['servingUnit'] as String,
    calories: (json['calories'] as num).toDouble(),
    protein: (json['protein'] as num).toDouble(),
    carbs: (json['carbs'] as num).toDouble(),
    fat: (json['fat'] as num).toDouble(),
    fiber: (json['fiber'] as num?)?.toDouble() ?? 0.0,
    sugar: (json['sugar'] as num?)?.toDouble() ?? 0.0,
    sodium: (json['sodium'] as num?)?.toDouble() ?? 0.0,
    isCustom: json['isCustom'] as bool? ?? false,
    category: json['category'] as String? ?? 'General',
    source: json['source'] as String? ?? 'SYSTEM',
    sourceId: json['sourceId'] as String?,
    createdBy: json['createdBy'] as String?,
    isPublic: json['isPublic'] as bool? ?? true,
    isVerified: json['isVerified'] as bool? ?? false,
    status: json['status'] as String? ?? 'APPROVED',
  );

  FoodItem copyWith({
    String? id,
    String? name,
    double? servingSize,
    String? servingUnit,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    double? fiber,
    double? sugar,
    double? sodium,
    bool? isCustom,
    String? category,
    String? source,
    String? sourceId,
    String? createdBy,
    bool? isPublic,
    bool? isVerified,
    String? status,
  }) {
    return FoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      servingSize: servingSize ?? this.servingSize,
      servingUnit: servingUnit ?? this.servingUnit,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      fiber: fiber ?? this.fiber,
      sugar: sugar ?? this.sugar,
      sodium: sodium ?? this.sodium,
      isCustom: isCustom ?? this.isCustom,
      category: category ?? this.category,
      source: source ?? this.source,
      sourceId: sourceId ?? this.sourceId,
      createdBy: createdBy ?? this.createdBy,
      isPublic: isPublic ?? this.isPublic,
      isVerified: isVerified ?? this.isVerified,
      status: status ?? this.status,
    );
  }
}
