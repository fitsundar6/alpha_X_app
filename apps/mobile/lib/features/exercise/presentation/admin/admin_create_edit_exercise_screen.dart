import 'package:flutter/material.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/features/exercise/domain/models/exercise_model.dart';
import 'package:alpha_x_gym/features/exercise/data/repositories/exercise_repository.dart';

class AdminCreateEditExerciseScreen extends StatefulWidget {
  final Exercise? exerciseToEdit;

  const AdminCreateEditExerciseScreen({
    super.key,
    this.exerciseToEdit,
  });

  @override
  State<AdminCreateEditExerciseScreen> createState() =>
      _AdminCreateEditExerciseScreenState();
}

class _AdminCreateEditExerciseScreenState
    extends State<AdminCreateEditExerciseScreen> {
  final _formKey = GlobalKey<FormState>();
  final ExerciseRepository _repo = ExerciseRepository();

  late TextEditingController _nameController;
  late TextEditingController _displayNameController;
  late TextEditingController _descriptionController;
  late TextEditingController _trainerNoteController;
  late TextEditingController _videoUrlController;
  late TextEditingController _tagsController;

  String _selectedCategory = 'Chest';
  String _selectedEquipment = 'Barbell';
  String _selectedMovementPattern = 'Horizontal Push';
  String _selectedDifficulty = 'Intermediate';
  String _selectedExerciseType = 'Strength';
  bool _isActive = true;

  final List<MuscleGroup> _primaryMuscles = [];
  final List<MuscleGroup> _secondaryMuscles = [];
  final List<String> _setupInstructions = [];
  final List<String> _executionSteps = [];
  final List<String> _coachingCues = [];
  final List<String> _commonMistakes = [];
  final List<String> _approvedAlternativeIds = [];

  final List<String> _allCategories = [
    'Chest',
    'Back',
    'Shoulders',
    'Biceps',
    'Triceps',
    'Forearms',
    'Quadriceps',
    'Hamstrings',
    'Glutes',
    'Calves',
    'Core',
    'Full Body',
    'Conditioning',
    'Boxing',
    'Cardio',
    'Mobility',
    'Flexibility',
    'Activation',
    'Warm-up',
    'Cool-down',
  ];

  final List<String> _allMovementPatterns = [
    'Horizontal Push',
    'Horizontal Pull',
    'Vertical Push',
    'Vertical Pull',
    'Squat',
    'Hinge',
    'Lunge',
    'Carry',
    'Rotation',
    'Isolation',
    'Cardio / Boxing',
  ];

  final List<String> _allDifficulties = [
    'Beginner',
    'Intermediate',
    'Advanced',
  ];

  final List<String> _allExerciseTypes = [
    'Strength',
    'Hypertrophy',
    'Power',
    'Functional',
    'Conditioning',
    'Boxing',
    'Cardio',
    'Mobility',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.exerciseToEdit;

    _nameController = TextEditingController(text: e?.name ?? '');
    _displayNameController = TextEditingController(text: e?.displayName ?? '');
    _descriptionController = TextEditingController(text: e?.description ?? '');
    _trainerNoteController =
        TextEditingController(text: e?.defaultTrainerNote ?? '');
    _videoUrlController = TextEditingController(text: e?.videoUrl ?? '');
    _tagsController = TextEditingController(text: e?.tags.join(', ') ?? '');

    if (e != null) {
      _selectedCategory = e.category;
      _selectedEquipment = e.equipment;
      _selectedMovementPattern = e.movementPattern;
      _selectedDifficulty = e.difficulty;
      _selectedExerciseType = e.exerciseType;
      _isActive = e.isActive;

      _primaryMuscles.addAll(e.primaryMuscles);
      _secondaryMuscles.addAll(e.secondaryMuscles);
      _setupInstructions.addAll(e.setupInstructions);
      _executionSteps.addAll(e.executionSteps);
      _coachingCues.addAll(e.coachingCues);
      _commonMistakes.addAll(e.commonMistakes);
      _approvedAlternativeIds.addAll(e.approvedAlternativeIds);
    } else {
      _primaryMuscles.add(MuscleGroup.upperChest);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _displayNameController.dispose();
    _descriptionController.dispose();
    _trainerNoteController.dispose();
    _videoUrlController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _addCustomEquipmentDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Add Custom Equipment',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'e.g. Safety Squat Bar, Pit Shark...',
            hintStyle: TextStyle(color: AppColors.textTertiary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed),
            onPressed: () {
              final text = textController.text.trim();
              if (text.isNotEmpty) {
                _repo.addCustomEquipment(text);
                setState(() => _selectedEquipment = text);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Add & Select', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _addDynamicItemDialog({
    required String title,
    required String hint,
    required ValueChanged<String> onAdd,
  }) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          maxLines: 3,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
            filled: true,
            fillColor: AppColors.surfaceCard,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed),
            onPressed: () {
              final text = textController.text.trim();
              if (text.isNotEmpty) {
                onAdd(text);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _saveExercise() {
    if (!_formKey.currentState!.validate()) return;

    if (_primaryMuscles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one primary muscle group.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final tags = _tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final isEditing = widget.exerciseToEdit != null;
    final exerciseId = isEditing
        ? widget.exerciseToEdit!.id
        : 'ex_${DateTime.now().millisecondsSinceEpoch}';

    final exercise = Exercise(
      id: exerciseId,
      name: _nameController.text.trim(),
      displayName: _displayNameController.text.trim().isNotEmpty
          ? _displayNameController.text.trim()
          : _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      category: _selectedCategory,
      primaryMuscles: List.from(_primaryMuscles),
      secondaryMuscles: List.from(_secondaryMuscles),
      equipment: _selectedEquipment,
      movementPattern: _selectedMovementPattern,
      difficulty: _selectedDifficulty,
      exerciseType: _selectedExerciseType,
      setupInstructions: List.from(_setupInstructions),
      executionSteps: List.from(_executionSteps),
      coachingCues: List.from(_coachingCues),
      commonMistakes: List.from(_commonMistakes),
      approvedAlternativeIds: List.from(_approvedAlternativeIds),
      defaultTrainerNote: _trainerNoteController.text.trim(),
      videoUrl: _videoUrlController.text.trim(),
      isActive: _isActive,
      tags: tags,
      createdAt: widget.exerciseToEdit?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (isEditing) {
      _repo.updateExercise(exercise);
    } else {
      _repo.addExercise(exercise);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isEditing
              ? 'Exercise updated successfully'
              : 'Exercise created successfully',
        ),
        backgroundColor: AppColors.primaryRed,
      ),
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.exerciseToEdit != null;
    final availableEquipment = _repo.availableEquipment;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          isEditing ? 'EDIT EXERCISE' : 'CREATE EXERCISE',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saveExercise,
            child: const Text(
              'SAVE',
              style: TextStyle(
                color: AppColors.primaryRed,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Basic Information
            _sectionHeader('1. BASIC INFORMATION'),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _nameController,
              label: 'Exercise Name *',
              hint: 'e.g. Barbell Incline Bench Press',
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Exercise name is required' : null,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _displayNameController,
              label: 'Display Name (Optional)',
              hint: 'e.g. Incline Bench Press',
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _descriptionController,
              label: 'Biomechanical Description',
              hint: 'Explain the joint mechanics, target muscular angles, etc.',
              maxLines: 3,
            ),

            const SizedBox(height: 24),

            // 2. Classification
            _sectionHeader('2. CLASSIFICATION & BIOMECHANICS'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildDropdown(
                    label: 'Category',
                    value: _selectedCategory,
                    items: _allCategories,
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCategory = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          label: 'Equipment',
                          value: _selectedEquipment,
                          items: availableEquipment,
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedEquipment = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: AppColors.primaryRed),
                        tooltip: 'Add Custom Equipment',
                        onPressed: _addCustomEquipmentDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildDropdown(
                    label: 'Movement Pattern',
                    value: _selectedMovementPattern,
                    items: _allMovementPatterns,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedMovementPattern = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          label: 'Difficulty',
                          value: _selectedDifficulty,
                          items: _allDifficulties,
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedDifficulty = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDropdown(
                          label: 'Exercise Type',
                          value: _selectedExerciseType,
                          items: _allExerciseTypes,
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedExerciseType = val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 3. Primary Muscle Groups
            _sectionHeader('3. PRIMARY TARGET MUSCLES (Required)'),
            const SizedBox(height: 4),
            const Text(
              'Select the primary agonist muscle groups targeted by this movement.',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: MuscleGroup.values.map((mg) {
                final isSelected = _primaryMuscles.contains(mg);
                return FilterChip(
                  label: Text(mg.displayName),
                  selected: isSelected,
                  selectedColor: AppColors.primaryRed,
                  backgroundColor: AppColors.surfaceCard,
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: isSelected ? AppColors.primaryRed : AppColors.border,
                    ),
                  ),
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _primaryMuscles.add(mg);
                        _secondaryMuscles.remove(mg);
                      } else {
                        _primaryMuscles.remove(mg);
                      }
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // 4. Secondary Muscle Groups
            _sectionHeader('4. SECONDARY ASSISTING MUSCLES (Optional)'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: MuscleGroup.values.map((mg) {
                final isSelected = _secondaryMuscles.contains(mg);
                final isPrimary = _primaryMuscles.contains(mg);
                return FilterChip(
                  label: Text(mg.displayName),
                  selected: isSelected,
                  selectedColor: AppColors.surfaceElevated,
                  backgroundColor: AppColors.surfaceCard,
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? AppColors.primaryRed : AppColors.textTertiary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: isSelected ? AppColors.primaryRed : AppColors.border,
                    ),
                  ),
                  onSelected: isPrimary
                      ? null
                      : (val) {
                          setState(() {
                            if (val) {
                              _secondaryMuscles.add(mg);
                            } else {
                              _secondaryMuscles.remove(mg);
                            }
                          });
                        },
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // 5. Setup & Execution Instructions
            _buildDynamicListSection(
              title: '5. SETUP INSTRUCTIONS',
              items: _setupInstructions,
              onAdd: () => _addDynamicItemDialog(
                title: 'Add Setup Instruction',
                hint: 'e.g. Set bench to 30 degrees incline...',
                onAdd: (text) => setState(() => _setupInstructions.add(text)),
              ),
              onRemove: (idx) => setState(() => _setupInstructions.removeAt(idx)),
            ),

            const SizedBox(height: 24),

            _buildDynamicListSection(
              title: '6. EXECUTION STEPS',
              items: _executionSteps,
              onAdd: () => _addDynamicItemDialog(
                title: 'Add Execution Step',
                hint: 'e.g. Lower bar under control to upper chest...',
                onAdd: (text) => setState(() => _executionSteps.add(text)),
              ),
              onRemove: (idx) => setState(() => _executionSteps.removeAt(idx)),
            ),

            const SizedBox(height: 24),

            _buildDynamicListSection(
              title: '7. COACHING CUES',
              items: _coachingCues,
              onAdd: () => _addDynamicItemDialog(
                title: 'Add Coaching Cue',
                hint: 'e.g. Keep chest tall, drive through heels...',
                onAdd: (text) => setState(() => _coachingCues.add(text)),
              ),
              onRemove: (idx) => setState(() => _coachingCues.removeAt(idx)),
            ),

            const SizedBox(height: 24),

            _buildDynamicListSection(
              title: '8. COMMON MISTAKES TO AVOID',
              items: _commonMistakes,
              onAdd: () => _addDynamicItemDialog(
                title: 'Add Common Mistake',
                hint: 'e.g. Flaring elbows 90 degrees wide...',
                onAdd: (text) => setState(() => _commonMistakes.add(text)),
              ),
              onRemove: (idx) => setState(() => _commonMistakes.removeAt(idx)),
            ),

            const SizedBox(height: 24),

            // 9. Approved Alternatives Selector
            _sectionHeader('9. APPROVED BIOMECHANICAL ALTERNATIVES'),
            const SizedBox(height: 4),
            const Text(
              'Select exercises that clients can safely swap this movement with during live workout execution.',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
            ),
            const SizedBox(height: 10),
            ..._repo.activeExercises
                .where((ex) => ex.id != widget.exerciseToEdit?.id)
                .map((ex) {
              final isChecked = _approvedAlternativeIds.contains(ex.id);
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: AppColors.primaryRed,
                title: Text(
                  ex.displayName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${ex.equipment} • ${ex.category}',
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                  ),
                ),
                value: isChecked,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _approvedAlternativeIds.add(ex.id);
                    } else {
                      _approvedAlternativeIds.remove(ex.id);
                    }
                  });
                },
              );
            }),

            const SizedBox(height: 24),

            // 10. Trainer Notes & Media
            _sectionHeader('10. TRAINER NOTES & MEDIA'),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _trainerNoteController,
              label: 'Default Trainer Note',
              hint: 'Preset coaching directive displayed to clients when performing this exercise',
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _videoUrlController,
              label: 'Demonstration Video URL (Optional)',
              hint: 'https://...',
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _tagsController,
              label: 'Tags (Comma-separated)',
              hint: 'Compound, Hypertrophy, Dumbbell, Chest',
            ),

            const SizedBox(height: 24),

            // 11. Active / Archive Status Switch
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Active Exercise',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        _isActive
                            ? 'Available in builder and workout sessions'
                            : 'Archived (hidden from active workouts)',
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: _isActive,
                    activeColor: AppColors.primaryRed,
                    onChanged: (val) => setState(() => _isActive = val),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Submit Button
            ElevatedButton.icon(
              onPressed: _saveExercise,
              icon: const Icon(Icons.check_circle_outline, color: Colors.white),
              label: Text(
                isEditing ? 'UPDATE EXERCISE' : 'CREATE EXERCISE',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.1,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
        filled: true,
        fillColor: AppColors.surfaceCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primaryRed),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonFormField<String>(
        value: items.contains(value) ? value : items.first,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          border: InputBorder.none,
        ),
        dropdownColor: AppColors.surfaceElevated,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        items: items
            .map((t) => DropdownMenuItem(value: t, child: Text(t)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildDynamicListSection({
    required String title,
    required List<String> items,
    required VoidCallback onAdd,
    required ValueChanged<int> onRemove,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionHeader(title),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 16, color: AppColors.primaryRed),
              label: const Text(
                'Add',
                style: TextStyle(
                  color: AppColors.primaryRed,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: Text(
                'No items added yet. Click + Add to include step or cue.',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
              ),
            ),
          )
        else
          ...items.asMap().entries.map((entry) {
            final idx = entry.key;
            final text = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${idx + 1}.',
                    style: const TextStyle(
                      color: AppColors.primaryRed,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 16,
                      color: AppColors.textTertiary,
                    ),
                    onPressed: () => onRemove(idx),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
