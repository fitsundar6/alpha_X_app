import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/core/constants/app_constants.dart';
import 'package:alpha_x_gym/features/exercise/domain/models/exercise_model.dart';
import 'package:alpha_x_gym/features/exercise/data/default_exercise_catalog.dart';

enum ExerciseSortOption {
  nameAsc,
  nameDesc,
  categoryAsc,
  recentlyUpdated,
}

class ExerciseRepository extends ChangeNotifier {
  static final ExerciseRepository _instance = ExerciseRepository._internal();
  factory ExerciseRepository() => _instance;
  static ExerciseRepository get instance => _instance;

  static const String _storageKey = 'alpha_x_custom_exercises';
  static const String _customEquipmentKey = 'alpha_x_custom_equipment';

  final List<Exercise> _exercises = [];
  final List<String> _customEquipment = [];
  bool _isLoaded = false;

  ExerciseRepository._internal() {
    _initDefaultExercises();
    _loadFromLocal();
  }

  bool get isLoaded => _isLoaded;
  List<Exercise> get allExercises => List.unmodifiable(_exercises);
  List<Exercise> get activeExercises =>
      List.unmodifiable(_exercises.where((e) => e.isActive));
  List<Exercise> get archivedExercises =>
      List.unmodifiable(_exercises.where((e) => !e.isActive));

  List<String> get availableEquipment {
    final defaultList = ExerciseEquipment.values.map((e) => e.displayName).toList();
    for (final c in _customEquipment) {
      if (!defaultList.contains(c)) {
        defaultList.add(c);
      }
    }
    return List.unmodifiable(defaultList);
  }

  void _initDefaultExercises() {
    _exercises.clear();
    _exercises.addAll(defaultAlphaXExercises);
  }

  Future<void> _loadFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customJson = prefs.getString(_storageKey);
      if (customJson != null) {
        final List<dynamic> list = jsonDecode(customJson);
        for (final item in list) {
          final ex = Exercise.fromJson(item as Map<String, dynamic>);
          final idx = _exercises.indexWhere((e) => e.id == ex.id);
          if (idx >= 0) {
            _exercises[idx] = ex;
          } else {
            _exercises.add(ex);
          }
        }
      }

      // Ensure all default catalog exercises are always preserved
      for (final defaultEx in defaultAlphaXExercises) {
        if (!_exercises.any((e) => e.id == defaultEx.id)) {
          _exercises.add(defaultEx);
        }
      }

      final equipmentList = prefs.getStringList(_customEquipmentKey);
      if (equipmentList != null) {
        _customEquipment.clear();
        _customEquipment.addAll(equipmentList);
      }
    } catch (_) {
      // Graceful fallback to default in-memory list
    } finally {
      _isLoaded = true;
      notifyListeners();
      fetchRemoteExercises();
    }
  }

  /// Sync latest global exercises from central backend PostgreSQL database
  Future<void> fetchRemoteExercises() async {
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/exercises?limit=500');
      final headers = <String, String>{'Content-Type': 'application/json'};
      final token = AuthService().token;
      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final items = (decoded['data']?['items'] ?? decoded['items'] ?? decoded['data']) as List<dynamic>?;
        if (items != null) {
          for (final item in items) {
            try {
              final remoteEx = Exercise.fromJson(item as Map<String, dynamic>);
              final idx = _exercises.indexWhere((e) => e.id == remoteEx.id);
              if (idx >= 0) {
                _exercises[idx] = remoteEx;
              } else {
                _exercises.add(remoteEx);
              }
            } catch (_) {}
          }
          await _saveToLocal();
          notifyListeners();
        }
      }
    } catch (_) {
      // Retain offline cached exercises
    }
  }

  Future<void> _saveToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _exercises.map((e) => e.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(list));
      await prefs.setStringList(_customEquipmentKey, _customEquipment);
    } catch (_) {}
  }

  // ==========================================
  // ADMIN CRUD OPERATIONS
  // ==========================================

  void addExercise(Exercise exercise) {
    _exercises.add(exercise);
    _saveToLocal();
    notifyListeners();
  }

  void updateExercise(Exercise exercise) {
    final idx = _exercises.indexWhere((e) => e.id == exercise.id);
    if (idx >= 0) {
      _exercises[idx] = exercise.copyWith(updatedAt: DateTime.now());
      _saveToLocal();
      notifyListeners();
    }
  }

  void duplicateExercise(String exerciseId) {
    final original = getExerciseById(exerciseId);
    if (original == null) return;

    final duplicated = original.copyWith(
      id: 'ex_${DateTime.now().millisecondsSinceEpoch}',
      name: '${original.name} (Copy)',
      displayName: '${original.displayName} (Copy)',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _exercises.add(duplicated);
    _saveToLocal();
    notifyListeners();
  }

  void archiveExercise(String exerciseId) {
    final idx = _exercises.indexWhere((e) => e.id == exerciseId);
    if (idx >= 0) {
      _exercises[idx] = _exercises[idx].copyWith(isActive: false);
      _saveToLocal();
      notifyListeners();
    }
  }

  void restoreExercise(String exerciseId) {
    final idx = _exercises.indexWhere((e) => e.id == exerciseId);
    if (idx >= 0) {
      _exercises[idx] = _exercises[idx].copyWith(isActive: true);
      _saveToLocal();
      notifyListeners();
    }
  }

  void addCustomEquipment(String equipmentName) {
    final trimmed = equipmentName.trim();
    if (trimmed.isNotEmpty && !_customEquipment.contains(trimmed)) {
      _customEquipment.add(trimmed);
      _saveToLocal();
      notifyListeners();
    }
  }

  Exercise? getExerciseById(String id) {
    if (id.trim().isEmpty) return null;
    final cleanId = id.trim().toLowerCase();
    try {
      return _exercises.firstWhere((e) => e.id.toLowerCase() == cleanId);
    } catch (_) {
      try {
        final altId = cleanId.startsWith('ex_')
            ? cleanId.substring(3)
            : 'ex_$cleanId';
        return _exercises.firstWhere((e) => e.id.toLowerCase() == altId);
      } catch (_) {
        try {
          return _exercises.firstWhere((e) =>
              e.approvedAlternativeIds.any((a) => a.toLowerCase() == cleanId));
        } catch (_) {
          return null;
        }
      }
    }
  }

  List<Exercise> getAlternatives(String exerciseId) {
    final original = getExerciseById(exerciseId);
    if (original == null) return [];

    final List<Exercise> results = [];

    // Return explicitly approved alternatives first
    for (final altId in original.approvedAlternativeIds) {
      final alt = getExerciseById(altId);
      if (alt != null && alt.isActive && alt.id != exerciseId && !results.any((e) => e.id == alt.id)) {
        results.add(alt);
      }
    }

    // Biomechanical matching by same primary muscle
    final sameMuscle = _exercises.where((e) =>
        e.id != exerciseId &&
        e.isActive &&
        !results.any((r) => r.id == e.id) &&
        e.primaryMuscles.any((m) => original.primaryMuscles.contains(m)));
    results.addAll(sameMuscle);

    // If still needed, matching by category
    if (results.length < 8) {
      final sameCategory = _exercises.where((e) =>
          e.id != exerciseId &&
          e.isActive &&
          !results.any((r) => r.id == e.id) &&
          e.category.toLowerCase() == original.category.toLowerCase());
      results.addAll(sameCategory);
    }

    return results;
  }

  List<Exercise> searchExercises({
    String? query,
    String? category,
    String? muscle,
    String? equipment,
    String? movementPattern,
    String? difficulty,
    bool includeArchived = false,
    ExerciseSortOption sort = ExerciseSortOption.nameAsc,
  }) {
    var results = _exercises.where((e) {
      if (!includeArchived && !e.isActive) return false;

      // 1. Category / Group Filter
      if (category != null && category.isNotEmpty && category != 'All') {
        final catLower = category.toLowerCase().trim();
        if (catLower == 'legs') {
          final isLegs = e.category.toLowerCase() == 'legs' ||
              e.category.toLowerCase() == 'quadriceps' ||
              e.category.toLowerCase() == 'hamstrings' ||
              e.category.toLowerCase() == 'calves' ||
              e.category.toLowerCase() == 'glutes' ||
              e.tags.any((t) => t.toLowerCase() == 'legs');
          if (!isLegs) return false;
        } else if (catLower == 'arms') {
          final isArms = e.category.toLowerCase() == 'arms' ||
              e.category.toLowerCase() == 'biceps' ||
              e.category.toLowerCase() == 'triceps' ||
              e.category.toLowerCase() == 'forearms' ||
              e.tags.any((t) => t.toLowerCase() == 'arms');
          if (!isArms) return false;
        } else if (catLower == 'functional') {
          final isFunc = e.category.toLowerCase() == 'functional' ||
              e.category.toLowerCase() == 'conditioning' ||
              e.category.toLowerCase() == 'full body' ||
              e.tags.any((t) => t.toLowerCase() == 'functional');
          if (!isFunc) return false;
        } else if (e.category.toLowerCase() != catLower) {
          return false;
        }
      }

      // 2. Query Search with Smart Partial Matching & Tokenization
      if (query != null && query.trim().isNotEmpty) {
        final q = query.trim().toLowerCase();
        final tokens = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

        final matchesAllTokens = tokens.every((token) {
          final matchesName = e.name.toLowerCase().contains(token) ||
              e.displayName.toLowerCase().contains(token);
          final matchesCategory = e.category.toLowerCase().contains(token);
          final matchesPrimaryMuscle = e.primaryMuscles.any((m) =>
              m.displayName.toLowerCase().contains(token) ||
              m.name.toLowerCase().contains(token));
          final matchesSecondaryMuscle = e.secondaryMuscles.any((m) =>
              m.displayName.toLowerCase().contains(token) ||
              m.name.toLowerCase().contains(token));
          final matchesEquipment = e.equipment.toLowerCase().contains(token);
          final matchesMovement = e.movementPattern.toLowerCase().contains(token);
          final matchesTags = e.tags.any((t) => t.toLowerCase().contains(token));
          final matchesDescription = e.description.toLowerCase().contains(token);

          // Keyword synonym expansions:
          bool matchesSynonyms = false;
          if (token == 'bench') {
            matchesSynonyms = e.tags.any((t) => t.toLowerCase().contains('bench')) ||
                e.name.toLowerCase().contains('bench') ||
                (e.category.toLowerCase() == 'chest' && e.movementPattern.toLowerCase().contains('push'));
          } else if (token == 'lat' || token == 'lats') {
            matchesSynonyms = e.name.toLowerCase().contains('lat') ||
                e.displayName.toLowerCase().contains('lat') ||
                e.tags.any((t) => t.toLowerCase().contains('lat')) ||
                e.primaryMuscles.any((m) => m == MuscleGroup.lats) ||
                (e.category.toLowerCase() == 'back' && e.movementPattern.toLowerCase().contains('pull'));
          } else if (token == 'shoulder' || token == 'shoulders') {
            matchesSynonyms = e.category.toLowerCase() == 'shoulders' ||
                e.tags.any((t) => t.toLowerCase().contains('shoulder')) ||
                e.name.toLowerCase().contains('shoulder') ||
                e.name.toLowerCase().contains('overhead') ||
                e.name.toLowerCase().contains('deltoid') ||
                e.primaryMuscles.any((m) =>
                    m == MuscleGroup.shoulders ||
                    m == MuscleGroup.frontDelts ||
                    m == MuscleGroup.sideDelts ||
                    m == MuscleGroup.rearDelts);
          } else if (token == 'curl') {
            matchesSynonyms = e.name.toLowerCase().contains('curl') ||
                e.tags.any((t) => t.toLowerCase().contains('curl')) ||
                e.category.toLowerCase() == 'biceps';
          } else if (token == 'squat') {
            matchesSynonyms = e.name.toLowerCase().contains('squat') ||
                e.movementPattern.toLowerCase() == 'squat' ||
                e.tags.any((t) => t.toLowerCase().contains('squat'));
          } else if (token == 'cable') {
            matchesSynonyms = e.equipment.toLowerCase() == 'cable' ||
                e.name.toLowerCase().contains('cable') ||
                e.tags.any((t) => t.toLowerCase() == 'cable');
          }

          return matchesName ||
              matchesCategory ||
              matchesPrimaryMuscle ||
              matchesSecondaryMuscle ||
              matchesEquipment ||
              matchesMovement ||
              matchesTags ||
              matchesDescription ||
              matchesSynonyms;
        });

        if (!matchesAllTokens) return false;
      }

      // 3. Muscle Filter
      if (muscle != null && muscle.isNotEmpty && muscle != 'All') {
        final hasMuscle = e.primaryMuscles.any((m) =>
                m.displayName.toLowerCase() == muscle.toLowerCase() ||
                m.name.toLowerCase() == muscle.toLowerCase()) ||
            e.secondaryMuscles.any((m) =>
                m.displayName.toLowerCase() == muscle.toLowerCase() ||
                m.name.toLowerCase() == muscle.toLowerCase());
        if (!hasMuscle) return false;
      }

      // 4. Equipment Filter
      if (equipment != null && equipment.isNotEmpty && equipment != 'All') {
        if (e.equipment.toLowerCase() != equipment.toLowerCase()) return false;
      }

      // 5. Movement Pattern Filter
      if (movementPattern != null && movementPattern.isNotEmpty && movementPattern != 'All') {
        if (e.movementPattern.toLowerCase() != movementPattern.toLowerCase()) return false;
      }

      // 6. Difficulty Filter
      if (difficulty != null && difficulty.isNotEmpty && difficulty != 'All') {
        if (e.difficulty.toLowerCase() != difficulty.toLowerCase()) return false;
      }

      return true;
    }).toList();

    // Sort results
    switch (sort) {
      case ExerciseSortOption.nameAsc:
        results.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case ExerciseSortOption.nameDesc:
        results.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case ExerciseSortOption.categoryAsc:
        results.sort((a, b) => a.category.compareTo(b.category));
        break;
      case ExerciseSortOption.recentlyUpdated:
        results.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
    }

    return results;
  }

  // ==========================================
  // STATIC BACKWARD-COMPATIBILITY METHODS
  // ==========================================
  static List<Exercise> getAllExercises() {
    return _instance.allExercises;
  }

  static Exercise? getById(String id) {
    return _instance.getExerciseById(id);
  }

  static List<Exercise> getApprovedAlternatives(String exerciseId) {
    return _instance.getAlternatives(exerciseId);
  }

  static List<Exercise> getApprovedAlternativesStatic(String exerciseId) {
    return _instance.getAlternatives(exerciseId);
  }
}
