enum SetType {
  warmup,
  working,
  failure,
  dropSet,
  restPause,
  amrap,
  backOff,
  activation,
}

extension SetTypeExtension on SetType {
  String get displayName {
    switch (this) {
      case SetType.warmup:
        return 'Warm-up';
      case SetType.working:
        return 'Working';
      case SetType.failure:
        return 'Failure';
      case SetType.dropSet:
        return 'Drop Set';
      case SetType.restPause:
        return 'Rest-Pause';
      case SetType.amrap:
        return 'AMRAP';
      case SetType.backOff:
        return 'Back-off';
      case SetType.activation:
        return 'Activation';
    }
  }

  String get shortTag {
    switch (this) {
      case SetType.warmup:
        return 'W';
      case SetType.working:
        return '1';
      case SetType.failure:
        return 'F';
      case SetType.dropSet:
        return 'D';
      case SetType.restPause:
        return 'RP';
      case SetType.amrap:
        return 'A';
      case SetType.backOff:
        return 'BO';
      case SetType.activation:
        return 'ACT';
    }
  }

  static SetType fromString(String? type) {
    if (type == null) return SetType.working;
    final lower = type.toLowerCase().replaceAll('-', '').replaceAll(' ', '').replaceAll('_', '');
    if (lower.contains('warm')) return SetType.warmup;
    if (lower.contains('fail')) return SetType.failure;
    if (lower.contains('drop')) return SetType.dropSet;
    if (lower.contains('pause')) return SetType.restPause;
    if (lower.contains('amrap')) return SetType.amrap;
    if (lower.contains('back')) return SetType.backOff;
    if (lower.contains('act')) return SetType.activation;
    return SetType.working;
  }
}

enum AdvancedTrainingMethod {
  straightSets,
  superset,
  giantSet,
  dropSet,
  restPause,
  pyramid,
  reversePyramid,
  amrap,
  emom,
  circuit,
}

extension AdvancedTrainingMethodExtension on AdvancedTrainingMethod {
  String get displayName {
    switch (this) {
      case AdvancedTrainingMethod.straightSets:
        return 'Straight Sets';
      case AdvancedTrainingMethod.superset:
        return 'Superset (A1/A2)';
      case AdvancedTrainingMethod.giantSet:
        return 'Giant Set (A1–A4)';
      case AdvancedTrainingMethod.dropSet:
        return 'Drop Set';
      case AdvancedTrainingMethod.restPause:
        return 'Rest-Pause';
      case AdvancedTrainingMethod.pyramid:
        return 'Ascending Pyramid';
      case AdvancedTrainingMethod.reversePyramid:
        return 'Reverse Pyramid';
      case AdvancedTrainingMethod.amrap:
        return 'AMRAP';
      case AdvancedTrainingMethod.emom:
        return 'EMOM';
      case AdvancedTrainingMethod.circuit:
        return 'Circuit';
    }
  }

  static AdvancedTrainingMethod fromString(String? method) {
    if (method == null) return AdvancedTrainingMethod.straightSets;
    for (final m in AdvancedTrainingMethod.values) {
      if (m.name.toLowerCase() == method.toLowerCase() ||
          m.displayName.toLowerCase() == method.toLowerCase()) {
        return m;
      }
    }
    return AdvancedTrainingMethod.straightSets;
  }
}

enum WorkoutSectionType {
  warmUp,
  mainWorkout,
  mobility,
  coolDown,
  custom,
}

extension WorkoutSectionTypeExtension on WorkoutSectionType {
  String get displayName {
    switch (this) {
      case WorkoutSectionType.warmUp:
        return 'Warm-up';
      case WorkoutSectionType.mainWorkout:
        return 'Main Workout';
      case WorkoutSectionType.mobility:
        return 'Mobility';
      case WorkoutSectionType.coolDown:
        return 'Cool-down';
      case WorkoutSectionType.custom:
        return 'Custom Section';
    }
  }

  String get defaultDescription {
    switch (this) {
      case WorkoutSectionType.warmUp:
        return 'General warm-up, dynamic movement, activation, & movement preparation';
      case WorkoutSectionType.mainWorkout:
        return 'Strength, hypertrophy, power, functional training, conditioning, & boxing';
      case WorkoutSectionType.mobility:
        return 'Dynamic mobility, activation, & joint preparation';
      case WorkoutSectionType.coolDown:
        return 'Static stretching, breathing, & central nervous system recovery';
      case WorkoutSectionType.custom:
        return 'Custom accessory or conditioning circuit';
    }
  }

  static WorkoutSectionType fromString(String? type) {
    if (type == null) return WorkoutSectionType.mainWorkout;
    final lower = type.toLowerCase().replaceAll('-', '').replaceAll(' ', '').replaceAll('_', '');
    if (lower.contains('warm')) return WorkoutSectionType.warmUp;
    if (lower.contains('mob')) return WorkoutSectionType.mobility;
    if (lower.contains('cool')) return WorkoutSectionType.coolDown;
    if (lower.contains('custom')) return WorkoutSectionType.custom;
    return WorkoutSectionType.mainWorkout;
  }
}

class WorkoutSection {
  final String id;
  final String title;
  final WorkoutSectionType sectionType;
  final int orderIndex;
  final String? notes;
  final String? trainerInstructions;

  const WorkoutSection({
    required this.id,
    required this.title,
    this.sectionType = WorkoutSectionType.mainWorkout,
    this.orderIndex = 0,
    this.notes,
    this.trainerInstructions,
  });

  WorkoutSection copyWith({
    String? id,
    String? title,
    WorkoutSectionType? sectionType,
    int? orderIndex,
    String? notes,
    String? trainerInstructions,
  }) {
    return WorkoutSection(
      id: id ?? this.id,
      title: title ?? this.title,
      sectionType: sectionType ?? this.sectionType,
      orderIndex: orderIndex ?? this.orderIndex,
      notes: notes ?? this.notes,
      trainerInstructions: trainerInstructions ?? this.trainerInstructions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'sectionType': sectionType.name,
      'orderIndex': orderIndex,
      'notes': notes,
      'trainerInstructions': trainerInstructions,
    };
  }

  factory WorkoutSection.fromJson(Map<String, dynamic> json) {
    return WorkoutSection(
      id: json['id'] as String,
      title: json['title'] as String,
      sectionType: WorkoutSectionTypeExtension.fromString(json['sectionType'] as String?),
      orderIndex: json['orderIndex'] as int? ?? 0,
      notes: json['notes'] as String?,
      trainerInstructions: json['trainerInstructions'] as String?,
    );
  }
}

class WorkoutPlanVersion {
  final String versionId;
  final int versionNumber;
  final DateTime createdAt;
  final String? notes;

  const WorkoutPlanVersion({
    required this.versionId,
    this.versionNumber = 1,
    required this.createdAt,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'versionId': versionId,
      'versionNumber': versionNumber,
      'createdAt': createdAt.toIso8601String(),
      'notes': notes,
    };
  }

  factory WorkoutPlanVersion.fromJson(Map<String, dynamic> json) {
    return WorkoutPlanVersion(
      versionId: json['versionId'] as String? ?? 'v1',
      versionNumber: json['versionNumber'] as int? ?? 1,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      notes: json['notes'] as String?,
    );
  }
}

class ExerciseSwapRecord {
  final String id;
  final String originalExerciseId;
  final String originalExerciseName;
  final String performedExerciseId;
  final String performedExerciseName;
  final DateTime swappedAt;
  final String? reason;

  const ExerciseSwapRecord({
    required this.id,
    required this.originalExerciseId,
    required this.originalExerciseName,
    required this.performedExerciseId,
    required this.performedExerciseName,
    required this.swappedAt,
    this.reason,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'originalExerciseId': originalExerciseId,
      'originalExerciseName': originalExerciseName,
      'performedExerciseId': performedExerciseId,
      'performedExerciseName': performedExerciseName,
      'swappedAt': swappedAt.toIso8601String(),
      'reason': reason,
    };
  }

  factory ExerciseSwapRecord.fromJson(Map<String, dynamic> json) {
    return ExerciseSwapRecord(
      id: json['id'] as String,
      originalExerciseId: json['originalExerciseId'] as String,
      originalExerciseName: json['originalExerciseName'] as String,
      performedExerciseId: json['performedExerciseId'] as String,
      performedExerciseName: json['performedExerciseName'] as String,
      swappedAt: json['swappedAt'] != null
          ? DateTime.tryParse(json['swappedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      reason: json['reason'] as String?,
    );
  }
}

class ExerciseChangeRequest {
  final String id;
  final String clientId;
  final String clientName;
  final String sessionId;
  final String sessionTitle;
  final String exerciseId;
  final String exerciseName;
  final String reason;
  final DateTime requestedAt;
  final String status; // 'PENDING', 'APPROVED', 'REJECTED'
  final String? adminNote;
  final String? replacementExerciseId;
  final String? replacementExerciseName;
  final bool isPermanent;

  const ExerciseChangeRequest({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.sessionId,
    required this.sessionTitle,
    required this.exerciseId,
    required this.exerciseName,
    required this.reason,
    required this.requestedAt,
    this.status = 'PENDING',
    this.adminNote,
    this.replacementExerciseId,
    this.replacementExerciseName,
    this.isPermanent = false,
  });

  bool get isPending => status == 'PENDING';
  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';

  ExerciseChangeRequest copyWith({
    String? id,
    String? clientId,
    String? clientName,
    String? sessionId,
    String? sessionTitle,
    String? exerciseId,
    String? exerciseName,
    String? reason,
    DateTime? requestedAt,
    String? status,
    String? adminNote,
    String? replacementExerciseId,
    String? replacementExerciseName,
    bool? isPermanent,
  }) {
    return ExerciseChangeRequest(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      sessionId: sessionId ?? this.sessionId,
      sessionTitle: sessionTitle ?? this.sessionTitle,
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseName: exerciseName ?? this.exerciseName,
      reason: reason ?? this.reason,
      requestedAt: requestedAt ?? this.requestedAt,
      status: status ?? this.status,
      adminNote: adminNote ?? this.adminNote,
      replacementExerciseId: replacementExerciseId ?? this.replacementExerciseId,
      replacementExerciseName: replacementExerciseName ?? this.replacementExerciseName,
      isPermanent: isPermanent ?? this.isPermanent,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clientId': clientId,
      'clientName': clientName,
      'sessionId': sessionId,
      'sessionTitle': sessionTitle,
      'exerciseId': exerciseId,
      'exerciseName': exerciseName,
      'reason': reason,
      'requestedAt': requestedAt.toIso8601String(),
      'status': status,
      'adminNote': adminNote,
      'replacementExerciseId': replacementExerciseId,
      'replacementExerciseName': replacementExerciseName,
      'isPermanent': isPermanent,
    };
  }

  factory ExerciseChangeRequest.fromJson(Map<String, dynamic> json) {
    return ExerciseChangeRequest(
      id: json['id'] as String,
      clientId: json['clientId'] as String,
      clientName: json['clientName'] as String? ?? 'Client',
      sessionId: json['sessionId'] as String,
      sessionTitle: json['sessionTitle'] as String,
      exerciseId: json['exerciseId'] as String,
      exerciseName: json['exerciseName'] as String,
      reason: json['reason'] as String,
      requestedAt: json['requestedAt'] != null
          ? DateTime.tryParse(json['requestedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      status: json['status'] as String? ?? 'PENDING',
      adminNote: json['adminNote'] as String?,
      replacementExerciseId: json['replacementExerciseId'] as String?,
      replacementExerciseName: json['replacementExerciseName'] as String?,
      isPermanent: json['isPermanent'] as bool? ?? false,
    );
  }
}

class ClientWorkoutPermissions {
  final bool allowExerciseSwap;
  final bool allowAddExercise;
  final bool allowRemoveExercise;
  final bool allowChangingSets;
  final bool allowChangingTargetReps;
  final bool allowChangingRest;
  final bool allowChangingExerciseOrder;

  const ClientWorkoutPermissions({
    this.allowExerciseSwap = true,
    this.allowAddExercise = false,
    this.allowRemoveExercise = false,
    this.allowChangingSets = true,
    this.allowChangingTargetReps = false,
    this.allowChangingRest = true,
    this.allowChangingExerciseOrder = false,
  });

  ClientWorkoutPermissions copyWith({
    bool? allowExerciseSwap,
    bool? allowAddExercise,
    bool? allowRemoveExercise,
    bool? allowChangingSets,
    bool? allowChangingTargetReps,
    bool? allowChangingRest,
    bool? allowChangingExerciseOrder,
  }) {
    return ClientWorkoutPermissions(
      allowExerciseSwap: allowExerciseSwap ?? this.allowExerciseSwap,
      allowAddExercise: allowAddExercise ?? this.allowAddExercise,
      allowRemoveExercise: allowRemoveExercise ?? this.allowRemoveExercise,
      allowChangingSets: allowChangingSets ?? this.allowChangingSets,
      allowChangingTargetReps: allowChangingTargetReps ?? this.allowChangingTargetReps,
      allowChangingRest: allowChangingRest ?? this.allowChangingRest,
      allowChangingExerciseOrder: allowChangingExerciseOrder ?? this.allowChangingExerciseOrder,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'allowExerciseSwap': allowExerciseSwap,
      'allowAddExercise': allowAddExercise,
      'allowRemoveExercise': allowRemoveExercise,
      'allowChangingSets': allowChangingSets,
      'allowChangingTargetReps': allowChangingTargetReps,
      'allowChangingRest': allowChangingRest,
      'allowChangingExerciseOrder': allowChangingExerciseOrder,
    };
  }

  factory ClientWorkoutPermissions.fromJson(Map<String, dynamic> json) {
    return ClientWorkoutPermissions(
      allowExerciseSwap: json['allowExerciseSwap'] as bool? ?? true,
      allowAddExercise: json['allowAddExercise'] as bool? ?? false,
      allowRemoveExercise: json['allowRemoveExercise'] as bool? ?? false,
      allowChangingSets: json['allowChangingSets'] as bool? ?? true,
      allowChangingTargetReps: json['allowChangingTargetReps'] as bool? ?? false,
      allowChangingRest: json['allowChangingRest'] as bool? ?? true,
      allowChangingExerciseOrder: json['allowChangingExerciseOrder'] as bool? ?? false,
    );
  }
}

class WeeklyWorkoutSchedule {
  final Map<int, String?> dayOfWeekSessionId; // 1 = Monday, 7 = Sunday
  final DateTime? startDate;
  final DateTime? endDate;

  const WeeklyWorkoutSchedule({
    this.dayOfWeekSessionId = const {},
    this.startDate,
    this.endDate,
  });

  WeeklyWorkoutSchedule copyWith({
    Map<int, String?>? dayOfWeekSessionId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return WeeklyWorkoutSchedule(
      dayOfWeekSessionId: dayOfWeekSessionId ?? this.dayOfWeekSessionId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dayOfWeekSessionId': dayOfWeekSessionId.map((k, v) => MapEntry(k.toString(), v)),
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
    };
  }

  factory WeeklyWorkoutSchedule.fromJson(Map<String, dynamic> json) {
    final map = <int, String?>{};
    if (json['dayOfWeekSessionId'] is Map) {
      (json['dayOfWeekSessionId'] as Map).forEach((k, v) {
        final day = int.tryParse(k.toString());
        if (day != null) map[day] = v as String?;
      });
    }
    return WeeklyWorkoutSchedule(
      dayOfWeekSessionId: map,
      startDate: json['startDate'] != null ? DateTime.tryParse(json['startDate'] as String) : null,
      endDate: json['endDate'] != null ? DateTime.tryParse(json['endDate'] as String) : null,
    );
  }
}

class ExerciseSet {
  final String id;
  final int setNumber;
  final SetType setType;

  // Previous Performance
  final double? previousWeight;
  final int? previousReps;
  final double? previousRpe;
  final int? previousRir;

  // Target prescribed by Admin / Trainer
  final double targetWeight;
  final double? targetWeightMax;
  final int targetRepsMin;
  final int targetRepsMax;
  final double? targetRpe;
  final int? targetRir;
  final String tempo; // e.g. "3-1-1-0"
  final int? durationSeconds; // for timed sets / isometric holds / EMOM
  final double? distanceMeters; // for carries / sled / runs
  final int? restSeconds;

  // Actual achieved by Client
  final double? actualWeight;
  final int? actualReps;
  final double? actualRpe;
  final int? actualRir;
  final bool isCompleted;
  final DateTime? completedAt;
  final String? notes;

  const ExerciseSet({
    required this.id,
    required this.setNumber,
    this.setType = SetType.working,
    this.previousWeight,
    this.previousReps,
    this.previousRpe,
    this.previousRir,
    required this.targetWeight,
    this.targetWeightMax,
    required this.targetRepsMin,
    required this.targetRepsMax,
    this.targetRpe = 8.0,
    this.targetRir = 2,
    this.tempo = '3-1-1-0',
    this.durationSeconds,
    this.distanceMeters,
    this.restSeconds,
    this.actualWeight,
    this.actualReps,
    this.actualRpe,
    this.actualRir,
    this.isCompleted = false,
    this.completedAt,
    this.notes,
  });

  String get targetRepsDisplay {
    if (durationSeconds != null && durationSeconds! > 0) {
      return '$durationSeconds s';
    }
    if (distanceMeters != null && distanceMeters! > 0) {
      final d = distanceMeters! % 1 == 0 ? distanceMeters!.toInt().toString() : distanceMeters!.toStringAsFixed(1);
      return '$d m';
    }
    if (targetRepsMin == targetRepsMax) {
      return '$targetRepsMin';
    }
    return '$targetRepsMin–$targetRepsMax';
  }

  String get previousDisplay {
    if (previousWeight == null || previousReps == null) {
      return '—';
    }
    final formattedWeight = previousWeight! % 1 == 0
        ? previousWeight!.toInt().toString()
        : previousWeight!.toStringAsFixed(1);
    return '$formattedWeight kg × $previousReps';
  }

  String get actualDisplay {
    if (actualWeight == null || actualReps == null) {
      return '—';
    }
    final formattedWeight = actualWeight! % 1 == 0
        ? actualWeight!.toInt().toString()
        : actualWeight!.toStringAsFixed(1);
    return '$formattedWeight kg × $actualReps';
  }

  double get volume {
    if (!isCompleted || actualWeight == null || actualReps == null) return 0.0;
    return actualWeight! * actualReps!;
  }

  double get estimatedOneRepMax {
    if (actualWeight == null || actualReps == null || actualReps == 0) return 0.0;
    // Epley Formula: 1RM = weight * (1 + reps / 30)
    return actualWeight! * (1 + (actualReps! / 30.0));
  }

  ExerciseSet copyWith({
    String? id,
    int? setNumber,
    SetType? setType,
    double? previousWeight,
    int? previousReps,
    double? previousRpe,
    int? previousRir,
    double? targetWeight,
    double? targetWeightMax,
    int? targetRepsMin,
    int? targetRepsMax,
    double? targetRpe,
    int? targetRir,
    String? tempo,
    int? durationSeconds,
    double? distanceMeters,
    int? restSeconds,
    double? actualWeight,
    int? actualReps,
    double? actualRpe,
    int? actualRir,
    bool? isCompleted,
    DateTime? completedAt,
    String? notes,
  }) {
    return ExerciseSet(
      id: id ?? this.id,
      setNumber: setNumber ?? this.setNumber,
      setType: setType ?? this.setType,
      previousWeight: previousWeight ?? this.previousWeight,
      previousReps: previousReps ?? this.previousReps,
      previousRpe: previousRpe ?? this.previousRpe,
      previousRir: previousRir ?? this.previousRir,
      targetWeight: targetWeight ?? this.targetWeight,
      targetWeightMax: targetWeightMax ?? this.targetWeightMax,
      targetRepsMin: targetRepsMin ?? this.targetRepsMin,
      targetRepsMax: targetRepsMax ?? this.targetRepsMax,
      targetRpe: targetRpe ?? this.targetRpe,
      targetRir: targetRir ?? this.targetRir,
      tempo: tempo ?? this.tempo,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      restSeconds: restSeconds ?? this.restSeconds,
      actualWeight: actualWeight ?? this.actualWeight,
      actualReps: actualReps ?? this.actualReps,
      actualRpe: actualRpe ?? this.actualRpe,
      actualRir: actualRir ?? this.actualRir,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'setNumber': setNumber,
      'setType': setType.name,
      'previousWeight': previousWeight,
      'previousReps': previousReps,
      'previousRpe': previousRpe,
      'previousRir': previousRir,
      'targetWeight': targetWeight,
      'targetWeightMax': targetWeightMax,
      'targetRepsMin': targetRepsMin,
      'targetRepsMax': targetRepsMax,
      'targetRpe': targetRpe,
      'targetRir': targetRir,
      'tempo': tempo,
      'durationSeconds': durationSeconds,
      'distanceMeters': distanceMeters,
      'restSeconds': restSeconds,
      'actualWeight': actualWeight,
      'actualReps': actualReps,
      'actualRpe': actualRpe,
      'actualRir': actualRir,
      'isCompleted': isCompleted,
      'completedAt': completedAt?.toIso8601String(),
      'notes': notes,
    };
  }

  factory ExerciseSet.fromJson(Map<String, dynamic> json) {
    return ExerciseSet(
      id: json['id'] as String,
      setNumber: json['setNumber'] as int,
      setType: SetTypeExtension.fromString(json['setType'] as String?),
      previousWeight: (json['previousWeight'] as num?)?.toDouble(),
      previousReps: json['previousReps'] as int?,
      previousRpe: (json['previousRpe'] as num?)?.toDouble(),
      previousRir: json['previousRir'] as int?,
      targetWeight: (json['targetWeight'] as num?)?.toDouble() ?? 0.0,
      targetWeightMax: (json['targetWeightMax'] as num?)?.toDouble(),
      targetRepsMin: json['targetRepsMin'] as int? ?? 8,
      targetRepsMax: json['targetRepsMax'] as int? ?? 12,
      targetRpe: (json['targetRpe'] as num?)?.toDouble() ?? 8.0,
      targetRir: json['targetRir'] as int? ?? 2,
      tempo: json['tempo'] as String? ?? '3-1-1-0',
      durationSeconds: json['durationSeconds'] as int?,
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
      restSeconds: json['restSeconds'] as int?,
      actualWeight: (json['actualWeight'] as num?)?.toDouble(),
      actualReps: json['actualReps'] as int?,
      actualRpe: (json['actualRpe'] as num?)?.toDouble(),
      actualRir: json['actualRir'] as int?,
      isCompleted: json['isCompleted'] as bool? ?? false,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
      notes: json['notes'] as String?,
    );
  }
}

class WorkoutExercise {
  final String id;
  final String exerciseId;
  final String exerciseName;
  final String category;
  final String primaryMusclesDisplay;
  final String secondaryMusclesDisplay;
  final String? supersetTag; // e.g. "A1", "A2", "B1"
  final String? sectionId; // References WorkoutSection.id
  final WorkoutSectionType sectionType;
  final AdvancedTrainingMethod trainingMethod;
  final int restSeconds;
  final String trainerNote;
  final String tempo;
  final List<String> approvedAlternativeIds;
  final List<ExerciseSet> sets;
  final bool isSkipped;
  final String? skipReason;
  final String? clientNote;
  final bool isUnavailable;
  final ExerciseSwapRecord? swapRecord;
  final int? durationSeconds;
  final double? distanceMeters;

  const WorkoutExercise({
    required this.id,
    required this.exerciseId,
    required this.exerciseName,
    required this.category,
    required this.primaryMusclesDisplay,
    required this.secondaryMusclesDisplay,
    this.supersetTag,
    this.sectionId,
    this.sectionType = WorkoutSectionType.mainWorkout,
    this.trainingMethod = AdvancedTrainingMethod.straightSets,
    this.restSeconds = 90,
    required this.trainerNote,
    this.tempo = '3-1-1-0',
    this.approvedAlternativeIds = const [],
    required this.sets,
    this.isSkipped = false,
    this.skipReason,
    this.clientNote,
    this.isUnavailable = false,
    this.swapRecord,
    this.durationSeconds,
    this.distanceMeters,
  });

  bool get isAllSetsCompleted => sets.isNotEmpty && sets.every((s) => s.isCompleted);

  int get completedSetsCount => sets.where((s) => s.isCompleted).length;

  double get totalExerciseVolume => sets.fold(0.0, (acc, s) => acc + s.volume);

  bool get isSuperset => supersetTag != null && supersetTag!.trim().isNotEmpty;

  String? get supersetGroupName {
    if (!isSuperset) return null;
    final tag = supersetTag!.trim();
    if (tag.isNotEmpty) {
      return 'SUPERSET ${tag[0].toUpperCase()}';
    }
    return 'SUPERSET';
  }

  WorkoutExercise copyWith({
    String? id,
    String? exerciseId,
    String? exerciseName,
    String? category,
    String? primaryMusclesDisplay,
    String? secondaryMusclesDisplay,
    String? supersetTag,
    String? sectionId,
    WorkoutSectionType? sectionType,
    AdvancedTrainingMethod? trainingMethod,
    int? restSeconds,
    String? trainerNote,
    String? tempo,
    List<String>? approvedAlternativeIds,
    List<ExerciseSet>? sets,
    bool? isSkipped,
    String? skipReason,
    String? clientNote,
    bool? isUnavailable,
    ExerciseSwapRecord? swapRecord,
    int? durationSeconds,
    double? distanceMeters,
  }) {
    return WorkoutExercise(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseName: exerciseName ?? this.exerciseName,
      category: category ?? this.category,
      primaryMusclesDisplay: primaryMusclesDisplay ?? this.primaryMusclesDisplay,
      secondaryMusclesDisplay: secondaryMusclesDisplay ?? this.secondaryMusclesDisplay,
      supersetTag: supersetTag ?? this.supersetTag,
      sectionId: sectionId ?? this.sectionId,
      sectionType: sectionType ?? this.sectionType,
      trainingMethod: trainingMethod ?? this.trainingMethod,
      restSeconds: restSeconds ?? this.restSeconds,
      trainerNote: trainerNote ?? this.trainerNote,
      tempo: tempo ?? this.tempo,
      approvedAlternativeIds: approvedAlternativeIds ?? this.approvedAlternativeIds,
      sets: sets ?? this.sets,
      isSkipped: isSkipped ?? this.isSkipped,
      skipReason: skipReason ?? this.skipReason,
      clientNote: clientNote ?? this.clientNote,
      isUnavailable: isUnavailable ?? this.isUnavailable,
      swapRecord: swapRecord ?? this.swapRecord,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      distanceMeters: distanceMeters ?? this.distanceMeters,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exerciseId': exerciseId,
      'exerciseName': exerciseName,
      'category': category,
      'primaryMusclesDisplay': primaryMusclesDisplay,
      'secondaryMusclesDisplay': secondaryMusclesDisplay,
      'supersetTag': supersetTag,
      'sectionId': sectionId,
      'sectionType': sectionType.name,
      'trainingMethod': trainingMethod.name,
      'restSeconds': restSeconds,
      'trainerNote': trainerNote,
      'tempo': tempo,
      'approvedAlternativeIds': approvedAlternativeIds,
      'sets': sets.map((s) => s.toJson()).toList(),
      'isSkipped': isSkipped,
      'skipReason': skipReason,
      'clientNote': clientNote,
      'isUnavailable': isUnavailable,
      'swapRecord': swapRecord?.toJson(),
      'durationSeconds': durationSeconds,
      'distanceMeters': distanceMeters,
    };
  }

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) {
    return WorkoutExercise(
      id: json['id'] as String,
      exerciseId: json['exerciseId'] as String,
      exerciseName: json['exerciseName'] as String,
      category: json['category'] as String? ?? 'General',
      primaryMusclesDisplay: json['primaryMusclesDisplay'] as String? ?? '',
      secondaryMusclesDisplay: json['secondaryMusclesDisplay'] as String? ?? '',
      supersetTag: json['supersetTag'] as String?,
      sectionId: json['sectionId'] as String?,
      sectionType: WorkoutSectionTypeExtension.fromString(json['sectionType'] as String?),
      trainingMethod: AdvancedTrainingMethodExtension.fromString(json['trainingMethod'] as String?),
      restSeconds: json['restSeconds'] as int? ?? 90,
      trainerNote: json['trainerNote'] as String? ?? '',
      tempo: json['tempo'] as String? ?? '3-1-1-0',
      approvedAlternativeIds: (json['approvedAlternativeIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      sets: (json['sets'] as List<dynamic>?)
              ?.map((s) => ExerciseSet.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      isSkipped: json['isSkipped'] as bool? ?? false,
      skipReason: json['skipReason'] as String?,
      clientNote: json['clientNote'] as String?,
      isUnavailable: json['isUnavailable'] as bool? ?? false,
      swapRecord: json['swapRecord'] != null
          ? ExerciseSwapRecord.fromJson(json['swapRecord'] as Map<String, dynamic>)
          : null,
      durationSeconds: json['durationSeconds'] as int?,
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
    );
  }
}

class WorkoutSession {
  final String id;
  final String title;
  final String workoutType; // Strength, Hypertrophy, Full Body, Conditioning, HIIT, Cardio, Mobility, Boxing
  final String targetMuscleGroup;
  final String difficulty; // Beginner, Intermediate, Advanced
  final int estimatedDurationMinutes;
  final String? description;
  final bool isActive;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? recurringSchedule;
  final String availabilityType; // ALL, SELECTED, INDIVIDUAL
  final List<String> assignedClientIds;
  final bool isRecommended;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int durationSeconds;
  final List<WorkoutExercise> exercises;
  final List<WorkoutSection> sections;
  final WorkoutPlanVersion planVersion;
  final List<int> trainingDays; // 1 = Mon ... 7 = Sun
  final WeeklyWorkoutSchedule? weeklySchedule;
  final ClientWorkoutPermissions permissions;
  final bool isCompleted;

  WorkoutSession({
    required this.id,
    required this.title,
    this.workoutType = 'Strength',
    String? targetMuscleGroup,
    String? focus,
    this.difficulty = 'Intermediate',
    this.estimatedDurationMinutes = 45,
    this.description,
    this.isActive = true,
    this.startDate,
    this.endDate,
    this.recurringSchedule,
    this.availabilityType = 'ALL',
    this.assignedClientIds = const [],
    this.isRecommended = false,
    DateTime? startedAt,
    this.completedAt,
    this.durationSeconds = 0,
    required this.exercises,
    List<WorkoutSection>? sections,
    WorkoutPlanVersion? planVersion,
    this.trainingDays = const [1, 3, 5],
    this.weeklySchedule,
    this.permissions = const ClientWorkoutPermissions(),
    this.isCompleted = false,
  })  : targetMuscleGroup = targetMuscleGroup ?? focus ?? 'Full Body',
        startedAt = startedAt ?? DateTime.now(),
        sections = sections ?? _defaultSections(),
        planVersion = planVersion ?? WorkoutPlanVersion(versionId: 'v1_$id', createdAt: DateTime.now());

  static List<WorkoutSection> _defaultSections() {
    return [
      const WorkoutSection(
        id: 'sec_warmup',
        title: 'Warm-up & Activation',
        sectionType: WorkoutSectionType.warmUp,
        orderIndex: 0,
      ),
      const WorkoutSection(
        id: 'sec_main',
        title: 'Main Workout',
        sectionType: WorkoutSectionType.mainWorkout,
        orderIndex: 1,
      ),
      const WorkoutSection(
        id: 'sec_mobility',
        title: 'Mobility & Accessory',
        sectionType: WorkoutSectionType.mobility,
        orderIndex: 2,
      ),
      const WorkoutSection(
        id: 'sec_cooldown',
        title: 'Cool-down & Recovery',
        sectionType: WorkoutSectionType.coolDown,
        orderIndex: 3,
      ),
    ];
  }

  String get focus => targetMuscleGroup;

  double get totalVolume => exercises.fold(0.0, (acc, ex) => acc + ex.totalExerciseVolume);

  int get totalCompletedSets => exercises.fold(0, (acc, ex) => acc + ex.completedSetsCount);

  int get totalSets => exercises.fold(0, (acc, ex) => acc + ex.sets.length);

  int get exerciseCount => exercises.length;

  List<WorkoutExercise> get warmUpExercises =>
      exercises.where((e) => e.sectionType == WorkoutSectionType.warmUp).toList();

  List<WorkoutExercise> get mainExercises =>
      exercises.where((e) => e.sectionType == WorkoutSectionType.mainWorkout).toList();

  List<WorkoutExercise> get mobilityExercises =>
      exercises.where((e) => e.sectionType == WorkoutSectionType.mobility).toList();

  List<WorkoutExercise> get coolDownExercises =>
      exercises.where((e) => e.sectionType == WorkoutSectionType.coolDown).toList();

  WorkoutSession copyWith({
    String? id,
    String? title,
    String? workoutType,
    String? targetMuscleGroup,
    String? focus,
    String? difficulty,
    int? estimatedDurationMinutes,
    String? description,
    bool? isActive,
    DateTime? startDate,
    DateTime? endDate,
    String? recurringSchedule,
    String? availabilityType,
    List<String>? assignedClientIds,
    bool? isRecommended,
    DateTime? startedAt,
    DateTime? completedAt,
    int? durationSeconds,
    List<WorkoutExercise>? exercises,
    List<WorkoutSection>? sections,
    WorkoutPlanVersion? planVersion,
    List<int>? trainingDays,
    WeeklyWorkoutSchedule? weeklySchedule,
    ClientWorkoutPermissions? permissions,
    bool? isCompleted,
  }) {
    return WorkoutSession(
      id: id ?? this.id,
      title: title ?? this.title,
      workoutType: workoutType ?? this.workoutType,
      targetMuscleGroup: targetMuscleGroup ?? focus ?? this.targetMuscleGroup,
      difficulty: difficulty ?? this.difficulty,
      estimatedDurationMinutes: estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      recurringSchedule: recurringSchedule ?? this.recurringSchedule,
      availabilityType: availabilityType ?? this.availabilityType,
      assignedClientIds: assignedClientIds ?? this.assignedClientIds,
      isRecommended: isRecommended ?? this.isRecommended,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      exercises: exercises ?? this.exercises,
      sections: sections ?? this.sections,
      planVersion: planVersion ?? this.planVersion,
      trainingDays: trainingDays ?? this.trainingDays,
      weeklySchedule: weeklySchedule ?? this.weeklySchedule,
      permissions: permissions ?? this.permissions,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'workoutType': workoutType,
      'targetMuscleGroup': targetMuscleGroup,
      'difficulty': difficulty,
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'description': description,
      'isActive': isActive,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'recurringSchedule': recurringSchedule,
      'availabilityType': availabilityType,
      'assignedClientIds': assignedClientIds,
      'isRecommended': isRecommended,
      'startedAt': startedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'durationSeconds': durationSeconds,
      'exercises': exercises.map((e) => e.toJson()).toList(),
      'sections': sections.map((s) => s.toJson()).toList(),
      'planVersion': planVersion.toJson(),
      'trainingDays': trainingDays,
      'weeklySchedule': weeklySchedule?.toJson(),
      'permissions': permissions.toJson(),
      'isCompleted': isCompleted,
    };
  }

  factory WorkoutSession.fromJson(Map<String, dynamic> json) {
    return WorkoutSession(
      id: json['id'] as String,
      title: json['title'] as String,
      workoutType: json['workoutType'] as String? ?? 'Strength',
      targetMuscleGroup: json['targetMuscleGroup'] as String? ?? 'Full Body',
      difficulty: json['difficulty'] as String? ?? 'Intermediate',
      estimatedDurationMinutes: json['estimatedDurationMinutes'] as int? ?? 45,
      description: json['description'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      startDate: json['startDate'] != null ? DateTime.tryParse(json['startDate'] as String) : null,
      endDate: json['endDate'] != null ? DateTime.tryParse(json['endDate'] as String) : null,
      recurringSchedule: json['recurringSchedule'] as String?,
      availabilityType: json['availabilityType'] as String? ?? 'ALL',
      assignedClientIds: (json['assignedClientIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      isRecommended: json['isRecommended'] as bool? ?? false,
      startedAt: json['startedAt'] != null
          ? DateTime.tryParse(json['startedAt'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
      durationSeconds: json['durationSeconds'] as int? ?? 0,
      exercises: (json['exercises'] as List<dynamic>?)
              ?.map((e) => WorkoutExercise.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      sections: (json['sections'] as List<dynamic>?)
              ?.map((s) => WorkoutSection.fromJson(s as Map<String, dynamic>))
              .toList(),
      planVersion: json['planVersion'] != null
          ? WorkoutPlanVersion.fromJson(json['planVersion'] as Map<String, dynamic>)
          : null,
      trainingDays: (json['trainingDays'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          const [1, 3, 5],
      weeklySchedule: json['weeklySchedule'] != null
          ? WeeklyWorkoutSchedule.fromJson(json['weeklySchedule'] as Map<String, dynamic>)
          : null,
      permissions: json['permissions'] != null
          ? ClientWorkoutPermissions.fromJson(json['permissions'] as Map<String, dynamic>)
          : const ClientWorkoutPermissions(),
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }
}

/// Historical record of a completed workout execution
class WorkoutRecord {
  final String id;
  final String clientId;
  final String? sessionId;
  final String sessionTitle;
  final String workoutType;
  final String targetMuscleGroup;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int durationSeconds;
  final double totalVolume;
  final int completedSetsCount;
  final int skippedSetsCount;
  final double? averageRpe;
  final double? averageRir;
  final bool isCompleted;
  final List<PersonalRecord> personalRecords;
  final String? notes;
  final List<WorkoutExercise> exercises;
  final List<ExerciseSwapRecord> exerciseSwaps;
  final WorkoutPlanVersion? planVersion;

  const WorkoutRecord({
    required this.id,
    required this.clientId,
    this.sessionId,
    required this.sessionTitle,
    required this.workoutType,
    required this.targetMuscleGroup,
    required this.startedAt,
    this.completedAt,
    this.durationSeconds = 0,
    this.totalVolume = 0.0,
    this.completedSetsCount = 0,
    this.skippedSetsCount = 0,
    this.averageRpe,
    this.averageRir,
    this.isCompleted = true,
    this.personalRecords = const [],
    this.notes,
    required this.exercises,
    this.exerciseSwaps = const [],
    this.planVersion,
  });

  String get durationDisplay {
    final minutes = (durationSeconds / 60).floor();
    final seconds = durationSeconds % 60;
    if (minutes > 0) {
      return '$minutes min${seconds > 0 ? " $seconds s" : ""}';
    }
    return '$seconds sec';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clientId': clientId,
      'sessionId': sessionId,
      'sessionTitle': sessionTitle,
      'workoutType': workoutType,
      'targetMuscleGroup': targetMuscleGroup,
      'startedAt': startedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'durationSeconds': durationSeconds,
      'totalVolume': totalVolume,
      'completedSetsCount': completedSetsCount,
      'skippedSetsCount': skippedSetsCount,
      'averageRpe': averageRpe,
      'averageRir': averageRir,
      'isCompleted': isCompleted,
      'personalRecords': personalRecords.map((p) => p.toJson()).toList(),
      'notes': notes,
      'exercises': exercises.map((e) => e.toJson()).toList(),
      'exerciseSwaps': exerciseSwaps.map((s) => s.toJson()).toList(),
      'planVersion': planVersion?.toJson(),
    };
  }

  factory WorkoutRecord.fromJson(Map<String, dynamic> json) {
    return WorkoutRecord(
      id: json['id'] as String,
      clientId: json['clientId'] as String,
      sessionId: json['sessionId'] as String?,
      sessionTitle: json['sessionTitle'] as String,
      workoutType: json['workoutType'] as String? ?? 'Strength',
      targetMuscleGroup: json['targetMuscleGroup'] as String? ?? 'Full Body',
      startedAt: DateTime.tryParse(json['startedAt'] as String) ?? DateTime.now(),
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
      durationSeconds: json['durationSeconds'] as int? ?? 0,
      totalVolume: (json['totalVolume'] as num?)?.toDouble() ?? 0.0,
      completedSetsCount: json['completedSetsCount'] as int? ?? 0,
      skippedSetsCount: json['skippedSetsCount'] as int? ?? 0,
      averageRpe: (json['averageRpe'] as num?)?.toDouble(),
      averageRir: (json['averageRir'] as num?)?.toDouble(),
      isCompleted: json['isCompleted'] as bool? ?? true,
      personalRecords: (json['personalRecords'] as List<dynamic>?)
              ?.map((p) => PersonalRecord.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      notes: json['notes'] as String?,
      exercises: (json['exercises'] as List<dynamic>?)
              ?.map((e) => WorkoutExercise.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      exerciseSwaps: (json['exerciseSwaps'] as List<dynamic>?)
              ?.map((s) => ExerciseSwapRecord.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      planVersion: json['planVersion'] != null
          ? WorkoutPlanVersion.fromJson(json['planVersion'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Historical exercise performance record for a specific session
class ExercisePerformanceHistoryItem {
  final String recordId;
  final String sessionTitle;
  final DateTime date;
  final List<ExerciseSet> sets;

  const ExercisePerformanceHistoryItem({
    required this.recordId,
    required this.sessionTitle,
    required this.date,
    required this.sets,
  });
}

/// Personal Record types detected during workout execution
enum PRType {
  weight,
  reps,
  volume,
  estimated1RM,
}

extension PRTypeExtension on PRType {
  String get displayName {
    switch (this) {
      case PRType.weight:
        return 'Weight PR';
      case PRType.reps:
        return 'Rep PR';
      case PRType.volume:
        return 'Volume PR';
      case PRType.estimated1RM:
        return 'Estimated 1RM PR';
    }
  }

  String get badgeLabel {
    switch (this) {
      case PRType.weight:
        return 'HEAVIEST WEIGHT';
      case PRType.reps:
        return 'MOST REPS';
      case PRType.volume:
        return 'MAX SET VOLUME';
      case PRType.estimated1RM:
        return 'ESTIMATED 1RM';
    }
  }
}

/// Personal Record achieved during workout execution
class PersonalRecord {
  final String id;
  final String exerciseId;
  final String exerciseName;
  final PRType type;
  final double value;
  final double weight;
  final int reps;
  final double? previousValue;
  final DateTime achievedAt;

  const PersonalRecord({
    required this.id,
    required this.exerciseId,
    required this.exerciseName,
    required this.type,
    required this.value,
    required this.weight,
    required this.reps,
    this.previousValue,
    required this.achievedAt,
  });

  String get formattedValue {
    final weightStr = weight % 1 == 0 ? weight.toInt().toString() : weight.toStringAsFixed(1);
    switch (type) {
      case PRType.weight:
        return '$weightStr kg';
      case PRType.reps:
        return '$reps reps @ $weightStr kg';
      case PRType.volume:
        return '${value.toInt()} kg';
      case PRType.estimated1RM:
        return '${value.toStringAsFixed(1)} kg 1RM';
    }
  }

  String get formattedPrevious {
    if (previousValue == null) return 'Baseline';
    final prevStr = previousValue! % 1 == 0
        ? previousValue!.toInt().toString()
        : previousValue!.toStringAsFixed(1);
    switch (type) {
      case PRType.weight:
        return '$prevStr kg';
      case PRType.reps:
        return '$prevStr reps';
      case PRType.volume:
        return '${previousValue!.toInt()} kg';
      case PRType.estimated1RM:
        return '$prevStr kg 1RM';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exerciseId': exerciseId,
      'exerciseName': exerciseName,
      'type': type.name,
      'value': value,
      'weight': weight,
      'reps': reps,
      'previousValue': previousValue,
      'achievedAt': achievedAt.toIso8601String(),
    };
  }

  factory PersonalRecord.fromJson(Map<String, dynamic> json) {
    PRType parsedType;
    try {
      parsedType = PRType.values.byName(json['type'] as String);
    } catch (_) {
      parsedType = PRType.weight;
    }
    return PersonalRecord(
      id: json['id'] as String,
      exerciseId: json['exerciseId'] as String,
      exerciseName: json['exerciseName'] as String,
      type: parsedType,
      value: (json['value'] as num).toDouble(),
      weight: (json['weight'] as num).toDouble(),
      reps: json['reps'] as int,
      previousValue: (json['previousValue'] as num?)?.toDouble(),
      achievedAt: DateTime.tryParse(json['achievedAt'] as String) ?? DateTime.now(),
    );
  }
}

/// Plate calculator computation result
class PlateCalculationResult {
  final double targetWeightKg;
  final double barWeightKg;
  final double weightPerSide;
  final Map<double, int> platesPerSide; // Plate weight -> Count per side
  final bool isExact;
  final double remainderKg;

  const PlateCalculationResult({
    required this.targetWeightKg,
    required this.barWeightKg,
    required this.weightPerSide,
    required this.platesPerSide,
    required this.isExact,
    required this.remainderKg,
  });
}
