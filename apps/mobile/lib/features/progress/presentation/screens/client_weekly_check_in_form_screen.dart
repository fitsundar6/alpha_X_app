import 'package:flutter/material.dart';
import 'package:alpha_x_gym/core/theme/alpha_x_design_system.dart';
import 'package:alpha_x_gym/features/progress/domain/models/weekly_check_in.dart';
import 'package:alpha_x_gym/features/progress/data/repositories/weekly_progress_repository.dart';

class ClientWeeklyCheckInFormScreen extends StatefulWidget {
  final WeeklyProgressRepository repository;
  final int weekNumber;

  const ClientWeeklyCheckInFormScreen({
    super.key,
    required this.repository,
    required this.weekNumber,
  });

  @override
  State<ClientWeeklyCheckInFormScreen> createState() => _ClientWeeklyCheckInFormScreenState();
}

class _ClientWeeklyCheckInFormScreenState extends State<ClientWeeklyCheckInFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // 1. Body Progress
  final _weightCtrl = TextEditingController();
  final _waistCtrl = TextEditingController();
  final _chestCtrl = TextEditingController();
  final _armsCtrl = TextEditingController();
  final _hipsCtrl = TextEditingController();
  final _thighsCtrl = TextEditingController();
  bool _showAdvancedMeasurements = false;

  // 2. Nutrition
  String _nutritionCalories = 'Good';
  String _nutritionProtein = 'Good';
  String _nutritionWater = 'Good';
  String _dietAdherence = 'Good';

  // 3. Sleep & Recovery
  String _sleepQuality = 'Good';
  double _sleepHours = 7.5;
  String _recoveryQuality = 'Good';

  // 4. Workout
  String _workoutCompletion = 'All';
  String _workoutFeeling = 'Good';
  String _energyLevel = 'Good';

  // 5. Pain / Discomfort
  bool _hasPain = false;
  final _painLocationCtrl = TextEditingController();
  final _painExerciseCtrl = TextEditingController();
  double _painLevel = 3.0;
  final _painDescriptionCtrl = TextEditingController();

  // 6. Weekly Problems
  final Set<String> _selectedProblems = {};
  static const List<String> _allProblems = [
    'Missed workouts',
    'Low protein',
    'Poor water intake',
    'Poor sleep',
    'Missed meals',
    'Calories not followed',
    'Poor recovery',
    'Stress/busy schedule',
    'Motivation issue',
    'Pain/discomfort',
    'No major problems',
    'Other',
  ];

  // 7. Client Notes
  final _clientNotesCtrl = TextEditingController();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _weightCtrl.addListener(_onFieldChanged);
    _waistCtrl.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _weightCtrl.removeListener(_onFieldChanged);
    _waistCtrl.removeListener(_onFieldChanged);
    _weightCtrl.dispose();
    _waistCtrl.dispose();
    _chestCtrl.dispose();
    _armsCtrl.dispose();
    _hipsCtrl.dispose();
    _thighsCtrl.dispose();
    _painLocationCtrl.dispose();
    _painExerciseCtrl.dispose();
    _painDescriptionCtrl.dispose();
    _clientNotesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete required fields (Weight is required)'),
          backgroundColor: AlphaXColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final payload = <String, dynamic>{
        'weightKg': double.tryParse(_weightCtrl.text.trim()) ?? 0.0,
        'waistCm': _waistCtrl.text.trim().isNotEmpty ? double.tryParse(_waistCtrl.text.trim()) : null,
        'chestCm': _chestCtrl.text.trim().isNotEmpty ? double.tryParse(_chestCtrl.text.trim()) : null,
        'armsCm': _armsCtrl.text.trim().isNotEmpty ? double.tryParse(_armsCtrl.text.trim()) : null,
        'hipsCm': _hipsCtrl.text.trim().isNotEmpty ? double.tryParse(_hipsCtrl.text.trim()) : null,
        'thighsCm': _thighsCtrl.text.trim().isNotEmpty ? double.tryParse(_thighsCtrl.text.trim()) : null,

        'nutritionCalories': _nutritionCalories,
        'nutritionProtein': _nutritionProtein,
        'nutritionWater': _nutritionWater,
        'dietAdherence': _dietAdherence,

        'sleepQuality': _sleepQuality,
        'sleepHours': _sleepHours,
        'recoveryQuality': _recoveryQuality,

        'workoutCompletion': _workoutCompletion,
        'workoutFeeling': _workoutFeeling,
        'energyLevel': _energyLevel,

        'hasPain': _hasPain,
        'painLocation': _hasPain ? _painLocationCtrl.text.trim() : null,
        'painExercise': _hasPain ? _painExerciseCtrl.text.trim() : null,
        'painLevel': _hasPain ? _painLevel.toInt() : null,
        'painDescription': _hasPain ? _painDescriptionCtrl.text.trim() : null,

        'weeklyProblems': _selectedProblems.toList(),
        'clientNotes': _clientNotesCtrl.text.trim().isNotEmpty ? _clientNotesCtrl.text.trim() : null,
      };

      final newCheckIn = await widget.repository.submitWeeklyCheckIn(payload);

      if (mounted) {
        Navigator.of(context).pop(newCheckIn);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AlphaXColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasData = _weightCtrl.text.isNotEmpty || _waistCtrl.text.isNotEmpty;

    return PopScope(
      canPop: !hasData,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldDiscard = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AlphaXColors.surfaceElevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AlphaXColors.border),
            ),
            title: const Text('Discard Check-In?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
            content: const Text(
              'Your entered weekly measurements have not been submitted. Do you want to discard them?',
              style: TextStyle(color: AlphaXColors.textSecondary, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Keep Editing', style: TextStyle(color: AlphaXColors.textSecondary, fontWeight: FontWeight.w600)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AlphaXColors.redAccent),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Discard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        );
        if (shouldDiscard == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
      backgroundColor: AlphaXColors.background,
      appBar: AppBar(
        backgroundColor: AlphaXColors.surface,
        title: Text(
          'WEEK ${widget.weekNumber} CHECK-IN',
          style: const TextStyle(
            color: AlphaXColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: AlphaXColors.textPrimary),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderBanner(),
                const SizedBox(height: 20),

                // 1. Body Progress Section
                _buildSectionBox(
                  title: '1. BODY PROGRESS',
                  subtitle: 'Enter your current body weight and waist measurement.',
                  icon: Icons.monitor_weight_rounded,
                  accentColor: AlphaXColors.redAccent,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildInputField(
                              controller: _weightCtrl,
                              label: 'Weight (kg) *',
                              hint: 'e.g. 78.5',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Required';
                                final num = double.tryParse(val.trim());
                                if (num == null || num <= 20 || num >= 350) return 'Invalid (20-350)';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInputField(
                              controller: _waistCtrl,
                              label: 'Waist (cm)',
                              hint: 'e.g. 84.0',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                        ],
                      ),
                      _buildLiveDeltaPreview(widget.repository.latestCheckIn ?? widget.repository.currentStatus?.lastCheckIn),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: () => setState(() => _showAdvancedMeasurements = !_showAdvancedMeasurements),
                        icon: Icon(
                          _showAdvancedMeasurements ? Icons.expand_less : Icons.expand_more,
                          color: AlphaXColors.textSecondary,
                          size: 18,
                        ),
                        label: Text(
                          _showAdvancedMeasurements ? 'Hide Optional Measurements' : '+ Add Chest, Arms, Hips, Thighs (Optional)',
                          style: const TextStyle(color: AlphaXColors.textSecondary, fontSize: 12),
                        ),
                      ),
                      if (_showAdvancedMeasurements) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildInputField(
                                controller: _chestCtrl,
                                label: 'Chest (cm)',
                                hint: 'e.g. 98.0',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildInputField(
                                controller: _armsCtrl,
                                label: 'Arms (cm)',
                                hint: 'e.g. 36.5',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildInputField(
                                controller: _hipsCtrl,
                                label: 'Hips (cm)',
                                hint: 'e.g. 96.0',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildInputField(
                                controller: _thighsCtrl,
                                label: 'Thighs (cm)',
                                hint: 'e.g. 58.0',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Nutrition Section
                _buildSectionBox(
                  title: '2. NUTRITION (PAST 7 DAYS)',
                  subtitle: 'How closely did you follow your nutrition targets?',
                  icon: Icons.restaurant_rounded,
                  accentColor: const Color(0xFF4CAF50),
                  child: Column(
                    children: [
                      _buildChoiceRow(
                        label: 'Calories Target',
                        options: ['Good', 'Mostly', 'Poor'],
                        selected: _nutritionCalories,
                        onChanged: (v) => setState(() => _nutritionCalories = v),
                      ),
                      const SizedBox(height: 12),
                      _buildChoiceRow(
                        label: 'Protein Intake',
                        options: ['Good', 'Mostly', 'Poor'],
                        selected: _nutritionProtein,
                        onChanged: (v) => setState(() => _nutritionProtein = v),
                      ),
                      const SizedBox(height: 12),
                      _buildChoiceRow(
                        label: 'Daily Water Hydration',
                        options: ['Good', 'Average', 'Poor'],
                        selected: _nutritionWater,
                        onChanged: (v) => setState(() => _nutritionWater = v),
                      ),
                      const SizedBox(height: 12),
                      _buildChoiceRow(
                        label: 'Diet-Plan Adherence',
                        options: ['Good', 'Mostly', 'Poor'],
                        selected: _dietAdherence,
                        onChanged: (v) => setState(() => _dietAdherence = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Sleep & Recovery Section
                _buildSectionBox(
                  title: '3. SLEEP & RECOVERY',
                  subtitle: 'Recovery is the foundation of long-term progress.',
                  icon: Icons.bedtime_rounded,
                  accentColor: const Color(0xFF29B6F6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildChoiceRow(
                        label: 'Sleep Quality',
                        options: ['Good', 'Average', 'Poor'],
                        selected: _sleepQuality,
                        onChanged: (v) => setState(() => _sleepQuality = v),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Average Sleep Hours', style: TextStyle(color: AlphaXColors.textSecondary, fontSize: 13)),
                          Text(
                            '${_sleepHours.toStringAsFixed(1)} hrs / night',
                            style: const TextStyle(color: AlphaXColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: const Color(0xFF29B6F6),
                          thumbColor: const Color(0xFF29B6F6),
                          inactiveTrackColor: AlphaXColors.border,
                        ),
                        child: Slider(
                          value: _sleepHours,
                          min: 4.0,
                          max: 12.0,
                          divisions: 16,
                          label: '${_sleepHours.toStringAsFixed(1)}h',
                          onChanged: (val) => setState(() => _sleepHours = val),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildChoiceRow(
                        label: 'Overall Recovery',
                        options: ['Good', 'Average', 'Poor'],
                        selected: _recoveryQuality,
                        onChanged: (v) => setState(() => _recoveryQuality = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 4. Workout Section
                _buildSectionBox(
                  title: '4. WORKOUT EXECUTION',
                  subtitle: 'Report your training consistency and intensity.',
                  icon: Icons.fitness_center_rounded,
                  accentColor: AlphaXColors.gold,
                  child: Column(
                    children: [
                      _buildChoiceRow(
                        label: 'Planned Workouts Completed',
                        options: ['All', 'Most', 'Some', 'None'],
                        selected: _workoutCompletion,
                        onChanged: (v) => setState(() => _workoutCompletion = v),
                      ),
                      const SizedBox(height: 12),
                      _buildChoiceRow(
                        label: 'Workout Feeling',
                        options: ['Very Good', 'Good', 'Average', 'Difficult'],
                        selected: _workoutFeeling,
                        onChanged: (v) => setState(() => _workoutFeeling = v),
                      ),
                      const SizedBox(height: 12),
                      _buildChoiceRow(
                        label: 'Energy Level',
                        options: ['High', 'Good', 'Low'],
                        selected: _energyLevel,
                        onChanged: (v) => setState(() => _energyLevel = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 5. Pain / Discomfort Section
                _buildSectionBox(
                  title: '5. PAIN / DISCOMFORT REPORT',
                  subtitle: 'Stored for trainer review to optimize exercise selection.',
                  icon: Icons.health_and_safety_rounded,
                  accentColor: AlphaXColors.warning,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Did you experience any pain or discomfort during training?',
                              style: TextStyle(color: AlphaXColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Switch(
                            value: _hasPain,
                            activeColor: AlphaXColors.warning,
                            onChanged: (v) => setState(() => _hasPain = v),
                          ),
                        ],
                      ),
                      if (_hasPain) ...[
                        const Divider(color: AlphaXColors.border, height: 20),
                        _buildInputField(
                          controller: _painLocationCtrl,
                          label: 'Pain Location *',
                          hint: 'e.g. Left shoulder, lower back, right knee',
                        ),
                        const SizedBox(height: 10),
                        _buildInputField(
                          controller: _painExerciseCtrl,
                          label: 'Exercise That Caused It',
                          hint: 'e.g. Barbell Incline Press',
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Pain Level (1-10)', style: TextStyle(color: AlphaXColors.textSecondary, fontSize: 13)),
                            Text(
                              '${_painLevel.toInt()} / 10',
                              style: const TextStyle(color: AlphaXColors.warning, fontSize: 14, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        Slider(
                          value: _painLevel,
                          min: 1.0,
                          max: 10.0,
                          divisions: 9,
                          activeColor: AlphaXColors.warning,
                          inactiveColor: AlphaXColors.border,
                          label: '${_painLevel.toInt()}',
                          onChanged: (val) => setState(() => _painLevel = val),
                        ),
                        const SizedBox(height: 6),
                        _buildInputField(
                          controller: _painDescriptionCtrl,
                          label: 'Description',
                          hint: 'e.g. Sharp pinch at top of motion, dull ache after workout...',
                          maxLines: 2,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AlphaXColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Alpha X does not diagnose pain or provide medical advice. Your coach will review this to adjust workout volume and exercise selection.',
                            style: TextStyle(color: AlphaXColors.textMuted, fontSize: 10),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 6. Weekly Problems Multi-Select
                _buildSectionBox(
                  title: '6. WEEKLY CHALLENGES & PROBLEMS',
                  subtitle: 'Select any obstacles you faced this past week (multi-select).',
                  icon: Icons.report_problem_rounded,
                  accentColor: AlphaXColors.textSecondary,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _allProblems.map((problem) {
                      final isSelected = _selectedProblems.contains(problem);
                      return FilterChip(
                        label: Text(problem),
                        selected: isSelected,
                        selectedColor: AlphaXColors.redAccent.withValues(alpha: 0.2),
                        backgroundColor: AlphaXColors.surfaceElevated,
                        checkmarkColor: AlphaXColors.redAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected ? AlphaXColors.redAccent : AlphaXColors.border,
                          ),
                        ),
                        labelStyle: TextStyle(
                          color: isSelected ? AlphaXColors.textPrimary : AlphaXColors.textSecondary,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                        onSelected: (val) {
                          setState(() {
                            if (val) {
                              _selectedProblems.add(problem);
                            } else {
                              _selectedProblems.remove(problem);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // 7. Client Notes
                _buildSectionBox(
                  title: '7. MESSAGE FOR YOUR COACH',
                  subtitle: 'Anything else you want your coach to know?',
                  icon: Icons.chat_bubble_outline_rounded,
                  accentColor: AlphaXColors.gold,
                  child: _buildInputField(
                    controller: _clientNotesCtrl,
                    label: 'Client Notes (Optional)',
                    hint: 'Share feedback, questions, or schedule changes for next week...',
                    maxLines: 3,
                  ),
                ),
                const SizedBox(height: 24),

                // Submit Action
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AlphaXColors.redAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AlphaXRadius.md)),
                      elevation: 4,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            'SUBMIT WEEK ${widget.weekNumber} CHECK-IN',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildHeaderBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AlphaXColors.surfaceCard,
        borderRadius: BorderRadius.circular(AlphaXRadius.md),
        border: Border.all(color: AlphaXColors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AlphaXColors.redAccent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_clock_rounded, color: AlphaXColors.redAccent, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WEEKLY PROGRESS SUBMISSION',
                  style: TextStyle(color: AlphaXColors.redAccent, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0),
                ),
                SizedBox(height: 3),
                Text(
                  'Submitting locks this check-in for 7 days until your next weekly review window opens.',
                  style: TextStyle(color: AlphaXColors.textSecondary, fontSize: 12, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionBox({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AlphaXColors.surfaceCard,
        borderRadius: BorderRadius.circular(AlphaXRadius.md),
        border: Border.all(color: AlphaXColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: accentColor, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AlphaXColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: AlphaXColors.textTertiary, fontSize: 11)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildChoiceRow({
    required String label,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AlphaXColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Row(
          children: options.map((opt) {
            final isChosen = selected.toLowerCase() == opt.toLowerCase();
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(opt),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isChosen ? AlphaXColors.redAccent.withValues(alpha: 0.2) : AlphaXColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isChosen ? AlphaXColors.redAccent : AlphaXColors.border,
                      width: isChosen ? 1.5 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    opt,
                    style: TextStyle(
                      color: isChosen ? AlphaXColors.textPrimary : AlphaXColors.textSecondary,
                      fontSize: 11,
                      fontWeight: isChosen ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AlphaXColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          style: const TextStyle(color: AlphaXColors.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AlphaXColors.textMuted, fontSize: 12),
            filled: true,
            fillColor: AlphaXColors.surfaceElevated,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AlphaXColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AlphaXColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AlphaXColors.redAccent),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLiveDeltaPreview(WeeklyCheckIn? prev) {
    if (prev == null) {
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AlphaXColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AlphaXColors.border),
        ),
        child: const Row(
          children: [
            Icon(Icons.flag_outlined, size: 14, color: AlphaXColors.redAccent),
            SizedBox(width: 8),
            Text(
              'Week 1 Baseline: Recording starting body metrics',
              style: TextStyle(color: AlphaXColors.textSecondary, fontSize: 11.5),
            ),
          ],
        ),
      );
    }

    final weightText = _weightCtrl.text.trim();
    final waistText = _waistCtrl.text.trim();
    final currentWeight = double.tryParse(weightText);
    final currentWaist = double.tryParse(waistText);

    final double? weightDiff = currentWeight != null ? (((currentWeight - prev.weightKg) * 10).round() / 10.0) : null;
    final double? waistDiff = (currentWaist != null && prev.waistCm != null)
        ? (((currentWaist - prev.waistCm!) * 10).round() / 10.0)
        : null;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AlphaXColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AlphaXColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PREVIOUS: ${prev.weightDisplay}${prev.waistCm != null ? " • Waist ${prev.waistDisplay}" : ""}',
                style: const TextStyle(
                  color: AlphaXColors.textTertiary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const Row(
                children: [
                  Icon(Icons.auto_awesome, size: 12, color: AlphaXColors.gold),
                  SizedBox(width: 4),
                  Text(
                    'AUTO-CALCULATED',
                    style: TextStyle(color: AlphaXColors.gold, fontSize: 9.5, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      weightDiff == null
                          ? Icons.remove_circle_outline
                          : (weightDiff <= 0 ? Icons.trending_down_rounded : Icons.trending_up_rounded),
                      size: 16,
                      color: weightDiff == null
                          ? AlphaXColors.textTertiary
                          : (weightDiff <= 0 ? AlphaXColors.success : AlphaXColors.warning),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      weightDiff == null
                          ? 'Weight Change: —'
                          : 'Weight: ${weightDiff > 0 ? "+" : ""}${weightDiff.toStringAsFixed(1)} kg',
                      style: TextStyle(
                        color: weightDiff == null
                            ? AlphaXColors.textTertiary
                            : (weightDiff <= 0 ? AlphaXColors.success : AlphaXColors.warning),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (prev.waistCm != null)
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        waistDiff == null
                            ? Icons.remove_circle_outline
                            : (waistDiff <= 0 ? Icons.trending_down_rounded : Icons.trending_up_rounded),
                        size: 16,
                        color: waistDiff == null
                            ? AlphaXColors.textTertiary
                            : (waistDiff <= 0 ? AlphaXColors.success : AlphaXColors.warning),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        waistDiff == null
                            ? 'Waist Change: —'
                            : 'Waist: ${waistDiff > 0 ? "+" : ""}${waistDiff.toStringAsFixed(1)} cm',
                        style: TextStyle(
                          color: waistDiff == null
                              ? AlphaXColors.textTertiary
                              : (waistDiff <= 0 ? AlphaXColors.success : AlphaXColors.warning),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
