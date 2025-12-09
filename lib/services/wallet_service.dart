import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/transaction_model.dart';
import '../models/coin_package_model.dart';
import 'token_auth_service.dart';

/// Wallet Service
/// Handles all wallet-related API calls
class WalletService {
  static const String baseUrl = 'https://flip-backend-mnpg.onrender.com/api';

  /// Get available coin packages
  static Future<List<CoinPackageModel>> getCoinPackages() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/wallet/packages'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      print('📱 WalletService.getCoinPackages: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final packages = data['data']['packages'] as List;
          return packages
              .map((p) => CoinPackageModel.fromJson(p as Map<String, dynamic>))
              .toList();
        }
      }

      print('❌ WalletService.getCoinPackages failed: ${response.body}');
      return [];
    } catch (e) {
      print('❌ WalletService.getCoinPackages error: $e');
      return [];
    }
  }

  /// Get current user's wallet balance
  static Future<Map<String, int>?> getBalance() async {
    try {
      final token = await TokenAuthService.getToken();
      if (token == null) {
        print('❌ WalletService: No auth token');
        return null;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/wallet/balance'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('📱 WalletService.getBalance: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final balance = data['data']['balance'] as Map<String, dynamic>;
          return {
            'coins': (balance['coins'] as num?)?.toInt() ?? 0,
            'diamonds': (balance['diamonds'] as num?)?.toInt() ?? 0,
            'points': (balance['points'] as num?)?.toInt() ?? 0,
          };
        }
      }

      print('❌ WalletService.getBalance failed: ${response.body}');
      return null;
    } catch (e) {
      print('❌ WalletService.getBalance error: $e');
      return null;
    }
  }

  /// Get transaction history
  static Future<List<TransactionModel>> getTransactions({
    String? type,
    String? currency,
    int limit = 50,
    int skip = 0,
  }) async {
    try {
      final token = await TokenAuthService.getToken();
      if (token == null) {
        print('❌ WalletService: No auth token');
        return [];
      }

      final queryParams = <String, String>{
        'limit': limit.toString(),
        'skip': skip.toString(),
      };
      if (type != null) queryParams['type'] = type;
      if (currency != null) queryParams['currency'] = currency;

      final uri = Uri.parse('$baseUrl/wallet/transactions')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('📱 WalletService.getTransactions: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final transactions = data['data']['transactions'] as List;
          return transactions
              .map((t) => TransactionModel.fromJson(t as Map<String, dynamic>))
              .toList();
        }
      }

      print('❌ WalletService.getTransactions failed: ${response.body}');
      return [];
    } catch (e) {
      print('❌ WalletService.getTransactions error: $e');
      return [];
    }
  }

  /// Get wallet summary
  static Future<Map<String, dynamic>?> getSummary() async {
    try {
      final token = await TokenAuthService.getToken();
      if (token == null) {
        print('❌ WalletService: No auth token');
        return null;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/wallet/summary'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('📱 WalletService.getSummary: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return data['data']['summary'] as Map<String, dynamic>;
        }
      }

      print('❌ WalletService.getSummary failed: ${response.body}');
      return null;
    } catch (e) {
      print('❌ WalletService.getSummary error: $e');
      return null;
    }
  }

  /// Purchase coins or diamonds
  static Future<Map<String, dynamic>?> purchaseCoins({
    required String currency,
    required int amount,
    required String paymentMethod,
    required String paymentToken,
  }) async {
    try {
      final token = await TokenAuthService.getToken();
      if (token == null) {
        print('❌ WalletService: No auth token');
        return null;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/wallet/purchase'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'currency': currency,
          'amount': amount,
          'paymentMethod': paymentMethod,
          'paymentToken': paymentToken,
        }),
      );

      print('📱 WalletService.purchaseCoins: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'] as Map<String, dynamic>;
        }
      }

      print('❌ WalletService.purchaseCoins failed: ${response.body}');
      return null;
    } catch (e) {
      print('❌ WalletService.purchaseCoins error: $e');
      return null;
    }
  }

  /// Transfer coins/diamonds to another user
  static Future<Map<String, dynamic>?> transferCoins({
    required String recipientId,
    required String currency,
    required int amount,
    String? message,
  }) async {
    try {
      final token = await TokenAuthService.getToken();
      if (token == null) {
        print('❌ WalletService: No auth token');
        return null;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/wallet/transfer'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'recipientId': recipientId,
          'currency': currency,
          'amount': amount,
          if (message != null) 'message': message,
        }),
      );

      print('📱 WalletService.transferCoins: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'] as Map<String, dynamic>;
        }
      }

      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ?? 'Transfer failed');
    } catch (e) {
      print('❌ WalletService.transferCoins error: $e');
      rethrow;
    }
  }

  /// Calculate coin package price (example packages)
  static Map<String, dynamic> getCoinPackage(int coins) {
    // Example pricing: $0.01 per coin with bulk discounts
    final packages = {
      100: {'price': 0.99, 'bonus': 0},
      500: {'price': 4.49, 'bonus': 50},
      1000: {'price': 8.49, 'bonus': 150},
      2500: {'price': 19.99, 'bonus': 500},
      5000: {'price': 37.99, 'bonus': 1200},
      10000: {'price': 69.99, 'bonus': 3000},
    };

    return packages[coins] ?? {'price': coins * 0.01, 'bonus': 0};
  }

  /// Calculate diamond package price
  static Map<String, dynamic> getDiamondPackage(int diamonds) {
    // Example pricing: $0.10 per diamond with bulk discounts
    final packages = {
      10: {'price': 0.99, 'bonus': 0},
      50: {'price': 4.49, 'bonus': 5},
      100: {'price': 8.49, 'bonus': 15},
      250: {'price': 19.99, 'bonus': 50},
      500: {'price': 37.99, 'bonus': 120},
      1000: {'price': 69.99, 'bonus': 300},
    };

    return packages[diamonds] ?? {'price': diamonds * 0.10, 'bonus': 0};
  }
}

