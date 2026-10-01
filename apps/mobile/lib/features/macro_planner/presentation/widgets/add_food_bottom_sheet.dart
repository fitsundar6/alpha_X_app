import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/client_theme_service.dart';
import '../../../../core/widgets/alpha_x_widgets.dart';
import '../../domain/models/food_item.dart';
import '../../domain/models/meal_type.dart';
import '../../domain/models/food_log_entry.dart';
import '../../data/repositories/macro_repository.dart';
import 'custom_food_dialog.dart';

/// Modal bottom sheet for searching, selecting, calculating, and adding foods into a meal
class AddFoodBottomSheet extends StatefulWidget {
  final MacroRepository repository;
  final MealType mealType;
  final String dateString;

  const AddFoodBottomSheet({
    super.key,
    required this.repository,
    required this.mealType,
    required this.dateString,
  });

  static Future<void> show(
    BuildContext context, {
    required MacroRepository repository,
    required MealType mealType,
    required String dateString,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddFoodBottomSheet(
        repository: repository,
        mealType: mealType,
        dateString: dateString,
      ),
    );
  }

  @override
  State<AddFoodBottomSheet> createState() => _AddFoodBottomSheetState();
}

class _AddFoodBottomSheetState extends State<AddFoodBottomSheet> {
  final _searchController = TextEditingController();
  String _selectedCategory = 'All';
  FoodItem? _selectedFood;
  double _quantity = 1.0;

  final List<String> _categories = [
    'All',
    'Snacks',
    'Indian Foods',
    'Protein',
    'Carbohydrates',
    'Fruits',
    'Vegetables',
    'Dairy',
    'Grains',
    'Legumes',
    'Nuts & Seeds',
    'Custom',
  ];

  @override
  void initState() {
    super.initState();
    // Default category to current meal for instant relevance if applicable
    if (widget.mealType == MealType.breakfast) {
      _selectedCategory = 'Indian Foods';
    } else if (widget.mealType == MealType.snack) {
      _selectedCategory = 'Snacks';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectFood(FoodItem food) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedFood = food;
      _quantity = 1.0;
    });
  }

  void _adjustQuantity(double delta) {
    HapticFeedback.selectionClick();
    setState(() {
      _quantity = (_quantity + delta).clamp(0.25, 99.0);
    });
  }

  void _setQuantity(double newQty) {
    HapticFeedback.selectionClick();
    setState(() {
      _quantity = newQty.clamp(0.25, 99.0);
    });
  }

  void _addFoodToMeal() {
    if (_selectedFood == null) return;
    HapticFeedback.mediumImpact();

    // Use repository.resolveClientId to guarantee correct association
    final entry = FoodLogEntry.fromFoodItem(
      clientId: widget.repository.resolveClientId(null),
      dateString: widget.dateString,
      mealType: widget.mealType,
      food: _selectedFood!,
      quantity: _quantity,
    );

    widget.repository.logFoodEntry(entry);
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ Added ${_selectedFood!.name} to ${widget.mealType.displayName}'),
        backgroundColor: AppColors.primaryRed,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openCustomFoodDialog() async {
    final newFood = await CustomFoodDialog.show(
      context,
      repository: widget.repository,
      initialMealType: widget.mealType,
      dateString: widget.dateString,
    );
    if (newFood != null && mounted) {
      final loggedEntries = widget.repository.getMealEntries(widget.dateString, widget.mealType);
      final wasLogged = loggedEntries.any((e) => e.foodId == newFood.id);
      if (wasLogged) {
        Navigator.of(context).pop();
      } else {
        setState(() {
          _selectedFood = newFood;
          _selectedCategory = 'Custom';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClientThemeColors.of(context);
    final foods = widget.repository.searchFoods(
      _searchController.text,
      category: _selectedCategory,
    );

    double? dragStartX;

    return PopScope(
      canPop: _selectedFood == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_selectedFood != null) {
          setState(() => _selectedFood = null);
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (details) {
          dragStartX = details.globalPosition.dx;
        },
        onHorizontalDragEnd: (details) {
          if (dragStartX != null && dragStartX! <= 60.0 && (details.primaryVelocity ?? 0) > 150) {
            if (_selectedFood != null) {
              setState(() => _selectedFood = null);
            } else {
              Navigator.of(context).pop();
            }
          }
          dragStartX = null;
        },
        child: Container(
          height: MediaQuery.of(context).size.height * 0.90,
          decoration: BoxDecoration(
            color: colors.surfaceCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: colors.border, width: 1.5)),
          ),
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

          // Header: Food Library                         [+ Custom]  (X)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 12, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(widget.mealType.iconEmoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Food Library',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Logging to ${widget.mealType.displayName}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Prominent Top-Right [+ Custom] Button
                    InkWell(
                      key: const Key('add_custom_food_top_button'),
                      borderRadius: BorderRadius.circular(8),
                      onTap: _openCustomFoodDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryRed,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryRed.withOpacity(0.35),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Custom',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'Search food (e.g. Dosa, Chicken, Egg, Rice, Oats, Whey)...',
                hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                prefixIcon: const Icon(Icons.search, color: AppColors.primaryRed, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: AppColors.textTertiary),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryRed)),
              ),
            ),
          ),

          // Category Chips Bar
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: _categories.length,
              itemBuilder: (ctx, idx) {
                final cat = _categories[idx];
                final isSel = cat == _selectedCategory;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: AlphaXPressable(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedCategory = cat);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSel ? AppColors.primaryRed : AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isSel ? AppColors.primaryRed : AppColors.border),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: isSel ? Colors.white : AppColors.textSecondary,
                          fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 6),

          // Food Catalog List
          Expanded(
            child: foods.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search_off, size: 40, color: AppColors.textTertiary),
                        const SizedBox(height: 10),
                        Text(
                          'No food found matching "${_searchController.text}"',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _openCustomFoodDialog,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Custom Food'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryRed,
                            side: const BorderSide(color: AppColors.primaryRed),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    itemCount: foods.length + 1,
                    itemBuilder: (ctx, idx) {
                      if (idx == foods.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: OutlinedButton.icon(
                            onPressed: _openCustomFoodDialog,
                            icon: const Icon(Icons.add_circle_outline, size: 16),
                            label: const Text('Don\'t see your food? Add Custom Food'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              side: const BorderSide(color: AppColors.border),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        );
                      }

                      final food = foods[idx];
                      final isSelected = _selectedFood?.id == food.id;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primaryRed.withOpacity(0.12) : AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppColors.primaryRed : AppColors.border,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: InkWell(
                          onTap: () => _selectFood(food),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            food.name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                            ),
                                          ),
                                          if (food.isCustom) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: AppColors.primaryRed,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text('CUSTOM', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '1 serving: ${food.servingDisplay}',
                                        style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${food.calories.round()} kcal  •  P: ${FoodLogEntry.formatMacro(food.protein)}g  C: ${FoodLogEntry.formatMacro(food.carbs)}g  F: ${FoodLogEntry.formatMacro(food.fat)}g${food.fiber > 0 ? "  Fiber: ${FoodLogEntry.formatMacro(food.fiber)}g" : ""}',
                                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  isSelected ? Icons.check_circle : Icons.add_circle_outline,
                                  color: isSelected ? AppColors.primaryRed : AppColors.textSecondary,
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // SECTION 5: FOOD ENTRY SCREEN DETAILS & REAL-TIME TOTALS
          if (_selectedFood != null) _buildSelectedFoodPanel(),
        ],
      ),
    ),
  ),
);
  }

  /// Section 5: Food Entry Screen details panel
  /// Shows serving size, per-serving values, [-] quantity [+], and immediate TOTAL calculation
  Widget _buildSelectedFoodPanel() {
    final food = _selectedFood!;
    final totalCal = food.calories * _quantity;
    final totalProt = food.protein * _quantity;
    final totalCarbs = food.carbs * _quantity;
    final totalFat = food.fat * _quantity;
    final totalFiber = food.fiber * _quantity;

    final isGramOrMl = food.servingUnit.toLowerCase() == 'g' ||
        food.servingUnit.toLowerCase() == 'grams' ||
        food.servingUnit.toLowerCase() == 'ml';

    final isPer100g = food.servingSize == 100 &&
        (food.servingUnit.toLowerCase() == 'g' || food.servingUnit.toLowerCase() == 'grams');

    final calFormatted = FoodLogEntry.formatCalories(totalCal);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: const Border(top: BorderSide(color: AppColors.border, width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Food Name & Serving Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food.name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isPer100g
                          ? 'Nutrition basis: per 100 g'
                          : 'Nutrition basis: per serving (${food.servingDisplay})',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                onPressed: () => setState(() => _selectedFood = null),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // PER-SERVING NUTRITION ROW
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isPer100g ? 'VALUES PER 100 G' : 'VALUES PER SERVING (${food.servingDisplay})',
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textTertiary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _miniNutrientPill('Calories', '${FoodLogEntry.formatCalories(food.calories)} kcal', AppColors.primaryRed),
                    _miniNutrientPill('Protein', '${FoodLogEntry.formatMacro(food.protein)} g', AppColors.accentRed),
                    _miniNutrientPill('Carbs', '${FoodLogEntry.formatMacro(food.carbs)} g', AppColors.info),
                    _miniNutrientPill('Fat', '${FoodLogEntry.formatMacro(food.fat)} g', AppColors.gold),
                    if (food.fiber > 0)
                      _miniNutrientPill('Fiber', '${FoodLogEntry.formatMacro(food.fiber)} g', AppColors.success),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // QUANTITY SELECTOR ROW: [-] Quantity [+] with tap-to-type
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Quantity:',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  Text(
                    '(Tap value to type)',
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 9),
                  ),
                ],
              ),
              Row(
                children: [
                  _stepperBtn('-', () => _adjustQuantity(-1.0)),
                  const SizedBox(width: 4),
                  if (isGramOrMl) ...[
                    _stepperBtn('-0.5', () => _adjustQuantity(-0.5)),
                    const SizedBox(width: 4),
                  ],
                  GestureDetector(
                    onTap: () => _promptDirectQuantity(food),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primaryRed.withOpacity(0.7)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatQuantityPreview(food),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit, size: 11, color: AppColors.primaryRed),
                        ],
                      ),
                    ),
                  ),
                  if (isGramOrMl) ...[
                    _stepperBtn('+0.5', () => _adjustQuantity(0.5)),
                    const SizedBox(width: 4),
                  ],
                  _stepperBtn('+', () => _adjustQuantity(1.0)),
                ],
              ),
            ],
          ),

          // Quick selection chips for gram-based items (e.g. 50g, 100g, 150g, 200g, 250g)
          if (isGramOrMl && food.servingSize > 1) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _quickGramChip('50g', 50.0 / food.servingSize),
                  const SizedBox(width: 6),
                  _quickGramChip('100g', 100.0 / food.servingSize),
                  const SizedBox(width: 6),
                  _quickGramChip('150g', 150.0 / food.servingSize),
                  const SizedBox(width: 6),
                  _quickGramChip('200g', 200.0 / food.servingSize),
                  const SizedBox(width: 6),
                  _quickGramChip('250g', 250.0 / food.servingSize),
                  const SizedBox(width: 6),
                  _quickGramChip('300g', 300.0 / food.servingSize),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),

          // IMMEDIATE TOTAL CARD (Section 5)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TOTAL',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      '$calFormatted kcal',
                      style: const TextStyle(
                        color: AppColors.primaryRed,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _macroTotalItem('Protein', '${FoodLogEntry.formatMacro(totalProt)} g', AppColors.accentRed),
                    _macroTotalItem('Carbs', '${FoodLogEntry.formatMacro(totalCarbs)} g', AppColors.info),
                    _macroTotalItem('Fat', '${FoodLogEntry.formatMacro(totalFat)} g', AppColors.gold),
                    _macroTotalItem('Fiber', '${FoodLogEntry.formatMacro(totalFiber)} g', AppColors.success),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Action Button
          AlphaXPressable(
            onTap: _addFoodToMeal,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.primaryRed,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryRed.withOpacity(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  'ADD TO ${widget.mealType.displayName.toUpperCase()} ($calFormatted KCAL)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _promptDirectQuantity(FoodItem food) async {
    final isGramOrMl = food.servingUnit.toLowerCase() == 'g' ||
        food.servingUnit.toLowerCase() == 'grams' ||
        food.servingUnit.toLowerCase() == 'ml';

    final initialText = isGramOrMl && food.servingSize > 1
        ? (food.servingSize * _quantity % 1 == 0
            ? (food.servingSize * _quantity).toInt().toString()
            : (food.servingSize * _quantity).toStringAsFixed(1))
        : (_quantity % 1 == 0 ? _quantity.toInt().toString() : _quantity.toStringAsFixed(1));

    final controller = TextEditingController(text: initialText);

    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Text(
          isGramOrMl && food.servingSize > 1
              ? 'Enter Quantity (${food.servingUnit})'
              : 'Enter Servings',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isGramOrMl && food.servingSize > 1
                  ? 'Base nutrition is stored per ${food.servingSize.toInt()} ${food.servingUnit}. Enter total grams to proportionally scale macros:'
                  : 'Enter quantity of servings (${food.servingDisplay}):',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
              decoration: InputDecoration(
                suffixText: isGramOrMl && food.servingSize > 1 ? food.servingUnit : 'servings',
                suffixStyle: const TextStyle(color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryRed)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed),
            onPressed: () {
              final val = double.tryParse(controller.text.trim());
              if (val != null && val > 0) {
                if (isGramOrMl && food.servingSize > 1) {
                  Navigator.of(ctx).pop(val / food.servingSize);
                } else {
                  Navigator.of(ctx).pop(val);
                }
              }
            },
            child: const Text('Apply', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      _setQuantity(result);
    }
  }

  String _formatQuantityPreview(FoodItem food) {
    final unitLower = food.servingUnit.toLowerCase();
    if (unitLower == 'piece' || unitLower == 'pieces') {
      final qStr = _quantity % 1 == 0 ? _quantity.toInt().toString() : _quantity.toStringAsFixed(1);
      return '$qStr ${_quantity == 1 ? "piece" : "pieces"}';
    }
    if (unitLower == 'scoop' || unitLower == 'scoops') {
      final qStr = _quantity % 1 == 0 ? _quantity.toInt().toString() : _quantity.toStringAsFixed(1);
      return '$qStr ${_quantity == 1 ? "scoop" : "scoops"}';
    }
    if (unitLower == 'g' || unitLower == 'grams') {
      final totalGrams = (food.servingSize * _quantity);
      final gStr = totalGrams % 1 == 0 ? totalGrams.toInt().toString() : totalGrams.toStringAsFixed(1);
      return '$gStr g';
    }
    final qStr = _quantity % 1 == 0 ? _quantity.toInt().toString() : _quantity.toStringAsFixed(1);
    return '$qStr ${food.servingUnit}';
  }

  Widget _quickGramChip(String label, double qty) {
    final isSelected = (_quantity - qty).abs() < 0.05;
    return GestureDetector(
      onTap: () => _setQuantity(qty),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryRed : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? AppColors.primaryRed : AppColors.borderSubtle),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _stepperBtn(String label, VoidCallback onTap) {
    return AlphaXPressable(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        alignment: Alignment.center,
        child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
      ),
    );
  }

  Widget _miniNutrientPill(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11)),
        const SizedBox(height: 1),
        Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 9, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _macroTotalItem(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 4),
        Text('$label: ', style: const TextStyle(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.w600)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
      ],
    );
  }
}
