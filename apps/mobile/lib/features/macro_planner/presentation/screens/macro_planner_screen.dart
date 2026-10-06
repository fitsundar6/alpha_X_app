import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/client_theme_service.dart';
import '../../../../core/widgets/alpha_x_widgets.dart';
import '../../data/repositories/macro_repository.dart';
import '../../domain/models/meal_type.dart';
import '../../domain/models/food_log_entry.dart';
import '../../domain/models/daily_macro_summary.dart';
import '../widgets/daily_macro_progress_dashboard.dart';
import '../widgets/add_food_bottom_sheet.dart';
import '../widgets/edit_food_quantity_dialog.dart';
import 'macro_input_screen.dart';
import 'macro_history_screen.dart';
import '../../../food_photo_tracking/presentation/screens/live_food_camera_screen.dart';
import '../../../food_photo_tracking/presentation/screens/my_food_photos_screen.dart';
import '../../domain/models/assigned_diet_plan.dart';

/// Main client hub for Alpha X Macro Planner & Daily Food Tracking
class MacroPlannerScreen extends StatefulWidget {
  final MacroRepository repository;
  final bool showAppBar;

  const MacroPlannerScreen({
    super.key,
    required this.repository,
    this.showAppBar = true,
  });

  @override
  State<MacroPlannerScreen> createState() => _MacroPlannerScreenState();
}

class _MacroPlannerScreenState extends State<MacroPlannerScreen> {
  final _reviewWeightController = TextEditingController();
  final _reviewWaistController = TextEditingController();
  bool _isReviewOpen = false;

  // Date Tracking state
  DateTime _selectedDate = DateTime.now();

  String get _selectedDateString => DateFormat('yyyy-MM-dd').format(_selectedDate);
  bool get _isToday => _selectedDateString == widget.repository.getTodayDateString();

  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_onRepoUpdate);
    final currentWeight = widget.repository.currentInput?.weightKg ?? 81.0;
    _reviewWeightController.text = currentWeight.toStringAsFixed(1);
    _reviewWaistController.text = '83.5';
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    try {
      await widget.repository.fetchAssignedDietPlan();
      await widget.repository.fetchFoodLogsFromBackend(_selectedDateString);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[MacroPlannerScreen] Sync error: $e');
    }
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onRepoUpdate);
    _reviewWeightController.dispose();
    _reviewWaistController.dispose();
    super.dispose();
  }

  void _onRepoUpdate() {
    if (mounted) setState(() {});
  }

  void _prevDay() {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
    widget.repository.fetchFoodLogsFromBackend(_selectedDateString);
  }

  void _nextDay() {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
    });
    widget.repository.fetchFoodLogsFromBackend(_selectedDateString);
  }

  void _jumpToToday() {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedDate = DateTime.now();
    });
    widget.repository.fetchFoodLogsFromBackend(_selectedDateString);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primaryRed,
              onPrimary: Colors.white,
              surface: AppColors.surfaceCard,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: AppColors.surfaceCard,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      HapticFeedback.selectionClick();
      setState(() {
        _selectedDate = picked;
      });
      widget.repository.fetchFoodLogsFromBackend(_selectedDateString);
    }
  }

  void _openAddFood(MealType mealType) {
    AddFoodBottomSheet.show(
      context,
      repository: widget.repository,
      mealType: mealType,
      dateString: _selectedDateString,
    );
  }

  void _openCameraScanner([MealType mealType = MealType.lunch]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => LiveFoodCameraScreen(
          initialMealType: mealType.displayName,
        ),
      ),
    );
  }

  void _openMyFoodPhotos() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => const MyFoodPhotosScreen(),
      ),
    );
  }

  void _openEditFood(FoodLogEntry entry) {
    EditFoodQuantityDialog.show(
      context,
      entry: entry,
      repository: widget.repository,
    );
  }

  void _openInputForm() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => MacroInputScreen(
          repository: widget.repository,
          initialInput: widget.repository.currentInput,
        ),
      ),
    );
  }

  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => MacroHistoryScreen(repository: widget.repository),
      ),
    );
  }

  void _saveReviewAndRecalculate() {
    final weight = double.tryParse(_reviewWeightController.text.trim());
    if (weight == null || weight < 30 || weight > 300) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid weight (30–300 kg)')),
      );
      return;
    }

    final waist = double.tryParse(_reviewWaistController.text.trim());
    widget.repository.recordProgressReview(newWeightKg: weight, waistCm: waist);

    final currentInput = widget.repository.currentInput;
    if (currentInput != null) {
      final updatedInput = currentInput.copyWith(weightKg: weight);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => MacroInputScreen(
            repository: widget.repository,
            initialInput: updatedInput,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClientThemeColors.of(context);
    final currentResult = widget.repository.currentResult;
    final currentInput = widget.repository.currentInput;
    final dailySummary = widget.repository.getDailyMacroSummary(_selectedDateString);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('ALPHA X MACRO PLANNER'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.photo_library_outlined),
                  tooltip: 'Food Photo Journal',
                  onPressed: _openMyFoodPhotos,
                ),
                IconButton(
                  icon: const Icon(Icons.history),
                  tooltip: 'Macro History',
                  onPressed: _openHistory,
                ),
                IconButton(
                  icon: const Icon(Icons.tune_rounded),
                  tooltip: 'Macro Calculator',
                  onPressed: _openInputForm,
                ),
              ],
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        children: [
          // If showAppBar is false, show a clean header row
          if (!widget.showAppBar) ...[
            Row(
              children: [
                const AlphaXLogo.badge(size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ALPHA X MACROS',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        'Daily Food & Macro Tracker',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.photo_library_outlined, size: 20, color: colors.textPrimary),
                  tooltip: 'Food Photo Journal',
                  onPressed: _openMyFoodPhotos,
                ),
                IconButton(
                  icon: Icon(Icons.history, size: 20, color: colors.textPrimary),
                  tooltip: 'Macro History',
                  onPressed: _openHistory,
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // 1. DATE NAVIGATION BAR
          _buildDateSelector(colors),

          const SizedBox(height: 14),

          // 2. UNIFIED HERO NUTRITION DASHBOARD
          if (widget.repository.hasAssignedDietPlan || currentResult != null) ...[
            DailyMacroProgressDashboard(
              summary: dailySummary,
              coachPlanName: widget.repository.hasAssignedDietPlan
                  ? widget.repository.assignedDietPlan!.planName
                  : null,
              coachNotes: widget.repository.hasAssignedDietPlan
                  ? widget.repository.assignedDietPlan!.notes
                  : null,
              goalName: currentInput?.goal.displayName,
              onViewCoachPlan: widget.repository.hasAssignedDietPlan
                  ? () => _showPrescribedMealsSheet(context, widget.repository.assignedDietPlan!)
                  : null,
              onEditTargets: _openInputForm,
            ),
            if (widget.repository.hasAssignedDietPlan) ...[
              const SizedBox(height: 8),
              AlphaXPressable(
                onTap: () => _showPrescribedMealsSheet(context, widget.repository.assignedDietPlan!),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: colors.surfaceCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.primary.withOpacity(0.35)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.restaurant_menu, size: 14, color: colors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Coach Prescribed Meals & Timings (${widget.repository.assignedDietPlan!.meals.length})',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.chevron_right, size: 16, color: colors.primary),
                    ],
                  ),
                ),
              ),
            ],
          ] else ...[
            _buildEmptyTargetsCard(colors),
          ],

          const SizedBox(height: 18),

          // 3. TODAY'S FOOD & MEAL LOGS
          _buildDailyFoodTracker(dailySummary, colors),

          const SizedBox(height: 16),

          // 4. WEEKLY BODY CHECK-IN (PROGRESS REVIEW)
          _buildWeeklyCheckInCard(colors),

          const SizedBox(height: 14),

          // 5. RECALCULATE & HISTORY SHORTCUTS
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openInputForm,
                  icon: const Icon(Icons.tune_rounded, size: 15),
                  label: const Text('RECALCULATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.textPrimary,
                    side: BorderSide(color: colors.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openHistory,
                  icon: const Icon(Icons.history, size: 15),
                  label: const Text('HISTORY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.textPrimary,
                    side: BorderSide(color: colors.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // --- WIDGET BUILDER: DATE NAVIGATION BAR ---
  Widget _buildDateSelector(ClientThemeColors colors) {
    final dateDisplay = _isToday
        ? 'TODAY • ${DateFormat("d MMM").format(_selectedDate).toUpperCase()}'
        : DateFormat("EEE, d MMM").format(_selectedDate).toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          // Previous Day Arrow
          AlphaXPressable(
            onTap: _prevDay,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: colors.border),
              ),
              child: Icon(Icons.chevron_left, size: 16, color: colors.textPrimary),
            ),
          ),
          const SizedBox(width: 6),

          // Active Date Picker Button
          Expanded(
            child: AlphaXPressable(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _isToday ? colors.primary : colors.surfaceElevated,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: _isToday ? colors.primary : colors.border,
                  ),
                  boxShadow: _isToday
                      ? [
                          BoxShadow(
                            color: colors.primary.withOpacity(0.35),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 12,
                      color: _isToday ? colors.onPrimary : colors.textPrimary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        dateDisplay,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: _isToday ? colors.onPrimary : colors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Next Day Arrow (or Today shortcut if in past)
          if (!_isToday) ...[
            AlphaXPressable(
              onTap: _jumpToToday,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withOpacity(0.35),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Text(
                  'TODAY',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: colors.onPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          AlphaXPressable(
            onTap: _nextDay,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: colors.border),
              ),
              child: Icon(Icons.chevron_right, size: 16, color: colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET BUILDER: TODAY'S FOOD & MEAL LOGS ---
  Widget _buildDailyFoodTracker(DailyMacroSummary dailySummary, ClientThemeColors colors) {
    final title = _isToday ? 'TODAY\'S MEALS' : '${DateFormat("d MMMM").format(_selectedDate).toUpperCase()}\'S MEALS';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: colors.surfaceElevated,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: colors.borderSubtle),
                    ),
                    child: Text(
                      '${dailySummary.totalMealsLogged}/4 logged',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AlphaXPressable(
              onTap: _openMyFoodPhotos,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.surfaceElevated,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.photo_library_outlined, size: 12, color: colors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'PHOTOS',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 4 Meal Sections (Breakfast, Lunch, Snack, Dinner)
        ...MealType.values.map((meal) {
          final mealSummary = dailySummary.mealSummaries[meal]!;
          return _buildMealSectionCard(meal, mealSummary, colors);
        }),
      ],
    );
  }

  Widget _buildMealSectionCard(MealType meal, MealNutritionSummary mealSummary, ClientThemeColors colors) {
    final hasEntries = mealSummary.entries.isNotEmpty;
    final cal = mealSummary.totalCalories.round();
    final prot = FoodLogEntry.formatMacro(mealSummary.totalProtein);
    final carbs = FoodLogEntry.formatMacro(mealSummary.totalCarbs);
    final fat = FoodLogEntry.formatMacro(mealSummary.totalFat);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(colors.isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Meal Header Row
          Row(
            children: [
              Text(meal.iconEmoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                meal.displayName.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: 6),
              if (hasEntries)
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: colors.surfaceElevated,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: colors.borderSubtle),
                    ),
                    child: Text(
                      '$cal kcal • P:${prot}g C:${carbs}g F:${fat}g',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: colors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
              else
                const Spacer(),
              if (hasEntries) const SizedBox(width: 6),
              // Quick Add Action
              AlphaXPressable(
                onTap: () => _openAddFood(meal),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.primary.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 14, color: colors.primary),
                      const SizedBox(width: 2),
                      Text(
                        'ADD',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: colors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Quick Camera Scan Action
              AlphaXPressable(
                onTap: () => _openCameraScanner(meal),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.border),
                  ),
                  child: Icon(Icons.camera_alt_outlined, size: 14, color: colors.textSecondary),
                ),
              ),
            ],
          ),

          // Food Items List or Compact Empty State
          if (hasEntries) ...[
            const SizedBox(height: 10),
            ...mealSummary.entries.map((entry) => _buildFoodEntryRow(entry, colors)),
          ] else ...[
            const SizedBox(height: 8),
            AlphaXPressable(
              onTap: () => _openAddFood(meal),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline, size: 14, color: colors.textTertiary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'No food logged yet • Tap to add',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: colors.textTertiary,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFoodEntryRow(FoodLogEntry entry, ClientThemeColors colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.foodName,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: colors.surfaceElevated,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '× ${entry.quantityDisplay}',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: colors.textPrimary,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    _buildSourceBadge(entry.source),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.totalCalories.round()} kcal • P:${FoodLogEntry.formatMacro(entry.totalProtein)}g C:${FoodLogEntry.formatMacro(entry.totalCarbs)}g F:${FoodLogEntry.formatMacro(entry.totalFat)}g',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: colors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined, size: 15, color: colors.textSecondary),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'Edit quantity',
            onPressed: () => _openEditFood(entry),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 15, color: colors.textTertiary),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'Delete item',
            onPressed: () {
              HapticFeedback.lightImpact();
              widget.repository.deleteFoodEntry(entry.id);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyCheckInCard(ClientThemeColors colors) {
    final currentWeight = widget.repository.currentInput?.weightKg ?? 81.0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AlphaXPressable(
            onTap: () => setState(() => _isReviewOpen = !_isReviewOpen),
            child: Row(
              children: [
                Icon(Icons.monitor_weight_outlined, size: 16, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'WEEKLY BODY CHECK-IN',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: colors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: colors.borderSubtle),
                  ),
                  child: Text(
                    '${currentWeight.toStringAsFixed(1)} kg',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  _isReviewOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 18,
                  color: colors.textSecondary,
                ),
              ],
            ),
          ),
          if (_isReviewOpen) ...[
            const SizedBox(height: 10),
            Text(
              'Update your body weight to refresh your macro baseline. Weight fluctuates daily with hydration, so track weekly trends.',
              style: TextStyle(fontSize: 11, color: colors.textTertiary, height: 1.3),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Current Weight', style: TextStyle(fontSize: 10, color: colors.textSecondary, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 5),
                      TextFormField(
                        controller: _reviewWeightController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(fontSize: 13, color: colors.textPrimary),
                        decoration: InputDecoration(
                          suffixText: 'kg',
                          isDense: true,
                          filled: true,
                          fillColor: colors.surface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: colors.borderSubtle)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: colors.borderSubtle)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Waist (Optional)', style: TextStyle(fontSize: 10, color: colors.textSecondary, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 5),
                      TextFormField(
                        controller: _reviewWaistController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(fontSize: 13, color: colors.textPrimary),
                        decoration: InputDecoration(
                          suffixText: 'cm',
                          isDense: true,
                          filled: true,
                          fillColor: colors.surface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: colors.borderSubtle)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: colors.borderSubtle)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveReviewAndRecalculate,
                icon: const Icon(Icons.trending_up, size: 15),
                label: const Text('UPDATE WEIGHT & RECALCULATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.surfaceElevated,
                  foregroundColor: colors.textPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: colors.border),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyTargetsCard(ClientThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.calculate_outlined, size: 40, color: colors.primary),
          const SizedBox(height: 12),
          Text(
            'No Active Targets Found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: colors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Calculate your baseline daily energy and macronutrient targets in less than 60 seconds.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _openInputForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('START MACRO PLANNER', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _showPrescribedMealsSheet(BuildContext context, AssignedDietPlan plan) {
    final colors = ClientThemeColors.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: colors.surfaceCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: colors.primary, width: 2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.planName.toUpperCase(),
                        style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Assigned by ${plan.assignedByName ?? "Coach"} • Version ${plan.version}',
                        style: TextStyle(color: colors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: colors.textSecondary),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: colors.borderSubtle, height: 1),
            const SizedBox(height: 12),
            Expanded(
              child: plan.meals.isEmpty
                  ? Center(
                      child: Text('No structured meals prescribed yet.', style: TextStyle(color: colors.textSecondary)),
                    )
                  : ListView.builder(
                      itemCount: plan.meals.length,
                      itemBuilder: (context, index) {
                        final meal = plan.meals[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colors.surfaceElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colors.borderSubtle),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    meal.name.toUpperCase(),
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  if (meal.timing.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: colors.primary.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: colors.primary.withOpacity(0.5)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.access_time, size: 11, color: colors.primary),
                                          const SizedBox(width: 4),
                                          Text(
                                            meal.timing,
                                            style: TextStyle(color: colors.primary, fontSize: 10, fontWeight: FontWeight.w800),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              if (meal.items.isEmpty) ...[
                                const SizedBox(height: 8),
                                Text('No specific foods listed.', style: TextStyle(color: colors.textTertiary, fontSize: 12)),
                              ] else ...[
                                const SizedBox(height: 10),
                                ...meal.items.map((item) {
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: colors.surfaceCard,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: colors.border),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 38,
                                          height: 38,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: colors.surfaceElevated,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            PrescribedFoodItem.getFoodEmoji(item.name),
                                            style: const TextStyle(fontSize: 18),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.name,
                                                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${item.calories.round()} kcal • P:${item.protein.round()}g C:${item.carbs.round()}g F:${item.fat.round()}g',
                                                style: TextStyle(color: colors.textSecondary, fontSize: 11),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: colors.primary.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: colors.primary.withOpacity(0.5)),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                item.simpleQuantityDisplay,
                                                style: TextStyle(
                                                  color: colors.textPrimary,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              if (item.servings > 0 &&
                                                  item.unit != 'piece' &&
                                                  item.unit != 'pieces' &&
                                                  item.unit != 'serving' &&
                                                  item.unit != 'egg' &&
                                                  item.unit != 'eggs')
                                                Text(
                                                  item.servings == 1 ? '1 serving' : '${item.servingsDisplay} servings',
                                                  style: TextStyle(
                                                    color: colors.textTertiary,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceBadge(String source) {
    if (source == 'AI_CAMERA') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
        decoration: BoxDecoration(
          color: Colors.tealAccent.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.tealAccent.withOpacity(0.6), width: 0.8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.camera_alt, size: 9, color: Colors.tealAccent),
            SizedBox(width: 3),
            Text(
              'AI CAMERA',
              style: TextStyle(color: Colors.tealAccent, fontSize: 9, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      );
    } else if (source == 'CUSTOM_FOOD') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.amber.withOpacity(0.6), width: 0.8),
        ),
        child: const Text(
          'CUSTOM',
          style: TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.w800),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
        decoration: BoxDecoration(
          color: Colors.blueAccent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.blueAccent.withOpacity(0.4), width: 0.8),
        ),
        child: const Text(
          'LIBRARY',
          style: TextStyle(color: Colors.lightBlueAccent, fontSize: 9, fontWeight: FontWeight.w800),
        ),
      );
    }
  }
}

