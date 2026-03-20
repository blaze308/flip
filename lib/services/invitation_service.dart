import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_auth_service.dart';

/// Invitation Service
/// Handles referral and invitation system API calls
class InvitationService {
  static const String baseUrl = 'https://flip-backend-mnpg.onrender.com/api';

  /// Get authentication headers
  static Future<Map<String, String>?> _getHeaders() async {
    final token = await TokenAuthService.getToken();
    if (token == null) {
      print('❌ InvitationService: No auth token');
      return null;
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Get user's referral code
  static Future<Map<String, dynamic>> getReferralCode() async {
    try {
      final headers = await _getHeaders();
      if (headers == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/invitation/referral-code'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'data': data['data'] ?? {
            'referralCode': '',
            'totalInvites': 0,
            'totalRewards': {},
          },
        };
      }
      return {
        'success': false,
        'message': data['message']?.toString() ?? 'Failed to get referral code',
      };
    } catch (e) {
      print('❌ InvitationService.getReferralCode error: $e');
      return {'success': false, 'message': 'An error occurred: $e'};
    }
  }

  /// Get invitation history
  static Future<List<Map<String, dynamic>>> getInvitationHistory() async {
    try {
      final headers = await _getHeaders();
      if (headers == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/invitation/history'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['success'] == true) {
        final history = (data['data'] as Map<String, dynamic>?)?['history'] as List<dynamic>?;
        return history?.cast<Map<String, dynamic>>() ?? [];
      }
      return [];
    } catch (e) {
      print('❌ InvitationService.getInvitationHistory error: $e');
      return [];
    }
  }

  /// Send invitation
  static Future<Map<String, dynamic>> sendInvitation({
    required String method,
    String? recipient,
  }) async {
    try {
      final headers = await _getHeaders();
      if (headers == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/invitation/send'),
        headers: headers,
        body: json.encode({'method': method, 'recipient': recipient}),
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? 'Invitation sent successfully',
          'data': data['data'],
        };
      }
      return {
        'success': false,
        'message': data['message']?.toString() ?? 'Failed to send invitation',
      };
    } catch (e) {
      print('❌ InvitationService.sendInvitation error: $e');
      return {'success': false, 'message': 'An error occurred: $e'};
    }
  }

  /// Claim referral reward
  static Future<Map<String, dynamic>> claimReferralReward(String invitationId, {String? invitedUserId}) async {
    try {
      final headers = await _getHeaders();
      if (headers == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/invitation/claim-reward/$invitationId'),
        headers: headers,
        body: json.encode({'invitedUserId': invitedUserId}),
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? 'Reward claimed successfully',
          'reward': (data['data'] as Map<String, dynamic>?)?['reward'],
        };
      }
      return {
        'success': false,
        'message': data['message']?.toString() ?? 'Failed to claim reward',
      };
    } catch (e) {
      print('❌ InvitationService.claimReferralReward error: $e');
      return {'success': false, 'message': 'An error occurred: $e'};
    }
  }
}

