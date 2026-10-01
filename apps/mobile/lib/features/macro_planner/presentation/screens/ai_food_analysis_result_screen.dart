import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/repositories/macro_repository.dart';
import '../../domain/models/food_item.dart';
import '../../domain/models/meal_type.dart';
import '../../domain/models/scanned_food_detection.dart';

/// Screen displaying AI Food Camera Scanner results
/// Allows athlete to review, edit portions, change meal category, and confirm addition to Food Log
class AiFoodAnalysisResultScreen extends StatefulWidget {
  final AiMealScanResult scanResult;
  final MacroRepository repository;
  final MealType initialMealType;
  final String dateString;

  const AiFoodAnalysisResultScreen({
    super.key,
    required this.scanResult,
    required this.repository,
    this.initialMealType = MealType.lunch,
    required this.dateString,
  });

  @override
  State<AiFoodAnalysisResultScreen> createState() => _AiFoodAnalysisResultScreenState();
}

class _AiFoodAnalysisResultScreenState extends State<AiFoodAnalysisResultScreen> {
  late List<ScannedFoodItem> _foods;
  late MealType _selectedMealType;
  late TextEditingController _mealNameController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _foods = List<ScannedFoodItem>.from(widget.scanResult.foods);
    _selectedMealType = widget.initialMealType;
    _mealNameController = TextEditingController(text: widget.scanResult.mealName);
  }

  @override
  void dispose() {
    _mealNameController.dispose();
    super.dispose();
  }

  // Live dynamic totals
  double get _totalCalories => _foods.fold(0.0, (acc, f) => acc + f.calories);
  double get _totalProtein => _foods.fold(0.0, (acc, f) => acc + f.protein);
  double get _totalCarbs => _foods.fold(0.0, (acc, f) => acc + f.carbs);
  double get _totalFat => _foods.fold(0.0, (acc, f) => acc + f.fat);
  double get _totalFiber => _foods.fold(0.0, (acc, f) => acc + f.fiber);

  void _editPortionDialog(int index) {
    final food = _foods[index];
    final controller = TextEditingController(
      text: food.estimatedGrams % 1 == 0
          ? food.estimatedGrams.toInt().toString()
          : food.estimatedGrams.toStringAsFixed(1),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Text('Edit ${food.name}', style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Adjust serving portion size (grams):',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                suffixText: 'grams',
                suffixStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.surfaceElevated,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primaryRed),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CANCEL', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final newGrams = double.tryParse(controller.text.trim());
              if (newGrams != null && newGrams > 0) {
                setState(() {
                  _foods[index] = food.updatePortionGrams(newGrams);
                });
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('UPDATE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _removeFood(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      _foods.removeAt(index);
    });
  }

  void _addMissingFoodFromLibrary() async {
    // Allows user to pick from Food Library if AI missed an item on the plate
    final allFoods = widget.repository.allFoods;
    FoodItem? selectedFood;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String filter = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = allFoods.where((f) => f.name.toLowerCase().contains(filter.toLowerCase())).toList();
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add Item from Food Library', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (val) => setModalState(() => filter = val),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search foods...',
                      hintStyle: const TextStyle(color: AppColors.textTertiary),
                      prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.surfaceElevated,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final item = filtered[i];
                        return ListTile(
                          title: Text(item.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          subtitle: Text('${item.servingDisplay} • ${item.calories.toInt()} kcal', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          trailing: const Icon(Icons.add_circle_outline, color: AppColors.primaryRed),
                          onTap: () {
                            selectedFood = item;
                            Navigator.of(ctx).pop();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (selectedFood != null) {
      setState(() {
        _foods.add(ScannedFoodItem(
          name: selectedFood!.name,
          matchedFoodId: selectedFood!.id,
          category: selectedFood!.category,
          estimatedGrams: selectedFood!.servingSize,
          servingDisplay: selectedFood!.servingDisplay,
          confidence: 1.0,
          calories: selectedFood!.calories,
          protein: selectedFood!.protein,
          carbs: selectedFood!.carbs,
          fat: selectedFood!.fat,
          fiber: selectedFood!.fiber,
          isEstimate: false,
          source: 'ALPHA_X_LIBRARY',
        ));
      });
    }
  }

  Future<void> _confirmAndAddToFoodLog() async {
    if (_foods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No foods selected. Please keep at least one food.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.heavyImpact();

    try {
      final clientId = widget.repository.resolveClientId();
      final dateString = widget.dateString;

      for (final food in _foods) {
        final entry = food.toFoodLogEntry(
          clientId: clientId,
          dateString: dateString,
          mealType: _selectedMealType,
        );
        widget.repository.logFoodEntry(entry);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surfaceElevated,
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Added ${_foods.length} items to ${_selectedMealType.displayName}!',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );

        // Pop back to Macro Planner screen
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('DETECTED MEAL ANALYSIS'),
        backgroundColor: AppColors.surfaceCard,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // Banner for low-confidence or estimate notification
          if (widget.scanResult.isLowConfidence) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.gold.withOpacity(0.5)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.warning_amber_rounded, color: AppColors.gold, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Food identification is uncertain. Please verify the detected food and serving size.',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Meal category selector
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'LOG TO MEAL CATEGORY',
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: MealType.values.map((meal) {
                    final isSelected = meal == _selectedMealType;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedMealType = meal);
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primaryRed : AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? AppColors.primaryRed : AppColors.borderSubtle,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(meal.iconEmoji, style: const TextStyle(fontSize: 16)),
                              const SizedBox(height: 2),
                              Text(
                                meal.displayName,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? Colors.white : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Total Meal Nutrition Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.surfaceElevated,
                  AppColors.surfaceCard,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primaryRed.withOpacity(0.4), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TOTAL MEAL NUTRITION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                        color: Colors.white,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'AI ESTIMATE',
                        style: TextStyle(
                          color: AppColors.primaryRed,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _totalCalories.toStringAsFixed(0),
                      style: AppTypography.displayLarge.copyWith(fontSize: 32, color: Colors.white),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'total kcal',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _MacroMiniBadge(label: 'Protein', grams: _totalProtein, color: AppColors.accentRed),
                    const SizedBox(width: 8),
                    _MacroMiniBadge(label: 'Carbs', grams: _totalCarbs, color: AppColors.info),
                    const SizedBox(width: 8),
                    _MacroMiniBadge(label: 'Fat', grams: _totalFat, color: AppColors.gold),
                    const SizedBox(width: 8),
                    _MacroMiniBadge(label: 'Fiber', grams: _totalFiber, color: AppColors.success),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Detected Foods Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DETECTED FOODS (${_foods.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              TextButton.icon(
                onPressed: _addMissingFoodFromLibrary,
                icon: const Icon(Icons.add, size: 16, color: AppColors.primaryRed),
                label: const Text(
                  'Add Item',
                  style: TextStyle(color: AppColors.primaryRed, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Individual Food Cards
          ...List.generate(_foods.length, (index) {
            final food = _foods[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
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
                            Text(
                              food.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: food.isFromFoodLibrary
                                        ? AppColors.success.withOpacity(0.15)
                                        : AppColors.surfaceElevated,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    food.isFromFoodLibrary ? 'Alpha X Verified' : 'AI Estimate',
                                    style: TextStyle(
                                      color: food.isFromFoodLibrary ? AppColors.success : AppColors.textTertiary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  food.servingDisplay,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Edit Portion Button
                      OutlinedButton.icon(
                        onPressed: () => _editPortionDialog(index),
                        icon: const Icon(Icons.edit, size: 13),
                        label: const Text('Edit Portion', style: TextStyle(fontSize: 11)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18, color: AppColors.textTertiary),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _removeFood(index),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(color: AppColors.borderSubtle, height: 1),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${food.calories.toStringAsFixed(0)} kcal',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text('P: ${food.protein.toStringAsFixed(1)}g', style: const TextStyle(color: AppColors.accentRed, fontSize: 12)),
                      Text('C: ${food.carbs.toStringAsFixed(1)}g', style: const TextStyle(color: AppColors.info, fontSize: 12)),
                      Text('F: ${food.fat.toStringAsFixed(1)}g', style: const TextStyle(color: AppColors.gold, fontSize: 12)),
                      Text('Fib: ${food.fiber.toStringAsFixed(1)}g', style: const TextStyle(color: AppColors.success, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 10),

          // Privacy & AI visual estimate disclaimer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              widget.scanResult.disclaimer,
              style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 20),

          // Action Buttons: Confirm & Add / Retake
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _confirmAndAddToFoodLog,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline, size: 20),
              label: Text(
                _isSaving ? 'SAVING TO FOOD LOG...' : 'CONFIRM & ADD TO FOOD LOG',
                style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),

          const SizedBox(height: 10),

          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('DISCARD & RETAKE PHOTO'),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _MacroMiniBadge extends StatelessWidget {
  final String label;
  final double grams;
  final Color color;

  const _MacroMiniBadge({
    required this.label,
    required this.grams,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              '${grams.toStringAsFixed(1)}g',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
