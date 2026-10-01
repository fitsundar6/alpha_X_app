import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:alpha_x_gym/core/constants/app_constants.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/features/progress/domain/models/weekly_check_in.dart';
import 'package:alpha_x_gym/features/progress/domain/models/weekly_check_in_status.dart';

class WeeklyProgressRepository extends ChangeNotifier {
  final http.Client _httpClient;

  WeeklyCheckInStatus? _currentStatus;
  List<WeeklyCheckIn> _clientHistory = [];
  bool _isLoading = false;
  String? _errorMessage;

  WeeklyCheckInStatus? get currentStatus => _currentStatus;
  List<WeeklyCheckIn> get clientHistory => List.unmodifiable(_clientHistory);
  WeeklyCheckIn? get latestCheckIn => _clientHistory.isNotEmpty ? _clientHistory.first : null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  WeeklyProgressRepository({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  Map<String, String> _buildHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final token = AuthService().token;
    if (token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// 1. Fetch weekly check-in availability status for current authenticated client
  Future<WeeklyCheckInStatus> fetchCheckInStatus({bool forceRefresh = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/client/me/weekly-check-ins/status');
      final res = await _httpClient.get(url, headers: _buildHeaders()).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final data = decoded['data'] ?? decoded;
        _currentStatus = WeeklyCheckInStatus.fromJson(data as Map<String, dynamic>);
        _isLoading = false;
        notifyListeners();
        return _currentStatus!;
      } else {
        final decoded = jsonDecode(res.body);
        _errorMessage = decoded['message'] ?? 'Failed to load check-in status (${res.statusCode})';
      }
    } catch (e) {
      debugPrint('[WeeklyProgressRepository] fetchCheckInStatus error: $e');
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
    return _currentStatus ?? WeeklyCheckInStatus.initial();
  }

  /// 2. Fetch all historical weekly check-ins for current authenticated client
  Future<List<WeeklyCheckIn>> fetchClientHistory() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/client/me/weekly-check-ins');
      final res = await _httpClient.get(url, headers: _buildHeaders()).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final list = (decoded['data'] ?? decoded) as List<dynamic>? ?? [];
        _clientHistory = list
            .map((item) => WeeklyCheckIn.fromJson(item as Map<String, dynamic>))
            .toList();
        _isLoading = false;
        notifyListeners();
        return _clientHistory;
      } else {
        final decoded = jsonDecode(res.body);
        _errorMessage = decoded['message'] ?? 'Failed to load weekly check-ins';
      }
    } catch (e) {
      debugPrint('[WeeklyProgressRepository] fetchClientHistory error: $e');
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
    return _clientHistory;
  }

  /// 3. Submit a new Weekly Check-In (Enforces 1-per-week lock on backend)
  Future<WeeklyCheckIn> submitWeeklyCheckIn(Map<String, dynamic> payload) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/client/me/weekly-check-ins');
      final res = await _httpClient
          .post(url, headers: _buildHeaders(), body: jsonEncode(payload))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 201 || res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final checkInJson = (decoded['data'] ?? decoded) as Map<String, dynamic>;
        final newCheckIn = WeeklyCheckIn.fromJson(checkInJson);

        // Update local status & history
        _clientHistory.insert(0, newCheckIn);
        _currentStatus = WeeklyCheckInStatus(
          isAvailable: false,
          currentWeekNumber: newCheckIn.weekNumber + 1,
          lastCheckIn: newCheckIn,
          nextCheckInDate: newCheckIn.nextCheckInDate,
          daysUntilNext: 7,
          statusText: 'Weekly Check-In Completed ✓ (Next Check-In: ${newCheckIn.nextCheckInDate.toIso8601String().substring(0, 10)})',
        );

        _isLoading = false;
        notifyListeners();
        return newCheckIn;
      } else {
        final decoded = jsonDecode(res.body);
        final msg = decoded['message'] ?? 'Failed to submit check-in (${res.statusCode})';
        _errorMessage = msg;
        _isLoading = false;
        notifyListeners();
        throw Exception(msg);
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// 4. Admin: Fetch a client's weekly progress history & analytics
  Future<Map<String, dynamic>> fetchAdminClientWeeklyProgress(String clientId) async {
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/admin/clients/$clientId/weekly-check-ins');
      final res = await _httpClient.get(url, headers: _buildHeaders()).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final data = (decoded['data'] ?? decoded) as Map<String, dynamic>;

        final rawHistory = data['history'] as List<dynamic>? ?? [];
        final history = rawHistory
            .map((item) => WeeklyCheckIn.fromJson(item as Map<String, dynamic>))
            .toList();

        final rawLatest = data['latestCheckIn'] as Map<String, dynamic>?;
        final latest = rawLatest != null ? WeeklyCheckIn.fromJson(rawLatest) : null;

        return {
          'client': data['client'],
          'history': history,
          'latestCheckIn': latest,
          'weightTrajectory': data['weightTrajectory'] as List<dynamic>? ?? [],
          'waistTrajectory': data['waistTrajectory'] as List<dynamic>? ?? [],
          'analytics': data['analytics'] ?? {},
        };
      } else {
        final decoded = jsonDecode(res.body);
        throw Exception(decoded['message'] ?? 'Failed to load client weekly progress (${res.statusCode})');
      }
    } catch (e) {
      debugPrint('[WeeklyProgressRepository] fetchAdminClientWeeklyProgress error: $e');
      rethrow;
    }
  }

  /// 5. Admin: Compare two weeks side-by-side
  Future<Map<String, dynamic>> compareWeeklyCheckIns(String clientId, int weekA, int weekB) async {
    try {
      final url = Uri.parse(
          '${AppConstants.apiBaseUrl}/admin/clients/$clientId/weekly-check-ins-compare?weekA=$weekA&weekB=$weekB');
      final res = await _httpClient.get(url, headers: _buildHeaders()).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final data = (decoded['data'] ?? decoded) as Map<String, dynamic>;

        final rawA = data['weekA'] as Map<String, dynamic>?;
        final rawB = data['weekB'] as Map<String, dynamic>?;

        return {
          'weekA': rawA != null ? WeeklyCheckIn.fromJson(rawA) : null,
          'weekB': rawB != null ? WeeklyCheckIn.fromJson(rawB) : null,
          'deltas': data['deltas'] ?? {},
        };
      } else {
        final decoded = jsonDecode(res.body);
        throw Exception(decoded['message'] ?? 'Failed to compare weeks');
      }
    } catch (e) {
      debugPrint('[WeeklyProgressRepository] compareWeeklyCheckIns error: $e');
      rethrow;
    }
  }

  /// 6. Admin: Submit Coach Review for a weekly check-in
  Future<WeeklyCheckIn> submitCoachReview(
    String clientId,
    String checkInId,
    Map<String, dynamic> reviewData,
  ) async {
    try {
      final url = Uri.parse(
          '${AppConstants.apiBaseUrl}/admin/clients/$clientId/weekly-check-ins/$checkInId/coach-review');
      final res = await _httpClient
          .post(url, headers: _buildHeaders(), body: jsonEncode(reviewData))
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final checkInJson = (decoded['data'] ?? decoded) as Map<String, dynamic>;
        final updated = WeeklyCheckIn.fromJson(checkInJson);

        // Update in client history if present
        final idx = _clientHistory.indexWhere((c) => c.id == checkInId);
        if (idx != -1) {
          _clientHistory[idx] = updated;
          notifyListeners();
        }

        return updated;
      } else {
        final decoded = jsonDecode(res.body);
        throw Exception(decoded['message'] ?? 'Failed to submit coach review');
      }
    } catch (e) {
      debugPrint('[WeeklyProgressRepository] submitCoachReview error: $e');
      rethrow;
    }
  }
}
