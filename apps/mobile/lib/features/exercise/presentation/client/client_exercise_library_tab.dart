import 'package:flutter/material.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/features/exercise/domain/models/exercise_model.dart';
import 'package:alpha_x_gym/features/exercise/data/repositories/exercise_repository.dart';
import '../widgets/exercise_detail_modal.dart';

/// Clean, client-facing Exercise Library browser.
/// Gives clients full direct access to search, filter by muscle/equipment/difficulty,
/// and review form execution GIFs, cues, and instructions.
class ClientExerciseLibraryTab extends StatefulWidget {
  const ClientExerciseLibraryTab({super.key});

  @override
  State<ClientExerciseLibraryTab> createState() => _ClientExerciseLibraryTabState();
}

class _ClientExerciseLibraryTabState extends State<ClientExerciseLibraryTab> {
  final ExerciseRepository _repo = ExerciseRepository();
  final TextEditingController _searchController = TextEditingController();

  String _selectedCategory = 'All';
  String _selectedEquipment = 'All';
  String _selectedDifficulty = 'All';

  final List<String> _categories = [
    'All',
    'Chest',
    'Back',
    'Shoulders',
    'Arms',
    'Biceps',
    'Triceps',
    'Legs',
    'Quadriceps',
    'Hamstrings',
    'Glutes',
    'Core',
    'Full Body',
    'Cardio',
    'Mobility',
  ];

  final List<String> _equipmentList = [
    'All',
    'Barbell',
    'Dumbbell',
    'Cable',
    'Machine',
    'Smith Machine',
    'Bodyweight',
    'Kettlebell',
  ];

  final List<String> _difficulties = [
    'All',
    'Beginner',
    'Intermediate',
    'Advanced',
  ];

  @override
  void initState() {
    super.initState();
    _repo.addListener(_onRepoChange);
  }

  @override
  void dispose() {
    _repo.removeListener(_onRepoChange);
    _searchController.dispose();
    super.dispose();
  }

  void _onRepoChange() {
    if (mounted) setState(() {});
  }

  List<Exercise> get _filteredExercises {
    return _repo.searchExercises(
      query: _searchController.text.trim(),
      category: _selectedCategory == 'All' ? null : _selectedCategory,
      equipment: _selectedEquipment == 'All' ? null : _selectedEquipment,
      difficulty: _selectedDifficulty == 'All' ? null : _selectedDifficulty,
      includeArchived: false,
    );
  }

  void _openExerciseDetail(Exercise exercise) {
    ExerciseDetailModal.show(context, exercise);
  }

  @override
  Widget build(BuildContext context) {
    final exercises = _filteredExercises;

    return Column(
      children: [
        // Search & Filter Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: AppColors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Input
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search 260+ exercises, muscles, equipment...',
                  hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: AppColors.primaryRed, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: AppColors.textSecondary, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                    borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Horizontal Category Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        selected: isSelected,
                        label: Text(cat),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                          fontSize: 12,
                        ),
                        backgroundColor: AppColors.surfaceElevated,
                        selectedColor: AppColors.primaryRed,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: isSelected ? AppColors.primaryRed : AppColors.border,
                          ),
                        ),
                        showCheckmark: false,
                        onSelected: (val) {
                          setState(() => _selectedCategory = val ? cat : 'All');
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),

              // Sub-filters row (Equipment & Difficulty)
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedEquipment,
                          isExpanded: true,
                          dropdownColor: AppColors.surfaceCard,
                          icon: const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary, size: 20),
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedEquipment = val);
                          },
                          items: _equipmentList.map((eq) {
                            return DropdownMenuItem(value: eq, child: Text(eq == 'All' ? 'All Equipment' : eq));
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedDifficulty,
                          isExpanded: true,
                          dropdownColor: AppColors.surfaceCard,
                          icon: const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary, size: 20),
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedDifficulty = val);
                          },
                          items: _difficulties.map((d) {
                            return DropdownMenuItem(value: d, child: Text(d == 'All' ? 'All Levels' : d));
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Exercise Count Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppColors.background,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SHOWING ${exercises.length} EXERCISES',
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  fontSize: 11,
                ),
              ),
              if (_searchController.text.isNotEmpty ||
                  _selectedCategory != 'All' ||
                  _selectedEquipment != 'All' ||
                  _selectedDifficulty != 'All')
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() {
                      _selectedCategory = 'All';
                      _selectedEquipment = 'All';
                      _selectedDifficulty = 'All';
                    });
                  },
                  child: const Text(
                    'Reset Filters',
                    style: TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.w700, fontSize: 11),
                  ),
                ),
            ],
          ),
        ),

        // Exercise List
        Expanded(
          child: exercises.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.fitness_center_outlined, size: 48, color: AppColors.textTertiary),
                      const SizedBox(height: 12),
                      const Text(
                        'No exercises match your filter',
                        style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Try adjusting your search terms or clearing filters.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: exercises.length,
                  itemBuilder: (context, index) {
                    final ex = exercises[index];
                    return _buildExerciseCard(ex);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildExerciseCard(Exercise ex) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openExerciseDetail(ex),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Thumbnail / GIF indicator
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Center(
                    child: ex.gifUrl.isNotEmpty
                        ? const Icon(Icons.play_circle_fill_rounded, color: AppColors.primaryRed, size: 24)
                        : const Icon(Icons.fitness_center_rounded, color: AppColors.textSecondary, size: 20),
                  ),
                ),
                const SizedBox(width: 12),

                // Title & Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ex.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.glowRed,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              ex.category.toUpperCase(),
                              style: const TextStyle(
                                color: AppColors.primaryRed,
                                fontWeight: FontWeight.w800,
                                fontSize: 9,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            ex.equipment,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.textTertiary),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            ex.difficulty,
                            style: TextStyle(
                              color: ex.difficulty == 'Beginner'
                                  ? AppColors.success
                                  : (ex.difficulty == 'Intermediate' ? AppColors.warning : AppColors.primaryRed),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
