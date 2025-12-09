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
        body: json.encode({
          'tier': tier,
          'durationDays': durationDays,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, ...data};
      } else {
        final error = json.decode(response.body);
        return {'success': false, 'message': error['message'] ?? 'Failed to purchase VIP'};
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
        body: json.encode({
          'durationDays': durationDays,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, ...data};
      } else {
        final error = json.decode(response.body);
        return {'success': false, 'message': error['message'] ?? 'Failed to purchase MVP'};
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
        return {'success': false, 'message': error['message'] ?? 'Failed to purchase Guardian'};
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

  /// Calculate VIP price based on tier and duration
  static int calculateVIPPrice(String tier, int duration) {
    // Base prices per month
    const basePrices = {
      'normal': 500,
      'super': 1000,
      'diamond': 2000,
    };

    // Discount multipliers
    const discounts = {
      1: 1.0,
      3: 0.95, // 5% off
      6: 0.90, // 10% off
      12: 0.85, // 15% off
    };

    final basePrice = basePrices[tier] ?? 500;
    final discount = discounts[duration] ?? 1.0;

    return (basePrice * duration * discount).round();
  }

  /// Calculate MVP price based on duration
  static int calculateMVPPrice(int duration) {
    const basePrice = 3000; // per month

    // Discount multipliers
    const discounts = {
      1: 1.0,
      3: 0.95, // 5% off
      6: 0.90, // 10% off
      12: 0.85, // 15% off
    };

    final discount = discounts[duration] ?? 1.0;

    return (basePrice * duration * discount).round();
  }

  /// Calculate Guardian price based on type and duration
  static int calculateGuardianPrice(String guardianType, int duration) {
    // Base prices per month
    const basePrices = {
      'silver': 1000,
      'gold': 2000,
      'king': 5000,
    };

    // Discount multipliers
    const discounts = {
      1: 1.0,
      3: 0.95, // 5% off
      6: 0.90, // 10% off
      12: 0.85, // 15% off
    };

    final basePrice = basePrices[guardianType] ?? 1000;
    final discount = discounts[duration] ?? 1.0;

    return (basePrice * duration * discount).round();
  }
}

