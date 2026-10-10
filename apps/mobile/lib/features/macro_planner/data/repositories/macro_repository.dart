import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/core/constants/app_constants.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/macro_enums.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/macro_input.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/macro_result.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/macro_settings.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/macro_history_entry.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/meal_type.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/food_item.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/food_log_entry.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/daily_macro_summary.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/assigned_diet_plan.dart';
import 'dart:io';
import 'package:alpha_x_gym/features/macro_planner/domain/models/confirmed_meal_photo.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/models/scanned_food_detection.dart';
import 'package:alpha_x_gym/features/macro_planner/data/food_database.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/services/macro_calculator.dart';
import 'package:alpha_x_gym/core/services/app_auto_refresh_service.dart';

/// Client progress check-in snapshot
class MacroProgressReview {
  final double currentWeightKg;
  final double? waistCm;
  final DateTime checkInDate;

  const MacroProgressReview({
    required this.currentWeightKg,
    this.waistCm,
    required this.checkInDate,
  });
}

/// Analysis response from a progress check-in
class ProgressReviewResult {
  final double weightDifferenceKg;
  final String advice;
  final String fluctuationNote;

  const ProgressReviewResult({
    required this.weightDifferenceKg,
    required this.advice,
    required this.fluctuationNote,
  });
}

/// State-management and data repository for Alpha X Macro Planner
class MacroRepository extends ChangeNotifier {
  MacroSettings _settings;
  MacroInput? _currentInput;
  MacroResult? _currentResult;
  final List<MacroHistoryEntry> _history = [];
  final List<MacroProgressReview> _reviews = [];

  // Food tracking state
  final List<FoodItem> _customFoods = [];
  final List<FoodItem> _serverFoods = [];
  final List<FoodLogEntry> _foodLogs = [];
  AssignedDietPlan? _assignedDietPlan;

  // Daily target overrides (allowing coaches/clients to set benchmark targets)
  double? _customTargetCalories;
  double? _customTargetProtein;
  double? _customTargetCarbs;
  double? _customTargetFat;
  double? _customTargetFiber;

  final bool _isTest;

  MacroRepository({
    MacroSettings? initialSettings,
    bool? isTestEnvironment,
    bool? seedDemoData,
  })  : _settings = initialSettings ?? MacroSettings.defaults(),
        _isTest = seedDemoData ?? isTestEnvironment ?? _detectTestEnvironment() {
    if (_isTest) {
      _seedDefaultData();
    }
    _loadLocalCache();
  }

  /// Named constructor for clean production state with zero synthetic demo data
  MacroRepository.clean({MacroSettings? initialSettings})
      : this(initialSettings: initialSettings, seedDemoData: false);

  /// Named constructor for test suites requiring synthetic fixtures
  MacroRepository.withFixtures({MacroSettings? initialSettings})
      : this(initialSettings: initialSettings, seedDemoData: true);

  static bool _detectTestEnvironment() {
    if (kIsWeb) return false;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  // Getters
  MacroSettings get settings => _settings;
  MacroInput? get currentInput => _currentInput;
  MacroResult? get currentResult => _currentResult;
  MacroResult? get activeResult => _currentResult;
  AssignedDietPlan? get assignedDietPlan => _assignedDietPlan;
  bool get hasAssignedDietPlan => _assignedDietPlan != null;
  List<MacroHistoryEntry> get history => List.unmodifiable(_history);
  List<MacroProgressReview> get reviews => List.unmodifiable(_reviews);

  bool get hasActiveTarget => _currentResult != null;
  double? get customCalories => _customTargetCalories;
  double? get customProtein => _customTargetProtein;
  double? get customCarbs => _customTargetCarbs;
  double? get customFat => _customTargetFat;
  double? get customFiber => _customTargetFiber;

  /// Set explicit daily targets (e.g. 2200 kcal, 160g P, 250g C, 70g F)
  void setCustomDailyTargets({
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    double? fiber,
  }) {
    if (calories != null) _customTargetCalories = calories;
    if (protein != null) _customTargetProtein = protein;
    if (carbs != null) _customTargetCarbs = carbs;
    if (fat != null) _customTargetFat = fat;
    if (fiber != null) _customTargetFiber = fiber;
    notifyListeners();
    _saveTargetsToPrefs();
  }

  /// Seed realistic client default data
  void _seedDefaultData() {
    final initialInput = const MacroInput(
      age: 28,
      sex: BiologicalSex.male,
      heightCm: 174.0,
      weightKg: 81.0,
      activityLevel: ActivityLevel.veryActive,
      goal: NutritionGoal.fatLoss,
    );

    final initialResult = MacroCalculator.calculate(
      input: initialInput,
      settings: _settings,
    );

    _currentInput = initialInput;
    _currentResult = initialResult;

    // Seed benchmark daily targets matching Alpha X standards (2200 kcal, 160g P, 250g C, 70g F)
    _customTargetCalories = 2200.0;
    _customTargetProtein = 160.0;
    _customTargetCarbs = 250.0;
    _customTargetFat = 70.0;
    _customTargetFiber = 30.0;

    // Seed 2 historical entries showing progression over past 2 weeks
    _history.add(
      MacroHistoryEntry(
        id: 'macro_hist_01',
        timestamp: DateTime.now().subtract(const Duration(days: 14)),
        input: initialInput.copyWith(weightKg: 83.0),
        result: MacroCalculator.calculate(
          input: initialInput.copyWith(weightKg: 83.0),
          settings: _settings,
        ),
        note: 'Initial Macro Target setup',
      ),
    );

    _history.add(
      MacroHistoryEntry(
        id: 'macro_hist_02',
        timestamp: DateTime.now().subtract(const Duration(days: 7)),
        input: initialInput.copyWith(weightKg: 82.0),
        result: MacroCalculator.calculate(
          input: initialInput.copyWith(weightKg: 82.0),
          settings: _settings,
        ),
        note: 'Mid-block weight adjustment (-1.0 kg)',
      ),
    );

    // Initial check-in
    _reviews.add(
      MacroProgressReview(
        currentWeightKg: 81.0,
        waistCm: 83.5,
        checkInDate: DateTime.now().subtract(const Duration(days: 1)),
      ),
    );
  }

  /// Calculate new targets on-the-fly without automatically overwriting saved profile
  MacroResult computeTargets(MacroInput input) {
    return MacroCalculator.calculate(input: input, settings: _settings);
  }

  /// Save newly computed targets as client's current daily targets
  void saveTargets({
    required MacroInput input,
    required MacroResult result,
    String note = '',
  }) {
    _currentInput = input;
    _currentResult = result;
    _customTargetCalories = result.targetCalories.toDouble();
    _customTargetProtein = result.proteinGrams.toDouble();
    _customTargetCarbs = result.carbGrams.toDouble();
    _customTargetFat = result.fatGrams.toDouble();
    _customTargetFiber = result.fiberGrams.toDouble();

    final entry = MacroHistoryEntry(
      id: 'macro_hist_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      input: input,
      result: result,
      note: note.isNotEmpty ? note : 'Saved for ${input.goal.displayName}',
    );

    // Insert at beginning of chronological history
    _history.insert(0, entry);
    notifyListeners();
    _saveTargetsToPrefs();
  }

  /// Re-apply an old historical calculation snapshot as active target
  void restoreFromHistory(MacroHistoryEntry entry) {
    _currentInput = entry.input;
    _currentResult = entry.result;
    _customTargetCalories = entry.result.targetCalories.toDouble();
    _customTargetProtein = entry.result.proteinGrams.toDouble();
    _customTargetCarbs = entry.result.carbGrams.toDouble();
    _customTargetFat = entry.result.fatGrams.toDouble();
    _customTargetFiber = entry.result.fiberGrams.toDouble();
    notifyListeners();
    _saveTargetsToPrefs();
  }

  /// Submit a body progress check-in (Weight, Waist)
  void recordProgressReview({
    required double newWeightKg,
    double? waistCm,
  }) {
    _reviews.insert(
      0,
      MacroProgressReview(
        currentWeightKg: newWeightKg,
        waistCm: waistCm,
        checkInDate: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  /// Calculate and automatically save new targets
  MacroResult calculateAndSave(MacroInput input, {String note = ''}) {
    final result = computeTargets(input);
    saveTargets(input: input, result: result, note: note);
    return result;
  }

  /// Submit a body progress check-in and get progress guidance
  ProgressReviewResult reviewProgress({
    required double currentWeightKg,
    double? currentWaistCm,
  }) {
    recordProgressReview(newWeightKg: currentWeightKg, waistCm: currentWaistCm);
    final previousWeight = _currentInput?.weightKg ?? currentWeightKg;
    final diff = currentWeightKg - previousWeight;
    final diffText = diff.abs() < 0.05
        ? 'unchanged'
        : (diff > 0 ? '+${diff.toStringAsFixed(1)} kg' : '${diff.toStringAsFixed(1)} kg');

    return ProgressReviewResult(
      weightDifferenceKg: diff,
      advice:
          'Your weight is $diffText relative to your baseline setup (${previousWeight.toStringAsFixed(1)} kg). Continue tracking your weekly trend rather than daily numbers.',
      fluctuationNote:
          'Keep in mind natural daily weight fluctuations from hydration, sodium, and training inflammation.',
    );
  }

  /// Admin operation: Update calculation configuration rules
  void updateAdminSettings(MacroSettings newSettings) {
    _settings = newSettings;
    // If active input exists, recalculate targets with updated admin rules
    if (_currentInput != null) {
      _currentResult = MacroCalculator.calculate(
        input: _currentInput!,
        settings: _settings,
      );
    }
    notifyListeners();
  }

  /// Alias for updateAdminSettings
  void updateSettings(MacroSettings newSettings) => updateAdminSettings(newSettings);

  // ==========================================
  // --- DAILY FOOD & MACRO TRACKER METHODS ---
  // ==========================================

  static const String _prefFoodLogsKey = 'alpha_x_food_logs_v1';
  static const String _prefCustomFoodsKey = 'alpha_x_custom_foods_v1';
  static const String _prefServerFoodsKey = 'alpha_x_server_foods_v1';
  static const String _prefAssignedDietPlanKey = 'alpha_x_assigned_diet_plan_v1';
  static const String _prefCurrentInputKey = 'alpha_x_current_macro_input_v1';
  static const String _prefTargetsKey = 'alpha_x_custom_macro_targets_v1';
  static const String _prefHistoryKey = 'alpha_x_macro_history_v1';

  List<FoodItem> get customFoods {
    final currentUserId = resolveClientId(null);
    return _customFoods
        .where((f) =>
            f.isPublic ||
            f.createdBy == null ||
            f.createdBy!.isEmpty ||
            f.createdBy == 'anonymous' ||
            f.createdBy == currentUserId ||
            f.createdBy == 'AXG-0001')
        .toList();
  }
  List<FoodItem> get serverFoods => List.unmodifiable(_serverFoods);

  /// Combined deduplicated food library containing standard system foods,
  /// backend-synced global foods, and local custom foods.
  List<FoodItem> get allFoods {
    final Map<String, FoodItem> map = {};
    for (final f in FoodDatabase.defaultFoods) {
      map[f.id] = f;
    }
    final currentUserId = resolveClientId(null);
    for (final f in _serverFoods) {
      if (!f.isCustom ||
          f.isPublic ||
          f.createdBy == null ||
          f.createdBy!.isEmpty ||
          f.createdBy == 'anonymous' ||
          f.createdBy == currentUserId ||
          f.createdBy == 'AXG-0001') {
        map[f.id] = f;
      }
    }
    for (final f in _customFoods) {
      // User isolation: Do not mix one user's private custom foods with another user's foods
      if (f.isPublic ||
          f.createdBy == null ||
          f.createdBy!.isEmpty ||
          f.createdBy == 'anonymous' ||
          f.createdBy == currentUserId ||
          f.createdBy == 'AXG-0001') {
        map[f.id] = f;
      }
    }
    return map.values.toList();
  }

  String resolveClientId([String? override]) {
    if (override != null && override.isNotEmpty) return override;
    if (AuthService().isAuthenticated) {
      final cId = AuthService().currentClientId;
      if (cId.isNotEmpty) return cId;
      final uId = AuthService().currentUserId;
      if (uId.isNotEmpty) return uId;
    }
    return 'athlete_client';
  }

  /// Get standard date string for today: 'yyyy-MM-dd'
  String getTodayDateString() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  /// Search foods supporting partial matches (e.g. "dosa" -> Dosa, Masala Dosa, Egg Dosa)
  /// and rich category filters.
  List<FoodItem> searchFoods(String query, {String? category}) {
    final cleanQ = query.trim().toLowerCase();
    return allFoods.where((food) {
      final matchesQuery = cleanQ.isEmpty ||
          food.name.toLowerCase().contains(cleanQ) ||
          food.category.toLowerCase().contains(cleanQ);

      final cat = category?.toLowerCase().trim();
      final bool matchesCategory;
      if (cat == null || cat.isEmpty || cat == 'all') {
        matchesCategory = true;
      } else if (cat == 'custom' || cat == 'user added') {
        matchesCategory = food.isCustom || food.source == 'USER';
      } else if (cat == 'snacks' || cat == 'snack') {
        matchesCategory = food.category.toLowerCase() == 'snacks' ||
            food.category.toLowerCase() == 'snack';
      } else if (cat == 'indian foods' || cat == 'indian') {
        matchesCategory = food.category.toLowerCase().contains('indian') ||
            food.category.toLowerCase().contains('rice') ||
            food.category.toLowerCase().contains('legume');
      } else {
        matchesCategory = food.category.toLowerCase() == cat;
      }

      return matchesQuery && matchesCategory;
    }).toList();
  }

  /// Save new custom food for future searches and immediately dispatch to central PostgreSQL database
  /// stored against the authenticated user's account without mixing with other users.
  Future<FoodItem> addCustomFood(FoodItem food) async {
    final cId = resolveClientId(food.createdBy);
    final cleanItem = food.copyWith(
      isCustom: true,
      category: food.category.isEmpty ? 'Custom' : food.category,
      source: 'USER',
      createdBy: cId,
      isPublic: food.isPublic,
      status: 'APPROVED',
    );

    // Save locally first for instant optimistic response
    _customFoods.removeWhere((f) => f.id == cleanItem.id);
    _customFoods.insert(0, cleanItem);
    _saveCustomFoodsToPrefs();
    notifyListeners();

    // Persist to central PostgreSQL backend so ALL clients and admin see it
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/foods');
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'x-client-id': cId,
      };
      final token = AuthService().token;
      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final body = jsonEncode({
        'name': cleanItem.name,
        'category': cleanItem.category,
        'servingSize': cleanItem.servingSize,
        'servingUnit': cleanItem.servingUnit,
        'calories': cleanItem.calories,
        'protein': cleanItem.protein,
        'carbohydrates': cleanItem.carbs,
        'fat': cleanItem.fat,
        'fiber': cleanItem.fiber,
        'sugar': cleanItem.sugar,
        'sodium': cleanItem.sodium,
        'createdBy': cId,
        'isPublic': cleanItem.isPublic,
      });

      final response = await http
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'] ?? decoded;
        final rawServerFood = FoodItem.fromJson(data as Map<String, dynamic>);
        final serverFood = rawServerFood.copyWith(
          createdBy: (rawServerFood.createdBy != null &&
                  rawServerFood.createdBy!.isNotEmpty &&
                  rawServerFood.createdBy != 'anonymous')
              ? rawServerFood.createdBy
              : cleanItem.createdBy,
          isPublic: cleanItem.isPublic,
        );

        // Update local item with server ID and verified data
        final idx = _customFoods.indexWhere((f) => f.id == cleanItem.id);
        if (idx != -1) {
          _customFoods[idx] = serverFood;
        } else {
          _customFoods.add(serverFood);
        }
        _serverFoods.removeWhere((f) => f.id == serverFood.id);
        _serverFoods.add(serverFood);

        _saveCustomFoodsToPrefs();
        _saveServerFoodsToPrefs();
        notifyListeners();
        return serverFood;
      }
    } catch (_) {
      // Offline fallback: stays in _customFoods with pending status
    }

    return cleanItem;
  }

  /// Pull global shared food catalog from backend PostgreSQL database
  Future<void> fetchGlobalFoods() async {
    try {
      final cId = resolveClientId(null);
      final url = Uri.parse('${AppConstants.apiBaseUrl}/foods?limit=500&userId=$cId');
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'x-client-id': cId,
      };
      final token = AuthService().token;
      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final items = (decoded['data']?['items'] ?? decoded['items'] ?? decoded['data']) as List<dynamic>?;
        if (items != null) {
          _serverFoods.clear();
          for (final item in items) {
            _serverFoods.add(FoodItem.fromJson(item as Map<String, dynamic>));
          }
          _saveServerFoodsToPrefs();
          notifyListeners();
        }
      }
    } catch (_) {
      // Retain previously cached server foods from SharedPreferences
    }
  }

  /// Retrieve all food log records for a given date and client
  List<FoodLogEntry> getFoodEntriesForDate(String dateString, {String? clientId}) {
    final cId = resolveClientId(clientId);
    return _foodLogs.where((e) {
      if (e.dateString != dateString) return false;
      return e.clientId == cId;
    }).toList();
  }

  /// Retrieve entries under a specific meal (Breakfast, Lunch, Snack, Dinner)
  List<FoodLogEntry> getMealEntries(String dateString, MealType mealType, {String? clientId}) {
    return getFoodEntriesForDate(dateString, clientId: clientId)
        .where((e) => e.mealType == mealType)
        .toList();
  }

  /// Calculate total nutrition for an individual meal
  MealNutritionSummary getMealSummary(String dateString, MealType mealType, {String? clientId}) {
    final entries = getMealEntries(dateString, mealType, clientId: clientId);
    return MealNutritionSummary(mealType: mealType, entries: entries);
  }

  /// Aggregate daily macro totals vs calculated targets
  DailyMacroSummary getDailyMacroSummary(String dateString, {String? clientId}) {
    final cId = resolveClientId(clientId);
    final dayEntries = getFoodEntriesForDate(dateString, clientId: cId);

    final targetCal = _assignedDietPlan?.dailyCalories.toDouble() ?? _customTargetCalories ?? _currentResult?.targetCalories.toDouble() ?? 2200.0;
    final targetProt = _assignedDietPlan?.protein ?? _customTargetProtein ?? _currentResult?.proteinGrams.toDouble() ?? 160.0;
    final targetCrbs = _assignedDietPlan?.carbs ?? _customTargetCarbs ?? _currentResult?.carbGrams.toDouble() ?? 250.0;
    final targetFt = _assignedDietPlan?.fat ?? _customTargetFat ?? _currentResult?.fatGrams.toDouble() ?? 70.0;
    final targetFbr = _assignedDietPlan?.fiber ?? _customTargetFiber ?? _currentResult?.fiberGrams.toDouble() ?? 30.0;

    double consumedCal = 0.0;
    double consumedProt = 0.0;
    double consumedCrbs = 0.0;
    double consumedFt = 0.0;
    double consumedFbr = 0.0;

    final Map<MealType, MealNutritionSummary> mealMap = {};

    for (final meal in MealType.values) {
      final mealEntries = dayEntries.where((e) => e.mealType == meal).toList();
      final summary = MealNutritionSummary(mealType: meal, entries: mealEntries);
      mealMap[meal] = summary;

      consumedCal += summary.totalCalories;
      consumedProt += summary.totalProtein;
      consumedCrbs += summary.totalCarbs;
      consumedFt += summary.totalFat;
      consumedFbr += summary.totalFiber;
    }

    return DailyMacroSummary(
      dateString: dateString,
      targetCalories: targetCal,
      targetProtein: targetProt,
      targetCarbs: targetCrbs,
      targetFat: targetFt,
      targetFiber: targetFbr,
      consumedCalories: consumedCal,
      consumedProtein: consumedProt,
      consumedCarbs: consumedCrbs,
      consumedFat: consumedFt,
      consumedFiber: consumedFbr,
      mealSummaries: mealMap,
    );
  }

  /// Explicitly set or update active assigned diet plan
  void setAssignedDietPlan(AssignedDietPlan? plan) {
    _assignedDietPlan = plan;
    if (plan != null) {
      setCustomDailyTargets(
        calories: plan.dailyCalories,
        protein: plan.protein,
        carbs: plan.carbohydrates,
        fat: plan.fat,
        fiber: plan.fiber,
      );
    }
    notifyListeners();
  }

  /// Fetch currently assigned diet plan from Coach/Trainer
  Future<void> fetchAssignedDietPlan() async {
    // Admins manage diet plans for athletes; they do not have personal assigned diet plans
    if (AuthService().isAdmin) return;

    try {
      final token = await AuthService().getValidToken();
      if (token.isEmpty) return;

      final url = Uri.parse('${AppConstants.apiBaseUrl}/client/me/diet-plan');
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'] ?? decoded;
        if (data != null && data is Map<String, dynamic> && data['planName'] != null) {
          final plan = AssignedDietPlan.fromJson(data);
          final bool changed = _assignedDietPlan == null ||
              _assignedDietPlan!.id != plan.id ||
              _assignedDietPlan!.version != plan.version ||
              _assignedDietPlan!.dailyCalories != plan.dailyCalories;

          _assignedDietPlan = plan;

          // Cache to local preferences to ensure availability on cold start/offline
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_prefAssignedDietPlanKey, jsonEncode(plan.toJson()));
          } catch (_) {}

          // Apply assigned targets
          setCustomDailyTargets(
            calories: plan.dailyCalories,
            protein: plan.protein,
            carbs: plan.carbohydrates,
            fat: plan.fat,
            fiber: plan.fiber,
          );
          if (changed) {
            notifyListeners();
          }
        } else if (data == null && _assignedDietPlan != null) {
          _assignedDietPlan = null;
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove(_prefAssignedDietPlanKey);
          } catch (_) {}
          notifyListeners();
        }
      }
    } catch (_) {
      // Offline fallback: retains active targets or defaults
    }
  }

  /// Pull actual food logs from backend for a specific date
  Future<void> fetchFoodLogsFromBackend(String dateString) async {
    // Admins do not have personal food logs under /client/me
    if (AuthService().isAdmin) return;
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/client/me/food-logs?date=$dateString');
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      final token = await AuthService().getValidToken();
      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'] ?? decoded;
        if (data is List) {
          final serverEntries = data.map((item) => FoodLogEntry.fromJson(item as Map<String, dynamic>)).toList();
          // Remove existing entries for date and replace with server verified records
          _foodLogs.removeWhere((e) => e.dateString == dateString);
          _foodLogs.addAll(serverEntries);
          _saveFoodLogsToPrefs();
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  /// Log a new food item into a meal
  void logFoodEntry(FoodLogEntry entry) {
    final validClientId = (entry.clientId.isNotEmpty && entry.clientId != entry.dateString)
        ? entry.clientId
        : resolveClientId(null);
    final normalized = entry.copyWith(clientId: validClientId);
    _foodLogs.add(normalized);
    _saveFoodLogsToPrefs();
    notifyListeners();

    // Asynchronously dispatch confirmed food log to backend PostgreSQL database
    _dispatchFoodLogToBackend(normalized);
  }

  Future<void> _dispatchFoodLogToBackend(FoodLogEntry entry) async {
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/client/me/food-logs');
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'x-client-id': entry.clientId,
      };
      final token = await AuthService().getValidToken();
      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final body = jsonEncode({
        'dateString': entry.dateString,
        'mealType': entry.mealType.displayName,
        'foodId': entry.foodId,
        'foodName': entry.foodName,
        'category': entry.category,
        'servingSize': entry.servingSize,
        'servingUnit': entry.servingUnit,
        'quantity': entry.quantity,
        'calories': entry.baseCalories * entry.quantity,
        'protein': entry.baseProtein * entry.quantity,
        'carbohydrates': entry.baseCarbs * entry.quantity,
        'fat': entry.baseFat * entry.quantity,
        'fiber': entry.baseFiber * entry.quantity,
        'source': entry.source,
        'isAiConfirmed': entry.isAiConfirmed,
        'loggedAt': (entry.loggedAt ?? entry.createdAt).toIso8601String(),
      });

      await http.post(url, headers: headers, body: body).timeout(const Duration(seconds: 5));
    } catch (_) {
      // Offline fallback: persists in local preferences
    }
  }

  /// Update quantity for an existing food entry
  void updateFoodEntryQuantity(String entryId, double newQuantity) {
    final index = _foodLogs.indexWhere((e) => e.id == entryId);
    if (index != -1) {
      if (newQuantity <= 0) {
        deleteFoodEntry(entryId);
      } else {
        _foodLogs[index] = _foodLogs[index].copyWith(quantity: newQuantity);
        _saveFoodLogsToPrefs();
        notifyListeners();
      }
    }
  }

  /// Delete a single food entry without affecting the rest of the meal
  void deleteFoodEntry(String entryId) {
    _foodLogs.removeWhere((e) => e.id == entryId);
    _saveFoodLogsToPrefs();
    notifyListeners();

    // Sync deletion to backend
    _dispatchDeleteFoodLogToBackend(entryId);
  }

  Future<void> _dispatchDeleteFoodLogToBackend(String entryId) async {
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/client/me/food-logs/$entryId');
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      final token = await AuthService().getValidToken();
      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      await http.delete(url, headers: headers).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  /// Clear all food entries for a specific date (useful for resets and tests)
  void clearEntriesForDate(String dateString) {
    _foodLogs.removeWhere((e) => e.dateString == dateString);
    _saveFoodLogsToPrefs();
    notifyListeners();
  }

  /// Securely upload and confirm live camera meal photo, link to Client ID, Meal ID,
  /// create food logs, and make visible to Admin
  Future<ConfirmedMealPhoto?> confirmAndUploadMealPhoto({
    String? capturedPhotoPath,
    Uint8List? capturedPhotoBytes,
    required String dateString,
    required MealType mealType,
    required String weightSource,
    required List<ScannedFoodItem> foods,
    String? mealId,
  }) async {
    final cId = resolveClientId(null);
    final finalMealId = mealId ?? 'meal_${DateTime.now().millisecondsSinceEpoch}_${foods.length}';

    // 1. Prepare Base64 payload
    String? base64Image;
    if (capturedPhotoBytes != null && capturedPhotoBytes.isNotEmpty) {
      base64Image = base64Encode(capturedPhotoBytes);
    } else if (capturedPhotoPath != null && capturedPhotoPath.isNotEmpty) {
      try {
        final file = File(capturedPhotoPath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          base64Image = base64Encode(bytes);
        }
      } catch (e) {
        debugPrint('[CONFIRM MEAL PHOTO] Error reading local image: $e');
      }
    }

    ConfirmedMealPhoto? confirmedPhoto;

    // 2. Dispatch to backend if image is available
    if (base64Image != null && base64Image.isNotEmpty) {
      try {
        final url = Uri.parse('${AppConstants.apiBaseUrl}/client/me/food-photos/confirm');
        final headers = <String, String>{
          'Content-Type': 'application/json',
          'x-client-id': cId,
        };
        final token = AuthService().token;
        if (token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }

        final itemsPayload = foods.map((f) => {
          'foodName': f.name,
          'foodId': f.matchedFoodId,
          'servingSize': f.estimatedGrams,
          'servingUnit': 'g',
          'quantity': 1.0,
          'calories': f.calories,
          'protein': f.protein,
          'carbohydrates': f.carbs,
          'fat': f.fat,
          'fiber': f.fiber,
          'category': f.category,
          'source': f.source == 'ALPHA_X_LIBRARY' ? 'FOOD_LIBRARY' : 'AI_CAMERA',
          'weightSource': f.weightSource,
        }).toList();

        final body = jsonEncode({
          'imageBase64': base64Image,
          'mimeType': 'image/jpeg',
          'mealId': finalMealId,
          'dateString': dateString,
          'mealType': mealType.displayName,
          'weightSource': weightSource,
          'items': itemsPayload,
        });

        final response = await http
            .post(url, headers: headers, body: body)
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200 || response.statusCode == 201) {
          final decoded = jsonDecode(response.body);
          final data = decoded['data'] ?? decoded;
          if (data['mealPhoto'] != null) {
            confirmedPhoto = ConfirmedMealPhoto.fromJson(data['mealPhoto'] as Map<String, dynamic>);
          }
        }
      } catch (e) {
        debugPrint('[CONFIRM MEAL PHOTO] Network / backend notice: $e');
      }
    }

    // 3. Create and store confirmed local FoodLogEntry records
    for (final food in foods) {
      final entry = food.toFoodLogEntry(
        clientId: cId,
        dateString: dateString,
        mealType: mealType,
        mealId: finalMealId,
        mealPhotoId: confirmedPhoto?.id,
        photoAvailable: confirmedPhoto != null,
      );
      _foodLogs.add(entry);
    }

    _saveFoodLogsToPrefs();
    notifyListeners();

    return confirmedPhoto;
  }

  // ==========================================
  // ADMIN NUTRITION SYSTEM API HELPERS
  // ==========================================

  /// Admin: Fetch target vs actual nutrition summary for any client
  Future<Map<String, dynamic>?> fetchAdminNutritionSummary(String clientId, String dateString) async {
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/admin/clients/$clientId/nutrition-summary?date=$dateString');
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      final token = AuthService().token;
      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'] ?? decoded;
        if (data is Map<String, dynamic>) {
          return data;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Admin: Assign structured diet plan with versioning
  Future<bool> assignAdminDietPlan({
    required String clientId,
    required String planName,
    required double dailyCalories,
    required double protein,
    required double carbs,
    required double fat,
    required double fiber,
    required double waterTargetLiters,
    String? notes,
    required List<PrescribedMeal> meals,
  }) async {
    try {
      var token = await AuthService().getValidToken();

      final url = Uri.parse('${AppConstants.apiBaseUrl}/admin/clients/$clientId/diet-plans');
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final body = jsonEncode({
        'planName': planName,
        'dailyCalories': dailyCalories,
        'protein': protein,
        'carbohydrates': carbs,
        'fat': fat,
        'fiber': fiber,
        'waterTargetLiters': waterTargetLiters,
        'notes': notes,
        'meals': meals.map((m) => m.toJson()).toList(),
      });

      var response = await http.post(url, headers: headers, body: body).timeout(const Duration(seconds: 10));

      // Automatic 401 retry with re-authenticated admin token
      if (response.statusCode == 401 && AuthService().isAdmin) {
        final freshToken = await AuthService().refreshAdminToken();
        if (freshToken != null && freshToken.isNotEmpty) {
          token = freshToken;
          headers['Authorization'] = 'Bearer $token';
          response = await http.post(url, headers: headers, body: body).timeout(const Duration(seconds: 10));
        }
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (clientId == resolveClientId(null) || clientId == AuthService().currentUserId) {
          fetchAssignedDietPlan();
        }
        AppAutoRefreshService.instance.triggerImmediateSync(reason: 'Admin saved diet plan');
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Admin: Fetch version history of diet plans
  Future<List<Map<String, dynamic>>> fetchAdminDietHistory(String clientId) async {
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/admin/clients/$clientId/diet-plans/history');
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      final token = AuthService().token;
      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'] ?? decoded;
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
      }
    } catch (_) {}
    return [];
  }

  /// Seed realistic food tracking data for today and yesterday
  void _seedFoodLogData() {
    final today = getTodayDateString();
    final yesterday = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 1)));
    final clientId = resolveClientId(null);

    final dosa = FoodDatabase.defaultFoods.firstWhere(
      (f) => f.id == 'food_plain_dosa' || f.id == 'food_dosa_plain_standard' || f.name.toLowerCase().contains('dosa'),
      orElse: () => FoodDatabase.defaultFoods.first,
    );
    final egg = FoodDatabase.defaultFoods.firstWhere(
      (f) => f.id == 'food_egg_whole' || f.name.toLowerCase().contains('egg'),
      orElse: () => FoodDatabase.defaultFoods.first,
    );
    final rice = FoodDatabase.defaultFoods.firstWhere(
      (f) => f.id == 'food_rice_white_cooked' || f.id == 'food_cooked_white_rice' || f.name.toLowerCase().contains('rice'),
      orElse: () => FoodDatabase.defaultFoods.first,
    );
    final chicken = FoodDatabase.defaultFoods.firstWhere(
      (f) => f.id == 'food_chicken_breast_cooked' || f.name.toLowerCase().contains('chicken breast'),
      orElse: () => FoodDatabase.defaultFoods.first,
    );
    final veg = FoodDatabase.defaultFoods.firstWhere(
      (f) => f.id == 'food_broccoli_steamed' || f.name.toLowerCase().contains('broccoli') || f.category == 'Vegetables',
      orElse: () => FoodDatabase.defaultFoods.first,
    );
    final banana = FoodDatabase.defaultFoods.firstWhere(
      (f) => f.id == 'food_banana_ripe' || f.name.toLowerCase().contains('banana'),
      orElse: () => FoodDatabase.defaultFoods.first,
    );
    final whey = FoodDatabase.defaultFoods.firstWhere(
      (f) => f.id == 'food_whey_isolate' || f.id == 'food_whey_concentrate' || f.name.toLowerCase().contains('whey'),
      orElse: () => FoodDatabase.defaultFoods.first,
    );

    // TODAY: Breakfast: 3 Dosa, 3 Eggs
    _foodLogs.add(FoodLogEntry.fromFoodItem(
      clientId: clientId,
      dateString: today,
      mealType: MealType.breakfast,
      food: dosa,
      quantity: 3.0,
    ));
    _foodLogs.add(FoodLogEntry.fromFoodItem(
      clientId: clientId,
      dateString: today,
      mealType: MealType.breakfast,
      food: egg,
      quantity: 3.0,
    ));

    // TODAY: Lunch: 2 cups Rice, 150g Chicken (1.5x 100g), 1 cup Vegetables
    _foodLogs.add(FoodLogEntry.fromFoodItem(
      clientId: clientId,
      dateString: today,
      mealType: MealType.lunch,
      food: rice,
      quantity: 2.0,
    ));
    _foodLogs.add(FoodLogEntry.fromFoodItem(
      clientId: clientId,
      dateString: today,
      mealType: MealType.lunch,
      food: chicken,
      quantity: 1.5,
    ));
    _foodLogs.add(FoodLogEntry.fromFoodItem(
      clientId: clientId,
      dateString: today,
      mealType: MealType.lunch,
      food: veg,
      quantity: 1.0,
    ));

    // TODAY: Snack: 1 Banana, 1 Scoop Whey Protein
    _foodLogs.add(FoodLogEntry.fromFoodItem(
      clientId: clientId,
      dateString: today,
      mealType: MealType.snack,
      food: banana,
      quantity: 1.0,
    ));
    _foodLogs.add(FoodLogEntry.fromFoodItem(
      clientId: clientId,
      dateString: today,
      mealType: MealType.snack,
      food: whey,
      quantity: 1.0,
    ));

    // YESTERDAY: Separate day data preserving date tracking
    _foodLogs.add(FoodLogEntry.fromFoodItem(
      clientId: clientId,
      dateString: yesterday,
      mealType: MealType.breakfast,
      food: dosa,
      quantity: 2.0,
    ));
    _foodLogs.add(FoodLogEntry.fromFoodItem(
      clientId: clientId,
      dateString: yesterday,
      mealType: MealType.breakfast,
      food: egg,
      quantity: 2.0,
    ));
    _foodLogs.add(FoodLogEntry.fromFoodItem(
      clientId: clientId,
      dateString: yesterday,
      mealType: MealType.lunch,
      food: rice,
      quantity: 1.5,
    ));
    _foodLogs.add(FoodLogEntry.fromFoodItem(
      clientId: clientId,
      dateString: yesterday,
      mealType: MealType.lunch,
      food: chicken,
      quantity: 1.0,
    ));
  }

  // --- LOCAL PERSISTENCE ---

  Future<void> _loadLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Restore persistent macro targets & profile input
      final inputJson = prefs.getString(_prefCurrentInputKey);
      if (inputJson != null && inputJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(inputJson) as Map<String, dynamic>;
          _currentInput = MacroInput.fromJson(decoded);
          if (_currentInput != null) {
            _currentResult = MacroCalculator.calculate(input: _currentInput!, settings: _settings);
          }
        } catch (_) {}
      }

      final targetsJson = prefs.getString(_prefTargetsKey);
      if (targetsJson != null && targetsJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(targetsJson) as Map<String, dynamic>;
          _customTargetCalories = (decoded['calories'] as num?)?.toDouble();
          _customTargetProtein = (decoded['protein'] as num?)?.toDouble();
          _customTargetCarbs = (decoded['carbs'] as num?)?.toDouble();
          _customTargetFat = (decoded['fat'] as num?)?.toDouble();
          _customTargetFiber = (decoded['fiber'] as num?)?.toDouble();
        } catch (_) {}
      }

      final histJson = prefs.getString(_prefHistoryKey);
      if (histJson != null && histJson.isNotEmpty) {
        try {
          final List<dynamic> list = jsonDecode(histJson);
          _history.clear();
          for (final item in list) {
            _history.add(MacroHistoryEntry.fromJson(item as Map<String, dynamic>));
          }
        } catch (_) {}
      }

      final customJson = prefs.getString(_prefCustomFoodsKey);
      if (customJson != null && customJson.isNotEmpty) {
        final List<dynamic> list = jsonDecode(customJson);
        _customFoods.clear();
        for (final item in list) {
          _customFoods.add(FoodItem.fromJson(item as Map<String, dynamic>));
        }
      }

      final serverJson = prefs.getString(_prefServerFoodsKey);
      if (serverJson != null && serverJson.isNotEmpty) {
        final List<dynamic> list = jsonDecode(serverJson);
        _serverFoods.clear();
        for (final item in list) {
          _serverFoods.add(FoodItem.fromJson(item as Map<String, dynamic>));
        }
      }

      final logsJson = prefs.getString(_prefFoodLogsKey);
      if (logsJson != null && logsJson.isNotEmpty) {
        final List<dynamic> list = jsonDecode(logsJson);
        _foodLogs.clear();
        for (final item in list) {
          _foodLogs.add(FoodLogEntry.fromJson(item as Map<String, dynamic>));
        }
      } else if (_isTest) {
        _seedFoodLogData();
      }

      // Restore assigned diet plan cache from trainer/admin
      final dietJson = prefs.getString(_prefAssignedDietPlanKey);
      if (dietJson != null && dietJson.isNotEmpty) {
        try {
          final decodedDiet = jsonDecode(dietJson) as Map<String, dynamic>;
          final plan = AssignedDietPlan.fromJson(decodedDiet);
          _assignedDietPlan = plan;
          setCustomDailyTargets(
            calories: plan.dailyCalories,
            protein: plan.protein,
            carbs: plan.carbohydrates,
            fat: plan.fat,
            fiber: plan.fiber,
          );
        } catch (_) {}
      }

      notifyListeners();

      // Trigger asynchronous background fetch from backend
      fetchGlobalFoods();
      if (AuthService().currentToken.isNotEmpty) {
        fetchAssignedDietPlan();
      }
    } catch (_) {
      // In test environments only, fallback to in-memory seeds
      if (_foodLogs.isEmpty && _isTest) {
        _seedFoodLogData();
      }
    }
  }

  Future<void> _saveTargetsToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_currentInput != null) {
        await prefs.setString(_prefCurrentInputKey, jsonEncode(_currentInput!.toJson()));
      }
      final targetsMap = {
        'calories': _customTargetCalories,
        'protein': _customTargetProtein,
        'carbs': _customTargetCarbs,
        'fat': _customTargetFat,
        'fiber': _customTargetFiber,
      };
      await prefs.setString(_prefTargetsKey, jsonEncode(targetsMap));
      final histList = _history.map((e) => e.toJson()).toList();
      await prefs.setString(_prefHistoryKey, jsonEncode(histList));
    } catch (_) {}
  }

  Future<void> _saveFoodLogsToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _foodLogs.map((e) => e.toJson()).toList();
      await prefs.setString(_prefFoodLogsKey, jsonEncode(list));
    } catch (_) {}
  }

  Future<void> _saveCustomFoodsToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _customFoods.map((e) => e.toJson()).toList();
      await prefs.setString(_prefCustomFoodsKey, jsonEncode(list));
    } catch (_) {}
  }

  Future<void> _saveServerFoodsToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _serverFoods.map((e) => e.toJson()).toList();
      await prefs.setString(_prefServerFoodsKey, jsonEncode(list));
    } catch (_) {}
  }
}

