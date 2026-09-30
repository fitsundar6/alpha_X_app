import 'macro_enums.dart';

/// Strongly typed client inputs for macro calculation
class MacroInput {
  final int age;
  final BiologicalSex sex;
  final double heightCm;
  final double weightKg;
  final ActivityLevel activityLevel;
  final NutritionGoal goal;

  const MacroInput({
    required this.age,
    required this.sex,
    required this.heightCm,
    required this.weightKg,
    required this.activityLevel,
    required this.goal,
  });

  /// Validate realistic physiological boundaries
  static String? validateAge(String? val) {
    if (val == null || val.trim().isEmpty) return 'Age is required';
    final parsed = int.tryParse(val.trim());
    if (parsed == null) return 'Enter a valid number';
    if (parsed < 14) return 'Minimum age is 14 years';
    if (parsed > 100) return 'Enter a realistic age (14–100)';
    return null;
  }

  static String? validateHeight(String? val) {
    if (val == null || val.trim().isEmpty) return 'Height is required';
    final parsed = double.tryParse(val.trim());
    if (parsed == null) return 'Enter a valid number';
    if (parsed < 100.0) return 'Minimum height is 100 cm';
    if (parsed > 250.0) return 'Maximum height is 250 cm';
    return null;
  }

  static String? validateWeight(String? val) {
    if (val == null || val.trim().isEmpty) return 'Weight is required';
    final parsed = double.tryParse(val.trim());
    if (parsed == null) return 'Enter a valid number';
    if (parsed < 30.0) return 'Minimum weight is 30 kg';
    if (parsed > 300.0) return 'Maximum weight is 300 kg';
    return null;
  }

  // Unit conversion helpers (metric internally, imperial for display)
  static double lbsToKg(double lbs) => lbs * 0.45359237;
  static double kgToLbs(double kg) => kg / 0.45359237;

  static double feetInchesToCm(int feet, double inches) {
    final totalInches = (feet * 12) + inches;
    return totalInches * 2.54;
  }

  static (int feet, double inches) cmToFeetInches(double cm) {
    final totalInches = cm / 2.54;
    final feet = totalInches ~/ 12;
    final remainingInches = totalInches % 12;
    return (feet, remainingInches);
  }

  MacroInput copyWith({
    int? age,
    BiologicalSex? sex,
    double? heightCm,
    double? weightKg,
    ActivityLevel? activityLevel,
    NutritionGoal? goal,
  }) {
    return MacroInput(
      age: age ?? this.age,
      sex: sex ?? this.sex,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      activityLevel: activityLevel ?? this.activityLevel,
      goal: goal ?? this.goal,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'age': age,
      'sex': sex.name,
      'heightCm': heightCm,
      'weightKg': weightKg,
      'activityLevel': activityLevel.name,
      'goal': goal.name,
    };
  }

  factory MacroInput.fromJson(Map<String, dynamic> json) {
    return MacroInput(
      age: json['age'] as int,
      sex: BiologicalSex.values.firstWhere(
        (s) => s.name == json['sex'],
        orElse: () => BiologicalSex.male,
      ),
      heightCm: (json['heightCm'] as num).toDouble(),
      weightKg: (json['weightKg'] as num).toDouble(),
      activityLevel: ActivityLevel.values.firstWhere(
        (a) => a.name == json['activityLevel'],
        orElse: () => ActivityLevel.moderatelyActive,
      ),
      goal: NutritionGoal.values.firstWhere(
        (g) => g.name == json['goal'],
        orElse: () => NutritionGoal.fatLoss,
      ),
    );
  }
}
