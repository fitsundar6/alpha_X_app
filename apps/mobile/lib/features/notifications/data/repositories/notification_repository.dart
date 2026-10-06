import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../../core/auth/auth_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/models/app_notification.dart';

class NotificationRepository extends ChangeNotifier {
  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _error;
  NotificationPreferences _preferences = const NotificationPreferences();

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get error => _error;
  NotificationPreferences get preferences => _preferences;

  String get _baseUrl => AppConstants.currentBaseUrl;

  Map<String, String> get _headers {
    final token = AuthService().token;
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Pings server to log app activity timestamp (for inactivity calculation)
  Future<void> sendActivityPing() async {
    try {
      final url = Uri.parse('$_baseUrl/client/me/activity-ping');
      await http.post(url, headers: _headers);
    } catch (_) {
      // Non-blocking background heartbeat
    }
  }

  /// Fetches latest notifications for client
  Future<void> fetchNotifications({bool silent = false}) async {
    // Admin users do not have a client profile or athlete notification feed
    if (AuthService().isAdmin) {
      _notifications = [];
      _unreadCount = 0;
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      }
      return;
    }

    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final url = Uri.parse('$_baseUrl/client/me/notifications');
      final res = await http.get(url, headers: _headers);

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final data = body['data'] ?? body;
        final list = (data['notifications'] as List?) ?? [];
        _notifications = list.map((item) => AppNotification.fromJson(item as Map<String, dynamic>)).toList();
        _unreadCount = (data['unreadCount'] as num?)?.toInt() ?? _notifications.where((n) => !n.isRead).length;
      } else {
        _error = 'Failed to load notifications (${res.statusCode})';
      }
    } catch (e) {
      _error = 'Network error fetching notifications: $e';
    } finally {
      if (!silent) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  /// Mark single notification as read
  Future<void> markAsRead(String id) async {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1 && !_notifications[idx].isRead) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true, readAt: DateTime.now());
      _unreadCount = (_unreadCount - 1).clamp(0, 999);
      notifyListeners();
    }

    try {
      final url = Uri.parse('$_baseUrl/client/me/notifications/$id/read');
      await http.put(url, headers: _headers);
    } catch (_) {
      // Optimistic update retained
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    _notifications = _notifications.map((n) => n.copyWith(isRead: true, readAt: DateTime.now())).toList();
    _unreadCount = 0;
    notifyListeners();

    try {
      final url = Uri.parse('$_baseUrl/client/me/notifications/read-all');
      await http.put(url, headers: _headers);
    } catch (_) {}
  }

  /// Fetch notification preferences
  Future<void> fetchPreferences() async {
    try {
      final url = Uri.parse('$_baseUrl/client/me/notification-preferences');
      final res = await http.get(url, headers: _headers);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final data = body['data'] ?? body;
        _preferences = NotificationPreferences.fromJson(data);
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Update notification preferences
  Future<bool> updatePreferences(NotificationPreferences prefs) async {
    _preferences = prefs;
    notifyListeners();

    try {
      final url = Uri.parse('$_baseUrl/client/me/notification-preferences');
      final res = await http.put(url, headers: _headers, body: jsonEncode(prefs.toJson()));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
