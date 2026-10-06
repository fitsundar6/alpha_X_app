import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
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
    final currentResult = widget.repository.currentResult;
    final currentInput = widget.repository.currentInput;
    final dailySummary = widget.repository.getDailyMacroSummary(_selectedDateString);

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('ALPHA X MACRO PLANNER'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.history, color: AppColors.textPrimary),
                  tooltip: 'Macro History',
                  onPressed: _openHistory,
                ),
              ],
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        children: [
          // Brand Header Pill
          Row(
            children: [
              const AlphaXLogo.badge(size: 32),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('ALPHA X MACRO PLANNER', style: AppTypography.headlineSmall),
                  Text('Daily Food & Macro Tracker', style: AppTypography.bodySmall),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // --- DATE TRACKING SELECTOR ---
          _buildDateSelector(),

          const SizedBox(height: 16),

          // --- SECTION 1: TRAINER ASSIGNED DIET PLAN (OR CALCULATED TARGET) ---
          if (widget.repository.hasAssignedDietPlan) ...[
            _buildAssignedDietCard(widget.repository.assignedDietPlan!),
          ] else if (currentResult != null && currentInput != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'MY DAILY TARGETS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Text(
                          currentInput.goal.displayName,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Prescribed Protocol: ${DateFormat('d MMMM yyyy').format(currentResult.calculatedAt)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: 14),

                  // Big Calorie Headline
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        currentResult.targetCalories.toString().replaceAllMapped(
                          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                          (Match m) => '${m[1]},',
                        ),
                        style: AppTypography.displayLarge.copyWith(fontSize: 34),
                      ),
                      const SizedBox(width: 8),
                      const Text('kcal / day', style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Estimated Maintenance: ${currentResult.maintenanceCalories} kcal/day',
                    style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                  ),

                  const SizedBox(height: 14),
                  const Divider(color: AppColors.borderSubtle, height: 1),
                  const SizedBox(height: 12),

                  // Macronutrients Grid
                  Row(
                    children: [
                      Expanded(
                        child: _MacroCompactItem(
                          label: 'Protein',
                          value: '${currentResult.proteinGrams}g',
                          range: currentResult.proteinRange.display,
                          color: AppColors.accentRed,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MacroCompactItem(
                          label: 'Carbs',
                          value: '${currentResult.carbGrams}g',
                          range: currentResult.carbRange.display,
                          color: AppColors.info,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MacroCompactItem(
                          label: 'Fat',
                          value: '${currentResult.fatGrams}g',
                          range: currentResult.fatRange.display,
                          color: AppColors.gold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Recalculate & View History Action Row
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _openInputForm,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('RECALCULATE'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _openHistory,
                          icon: const Icon(Icons.history, size: 16),
                          label: const Text('VIEW HISTORY'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            // Empty State
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  const Icon(Icons.calculate_outlined, size: 48, color: AppColors.primaryRed),
                  const SizedBox(height: 14),
                  const Text('No Active Targets Found', style: AppTypography.headlineSmall),
                  const SizedBox(height: 6),
                  const Text(
                    'Calculate your baseline daily energy and macronutrient targets in less than 60 seconds.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: _openInputForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('START MACRO PLANNER', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 18),

          // --- SECTION 7 & 13: TODAY'S MACRO PROGRESS DASHBOARD ---
          DailyMacroProgressDashboard(summary: dailySummary),

          const SizedBox(height: 22),

          // --- SECTION 2, 3, 9: TODAY'S FOOD & MEAL LOGS ---
          _buildDailyFoodTracker(dailySummary),

          const SizedBox(height: 24),

          // REVIEW YOUR TARGET PROGRESS CHECK-IN SECTION
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.monitor_weight_outlined, size: 18, color: AppColors.primaryRed),
                        SizedBox(width: 8),
                        Text(
                          'REVIEW YOUR TARGET',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(_isReviewOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 20),
                      onPressed: () => setState(() => _isReviewOpen = !_isReviewOpen),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Your current target is based on your previous data.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Body weight naturally fluctuates daily due to hydration, glycogen, and sodium. Avoid recalculating targets based on single-day changes.',
                  style: TextStyle(fontSize: 11, color: AppColors.textTertiary, height: 1.35),
                ),

                if (_isReviewOpen) ...[
                  const SizedBox(height: 14),
                  const Divider(color: AppColors.borderSubtle, height: 1),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Current Weight', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _reviewWeightController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                suffixText: 'kg',
                                isDense: true,
                                filled: true,
                                fillColor: AppColors.surface,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderSubtle)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderSubtle)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Waist (Optional)', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _reviewWaistController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                suffixText: 'cm',
                                isDense: true,
                                filled: true,
                                fillColor: AppColors.surface,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderSubtle)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderSubtle)),
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
                      icon: const Icon(Icons.trending_up, size: 16),
                      label: const Text('UPDATE WEIGHT & RECALCULATE'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surfaceElevated,
                        foregroundColor: AppColors.textPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Primary Calculate Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openInputForm,
              icon: const Icon(Icons.calculate, size: 18),
              label: const Text(
                'NEW MACRO CALCULATION',
                style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.8),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // --- WIDGET BUILDER: DATE NAVIGATION BAR ---
  Widget _buildDateSelector() {
    final prevDate = _selectedDate.subtract(const Duration(days: 1));
    final nextDate = _selectedDate.add(const Duration(days: 1));
    final dateDisplay = _isToday
        ? 'TODAY • ${DateFormat("d MMMM").format(_selectedDate).toUpperCase()}'
        : DateFormat("EEE, d MMM yyyy").format(_selectedDate).toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous Day Arrow
          AlphaXPressable(
            onTap: _prevDay,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.chevron_left, size: 16, color: AppColors.textPrimary),
                  Text(
                    DateFormat('d MMM').format(prevDate),
                    style: const TextStyle(fontFamily: 'Poppins', color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),

          // Active Date Picker Button
          AlphaXPressable(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _isToday ? AppColors.primary : AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: _isToday ? AppColors.primary : AppColors.border,
                ),
                boxShadow: _isToday
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.35),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 13,
                    color: _isToday ? AppColors.onPrimary : Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    dateDisplay,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: _isToday ? AppColors.onPrimary : Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Next Day Arrow (or Today shortcut if in past)
          if (!_isToday) ...[
            AlphaXPressable(
              onTap: _jumpToToday,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.35),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Text(
                  'TODAY',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: AppColors.onPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ] else ...[
            AlphaXPressable(
              onTap: _nextDay,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('d MMM').format(nextDate),
                      style: const TextStyle(fontFamily: 'Poppins', color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    const Icon(Icons.chevron_right, size: 16, color: AppColors.textPrimary),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- WIDGET BUILDER: TODAY'S FOOD & MEAL LOGS ---
  Widget _buildDailyFoodTracker(DailyMacroSummary dailySummary) {
    final title = _isToday ? 'TODAY\'S FOOD' : '${DateFormat("d MMMM").format(_selectedDate).toUpperCase()}\'S FOOD';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 1.1,
              ),
            ),
            Row(
              children: [
                AlphaXPressable(
                  onTap: () => _openCameraScanner(MealType.lunch),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.primaryRed),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.camera_alt, size: 13, color: AppColors.primaryRed),
                        SizedBox(width: 4),
                        Text(
                          '📷 SCAN FOOD',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                AlphaXPressable(
                  onTap: () => _openAddFood(MealType.snack),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.restaurant_menu, size: 13, color: AppColors.primaryRed),
                        SizedBox(width: 4),
                        Text(
                          'FOOD LIBRARY',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${dailySummary.totalMealsLogged} / 4 logged',
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Log your actual meals to monitor nutrition against your target.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 14),

        // LIVE FOOD PHOTO TRACKING & TRAINER VERIFICATION BANNER
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.surfaceCard,
                AppColors.primaryRed.withOpacity(0.12),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primaryRed.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primaryRed),
                ),
                child: const Icon(Icons.camera_alt, color: AppColors.primaryRed, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LIVE FOOD PHOTO TRACKING',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Take a live camera photo of your meal for your trainer to review.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: _openMyFoodPhotos,
                      child: Row(
                        children: const [
                          Icon(Icons.history, size: 12, color: AppColors.primaryRed),
                          SizedBox(width: 4),
                          Text(
                            'View My Food Photos History →',
                            style: TextStyle(
                              color: AppColors.primaryRed,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _openCameraScanner(MealType.lunch),
                icon: const Icon(Icons.photo_camera, size: 14),
                label: const Text('PHOTO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),

        // 4 Meal Sections (Breakfast, Lunch, Snack, Dinner)
        ...MealType.values.map((meal) {
          final mealSummary = dailySummary.mealSummaries[meal]!;
          return _buildMealSectionCard(meal, mealSummary);
        }),

        const SizedBox(height: 8),

        // Section 13: DAILY TOTAL SUMMARY CARD
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primaryRed.withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryRed.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'DAILY TOTAL',
                    style: TextStyle(
                      color: AppColors.primaryRed,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    '${dailySummary.consumedCalories.round()} kcal',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _dailySummaryMacroItem('Protein', '${FoodLogEntry.formatMacro(dailySummary.consumedProtein)} g', AppColors.accentRed),
                  _dailySummaryMacroItem('Carbs', '${FoodLogEntry.formatMacro(dailySummary.consumedCarbs)} g', AppColors.info),
                  _dailySummaryMacroItem('Fat', '${FoodLogEntry.formatMacro(dailySummary.consumedFat)} g', AppColors.gold),
                  if (dailySummary.consumedFiber > 0)
                    _dailySummaryMacroItem('Fiber', '${FoodLogEntry.formatMacro(dailySummary.consumedFiber)} g', AppColors.success),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dailySummaryMacroItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }

  Widget _buildMealSectionCard(MealType meal, MealNutritionSummary mealSummary) {
    final cal = mealSummary.totalCalories.round();
    final prot = FoodLogEntry.formatMacro(mealSummary.totalProtein);
    final carbs = FoodLogEntry.formatMacro(mealSummary.totalCarbs);
    final fat = FoodLogEntry.formatMacro(mealSummary.totalFat);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Meal Header Row
          Row(
            children: [
              Text(meal.iconEmoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                meal.displayName.toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              // Meal Total Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Text(
                  '$cal kcal • P:${prot}g C:${carbs}g F:${fat}g',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Logged Food Items List
          if (mealSummary.entries.isNotEmpty) ...[
            ...mealSummary.entries.map((entry) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderSubtle),
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
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceElevated,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '× ${entry.quantityDisplay}',
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    color: AppColors.textPrimary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              _buildSourceBadge(entry.source),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${entry.totalCalories.round()} kcal  •  P: ${FoodLogEntry.formatMacro(entry.totalProtein)}g  C: ${FoodLogEntry.formatMacro(entry.totalCarbs)}g  F: ${FoodLogEntry.formatMacro(entry.totalFat)}g',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.textSecondary),
                      tooltip: 'Edit quantity',
                      onPressed: () => _openEditFood(entry),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: AppColors.textTertiary),
                      tooltip: 'Delete item',
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        widget.repository.deleteFoodEntry(entry.id);
                      },
                    ),
                  ],
                ),
              );
            }),

            // Section 6: BREAKFAST TOTAL / MEAL TOTAL BOX
            Container(
              margin: const EdgeInsets.only(top: 4, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${meal.displayName.toUpperCase()} TOTAL',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    '$cal kcal  •  P: ${prot}g  C: ${carbs}g  Fat: ${fat}g',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No foods logged yet for ${meal.displayName}.',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  color: AppColors.textTertiary,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],

          // Action Buttons: Add Food & Scan Food with Live Camera
          Row(
            children: [
              Expanded(
                flex: 3,
                child: AlphaXPressable(
                  onTap: () => _openAddFood(meal),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.add_rounded, size: 16, color: AppColors.onPrimary),
                        SizedBox(width: 4),
                        Text(
                          'ADD FOOD',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: AppColors.onPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: AlphaXPressable(
                  onTap: () => _openCameraScanner(meal),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.camera_alt, size: 15, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text(
                          '📷 SCAN FOOD',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAssignedDietCard(AssignedDietPlan plan) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryRed.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryRed.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primaryRed),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified, size: 12, color: AppColors.primaryRed),
                    const SizedBox(width: 4),
                    Text(
                      'PRESCRIBED BY COACH (v${plan.version})',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: AppColors.primaryRed,
                      ),
                    ),
                  ],
                ),
              ),
              if (plan.assignedByName != null)
                Text(
                  'Coach: ${plan.assignedByName}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            plan.planName,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),

          // Daily Targets
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${plan.dailyCalories}',
                style: AppTypography.displayLarge.copyWith(fontSize: 32),
              ),
              const SizedBox(width: 6),
              const Text('kcal / day target', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: AppColors.borderSubtle, height: 1),
          const SizedBox(height: 10),

          // Macros Grid
          Row(
            children: [
              Expanded(
                child: _MacroCompactItem(
                  label: 'Protein',
                  value: '${plan.protein.round()}g',
                  range: 'Target',
                  color: AppColors.accentRed,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MacroCompactItem(
                  label: 'Carbs',
                  value: '${plan.carbs.round()}g',
                  range: 'Target',
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MacroCompactItem(
                  label: 'Fat',
                  value: '${plan.fat.round()}g',
                  range: 'Target',
                  color: AppColors.gold,
                ),
              ),
              if (plan.fiber > 0) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _MacroCompactItem(
                    label: 'Fiber',
                    value: '${plan.fiber.round()}g',
                    range: 'Target',
                    color: AppColors.success,
                  ),
                ),
              ],
            ],
          ),

          if (plan.notes != null && plan.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.sticky_note_2_outlined, size: 14, color: AppColors.gold),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      plan.notes!,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primaryRed),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.restaurant_menu, size: 14, color: AppColors.primaryRed),
              label: Text(
                'VIEW PRESCRIBED MEALS & TIMINGS (${plan.meals.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              onPressed: () => _showPrescribedMealsSheet(context, plan),
            ),
          ),
        ],
      ),
    );
  }

  void _showPrescribedMealsSheet(BuildContext context, AssignedDietPlan plan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: const BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppColors.primaryRed, width: 2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
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
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Assigned by ${plan.assignedByName ?? "Coach"} • Version ${plan.version}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: AppColors.borderSubtle, height: 1),
            const SizedBox(height: 12),
            Expanded(
              child: plan.meals.isEmpty
                  ? const Center(
                      child: Text('No structured meals prescribed yet.', style: TextStyle(color: AppColors.textSecondary)),
                    )
                  : ListView.builder(
                      itemCount: plan.meals.length,
                      itemBuilder: (context, index) {
                        final meal = plan.meals[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    meal.name.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  if (meal.timing.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryRed.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AppColors.primaryRed.withOpacity(0.5)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.access_time, size: 11, color: AppColors.primaryRed),
                                          const SizedBox(width: 4),
                                          Text(
                                            meal.timing,
                                            style: const TextStyle(color: AppColors.primaryRed, fontSize: 10, fontWeight: FontWeight.w800),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              if (meal.items.isEmpty) ...[
                                const SizedBox(height: 8),
                                const Text('No specific foods listed.', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                              ] else ...[
                                const SizedBox(height: 10),
                                ...meal.items.map((item) {
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceCard,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 38,
                                          height: 38,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceElevated,
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
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${item.calories.round()} kcal • P:${item.protein.round()}g C:${item.carbs.round()}g F:${item.fat.round()}g',
                                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryRed.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AppColors.primaryRed.withOpacity(0.5)),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                item.simpleQuantityDisplay,
                                                style: const TextStyle(
                                                  color: Colors.white,
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
                                                  style: const TextStyle(
                                                    color: AppColors.textTertiary,
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

class _MacroCompactItem extends StatelessWidget {
  final String label;
  final String value;
  final String range;
  final Color color;

  const _MacroCompactItem({
    required this.label,
    required this.value,
    required this.range,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(range, style: const TextStyle(fontSize: 10, color: AppColors.textTertiary)),
        ],
      ),
    );
  }
}
