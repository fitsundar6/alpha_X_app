import 'package:flutter/material.dart';

class MuscleGroupTelemetry {
  final String muscleGroup;
  final String displayName;
  final int totalSets;
  final double totalVolumeKg;
  final String status;
  final Color statusColor;
  final List<String> topExercises;

  const MuscleGroupTelemetry({
    required this.muscleGroup,
    required this.displayName,
    required this.totalSets,
    required this.totalVolumeKg,
    required this.status,
    required this.statusColor,
    required this.topExercises,
  });

  factory MuscleGroupTelemetry.fromJson(Map<String, dynamic> json) {
    Color parseHexColor(String hex) {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    }

    return MuscleGroupTelemetry(
      muscleGroup: json['muscleGroup'] ?? '',
      displayName: json['displayName'] ?? '',
      totalSets: (json['totalSets'] as num?)?.toInt() ?? 0,
      totalVolumeKg: (json['totalVolumeKg'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'OPTIMAL',
      statusColor: parseHexColor(json['statusColor'] ?? '#00FF87'),
      topExercises: (json['topExercises'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class PRHighlight {
  final String exerciseName;
  final String type;
  final double value;
  final double? weight;
  final int? reps;
  final String achievedAt;

  const PRHighlight({
    required this.exerciseName,
    required this.type,
    required this.value,
    this.weight,
    this.reps,
    required this.achievedAt,
  });

  factory PRHighlight.fromJson(Map<String, dynamic> json) {
    return PRHighlight(
      exerciseName: json['exerciseName'] ?? '',
      type: json['type'] ?? 'WEIGHT',
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      weight: (json['weight'] as num?)?.toDouble(),
      reps: (json['reps'] as num?)?.toInt(),
      achievedAt: json['achievedAt'] ?? '',
    );
  }
}

class PhysicalComparison {
  final double tonnageKg;
  final String equivalentLabel;
  final int itemCount;
  final String itemIcon;
  final String description;

  const PhysicalComparison({
    required this.tonnageKg,
    required this.equivalentLabel,
    required this.itemCount,
    required this.itemIcon,
    required this.description,
  });

  factory PhysicalComparison.fromJson(Map<String, dynamic> json) {
    return PhysicalComparison(
      tonnageKg: (json['tonnageKg'] as num?)?.toDouble() ?? 0.0,
      equivalentLabel: json['equivalentLabel'] ?? '',
      itemCount: (json['itemCount'] as num?)?.toInt() ?? 1,
      itemIcon: json['itemIcon'] ?? '🛻',
      description: json['description'] ?? '',
    );
  }
}

class WeeklyTelemetryReport {
  final String id;
  final String clientId;
  final String clientName;
  final int weekNumber;
  final int year;
  final String startDate;
  final String endDate;
  final int totalWorkoutsCompleted;
  final int targetWorkouts;
  final int adherencePercentage;
  final int totalDurationMinutes;
  final double totalVolumeKg;
  final int completedSetsCount;
  final double? averageRpe;
  final PhysicalComparison physicalComparison;
  final List<MuscleGroupTelemetry> muscleHeatmap;
  final List<PRHighlight> personalRecords;
  final String aiCoachCommentary;
  final int streakWeeks;
  final String generatedAt;

  const WeeklyTelemetryReport({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.weekNumber,
    required this.year,
    required this.startDate,
    required this.endDate,
    required this.totalWorkoutsCompleted,
    required this.targetWorkouts,
    required this.adherencePercentage,
    required this.totalDurationMinutes,
    required this.totalVolumeKg,
    required this.completedSetsCount,
    this.averageRpe,
    required this.physicalComparison,
    required this.muscleHeatmap,
    required this.personalRecords,
    required this.aiCoachCommentary,
    required this.streakWeeks,
    required this.generatedAt,
  });

  factory WeeklyTelemetryReport.fromJson(Map<String, dynamic> json) {
    return WeeklyTelemetryReport(
      id: json['id'] ?? '',
      clientId: json['clientId'] ?? '',
      clientName: json['clientName'] ?? 'Athlete',
      weekNumber: (json['weekNumber'] as num?)?.toInt() ?? 1,
      year: (json['year'] as num?)?.toInt() ?? 2026,
      startDate: json['startDate'] ?? '',
      endDate: json['endDate'] ?? '',
      totalWorkoutsCompleted: (json['totalWorkoutsCompleted'] as num?)?.toInt() ?? 0,
      targetWorkouts: (json['targetWorkouts'] as num?)?.toInt() ?? 4,
      adherencePercentage: (json['adherencePercentage'] as num?)?.toInt() ?? 0,
      totalDurationMinutes: (json['totalDurationMinutes'] as num?)?.toInt() ?? 0,
      totalVolumeKg: (json['totalVolumeKg'] as num?)?.toDouble() ?? 0.0,
      completedSetsCount: (json['completedSetsCount'] as num?)?.toInt() ?? 0,
      averageRpe: (json['averageRpe'] as num?)?.toDouble(),
      physicalComparison: PhysicalComparison.fromJson(json['physicalComparison'] ?? {}),
      muscleHeatmap: (json['muscleHeatmap'] as List<dynamic>?)
              ?.map((e) => MuscleGroupTelemetry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      personalRecords: (json['personalRecords'] as List<dynamic>?)
              ?.map((e) => PRHighlight.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      aiCoachCommentary: json['aiCoachCommentary'] ?? '',
      streakWeeks: (json['streakWeeks'] as num?)?.toInt() ?? 1,
      generatedAt: json['generatedAt'] ?? '',
    );
  }
}
