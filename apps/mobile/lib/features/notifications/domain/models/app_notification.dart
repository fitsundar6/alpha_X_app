/// Represents an automated or AI-generated notification for an Alpha X athlete
class AppNotification {
  final String id;
  final String title;
  final String message;
  final String type; // WORKOUT, NUTRITION, CHECK_IN, ACTIVITY, MEMBERSHIP, SYSTEM
  final String category;
  final String priority; // LOW, NORMAL, HIGH, URGENT
  final String source; // AUTOMATION_RULE, AI_COACH, ADMIN, SYSTEM
  final String? triggerRule;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.category = 'GENERAL',
    this.priority = 'NORMAL',
    this.source = 'AUTOMATION_RULE',
    this.triggerRule,
    this.isRead = false,
    this.readAt,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Alpha X Update',
      message: json['message']?.toString() ?? '',
      type: json['type']?.toString() ?? 'SYSTEM',
      category: json['category']?.toString() ?? 'GENERAL',
      priority: json['priority']?.toString() ?? 'NORMAL',
      source: json['source']?.toString() ?? 'AUTOMATION_RULE',
      triggerRule: json['triggerRule']?.toString(),
      isRead: json['isRead'] == true,
      readAt: json['readAt'] != null ? DateTime.tryParse(json['readAt'].toString()) : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type,
      'category': category,
      'priority': priority,
      'source': source,
      'triggerRule': triggerRule,
      'isRead': isRead,
      'readAt': readAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  AppNotification copyWith({
    String? id,
    String? title,
    String? message,
    String? type,
    String? category,
    String? priority,
    String? source,
    String? triggerRule,
    bool? isRead,
    DateTime? readAt,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      source: source ?? this.source,
      triggerRule: triggerRule ?? this.triggerRule,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class NotificationPreferences {
  final bool workoutReminders;
  final bool nutritionReminders;
  final bool weeklyCheckInReminders;
  final bool activityReminders;
  final bool membershipAlerts;
  final bool aiEngagementEnabled;

  const NotificationPreferences({
    this.workoutReminders = true,
    this.nutritionReminders = true,
    this.weeklyCheckInReminders = true,
    this.activityReminders = true,
    this.membershipAlerts = true,
    this.aiEngagementEnabled = true,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      workoutReminders: json['workoutReminders'] != false,
      nutritionReminders: json['nutritionReminders'] != false,
      weeklyCheckInReminders: json['weeklyCheckInReminders'] != false,
      activityReminders: json['activityReminders'] != false,
      membershipAlerts: json['membershipAlerts'] != false,
      aiEngagementEnabled: json['aiEngagementEnabled'] != false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'workoutReminders': workoutReminders,
      'nutritionReminders': nutritionReminders,
      'weeklyCheckInReminders': weeklyCheckInReminders,
      'activityReminders': activityReminders,
      'membershipAlerts': membershipAlerts,
      'aiEngagementEnabled': aiEngagementEnabled,
    };
  }
}
