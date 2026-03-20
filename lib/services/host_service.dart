import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_auth_service.dart';

/// Host Service
/// Handles host center and streaming analytics API calls
class HostService {
  static const String baseUrl = 'https://flip-backend-mnpg.onrender.com/api';

  /// Get authentication headers
  static Future<Map<String, String>?> _getHeaders() async {
    final token = await TokenAuthService.getToken();
    if (token == null) {
      print('❌ HostService: No auth token');
      return null;
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Get host dashboard stats
  static Future<Map<String, dynamic>?> getHostDashboard() async {
    try {
      final headers = await _getHeaders();
      if (headers == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/host/stats'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;
      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['success'] != true) return null;

      final d = (data['data'] as Map<String, dynamic>?) ?? {};
      return {
        'totalEarnings': d['totalEarnings'] ?? 0,
        'todayEarnings': d['currentMonthEarnings'] ?? 0,
        'totalStreams': d['totalStreams'] ?? 0,
        'totalViewers': d['totalViewersCount'] ?? 0,
        'totalDuration': 0,
        'averageViewers': d['avgViewers'] ?? 0,
        'hostLevel': d['hostLevel'] ?? 1,
        'nextLevelProgress': 0,
        'isHost': d['isHost'] ?? false,
        'giftsReceived': d['giftsReceived'] ?? 0,
        'liveLevel': d['liveLevel'] ?? 0,
      };
    } catch (e) {
      print('❌ HostService.getHostDashboard error: $e');
      return null;
    }
  }

  /// Get earnings report
  static Future<Map<String, dynamic>?> getEarningsReport({
    String period = 'month',
  }) async {
    try {
      final headers = await _getHeaders();
      if (headers == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/host/earnings').replace(
          queryParameters: {'period': period},
        ),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;
      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['success'] != true) return null;

      final d = (data['data'] as Map<String, dynamic>?) ?? {};
      return {
        'period': d['period'] ?? period,
        'totalEarnings': d['totalEarnings'] ?? 0,
        'breakdown': {
          'gifts': d['totalGifts'] ?? 0,
          'diamonds': d['totalEarnings'] ?? 0,
          'subscriptions': 0,
        },
        'history': d['earningsByDay'] ?? [],
        'topGifters': d['topGifters'] ?? [],
      };
    } catch (e) {
      print('❌ HostService.getEarningsReport error: $e');
      return null;
    }
  }

  /// Get live statistics
  static Future<Map<String, dynamic>?> getLiveStatistics(String streamId) async {
    try {
      final headers = await _getHeaders();
      if (headers == null) {
        print('❌ HostService: No auth token');
        return null;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/host/live/$streamId/stats'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;
      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['success'] != true) return null;

      final d = (data['data'] as Map<String, dynamic>?) ?? {};
      return {
        'currentViewers': d['currentViewers'] ?? 0,
        'peakViewers': d['peakViewers'] ?? 0,
        'totalViews': d['totalViews'] ?? 0,
        'duration': d['duration'] ?? 0,
        'giftsReceived': d['giftsReceived'] ?? 0,
        'newFollowers': d['newFollowers'] ?? 0,
      };
    } catch (e) {
      print('❌ HostService.getLiveStatistics error: $e');
      return null;
    }
  }

  /// Apply to be a host
  static Future<Map<String, dynamic>> applyForHost({
    required String reason,
    required String experience,
    String? socialMedia,
  }) async {
    try {
      final headers = await _getHeaders();
      if (headers == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/host/apply'),
        headers: headers,
        body: json.encode({
          'reason': reason,
          'experience': experience,
          if (socialMedia != null) 'socialMedia': socialMedia,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(response.body) as Map<String, dynamic>;
      return {
        'success': response.statusCode == 200 && data['success'] == true,
        'message': data['message']?.toString() ?? 'Application submitted successfully',
      };
    } catch (e) {
      print('❌ HostService.applyForHost error: $e');
      return {'success': false, 'message': 'An error occurred: $e'};
    }
  }

  /// Get host application status
  static Future<Map<String, dynamic>?> getHostApplicationStatus() async {
    try {
      final headers = await _getHeaders();
      if (headers == null) {
        print('❌ HostService: No auth token');
        return null;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/host/application-status'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;
      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['success'] != true) return null;

      final d = (data['data'] as Map<String, dynamic>?) ?? {};
      return {
        'isHost': d['isHost'] ?? false,
        'hostApprovedAt': d['hostApprovedAt'],
        'status': d['status'] ?? 'not_applied',
      };
    } catch (e) {
      print('❌ HostService.getHostApplicationStatus error: $e');
      return null;
    }
  }

  /// Get host rewards
  static Future<List<Map<String, dynamic>>> getHostRewards() async {
    try {
      final headers = await _getHeaders();
      if (headers == null) {
        print('❌ HostService: No auth token');
        return [];
      }

      final response = await http.get(
        Uri.parse('$baseUrl/host/rewards'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return [];
      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['success'] != true) return [];

      final d = (data['data'] as Map<String, dynamic>?) ?? {};
      return (d['rewards'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    } catch (e) {
      print('❌ HostService.getHostRewards error: $e');
      return [];
    }
  }
}

