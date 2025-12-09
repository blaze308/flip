import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_auth_service.dart';

/// Settings Service
/// Handles all settings-related API calls
class SettingsService {
  static const String baseUrl = 'https://flip-backend-mnpg.onrender.com/api';

  /// Get authentication headers
  static Future<Map<String, String>?> _getHeaders() async {
    final token = await TokenAuthService.getToken();
    if (token == null) {
      print('❌ SettingsService: No auth token');
      return null;
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Update notification preferences
  static Future<Map<String, dynamic>> updateNotifications({
    bool? email,
    bool? push,
    bool? sms,
  }) async {
    try {
      final headers = await _getHeaders();
      if (headers == null) {
        return {
          'success': false,
          'message': 'No authentication token',
        };
      }

      final Map<String, dynamic> body = {};
      if (email != null) body['email'] = email;
      if (push != null) body['push'] = push;
      if (sms != null) body['sms'] = sms;

      final response = await http.put(
        Uri.parse('$baseUrl/users/notifications'),
        headers: headers,
        body: json.encode(body),
      );

      print('📱 SettingsService.updateNotifications: ${response.statusCode}');

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? 'Notifications updated successfully',
          'notifications': data['data']?['notifications'],
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Failed to update notifications',
      };
    } catch (e) {
      print('❌ SettingsService.updateNotifications error: $e');
      return {
        'success': false,
        'message': 'An error occurred: $e',
      };
    }
  }

  /// Update privacy settings
  static Future<Map<String, dynamic>> updatePrivacy({
    bool? profileVisible,
    bool? showEmail,
    bool? showPhone,
  }) async {
    try {
      final headers = await _getHeaders();
      if (headers == null) {
        return {
          'success': false,
          'message': 'No authentication token',
        };
      }

      final Map<String, dynamic> body = {
        'profile': {
          'preferences': {
            'privacy': {},
          },
        },
      };

      if (profileVisible != null) {
        body['profile']['preferences']['privacy']['profileVisible'] = profileVisible;
      }
      if (showEmail != null) {
        body['profile']['preferences']['privacy']['showEmail'] = showEmail;
      }
      if (showPhone != null) {
        body['profile']['preferences']['privacy']['showPhone'] = showPhone;
      }

      final response = await http.put(
        Uri.parse('$baseUrl/users/profile'),
        headers: headers,
        body: json.encode(body),
      );

      print('📱 SettingsService.updatePrivacy: ${response.statusCode}');

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? 'Privacy settings updated successfully',
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Failed to update privacy settings',
      };
    } catch (e) {
      print('❌ SettingsService.updatePrivacy error: $e');
      return {
        'success': false,
        'message': 'An error occurred: $e',
      };
    }
  }

  /// Update language preference
  static Future<Map<String, dynamic>> updateLanguage(String language) async {
    try {
      final headers = await _getHeaders();
      if (headers == null) {
        return {
          'success': false,
          'message': 'No authentication token',
        };
      }

      final response = await http.put(
        Uri.parse('$baseUrl/users/profile'),
        headers: headers,
        body: json.encode({
          'profile': {
            'preferences': {
              'language': language,
            },
          },
        }),
      );

      print('📱 SettingsService.updateLanguage: ${response.statusCode}');

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? 'Language updated successfully',
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Failed to update language',
      };
    } catch (e) {
      print('❌ SettingsService.updateLanguage error: $e');
      return {
        'success': false,
        'message': 'An error occurred: $e',
      };
    }
  }

  /// Delete account
  static Future<Map<String, dynamic>> deleteAccount() async {
    try {
      final headers = await _getHeaders();
      if (headers == null) {
        return {
          'success': false,
          'message': 'No authentication token',
        };
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/users/account'),
        headers: headers,
      );

      print('📱 SettingsService.deleteAccount: ${response.statusCode}');

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? 'Account deleted successfully',
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Failed to delete account',
      };
    } catch (e) {
      print('❌ SettingsService.deleteAccount error: $e');
      return {
        'success': false,
        'message': 'An error occurred: $e',
      };
    }
  }

  /// Get active sessions
  static Future<List<Map<String, dynamic>>> getSessions() async {
    try {
      final headers = await _getHeaders();
      if (headers == null) {
        print('❌ SettingsService: No auth token');
        return [];
      }

      final response = await http.get(
        Uri.parse('$baseUrl/users/sessions'),
        headers: headers,
      );

      print('📱 SettingsService.getSessions: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> sessions = data['data']['sessions'] ?? [];
          return sessions.map((s) => Map<String, dynamic>.from(s)).toList();
        }
      }

      return [];
    } catch (e) {
      print('❌ SettingsService.getSessions error: $e');
      return [];
    }
  }

  /// Delete a session
  static Future<Map<String, dynamic>> deleteSession(String sessionId) async {
    try {
      final headers = await _getHeaders();
      if (headers == null) {
        return {
          'success': false,
          'message': 'No authentication token',
        };
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/users/sessions/$sessionId'),
        headers: headers,
      );

      print('📱 SettingsService.deleteSession: ${response.statusCode}');

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? 'Session deleted successfully',
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Failed to delete session',
      };
    } catch (e) {
      print('❌ SettingsService.deleteSession error: $e');
      return {
        'success': false,
        'message': 'An error occurred: $e',
      };
    }
  }

  /// Submit feedback
  static Future<Map<String, dynamic>> submitFeedback({
    required String type,
    required String message,
    String? category,
  }) async {
    try {
      final headers = await _getHeaders();
      if (headers == null) {
        return {
          'success': false,
          'message': 'No authentication token',
        };
      }

      // TODO: Implement feedback API endpoint on backend
      // For now, return success
      return {
        'success': true,
        'message': 'Feedback submitted successfully',
      };
    } catch (e) {
      print('❌ SettingsService.submitFeedback error: $e');
      return {
        'success': false,
        'message': 'An error occurred: $e',
      };
    }
  }

  /// Report user or content
  static Future<Map<String, dynamic>> reportContent({
    required String type, // 'user', 'post', 'message', etc.
    required String targetId,
    required String reason,
    String? description,
  }) async {
    try {
      final headers = await _getHeaders();
      if (headers == null) {
        return {
          'success': false,
          'message': 'No authentication token',
        };
      }

      // TODO: Implement report API endpoint on backend
      // For now, return success
      return {
        'success': true,
        'message': 'Report submitted successfully',
      };
    } catch (e) {
      print('❌ SettingsService.reportContent error: $e');
      return {
        'success': false,
        'message': 'An error occurred: $e',
      };
    }
  }
}

