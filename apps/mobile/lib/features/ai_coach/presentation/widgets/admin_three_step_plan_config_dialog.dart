import 'package:flutter/material.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/features/ai_coach/domain/models/ai_coach_models.dart';
import 'package:alpha_x_gym/features/ai_coach/data/repositories/ai_coach_repository.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';

class WorkoutSplitTemplateInfo {
  final String key;
  final String id;
  final String displayName;
  final String category;
  final String description;
  final int defaultDays;
  final int minDays;
  final int maxDays;

  const WorkoutSplitTemplateInfo({
    required this.key,
    required this.id,
    required this.displayName,
    required this.category,
    required this.description,
    required this.defaultDays,
    required this.minDays,
    required this.maxDays,
  });
}

const List<WorkoutSplitTemplateInfo> allWorkoutSplits = [
  WorkoutSplitTemplateInfo(
    key: 'FULL_BODY',
    id: 'full_body',
    displayName: 'Full Body',
    category: 'Movement',
    description: 'Trains every major muscle group each session with balanced, rotating compound lifts.',
    defaultDays: 3,
    minDays: 2,
    maxDays: 4,
  ),
  WorkoutSplitTemplateInfo(
    key: 'UPPER_LOWER',
    id: 'upper_lower',
    displayName: 'Upper / Lower',
    category: 'Movement',
    description: 'Alternates upper body torso sessions with lower body leg and posterior chain sessions.',
    defaultDays: 4,
    minDays: 2,
    maxDays: 5,
  ),
  WorkoutSplitTemplateInfo(
    key: 'PUSH_PULL_LEGS',
    id: 'push_pull_legs',
    displayName: 'Push / Pull / Legs',
    category: 'Movement',
    description: 'Gold-standard movement split grouping pushing muscles, pulling muscles, and legs.',
    defaultDays: 3,
    minDays: 3,
    maxDays: 6,
  ),
  WorkoutSplitTemplateInfo(
    key: 'PPL_X2',
    id: 'ppl_x2',
    displayName: 'PPL × 2',
    category: 'Movement',
    description: 'High-frequency 6-day split running Push/Pull/Legs twice weekly with varied movement variations.',
    defaultDays: 6,
    minDays: 5,
    maxDays: 6,
  ),
  WorkoutSplitTemplateInfo(
    key: 'BRO_SPLIT',
    id: 'bro_split',
    displayName: 'Bro Split / One Muscle per Day',
    category: 'Bodypart',
    description: 'Classic single-muscle focus providing maximal isolation and pump per individual body part.',
    defaultDays: 5,
    minDays: 4,
    maxDays: 6,
  ),
  WorkoutSplitTemplateInfo(
    key: 'CHEST_BACK_SHOULDERS_ARMS_LEGS',
    id: 'chest_back_shoulders_arms_legs',
    displayName: 'Chest / Back / Shoulders / Arms / Legs',
    category: 'Bodypart',
    description: 'Systematic 5-day bodypart isolation targeting full muscular symmetry.',
    defaultDays: 5,
    minDays: 4,
    maxDays: 5,
  ),
  WorkoutSplitTemplateInfo(
    key: 'ARNOLD_SPLIT',
    id: 'arnold_split',
    displayName: 'Arnold Split',
    category: 'Bodypart',
    description: 'Golden-Era favorite pairing opposing muscle groups: Chest/Back, Shoulders/Arms, and Legs.',
    defaultDays: 6,
    minDays: 3,
    maxDays: 6,
  ),
  WorkoutSplitTemplateInfo(
    key: 'ANTAGONIST_SPLIT',
    id: 'antagonist_split',
    displayName: 'Antagonist Split',
    category: 'Movement',
    description: 'Alternating opposing muscle pairs for maximum mechanical efficiency and muscle recovery.',
    defaultDays: 4,
    minDays: 3,
    maxDays: 5,
  ),
  WorkoutSplitTemplateInfo(
    key: 'POWERLIFTING_SPLIT',
    id: 'powerlifting_split',
    displayName: 'Powerlifting Split',
    category: 'Strength',
    description: 'Competition-focused periodization for maximal 1RM strength in Squat, Bench, and Deadlift.',
    defaultDays: 3,
    minDays: 3,
    maxDays: 4,
  ),
  WorkoutSplitTemplateInfo(
    key: 'SBD_FOCUS',
    id: 'sbd_focus',
    displayName: 'Squat / Bench / Deadlift Focus',
    category: 'Strength',
    description: 'Direct focus on the Big Three power movements with targeted hypertrophy assistance.',
    defaultDays: 3,
    minDays: 3,
    maxDays: 4,
  ),
  WorkoutSplitTemplateInfo(
    key: 'FIVE_THREE_ONE',
    id: 'five_three_one',
    displayName: '5/3/1-style strength programming',
    category: 'Strength',
    description: 'Jim Wendler wave loading protocol rotating overhead press, deadlift, bench, and squat.',
    defaultDays: 4,
    minDays: 3,
    maxDays: 4,
  ),
  WorkoutSplitTemplateInfo(
    key: 'UPPER_LOWER_STRENGTH',
    id: 'upper_lower_strength',
    displayName: 'Upper / Lower Strength',
    category: 'Strength',
    description: 'Heavy compound upper/lower split engineered for strength progression and high CNS output.',
    defaultDays: 4,
    minDays: 3,
    maxDays: 4,
  ),
  WorkoutSplitTemplateInfo(
    key: 'HYPERTROPHY_SPECIALIZATION',
    id: 'hypertrophy_specialization',
    displayName: 'Hypertrophy / Specialization Split',
    category: 'Bodypart',
    description: 'High-volume hypertrophy split directing prioritized weekly volume into specific lagging muscle groups.',
    defaultDays: 5,
    minDays: 4,
    maxDays: 6,
  ),
  WorkoutSplitTemplateInfo(
    key: 'WEAK_POINT_FOCUS',
    id: 'weak_point_focus',
    displayName: 'Weak-Point Focus Split',
    category: 'Bodypart',
    description: 'Prioritizes identified athlete weak points at start of session before systemic fatigue builds.',
    defaultDays: 4,
    minDays: 3,
    maxDays: 5,
  ),
  WorkoutSplitTemplateInfo(
    key: 'UPPER_LOWER_ARMS',
    id: 'upper_lower_arms',
    displayName: 'Upper / Lower + Arms',
    category: 'Bodypart',
    description: 'Standard 4-day Upper/Lower structure enhanced with a dedicated 5th day for direct arm and shoulder growth.',
    defaultDays: 5,
    minDays: 4,
    maxDays: 5,
  ),
  WorkoutSplitTemplateInfo(
    key: 'FULL_BODY_CONDITIONING',
    id: 'full_body_conditioning',
    displayName: 'Full Body + Conditioning',
    category: 'Conditioning',
    description: 'Blends full body compound resistance training with dedicated aerobic and work capacity sessions.',
    defaultDays: 4,
    minDays: 3,
    maxDays: 5,
  ),
  WorkoutSplitTemplateInfo(
    key: 'STRENGTH_CONDITIONING',
    id: 'strength_conditioning',
    displayName: 'Strength + Conditioning',
    category: 'Conditioning',
    description: 'Combines heavy raw barbell strength with high-efficiency metabolic conditioning intervals.',
    defaultDays: 4,
    minDays: 3,
    maxDays: 5,
  ),
  WorkoutSplitTemplateInfo(
    key: 'CIRCUIT_TRAINING',
    id: 'circuit_training',
    displayName: 'Circuit Training',
    category: 'Conditioning',
    description: 'High-density multi-exercise circuits focusing on elevated heart rates, muscular endurance, and fat loss.',
    defaultDays: 3,
    minDays: 2,
    maxDays: 4,
  ),
  WorkoutSplitTemplateInfo(
    key: 'SPORTS_PERFORMANCE',
    id: 'sports_performance',
    displayName: 'Sports Performance Split',
    category: 'Strength',
    description: 'Engineered for athletes: rate of force development, explosive power, speed, agility, and injury prevention.',
    defaultDays: 4,
    minDays: 3,
    maxDays: 5,
  ),
  WorkoutSplitTemplateInfo(
    key: 'CUSTOM_SPLIT',
    id: 'custom_split',
    displayName: 'Custom Split',
    category: 'Custom',
    description: 'Fully flexible template configured by admin to athlete specific requirements.',
    defaultDays: 4,
    minDays: 2,
    maxDays: 7,
  ),
];

class AdminThreeStepPlanConfigDialog extends StatefulWidget {
  final AiCoachRepository aiCoachRepository;
  final WorkoutRepository? workoutRepository;
  final String? initialClientId;
  final AiProposalType? initialPlanType;
  final String? conversationId;
  final Function(AiProposal proposal)? onProposalCreated;

  const AdminThreeStepPlanConfigDialog({
    super.key,
    required this.aiCoachRepository,
    this.workoutRepository,
    this.initialClientId,
    this.initialPlanType,
    this.conversationId,
    this.onProposalCreated,
  });

  static Future<AiProposal?> show({
    required BuildContext context,
    required AiCoachRepository aiCoachRepository,
    WorkoutRepository? workoutRepository,
    String? initialClientId,
    AiProposalType? initialPlanType,
    String? conversationId,
    Function(AiProposal proposal)? onProposalCreated,
  }) {
    return showModalBottomSheet<AiProposal>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AdminThreeStepPlanConfigDialog(
        aiCoachRepository: aiCoachRepository,
        workoutRepository: workoutRepository,
        initialClientId: initialClientId,
        initialPlanType: initialPlanType,
        conversationId: conversationId,
        onProposalCreated: onProposalCreated,
      ),
    );
  }

  @override
  State<AdminThreeStepPlanConfigDialog> createState() => _AdminThreeStepPlanConfigDialogState();
}

class _AdminThreeStepPlanConfigDialogState extends State<AdminThreeStepPlanConfigDialog> {
  int _currentStep = 1;

  // Step 1: Selected Client State
  String? _selectedClientId;
  String _selectedClientName = 'Select an Athlete';
  Map<String, String> _selectedClientData = {};
  final TextEditingController _clientSearchController = TextEditingController();

  // Step 2: Plan Type State
  AiProposalType _selectedPlanType = AiProposalType.workout;

  // Step 3 (Workout): Configuration State
  String _splitSearchQuery = '';
  final TextEditingController _splitSearchController = TextEditingController();
  WorkoutSplitTemplateInfo _selectedSplit = allWorkoutSplits[0]; // Full Body
  int _daysPerWeek = 4;
  final Set<String> _selectedWeekdays = {'Monday', 'Tuesday', 'Thursday', 'Friday'};
  String _primaryGoal = 'Hypertrophy';
  String _trainingExperience = 'Intermediate';
  String _equipment = 'Full Commercial Gym';
  int _sessionDurationMinutes = 50;
  final Set<String> _focusMuscles = <String>{};
  final Set<String> _weakPoints = <String>{};
  final TextEditingController _exclusionsController = TextEditingController();
  final TextEditingController _preferredController = TextEditingController();
  final TextEditingController _avoidController = TextEditingController();

  // Step 3 (Diet): Configuration State
  bool _isMacroOnly = false;
  String _dietGoal = 'Fat Loss';
  final TextEditingController _caloriesController = TextEditingController(text: '2000');
  final TextEditingController _proteinController = TextEditingController(text: '160');
  final TextEditingController _carbsController = TextEditingController(text: '200');
  final TextEditingController _fatController = TextEditingController(text: '55');
  final TextEditingController _fiberController = TextEditingController(text: '30');
  final TextEditingController _waterController = TextEditingController(text: '3.5');
  final Set<String> _dietaryPreferences = <String>{};
  int _mealsPerDay = 4;

  bool _isGenerating = false;
  String? _errorMessage;

  final List<String> _allWeekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  final List<String> _allMuscleGroups = [
    'Chest', 'Back', 'Shoulders', 'Biceps', 'Triceps', 'Quadriceps', 'Hamstrings', 'Glutes', 'Calves', 'Core'
  ];

  final List<String> _allDietaryPreferences = [
    'Vegetarian', 'Non-Vegetarian', 'Vegan', 'Egg-Free', 'Dairy-Free', 'Nut-Free', 'Gluten-Free'
  ];

  @override
  void initState() {
    super.initState();
    _selectedClientId = widget.initialClientId;
    if (widget.initialPlanType != null) {
      _selectedPlanType = widget.initialPlanType!;
      _currentStep = 3; // jump to step 3 if client and type are already targeted
    }

    _loadClientData();
  }

  static const List<Map<String, String>> defaultSeedClients = [
    {
      'clientId': 'AXG-0001',
      'id': 'AXG-0001',
      'name': 'Kumar',
      'primaryGoal': 'Hypertrophy',
      'fitnessLevel': 'Intermediate',
      'trainingDaysPerWeek': '4',
      'equipmentAccess': 'Full Gym Equipment',
      'hasCurrentInjury': 'true',
      'injuryAreas': 'Lower Back (Avoid heavy conventional deadlifts)',
      'weightKg': '78',
      'heightCm': '176',
    },
    {
      'clientId': 'AXG-0002',
      'id': 'AXG-0002',
      'name': 'Alex Johnson',
      'primaryGoal': 'Strength',
      'fitnessLevel': 'Advanced',
      'trainingDaysPerWeek': '5',
      'equipmentAccess': 'Barbell & Plates',
      'hasCurrentInjury': 'false',
      'weightKg': '85',
      'heightCm': '182',
    },
    {
      'clientId': 'AXG-0003',
      'id': 'AXG-0003',
      'name': 'Sarah Smith',
      'primaryGoal': 'Fat Loss',
      'fitnessLevel': 'Beginner',
      'trainingDaysPerWeek': '3',
      'equipmentAccess': 'Dumbbells & Bench',
      'hasCurrentInjury': 'false',
      'weightKg': '62',
      'heightCm': '165',
    },
  ];

  List<Map<String, String>> _getAllClients() {
    final repoClients = widget.workoutRepository?.clientsList ?? [];
    if (repoClients.isNotEmpty) return repoClients;
    return defaultSeedClients;
  }

  void _loadClientData() {
    final clients = _getAllClients();
    if (_selectedClientId != null && clients.isNotEmpty) {
      final match = clients.firstWhere(
        (c) => c['clientId'] == _selectedClientId || c['id'] == _selectedClientId,
        orElse: () => {},
      );
      if (match.isNotEmpty) {
        _selectedClientData = Map<String, String>.from(match);
        _selectedClientName = match['name'] ?? _selectedClientId!;

        // Pre-fill fields from actual client assessment
        if (match['primaryGoal'] != null) {
          _primaryGoal = match['primaryGoal']!;
          final pg = match['primaryGoal']!.toLowerCase();
          if (pg.contains('fat loss') || pg.contains('cutting') || pg.contains('cut')) {
            _dietGoal = 'Fat Loss';
          } else if (pg.contains('hypertrophy') || pg.contains('muscle') || pg.contains('bulk') || pg.contains('strength')) {
            _dietGoal = 'Lean Muscle Gain / Bulking';
          } else if (pg.contains('athletic') || pg.contains('performance') || pg.contains('sport')) {
            _dietGoal = 'Athletic Performance';
          } else {
            _dietGoal = 'Maintenance';
          }
        }
        if (match['fitnessLevel'] != null) {
          _trainingExperience = match['fitnessLevel']!;
        }
        if (match['trainingDaysPerWeek'] != null) {
          final parsedDays = int.tryParse(match['trainingDaysPerWeek']!);
          if (parsedDays != null && parsedDays >= 2 && parsedDays <= 7) {
            _daysPerWeek = parsedDays;
          }
        }
        if (match['hasCurrentInjury'] == 'true' && match['injuryAreas'] != null) {
          _exclusionsController.text = match['injuryAreas']!;
        }

        // Auto compute personalized diet metrics based on client biometrics and goal
        _recalculateDietMacrosForGoal(_dietGoal);
      }
    } else {
      _recalculateDietMacrosForGoal(_dietGoal);
    }
  }

  void _recalculateDietMacrosForGoal(String goal) {
    final rawWeight = double.tryParse(_selectedClientData['weightKg'] ?? '');
    final rawHeight = double.tryParse(_selectedClientData['heightCm'] ?? '');
    final rawAge = int.tryParse(_selectedClientData['age'] ?? '');
    final gender = (_selectedClientData['gender'] ?? 'male').toLowerCase();
    final trainingDays = int.tryParse(_selectedClientData['trainingDaysPerWeek'] ?? '') ?? _daysPerWeek;

    final isMissingAssessmentData = rawWeight == null || rawWeight <= 0 || rawHeight == null || rawHeight <= 0;
    final weightKg = !isMissingAssessmentData ? rawWeight : 70.0;
    final heightCm = !isMissingAssessmentData ? rawHeight : 175.0;
    final age = (rawAge != null && rawAge > 0 && rawAge < 100) ? rawAge : 28;

    // 1. Mifflin-St Jeor BMR
    final double bmr = gender == 'female'
        ? (10 * weightKg + 6.25 * heightCm - 5 * age - 161)
        : (10 * weightKg + 6.25 * heightCm - 5 * age + 5);

    // 2. Activity Multiplier
    double activityMultiplier = 1.55;
    if (trainingDays >= 6) {
      activityMultiplier = 1.725;
    } else if (trainingDays == 4 || trainingDays == 5) {
      activityMultiplier = 1.55;
    } else if (trainingDays == 3) {
      activityMultiplier = 1.375;
    } else if (trainingDays <= 2) {
      activityMultiplier = 1.2;
    }

    final int tdee = (bmr * activityMultiplier).round();

    // 3. Goal-Specific Partitioning
    final lower = goal.toLowerCase();
    int targetCalories;
    int targetProtein;
    int targetFat;
    int targetCarbs;

    if (lower.contains('fat loss') || lower.contains('cutting') || lower.contains('cut') || lower.contains('deficit')) {
      targetCalories = (tdee * 0.80).round();
      if (targetCalories < 1400) targetCalories = 1400;
      targetProtein = (weightKg * 2.2).round();
      if (targetProtein < 120) targetProtein = 120;
      final fatFromPct = (targetCalories * 0.22 / 9).round();
      final minFat = (weightKg * 0.7).round();
      targetFat = fatFromPct > minFat ? fatFromPct : (minFat > 40 ? minFat : 40);
      final remainingCals = targetCalories - (targetProtein * 4 + targetFat * 9);
      targetCarbs = (remainingCals / 4).round();
      if (targetCarbs < 50) targetCarbs = 50;
      targetCalories = targetProtein * 4 + targetCarbs * 4 + targetFat * 9;
    } else if (lower.contains('lean') || lower.contains('bulk') || lower.contains('muscle') || lower.contains('hypertrophy')) {
      targetCalories = (tdee * 1.10).round();
      targetProtein = (weightKg * 2.0).round();
      if (targetProtein < 120) targetProtein = 120;
      final fatFromPct = (targetCalories * 0.25 / 9).round();
      final minFat = (weightKg * 0.8).round();
      targetFat = fatFromPct > minFat ? fatFromPct : (minFat > 50 ? minFat : 50);
      final remainingCals = targetCalories - (targetProtein * 4 + targetFat * 9);
      targetCarbs = (remainingCals / 4).round();
      if (targetCarbs < 100) targetCarbs = 100;
      targetCalories = targetProtein * 4 + targetCarbs * 4 + targetFat * 9;
    } else if (lower.contains('athletic') || lower.contains('performance') || lower.contains('endurance') || lower.contains('sport')) {
      targetCalories = (tdee * 1.08).round();
      targetProtein = (weightKg * 1.9).round();
      if (targetProtein < 120) targetProtein = 120;
      targetFat = (targetCalories * 0.20 / 9).round();
      if (targetFat < 45) targetFat = 45;
      final remainingCals = targetCalories - (targetProtein * 4 + targetFat * 9);
      targetCarbs = (remainingCals / 4).round();
      if (targetCarbs < 120) targetCarbs = 120;
      targetCalories = targetProtein * 4 + targetCarbs * 4 + targetFat * 9;
    } else {
      // Maintenance / General / Custom
      targetCalories = tdee;
      targetProtein = (weightKg * 1.8).round();
      if (targetProtein < 110) targetProtein = 110;
      targetFat = (targetCalories * 0.25 / 9).round();
      if (targetFat < 45) targetFat = 45;
      final remainingCals = targetCalories - (targetProtein * 4 + targetFat * 9);
      targetCarbs = (remainingCals / 4).round();
      if (targetCarbs < 80) targetCarbs = 80;
      targetCalories = targetProtein * 4 + targetCarbs * 4 + targetFat * 9;
    }

    final int targetFiber = (targetCalories * 0.014).round().clamp(25, 45);
    final double targetWater = (weightKg * 0.04 < 3.0 ? 3.0 : ((weightKg * 0.04 * 10).round() / 10));

    _caloriesController.text = targetCalories.toString();
    _proteinController.text = targetProtein.toString();
    _carbsController.text = targetCarbs.toString();
    _fatController.text = targetFat.toString();
    _fiberController.text = targetFiber.toString();
    _waterController.text = targetWater.toStringAsFixed(1);
  }

  @override
  void dispose() {
    _clientSearchController.dispose();
    _splitSearchController.dispose();
    _exclusionsController.dispose();
    _preferredController.dispose();
    _avoidController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _fiberController.dispose();
    _waterController.dispose();
    super.dispose();
  }

  void _onClientSelected(Map<String, String> client) {
    setState(() {
      _selectedClientId = client['clientId'] ?? client['id'];
      _selectedClientName = client['name'] ?? 'Athlete';
      _selectedClientData = Map<String, String>.from(client);
      _loadClientData();
      _errorMessage = null;
    });
  }

  Future<void> _handleGenerateProposal() async {
    if (_selectedClientId == null || _selectedClientId!.isEmpty) {
      setState(() => _errorMessage = 'Please select a client in Step 1 first.');
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      final isWorkout = _selectedPlanType == AiProposalType.workout;
      final proposal = await widget.aiCoachRepository.generatePlanProposal(
        clientIdentifier: _selectedClientId!,
        clientName: _selectedClientName,
        planType: isWorkout ? 'WORKOUT' : 'DIET',
        conversationId: widget.conversationId,
        workoutConfig: isWorkout
            ? {
                'splitKey': _selectedSplit.key,
                'splitName': _selectedSplit.displayName,
                'daysPerWeek': _daysPerWeek,
                'weekdaySchedule': _selectedWeekdays.toList(),
                'primaryGoal': _primaryGoal,
                'trainingExperience': _trainingExperience,
                'equipment': _equipment,
                'sessionDurationMinutes': _sessionDurationMinutes,
                'focusMuscles': _focusMuscles.toList(),
                'weakPoints': _weakPoints.toList(),
                'injuryExclusions': _exclusionsController.text.trim().isNotEmpty
                    ? [_exclusionsController.text.trim()]
                    : [],
                'preferredExercises': _preferredController.text.trim().isNotEmpty
                    ? [_preferredController.text.trim()]
                    : [],
                'exercisesToAvoid': _avoidController.text.trim().isNotEmpty
                    ? [_avoidController.text.trim()]
                    : [],
              }
            : null,
        dietConfig: !isWorkout
            ? {
                'planKind': _isMacroOnly ? 'MACRO_ONLY' : 'DIET_PLAN',
                'primaryGoal': _dietGoal,
                'dailyCalories': int.tryParse(_caloriesController.text) ?? 2000,
                'protein': int.tryParse(_proteinController.text) ?? 150,
                'carbohydrates': int.tryParse(_carbsController.text) ?? 200,
                'fat': int.tryParse(_fatController.text) ?? 55,
                'fiber': int.tryParse(_fiberController.text) ?? 30,
                'waterTargetLiters': double.tryParse(_waterController.text) ?? 3.5,
                'dietaryPreferences': _dietaryPreferences.toList(),
                'mealsPerDay': _mealsPerDay,
              }
            : null,
      );

      if (!mounted) return;

      if (proposal != null) {
        Navigator.of(context).pop(proposal);
        if (widget.onProposalCreated != null) {
          widget.onProposalCreated!(proposal);
        }
      } else {
        setState(() {
          _isGenerating = false;
          _errorMessage = 'Could not generate proposal. Please verify the configuration.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _errorMessage = 'Error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppColors.primaryRed, width: 1.5)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          _buildStepIndicator(),
          if (_errorMessage != null) _buildErrorBanner(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: _buildCurrentStepContent(),
            ),
          ),
          _buildBottomActionButtons(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryRed.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.tune, color: AppColors.primaryRed, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PLAN CONFIGURATION ENGINE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  '3-Step AI Prescription & Verification Pipeline',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.surfaceElevated,
      child: Row(
        children: [
          _buildStepChip(1, '1. Client', Icons.person),
          const SizedBox(width: 4),
          const Expanded(child: Divider(color: AppColors.border, indent: 4, endIndent: 4)),
          const SizedBox(width: 4),
          _buildStepChip(2, '2. Plan', Icons.category),
          const SizedBox(width: 4),
          const Expanded(child: Divider(color: AppColors.border, indent: 4, endIndent: 4)),
          const SizedBox(width: 4),
          _buildStepChip(3, '3. Config', Icons.settings),
        ],
      ),
    );
  }

  Widget _buildStepChip(int step, String label, IconData icon) {
    final isActive = _currentStep == step;
    final isDone = _currentStep > step;

    return InkWell(
      onTap: () {
        if (step < _currentStep || (_currentStep == 1 && _selectedClientId != null)) {
          setState(() => _currentStep = step);
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? AppColors.primaryRed
                  : (isDone ? AppColors.statusGreen : AppColors.surfaceCard),
              border: Border.all(
                color: isActive ? AppColors.primaryRed : AppColors.border,
                width: 1.5,
              ),
            ),
            child: Center(
              child: isDone
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : Text(
                      '$step',
                      style: TextStyle(
                        color: isActive ? Colors.white : AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : (isDone ? Colors.white70 : AppColors.textTertiary),
              fontSize: 11,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.primaryRed.withOpacity(0.15),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.primaryRed, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 1:
        return _buildStep1ClientSelection();
      case 2:
        return _buildStep2PlanTypeSelection();
      case 3:
      default:
        return _selectedPlanType == AiProposalType.workout
            ? _buildStep3WorkoutConfiguration()
            : _buildStep3DietConfiguration();
    }
  }

  // ==========================================
  // STEP 1: SELECT CLIENT & ASSESSMENT PREVIEW
  // ==========================================
  Widget _buildStep1ClientSelection() {
    final clients = _getAllClients();
    final filtered = clients.where((c) {
      final query = _clientSearchController.text.toLowerCase();
      if (query.isEmpty) return true;
      final name = (c['name'] ?? '').toLowerCase();
      final id = (c['clientId'] ?? c['id'] ?? '').toLowerCase();
      return name.contains(query) || id.contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'STEP 1: SELECT ATHLETE',
          style: TextStyle(color: AppColors.primaryRed, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
        const SizedBox(height: 4),
        const Text(
          'Choose the target client to load their real assessment, training level, injuries, and available equipment.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 14),

        // Search bar
        TextField(
          key: const Key('admin_client_search_input'),
          controller: _clientSearchController,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Search athlete by name or AXG ID...',
            hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
            prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 18),
            filled: true,
            fillColor: AppColors.surfaceCard,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),

        // Client List selection chips / tiles
        Container(
          constraints: const BoxConstraints(maxHeight: 180),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: filtered.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No athletes match search query.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  separatorBuilder: (ctx, idx) => const Divider(color: AppColors.border, height: 1),
                  itemBuilder: (ctx, i) {
                    final c = filtered[i];
                    final cId = c['clientId'] ?? c['id'] ?? '';
                    final cName = c['name'] ?? 'Athlete';
                    final isSelected = _selectedClientId == cId;

                    return Material(
                      color: Colors.transparent,
                      child: ListTile(
                        dense: true,
                        selected: isSelected,
                        selectedTileColor: AppColors.primaryRed.withOpacity(0.12),
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: isSelected ? AppColors.primaryRed : AppColors.surfaceElevated,
                          child: Text(
                            cName.isNotEmpty ? cName[0].toUpperCase() : 'A',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(cName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text('${c['primaryGoal'] ?? 'General'} • ${c['fitnessLevel'] ?? 'Intermediate'}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text(cId, style: const TextStyle(color: AppColors.primaryRed, fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.check_circle, color: AppColors.primaryRed, size: 16),
                            ],
                          ],
                        ),
                        onTap: () => _onClientSelected(c),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 16),

        // Loaded Client Assessment Overview Card
        if (_selectedClientId != null) _buildSelectedAssessmentOverviewCard(),
      ],
    );
  }

  Widget _buildSelectedAssessmentOverviewCard() {
    final client = _selectedClientData;
    final name = client['name'] ?? _selectedClientName;
    final id = client['clientId'] ?? client['id'] ?? _selectedClientId ?? '';
    final goal = client['primaryGoal'] ?? 'General Fitness';
    final level = client['fitnessLevel'] ?? 'Intermediate';
    final days = client['trainingDaysPerWeek'] ?? '4';
    final injury = client['hasCurrentInjury'] == 'true' ? client['injuryAreas'] ?? 'Restriction noted' : null;
    final equipment = client['equipmentAccess'] ?? 'Full Gym Equipment';
    final weight = client['weightKg'] != null ? '${client['weightKg']} kg' : 'Baseline';
    final height = client['heightCm'] != null ? '${client['heightCm']} cm' : 'Baseline';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryRed.withOpacity(0.4), width: 1.2),
        gradient: LinearGradient(
          colors: [
            AppColors.primaryRed.withOpacity(0.08),
            AppColors.surfaceCard,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            runSpacing: 4,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.badge_outlined, color: AppColors.primaryRed, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'LOADED ATHLETE ASSESSMENT PROFILE',
                    style: TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.w900, fontSize: 11),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(id, style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace')),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildBadge('Goal', goal, Icons.flag_outlined),
              _buildBadge('Level', level, Icons.trending_up),
              _buildBadge('Frequency', '$days days/wk', Icons.calendar_today_outlined),
              _buildBadge('Metrics', '$weight • $height', Icons.monitor_weight_outlined),
              _buildBadge('Equipment', equipment, Icons.fitness_center),
            ],
          ),
          if (injury != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.amber.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Injury / Restriction: $injury',
                      style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadge(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.primaryRed),
          const SizedBox(width: 4),
          Text('$title: ', style: const TextStyle(color: AppColors.textTertiary, fontSize: 10)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ==========================================
  // STEP 2: SELECT PLAN TYPE (EXACTLY TWO)
  // ==========================================
  Widget _buildStep2PlanTypeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'STEP 2: SELECT PLAN TYPE',
          style: TextStyle(color: AppColors.primaryRed, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
        const SizedBox(height: 4),
        const Text(
          'Provide exactly one plan proposal type to generate and stage for admin review.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 20),

        // Option 1: AI Workout Proposal
        _buildPlanTypeOptionCard(
          key: const Key('plan_type_workout_card'),
          type: AiProposalType.workout,
          title: 'AI Workout Proposal',
          subtitle: 'Personalized training split, session schedule, exercise selection, sets, reps, and RIR progression.',
          icon: Icons.fitness_center,
          color: AppColors.primaryRed,
          badgeText: '20 Supported Splits',
        ),
        const SizedBox(height: 14),

        // Option 2: AI Diet / Macro Proposal
        _buildPlanTypeOptionCard(
          key: const Key('plan_type_diet_card'),
          type: AiProposalType.diet,
          title: 'AI Diet / Macro Proposal',
          subtitle: 'Full meal-by-meal food plan with portion weights in grams or flexible daily calorie/macro targets.',
          icon: Icons.restaurant_menu,
          color: AppColors.statusGreen,
          badgeText: 'Full Diet or Macro-Only',
        ),
      ],
    );
  }

  Widget _buildPlanTypeOptionCard({
    required Key key,
    required AiProposalType type,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String badgeText,
  }) {
    final isSelected = _selectedPlanType == type;

    return InkWell(
      key: key,
      onTap: () {
        setState(() => _selectedPlanType = type);
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.12) : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withOpacity(0.2), blurRadius: 10, spreadRadius: 1)]
              : [],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? color : color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isSelected ? Colors.white : color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Radio<AiProposalType>(
              value: type,
              groupValue: _selectedPlanType,
              activeColor: color,
              onChanged: (val) {
                if (val != null) setState(() => _selectedPlanType = val);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // STEP 3: CONFIGURE PLAN — WORKOUT (20 SPLITS)
  // ==========================================
  Widget _buildStep3WorkoutConfiguration() {
    final filteredSplits = allWorkoutSplits.where((s) {
      if (_splitSearchQuery.isEmpty) return true;
      final q = _splitSearchQuery.toLowerCase();
      return s.displayName.toLowerCase().contains(q) ||
          s.category.toLowerCase().contains(q) ||
          s.description.toLowerCase().contains(q);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'STEP 3: CONFIGURE WORKOUT PLAN',
          style: TextStyle(color: AppColors.primaryRed, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
        const SizedBox(height: 4),
        Text(
          'Configuring workout proposal for $_selectedClientName. Selected split acts as an adaptive template.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 14),

        // Searchable Split Selector
        const Text(
          'WORKOUT SPLIT TEMPLATE (20 SUPPORTED)',
          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        TextField(
          key: const Key('admin_split_search_input'),
          controller: _splitSearchController,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Search splits (e.g. Arnold, PPL, Upper/Lower, 5/3/1, Powerlifting)...',
            hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
            prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 18),
            filled: true,
            fillColor: AppColors.surfaceCard,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
          onChanged: (val) {
            setState(() => _splitSearchQuery = val.trim());
          },
        ),
        const SizedBox(height: 8),

        // Split Selector Grid / List
        Container(
          constraints: const BoxConstraints(maxHeight: 180),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: filteredSplits.length,
            separatorBuilder: (ctx, idx) => const Divider(color: AppColors.border, height: 1),
            itemBuilder: (ctx, idx) {
              final split = filteredSplits[idx];
              final isSelected = _selectedSplit.key == split.key;

              return Material(
                color: Colors.transparent,
                child: ListTile(
                  dense: true,
                  selected: isSelected,
                  selectedTileColor: AppColors.primaryRed.withOpacity(0.15),
                  title: Text(
                    split.displayName,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    split.description,
                    style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('${split.defaultDays} d/wk', style: const TextStyle(color: AppColors.primaryRed, fontSize: 10)),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.check, color: AppColors.primaryRed, size: 16),
                      ],
                    ],
                  ),
                  onTap: () {
                    setState(() {
                      _selectedSplit = split;
                      if (_daysPerWeek < split.minDays) _daysPerWeek = split.minDays;
                      if (_daysPerWeek > split.maxDays) _daysPerWeek = split.maxDays;
                    });
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Training Days Per Week
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'TRAINING DAYS PER WEEK:',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            Text(
              '$_daysPerWeek Days',
              style: const TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.w900, fontSize: 14),
            ),
          ],
        ),
        Slider(
          key: const Key('admin_training_days_slider'),
          value: _daysPerWeek.toDouble(),
          min: 2,
          max: 7,
          divisions: 5,
          activeColor: AppColors.primaryRed,
          inactiveColor: AppColors.surfaceElevated,
          onChanged: (val) {
            setState(() {
              _daysPerWeek = val.round();
            });
          },
        ),
        const SizedBox(height: 10),

        // Weekday Schedule Selection
        const Text(
          'WEEKDAY SCHEDULE:',
          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _allWeekdays.map((day) {
            final isChosen = _selectedWeekdays.contains(day);
            return FilterChip(
              label: Text(day, style: TextStyle(fontSize: 11, color: isChosen ? Colors.white : AppColors.textSecondary)),
              selected: isChosen,
              selectedColor: AppColors.primaryRed,
              backgroundColor: AppColors.surfaceCard,
              checkmarkColor: Colors.white,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedWeekdays.add(day);
                  } else {
                    if (_selectedWeekdays.length > 1) {
                      _selectedWeekdays.remove(day);
                    }
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Primary Goal & Experience
        Row(
          children: [
            Expanded(
              child: _buildDropdown(
                label: 'PRIMARY GOAL',
                value: _primaryGoal,
                items: ['Hypertrophy', 'Strength', 'Fat Loss', 'General Fitness', 'Athletic Performance'],
                onChanged: (val) => setState(() => _primaryGoal = val ?? _primaryGoal),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildDropdown(
                label: 'EXPERIENCE',
                value: _trainingExperience,
                items: ['Beginner', 'Intermediate', 'Advanced'],
                onChanged: (val) => setState(() => _trainingExperience = val ?? _trainingExperience),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Equipment & Session Duration
        Row(
          children: [
            Expanded(
              child: _buildDropdown(
                label: 'AVAILABLE EQUIPMENT',
                value: _equipment,
                items: [
                  'Full Commercial Gym',
                  'Barbell & Dumbbells',
                  'Dumbbells & Bench',
                  'Cables & Machines',
                  'Bodyweight / Calisthenics',
                ],
                onChanged: (val) => setState(() => _equipment = val ?? _equipment),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildDropdown(
                label: 'SESSION DURATION',
                value: '$_sessionDurationMinutes min',
                items: ['30 min', '45 min', '50 min', '60 min', '75 min', '90 min'],
                onChanged: (val) {
                  if (val != null) {
                    final mins = int.tryParse(val.replaceAll(' min', ''));
                    if (mins != null) setState(() => _sessionDurationMinutes = mins);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Focus Muscles / Weak Points
        const Text(
          'FOCUS MUSCLES & WEAK POINTS (OPTIONAL):',
          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _allMuscleGroups.map((muscle) {
            final isFocus = _focusMuscles.contains(muscle);
            return FilterChip(
              label: Text(muscle, style: TextStyle(fontSize: 11, color: isFocus ? Colors.white : AppColors.textSecondary)),
              selected: isFocus,
              selectedColor: AppColors.glowRed,
              backgroundColor: AppColors.surfaceCard,
              onSelected: (sel) {
                setState(() {
                  if (sel) {
                    _focusMuscles.add(muscle);
                  } else {
                    _focusMuscles.remove(muscle);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 14),

        // Exercise Exclusions (Injuries / Restrictions)
        TextField(
          controller: _exclusionsController,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: const InputDecoration(
            labelText: 'Exercise Exclusions / Injury Restrictions',
            labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            hintText: 'e.g. Knee discomfort — avoid deep squats or jump lunges',
            hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 11),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.primaryRed)),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 16),

        // Live Generated Schedule Preview
        _buildGeneratedSchedulePreview(),
      ],
    );
  }

  Widget _buildGeneratedSchedulePreview() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.preview_outlined, color: Colors.lightBlueAccent, size: 16),
              const SizedBox(width: 6),
              const Text(
                'LIVE SCHEDULE PREVIEW',
                style: TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold, fontSize: 11),
              ),
              const Spacer(),
              Text(
                '${_selectedSplit.displayName} (${_daysPerWeek}d)',
                style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 8),
          Text(
            'The backend engine will dynamically program balanced compound and isolation movements across $_daysPerWeek sessions, fully respecting recovery windows and target muscle groups.',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // STEP 3: CONFIGURE PLAN — DIET / MACROS
  // ==========================================
  Widget _buildStep3DietConfiguration() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'STEP 3: CONFIGURE DIET & MACRO PLAN',
          style: TextStyle(color: AppColors.statusGreen, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
        const SizedBox(height: 4),
        Text(
          'Configuring nutrition proposal for $_selectedClientName. Toggle between structured meals or macro-only targets.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 14),

        // Sub-Plan Type: Full Diet Plan vs Macro-Only Plan
        Row(
          children: [
            Expanded(
              child: _buildSubPlanToggle(
                key: const Key('toggle_full_diet_plan'),
                label: 'Full Meal-by-Meal Plan',
                subtitle: 'Structured meals, food weights in grams, timings',
                isSelected: !_isMacroOnly,
                onTap: () => setState(() => _isMacroOnly = false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSubPlanToggle(
                key: const Key('toggle_macro_only_plan'),
                label: 'Macro-Only Plan',
                subtitle: 'Daily macro targets without fixed meals',
                isSelected: _isMacroOnly,
                onTap: () => setState(() => _isMacroOnly = true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_selectedClientData['weightKg'] == null || _selectedClientData['weightKg']!.isEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.warningYellow.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.warningYellow.withOpacity(0.5)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.warningYellow, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Client biometrics missing (weight/height). Standard reference baseline (70kg, 175cm) used. Update assessment in Athlete Profile.',
                    style: TextStyle(color: AppColors.warningYellow, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Primary Nutrition Goal
        _buildDropdown(
          label: 'PRIMARY NUTRITION GOAL',
          value: _dietGoal,
          items: ['Fat Loss', 'Lean Muscle Gain / Bulking', 'Maintenance', 'Athletic Performance'],
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _dietGoal = val;
                _recalculateDietMacrosForGoal(val);
              });
            }
          },
        ),
        const SizedBox(height: 14),

        // Daily Calories & Protein
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('diet_calories_input'),
                controller: _caloriesController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Daily Calories (kcal)',
                  labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.statusGreen)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                key: const Key('diet_protein_input'),
                controller: _proteinController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Protein (g)',
                  labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.statusGreen)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Carbs, Fat, Fiber, Water
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('diet_carbs_input'),
                controller: _carbsController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Carbs (g)',
                  labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.statusGreen)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                key: const Key('diet_fat_input'),
                controller: _fatController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Fat (g)',
                  labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.statusGreen)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _waterController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Water (L)',
                  labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.statusGreen)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Dietary Preferences / Restrictions
        const Text(
          'DIETARY PREFERENCES & ALLERGIES:',
          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _allDietaryPreferences.map((pref) {
            final isChosen = _dietaryPreferences.contains(pref);
            return FilterChip(
              label: Text(pref, style: TextStyle(fontSize: 11, color: isChosen ? Colors.white : AppColors.textSecondary)),
              selected: isChosen,
              selectedColor: AppColors.statusGreen,
              backgroundColor: AppColors.surfaceCard,
              onSelected: (sel) {
                setState(() {
                  if (sel) {
                    _dietaryPreferences.add(pref);
                  } else {
                    _dietaryPreferences.remove(pref);
                  }
                });
              },
            );
          }).toList(),
        ),

        if (!_isMacroOnly) ...[
          const SizedBox(height: 14),
          _buildDropdown(
            label: 'STRUCTURED MEALS PER DAY',
            value: '$_mealsPerDay Meals',
            items: ['3 Meals', '4 Meals', '5 Meals', '6 Meals'],
            onChanged: (val) {
              if (val != null) {
                final m = int.tryParse(val.replaceAll(' Meals', ''));
                if (m != null) setState(() => _mealsPerDay = m);
              }
            },
          ),
        ],
      ],
    );
  }

  Widget _buildSubPlanToggle({
    required Key key,
    required String label,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.statusGreen.withOpacity(0.12) : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.statusGreen : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  size: 14,
                  color: isSelected ? AppColors.statusGreen : AppColors.textTertiary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    final effectiveValue = items.contains(value) ? value : items.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: effectiveValue,
              isExpanded: true,
              dropdownColor: AppColors.surfaceCard,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              items: items.map((it) => DropdownMenuItem(value: it, child: Text(it))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // BOTTOM NAVIGATION & SUBMISSION BUTTONS
  // ==========================================
  Widget _buildBottomActionButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (_currentStep > 1) ...[
            OutlinedButton(
              key: const Key('admin_plan_config_back_button'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onPressed: _isGenerating ? null : () => setState(() => _currentStep--),
              child: const Text('Back'),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: _currentStep < 3
                ? ElevatedButton.icon(
                    key: const Key('admin_plan_config_continue_button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: Text(
                      _currentStep == 1 ? 'Continue to Plan Type' : 'Continue to Configuration',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: () {
                      if (_currentStep == 1 && (_selectedClientId == null || _selectedClientId!.isEmpty)) {
                        setState(() => _errorMessage = 'Please select an athlete first.');
                        return;
                      }
                      setState(() {
                        _errorMessage = null;
                        _currentStep++;
                      });
                    },
                  )
                : ElevatedButton.icon(
                    key: const Key('admin_generate_plan_proposal_button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedPlanType == AiProposalType.workout
                          ? AppColors.primaryRed
                          : AppColors.statusGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: _isGenerating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome, size: 16),
                    label: Text(
                      _isGenerating
                          ? 'Generating Plan...'
                          : 'Generate ${_selectedPlanType == AiProposalType.workout ? 'Workout' : 'Diet'} Proposal (PENDING)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: _isGenerating ? null : _handleGenerateProposal,
                  ),
          ),
        ],
      ),
    );
  }
}
