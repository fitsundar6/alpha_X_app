import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../models/food_photo_model.dart';

class FoodPhotoTrackingService {
  static final FoodPhotoTrackingService _instance = FoodPhotoTrackingService._internal();
  factory FoodPhotoTrackingService() => _instance;
  FoodPhotoTrackingService._internal();

  static const String _storageKeyOfflinePhotos = 'alpha_x_offline_food_photos';
  static const String _storageKeyCachedPhotos = 'alpha_x_cached_my_food_photos';

  bool _isSyncing = false;

  /// Helper to get auth headers with Bearer token
  Map<String, String> _getAuthHeaders() {
    final token = AuthService().currentToken;
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Records a live captured food photo.
  /// If device is online, uploads to backend.
  /// If offline or server unreachable, saves locally into offline queue.
  Future<FoodPhotoModel> recordLiveFoodPhoto({
    required String imageBase64,
    required String mealType,
    required DateTime capturedAt,
    String? clientNote,
    String? localFilePath,
  }) async {
    final cleanMealType = mealType.trim();
    final clientId = AuthService().currentClientId.isNotEmpty
        ? AuthService().currentClientId
        : 'AXG-CLIENT';
    final dateString = capturedAt.toIso8601String().split('T')[0];
    final timezone = DateTime.now().timeZoneName;

    // Construct local model
    final pendingPhoto = FoodPhotoModel(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      clientId: clientId,
      clientName: AuthService().currentUserName,
      dateString: dateString,
      mealType: cleanMealType,
      capturedAt: capturedAt,
      status: 'PENDING',
      clientNote: clientNote?.trim(),
      photoUrl: localFilePath ?? '',
      localFilePath: localFilePath,
      isPendingSync: true,
      timezone: timezone,
    );

    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/food-photos/live');
      final res = await http.post(
        url,
        headers: _getAuthHeaders(),
        body: jsonEncode({
          'image': imageBase64,
          'mealType': cleanMealType,
          'capturedAt': capturedAt.toIso8601String(),
          'timezone': timezone,
          'clientNote': clientNote?.trim(),
        }),
      ).timeout(const Duration(seconds: 14));

      if (res.statusCode == 200 || res.statusCode == 201) {
        final decoded = jsonDecode(res.body);
        if (decoded['data'] != null && decoded['data']['foodPhoto'] != null) {
          final serverPhoto = FoodPhotoModel.fromJson(decoded['data']['foodPhoto']);
          await _cachePhotoLocally(serverPhoto);
          return serverPhoto;
        }
      }
      throw Exception('Server returned status ${res.statusCode}');
    } catch (e) {
      debugPrint('[FOOD PHOTO TRACKING] Upload notice ($e) - saving to offline queue');
      await _savePhotoToOfflineQueue(
        photo: pendingPhoto,
        imageBase64: imageBase64,
      );
      await _cachePhotoLocally(pendingPhoto);
      return pendingPhoto;
    }
  }

  /// Retrieves photo history for the authenticated client.
  Future<List<FoodPhotoModel>> getClientFoodPhotos({
    String? dateString,
    String? mealType,
  }) async {
    List<FoodPhotoModel> results = [];

    try {
      final queryParams = <String, String>{};
      if (dateString != null && dateString.isNotEmpty) queryParams['dateString'] = dateString;
      if (mealType != null && mealType.isNotEmpty) queryParams['mealType'] = mealType;

      final uri = Uri.parse('${AppConstants.apiBaseUrl}/food-photos/my-photos').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      final res = await http.get(uri, headers: _getAuthHeaders()).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded['data'] != null && decoded['data']['photos'] is List) {
          final list = (decoded['data']['photos'] as List)
              .map((item) => FoodPhotoModel.fromJson(Map<String, dynamic>.from(item)))
              .toList();
          results = list;
          await _saveCachedPhotos(list);
        }
      }
    } catch (e) {
      debugPrint('[FOOD PHOTO TRACKING] Fetch network notice: $e, using cached/offline data');
      results = await _loadCachedPhotos();
    }

    // Merge any pending offline photos that are not yet on the server
    final offlinePhotos = await _loadOfflineQueuePhotos();
    final combined = <FoodPhotoModel>[];

    for (final off in offlinePhotos) {
      if (dateString != null && off.dateString != dateString) continue;
      if (mealType != null && off.mealType.toLowerCase() != mealType.toLowerCase()) continue;
      combined.add(off);
    }

    for (final p in results) {
      if (!combined.any((c) => c.id == p.id)) {
        combined.add(p);
      }
    }

    combined.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    return combined;
  }

  /// Admin Monitoring: Fetches food photos across clients or filtered by client / date.
  Future<Map<String, dynamic>> getAdminFoodPhotosMonitoring({
    String? clientId,
    String? dateString,
    String? mealType,
    String? status,
    String? search,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (clientId != null && clientId.isNotEmpty) queryParams['clientId'] = clientId;
      if (dateString != null && dateString.isNotEmpty) queryParams['dateString'] = dateString;
      if (mealType != null && mealType.isNotEmpty) queryParams['mealType'] = mealType;
      if (status != null && status.isNotEmpty) queryParams['status'] = status;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final uri = Uri.parse('${AppConstants.apiBaseUrl}/food-photos/admin/monitoring').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      final res = await http.get(uri, headers: _getAuthHeaders()).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final data = decoded['data'] ?? {};
        final list = (data['photos'] as List? ?? [])
            .map((item) => FoodPhotoModel.fromJson(Map<String, dynamic>.from(item)))
            .toList();

        return {
          'photos': list,
          'summary': data['summary'] ?? {},
          'filterDate': data['filterDate'] ?? dateString ?? DateTime.now().toIso8601String().split('T')[0],
        };
      }
      throw Exception('Server returned ${res.statusCode}');
    } catch (e) {
      debugPrint('[FOOD PHOTO TRACKING] Admin fetch notice: $e');
      return {
        'photos': <FoodPhotoModel>[],
        'summary': {'total': 0, 'verifiedCount': 0, 'pendingCount': 0, 'needsAttentionCount': 0},
        'filterDate': dateString ?? DateTime.now().toIso8601String().split('T')[0],
      };
    }
  }

  /// Admin Verification: Updates status to VERIFIED or NEEDS_ATTENTION.
  Future<bool> adminVerifyFoodPhoto({
    required String photoId,
    required String status,
    String? adminNote,
  }) async {
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/food-photos/$photoId/verify');
      final res = await http.patch(
        url,
        headers: _getAuthHeaders(),
        body: jsonEncode({
          'status': status.toUpperCase(),
          'adminNote': adminNote?.trim(),
        }),
      ).timeout(const Duration(seconds: 10));

      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[FOOD PHOTO TRACKING] Admin verify notice: $e');
      return false;
    }
  }

  /// Automatically synchronizes pending offline photos when connection is restored.
  Future<int> syncPendingFoodPhotos() async {
    if (_isSyncing) return 0;
    _isSyncing = true;

    int syncedCount = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawQueue = prefs.getStringList(_storageKeyOfflinePhotos) ?? [];
      if (rawQueue.isEmpty) return 0;

      final remaining = <String>[];

      for (final itemStr in rawQueue) {
        try {
          final item = jsonDecode(itemStr) as Map<String, dynamic>;
          final photoJson = item['photo'] as Map<String, dynamic>;
          final imageBase64 = item['imageBase64'] as String;

          final url = Uri.parse('${AppConstants.apiBaseUrl}/food-photos/live');
          final res = await http.post(
            url,
            headers: _getAuthHeaders(),
            body: jsonEncode({
              'image': imageBase64,
              'mealType': photoJson['mealType'],
              'capturedAt': photoJson['capturedAt'],
              'timezone': photoJson['timezone'] ?? 'UTC',
              'clientNote': photoJson['clientNote'],
            }),
          ).timeout(const Duration(seconds: 12));

          if (res.statusCode == 200 || res.statusCode == 201) {
            syncedCount++;
          } else {
            remaining.add(itemStr);
          }
        } catch (_) {
          remaining.add(itemStr);
        }
      }

      await prefs.setStringList(_storageKeyOfflinePhotos, remaining);
    } catch (e) {
      debugPrint('[FOOD PHOTO TRACKING] Sync error: $e');
    } finally {
      _isSyncing = false;
    }
    return syncedCount;
  }

  // --- Local Storage & Cache Helpers ---

  Future<void> _savePhotoToOfflineQueue({
    required FoodPhotoModel photo,
    required String imageBase64,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawQueue = prefs.getStringList(_storageKeyOfflinePhotos) ?? [];
      final record = jsonEncode({
        'photo': photo.toJson(),
        'imageBase64': imageBase64,
        'queuedAt': DateTime.now().toIso8601String(),
      });
      rawQueue.add(record);
      await prefs.setStringList(_storageKeyOfflinePhotos, rawQueue);
    } catch (_) {}
  }

  Future<List<FoodPhotoModel>> _loadOfflineQueuePhotos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawQueue = prefs.getStringList(_storageKeyOfflinePhotos) ?? [];
      final list = <FoodPhotoModel>[];
      for (final s in rawQueue) {
        try {
          final item = jsonDecode(s) as Map<String, dynamic>;
          list.add(FoodPhotoModel.fromJson(item['photo']));
        } catch (_) {}
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<void> _cachePhotoLocally(FoodPhotoModel photo) async {
    try {
      final cached = await _loadCachedPhotos();
      final index = cached.indexWhere((p) => p.id == photo.id);
      if (index >= 0) {
        cached[index] = photo;
      } else {
        cached.insert(0, photo);
      }
      await _saveCachedPhotos(cached);
    } catch (_) {}
  }

  Future<void> _saveCachedPhotos(List<FoodPhotoModel> photos) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = photos.map((p) => jsonEncode(p.toJson())).toList();
      await prefs.setStringList(_storageKeyCachedPhotos, jsonList);
    } catch (_) {}
  }

  Future<List<FoodPhotoModel>> _loadCachedPhotos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_storageKeyCachedPhotos) ?? [];
      return list
          .map((s) => FoodPhotoModel.fromJson(jsonDecode(s) as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
