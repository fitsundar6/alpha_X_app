import 'package:flutter/material.dart';
import 'package:alpha_x_gym/core/theme/app_colors.dart';
import 'package:alpha_x_gym/features/exercise/domain/models/exercise_model.dart';
import 'package:alpha_x_gym/features/exercise/data/repositories/exercise_repository.dart';
import 'package:alpha_x_gym/features/workout/data/repositories/workout_repository.dart';
import 'admin_create_edit_exercise_screen.dart';
import '../widgets/exercise_detail_modal.dart';

class AdminExerciseDatabaseScreen extends StatefulWidget {
  final WorkoutRepository? workoutRepository;

  const AdminExerciseDatabaseScreen({
    super.key,
    this.workoutRepository,
  });

  @override
  State<AdminExerciseDatabaseScreen> createState() =>
      _AdminExerciseDatabaseScreenState();
}

class _AdminExerciseDatabaseScreenState
    extends State<AdminExerciseDatabaseScreen> {
  final ExerciseRepository _repo = ExerciseRepository();
  final TextEditingController _searchController = TextEditingController();

  String _selectedCategory = 'All';
  final String _selectedEquipment = 'All';
  final String _selectedDifficulty = 'All';
  final String _selectedMovement = 'All';
  bool _showArchived = false;
  ExerciseSortOption _sortOption = ExerciseSortOption.nameAsc;

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
      movementPattern: _selectedMovement == 'All' ? null : _selectedMovement,
      includeArchived: _showArchived,
      sort: _sortOption,
    );
  }

  void _openCreateExercise() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AdminCreateEditExerciseScreen(),
      ),
    );
  }

  void _openEditExercise(Exercise exercise) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminCreateEditExerciseScreen(
          exerciseToEdit: exercise,
        ),
      ),
    );
  }

  void _duplicateExercise(Exercise exercise) {
    _repo.duplicateExercise(exercise.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Duplicated "${exercise.displayName}"'),
        backgroundColor: AppColors.primaryRed,
      ),
    );
  }

  void _toggleArchiveExercise(Exercise exercise) {
    if (exercise.isActive) {
      // Safety check: is exercise used in history?
      final isUsed = widget.workoutRepository?.isExerciseUsedInHistory(exercise.id) ?? false;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceElevated,
          title: const Text('Archive Exercise', style: TextStyle(color: AppColors.textPrimary)),
          content: Text(
            isUsed
                ? 'This exercise has been logged in historical workout sessions. Archiving it will preserve all historical client records while hiding it from future workout builders.'
                : 'Are you sure you want to archive "${exercise.displayName}"? It will be hidden from the active exercise list.',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
              onPressed: () {
                _repo.archiveExercise(exercise.id);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Archived "${exercise.displayName}" safely.'),
                    backgroundColor: AppColors.warning,
                  ),
                );
              },
              child: const Text('Archive', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    } else {
      _repo.restoreExercise(exercise.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restored "${exercise.displayName}" to active library.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _openCustomEquipmentDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Manage Equipment',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add custom equipment to the gym database:',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'e.g. Belt Squat, Glute Ham Developer...',
                  hintStyle: const TextStyle(color: AppColors.textTertiary),
                  filled: true,
                  fillColor: AppColors.surfaceCard,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Available Equipment Library:',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _repo.availableEquipment.map((eq) {
                      return Chip(
                        label: Text(eq, style: const TextStyle(fontSize: 11, color: AppColors.textPrimary)),
                        backgroundColor: AppColors.surfaceCard,
                        side: const BorderSide(color: AppColors.border),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed),
            onPressed: () {
              final text = textController.text.trim();
              if (text.isNotEmpty) {
                _repo.addCustomEquipment(text);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Add Equipment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exercises = _filteredExercises;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryRed,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'ALPHA X',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'EXERCISE DATABASE',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
                fontSize: 15,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.fitness_center, color: AppColors.textSecondary, size: 20),
            tooltip: 'Manage Equipment',
            onPressed: _openCustomEquipmentDialog,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: _openCreateExercise,
              icon: const Icon(Icons.add, size: 16, color: Colors.white),
              label: const Text(
                '+ ADD EXERCISE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filters Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            color: AppColors.surface,
            child: Column(
              children: [
                // Search Input
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search by exercise name, muscle, equipment, pattern...',
                    hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                    prefixIcon: const Icon(Icons.search, color: AppColors.textTertiary, size: 18),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16, color: AppColors.textTertiary),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.surfaceCard,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                ),
                const SizedBox(height: 8),

                // Category Filter Chips
                SizedBox(
                  height: 34,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
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

                // Secondary Filter Controls Row
                Row(
                  children: [
                    // Sort Dropdown
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCard,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<ExerciseSortOption>(
                            value: _sortOption,
                            isExpanded: true,
                            dropdownColor: AppColors.surfaceElevated,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 11),
                            items: const [
                              DropdownMenuItem(value: ExerciseSortOption.nameAsc, child: Text('Sort: Name (A–Z)')),
                              DropdownMenuItem(value: ExerciseSortOption.nameDesc, child: Text('Sort: Name (Z–A)')),
                              DropdownMenuItem(value: ExerciseSortOption.categoryAsc, child: Text('Sort: Category')),
                              DropdownMenuItem(value: ExerciseSortOption.recentlyUpdated, child: Text('Sort: Updated')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _sortOption = val);
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Archived Toggle Chip
                    FilterChip(
                      label: Text(
                        _showArchived ? 'Include Archived' : 'Active Only',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _showArchived ? AppColors.warning : AppColors.textSecondary,
                        ),
                      ),
                      selected: _showArchived,
                      selectedColor: AppColors.warning.withOpacity(0.2),
                      backgroundColor: AppColors.surfaceCard,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: _showArchived ? AppColors.warning : AppColors.border,
                        ),
                      ),
                      onSelected: (val) => setState(() => _showArchived = val),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Count & Status indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${exercises.length} EXERCISES FOUND',
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  '${_repo.activeExercises.length} Active • ${_repo.archivedExercises.length} Archived',
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                ),
              ],
            ),
          ),

          // Exercises List View
          Expanded(
            child: exercises.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.search_off_rounded, size: 52, color: AppColors.textTertiary),
                          const SizedBox(height: 12),
                          const Text(
                            'No Exercises Matched Filter',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Try clearing search or filters to see available exercises.',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _openCreateExercise,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Create New Exercise'),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    itemCount: exercises.length,
                    itemBuilder: (ctx, index) {
                      final ex = exercises[index];
                      return _buildExerciseCard(ex);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateExercise,
        backgroundColor: AppColors.primaryRed,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          '+ ADD EXERCISE',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }

  Widget _buildExerciseCard(Exercise ex) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ex.isActive ? AppColors.border : AppColors.warning.withOpacity(0.4),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => ExerciseDetailModal.show(
          context,
          ex,
          onEdit: () => _openEditExercise(ex),
          onDuplicate: () => _duplicateExercise(ex),
          onToggleArchive: () => _toggleArchiveExercise(ex),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: ex.isActive
                                    ? AppColors.primaryRed.withOpacity(0.18)
                                    : AppColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                ex.category.toUpperCase(),
                                style: TextStyle(
                                  color: ex.isActive ? AppColors.primaryRed : AppColors.textTertiary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                ex.equipment,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (!ex.isActive) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'ARCHIVED',
                                  style: TextStyle(
                                    color: AppColors.warning,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          ex.displayName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: AppColors.textTertiary, size: 20),
                    color: AppColors.surfaceElevated,
                    onSelected: (action) {
                      switch (action) {
                        case 'details':
                          ExerciseDetailModal.show(
                            context,
                            ex,
                            onEdit: () => _openEditExercise(ex),
                            onDuplicate: () => _duplicateExercise(ex),
                            onToggleArchive: () => _toggleArchiveExercise(ex),
                          );
                          break;
                        case 'edit':
                          _openEditExercise(ex);
                          break;
                        case 'duplicate':
                          _duplicateExercise(ex);
                          break;
                        case 'archive':
                          _toggleArchiveExercise(ex);
                          break;
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'details',
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 18, color: AppColors.textPrimary),
                            SizedBox(width: 10),
                            Text('View Details'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18, color: AppColors.textPrimary),
                            SizedBox(width: 10),
                            Text('Edit Exercise'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'duplicate',
                        child: Row(
                          children: [
                            Icon(Icons.copy_outlined, size: 18, color: AppColors.textPrimary),
                            SizedBox(width: 10),
                            Text('Duplicate'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'archive',
                        child: Row(
                          children: [
                            Icon(
                              ex.isActive ? Icons.archive_outlined : Icons.unarchive_outlined,
                              size: 18,
                              color: ex.isActive ? AppColors.warning : AppColors.success,
                            ),
                            const SizedBox(width: 10),
                            Text(ex.isActive ? 'Archive' : 'Restore'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.adjust, size: 14, color: AppColors.primaryRed),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      ex.primaryMusclesDisplay,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ),
                  Text(
                    '${ex.difficulty} • ${ex.movementPattern}',
                    style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
