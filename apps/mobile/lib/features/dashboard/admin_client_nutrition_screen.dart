import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../macro_planner/data/repositories/macro_repository.dart';
import '../macro_planner/domain/models/assigned_diet_plan.dart';
import 'admin_create_edit_diet_plan_screen.dart';
import 'widgets/admin_meal_photo_viewer_dialog.dart';

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
  String _selectedMealFilter = 'ALL';

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

  void _openPhotoViewer(Map<String, dynamic> photo) {
    final clientName = widget.client['name'] ?? 'Athlete';
    final clientId = widget.client['clientId'] ?? widget.client['id'] ?? '';

    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => AdminMealPhotoViewerDialog(
          mealPhoto: photo,
          clientName: clientName,
          clientId: clientId,
          onPhotoDeleted: () {
            _loadData();
          },
        ),
      ),
    );
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

        // CLIENT FOOD LOG (WITH LIVE CAMERA MEAL PHOTO SUPPORT)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'CLIENT FOOD LOG',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            Text(
              '${comp?['calories']?['actual'] ?? 0} kcal consumed',
              style: const TextStyle(color: AppColors.primaryRed, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Meal Category Filter Bar (ALL, BREAKFAST, LUNCH, SNACKS, DINNER)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['ALL', 'BREAKFAST', 'LUNCH', 'SNACKS', 'DINNER'].map((filter) {
              final isSelected = _selectedMealFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    filter == 'ALL' ? 'ALL MEALS' : filter,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.primaryRed,
                  backgroundColor: AppColors.surfaceCard,
                  side: BorderSide(
                    color: isSelected ? AppColors.primaryRed : AppColors.borderSubtle,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedMealFilter = filter);
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),

        // Build filtered meal cards
        ..._buildClientMealLogCards(meals),
      ],
    );
  }

  List<Widget> _buildClientMealLogCards(Map<String, dynamic> meals) {
    final photosByType = _nutritionSummary?['mealPhotosByType'] as Map<String, dynamic>? ?? {};
    final allCategories = ['Breakfast', 'Lunch', 'Snacks', 'Dinner'];

    final filteredCategories = _selectedMealFilter == 'ALL'
        ? allCategories
        : allCategories.where((c) => c.toUpperCase() == _selectedMealFilter).toList();

    return filteredCategories.map((mealCategory) {
      final entries = (meals[mealCategory] as List<dynamic>? ?? []);
      final photos = (photosByType[mealCategory] as List<dynamic>? ?? []);
      final bool hasPhotos = photos.isNotEmpty || entries.any((e) => e['photoAvailable'] == true);
      final photoData = photos.isNotEmpty ? (photos[0] as Map<String, dynamic>) : null;

      // Calculate meal totals
      double mealCal = 0;
      double mealProt = 0;
      double mealCrbs = 0;
      double mealFt = 0;
      double mealFbr = 0;

      for (final item in entries) {
        final q = (item['quantity'] as num?)?.toDouble() ?? 1.0;
        mealCal += ((item['calories'] as num?)?.toDouble() ?? 0) * q;
        mealProt += ((item['protein'] as num?)?.toDouble() ?? 0) * q;
        mealCrbs += ((item['carbohydrates'] ?? item['carbs'] as num?)?.toDouble() ?? 0) * q;
        mealFt += ((item['fat'] as num?)?.toDouble() ?? 0) * q;
        mealFbr += ((item['fiber'] as num?)?.toDouble() ?? 0) * q;
      }

      if (entries.isEmpty && photoData != null) {
        mealCal = (photoData['totalCalories'] as num?)?.toDouble() ?? 0;
        mealProt = (photoData['totalProtein'] as num?)?.toDouble() ?? 0;
        mealCrbs = (photoData['totalCarbs'] as num?)?.toDouble() ?? 0;
        mealFt = (photoData['totalFat'] as num?)?.toDouble() ?? 0;
        mealFbr = (photoData['totalFiber'] as num?)?.toDouble() ?? 0;
      }

      final itemsSummary = entries.isNotEmpty
          ? entries.map((e) => e['foodName'] ?? 'Food').take(3).join(' • ')
          : (photoData != null && photoData['items'] is List
              ? (photoData['items'] as List).map((i) => i['foodName'] ?? 'Food').take(3).join(' • ')
              : 'No foods logged for $mealCategory');

      String timeDisplay = _selectedDateString;
      if (photoData != null && photoData['confirmedAt'] != null) {
        final dt = DateTime.tryParse(photoData['confirmedAt'].toString());
        if (dt != null) {
          timeDisplay = DateFormat('dd MMM yyyy • h:mm a').format(dt.toLocal());
        }
      } else if (entries.isNotEmpty && entries[0]['loggedAt'] != null) {
        final dt = DateTime.tryParse(entries[0]['loggedAt'].toString());
        if (dt != null) {
          timeDisplay = DateFormat('dd MMM yyyy • h:mm a').format(dt.toLocal());
        }
      }

      final weightSource = photoData?['weightSource'] ??
          (entries.any((e) => e['weightSource'] == 'SMART_SCALE_BLE')
              ? 'SMART_SCALE_BLE'
              : (entries.any((e) => e['weightSource'] == 'AI_ESTIMATE') ? 'AI_ESTIMATE' : 'CLIENT_ENTERED'));

      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasPhotos ? AppColors.primaryRed.withOpacity(0.5) : AppColors.border,
            width: hasPhotos ? 1.5 : 1.0,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header: Meal Type + Photo Available / No Photo Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AppColors.surfaceElevated,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        mealCategory.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '• $timeDisplay',
                        style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: hasPhotos ? AppColors.success.withOpacity(0.15) : Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: hasPhotos ? AppColors.success.withOpacity(0.5) : AppColors.borderSubtle,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasPhotos ? Icons.camera_alt : Icons.no_photography_outlined,
                          size: 12,
                          color: hasPhotos ? AppColors.success : AppColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          hasPhotos ? '📷 Photo Available' : 'No Photo',
                          style: TextStyle(
                            color: hasPhotos ? AppColors.success : AppColors.textTertiary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Card Body: Items Summary, Macros & Action Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    itemsSummary,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Nutrition Metrics Row
                  Row(
                    children: [
                      Text(
                        '${mealCal.round()} kcal',
                        style: const TextStyle(
                          color: AppColors.primaryRed,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        '${mealProt.round()}g Protein',
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${mealCrbs.round()}g Carbs',
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${mealFt.round()}g Fat',
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${mealFbr.round()}g Fiber',
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Weight source indicator badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: weightSource == 'SMART_SCALE_BLE'
                          ? AppColors.success.withOpacity(0.12)
                          : (weightSource == 'AI_ESTIMATE'
                              ? AppColors.gold.withOpacity(0.12)
                              : Colors.lightBlueAccent.withOpacity(0.12)),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: weightSource == 'SMART_SCALE_BLE'
                            ? AppColors.success.withOpacity(0.4)
                            : (weightSource == 'AI_ESTIMATE'
                                ? AppColors.gold.withOpacity(0.4)
                                : Colors.lightBlueAccent.withOpacity(0.4)),
                      ),
                    ),
                    child: Text(
                      weightSource == 'SMART_SCALE_BLE'
                          ? 'WEIGHT: SMART SCALE MEASURED'
                          : (weightSource == 'AI_ESTIMATE'
                              ? 'WEIGHT: AI ESTIMATED PORTION'
                              : 'WEIGHT: CLIENT ENTERED'),
                      style: TextStyle(
                        color: weightSource == 'SMART_SCALE_BLE'
                            ? AppColors.success
                            : (weightSource == 'AI_ESTIMATE' ? AppColors.gold : Colors.lightBlueAccent),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // Prominent Action Button: [ VIEW PHOTO ]
                  if (hasPhotos && photoData != null) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.fullscreen, size: 18),
                        label: const Text(
                          'VIEW PHOTO',
                          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0, fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _openPhotoViewer(photoData),
                      ),
                    ),
                  ],

                  // Individual food items expandable
                  if (entries.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(color: AppColors.borderSubtle, height: 1),
                    const SizedBox(height: 10),
                    ...entries.map((item) {
                      final src = item['weightSource'] ?? (item['source'] == 'AI_CAMERA' ? 'AI_ESTIMATE' : 'CLIENT_ENTERED');
                      final isScale = src == 'SMART_SCALE_BLE';
                      final isAi = src == 'AI_ESTIMATE';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${item['quantity']}× ${item['foodName']} (${item['servingSize']} ${item['servingUnit']})',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: isScale
                                    ? AppColors.success.withOpacity(0.12)
                                    : (isAi ? AppColors.gold.withOpacity(0.12) : Colors.lightBlueAccent.withOpacity(0.12)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isScale ? 'Scale' : (isAi ? 'AI Est.' : 'Client'),
                                style: TextStyle(
                                  color: isScale
                                      ? AppColors.success
                                      : (isAi ? AppColors.gold : Colors.lightBlueAccent),
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${(item['calories'] as num?)?.round()} kcal',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
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
