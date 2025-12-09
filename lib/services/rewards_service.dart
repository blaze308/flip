import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/daily_reward_model.dart';
import 'token_auth_service.dart';

/// Rewards Service
/// Handles daily rewards and reward history
class RewardsService {
  static const String baseUrl = 'https://flip-backend-mnpg.onrender.com/api';

  /// Get daily reward status
  static Future<DailyRewardStatus?> getDailyRewardStatus() async {
    try {
      final token = await TokenAuthService.getToken();
      if (token == null) throw Exception('Authentication token not found');

      final response = await http.get(
        Uri.parse('$baseUrl/rewards/daily/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📱 RewardsService.getDailyRewardStatus: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return DailyRewardStatus.fromJson(data['data']);
        }
      }

      print('❌ RewardsService.getDailyRewardStatus failed: ${response.body}');
      return null;
    } catch (e) {
      print('❌ RewardsService.getDailyRewardStatus error: $e');
      return null;
    }
  }

  /// Claim daily reward
  static Future<Map<String, dynamic>> claimDailyReward() async {
    try {
      final token = await TokenAuthService.getToken();
      if (token == null) throw Exception('Authentication token not found');

      final response = await http.post(
        Uri.parse('$baseUrl/rewards/daily/claim'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📱 RewardsService.claimDailyReward: ${response.statusCode}');

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'reward': data['data']['reward'],
          'nextDay': data['data']['nextDay'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to claim reward',
        };
      }
    } catch (e) {
      print('❌ RewardsService.claimDailyReward error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  /// Get reward history
  static Future<List<DailyRewardModel>> getRewardHistory({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final token = await TokenAuthService.getToken();
      if (token == null) throw Exception('Authentication token not found');

      final response = await http.get(
        Uri.parse('$baseUrl/rewards/history?page=$page&limit=$limit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📱 RewardsService.getRewardHistory: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final rewards = data['data']['rewards'] as List;
          return rewards
              .map((r) => DailyRewardModel.fromJson(r as Map<String, dynamic>))
              .toList();
        }
      }

      print('❌ RewardsService.getRewardHistory failed: ${response.body}');
      return [];
    } catch (e) {
      print('❌ RewardsService.getRewardHistory error: $e');
      return [];
    }
  }
}

