import 'package:flutter/material.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/features/exercise/domain/models/exercise_model.dart';
import 'package:alpha_x_gym/features/exercise/data/repositories/exercise_repository.dart';

class ExercisePickerDialog extends StatefulWidget {
  final String? initialCategory;
  final String? excludedExerciseId;
  final ValueChanged<Exercise> onSelect;

  const ExercisePickerDialog({
    super.key,
    this.initialCategory,
    this.excludedExerciseId,
    required this.onSelect,
  });

  static Future<Exercise?> show(
    BuildContext context, {
    String? initialCategory,
    String? excludedExerciseId,
  }) async {
    Exercise? selected;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => ExercisePickerDialog(
          initialCategory: initialCategory,
          excludedExerciseId: excludedExerciseId,
          onSelect: (ex) {
            selected = ex;
            Navigator.of(ctx).pop();
          },
        ),
      ),
    );
    return selected;
  }

  @override
  State<ExercisePickerDialog> createState() => _ExercisePickerDialogState();
}

class _ExercisePickerDialogState extends State<ExercisePickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  final ExerciseRepository _repo = ExerciseRepository();

  String _selectedCategory = 'All';
  final String _selectedEquipment = 'All';
  final String _selectedDifficulty = 'All';

  final List<String> _categories = [
    'All',
    'Chest',
    'Back',
    'Shoulders',
    'Arms',
    'Biceps',
    'Triceps',
    'Legs',
    'Glutes',
    'Core',
    'Full Body',
    'Functional',
    'Quadriceps',
    'Hamstrings',
    'Calves',
    'Forearms',
    'Conditioning',
    'Boxing',
    'Cardio',
    'Mobility',
    'Flexibility',
    'Activation',
    'Warm-up',
    'Cool-down',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) {
      final match = _categories.firstWhere(
        (c) => c.toLowerCase() == widget.initialCategory!.toLowerCase(),
        orElse: () => '',
      );
      if (match.isNotEmpty) {
        _selectedCategory = match;
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Exercise> get _filteredExercises {
    return _repo.searchExercises(
      query: _searchController.text.trim(),
      category: _selectedCategory == 'All' ? null : _selectedCategory,
      equipment: _selectedEquipment == 'All' ? null : _selectedEquipment,
      difficulty: _selectedDifficulty == 'All' ? null : _selectedDifficulty,
      includeArchived: false,
      sort: ExerciseSortOption.nameAsc,
    ).where((e) => e.id != widget.excludedExerciseId).toList();
  }

  @override
  Widget build(BuildContext context) {
    final exercises = _filteredExercises;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.fitness_center_rounded,
                  color: AppColors.primaryRed,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'SELECT EXERCISE',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
                const Spacer(),
                Text(
                  '${exercises.length} available',
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search by exercise name, muscle, equipment...',
                hintStyle: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 13,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.textTertiary,
                  size: 20,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear,
                          size: 18,
                          color: AppColors.textTertiary,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surfaceCard,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primaryRed),
                ),
              ),
            ),
          ),

          // Horizontal Category Filter Chips
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (ctx, idx) {
                final cat = _categories[idx];
                final isSelected = cat == _selectedCategory;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(cat),
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
                      if (val) setState(() => _selectedCategory = cat);
                    },
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),
          const Divider(color: AppColors.border, height: 1),

          // Exercise List
          Expanded(
            child: exercises.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.search_off_rounded,
                            size: 48,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No matching exercises found',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Try changing filters or search keywords.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: exercises.length,
                    itemBuilder: (ctx, index) {
                      final ex = exercises[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 4,
                          ),
                          title: Text(
                            ex.displayName,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            '${ex.equipment} • ${ex.category} • ${ex.primaryMusclesDisplay}',
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.add_circle_outline,
                            color: AppColors.primaryRed,
                            size: 22,
                          ),
                          onTap: () => widget.onSelect(ex),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
