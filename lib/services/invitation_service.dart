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
        return {
          'success': false,
          'message': 'No authentication token',
        };
      }

      // TODO: Implement backend endpoint
      // For now, return mock data
      return {
        'success': true,
        'data': {
          'referralCode': 'FLIP${DateTime.now().millisecondsSinceEpoch % 100000}',
          'totalInvites': 0,
          'totalRewards': 0,
        },
      };
    } catch (e) {
      print('❌ InvitationService.getReferralCode error: $e');
      return {
        'success': false,
        'message': 'An error occurred: $e',
      };
    }
  }

  /// Get invitation history
  static Future<List<Map<String, dynamic>>> getInvitationHistory() async {
    try {
      final headers = await _getHeaders();
      if (headers == null) {
        print('❌ InvitationService: No auth token');
        return [];
      }

      // TODO: Implement backend endpoint
      // For now, return empty list
      return [];
    } catch (e) {
      print('❌ InvitationService.getInvitationHistory error: $e');
      return [];
    }
  }

  /// Send invitation
  static Future<Map<String, dynamic>> sendInvitation({
    required String method, // 'sms', 'email', 'link'
    String? recipient,
  }) async {
    try {
      final headers = await _getHeaders();
      if (headers == null) {
        return {
          'success': false,
          'message': 'No authentication token',
        };
      }

      // TODO: Implement backend endpoint
      // For now, return success
      return {
        'success': true,
        'message': 'Invitation sent successfully',
      };
    } catch (e) {
      print('❌ InvitationService.sendInvitation error: $e');
      return {
        'success': false,
        'message': 'An error occurred: $e',
      };
    }
  }

  /// Claim referral reward
  static Future<Map<String, dynamic>> claimReferralReward(String invitationId) async {
    try {
      final headers = await _getHeaders();
      if (headers == null) {
        return {
          'success': false,
          'message': 'No authentication token',
        };
      }

      // TODO: Implement backend endpoint
      // For now, return success
      return {
        'success': true,
        'message': 'Reward claimed successfully',
        'reward': {
          'coins': 100,
          'diamonds': 10,
        },
      };
    } catch (e) {
      print('❌ InvitationService.claimReferralReward error: $e');
      return {
        'success': false,
        'message': 'An error occurred: $e',
      };
    }
  }
}

