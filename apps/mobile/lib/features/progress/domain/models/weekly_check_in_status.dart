import 'weekly_check_in.dart';

/// Status of the Client's weekly check-in availability
class WeeklyCheckInStatus {
  final bool isAvailable;
  final int currentWeekNumber;
  final WeeklyCheckIn? lastCheckIn;
  final DateTime? nextCheckInDate;
  final int daysUntilNext;
  final String statusText;

  const WeeklyCheckInStatus({
    required this.isAvailable,
    required this.currentWeekNumber,
    this.lastCheckIn,
    this.nextCheckInDate,
    required this.daysUntilNext,
    required this.statusText,
  });

  factory WeeklyCheckInStatus.initial() => const WeeklyCheckInStatus(
    isAvailable: true,
    currentWeekNumber: 1,
    lastCheckIn: null,
    nextCheckInDate: null,
    daysUntilNext: 0,
    statusText: 'Week 1 Check-In Available',
  );

  factory WeeklyCheckInStatus.fromJson(Map<String, dynamic> json) {
    return WeeklyCheckInStatus(
      isAvailable: json['isAvailable'] as bool? ?? false,
      currentWeekNumber: (json['currentWeekNumber'] as num?)?.toInt() ?? 1,
      lastCheckIn: json['lastCheckIn'] != null && json['lastCheckIn'] is Map<String, dynamic>
          ? WeeklyCheckIn.fromJson(json['lastCheckIn'] as Map<String, dynamic>)
          : null,
      nextCheckInDate: json['nextCheckInDate'] != null
          ? DateTime.tryParse(json['nextCheckInDate'].toString())
          : null,
      daysUntilNext: (json['daysUntilNext'] as num?)?.toInt() ?? 0,
      statusText: json['statusText'] as String? ?? 'Weekly Check-In Status',
    );
  }
}
