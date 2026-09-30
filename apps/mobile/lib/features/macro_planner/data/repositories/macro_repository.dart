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
import 'package:alpha_x_gym/features/macro_planner/data/food_database.dart';
import 'package:alpha_x_gym/features/macro_planner/domain/services/macro_calculator.dart';

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

  // Daily target overrides (allowing coaches/clients to set benchmark targets)
  double? _customTargetCalories;
  double? _customTargetProtein;
  double? _customTargetCarbs;
  double? _customTargetFat;
  double? _customTargetFiber;

  MacroRepository({MacroSettings? initialSettings})
      : _settings = initialSettings ?? MacroSettings.defaults() {
    _seedDefaultData();
    _loadLocalCache();
  }

  // Getters
  MacroSettings get settings => _settings;
  MacroInput? get currentInput => _currentInput;
  MacroResult? get currentResult => _currentResult;
  MacroResult? get activeResult => _currentResult;
  List<MacroHistoryEntry> get history => List.unmodifiable(_history);
  List<MacroProgressReview> get reviews => List.unmodifiable(_reviews);

  bool get hasActiveTarget => _currentResult != null;

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
  }

  /// Re-apply an old historical calculation snapshot as active target
  void restoreFromHistory(MacroHistoryEntry entry) {
    _currentInput = entry.input;
    _currentResult = entry.result;
    notifyListeners();
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
      if (uId.isNotEmpty && uId != 'client_guest') return uId;
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

    final targetCal = _customTargetCalories ?? _currentResult?.targetCalories.toDouble() ?? 2200.0;
    final targetProt = _customTargetProtein ?? _currentResult?.proteinGrams.toDouble() ?? 160.0;
    final targetCrbs = _customTargetCarbs ?? _currentResult?.carbGrams.toDouble() ?? 250.0;
    final targetFt = _customTargetFat ?? _currentResult?.fatGrams.toDouble() ?? 70.0;
    final targetFbr = _customTargetFiber ?? _currentResult?.fiberGrams.toDouble() ?? 30.0;

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

  /// Log a new food item into a meal
  void logFoodEntry(FoodLogEntry entry) {
    final validClientId = (entry.clientId.isNotEmpty && entry.clientId != entry.dateString)
        ? entry.clientId
        : resolveClientId(null);
    final normalized = entry.copyWith(clientId: validClientId);
    _foodLogs.add(normalized);
    _saveFoodLogsToPrefs();
    notifyListeners();
  }

  /// Update quantity for an existing food entry
  void updateFoodEntryQuantity(String entryId, double newQuantity) {
    final index = _foodLogs.indexWhere((e) => e.id == entryId);
    if (index != -1) {
      if (newQuantity <= 0) {
        _foodLogs.removeAt(index);
      } else {
        _foodLogs[index] = _foodLogs[index].copyWith(quantity: newQuantity);
      }
      _saveFoodLogsToPrefs();
      notifyListeners();
    }
  }

  /// Delete a single food entry without affecting the rest of the meal
  void deleteFoodEntry(String entryId) {
    _foodLogs.removeWhere((e) => e.id == entryId);
    _saveFoodLogsToPrefs();
    notifyListeners();
  }

  /// Clear all food entries for a specific date (useful for resets and tests)
  void clearEntriesForDate(String dateString) {
    _foodLogs.removeWhere((e) => e.dateString == dateString);
    _saveFoodLogsToPrefs();
    notifyListeners();
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
      } else {
        _seedFoodLogData();
      }
      notifyListeners();

      // Trigger asynchronous background fetch from backend
      fetchGlobalFoods();
    } catch (_) {
      // In test environments or first run, fallback to in-memory seeds
      if (_foodLogs.isEmpty) {
        _seedFoodLogData();
      }
    }
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

