import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/gift_model.dart';
import 'token_auth_service.dart';

/// Gift Service
/// Handles all gift-related API calls
class GiftService {
  static const String baseUrl = 'https://flip-backend-mnpg.onrender.com/api';

  /// Get all available gifts
  static Future<List<GiftModel>> getAllGifts() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/gifts'),
        headers: {'Content-Type': 'application/json'},
      );

      print('📱 GiftService.getAllGifts: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final gifts = data['data']['gifts'] as List;
          return gifts
              .map((g) => GiftModel.fromJson(g as Map<String, dynamic>))
              .toList();
        }
      }

      print('❌ GiftService.getAllGifts failed: ${response.body}');
      return [];
    } catch (e) {
      print('❌ GiftService.getAllGifts error: $e');
      return [];
    }
  }

  /// Get gifts received by current user
  static Future<Map<String, dynamic>> getReceivedGifts({
    int limit = 50,
    int skip = 0,
    String? context,
  }) async {
    try {
      final token = await TokenAuthService.getToken();
      if (token == null) {
        print('❌ GiftService: No auth token');
        return {'gifts': [], 'totalValue': 0, 'total': 0};
      }

      final queryParams = <String, String>{
        'limit': limit.toString(),
        'skip': skip.toString(),
      };
      if (context != null) queryParams['context'] = context;

      final uri = Uri.parse(
        '$baseUrl/gifts/received',
      ).replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('📱 GiftService.getReceivedGifts: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return {
            'gifts': data['data']['gifts'] as List,
            'totalValue': data['data']['totalValue'] as int,
            'total': data['data']['pagination']['total'] as int,
            'hasMore': data['data']['pagination']['hasMore'] as bool,
          };
        }
      }

      print('❌ GiftService.getReceivedGifts failed: ${response.body}');
      return {'gifts': [], 'totalValue': 0, 'total': 0};
    } catch (e) {
      print('❌ GiftService.getReceivedGifts error: $e');
      return {'gifts': [], 'totalValue': 0, 'total': 0};
    }
  }

  /// Get gifts sent by current user
  static Future<Map<String, dynamic>> getSentGifts({
    int limit = 50,
    int skip = 0,
  }) async {
    try {
      final token = await TokenAuthService.getToken();
      if (token == null) {
        print('❌ GiftService: No auth token');
        return {'gifts': [], 'totalValue': 0, 'total': 0};
      }

      final queryParams = <String, String>{
        'limit': limit.toString(),
        'skip': skip.toString(),
      };

      final uri = Uri.parse(
        '$baseUrl/gifts/sent',
      ).replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('📱 GiftService.getSentGifts: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return {
            'gifts': data['data']['gifts'] as List,
            'totalValue': data['data']['totalValue'] as int,
            'total': data['data']['pagination']['total'] as int,
            'hasMore': data['data']['pagination']['hasMore'] as bool,
          };
        }
      }

      print('❌ GiftService.getSentGifts failed: ${response.body}');
      return {'gifts': [], 'totalValue': 0, 'total': 0};
    } catch (e) {
      print('❌ GiftService.getSentGifts error: $e');
      return {'gifts': [], 'totalValue': 0, 'total': 0};
    }
  }

  /// Get gift statistics for current user
  static Future<Map<String, dynamic>?> getGiftStats() async {
    try {
      final token = await TokenAuthService.getToken();
      if (token == null) {
        print('❌ GiftService: No auth token');
        return null;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/gifts/stats'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('📱 GiftService.getGiftStats: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return data['data'] as Map<String, dynamic>;
        }
      }

      print('❌ GiftService.getGiftStats failed: ${response.body}');
      return null;
    } catch (e) {
      print('❌ GiftService.getGiftStats error: $e');
      return null;
    }
  }

  /// Get gifts received by a specific user (public)
  static Future<Map<String, dynamic>> getUserReceivedGifts(
    String userId, {
    int limit = 20,
    int skip = 0,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'skip': skip.toString(),
      };

      final uri = Uri.parse(
        '$baseUrl/gifts/user/$userId/received',
      ).replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      print('📱 GiftService.getUserReceivedGifts: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return {
            'gifts': data['data']['gifts'] as List,
            'total': data['data']['pagination']['total'] as int,
            'hasMore': data['data']['pagination']['hasMore'] as bool,
          };
        }
      }

      print('❌ GiftService.getUserReceivedGifts failed: ${response.body}');
      return {'gifts': [], 'total': 0};
    } catch (e) {
      print('❌ GiftService.getUserReceivedGifts error: $e');
      return {'gifts': [], 'total': 0};
    }
  }

  /// Send a gift to another user
  static Future<Map<String, dynamic>> sendGift({
    required String giftId,
    required String receiverId,
    String context = 'live',
    String? contextId,
    String? message,
    int quantity = 1,
  }) async {
    try {
      final token = await TokenAuthService.getToken();
      if (token == null) {
        print('❌ GiftService: No auth token');
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/gifts/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'giftId': giftId,
          'receiverId': receiverId,
          'context': context,
          'contextId': contextId,
          'message': message,
          'quantity': quantity,
        }),
      );

      print('📱 GiftService.sendGift: ${response.statusCode}');

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'data': data['data']};
      } else if (response.statusCode == 400 &&
          data['message'] == 'Insufficient coins') {
        // Return insufficient balance info
        return {
          'success': false,
          'insufficientBalance': true,
          'required': data['data']['required'],
          'current': data['data']['current'],
          'shortfall': data['data']['shortfall'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to send gift',
        };
      }
    } catch (e) {
      print('❌ GiftService.sendGift error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Purchase coins and automatically send a gift
  /// This is used when user doesn't have enough coins
  static Future<Map<String, dynamic>> purchaseAndSendGift({
    required String paymentMethod,
    required String coinPackageId,
    required Map<String, dynamic> giftData,
  }) async {
    try {
      final token = await TokenAuthService.getToken();
      if (token == null) {
        print('❌ GiftService: No auth token');
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/payments/purchase-and-send-gift'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'paymentMethod': paymentMethod,
          'coinPackageId': coinPackageId,
          'giftData': giftData,
        }),
      );

      print('📱 GiftService.purchaseAndSendGift: ${response.statusCode}');

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to purchase and send gift',
        };
      }
    } catch (e) {
      print('❌ GiftService.purchaseAndSendGift error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }
}
