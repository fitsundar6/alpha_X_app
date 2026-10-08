import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../macro_planner/data/food_database.dart';
import '../macro_planner/data/repositories/macro_repository.dart';
import '../macro_planner/domain/models/assigned_diet_plan.dart';
import '../macro_planner/domain/models/food_item.dart';

/// Screen allowing Trainer/Admin to design and assign a structured diet plan to a client
/// Includes daily macro targets and structured meals (Breakfast, Lunch, Snacks, Dinner) with timings and foods
class AdminCreateEditDietPlanScreen extends StatefulWidget {
  final Map<String, dynamic> client;
  final MacroRepository macroRepository;
  final AssignedDietPlan? initialDietPlan;
  final VoidCallback? onSaved;

  const AdminCreateEditDietPlanScreen({
    super.key,
    required this.client,
    required this.macroRepository,
    this.initialDietPlan,
    this.onSaved,
  });

  @override
  State<AdminCreateEditDietPlanScreen> createState() => _AdminCreateEditDietPlanScreenState();
}

class _AdminCreateEditDietPlanScreenState extends State<AdminCreateEditDietPlanScreen> {
  late TextEditingController _planNameController;
  late TextEditingController _caloriesController;
  late TextEditingController _proteinController;
  late TextEditingController _carbsController;
  late TextEditingController _fatController;
  late TextEditingController _fiberController;
  late TextEditingController _waterController;
  late TextEditingController _notesController;

  late List<PrescribedMeal> _meals;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final plan = widget.initialDietPlan;
    final clientName = widget.client['name'] ?? 'Athlete';

    _planNameController = TextEditingController(
      text: plan?.planName ?? 'Prescribed Nutrition Plan - $clientName',
    );
    _caloriesController = TextEditingController(text: (plan?.dailyCalories ?? 2200).toInt().toString());
    _proteinController = TextEditingController(text: (plan?.protein ?? 160).toInt().toString());
    _carbsController = TextEditingController(text: (plan?.carbohydrates ?? 230).toInt().toString());
    _fatController = TextEditingController(text: (plan?.fat ?? 65).toInt().toString());
    _fiberController = TextEditingController(text: (plan?.fiber ?? 30).toInt().toString());
    _waterController = TextEditingController(text: (plan?.waterTargetLiters ?? 3.5).toString());
    _notesController = TextEditingController(text: plan?.notes ?? 'Prioritize whole foods, hit daily protein target, and stay hydrated.');

    if (plan != null && plan.prescribedMeals.isNotEmpty) {
      _meals = List.from(plan.prescribedMeals);
    } else {
      // Default 4 structured meal framework
      _meals = [
        const PrescribedMeal(mealType: 'Breakfast', timing: '8:00 AM', notes: 'Pre-workout nutrition', foods: []),
        const PrescribedMeal(mealType: 'Lunch', timing: '1:30 PM', notes: 'Lean protein & complex carbs', foods: []),
        const PrescribedMeal(mealType: 'Snacks', timing: '5:00 PM', notes: 'Post-workout recovery fuel', foods: []),
        const PrescribedMeal(mealType: 'Dinner', timing: '8:30 PM', notes: 'Light carb, protein & greens', foods: []),
      ];
    }
  }

  @override
  void dispose() {
    _planNameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _fiberController.dispose();
    _waterController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  static const List<String> _supportedUnits = [
    'g',
    'kg',
    'ml',
    'L',
    'serving',
    'piece',
    'egg',
    'cup',
    'tbsp',
    'tsp',
    'slice',
    'bowl',
  ];

  void _addFoodToMeal(int mealIndex) async {
    final allFoods = FoodDatabase.defaultFoods;
    FoodItem? selectedFood;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = allFoods.where((f) => f.name.toLowerCase().contains(query.toLowerCase())).toList();
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Food from Library', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (val) => setModalState(() => query = val),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search foods (chicken, rice, oats, egg)...',
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
                        final food = filtered[i];
                        return ListTile(
                          title: Text(food.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            '${food.servingDisplay} • ${food.calories.toInt()} kcal • P:${food.protein.toInt()}g C:${food.carbs.toInt()}g F:${food.fat.toInt()}g',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                          trailing: const Icon(Icons.add_circle, color: AppColors.primaryRed),
                          onTap: () {
                            selectedFood = food;
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

    if (selectedFood != null && mounted) {
      await _showFoodServingDialog(
        mealIndex: mealIndex,
        foodLibraryItem: selectedFood,
      );
    }
  }

  Future<void> _showFoodServingDialog({
    required int mealIndex,
    FoodItem? foodLibraryItem,
    PrescribedFoodItem? existingFoodItem,
    int? foodIndex,
  }) async {
    final isEditing = existingFoodItem != null && foodIndex != null;
    final foodName = foodLibraryItem?.name ?? existingFoodItem?.name ?? 'Food Item';
    final foodId = foodLibraryItem?.id ?? existingFoodItem?.foodId;

    // Base nutritional facts from food library or preserved base facts
    final baseCalories = foodLibraryItem?.calories ?? existingFoodItem?.baseCalories ?? existingFoodItem?.calories ?? 0.0;
    final baseProtein = foodLibraryItem?.protein ?? existingFoodItem?.baseProtein ?? existingFoodItem?.protein ?? 0.0;
    final baseCarbs = foodLibraryItem?.carbs ?? existingFoodItem?.baseCarbs ?? existingFoodItem?.carbs ?? 0.0;
    final baseFat = foodLibraryItem?.fat ?? existingFoodItem?.baseFat ?? existingFoodItem?.fat ?? 0.0;
    final baseFiber = foodLibraryItem?.fiber ?? existingFoodItem?.baseFiber ?? existingFoodItem?.fiber ?? 0.0;
    final baseServingSize = foodLibraryItem != null
        ? (foodLibraryItem.servingSize > 0 ? foodLibraryItem.servingSize : 100.0)
        : (existingFoodItem?.servingSize ?? 100.0);
    final baseServingUnit = foodLibraryItem?.servingUnit.trim().isNotEmpty == true
        ? foodLibraryItem!.servingUnit.trim()
        : (existingFoodItem?.baseUnit ?? 'g');

    // Initial unit
    String selectedUnit = existingFoodItem?.unit ??
        (foodLibraryItem?.servingUnit.trim().isNotEmpty == true ? foodLibraryItem!.servingUnit.trim() : 'g');

    // Normalize unit if needed
    final cleanLower = selectedUnit.toLowerCase();
    if (cleanLower == 'grams' || cleanLower == 'gram') {
      selectedUnit = 'g';
    } else if (cleanLower == 'pieces') {
      selectedUnit = 'piece';
    } else if (cleanLower == 'servings') {
      selectedUnit = 'serving';
    } else if (cleanLower == 'eggs') {
      selectedUnit = 'egg';
    } else if (cleanLower == 'slices') {
      selectedUnit = 'slice';
    } else if (cleanLower == 'cups') {
      selectedUnit = 'cup';
    } else if (cleanLower == 'bowls') {
      selectedUnit = 'bowl';
    }

    // Ensure unit is present in dropdown
    final List<String> unitsList = List.from(_supportedUnits);
    if (!unitsList.contains(selectedUnit)) {
      unitsList.insert(0, selectedUnit);
    }

    // Initial quantity
    String initialQty = '100';
    if (existingFoodItem != null) {
      initialQty = existingFoodItem.quantityDisplay;
    } else if (foodLibraryItem != null) {
      if (foodLibraryItem.servingSize > 0) {
        initialQty = foodLibraryItem.servingSize % 1 == 0
            ? foodLibraryItem.servingSize.toInt().toString()
            : foodLibraryItem.servingSize.toString();
      } else {
        initialQty = selectedUnit == 'piece' || selectedUnit == 'serving' ? '1' : '100';
      }
    }

    // Initial servings
    final String initialServings = existingFoodItem != null ? existingFoodItem.servingsDisplay : '1';

    final qtyController = TextEditingController(text: initialQty);
    final servingsController = TextEditingController(text: initialServings);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        String? errorMessage;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final rawQty = double.tryParse(qtyController.text.trim()) ?? 0.0;
            final rawServings = double.tryParse(servingsController.text.trim()) ?? 1.0;

            final calculated = PrescribedFoodItem.calculateNutritionFromBase(
              baseCalories: baseCalories,
              baseProtein: baseProtein,
              baseCarbs: baseCarbs,
              baseFat: baseFat,
              baseFiber: baseFiber,
              baseServingSize: baseServingSize,
              baseServingUnit: baseServingUnit,
              quantity: rawQty,
              unit: selectedUnit,
              servings: rawServings,
            );

            final displayServing = PrescribedFoodItem.formatServingDisplay(
              quantity: rawQty,
              unit: selectedUnit,
              servings: rawServings,
            );

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Header
                    Row(
                      children: [
                        Text(PrescribedFoodItem.getFoodEmoji(foodName), style: const TextStyle(fontSize: 26)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                foodName,
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Base: ${baseServingSize % 1 == 0 ? baseServingSize.toInt() : baseServingSize} $baseServingUnit • ${baseCalories.round()} kcal • P:${baseProtein.toStringAsFixed(1)}g C:${baseCarbs.toStringAsFixed(1)}g F:${baseFat.toStringAsFixed(1)}g',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: AppColors.borderSubtle, height: 1),
                    const SizedBox(height: 16),

                    // Quantity and Unit Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Quantity input
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('QUANTITY', style: TextStyle(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: qtyController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                onChanged: (val) {
                                  setSheetState(() {
                                    final d = double.tryParse(val.trim());
                                    if (d == null || d <= 0) {
                                      errorMessage = 'Quantity must be greater than 0';
                                    } else {
                                      errorMessage = null;
                                    }
                                  });
                                },
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: AppColors.surfaceElevated,
                                  hintText: '150',
                                  hintStyle: const TextStyle(color: AppColors.textTertiary),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Unit dropdown
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('UNIT', style: TextStyle(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: selectedUnit,
                                dropdownColor: AppColors.surfaceCard,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: AppColors.surfaceElevated,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                ),
                                items: unitsList.map((u) {
                                  return DropdownMenuItem<String>(
                                    value: u,
                                    child: Text(u, style: const TextStyle(color: Colors.white)),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setSheetState(() => selectedUnit = val);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Number of Servings Row
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('NUMBER OF SERVINGS', style: TextStyle(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: servingsController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          onChanged: (val) {
                            setSheetState(() {
                              final d = double.tryParse(val.trim());
                              if (d == null || d <= 0) {
                                errorMessage = 'Servings must be greater than 0';
                              } else {
                                errorMessage = null;
                              }
                            });
                          },
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.surfaceElevated,
                            hintText: '1',
                            hintStyle: const TextStyle(color: AppColors.textTertiary),
                            suffixText: 'servings',
                            suffixStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Live Calculated Nutrition Preview Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primaryRed.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'ASSIGNED NUTRITION',
                                style: TextStyle(color: AppColors.primaryRed, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                              ),
                              Text(
                                displayServing,
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(child: _buildNutritionPill('Calories', '${calculated['calories']!.round()}', 'kcal', AppColors.primaryRed)),
                              const SizedBox(width: 6),
                              Expanded(child: _buildNutritionPill('Protein', calculated['protein']!.toStringAsFixed(1), 'g', AppColors.accentRed)),
                              const SizedBox(width: 6),
                              Expanded(child: _buildNutritionPill('Carbs', calculated['carbs']!.toStringAsFixed(1), 'g', AppColors.info)),
                              const SizedBox(width: 6),
                              Expanded(child: _buildNutritionPill('Fat', calculated['fat']!.toStringAsFixed(1), 'g', AppColors.gold)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    if (errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorMessage!,
                        style: const TextStyle(color: AppColors.primaryRed, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.border),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('CANCEL', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryRed,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              final finalQty = double.tryParse(qtyController.text.trim());
                              final finalServings = double.tryParse(servingsController.text.trim());

                              if (finalQty == null || finalQty <= 0) {
                                setSheetState(() => errorMessage = 'Please enter a quantity greater than 0');
                                return;
                              }
                              if (finalServings == null || finalServings <= 0) {
                                setSheetState(() => errorMessage = 'Please enter servings greater than 0');
                                return;
                              }

                              final calculatedNutrition = PrescribedFoodItem.calculateNutritionFromBase(
                                baseCalories: baseCalories,
                                baseProtein: baseProtein,
                                baseCarbs: baseCarbs,
                                baseFat: baseFat,
                                baseFiber: baseFiber,
                                baseServingSize: baseServingSize,
                                baseServingUnit: baseServingUnit,
                                quantity: finalQty,
                                unit: selectedUnit,
                                servings: finalServings,
                              );

                              final updatedItem = PrescribedFoodItem(
                                foodId: foodId,
                                name: foodName,
                                quantity: finalQty,
                                unit: selectedUnit,
                                servings: finalServings,
                                servingSize: baseServingSize,
                                baseUnit: baseServingUnit,
                                calories: calculatedNutrition['calories']!,
                                protein: calculatedNutrition['protein']!,
                                carbs: calculatedNutrition['carbs']!,
                                fat: calculatedNutrition['fat']!,
                                fiber: calculatedNutrition['fiber']!,
                                baseCalories: baseCalories,
                                baseProtein: baseProtein,
                                baseCarbs: baseCarbs,
                                baseFat: baseFat,
                                baseFiber: baseFiber,
                                servingDisplay: PrescribedFoodItem.formatServingDisplay(
                                  quantity: finalQty,
                                  unit: selectedUnit,
                                  servings: finalServings,
                                ),
                              );

                              setState(() {
                                final currentMeal = _meals[mealIndex];
                                final updatedFoods = List<PrescribedFoodItem>.from(currentMeal.foods);
                                if (isEditing) {
                                  updatedFoods[foodIndex] = updatedItem;
                                } else {
                                  updatedFoods.add(updatedItem);
                                }
                                _meals[mealIndex] = PrescribedMeal(
                                  mealType: currentMeal.mealType,
                                  timing: currentMeal.timing,
                                  notes: currentMeal.notes,
                                  foods: updatedFoods,
                                );
                              });

                              Navigator.of(context).pop();
                            },
                            child: Text(
                              isEditing ? 'SAVE CHANGES' : 'ADD TO MEAL',
                              style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _removeFoodFromMeal(int mealIndex, int foodIndex) {
    setState(() {
      final currentMeal = _meals[mealIndex];
      final updatedFoods = List<PrescribedFoodItem>.from(currentMeal.foods)..removeAt(foodIndex);
      _meals[mealIndex] = PrescribedMeal(
        mealType: currentMeal.mealType,
        timing: currentMeal.timing,
        notes: currentMeal.notes,
        foods: updatedFoods,
      );
    });
  }

  void _editMealTiming(int mealIndex) async {
    final controller = TextEditingController(text: _meals[mealIndex].timing);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Text('Set ${_meals[mealIndex].mealType} Timing', style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'e.g. 8:30 AM'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  final m = _meals[mealIndex];
                  _meals[mealIndex] = PrescribedMeal(mealType: m.mealType, timing: controller.text.trim(), notes: m.notes, foods: m.foods);
                });
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAndAssignDiet() async {
    final planName = _planNameController.text.trim();
    if (planName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a diet plan name.')));
      return;
    }

    final calories = double.tryParse(_caloriesController.text.trim()) ?? 2000;
    final protein = double.tryParse(_proteinController.text.trim()) ?? 150;
    final carbs = double.tryParse(_carbsController.text.trim()) ?? 200;
    final fat = double.tryParse(_fatController.text.trim()) ?? 60;
    final fiber = double.tryParse(_fiberController.text.trim()) ?? 30;
    final water = double.tryParse(_waterController.text.trim()) ?? 3.5;

    setState(() => _isSaving = true);
    HapticFeedback.heavyImpact();

    try {
      final clientId = widget.client['id'] ?? widget.client['clientId'];
      final success = await widget.macroRepository.assignAdminDietPlan(
        clientId: clientId,
        planName: planName,
        dailyCalories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
        fiber: fiber,
        waterTargetLiters: water,
        notes: _notesController.text.trim(),
        meals: _meals,
      );

      if (mounted) {
        if (success) {
          widget.onSaved?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.surfaceElevated,
              content: Text('Diet Plan successfully assigned to ${widget.client['name'] ?? 'client'}!'),
            ),
          );
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to assign diet plan. Please check connection.')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientName = widget.client['name'] ?? 'Athlete';
    final clientId = widget.client['clientId'] ?? widget.client['id'] ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('ASSIGN DIET • $clientName'.toUpperCase()),
        backgroundColor: AppColors.surfaceCard,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Client info pill
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.person, color: AppColors.primaryRed, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Assigning structured nutrition protocol for $clientName ($clientId)',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Plan Name
          const Text('PLAN NAME', style: TextStyle(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
          const SizedBox(height: 6),
          TextField(
            controller: _planNameController,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surfaceCard,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 16),

          // Daily Target Macros Card
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
                const Text('DAILY TARGET MACROS', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildMacroField('Calories', _caloriesController, 'kcal', AppColors.primaryRed)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildMacroField('Protein', _proteinController, 'g', AppColors.accentRed)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildMacroField('Carbs', _carbsController, 'g', AppColors.info)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildMacroField('Fat', _fatController, 'g', AppColors.gold)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildMacroField('Fiber', _fiberController, 'g', AppColors.success)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildMacroField('Water', _waterController, 'L', Colors.lightBlueAccent)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Structured Meal Plans
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('STRUCTURED MEALS (FOOD LIBRARY)', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
            ],
          ),
          const SizedBox(height: 10),

          ...List.generate(_meals.length, (mIdx) {
            final meal = _meals[mIdx];
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(meal.mealType.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => _editMealTiming(mIdx),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.borderSubtle),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time, size: 12, color: AppColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(meal.timing, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: () => _addFoodToMeal(mIdx),
                        icon: const Icon(Icons.add, size: 14, color: AppColors.primaryRed),
                        label: const Text('Add Food', style: TextStyle(color: AppColors.primaryRed, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  if (meal.foods.isNotEmpty) ...[
                    const Divider(color: AppColors.borderSubtle, height: 16),
                    ...List.generate(meal.foods.length, (fIdx) {
                      final food = meal.foods[fIdx];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Food Header
                            Row(
                              children: [
                                Text(PrescribedFoodItem.getFoodEmoji(food.name), style: const TextStyle(fontSize: 18)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    food.name,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceCard,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppColors.borderSubtle),
                                  ),
                                  child: Text(
                                    food.effectiveServingDisplay,
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Quantity and Servings display row
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Quantity', style: TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceCard,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: AppColors.borderSubtle),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(food.quantityDisplay, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                            Text(food.unit, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12)),
                                          ],
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
                                      const Text('Servings', style: TextStyle(color: AppColors.textTertiary, fontSize: 10, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceCard,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: AppColors.borderSubtle),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(food.servingsDisplay, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                            const Text('serving', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Nutrition values
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceCard.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Calories: ${food.calories.round()} kcal', style: const TextStyle(color: AppColors.primaryRed, fontSize: 11, fontWeight: FontWeight.bold)),
                                  Text('Protein: ${food.protein.toStringAsFixed(1)} g', style: const TextStyle(color: AppColors.accentRed, fontSize: 11, fontWeight: FontWeight.bold)),
                                  Text('Carbs: ${food.carbs.toStringAsFixed(1)} g', style: const TextStyle(color: AppColors.info, fontSize: 11, fontWeight: FontWeight.bold)),
                                  Text('Fat: ${food.fat.toStringAsFixed(1)} g', style: const TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Actions: [ Edit ] and [ Remove ]
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    side: const BorderSide(color: AppColors.border),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  icon: const Icon(Icons.edit_outlined, size: 13, color: Colors.white),
                                  label: const Text('Edit', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                  onPressed: () => _showFoodServingDialog(
                                    mealIndex: mIdx,
                                    existingFoodItem: food,
                                    foodIndex: fIdx,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    side: BorderSide(color: AppColors.primaryRed.withOpacity(0.6)),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  icon: const Icon(Icons.delete_outline, size: 13, color: AppColors.primaryRed),
                                  label: const Text('Remove', style: TextStyle(color: AppColors.primaryRed, fontSize: 11, fontWeight: FontWeight.bold)),
                                  onPressed: () => _removeFoodFromMeal(mIdx, fIdx),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            );
          }),

          const SizedBox(height: 10),

          // Coaching Notes
          const Text('COACHING NOTES & INSTRUCTIONS', style: TextStyle(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
          const SizedBox(height: 6),
          TextField(
            controller: _notesController,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surfaceCard,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),

          const SizedBox(height: 24),

          // Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveAndAssignDiet,
              icon: _isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_circle, size: 18),
              label: Text(
                _isSaving ? 'ASSIGNING TO CLIENT...' : 'ASSIGN DIET PLAN TO CLIENT',
                style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildNutritionPill(String label, String value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          RichText(
            text: TextSpan(
              text: value,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
              children: [
                TextSpan(
                  text: ' $unit',
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 9, fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroField(String label, TextEditingController controller, String unit, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          decoration: InputDecoration(
            suffixText: unit,
            suffixStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
            filled: true,
            fillColor: AppColors.surfaceElevated,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}
