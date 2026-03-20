import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_auth_service.dart';

/// Notification Service
/// Handles notification center and alerts API calls
class NotificationService {
  static const String baseUrl = 'https://flip-backend-mnpg.onrender.com/api';

  /// Get authentication headers
  static Future<Map<String, String>?> _getHeaders() async {
    final token = await TokenAuthService.getToken();
    if (token == null) {
      print('❌ NotificationService: No auth token');
      return null;
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Get all notifications
  static Future<List<Map<String, dynamic>>> getNotifications({
    int page = 1,
    int limit = 20,
    bool unreadOnly = false,
  }) async {
    try {
      final headers = await _getHeaders();
      if (headers == null) return [];

      final uri = Uri.parse('$baseUrl/notifications').replace(
        queryParameters: {
          'page': page.toString(),
          'limit': limit.toString(),
          if (unreadOnly) 'unreadOnly': 'true',
        },
      );
      final response = await http.get(uri, headers: headers).timeout(
        const Duration(seconds: 15),
      );

      final data = json.decode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['success'] == true) {
        final list = (data['data'] as Map<String, dynamic>?)?['notifications'] as List<dynamic>?;
        return list?.cast<Map<String, dynamic>>() ?? [];
      }
      return [];
    } catch (e) {
      print('❌ NotificationService.getNotifications error: $e');
      return [];
    }
  }

  /// Mark notification as read
  static Future<Map<String, dynamic>> markAsRead(String notificationId) async {
    try {
      final headers = await _getHeaders();
      if (headers == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.put(
        Uri.parse('$baseUrl/notifications/$notificationId/read'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(response.body) as Map<String, dynamic>;
      return {
        'success': response.statusCode == 200 && data['success'] == true,
        'message': data['message']?.toString() ?? '',
      };
    } catch (e) {
      print('❌ NotificationService.markAsRead error: $e');
      return {'success': false, 'message': 'An error occurred: $e'};
    }
  }

  /// Mark all notifications as read
  static Future<Map<String, dynamic>> markAllAsRead() async {
    try {
      final headers = await _getHeaders();
      if (headers == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.put(
        Uri.parse('$baseUrl/notifications/read-all'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(response.body) as Map<String, dynamic>;
      return {
        'success': response.statusCode == 200 && data['success'] == true,
        'message': data['message']?.toString() ?? '',
      };
    } catch (e) {
      print('❌ NotificationService.markAllAsRead error: $e');
      return {'success': false, 'message': 'An error occurred: $e'};
    }
  }

  /// Delete notification
  static Future<Map<String, dynamic>> deleteNotification(String notificationId) async {
    try {
      final headers = await _getHeaders();
      if (headers == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/notifications/$notificationId'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(response.body) as Map<String, dynamic>;
      return {
        'success': response.statusCode == 200 && data['success'] == true,
        'message': data['message']?.toString() ?? '',
      };
    } catch (e) {
      print('❌ NotificationService.deleteNotification error: $e');
      return {'success': false, 'message': 'An error occurred: $e'};
    }
  }

  /// Get unread count
  static Future<int> getUnreadCount() async {
    try {
      final headers = await _getHeaders();
      if (headers == null) return 0;

      final response = await http.get(
        Uri.parse('$baseUrl/notifications/unread-count'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['success'] == true) {
        return (data['data'] as Map<String, dynamic>?)?['unreadCount'] as int? ?? 0;
      }
      return 0;
    } catch (e) {
      print('❌ NotificationService.getUnreadCount error: $e');
      return 0;
    }
  }
}

