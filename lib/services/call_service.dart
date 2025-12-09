import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_auth_service.dart';

/// Service for managing calls via backend API
class CallService {
  static const String baseUrl = 'https://flip-backend-mnpg.onrender.com/api';

  /// Create a call and send invitations to participants
  static Future<Map<String, dynamic>?> createCall({
    required String chatId,
    required List<String> participants,
    required String type, // 'audio' or 'video'
  }) async {
    try {
      print('📞 CallService: Creating $type call for chat $chatId');

      final headers = await TokenAuthService.getAuthHeaders();
      if (headers == null) {
        throw Exception('Not authenticated');
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/calls/create'),
            headers: {...headers, 'Content-Type': 'application/json'},
            body: jsonEncode({
              'chatId': chatId,
              'participants': participants,
              'type': type,
            }),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Request timeout - check your connection');
            },
          );

      print('📞 CallService: Response status: ${response.statusCode}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📞 CallService: Call created successfully');
        return data['data'] as Map<String, dynamic>?;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to create call');
      }
    } catch (e) {
      print('📞 CallService: Error creating call: $e');
      rethrow;
    }
  }

  /// Join a call
  static Future<Map<String, dynamic>?> joinCall(String callId) async {
    try {
      print('📞 CallService: Joining call $callId');

      final headers = await TokenAuthService.getAuthHeaders();
      if (headers == null) {
        throw Exception('Not authenticated');
      }

      final response = await http
          .post(Uri.parse('$baseUrl/calls/$callId/join'), headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📞 CallService: Joined call successfully');
        return data['data'] as Map<String, dynamic>?;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to join call');
      }
    } catch (e) {
      print('📞 CallService: Error joining call: $e');
      rethrow;
    }
  }

  /// End a call
  static Future<void> endCall(String callId) async {
    try {
      print('📞 CallService: Ending call $callId');

      final headers = await TokenAuthService.getAuthHeaders();
      if (headers == null) {
        throw Exception('Not authenticated');
      }

      final response = await http
          .post(Uri.parse('$baseUrl/calls/$callId/end'), headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        print('📞 CallService: Call ended successfully');
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to end call');
      }
    } catch (e) {
      print('📞 CallService: Error ending call: $e');
      rethrow;
    }
  }

  /// Reject a call
  static Future<void> rejectCall(String callId) async {
    try {
      print('📞 CallService: Rejecting call $callId');

      final headers = await TokenAuthService.getAuthHeaders();
      if (headers == null) {
        throw Exception('Not authenticated');
      }

      final response = await http
          .post(Uri.parse('$baseUrl/calls/$callId/reject'), headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        print('📞 CallService: Call rejected successfully');
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to reject call');
      }
    } catch (e) {
      print('📞 CallService: Error rejecting call: $e');
      rethrow;
    }
  }

  /// Get active calls for the current user
  static Future<List<Map<String, dynamic>>> getActiveCalls() async {
    try {
      print('📞 CallService: Fetching active calls');

      final headers = await TokenAuthService.getAuthHeaders();
      if (headers == null) {
        throw Exception('Not authenticated');
      }

      final response = await http
          .get(Uri.parse('$baseUrl/calls/active'), headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final calls = data['data']['calls'] as List;
        print('📞 CallService: Found ${calls.length} active calls');
        return calls.cast<Map<String, dynamic>>();
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to get active calls');
      }
    } catch (e) {
      print('📞 CallService: Error getting active calls: $e');
      return [];
    }
  }
}
