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

  const AdminCreateEditDietPlanScreen({
    super.key,
    required this.client,
    required this.macroRepository,
    this.initialDietPlan,
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
                      hintText: 'Search foods (dosa, chicken, rice, eggs)...',
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

    if (selectedFood != null) {
      setState(() {
        final currentMeal = _meals[mealIndex];
        final updatedFoods = List<PrescribedFoodItem>.from(currentMeal.foods)..add(
          PrescribedFoodItem(
            name: selectedFood!.name,
            servingDisplay: selectedFood!.servingDisplay,
            quantity: 1.0,
            calories: selectedFood!.calories,
            protein: selectedFood!.protein,
            carbs: selectedFood!.carbs,
            fat: selectedFood!.fat,
            fiber: selectedFood!.fiber,
          ),
        );
        _meals[mealIndex] = PrescribedMeal(
          mealType: currentMeal.mealType,
          timing: currentMeal.timing,
          notes: currentMeal.notes,
          foods: updatedFoods,
        );
      });
    }
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
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(food.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                                  Text(
                                    '${food.servingDisplay} • ${food.calories.toInt()} kcal • P:${food.protein.toStringAsFixed(1)}g',
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16, color: AppColors.textTertiary),
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _removeFoodFromMeal(mIdx, fIdx),
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
