import 'package:alpha_x_gym/features/exercise/data/exercise_media_mapping.dart';

enum MuscleGroup {
  upperChest,
  midChest,
  lowerChest,
  frontDelts,
  sideDelts,
  rearDelts,
  shoulders,
  lats,
  rhomboids,
  traps,
  lowerBack,
  quads,
  hamstrings,
  glutes,
  calves,
  biceps,
  triceps,
  forearms,
  coreAbs,
  fullBody,
}

extension MuscleGroupName on MuscleGroup {
  String get displayName {
    switch (this) {
      case MuscleGroup.upperChest:
        return 'Upper Chest';
      case MuscleGroup.midChest:
        return 'Mid Chest';
      case MuscleGroup.lowerChest:
        return 'Lower Chest';
      case MuscleGroup.frontDelts:
        return 'Front Delts';
      case MuscleGroup.sideDelts:
        return 'Side Delts';
      case MuscleGroup.rearDelts:
        return 'Rear Delts';
      case MuscleGroup.shoulders:
        return 'Shoulders';
      case MuscleGroup.lats:
        return 'Lats';
      case MuscleGroup.rhomboids:
        return 'Rhomboids';
      case MuscleGroup.traps:
        return 'Trapezius';
      case MuscleGroup.lowerBack:
        return 'Lower Back';
      case MuscleGroup.quads:
        return 'Quadriceps';
      case MuscleGroup.hamstrings:
        return 'Hamstrings';
      case MuscleGroup.glutes:
        return 'Glutes';
      case MuscleGroup.calves:
        return 'Calves';
      case MuscleGroup.biceps:
        return 'Biceps';
      case MuscleGroup.triceps:
        return 'Triceps';
      case MuscleGroup.forearms:
        return 'Forearms';
      case MuscleGroup.coreAbs:
        return 'Core & Abs';
      case MuscleGroup.fullBody:
        return 'Full Body';
    }
  }

  static MuscleGroup fromString(String name) {
    for (final m in MuscleGroup.values) {
      if (m.name.toLowerCase() == name.toLowerCase() ||
          m.displayName.toLowerCase() == name.toLowerCase()) {
        return m;
      }
    }
    return MuscleGroup.upperChest;
  }
}

enum ExerciseCategory {
  chest,
  back,
  shoulders,
  biceps,
  triceps,
  forearms,
  quadriceps,
  hamstrings,
  glutes,
  calves,
  legs,
  core,
  fullBody,
  functional,
  conditioning,
  boxing,
  cardio,
  mobility,
  flexibility,
  activation,
  warmUp,
  coolDown,
}

extension ExerciseCategoryExtension on ExerciseCategory {
  String get displayName {
    switch (this) {
      case ExerciseCategory.chest:
        return 'Chest';
      case ExerciseCategory.back:
        return 'Back';
      case ExerciseCategory.shoulders:
        return 'Shoulders';
      case ExerciseCategory.biceps:
        return 'Biceps';
      case ExerciseCategory.triceps:
        return 'Triceps';
      case ExerciseCategory.forearms:
        return 'Forearms';
      case ExerciseCategory.quadriceps:
        return 'Quadriceps';
      case ExerciseCategory.hamstrings:
        return 'Hamstrings';
      case ExerciseCategory.glutes:
        return 'Glutes';
      case ExerciseCategory.calves:
        return 'Calves';
      case ExerciseCategory.legs:
        return 'Legs';
      case ExerciseCategory.core:
        return 'Core';
      case ExerciseCategory.fullBody:
        return 'Full Body';
      case ExerciseCategory.functional:
        return 'Functional';
      case ExerciseCategory.conditioning:
        return 'Conditioning';
      case ExerciseCategory.boxing:
        return 'Boxing';
      case ExerciseCategory.cardio:
        return 'Cardio';
      case ExerciseCategory.mobility:
        return 'Mobility';
      case ExerciseCategory.flexibility:
        return 'Flexibility';
      case ExerciseCategory.activation:
        return 'Activation';
      case ExerciseCategory.warmUp:
        return 'Warm-up';
      case ExerciseCategory.coolDown:
        return 'Cool-down';
    }
  }

  static ExerciseCategory fromString(String name) {
    for (final c in ExerciseCategory.values) {
      if (c.name.toLowerCase() == name.toLowerCase() ||
          c.displayName.toLowerCase() == name.toLowerCase()) {
        return c;
      }
    }
    return ExerciseCategory.chest;
  }
}

enum ExerciseEquipment {
  barbell,
  dumbbell,
  cable,
  smithMachine,
  machine,
  kettlebell,
  resistanceBand,
  bodyweight,
  trx,
  ezBar,
  trapBar,
  medicineBall,
  sled,
  battleRope,
  cardioEquipment,
  boxingEquipment,
  other,
}

extension ExerciseEquipmentExtension on ExerciseEquipment {
  String get displayName {
    switch (this) {
      case ExerciseEquipment.barbell:
        return 'Barbell';
      case ExerciseEquipment.dumbbell:
        return 'Dumbbell';
      case ExerciseEquipment.cable:
        return 'Cable';
      case ExerciseEquipment.smithMachine:
        return 'Smith Machine';
      case ExerciseEquipment.machine:
        return 'Machine';
      case ExerciseEquipment.kettlebell:
        return 'Kettlebell';
      case ExerciseEquipment.resistanceBand:
        return 'Resistance Band';
      case ExerciseEquipment.bodyweight:
        return 'Bodyweight';
      case ExerciseEquipment.trx:
        return 'TRX';
      case ExerciseEquipment.ezBar:
        return 'EZ Bar';
      case ExerciseEquipment.trapBar:
        return 'Trap Bar';
      case ExerciseEquipment.medicineBall:
        return 'Medicine Ball';
      case ExerciseEquipment.sled:
        return 'Sled';
      case ExerciseEquipment.battleRope:
        return 'Battle Rope';
      case ExerciseEquipment.cardioEquipment:
        return 'Cardio Equipment';
      case ExerciseEquipment.boxingEquipment:
        return 'Boxing Equipment';
      case ExerciseEquipment.other:
        return 'Other';
    }
  }

  static ExerciseEquipment fromString(String name) {
    for (final e in ExerciseEquipment.values) {
      if (e.name.toLowerCase() == name.toLowerCase() ||
          e.displayName.toLowerCase() == name.toLowerCase()) {
        return e;
      }
    }
    return ExerciseEquipment.barbell;
  }
}

enum MovementPattern {
  horizontalPush,
  horizontalPull,
  verticalPush,
  verticalPull,
  squat,
  hinge,
  lunge,
  carry,
  rotation,
  isolation,
  cardioBoxing,
}

extension MovementPatternExtension on MovementPattern {
  String get displayName {
    switch (this) {
      case MovementPattern.horizontalPush:
        return 'Horizontal Push';
      case MovementPattern.horizontalPull:
        return 'Horizontal Pull';
      case MovementPattern.verticalPush:
        return 'Vertical Push';
      case MovementPattern.verticalPull:
        return 'Vertical Pull';
      case MovementPattern.squat:
        return 'Squat';
      case MovementPattern.hinge:
        return 'Hinge';
      case MovementPattern.lunge:
        return 'Lunge';
      case MovementPattern.carry:
        return 'Carry';
      case MovementPattern.rotation:
        return 'Rotation';
      case MovementPattern.isolation:
        return 'Isolation';
      case MovementPattern.cardioBoxing:
        return 'Cardio / Boxing';
    }
  }

  static MovementPattern fromString(String name) {
    for (final p in MovementPattern.values) {
      if (p.name.toLowerCase() == name.toLowerCase() ||
          p.displayName.toLowerCase() == name.toLowerCase()) {
        return p;
      }
    }
    return MovementPattern.isolation;
  }
}

enum ExerciseDifficulty {
  beginner,
  intermediate,
  advanced,
}

extension ExerciseDifficultyExtension on ExerciseDifficulty {
  String get displayName {
    switch (this) {
      case ExerciseDifficulty.beginner:
        return 'Beginner';
      case ExerciseDifficulty.intermediate:
        return 'Intermediate';
      case ExerciseDifficulty.advanced:
        return 'Advanced';
    }
  }

  static ExerciseDifficulty fromString(String name) {
    for (final d in ExerciseDifficulty.values) {
      if (d.name.toLowerCase() == name.toLowerCase() ||
          d.displayName.toLowerCase() == name.toLowerCase()) {
        return d;
      }
    }
    return ExerciseDifficulty.intermediate;
  }
}

enum ExerciseTypeEnum {
  strength,
  hypertrophy,
  power,
  functional,
  conditioning,
  boxing,
  cardio,
  mobility,
}

extension ExerciseTypeEnumExtension on ExerciseTypeEnum {
  String get displayName {
    switch (this) {
      case ExerciseTypeEnum.strength:
        return 'Strength';
      case ExerciseTypeEnum.hypertrophy:
        return 'Hypertrophy';
      case ExerciseTypeEnum.power:
        return 'Power';
      case ExerciseTypeEnum.functional:
        return 'Functional';
      case ExerciseTypeEnum.conditioning:
        return 'Conditioning';
      case ExerciseTypeEnum.boxing:
        return 'Boxing';
      case ExerciseTypeEnum.cardio:
        return 'Cardio';
      case ExerciseTypeEnum.mobility:
        return 'Mobility';
    }
  }

  static ExerciseTypeEnum fromString(String name) {
    for (final t in ExerciseTypeEnum.values) {
      if (t.name.toLowerCase() == name.toLowerCase() ||
          t.displayName.toLowerCase() == name.toLowerCase()) {
        return t;
      }
    }
    return ExerciseTypeEnum.strength;
  }
}

class Exercise {
  final String id;
  final String name;
  final String displayName;
  final String description;
  final String category; // Stored as display name or string
  final String? subCategory;
  final List<MuscleGroup> primaryMuscles;
  final List<MuscleGroup> secondaryMuscles;
  final String equipment; // Equipment display name or custom equipment string
  final String movementPattern;
  final String difficulty;
  final String exerciseType;
  final List<String> setupInstructions;
  final List<String> executionSteps;
  final List<String> coachingCues;
  final List<String> commonMistakes;
  final List<String> approvedAlternativeIds;
  final String defaultTrainerNote;
  final String videoUrl;
  final String thumbnailUrl;
  final String imageUrl;
  final String animationUrl;
  final String gifUrl;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;

  Exercise({
    required this.id,
    required this.name,
    String? displayName,
    this.description = '',
    required this.category,
    this.subCategory,
    required this.primaryMuscles,
    this.secondaryMuscles = const [],
    this.equipment = 'Barbell',
    this.movementPattern = 'Horizontal Push',
    this.difficulty = 'Intermediate',
    this.exerciseType = 'Strength',
    this.setupInstructions = const [],
    this.executionSteps = const [],
    this.coachingCues = const [],
    this.commonMistakes = const [],
    this.approvedAlternativeIds = const [],
    this.defaultTrainerNote = '',
    this.videoUrl = '',
    this.thumbnailUrl = '',
    this.imageUrl = '',
    this.animationUrl = '',
    this.gifUrl = '',
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.tags = const [],
  })  : displayName = displayName ?? name,
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Returns the verified animated GIF demonstration URL specifically for this exercise.
  /// Resolves strictly via: gifUrl -> animationUrl (if valid gif) -> ExerciseMediaMapping.
  /// Strictly returns ANIMATED GIF media. NEVER falls back to static hero images or MP4 videos.
  String get gifDemonstrationUrl {
    final g = gifUrl.trim();
    if (ExerciseMediaMapping.isValidGif(g)) return g;
    final a = animationUrl.trim();
    if (ExerciseMediaMapping.isValidGif(a)) return a;
    final mapped = ExerciseMediaMapping.getGifForExerciseId(id) ??
        ExerciseMediaMapping.getGifForExerciseName(name);
    if (mapped != null && ExerciseMediaMapping.isValidGif(mapped)) return mapped;
    return '';
  }

  /// Backwards compatibility getter: strictly returns animated GIF demonstration URL.
  /// Never returns hero images, static photos, or external video players.
  String get actualMediaUrl => gifDemonstrationUrl;

  bool get hasActualMedia => gifDemonstrationUrl.isNotEmpty;
  bool get hasGifDemonstration => gifDemonstrationUrl.isNotEmpty;

  String get primaryMusclesDisplay =>
      primaryMuscles.map((m) => m.displayName).join(' • ');

  String get secondaryMusclesDisplay =>
      secondaryMuscles.map((m) => m.displayName).join(' • ');

  Exercise copyWith({
    String? id,
    String? name,
    String? displayName,
    String? description,
    String? category,
    String? subCategory,
    List<MuscleGroup>? primaryMuscles,
    List<MuscleGroup>? secondaryMuscles,
    String? equipment,
    String? movementPattern,
    String? difficulty,
    String? exerciseType,
    List<String>? setupInstructions,
    List<String>? executionSteps,
    List<String>? coachingCues,
    List<String>? commonMistakes,
    List<String>? approvedAlternativeIds,
    String? defaultTrainerNote,
    String? videoUrl,
    String? thumbnailUrl,
    String? imageUrl,
    String? animationUrl,
    String? gifUrl,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? tags,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      description: description ?? this.description,
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      primaryMuscles: primaryMuscles ?? this.primaryMuscles,
      secondaryMuscles: secondaryMuscles ?? this.secondaryMuscles,
      equipment: equipment ?? this.equipment,
      movementPattern: movementPattern ?? this.movementPattern,
      difficulty: difficulty ?? this.difficulty,
      exerciseType: exerciseType ?? this.exerciseType,
      setupInstructions: setupInstructions ?? this.setupInstructions,
      executionSteps: executionSteps ?? this.executionSteps,
      coachingCues: coachingCues ?? this.coachingCues,
      commonMistakes: commonMistakes ?? this.commonMistakes,
      approvedAlternativeIds: approvedAlternativeIds ?? this.approvedAlternativeIds,
      defaultTrainerNote: defaultTrainerNote ?? this.defaultTrainerNote,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      animationUrl: animationUrl ?? this.animationUrl,
      gifUrl: gifUrl ?? this.gifUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      tags: tags ?? this.tags,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'displayName': displayName,
      'description': description,
      'category': category,
      'subCategory': subCategory,
      'primaryMuscles': primaryMuscles.map((m) => m.name).toList(),
      'secondaryMuscles': secondaryMuscles.map((m) => m.name).toList(),
      'equipment': equipment,
      'movementPattern': movementPattern,
      'difficulty': difficulty,
      'exerciseType': exerciseType,
      'setupInstructions': setupInstructions,
      'executionSteps': executionSteps,
      'coachingCues': coachingCues,
      'commonMistakes': commonMistakes,
      'approvedAlternativeIds': approvedAlternativeIds,
      'defaultTrainerNote': defaultTrainerNote,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'imageUrl': imageUrl,
      'animationUrl': gifDemonstrationUrl,
      'gifUrl': gifDemonstrationUrl,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'tags': tags,
    };
  }

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as String,
      name: json['name'] as String,
      displayName: json['displayName'] as String?,
      description: json['description'] as String? ?? '',
      category: json['category'] as String,
      subCategory: json['subCategory'] as String?,
      primaryMuscles: (json['primaryMuscles'] as List<dynamic>?)
              ?.map((m) => MuscleGroupName.fromString(m.toString()))
              .toList() ??
          [],
      secondaryMuscles: (json['secondaryMuscles'] as List<dynamic>?)
              ?.map((m) => MuscleGroupName.fromString(m.toString()))
              .toList() ??
          [],
      equipment: json['equipment'] as String? ?? 'Barbell',
      movementPattern: json['movementPattern'] as String? ?? 'Isolation',
      difficulty: json['difficulty'] as String? ?? 'Intermediate',
      exerciseType: json['exerciseType'] as String? ?? 'Strength',
      setupInstructions: (json['setupInstructions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      executionSteps: (json['executionSteps'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      coachingCues: (json['coachingCues'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      commonMistakes: (json['commonMistakes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      approvedAlternativeIds: (json['approvedAlternativeIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      defaultTrainerNote: json['defaultTrainerNote'] as String? ?? '',
      videoUrl: json['videoUrl'] as String? ?? json['video_url'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? json['thumbnail_url'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? json['image_url'] as String? ?? '',
      animationUrl: json['animationUrl'] as String? ?? json['animation_url'] as String? ?? '',
      gifUrl: json['gifUrl'] as String? ?? json['gif_url'] as String? ?? json['animationUrl'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}
