import 'package:intl/intl.dart';

/// Represents a client's captured live food photo for trainer review and verification.
/// Evidence-only model: contains no AI estimates or automatic food log entries.
class FoodPhotoModel {
  final String id;
  final String clientId;
  final String? clientName;
  final String? clientEmail;
  final String dateString;
  final String mealType;
  final DateTime capturedAt;
  final String status; // PENDING, VERIFIED, NEEDS_ATTENTION
  final String? clientNote;
  final String? adminNote;
  final DateTime? verifiedAt;
  final String photoUrl;
  final String? localFilePath;
  final bool isPendingSync;
  final String timezone;

  FoodPhotoModel({
    required this.id,
    required this.clientId,
    this.clientName,
    this.clientEmail,
    required this.dateString,
    required this.mealType,
    required this.capturedAt,
    this.status = 'PENDING',
    this.clientNote,
    this.adminNote,
    this.verifiedAt,
    required this.photoUrl,
    this.localFilePath,
    this.isPendingSync = false,
    this.timezone = 'UTC',
  });

  bool get isVerified => status.toUpperCase() == 'VERIFIED';
  bool get isNeedsAttention => status.toUpperCase() == 'NEEDS_ATTENTION';
  bool get isPending => status.toUpperCase() == 'PENDING';

  String get formattedDateTime {
    return DateFormat('dd MMM yyyy • h:mm a').format(capturedAt);
  }

  String get formattedDate {
    return DateFormat('dd MMM yyyy').format(capturedAt);
  }

  String get formattedTime {
    return DateFormat('h:mm a').format(capturedAt);
  }

  factory FoodPhotoModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedCapturedAt;
    try {
      parsedCapturedAt = json['capturedAt'] != null
          ? DateTime.parse(json['capturedAt'].toString())
          : DateTime.now();
    } catch (_) {
      parsedCapturedAt = DateTime.now();
    }

    DateTime? parsedVerifiedAt;
    if (json['verifiedAt'] != null) {
      try {
        parsedVerifiedAt = DateTime.parse(json['verifiedAt'].toString());
      } catch (_) {}
    }

    return FoodPhotoModel(
      id: json['id']?.toString() ?? '',
      clientId: json['clientId']?.toString() ?? 'AXG-CLIENT',
      clientName: json['clientName']?.toString(),
      clientEmail: json['clientEmail']?.toString(),
      dateString: json['dateString']?.toString() ?? DateFormat('yyyy-MM-dd').format(parsedCapturedAt),
      mealType: json['mealType']?.toString() ?? 'Lunch',
      capturedAt: parsedCapturedAt,
      status: json['status']?.toString().toUpperCase() ?? 'PENDING',
      clientNote: json['clientNote']?.toString(),
      adminNote: json['adminNote']?.toString(),
      verifiedAt: parsedVerifiedAt,
      photoUrl: json['photoUrl']?.toString() ?? '',
      localFilePath: json['localFilePath']?.toString(),
      isPendingSync: json['isPendingSync'] == true,
      timezone: json['timezone']?.toString() ?? 'UTC',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clientId': clientId,
      'clientName': clientName,
      'clientEmail': clientEmail,
      'dateString': dateString,
      'mealType': mealType,
      'capturedAt': capturedAt.toIso8601String(),
      'status': status,
      'clientNote': clientNote,
      'adminNote': adminNote,
      'verifiedAt': verifiedAt?.toIso8601String(),
      'photoUrl': photoUrl,
      'localFilePath': localFilePath,
      'isPendingSync': isPendingSync,
      'timezone': timezone,
    };
  }

  FoodPhotoModel copyWith({
    String? id,
    String? clientId,
    String? clientName,
    String? clientEmail,
    String? dateString,
    String? mealType,
    DateTime? capturedAt,
    String? status,
    String? clientNote,
    String? adminNote,
    DateTime? verifiedAt,
    String? photoUrl,
    String? localFilePath,
    bool? isPendingSync,
    String? timezone,
  }) {
    return FoodPhotoModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      clientEmail: clientEmail ?? this.clientEmail,
      dateString: dateString ?? this.dateString,
      mealType: mealType ?? this.mealType,
      capturedAt: capturedAt ?? this.capturedAt,
      status: status ?? this.status,
      clientNote: clientNote ?? this.clientNote,
      adminNote: adminNote ?? this.adminNote,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      photoUrl: photoUrl ?? this.photoUrl,
      localFilePath: localFilePath ?? this.localFilePath,
      isPendingSync: isPendingSync ?? this.isPendingSync,
      timezone: timezone ?? this.timezone,
    );
  }
}
