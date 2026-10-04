import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alpha_x_gym/core/constants/app_constants.dart';
import 'package:alpha_x_gym/core/auth/auth_service.dart';
import 'package:alpha_x_gym/features/telemetry/domain/models/weekly_telemetry_report.dart';

class WeeklyTelemetryRepository extends ChangeNotifier {
  final http.Client _httpClient;
  static const String _storageKeyTelemetry = 'alpha_x_cached_weekly_telemetry';

  WeeklyTelemetryReport? _currentReport;
  bool _isLoading = false;
  String? _errorMessage;

  WeeklyTelemetryReport? get currentReport => _currentReport;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  WeeklyTelemetryRepository({http.Client? httpClient})
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

  /// Initialize and load cached telemetry
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString(_storageKeyTelemetry);
      if (cachedStr != null && cachedStr.isNotEmpty) {
        final decoded = jsonDecode(cachedStr);
        _currentReport = WeeklyTelemetryReport.fromJson(decoded as Map<String, dynamic>);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[WeeklyTelemetryRepository] Failed to read cached telemetry: $e');
    }
  }

  /// Fetch weekly telemetry report from backend
  Future<WeeklyTelemetryReport?> fetchWeeklyTelemetry({DateTime? date, bool forceRefresh = false}) async {
    if (!forceRefresh && _currentReport != null) {
      return _currentReport;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      String query = '';
      if (date != null) {
        final dateStr = date.toIso8601String().split('T').first;
        query = '?date=$dateStr';
      }

      final url = Uri.parse('${AppConstants.apiBaseUrl}/telemetry/client/weekly-report$query');
      final res = await _httpClient.get(url, headers: _buildHeaders()).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final data = decoded['data'] ?? decoded;
        _currentReport = WeeklyTelemetryReport.fromJson(data as Map<String, dynamic>);
        _isLoading = false;

        // Persist to local storage for instant offline loading
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_storageKeyTelemetry, jsonEncode(data));
        } catch (_) {}

        notifyListeners();
        return _currentReport;
      } else {
        _errorMessage = 'Failed to load telemetry (${res.statusCode})';
      }
    } catch (e) {
      debugPrint('[WeeklyTelemetryRepository] fetchWeeklyTelemetry error: $e');
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
    return _currentReport;
  }
}
