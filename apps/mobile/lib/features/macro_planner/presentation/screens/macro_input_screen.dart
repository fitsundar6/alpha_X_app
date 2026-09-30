import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/repositories/macro_repository.dart';
import '../../domain/models/macro_enums.dart';
import '../../domain/models/macro_input.dart';
import '../widgets/activity_selector.dart';
import '../widgets/goal_selector.dart';
import 'macro_result_screen.dart';

/// Form screen collecting personal data, body measurements, activity level, and goal
class MacroInputScreen extends StatefulWidget {
  final MacroRepository repository;
  final MacroInput? initialInput;

  const MacroInputScreen({
    super.key,
    required this.repository,
    this.initialInput,
  });

  @override
  State<MacroInputScreen> createState() => _MacroInputScreenState();
}

class _MacroInputScreenState extends State<MacroInputScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _ageController;
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;

  // Imperial support controllers
  late final TextEditingController _heightFeetController;
  late final TextEditingController _heightInchesController;
  late final TextEditingController _weightLbsController;

  BiologicalSex _sex = BiologicalSex.male;
  ActivityLevel _activityLevel = ActivityLevel.moderatelyActive;
  NutritionGoal _goal = NutritionGoal.fatLoss;

  bool _isImperial = false;

  @override
  void initState() {
    super.initState();
    final init = widget.initialInput ?? widget.repository.currentInput;

    if (init != null) {
      _sex = init.sex;
      _activityLevel = init.activityLevel;
      _goal = init.goal;
      _ageController = TextEditingController(text: init.age.toString());
      _heightController = TextEditingController(text: init.heightCm.toStringAsFixed(0));
      _weightController = TextEditingController(text: init.weightKg.toStringAsFixed(1));

      final (feet, inches) = MacroInput.cmToFeetInches(init.heightCm);
      _heightFeetController = TextEditingController(text: feet.toString());
      _heightInchesController = TextEditingController(text: inches.toStringAsFixed(1));
      _weightLbsController = TextEditingController(text: MacroInput.kgToLbs(init.weightKg).toStringAsFixed(1));
    } else {
      _ageController = TextEditingController(text: '28');
      _heightController = TextEditingController(text: '174');
      _weightController = TextEditingController(text: '81.0');

      _heightFeetController = TextEditingController(text: '5');
      _heightInchesController = TextEditingController(text: '8.5');
      _weightLbsController = TextEditingController(text: '178.5');
    }
  }

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _heightFeetController.dispose();
    _heightInchesController.dispose();
    _weightLbsController.dispose();
    super.dispose();
  }

  void _onToggleUnits(bool imperial) {
    if (_isImperial == imperial) return;
    setState(() {
      _isImperial = imperial;
      if (_isImperial) {
        // Metric -> Imperial
        final cm = double.tryParse(_heightController.text) ?? 174.0;
        final kg = double.tryParse(_weightController.text) ?? 81.0;
        final (feet, inches) = MacroInput.cmToFeetInches(cm);
        _heightFeetController.text = feet.toString();
        _heightInchesController.text = inches.toStringAsFixed(1);
        _weightLbsController.text = MacroInput.kgToLbs(kg).toStringAsFixed(1);
      } else {
        // Imperial -> Metric
        final feet = int.tryParse(_heightFeetController.text) ?? 5;
        final inches = double.tryParse(_heightInchesController.text) ?? 8.5;
        final lbs = double.tryParse(_weightLbsController.text) ?? 178.5;
        final cm = MacroInput.feetInchesToCm(feet, inches);
        final kg = MacroInput.lbsToKg(lbs);
        _heightController.text = cm.toStringAsFixed(0);
        _weightController.text = kg.toStringAsFixed(1);
      }
    });
  }

  void _calculateTargets() {
    if (!_formKey.currentState!.validate()) return;

    final age = int.parse(_ageController.text.trim());
    double heightCm;
    double weightKg;

    if (_isImperial) {
      final feet = int.tryParse(_heightFeetController.text.trim()) ?? 5;
      final inches = double.tryParse(_heightInchesController.text.trim()) ?? 0.0;
      final lbs = double.tryParse(_weightLbsController.text.trim()) ?? 150.0;
      heightCm = MacroInput.feetInchesToCm(feet, inches);
      weightKg = MacroInput.lbsToKg(lbs);
    } else {
      heightCm = double.parse(_heightController.text.trim());
      weightKg = double.parse(_weightController.text.trim());
    }

    final input = MacroInput(
      age: age,
      sex: _sex,
      heightCm: heightCm,
      weightKg: weightKg,
      activityLevel: _activityLevel,
      goal: _goal,
    );

    final result = widget.repository.computeTargets(input);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => MacroResultScreen(
          input: input,
          result: result,
          repository: widget.repository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CALCULATE NUTRITION TARGETS'),
        actions: [
          // Metric / Imperial unit toggle pill
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _UnitChip(
                      label: 'Metric',
                      isSelected: !_isImperial,
                      onTap: () => _onToggleUnits(false),
                    ),
                    _UnitChip(
                      label: 'Imperial',
                      isSelected: _isImperial,
                      onTap: () => _onToggleUnits(true),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          children: [
            const Text(
              'ALPHA X MACRO PLANNER',
              style: AppTypography.displayMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'Know your baseline daily energy and macronutrient targets calibrated to your body and fitness goals.',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: 20),

            // SECTION 1: Personal Information
            _SectionHeader(title: '1. PERSONAL INFORMATION', icon: Icons.person_outline),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Age', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: MacroInput.validateAge,
                        decoration: InputDecoration(
                          hintText: 'e.g. 28',
                          suffixText: 'yrs',
                          filled: true,
                          fillColor: AppColors.surfaceCard,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Biological Sex', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: _SexSelectable(
                              label: 'Male',
                              isSelected: _sex == BiologicalSex.male,
                              onTap: () => setState(() => _sex = BiologicalSex.male),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _SexSelectable(
                              label: 'Female',
                              isSelected: _sex == BiologicalSex.female,
                              onTap: () => setState(() => _sex = BiologicalSex.female),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // SECTION 2: Body Measurements
            _SectionHeader(title: '2. BODY MEASUREMENTS', icon: Icons.straighten),
            const SizedBox(height: 12),

            if (!_isImperial) ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Height', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _heightController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: MacroInput.validateHeight,
                          decoration: InputDecoration(
                            hintText: 'e.g. 174',
                            suffixText: 'cm',
                            filled: true,
                            fillColor: AppColors.surfaceCard,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Body Weight', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _weightController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: MacroInput.validateWeight,
                          decoration: InputDecoration(
                            hintText: 'e.g. 81.0',
                            suffixText: 'kg',
                            filled: true,
                            fillColor: AppColors.surfaceCard,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Height (Feet)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _heightFeetController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: '5',
                            suffixText: 'ft',
                            filled: true,
                            fillColor: AppColors.surfaceCard,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Inches', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _heightInchesController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            hintText: '9',
                            suffixText: 'in',
                            filled: true,
                            fillColor: AppColors.surfaceCard,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Weight (Pounds)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _weightLbsController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            hintText: '178.5',
                            suffixText: 'lbs',
                            filled: true,
                            fillColor: AppColors.surfaceCard,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 24),

            // SECTION 3: Activity Level
            _SectionHeader(title: '3. ACTIVITY LEVEL', icon: Icons.directions_run),
            const SizedBox(height: 6),
            const Text(
              'Select your typical weekly activity. (Do not assume level based only on gym sessions)',
              style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 12),
            ActivitySelector(
              selectedLevel: _activityLevel,
              onSelected: (level) => setState(() => _activityLevel = level),
            ),

            const SizedBox(height: 24),

            // SECTION 4: Nutrition Goal
            _SectionHeader(title: '4. NUTRITION GOAL', icon: Icons.track_changes),
            const SizedBox(height: 6),
            const Text(
              'Select your desired energy balance target. Individual outcomes vary.',
              style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 12),
            GoalSelector(
              selectedGoal: _goal,
              onSelected: (goal) => setState(() => _goal = goal),
            ),

            const SizedBox(height: 28),

            // Calculate Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _calculateTargets,
                icon: const Icon(Icons.calculate, size: 20),
                label: const Text(
                  'CALCULATE MY TARGETS',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 6,
                  shadowColor: AppColors.glowRed,
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primaryRed),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _SexSelectable extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SexSelectable({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceElevated : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryRed : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _UnitChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _UnitChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryRed : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}
