/// Represents a Client Weekly Check-In submission in the Alpha X Fitness System
class WeeklyCheckIn {
  final String id;
  final String? clientId;
  final String clientProfileId;
  final int weekNumber;
  final int year;
  final DateTime checkInDate;
  final DateTime nextCheckInDate;

  // Body Progress
  final double weightKg;
  final double? waistCm;
  final double? chestCm;
  final double? armsCm;
  final double? hipsCm;
  final double? thighsCm;
  final double? weightChange;
  final double? waistChange;

  // Nutrition Adherence (Previous 7 days)
  final String nutritionCalories; // Good, Mostly, Poor
  final String nutritionProtein;  // Good, Mostly, Poor
  final String nutritionWater;    // Good, Average, Poor
  final String dietAdherence;     // Good, Mostly, Poor

  // Sleep & Recovery
  final String sleepQuality;      // Good, Average, Poor
  final double sleepHours;
  final String recoveryQuality;   // Good, Average, Poor

  // Workout
  final String workoutCompletion; // All, Most, Some, None
  final String workoutFeeling;    // Very Good, Good, Average, Difficult
  final String energyLevel;       // High, Good, Low

  // Pain / Discomfort
  final bool hasPain;
  final String? painLocation;
  final String? painExercise;
  final int? painLevel;           // 1 - 10
  final String? painDescription;

  // Weekly Problems & Client Notes
  final List<String> weeklyProblems;
  final String? clientNotes;

  // Coach Review
  final bool hasCoachReview;
  final String? reviewedById;
  final String? reviewedByName;
  final DateTime? reviewedAt;
  final String? whatWentWell;
  final String? needsImprovement;
  final String? nextWeekFocus;
  final String? workoutNotes;
  final String? nutritionNotes;
  final String? recoveryNotes;
  final bool followUpRequired;

  final DateTime createdAt;

  const WeeklyCheckIn({
    required this.id,
    this.clientId,
    required this.clientProfileId,
    required this.weekNumber,
    required this.year,
    required this.checkInDate,
    required this.nextCheckInDate,
    required this.weightKg,
    this.waistCm,
    this.chestCm,
    this.armsCm,
    this.hipsCm,
    this.thighsCm,
    this.weightChange,
    this.waistChange,
    required this.nutritionCalories,
    required this.nutritionProtein,
    required this.nutritionWater,
    required this.dietAdherence,
    required this.sleepQuality,
    required this.sleepHours,
    required this.recoveryQuality,
    required this.workoutCompletion,
    required this.workoutFeeling,
    required this.energyLevel,
    this.hasPain = false,
    this.painLocation,
    this.painExercise,
    this.painLevel,
    this.painDescription,
    this.weeklyProblems = const [],
    this.clientNotes,
    this.hasCoachReview = false,
    this.reviewedById,
    this.reviewedByName,
    this.reviewedAt,
    this.whatWentWell,
    this.needsImprovement,
    this.nextWeekFocus,
    this.workoutNotes,
    this.nutritionNotes,
    this.recoveryNotes,
    this.followUpRequired = false,
    required this.createdAt,
  });

  String get weightDisplay => '${weightKg.toStringAsFixed(1)} kg';
  String get waistDisplay => waistCm != null ? '${waistCm!.toStringAsFixed(1)} cm' : '—';

  String get weightChangeDisplay {
    if (weightChange == null) return 'Baseline';
    final sign = weightChange! > 0 ? '+' : '';
    return '$sign${weightChange!.toStringAsFixed(1)} kg';
  }

  String get waistChangeDisplay {
    if (waistChange == null) return 'Baseline';
    final sign = waistChange! > 0 ? '+' : '';
    return '$sign${waistChange!.toStringAsFixed(1)} cm';
  }

  factory WeeklyCheckIn.fromJson(Map<String, dynamic> json) {
    return WeeklyCheckIn(
      id: json['id'] as String? ?? '',
      clientId: json['clientId'] as String?,
      clientProfileId: json['clientProfileId'] as String? ?? '',
      weekNumber: (json['weekNumber'] as num?)?.toInt() ?? 1,
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      checkInDate: json['checkInDate'] != null
          ? DateTime.tryParse(json['checkInDate'].toString()) ?? DateTime.now()
          : DateTime.now(),
      nextCheckInDate: json['nextCheckInDate'] != null
          ? DateTime.tryParse(json['nextCheckInDate'].toString()) ?? DateTime.now().add(const Duration(days: 7))
          : DateTime.now().add(const Duration(days: 7)),
      weightKg: (json['weightKg'] as num?)?.toDouble() ?? 70.0,
      waistCm: (json['waistCm'] as num?)?.toDouble(),
      chestCm: (json['chestCm'] as num?)?.toDouble(),
      armsCm: (json['armsCm'] as num?)?.toDouble(),
      hipsCm: (json['hipsCm'] as num?)?.toDouble(),
      thighsCm: (json['thighsCm'] as num?)?.toDouble(),
      weightChange: (json['weightChange'] as num?)?.toDouble(),
      waistChange: (json['waistChange'] as num?)?.toDouble(),
      nutritionCalories: json['nutritionCalories'] as String? ?? 'Good',
      nutritionProtein: json['nutritionProtein'] as String? ?? 'Good',
      nutritionWater: json['nutritionWater'] as String? ?? 'Good',
      dietAdherence: json['dietAdherence'] as String? ?? 'Good',
      sleepQuality: json['sleepQuality'] as String? ?? 'Good',
      sleepHours: (json['sleepHours'] as num?)?.toDouble() ?? 7.0,
      recoveryQuality: json['recoveryQuality'] as String? ?? 'Good',
      workoutCompletion: json['workoutCompletion'] as String? ?? 'All',
      workoutFeeling: json['workoutFeeling'] as String? ?? 'Good',
      energyLevel: json['energyLevel'] as String? ?? 'Good',
      hasPain: json['hasPain'] as bool? ?? false,
      painLocation: json['painLocation'] as String?,
      painExercise: json['painExercise'] as String?,
      painLevel: (json['painLevel'] as num?)?.toInt(),
      painDescription: json['painDescription'] as String?,
      weeklyProblems: (json['weeklyProblems'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      clientNotes: json['clientNotes'] as String?,
      hasCoachReview: json['hasCoachReview'] as bool? ?? false,
      reviewedById: json['reviewedById'] as String?,
      reviewedByName: json['reviewedByName'] as String?,
      reviewedAt: json['reviewedAt'] != null ? DateTime.tryParse(json['reviewedAt'].toString()) : null,
      whatWentWell: json['whatWentWell'] as String?,
      needsImprovement: json['needsImprovement'] as String?,
      nextWeekFocus: json['nextWeekFocus'] as String?,
      workoutNotes: json['workoutNotes'] as String?,
      nutritionNotes: json['nutritionNotes'] as String?,
      recoveryNotes: json['recoveryNotes'] as String?,
      followUpRequired: json['followUpRequired'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'clientId': clientId,
    'clientProfileId': clientProfileId,
    'weekNumber': weekNumber,
    'year': year,
    'checkInDate': checkInDate.toIso8601String(),
    'nextCheckInDate': nextCheckInDate.toIso8601String(),
    'weightKg': weightKg,
    'waistCm': waistCm,
    'chestCm': chestCm,
    'armsCm': armsCm,
    'hipsCm': hipsCm,
    'thighsCm': thighsCm,
    'weightChange': weightChange,
    'waistChange': waistChange,
    'nutritionCalories': nutritionCalories,
    'nutritionProtein': nutritionProtein,
    'nutritionWater': nutritionWater,
    'dietAdherence': dietAdherence,
    'sleepQuality': sleepQuality,
    'sleepHours': sleepHours,
    'recoveryQuality': recoveryQuality,
    'workoutCompletion': workoutCompletion,
    'workoutFeeling': workoutFeeling,
    'energyLevel': energyLevel,
    'hasPain': hasPain,
    'painLocation': painLocation,
    'painExercise': painExercise,
    'painLevel': painLevel,
    'painDescription': painDescription,
    'weeklyProblems': weeklyProblems,
    'clientNotes': clientNotes,
    'hasCoachReview': hasCoachReview,
    'reviewedById': reviewedById,
    'reviewedByName': reviewedByName,
    'reviewedAt': reviewedAt?.toIso8601String(),
    'whatWentWell': whatWentWell,
    'needsImprovement': needsImprovement,
    'nextWeekFocus': nextWeekFocus,
    'workoutNotes': workoutNotes,
    'nutritionNotes': nutritionNotes,
    'recoveryNotes': recoveryNotes,
    'followUpRequired': followUpRequired,
  };
}
