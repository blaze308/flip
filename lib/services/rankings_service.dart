import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ranking_model.dart';
import 'token_auth_service.dart';

/// Rankings Service
/// Handles leaderboard rankings and rewards
class RankingsService {
  static const String baseUrl = 'https://flip-backend-mnpg.onrender.com/api';

  /// Get rankings
  static Future<Map<String, dynamic>?> getRankings({
    required RankingType type,
    required RankingPeriod period,
  }) async {
    try {
      final token = await TokenAuthService.getToken();
      if (token == null) throw Exception('Authentication token not found');

      final typeStr = type.name;
      final periodStr = period.name;

      final response = await http.get(
        Uri.parse('$baseUrl/rankings/$typeStr/$periodStr'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📱 RankingsService.getRankings: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final rankings = (data['data']['rankings'] as List)
              .map((r) => RankingModel.fromJson(r as Map<String, dynamic>))
              .toList();

          final userRanking = data['data']['userRanking'] != null
              ? UserRanking.fromJson(data['data']['userRanking'] as Map<String, dynamic>)
              : null;

          return {
            'rankings': rankings,
            'userRanking': userRanking,
            'period': data['data']['period'],
          };
        }
      }

      print('❌ RankingsService.getRankings failed: ${response.body}');
      return null;
    } catch (e) {
      print('❌ RankingsService.getRankings error: $e');
      return null;
    }
  }

  /// Claim ranking reward
  static Future<Map<String, dynamic>> claimRankingReward({
    required RankingType type,
    required RankingPeriod period,
    required String periodStart,
  }) async {
    try {
      final token = await TokenAuthService.getToken();
      if (token == null) throw Exception('Authentication token not found');

      final response = await http.post(
        Uri.parse('$baseUrl/rankings/claim'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'type': type.name,
          'period': period.name,
          'periodStart': periodStart,
        }),
      );

      print('📱 RankingsService.claimRankingReward: ${response.statusCode}');

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'rewardCoins': data['data']['rewardCoins'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to claim reward',
        };
      }
    } catch (e) {
      print('❌ RankingsService.claimRankingReward error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  /// Get ranking rules
  static Future<Map<String, dynamic>?> getRankingRules() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/rankings/rules'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      print('📱 RankingsService.getRankingRules: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return data['data'] as Map<String, dynamic>;
        }
      }

      print('❌ RankingsService.getRankingRules failed: ${response.body}');
      return null;
    } catch (e) {
      print('❌ RankingsService.getRankingRules error: $e');
      return null;
    }
  }
}

