import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_auth_service.dart';

/// Service for handling gamification-related API calls
class GamificationService {
  static const String baseUrl = 'https://flip-backend-mnpg.onrender.com/api';

  /// Get current user's levels and progress
  static Future<Map<String, dynamic>> getLevels() async {
    try {
      final token = await TokenAuthService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/gamification/levels'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] as Map<String, dynamic>;
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to fetch levels');
      }
    } catch (e) {
      print('❌ GamificationService.getLevels error: $e');
      rethrow;
    }
  }

  /// Purchase VIP membership
  /// [tier] can be 'normal', 'super', or 'diamond'
  /// [durationDays] is in days (30, 90, 180, 365)
  static Future<Map<String, dynamic>> purchaseVip({
    required String tier,
    required int durationDays,
  }) async {
    try {
      final token = await TokenAuthService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/gamification/vip/purchase'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'tier': tier, 'durationDays': durationDays}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, ...data};
      } else {
        final error = json.decode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Failed to purchase VIP',
        };
      }
    } catch (e) {
      print('❌ GamificationService.purchaseVip error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Purchase MVP membership
  /// [durationDays] is in days (30, 90, 180, 365)
  static Future<Map<String, dynamic>> purchaseMvp({
    required int durationDays,
  }) async {
    try {
      final token = await TokenAuthService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/gamification/mvp/purchase'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'durationDays': durationDays}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, ...data};
      } else {
        final error = json.decode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Failed to purchase MVP',
        };
      }
    } catch (e) {
      print('❌ GamificationService.purchaseMvp error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Purchase Guardian status for another user
  /// [tier] can be 'silver', 'gold', or 'king'
  /// [guardedUserId] is the user to guard
  /// [durationDays] is in days (30, 90, 180, 365)
  static Future<Map<String, dynamic>> purchaseGuardian({
    required String tier,
    required String guardedUserId,
    required int durationDays,
  }) async {
    try {
      final token = await TokenAuthService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/gamification/guardian/purchase'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'tier': tier,
          'guardedUserId': guardedUserId,
          'durationDays': durationDays,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, ...data};
      } else {
        final error = json.decode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Failed to purchase Guardian',
        };
      }
    } catch (e) {
      print('❌ GamificationService.purchaseGuardian error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Get list of users the current user is guarding
  static Future<List<Map<String, dynamic>>> getMyGuardians() async {
    try {
      final token = await TokenAuthService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/gamification/guardian/my-guardians'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data']['guardians']);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to fetch guardians');
      }
    } catch (e) {
      print('❌ GamificationService.getMyGuardians error: $e');
      rethrow;
    }
  }

  /// Get list of users guarding the current user
  static Future<List<Map<String, dynamic>>> getGuardedBy() async {
    try {
      final token = await TokenAuthService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/gamification/guardian/guarded-by'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data']['guardians']);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to fetch guardians');
      }
    } catch (e) {
      print('❌ GamificationService.getGuardedBy error: $e');
      rethrow;
    }
  }

  /// Get user's subscription history
  static Future<List<Map<String, dynamic>>> getSubscriptions() async {
    try {
      final token = await TokenAuthService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/gamification/subscriptions'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data']['subscriptions']);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to fetch subscriptions');
      }
    } catch (e) {
      print('❌ GamificationService.getSubscriptions error: $e');
      rethrow;
    }
  }

  /// Calculate VIP price based on tier and duration
  static int calculateVIPPrice(String tier, int durationMonths) {
    // Base prices per month (Matches backend gamification.js)
    const basePrices = {'normal': 95000, 'super': 100000, 'diamond': 250000};

    final basePrice = basePrices[tier] ?? 95000;
    return (basePrice * durationMonths).round();
  }

  /// Calculate MVP price based on duration
  static int calculateMVPPrice(int durationDays) {
    // Matches pricingTable in backend gamification.js
    const pricingTable = {30: 7085, 90: 20000, 180: 38000, 365: 70000};

    return pricingTable[durationDays] ?? 7085;
  }

  /// Calculate Guardian price based on type and duration
  static int calculateGuardianPrice(String guardianType, int durationMonths) {
    // Base prices per month (Matches backend gamification.js)
    const basePrices = {'silver': 15000, 'gold': 30000, 'king': 150000};

    final basePrice = basePrices[guardianType] ?? 15000;
    return (basePrice * durationMonths).round();
  }
}
