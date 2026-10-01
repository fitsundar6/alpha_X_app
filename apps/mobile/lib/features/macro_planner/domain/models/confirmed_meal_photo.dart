import 'package:intl/intl.dart';

/// Represents a confirmed meal photo stored securely on the backend
class ConfirmedMealPhoto {
  final String id;
  final String mealId;
  final String clientId;
  final String? clientName;
  final String dateString;
  final String mealType;
  final DateTime confirmedAt;
  final DateTime? capturedAt;
  final String weightSource; // 'AI_ESTIMATE', 'SMART_SCALE_BLE', 'CLIENT_ENTERED'
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final double totalFiber;
  final String photoUrl;
  final bool photoAvailable;
  final List<Map<String, dynamic>> items;

  const ConfirmedMealPhoto({
    required this.id,
    required this.mealId,
    required this.clientId,
    this.clientName,
    required this.dateString,
    required this.mealType,
    required this.confirmedAt,
    this.capturedAt,
    this.weightSource = 'AI_ESTIMATE',
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    this.totalFiber = 0.0,
    required this.photoUrl,
    this.photoAvailable = true,
    this.items = const [],
  });

  bool get isAiEstimated => weightSource == 'AI_ESTIMATE';
  bool get isSmartScale => weightSource == 'SMART_SCALE_BLE';
  bool get isClientEntered => weightSource == 'CLIENT_ENTERED';

  String get weightSourceBadgeText {
    if (isSmartScale) return 'SMART SCALE MEASURED';
    if (isAiEstimated) return 'AI ESTIMATED PORTION';
    return 'CLIENT ENTERED WEIGHT';
  }

  String get formattedDateTime {
    final localTime = confirmedAt.toLocal();
    return DateFormat('dd MMM yyyy • h:mm a').format(localTime);
  }

  String get formattedTime {
    final localTime = confirmedAt.toLocal();
    return DateFormat('h:mm a').format(localTime);
  }

  String get itemsSummaryText {
    if (items.isEmpty) return mealType;
    final names = items.map((i) => i['foodName'] ?? i['name'] ?? 'Food').take(4).join(' • ');
    return items.length > 4 ? '$names...' : names;
  }

  factory ConfirmedMealPhoto.fromJson(Map<String, dynamic> json) {
    DateTime parsedConfirmed = DateTime.now();
    if (json['confirmedAt'] != null) {
      parsedConfirmed = DateTime.tryParse(json['confirmedAt'].toString()) ?? DateTime.now();
    } else if (json['createdAt'] != null) {
      parsedConfirmed = DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now();
    }

    DateTime? parsedCaptured;
    if (json['capturedAt'] != null) {
      parsedCaptured = DateTime.tryParse(json['capturedAt'].toString());
    }

    List<Map<String, dynamic>> parsedItems = [];
    if (json['items'] is List) {
      parsedItems = (json['items'] as List)
          .whereType<Map<String, dynamic>>()
          .toList();
    }

    return ConfirmedMealPhoto(
      id: json['id']?.toString() ?? '',
      mealId: json['mealId']?.toString() ?? '',
      clientId: json['clientId']?.toString() ?? '',
      clientName: json['clientName']?.toString(),
      dateString: json['dateString']?.toString() ?? '',
      mealType: json['mealType']?.toString() ?? 'Meal',
      confirmedAt: parsedConfirmed,
      capturedAt: parsedCaptured,
      weightSource: json['weightSource']?.toString() ?? 'AI_ESTIMATE',
      totalCalories: (json['totalCalories'] as num?)?.toDouble() ?? 0.0,
      totalProtein: (json['totalProtein'] as num?)?.toDouble() ?? 0.0,
      totalCarbs: (json['totalCarbs'] as num?)?.toDouble() ?? 0.0,
      totalFat: (json['totalFat'] as num?)?.toDouble() ?? 0.0,
      totalFiber: (json['totalFiber'] as num?)?.toDouble() ?? 0.0,
      photoUrl: json['photoUrl']?.toString() ?? '',
      photoAvailable: json['photoAvailable'] as bool? ?? true,
      items: parsedItems,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'mealId': mealId,
    'clientId': clientId,
    'clientName': clientName,
    'dateString': dateString,
    'mealType': mealType,
    'confirmedAt': confirmedAt.toIso8601String(),
    'capturedAt': capturedAt?.toIso8601String(),
    'weightSource': weightSource,
    'totalCalories': totalCalories,
    'totalProtein': totalProtein,
    'totalCarbs': totalCarbs,
    'totalFat': totalFat,
    'totalFiber': totalFiber,
    'photoUrl': photoUrl,
    'photoAvailable': photoAvailable,
    'items': items,
  };
}
