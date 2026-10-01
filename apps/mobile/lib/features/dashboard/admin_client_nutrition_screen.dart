import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../macro_planner/data/repositories/macro_repository.dart';
import '../macro_planner/domain/models/assigned_diet_plan.dart';
import 'admin_create_edit_diet_plan_screen.dart';

/// Screen for Master Admin / Trainer to monitor client nutrition:
/// - Assigned Diet vs Actual Food Log (Factual Comparison)
/// - Prescribed Meals & Timings
/// - Diet Version History
class AdminClientNutritionScreen extends StatefulWidget {
  final Map<String, dynamic> client;
  final MacroRepository macroRepository;

  const AdminClientNutritionScreen({
    super.key,
    required this.client,
    required this.macroRepository,
  });

  @override
  State<AdminClientNutritionScreen> createState() => _AdminClientNutritionScreenState();
}

class _AdminClientNutritionScreenState extends State<AdminClientNutritionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  Map<String, dynamic>? _nutritionSummary;
  List<Map<String, dynamic>> _dietHistory = [];

  String get _selectedDateString => DateFormat('yyyy-MM-dd').format(_selectedDate);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final clientId = widget.client['id'] ?? widget.client['clientId'] ?? '';

    try {
      final summary = await widget.macroRepository.fetchAdminNutritionSummary(clientId, _selectedDateString);
      final history = await widget.macroRepository.fetchAdminDietHistory(clientId);

      if (mounted) {
        setState(() {
          _nutritionSummary = summary;
          _dietHistory = history;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openCreateEditDiet({AssignedDietPlan? existingPlan}) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (ctx) => AdminCreateEditDietPlanScreen(
          client: widget.client,
          macroRepository: widget.macroRepository,
          initialDietPlan: existingPlan,
        ),
      ),
    );

    if (updated == true) {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientName = widget.client['name'] ?? 'Athlete';
    final clientId = widget.client['clientId'] ?? widget.client['id'] ?? '';
    final primaryGoal = widget.client['primaryGoal'] ?? 'General Fitness';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('NUTRITION • $clientName'.toUpperCase()),
        backgroundColor: AppColors.surfaceCard,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryRed,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          tabs: const [
            Tab(text: 'TARGET VS ACTUAL'),
            Tab(text: 'ASSIGNED DIET'),
            Tab(text: 'VERSION HISTORY'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryRed))
          : Column(
              children: [
                // Top Client Summary Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceCard,
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primaryRed,
                        child: Text(
                          clientName.isNotEmpty ? clientName.substring(0, 1).toUpperCase() : 'A',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(clientName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                            Text('$clientId • Goal: $primaryGoal', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _openCreateEditDiet(),
                        icon: const Icon(Icons.edit, size: 14),
                        label: const Text('UPDATE DIET', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ),

                // Tab Views
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTargetVsActualTab(),
                      _buildAssignedDietTab(),
                      _buildHistoryTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // --- TAB 1: TARGET VS ACTUAL (DAILY FOOD LOG & FACTUAL COMPARISON) ---
  Widget _buildTargetVsActualTab() {
    final comp = _nutritionSummary?['comparison'];
    final meals = _nutritionSummary?['meals'] as Map<String, dynamic>? ?? {};
    final totalMealsLogged = _nutritionSummary?['totalMealsLogged'] ?? 0;
    final lastMealTime = _nutritionSummary?['lastMealTime'];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Date Selector Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                onPressed: () {
                  setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
                  _loadData();
                },
              ),
              Text(
                DateFormat('EEEE, d MMMM yyyy').format(_selectedDate).toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.8),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white),
                onPressed: () {
                  setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));
                  _loadData();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Factual Target vs Actual Grid Card
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
                  const Text('DAILY TARGET VS ACTUAL CONSUMPTION', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                  Text(
                    '$totalMealsLogged / 4 meals logged',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (lastMealTime != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Last logged meal: ${DateFormat('h:mm a').format(DateTime.parse(lastMealTime).toLocal())}',
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                ),
              ],
              const SizedBox(height: 14),
              const Divider(color: AppColors.borderSubtle, height: 1),
              const SizedBox(height: 12),

              // Macro Rows
              _buildComparisonRow('Calories', comp?['calories'], 'kcal', AppColors.primaryRed),
              const SizedBox(height: 10),
              _buildComparisonRow('Protein', comp?['protein'], 'g', AppColors.accentRed),
              const SizedBox(height: 10),
              _buildComparisonRow('Carbohydrates', comp?['carbohydrates'], 'g', AppColors.info),
              const SizedBox(height: 10),
              _buildComparisonRow('Fat', comp?['fat'], 'g', AppColors.gold),
              const SizedBox(height: 10),
              _buildComparisonRow('Fiber', comp?['fiber'], 'g', AppColors.success),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Actual Meals Logged with Source Badges
        const Text('ACTUAL FOOD CONSUMED', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
        const SizedBox(height: 10),

        ...['Breakfast', 'Lunch', 'Snacks', 'Dinner'].map((mealCategory) {
          final entries = (meals[mealCategory] as List<dynamic>? ?? []);
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
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
                    Text(mealCategory.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                    Text('${entries.length} items logged', style: const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                  ],
                ),
                if (entries.isEmpty) ...[
                  const SizedBox(height: 6),
                  const Text('No actual foods logged for this meal.', style: TextStyle(color: AppColors.textTertiary, fontSize: 12, fontStyle: FontStyle.italic)),
                ] else ...[
                  const Divider(color: AppColors.borderSubtle, height: 14),
                  ...entries.map((item) {
                    final source = item['source'] ?? 'FOOD_LIBRARY';
                    final isAiCamera = source == 'AI_CAMERA';
                    final isCustom = source == 'CUSTOM_FOOD';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
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
                                        item['foodName'] ?? 'Food',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Source Tag
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isAiCamera
                                            ? AppColors.primaryRed.withOpacity(0.15)
                                            : (isCustom ? Colors.purpleAccent.withOpacity(0.15) : AppColors.surfaceElevated),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: isAiCamera
                                              ? AppColors.primaryRed
                                              : (isCustom ? Colors.purpleAccent : AppColors.borderSubtle),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        isAiCamera ? '📷 AI CAMERA' : (isCustom ? 'CUSTOM' : 'LIBRARY'),
                                        style: TextStyle(
                                          color: isAiCamera
                                              ? AppColors.primaryRed
                                              : (isCustom ? Colors.purpleAccent : AppColors.textSecondary),
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${item['quantity']}x • ${item['servingSize']} ${item['servingUnit']} • ${item['calories']?.round()} kcal (P:${item['protein']?.round()}g C:${item['carbohydrates']?.round()}g F:${item['fat']?.round()}g)',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
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
        }),
      ],
    );
  }

  Widget _buildComparisonRow(String label, Map<String, dynamic>? data, String unit, Color color) {
    final assigned = data?['assigned'] ?? 0;
    final actual = data?['actual'] ?? 0;
    final diff = data?['diff'] ?? 0;
    final isOver = diff > 0;

    return Row(
      children: [
        SizedBox(
          width: 95,
          child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: Text(
            'Assigned: $assigned $unit',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ),
        Expanded(
          child: Text(
            'Actual: $actual $unit',
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: (diff == 0 ? Colors.grey : (isOver ? Colors.orange : Colors.green)).withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            diff == 0 ? 'On Target' : (diff > 0 ? '+$diff $unit' : '$diff $unit'),
            style: TextStyle(
              color: diff == 0 ? Colors.white70 : (isOver ? Colors.orangeAccent : Colors.lightGreenAccent),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // --- TAB 2: ASSIGNED DIET PLAN (PRESCRIPTION) ---
  Widget _buildAssignedDietTab() {
    final assignedDietRaw = _nutritionSummary?['assignedDiet'];
    if (assignedDietRaw == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.restaurant_menu, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            const Text('No Active Diet Plan Assigned', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Create and assign a structured nutrition protocol for this client.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed),
              onPressed: () => _openCreateEditDiet(),
              child: const Text('CREATE DIET PLAN'),
            ),
          ],
        ),
      );
    }

    final plan = AssignedDietPlan.fromJson(assignedDietRaw as Map<String, dynamic>);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
                  Expanded(
                    child: Text(plan.planName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.primaryRed.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                    child: Text('VERSION ${plan.version}', style: const TextStyle(color: AppColors.primaryRed, fontSize: 11, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Prescribed by: ${plan.assignedByName ?? "Trainer"} • ${DateFormat("d MMM yyyy").format(plan.createdAt)}',
                style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
              ),
              const SizedBox(height: 14),
              const Divider(color: AppColors.borderSubtle, height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _macroBadge('CALORIES', '${plan.dailyCalories.toInt()} kcal', AppColors.primaryRed),
                  _macroBadge('PROTEIN', '${plan.protein.toInt()}g', AppColors.accentRed),
                  _macroBadge('CARBS', '${plan.carbohydrates.toInt()}g', AppColors.info),
                  _macroBadge('FAT', '${plan.fat.toInt()}g', AppColors.gold),
                  _macroBadge('FIBER', '${plan.fiber.toInt()}g', AppColors.success),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        const Text('PRESCRIBED MEALS & TIMINGS', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
        const SizedBox(height: 10),

        if (plan.prescribedMeals.isEmpty)
          const Text('No meal breakdown specified.', style: TextStyle(color: AppColors.textTertiary, fontSize: 12, fontStyle: FontStyle.italic))
        else
          ...plan.prescribedMeals.map((meal) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
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
                      Text(meal.mealType.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(6)),
                        child: Text(meal.timing, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  if (meal.notes != null && meal.notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(meal.notes!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                  if (meal.foods.isNotEmpty) ...[
                    const Divider(color: AppColors.borderSubtle, height: 14),
                    ...meal.foods.map((food) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(food.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                            ),
                            Text(
                              '${food.servingDisplay} • ${food.calories.toInt()} kcal',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
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

        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () => _openCreateEditDiet(existingPlan: plan),
          icon: const Icon(Icons.edit, size: 16),
          label: const Text('UPDATE / REPLACE DIET PLAN'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryRed,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _macroBadge(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // --- TAB 3: DIET PLAN VERSION HISTORY ---
  Widget _buildHistoryTab() {
    if (_dietHistory.isEmpty) {
      return const Center(
        child: Text('No previous diet history records found.', style: TextStyle(color: AppColors.textTertiary)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _dietHistory.length,
      itemBuilder: (ctx, i) {
        final item = _dietHistory[i];
        final version = item['version'] ?? (i + 1);
        final planName = item['planName'] ?? 'Diet Plan';
        final adminName = item['adminName'] ?? 'Trainer Alex Stone';
        final date = item['createdAt'] != null
            ? DateFormat('d MMMM yyyy, h:mm a').format(DateTime.parse(item['createdAt']).toLocal())
            : 'Recent';
        final summary = item['changeSummary'] ?? 'Diet plan updated';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
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
                  Text(planName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(6)),
                    child: Text('v$version', style: const TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.w900, fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Assigned by: $adminName • $date', style: const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
              const SizedBox(height: 8),
              Text(
                'Targets: ${item['dailyCalories']} kcal • P:${item['protein']}g C:${item['carbohydrates']}g Fat:${item['fat']}g Fiber:${item['fiber']}g',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(8)),
                child: Text(summary, style: const TextStyle(color: Colors.white70, fontSize: 11, fontStyle: FontStyle.italic)),
              ),
            ],
          ),
        );
      },
    );
  }
}
