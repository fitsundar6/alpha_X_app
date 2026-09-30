import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/alpha_x_widgets.dart';
import '../../domain/models/food_item.dart';
import '../../domain/models/meal_type.dart';
import '../../domain/models/food_log_entry.dart';
import '../../data/repositories/macro_repository.dart';

/// Modal dialog for adding a new Custom Food to the global catalog
class CustomFoodDialog extends StatefulWidget {
  final MacroRepository repository;
  final MealType? initialMealType;
  final String dateString;

  const CustomFoodDialog({
    super.key,
    required this.repository,
    this.initialMealType,
    required this.dateString,
  });

  static Future<FoodItem?> show(
    BuildContext context, {
    required MacroRepository repository,
    MealType? initialMealType,
    required String dateString,
  }) {
    return showDialog<FoodItem>(
      context: context,
      builder: (ctx) => CustomFoodDialog(
        repository: repository,
        initialMealType: initialMealType,
        dateString: dateString,
      ),
    );
  }

  @override
  State<CustomFoodDialog> createState() => _CustomFoodDialogState();
}

class _CustomFoodDialogState extends State<CustomFoodDialog> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _servingSizeController = TextEditingController(text: '100');
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _fiberController = TextEditingController(text: '0');

  String _selectedUnit = 'grams';
  final List<String> _units = [
    'grams',
    'piece',
    'sandwich',
    'slice',
    'cup',
    'ml',
    'scoop',
    'tablespoon',
    'bowl',
    'serving',
  ];

  String _selectedCategory = 'Custom';
  final List<String> _categories = [
    'Custom',
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
  ];

  bool _alsoLogToMeal = true;
  final double _logQuantity = 1.0;
  bool _caloriesManuallyEdited = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _proteinController.addListener(_onMacroChanged);
    _carbsController.addListener(_onMacroChanged);
    _fatController.addListener(_onMacroChanged);
  }

  @override
  void dispose() {
    _proteinController.removeListener(_onMacroChanged);
    _carbsController.removeListener(_onMacroChanged);
    _fatController.removeListener(_onMacroChanged);
    _nameController.dispose();
    _servingSizeController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _fiberController.dispose();
    super.dispose();
  }

  double get _estimatedCalories {
    final p = double.tryParse(_proteinController.text.trim()) ?? 0.0;
    final c = double.tryParse(_carbsController.text.trim()) ?? 0.0;
    final f = double.tryParse(_fatController.text.trim()) ?? 0.0;
    return (p * 4.0) + (c * 4.0) + (f * 9.0);
  }

  void _onMacroChanged() {
    if (!_caloriesManuallyEdited) {
      final est = _estimatedCalories;
      if (est > 0) {
        _caloriesController.text = est.round().toString();
      }
    }
    setState(() {});
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final servingSize = double.tryParse(_servingSizeController.text.trim()) ?? 100.0;
    final protein = double.tryParse(_proteinController.text.trim()) ?? 0.0;
    final carbs = double.tryParse(_carbsController.text.trim()) ?? 0.0;
    final fat = double.tryParse(_fatController.text.trim()) ?? 0.0;
    final fiber = double.tryParse(_fiberController.text.trim()) ?? 0.0;
    final calories = double.tryParse(_caloriesController.text.trim()) ?? _estimatedCalories;

    // Check duplicate in catalog
    final existingMatch = widget.repository.allFoods.any((f) =>
        f.name.trim().toLowerCase() == name.toLowerCase() &&
        f.servingUnit.toLowerCase() == _selectedUnit.toLowerCase() &&
        (f.servingSize - servingSize).abs() < 0.1);

    if (existingMatch) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Food Already Exists', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
          content: Text(
            '"$name" ($servingSize $_selectedUnit) already exists in the catalog. Would you still like to save this variation?',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Save Anyway', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() => _isSaving = true);

    final customFood = FoodItem(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      servingSize: servingSize,
      servingUnit: _selectedUnit,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      fiber: fiber,
      isCustom: true,
      category: _selectedCategory,
      source: 'USER',
      createdBy: widget.repository.resolveClientId(null),
      isPublic: false,
      isVerified: false,
      status: 'APPROVED',
    );

    // Save and sync globally to PostgreSQL
    final savedFood = await widget.repository.addCustomFood(customFood);

    if (_alsoLogToMeal && widget.initialMealType != null) {
      final entry = FoodLogEntry.fromFoodItem(
        clientId: widget.repository.resolveClientId(null),
        dateString: widget.dateString,
        mealType: widget.initialMealType!,
        food: savedFood,
        quantity: _logQuantity,
      );
      widget.repository.logFoodEntry(entry);
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(savedFood);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ Saved "$name" to Food Library'),
        backgroundColor: AppColors.primaryRed,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final est = _estimatedCalories;
    final enteredCal = double.tryParse(_caloriesController.text.trim()) ?? 0.0;
    final hasCalorieDifference = _caloriesManuallyEdited &&
        est > 0 &&
        enteredCal > 0 &&
        (enteredCal - est).abs() > (est * 0.15).clamp(15.0, 100.0);

    return Dialog(
      backgroundColor: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: AppColors.border)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.restaurant_menu, color: AppColors.primaryRed, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'ADD CUSTOM FOOD',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: AppColors.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Saved foods are added to your personal Food Library and saved to your account.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 16),

                // Food Name
                _buildField(
                  controller: _nameController,
                  label: 'Food Name',
                  hint: 'e.g. Homemade Chicken Rice',
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Food name cannot be empty';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Category Selector
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Category', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCategory,
                          isExpanded: true,
                          dropdownColor: AppColors.surfaceCard,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                          items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedCategory = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Serving Size & Unit Row
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildField(
                        controller: _servingSizeController,
                        label: 'Serving Size',
                        hint: '100',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))],
                        validator: (val) {
                          final num = double.tryParse(val ?? '');
                          if (num == null || num <= 0) return 'Invalid size';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Serving Unit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedUnit,
                                isExpanded: true,
                                dropdownColor: AppColors.surfaceCard,
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                                items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedUnit = val);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Nutrition Basis Display
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 14, color: AppColors.primaryRed),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Nutrition basis: per ${_servingSizeController.text.trim().isEmpty ? '100' : _servingSizeController.text.trim()} $_selectedUnit',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Macros Section Header
                const Text(
                  'NUTRITION VALUES',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textTertiary),
                ),
                const SizedBox(height: 8),

                // Protein & Carbs Row
                Row(
                  children: [
                    Expanded(
                      child: _buildField(
                        controller: _proteinController,
                        label: 'Protein (g)',
                        hint: '0',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))],
                        validator: (val) {
                          final num = double.tryParse(val ?? '');
                          if (num == null || num < 0) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildField(
                        controller: _carbsController,
                        label: 'Carbs (g)',
                        hint: '0',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))],
                        validator: (val) {
                          final num = double.tryParse(val ?? '');
                          if (num == null || num < 0) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Fat & Fiber Row
                Row(
                  children: [
                    Expanded(
                      child: _buildField(
                        controller: _fatController,
                        label: 'Fat (g)',
                        hint: '0',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))],
                        validator: (val) {
                          final num = double.tryParse(val ?? '');
                          if (num == null || num < 0) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildField(
                        controller: _fiberController,
                        label: 'Fiber (g) - Opt',
                        hint: '0',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Automatic Calorie Calculation Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Estimated Calories:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                          ),
                          Text(
                            '${est.round()} kcal',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.primaryRed),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Atwater Standard: (Protein × 4) + (Carbs × 4) + (Fat × 9)',
                        style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Calories Field (Allows manual entry / override)
                _buildField(
                  controller: _caloriesController,
                  label: 'Total Calories (kcal)',
                  hint: est > 0 ? '${est.round()}' : 'e.g. 180',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))],
                  onChanged: (val) {
                    setState(() {
                      _caloriesManuallyEdited = true;
                    });
                  },
                  validator: (val) {
                    final num = double.tryParse(val ?? '');
                    if (num == null || num < 0) return 'Enter calories (0+)';
                    return null;
                  },
                ),

                if (hasCalorieDifference) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.amber),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Entered calories (${enteredCal.round()}) differ from macro estimate (${est.round()} kcal).',
                            style: const TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (widget.initialMealType != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _alsoLogToMeal,
                          activeColor: AppColors.primaryRed,
                          onChanged: (val) => setState(() => _alsoLogToMeal = val ?? true),
                        ),
                        Expanded(
                          child: Text(
                            'Also log 1 serving to ${widget.initialMealType!.displayName} now',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Save Action Button
                AlphaXPressable(
                  onTap: _isSaving ? null : _save,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _isSaving ? AppColors.surface : AppColors.primaryRed,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        if (!_isSaving)
                          BoxShadow(
                            color: AppColors.primaryRed.withOpacity(0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                      ],
                    ),
                    child: Center(
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'SAVE TO GLOBAL DATABASE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    void Function(String)? onChanged,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primaryRed)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.error)),
          ),
          validator: validator,
        ),
      ],
    );
  }
}
