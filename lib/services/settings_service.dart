import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_auth_service.dart';

/// Settings Service
/// Handles all settings-related API calls
class SettingsService {
  static const String baseUrl = 'https://flip-backend-mnpg.onrender.com/api';

  /// Get user preferences (currency, privacy, etc.)
  static Future<Map<String, dynamic>?> getPreferences() async {
    try {
      final headers = await _getHeaders();
      if (headers == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/users/profile'),
        headers: headers,
      );

      if (response.statusCode != 200) return null;
      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['success'] != true) return null;

      final user = (data['data'] as Map<String, dynamic>?)?['user'] as Map<String, dynamic>?;
      final profile = user?['profile'] as Map<String, dynamic>?;
      final prefs = profile?['preferences'] as Map<String, dynamic>?;
      return prefs;
    } catch (e) {
      print('❌ SettingsService.getPreferences error: $e');
      return null;
    }
  }

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

  /// Update currency preference
  static Future<Map<String, dynamic>> updateCurrency(String currency) async {
    try {
      final headers = await _getHeaders();
      if (headers == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.put(
        Uri.parse('$baseUrl/users/profile'),
        headers: headers,
        body: json.encode({
          'profile': {
            'preferences': {'currency': currency},
          },
        }),
      );

      final data = json.decode(response.body) as Map<String, dynamic>;
      return {
        'success': response.statusCode == 200 && data['success'] == true,
        'message': data['message']?.toString() ?? 'Currency updated',
      };
    } catch (e) {
      print('❌ SettingsService.updateCurrency error: $e');
      return {'success': false, 'message': 'An error occurred: $e'};
    }
  }

  /// Update privacy settings
  static Future<Map<String, dynamic>> updatePrivacy({
    bool? profileVisible,
    bool? showEmail,
    bool? showPhone,
    String? messageWhoCan,
    String? callWhoCan,
    bool? invisibleMode,
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
      if (messageWhoCan != null) {
        body['profile']['preferences']['privacy']['messageWhoCan'] = messageWhoCan;
      }
      if (callWhoCan != null) {
        body['profile']['preferences']['privacy']['callWhoCan'] = callWhoCan;
      }
      if (invisibleMode != null) {
        body['profile']['preferences']['privacy']['invisibleMode'] = invisibleMode;
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

  /// Get my feedback submissions
  static Future<Map<String, dynamic>> getMyFeedback({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final headers = await _getHeaders();
      if (headers == null) {
        return {'success': false, 'feedback': [], 'pagination': null};
      }

      final uri = Uri.parse('$baseUrl/support/feedback').replace(
        queryParameters: {'page': page.toString(), 'limit': limit.toString()},
      );
      final response = await http.get(uri, headers: headers).timeout(
        const Duration(seconds: 15),
      );

      final data = json.decode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['success'] == true) {
        final d = data['data'] as Map<String, dynamic>? ?? {};
        return {
          'success': true,
          'feedback': d['feedback'] as List<dynamic>? ?? [],
          'pagination': d['pagination'] as Map<String, dynamic>?,
        };
      }
      return {'success': false, 'feedback': [], 'pagination': null};
    } catch (e) {
      print('❌ SettingsService.getMyFeedback error: $e');
      return {'success': false, 'feedback': [], 'pagination': null};
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
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/support/feedback'),
        headers: headers,
        body: json.encode({
          'subject': category ?? type,
          'message': message,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(response.body) as Map<String, dynamic>;
      return {
        'success': response.statusCode == 200 && data['success'] == true,
        'message': data['message']?.toString() ?? 'Feedback submitted successfully',
      };
    } catch (e) {
      print('❌ SettingsService.submitFeedback error: $e');
      return {'success': false, 'message': 'An error occurred: $e'};
    }
  }

  /// Submit contact form (works with or without auth)
  static Future<Map<String, dynamic>> submitContact({
    required String subject,
    required String message,
    String? email,
  }) async {
    try {
      final headers = <String, String>{'Content-Type': 'application/json'};
      final token = await TokenAuthService.getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final body = <String, dynamic>{'subject': subject, 'message': message};
      if (email != null && email.isNotEmpty) body['email'] = email;

      final response = await http.post(
        Uri.parse('$baseUrl/support/contact'),
        headers: headers,
        body: json.encode(body),
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(response.body) as Map<String, dynamic>;
      return {
        'success': response.statusCode == 200 && data['success'] == true,
        'message': data['message']?.toString() ?? 'Message sent successfully',
      };
    } catch (e) {
      print('❌ SettingsService.submitContact error: $e');
      return {'success': false, 'message': 'An error occurred: $e'};
    }
  }

  /// Report user or content
  static Future<Map<String, dynamic>> reportContent({
    required String type, // 'user', 'post', 'comment', 'story', 'chat'
    required String targetId,
    required String reason,
    String? description,
  }) async {
    try {
      final headers = await _getHeaders();
      if (headers == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/support/report'),
        headers: headers,
        body: json.encode({
          'targetType': type,
          'targetId': targetId,
          'reason': reason,
          'message': description ?? reason,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(response.body) as Map<String, dynamic>;
      return {
        'success': response.statusCode == 200 && data['success'] == true,
        'message': data['message']?.toString() ?? 'Report submitted successfully',
      };
    } catch (e) {
      print('❌ SettingsService.reportContent error: $e');
      return {'success': false, 'message': 'An error occurred: $e'};
    }
  }
}

