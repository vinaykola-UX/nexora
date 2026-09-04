import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../features/authentication/data/auth_service.dart';
import '../models/notification_model.dart';

/// Provider for NotificationService
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final authService = ref.watch(authServiceProvider);
  return NotificationService(authService: authService);
});

/// Unread notification count provider (refreshes automatically)
final unreadNotificationCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final service = ref.watch(notificationServiceProvider);
  final counts = await service.fetchUnreadCount();
  return counts.unreadCount;
});

/// Notification list provider
final notificationListProvider = FutureProvider.autoDispose<List<NotificationModel>>((ref) async {
  final service = ref.watch(notificationServiceProvider);
  return await service.fetchNotifications();
});

class NotificationService {
  final AuthService _authService;
  final String _baseUrl;

  NotificationService({
    required AuthService authService,
    String baseUrl = AppConstants.workerBaseUrl,
  })  : _authService = authService,
        _baseUrl = baseUrl;

  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _authService.getIdToken();
    return {
      'Content-Type': 'application/json',
      'User-Agent': 'Nexora-Flutter-App/1.0',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Registers an FCM device token with the backend
  Future<bool> registerDeviceToken({
    required String fcmToken,
    String platform = 'android',
    String? deviceName,
    String? appVersion,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      final url = Uri.parse('$_baseUrl/student/devices/register');
      final res = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          'fcm_token': fcmToken,
          'platform': platform,
          'device_name': deviceName,
          'app_version': appVersion,
        }),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Unregisters an FCM device token
  Future<bool> unregisterDeviceToken(String fcmToken) async {
    try {
      final headers = await _getAuthHeaders();
      final url = Uri.parse('$_baseUrl/student/devices/unregister');
      final res = await http.post(
        url,
        headers: headers,
        body: jsonEncode({'fcm_token': fcmToken}),
      ).timeout(const Duration(seconds: 10));

      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Fetches in-app notifications for the authenticated student
  Future<List<NotificationModel>> fetchNotifications({
    int limit = 50,
    int offset = 0,
    bool unreadOnly = false,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      final url = Uri.parse('$_baseUrl/student/notifications?limit=$limit&offset=$offset&unread=$unreadOnly');
      final res = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['notifications'] is List) {
          return (data['notifications'] as List)
              .map((item) => NotificationModel.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Marks a specific notification as read
  Future<bool> markAsRead(int notificationId) async {
    try {
      final headers = await _getAuthHeaders();
      final url = Uri.parse('$_baseUrl/student/notifications/$notificationId/read');
      final res = await http.post(url, headers: headers).timeout(const Duration(seconds: 8));

      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Marks all notifications as read
  Future<bool> markAllAsRead() async {
    try {
      final headers = await _getAuthHeaders();
      final url = Uri.parse('$_baseUrl/student/notifications/read-all');
      final res = await http.post(url, headers: headers).timeout(const Duration(seconds: 8));

      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Gets unread notification count
  Future<NotificationCountModel> fetchUnreadCount() async {
    try {
      final headers = await _getAuthHeaders();
      final url = Uri.parse('$_baseUrl/student/notification-count');
      final res = await http.get(url, headers: headers).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return NotificationCountModel.fromJson(data);
      }
      return NotificationCountModel(unreadCount: 0, totalCount: 0);
    } catch (_) {
      return NotificationCountModel(unreadCount: 0, totalCount: 0);
    }
  }
}
