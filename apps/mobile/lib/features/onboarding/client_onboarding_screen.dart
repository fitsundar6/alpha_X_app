import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/core/widgets/alpha_x_logo.dart';

/// The official Alpha X Gym 10-Step Fitness Assessment & Onboarding Screen.
///
/// Features:
/// 1. Professional Multi-Step Form showing "Step X of 10" with BACK and NEXT buttons.
/// 2. Header: "WELCOME TO ALPHA X GYM" "Let's complete your fitness assessment..."
/// 3. Step 1: Fitness Level (BEGINNER, INTERMEDIATE, ADVANCED, RETURNING).
/// 4. Step 2: Primary Goal & Optional Secondary Goal.
/// 5. Step 3: Body Information (Weight [kg], Height [cm], Age, Gender).
/// 6. Step 4: Training Experience.
/// 7. Step 5: Training Availability (Days per week & preferred days).
/// 8. Step 6: Current Injury / Pain Screening with medical safety notice.
/// 9. Step 7: Previous Surgery Screening.
/// 10. Step 8: Daily Activity Level outside the gym.
/// 11. Step 9: Sleep Hours & Daily Step Count.
/// 12. Step 10: Training Preferences (Multi-select).
/// 13. Step 11: Final Assessment Review with EDIT and SUBMIT ASSESSMENT buttons.
/// 14. Progressive auto-save after each step so client never loses progress.
class ClientOnboardingScreen extends StatefulWidget {
  final int initialStep;

  const ClientOnboardingScreen({
    super.key,
    this.initialStep = 1,
  });

  @override
  State<ClientOnboardingScreen> createState() => _ClientOnboardingScreenState();
}

class _ClientOnboardingScreenState extends State<ClientOnboardingScreen> {
  final _authService = AuthService();
  late int _currentStep;
  bool _isSaving = false;
  String? _validationError;

  // Controllers
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _ageController = TextEditingController();
  final _stepsController = TextEditingController();
  final _injuryDescController = TextEditingController();
  final _surgeryAreaController = TextEditingController();
  final _surgeryDetailsController = TextEditingController();
  final _surgeryYearController = TextEditingController();
  final _surgeryLimitationsController = TextEditingController();

  // Assessment State
  String? _fitnessLevel;
  String? _primaryGoal;
  String? _secondaryGoal;
  String? _gender = 'Not specified';
  String? _trainingExperience;
  int _trainingDaysPerWeek = 4;
  final Set<String> _preferredDays = {};
  bool _hasCurrentInjury = false;
  final Set<String> _selectedInjuryAreas = {};
  bool _hasPreviousSurgery = false;
  String? _activityLevel;
  String? _sleepHours;
  int _dailySteps = 6000;
  final Set<String> _trainingPreferences = {};

  final int _totalAssessmentSteps = 10;
  final int _reviewStep = 11;

  @override
  void initState() {
    super.initState();
    final savedStep = _authService.onboardingStep;
    _currentStep = (widget.initialStep > 1)
        ? widget.initialStep
        : (savedStep > 0 && savedStep <= _totalAssessmentSteps ? savedStep : 1);

    _populateFromExistingProfile();
  }

  void _populateFromExistingProfile() {
    final p = _authService.clientProfile;
    if (p.isNotEmpty) {
      _fitnessLevel = p['fitnessLevel']?.toString();
      _primaryGoal = p['primaryGoal']?.toString();
      _secondaryGoal = p['secondaryGoal']?.toString();
      if (p['weightKg'] != null) _weightController.text = p['weightKg'].toString();
      if (p['heightCm'] != null) _heightController.text = p['heightCm'].toString();
      if (p['age'] != null) _ageController.text = p['age'].toString();
      if (p['gender'] != null) _gender = p['gender'].toString();
      _trainingExperience = p['trainingExperience']?.toString();
      if (p['trainingDaysPerWeek'] != null) {
        _trainingDaysPerWeek = int.tryParse(p['trainingDaysPerWeek'].toString()) ?? 4;
      }
      if (p['preferredDays'] is List) {
        _preferredDays.addAll((p['preferredDays'] as List).map((e) => e.toString()));
      }
      _hasCurrentInjury = p['hasCurrentInjury'] == true;
      if (p['injuryAreas'] is List) {
        _selectedInjuryAreas.addAll((p['injuryAreas'] as List).map((e) => e.toString()));
      }
      if (p['injuryDescription'] != null) {
        _injuryDescController.text = p['injuryDescription'].toString();
      }
      _hasPreviousSurgery = p['hasPreviousSurgery'] == true;
      if (p['surgeryDetails'] != null) {
        _surgeryDetailsController.text = p['surgeryDetails'].toString();
      }
      _activityLevel = p['activityLevel']?.toString();
      _sleepHours = p['sleepHours']?.toString();
      if (p['dailySteps'] != null) {
        _dailySteps = int.tryParse(p['dailySteps'].toString()) ?? 6000;
        _stepsController.text = _dailySteps.toString();
      } else {
        _stepsController.text = '6000';
      }
      if (p['trainingPreferences'] is List) {
        _trainingPreferences.addAll((p['trainingPreferences'] as List).map((e) => e.toString()));
      }
    } else {
      _stepsController.text = '6000';
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    _stepsController.dispose();
    _injuryDescController.dispose();
    _surgeryAreaController.dispose();
    _surgeryDetailsController.dispose();
    _surgeryYearController.dispose();
    _surgeryLimitationsController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _collectCurrentData() {
    final weight = double.tryParse(_weightController.text.trim());
    final height = double.tryParse(_heightController.text.trim());
    final age = int.tryParse(_ageController.text.trim());
    final steps = int.tryParse(_stepsController.text.trim()) ?? _dailySteps;

    String? surgeryDetailsCombined;
    if (_hasPreviousSurgery) {
      final parts = <String>[];
      if (_surgeryAreaController.text.isNotEmpty) parts.add('Area: ${_surgeryAreaController.text.trim()}');
      if (_surgeryDetailsController.text.isNotEmpty) parts.add('Details: ${_surgeryDetailsController.text.trim()}');
      if (_surgeryYearController.text.isNotEmpty) parts.add('Year: ${_surgeryYearController.text.trim()}');
      if (_surgeryLimitationsController.text.isNotEmpty) parts.add('Limitations: ${_surgeryLimitationsController.text.trim()}');
      surgeryDetailsCombined = parts.isNotEmpty ? parts.join(' | ') : 'Reported';
    }

    return {
      'fitnessLevel': _fitnessLevel,
      'primaryGoal': _primaryGoal,
      'secondaryGoal': _secondaryGoal,
      'weightKg': weight,
      'heightCm': height,
      'age': age,
      'gender': _gender,
      'trainingExperience': _trainingExperience,
      'trainingDaysPerWeek': _trainingDaysPerWeek,
      'preferredDays': _preferredDays.toList(),
      'hasCurrentInjury': _hasCurrentInjury,
      'injuryAreas': _selectedInjuryAreas.toList(),
      'injuryDescription': _injuryDescController.text.trim().isNotEmpty ? _injuryDescController.text.trim() : null,
      'hasPreviousSurgery': _hasPreviousSurgery,
      'surgeryDetails': surgeryDetailsCombined,
      'activityLevel': _activityLevel,
      'sleepHours': _sleepHours,
      'dailySteps': steps,
      'trainingPreferences': _trainingPreferences.toList(),
    };
  }

  bool _validateCurrentStep() {
    setState(() => _validationError = null);

    switch (_currentStep) {
      case 1:
        if (_fitnessLevel == null) {
          setState(() => _validationError = 'Please select your current fitness level to continue.');
          return false;
        }
        return true;

      case 2:
        if (_primaryGoal == null) {
          setState(() => _validationError = 'Please select your primary fitness goal.');
          return false;
        }
        return true;

      case 3:
        final weight = double.tryParse(_weightController.text.trim());
        final height = double.tryParse(_heightController.text.trim());
        final age = int.tryParse(_ageController.text.trim());

        if (weight == null || weight <= 0 || weight < 20 || weight > 350) {
          setState(() => _validationError = 'Please enter a valid weight between 20 kg and 350 kg.');
          return false;
        }
        if (height == null || height <= 0 || height < 50 || height > 280) {
          setState(() => _validationError = 'Please enter a valid height between 50 cm and 280 cm.');
          return false;
        }
        if (age == null || age <= 0 || age < 10 || age > 120) {
          setState(() => _validationError = 'Please enter a valid whole age between 10 and 120.');
          return false;
        }
        return true;

      case 4:
        if (_trainingExperience == null) {
          setState(() => _validationError = 'Please select your training experience.');
          return false;
        }
        return true;

      case 5:
        if (_trainingDaysPerWeek < 2 || _trainingDaysPerWeek > 7) {
          setState(() => _validationError = 'Please select between 2 and 7 training days per week.');
          return false;
        }
        return true;

      case 6:
        if (_hasCurrentInjury && _selectedInjuryAreas.isEmpty) {
          setState(() => _validationError = 'Please select at least one affected area or choose NO if you have no injury.');
          return false;
        }
        return true;

      case 7:
        if (_hasPreviousSurgery && _surgeryAreaController.text.trim().isEmpty && _surgeryDetailsController.text.trim().isEmpty) {
          setState(() => _validationError = 'Please provide details of previous surgery or choose NO.');
          return false;
        }
        return true;

      case 8:
        if (_activityLevel == null) {
          setState(() => _validationError = 'Please select your daily activity level outside the gym.');
          return false;
        }
        return true;

      case 9:
        if (_sleepHours == null) {
          setState(() => _validationError = 'Please select your average nightly sleep duration.');
          return false;
        }
        final steps = int.tryParse(_stepsController.text.trim());
        if (steps == null || steps < 0) {
          setState(() => _validationError = 'Please enter a valid non-negative whole number for daily steps.');
          return false;
        }
        return true;

      case 10:
        if (_trainingPreferences.isEmpty) {
          setState(() => _validationError = 'Please select at least one training preference.');
          return false;
        }
        return true;

      default:
        return true;
    }
  }

  Future<void> _handleNext() async {
    if (!_validateCurrentStep()) return;

    setState(() => _isSaving = true);
    final data = _collectCurrentData();

    try {
      await _authService.saveOnboardingStep(
        data,
        step: _currentStep < _reviewStep ? _currentStep + 1 : _reviewStep,
      );
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isSaving = false;
        if (_currentStep < _reviewStep) {
          _currentStep++;
        }
      });
    }
  }

  void _handleBack() {
    if (_currentStep > 1) {
      setState(() {
        _validationError = null;
        _currentStep--;
      });
    }
  }

  Future<void> _handleSubmitAssessment() async {
    setState(() {
      _isSaving = true;
      _validationError = null;
    });
    final data = _collectCurrentData();

    try {
      await _authService.saveOnboardingStep(
        data,
        step: _totalAssessmentSteps,
        isComplete: true,
      );

      if (!mounted) return;
      if (_authService.hasPendingAssessmentSync) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.orange.shade800,
            content: const Text('Saved offline — will sync automatically when you\'re online.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Fitness Assessment completed and saved to Alpha X Gym server! Welcome to Alpha X Gym.'),
          ),
        );
      }

      // Navigate to Client Dashboard
      Navigator.of(context).pushReplacementNamed('/dashboard');
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _validationError = 'Could not save your assessment. Please try again.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.primaryRed,
            content: Text('Could not save your assessment. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentStep > 1
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
                onPressed: _isSaving ? null : _handleBack,
              )
            : null,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AlphaXLogo.appBar(size: 26),
            const SizedBox(width: 8),
            Text(
              _currentStep == _reviewStep
                  ? 'FINAL REVIEW'
                  : 'STEP $_currentStep OF $_totalAssessmentSteps',
              style: const TextStyle(
                color: AppColors.primaryRed,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                fontSize: 14,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Bar
            LinearProgressIndicator(
              value: (_currentStep) / _reviewStep,
              backgroundColor: AppColors.surfaceCard,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryRed),
              minHeight: 4,
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Welcome & Motivation Banner (Steps 1-10)
                    if (_currentStep <= _totalAssessmentSteps) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.primaryRed.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryRed,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _authService.currentClientId,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'WELCOME TO ALPHA X GYM',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              "Let's complete your fitness assessment so we can understand your goals, experience and training needs.",
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Validation Banner
                    if (_validationError != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryRed.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primaryRed.withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: AppColors.primaryRed, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _validationError!,
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Step Dynamic Content
                    _buildStepContent(),
                  ],
                ),
              ),
            ),

            // Persistent Footer Navigation Bar (BACK / NEXT / SUBMIT)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: AppColors.surfaceCard,
                border: Border(top: BorderSide(color: AppColors.border, width: 1)),
              ),
              child: Row(
                children: [
                  if (_currentStep > 1) ...[
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isSaving ? null : _handleBack,
                        child: const Text('BACK', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryRed,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isSaving
                          ? null
                          : (_currentStep == _reviewStep ? _handleSubmitAssessment : _handleNext),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              _currentStep == _reviewStep ? 'SUBMIT ASSESSMENT' : 'NEXT',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.8),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 1:
        return _buildStep1FitnessLevel();
      case 2:
        return _buildStep2PrimaryGoal();
      case 3:
        return _buildStep3BodyInformation();
      case 4:
        return _buildStep4TrainingExperience();
      case 5:
        return _buildStep5TrainingAvailability();
      case 6:
        return _buildStep6CurrentInjury();
      case 7:
        return _buildStep7PreviousSurgery();
      case 8:
        return _buildStep8DailyActivity();
      case 9:
        return _buildStep9SleepAndSteps();
      case 10:
        return _buildStep10TrainingPreferences();
      case 11:
        return _buildStep11Review();
      default:
        return const SizedBox.shrink();
    }
  }

  // --- STEP 1: FITNESS LEVEL ---
  Widget _buildStep1FitnessLevel() {
    final levels = [
      {'key': 'BEGINNER', 'title': 'BEGINNER', 'desc': 'New to structured exercise or little recent training experience.'},
      {'key': 'INTERMEDIATE', 'title': 'INTERMEDIATE', 'desc': 'Exercises regularly and has experience with structured training.'},
      {'key': 'ADVANCED', 'title': 'ADVANCED', 'desc': 'Several years of consistent training experience.'},
      {'key': 'RETURNING', 'title': 'RETURNING', 'desc': 'Previously trained but took a long break and is returning to fitness.'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader('FITNESS LEVEL', 'How would you describe your current fitness level?'),
        const SizedBox(height: 16),
        ...levels.map((lvl) {
          final isSelected = _fitnessLevel?.toUpperCase() == lvl['key'];
          return _buildChoiceCard(
            title: lvl['title']!,
            description: lvl['desc']!,
            isSelected: isSelected,
            onTap: () => setState(() => _fitnessLevel = lvl['key']!.toLowerCase()),
          );
        }),
      ],
    );
  }

  // --- STEP 2: PRIMARY GOAL ---
  Widget _buildStep2PrimaryGoal() {
    final goals = [
      'Fat Loss',
      'Muscle Gain',
      'Body Recomposition',
      'Build Strength',
      'Weight Gain',
      'General Fitness',
      'Improve Conditioning',
      'Improve Mobility',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader('PRIMARY FITNESS GOAL', 'What is your primary fitness goal?'),
        const SizedBox(height: 16),
        ...goals.map((g) {
          final isSelected = _primaryGoal == g;
          return _buildChoiceCard(
            title: g,
            description: '',
            isSelected: isSelected,
            onTap: () => setState(() => _primaryGoal = g),
          );
        }),
        const SizedBox(height: 16),
        _buildSubHeader('OPTIONAL: SECONDARY GOAL'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: goals.contains(_secondaryGoal) ? _secondaryGoal : null,
          dropdownColor: AppColors.surfaceCard,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          decoration: _inputDecoration('Secondary Goal (Optional)'),
          items: [
            const DropdownMenuItem(value: null, child: Text('None', style: TextStyle(color: AppColors.textSecondary))),
            ...goals.where((g) => g != _primaryGoal).map((g) => DropdownMenuItem(value: g, child: Text(g))),
          ],
          onChanged: (val) => setState(() => _secondaryGoal = val),
        ),
      ],
    );
  }

  // --- STEP 3: BODY INFORMATION ---
  Widget _buildStep3BodyInformation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader('BODY INFORMATION', 'Please enter your current measurements. Required for workout and nutrition planning.'),
        const SizedBox(height: 18),

        // Weight (kg) - Decimal only, letters strictly forbidden
        TextFormField(
          controller: _weightController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
          decoration: _inputDecoration('Current Weight (kg)', hint: 'e.g. 82.5', suffix: 'kg'),
        ),
        const SizedBox(height: 14),

        // Height (cm) - Number only
        TextFormField(
          controller: _heightController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
          decoration: _inputDecoration('Height (cm)', hint: 'e.g. 178', suffix: 'cm'),
        ),
        const SizedBox(height: 14),

        // Age - Integer only, no decimals
        TextFormField(
          controller: _ageController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
          decoration: _inputDecoration('Age', hint: 'e.g. 28', suffix: 'years'),
        ),
        const SizedBox(height: 14),

        // Gender (Optional)
        _buildSubHeader('GENDER (OPTIONAL)'),
        const SizedBox(height: 8),
        Row(
          children: ['Male', 'Female', 'Other', 'Prefer not to say'].map((g) {
            final isSel = _gender == g;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: ChoiceChip(
                  label: Text(g, style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.w800 : FontWeight.w500, color: isSel ? Colors.white : AppColors.textSecondary)),
                  selected: isSel,
                  selectedColor: AppColors.primaryRed,
                  backgroundColor: AppColors.surfaceCard,
                  onSelected: (sel) => setState(() => _gender = g),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- STEP 4: TRAINING EXPERIENCE ---
  Widget _buildStep4TrainingExperience() {
    final expOptions = [
      'New to training',
      'Less than 3 months',
      '3–6 months',
      '6–12 months',
      '1–2 years',
      '2–5 years',
      '5+ years',
      'Returning after a break',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader('TRAINING EXPERIENCE', 'How long have you been training consistently?'),
        const SizedBox(height: 16),
        ...expOptions.map((e) {
          final isSelected = _trainingExperience == e;
          return _buildChoiceCard(
            title: e,
            description: '',
            isSelected: isSelected,
            onTap: () => setState(() => _trainingExperience = e),
          );
        }),
      ],
    );
  }

  // --- STEP 5: TRAINING AVAILABILITY ---
  Widget _buildStep5TrainingAvailability() {
    final daysOfWeek = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader('TRAINING AVAILABILITY', 'How many days can you realistically train each week?'),
        const SizedBox(height: 16),

        // Training days per week (2 - 7)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [2, 3, 4, 5, 6, 7].map((daysCount) {
            final isSelected = _trainingDaysPerWeek == daysCount;
            return GestureDetector(
              onTap: () => setState(() => _trainingDaysPerWeek = daysCount),
              child: Container(
                width: 48,
                height: 52,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primaryRed : AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isSelected ? AppColors.primaryRed : AppColors.border),
                ),
                child: Center(
                  child: Text(
                    daysCount.toString(),
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 22),

        _buildSubHeader('PREFERRED TRAINING DAYS (OPTIONAL)'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: daysOfWeek.map((day) {
            final isSel = _preferredDays.contains(day);
            return FilterChip(
              label: Text(day, style: TextStyle(color: isSel ? Colors.white : AppColors.textSecondary, fontWeight: isSel ? FontWeight.w800 : FontWeight.w500)),
              selected: isSel,
              selectedColor: AppColors.primaryRed,
              backgroundColor: AppColors.surfaceCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: isSel ? AppColors.primaryRed : AppColors.border)),
              onSelected: (sel) {
                setState(() {
                  if (sel) {
                    _preferredDays.add(day);
                  } else {
                    _preferredDays.remove(day);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- STEP 6: CURRENT INJURY / PAIN ---
  Widget _buildStep6CurrentInjury() {
    final areas = [
      'Neck',
      'Shoulder',
      'Elbow',
      'Wrist',
      'Upper Back',
      'Lower Back',
      'Hip',
      'Knee',
      'Ankle',
      'Other',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader('CURRENT INJURY / PAIN', 'Do you currently have any pain, injury, or movement limitation that may affect your training?'),
        const SizedBox(height: 16),

        // YES / NO Toggle
        Row(
          children: [
            Expanded(
              child: _buildChoiceCard(
                title: 'NO',
                description: 'No current pain or movement limitations.',
                isSelected: !_hasCurrentInjury,
                onTap: () => setState(() {
                  _hasCurrentInjury = false;
                  _selectedInjuryAreas.clear();
                  _injuryDescController.clear();
                }),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildChoiceCard(
                title: 'YES',
                description: 'I have an injury or painful area.',
                isSelected: _hasCurrentInjury,
                onTap: () => setState(() => _hasCurrentInjury = true),
              ),
            ),
          ],
        ),

        if (_hasCurrentInjury) ...[
          const SizedBox(height: 18),
          _buildSubHeader('SELECT AFFECTED AREA(S)'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: areas.map((a) {
              final isSel = _selectedInjuryAreas.contains(a);
              return FilterChip(
                label: Text(a, style: TextStyle(color: isSel ? Colors.white : AppColors.textSecondary, fontWeight: isSel ? FontWeight.w800 : FontWeight.w500)),
                selected: isSel,
                selectedColor: AppColors.primaryRed,
                backgroundColor: AppColors.surfaceCard,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: isSel ? AppColors.primaryRed : AppColors.border)),
                onSelected: (sel) {
                  setState(() {
                    if (sel) {
                      _selectedInjuryAreas.add(a);
                    } else {
                      _selectedInjuryAreas.remove(a);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Injury Details (Normal Text keyboard)
          TextFormField(
            controller: _injuryDescController,
            keyboardType: TextInputType.text,
            maxLines: 3,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: _inputDecoration('Injury Details & Movements That Hurt', hint: 'e.g. Pain during overhead press or heavy squats...'),
          ),
        ],

        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.shield_outlined, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Medical Safety: Our trainers use this to design safe alternative exercises. We do not diagnose medical conditions.',
                  style: TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- STEP 7: PREVIOUS SURGERY ---
  Widget _buildStep7PreviousSurgery() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader('PREVIOUS SURGERY', 'Have you had any previous surgery that may affect your training?'),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: _buildChoiceCard(
                title: 'NO',
                description: 'No previous surgeries to report.',
                isSelected: !_hasPreviousSurgery,
                onTap: () => setState(() {
                  _hasPreviousSurgery = false;
                  _surgeryAreaController.clear();
                  _surgeryDetailsController.clear();
                  _surgeryYearController.clear();
                  _surgeryLimitationsController.clear();
                }),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildChoiceCard(
                title: 'YES',
                description: 'I have had previous surgery.',
                isSelected: _hasPreviousSurgery,
                onTap: () => setState(() => _hasPreviousSurgery = true),
              ),
            ),
          ],
        ),

        if (_hasPreviousSurgery) ...[
          const SizedBox(height: 18),
          _buildSubHeader('SURGERY INFORMATION'),
          const SizedBox(height: 10),

          // Body Area
          TextFormField(
            controller: _surgeryAreaController,
            keyboardType: TextInputType.text,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: _inputDecoration('Body Area (e.g. Left Knee, Shoulder)'),
          ),
          const SizedBox(height: 10),

          // Surgery Details
          TextFormField(
            controller: _surgeryDetailsController,
            keyboardType: TextInputType.text,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: _inputDecoration('Surgery Details (e.g. ACL Reconstruction, Arthroscopy)'),
          ),
          const SizedBox(height: 10),

          // Approximate Year (Integer keyboard)
          TextFormField(
            controller: _surgeryYearController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: _inputDecoration('Approximate Year', hint: 'e.g. 2021'),
          ),
          const SizedBox(height: 10),

          // Current Limitations (Text)
          TextFormField(
            controller: _surgeryLimitationsController,
            keyboardType: TextInputType.text,
            maxLines: 2,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: _inputDecoration('Current Limitations / Restrictions', hint: 'e.g. Cannot perform deep squats without pain'),
          ),
        ],
      ],
    );
  }

  // --- STEP 8: DAILY ACTIVITY ---
  Widget _buildStep8DailyActivity() {
    final activities = [
      {'key': 'LOW', 'title': 'LOW', 'desc': 'Desk job, mostly sitting, very little movement.'},
      {'key': 'LIGHT', 'title': 'LIGHT', 'desc': 'Some walking throughout the day, light housework.'},
      {'key': 'MODERATE', 'title': 'MODERATE', 'desc': 'On your feet frequently, active commute, teaching/nursing.'},
      {'key': 'HIGH', 'title': 'HIGH', 'desc': 'Heavy physical labor, construction, high-intensity daily movement.'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader('DAILY ACTIVITY', 'How active are you outside the gym?'),
        const SizedBox(height: 16),
        ...activities.map((a) {
          final isSelected = _activityLevel == a['key'];
          return _buildChoiceCard(
            title: a['title']!,
            description: a['desc']!,
            isSelected: isSelected,
            onTap: () => setState(() => _activityLevel = a['key']),
          );
        }),
      ],
    );
  }

  // --- STEP 9: SLEEP & DAILY STEPS ---
  Widget _buildStep9SleepAndSteps() {
    final sleepRanges = ['Less than 5', '5–6', '6–7', '7–8', '8+'];
    final stepRanges = [
      {'val': 2500, 'label': 'Under 3,000'},
      {'val': 4000, 'label': '3,000–5,000'},
      {'val': 6500, 'label': '5,000–8,000'},
      {'val': 9000, 'label': '8,000–10,000'},
      {'val': 12000, 'label': '10,000+'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader('SLEEP & DAILY STEPS', 'Recovery and non-exercise activity tracking.'),
        const SizedBox(height: 16),

        _buildSubHeader('AVERAGE NIGHTLY SLEEP (HOURS)'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: sleepRanges.map((s) {
            final isSel = _sleepHours == s;
            return ChoiceChip(
              label: Text('$s hrs', style: TextStyle(color: isSel ? Colors.white : AppColors.textSecondary, fontWeight: isSel ? FontWeight.w800 : FontWeight.w500)),
              selected: isSel,
              selectedColor: AppColors.primaryRed,
              backgroundColor: AppColors.surfaceCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: isSel ? AppColors.primaryRed : AppColors.border)),
              onSelected: (sel) => setState(() => _sleepHours = s),
            );
          }).toList(),
        ),
        const SizedBox(height: 22),

        _buildSubHeader('APPROXIMATE DAILY STEP COUNT'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: stepRanges.map((st) {
            final isSel = _dailySteps == st['val'];
            return ChoiceChip(
              label: Text(st['label'] as String, style: TextStyle(color: isSel ? Colors.white : AppColors.textSecondary, fontWeight: isSel ? FontWeight.w800 : FontWeight.w500)),
              selected: isSel,
              selectedColor: AppColors.primaryRed,
              backgroundColor: AppColors.surfaceCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: isSel ? AppColors.primaryRed : AppColors.border)),
              onSelected: (sel) {
                setState(() {
                  _dailySteps = st['val'] as int;
                  _stepsController.text = _dailySteps.toString();
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 14),

        // Manual Step Entry (Numbers only)
        TextFormField(
          controller: _stepsController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
          decoration: _inputDecoration('Or enter custom daily step target', suffix: 'steps'),
          onChanged: (val) {
            final parsed = int.tryParse(val);
            if (parsed != null) _dailySteps = parsed;
          },
        ),
      ],
    );
  }

  // --- STEP 10: TRAINING PREFERENCES ---
  Widget _buildStep10TrainingPreferences() {
    final prefs = [
      'Strength Training',
      'Muscle Building',
      'Boxing',
      'Cardio',
      'Functional Training',
      'Mobility',
      'Bodyweight Training',
      'Conditioning',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader('TRAINING PREFERENCES', 'Select all training styles you enjoy or want included in your program (multi-select).'),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: prefs.map((p) {
            final isSel = _trainingPreferences.contains(p);
            return FilterChip(
              label: Text(p, style: TextStyle(color: isSel ? Colors.white : AppColors.textSecondary, fontWeight: isSel ? FontWeight.w800 : FontWeight.w500)),
              selected: isSel,
              selectedColor: AppColors.primaryRed,
              backgroundColor: AppColors.surfaceCard,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: isSel ? AppColors.primaryRed : AppColors.border)),
              onSelected: (sel) {
                setState(() {
                  if (sel) {
                    _trainingPreferences.add(p);
                  } else {
                    _trainingPreferences.remove(p);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- STEP 11: FINAL ASSESSMENT REVIEW ---
  Widget _buildStep11Review() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader('FINAL ASSESSMENT REVIEW', 'Please verify your information before final submission to your trainer.'),
        const SizedBox(height: 16),

        _buildReviewSection('BASIC INFORMATION', 3, [
          _reviewRow('Client ID', _authService.currentClientId),
          _reviewRow('Full Name', _authService.currentUserName),
          _reviewRow('Email', _authService.currentUserEmail),
          _reviewRow('Weight', '${_weightController.text.trim()} kg'),
          _reviewRow('Height', '${_heightController.text.trim()} cm'),
          _reviewRow('Age', '${_ageController.text.trim()} years'),
          _reviewRow('Gender', _gender ?? 'Not specified'),
        ]),
        const SizedBox(height: 14),

        _buildReviewSection('GOALS & EXPERIENCE', 1, [
          _reviewRow('Fitness Level', (_fitnessLevel ?? 'beginner').toUpperCase()),
          _reviewRow('Primary Goal', _primaryGoal ?? 'Not set'),
          _reviewRow('Secondary Goal', _secondaryGoal ?? 'None'),
          _reviewRow('Experience', _trainingExperience ?? 'Not set'),
          _reviewRow('Training Days', '$_trainingDaysPerWeek days / week'),
        ]),
        const SizedBox(height: 14),

        _buildReviewSection('LIFESTYLE & ACTIVITY', 8, [
          _reviewRow('Activity Level', _activityLevel ?? 'MODERATE'),
          _reviewRow('Sleep', '${_sleepHours ?? "7–8"} hours'),
          _reviewRow('Daily Steps', '${_stepsController.text.trim()} steps'),
        ]),
        const SizedBox(height: 14),

        _buildReviewSection('SAFETY & REHAB', 6, [
          _reviewRow('Current Injury', _hasCurrentInjury ? 'YES (${_selectedInjuryAreas.join(", ")})' : 'NO'),
          if (_hasCurrentInjury && _injuryDescController.text.isNotEmpty)
            _reviewRow('Injury Details', _injuryDescController.text.trim()),
          _reviewRow('Previous Surgery', _hasPreviousSurgery ? 'YES' : 'NO'),
          if (_hasPreviousSurgery && _surgeryAreaController.text.isNotEmpty)
            _reviewRow('Surgery Info', '${_surgeryAreaController.text} (${_surgeryYearController.text})'),
        ]),
        const SizedBox(height: 14),

        _buildReviewSection('TRAINING PREFERENCES', 10, [
          _reviewRow('Preferences', _trainingPreferences.isNotEmpty ? _trainingPreferences.join(', ') : 'None selected'),
        ]),
      ],
    );
  }

  Widget _buildReviewSection(String title, int jumpToStep, List<Widget> rows) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.primaryRed,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1.0,
                ),
              ),
              InkWell(
                onTap: () => setState(() => _currentStep = jumpToStep),
                child: const Row(
                  children: [
                    Icon(Icons.edit, size: 14, color: AppColors.textTertiary),
                    SizedBox(width: 4),
                    Text('EDIT', style: TextStyle(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(color: AppColors.border, height: 16),
          ...rows,
        ],
      ),
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // --- UI Helpers ---
  Widget _buildStepHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildSubHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textTertiary,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildChoiceCard({
    required String title,
    required String description,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryRed.withOpacity(0.12) : AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primaryRed : AppColors.border,
              width: isSelected ? 1.8 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        description,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppColors.primaryRed : Colors.transparent,
                  border: Border.all(color: isSelected ? AppColors.primaryRed : AppColors.textTertiary, width: 1.5),
                ),
                child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, {String? hint, String? suffix}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixText: suffix,
      suffixStyle: const TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.bold, fontSize: 12),
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
      filled: true,
      fillColor: AppColors.surfaceCard,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5)),
    );
  }
}
