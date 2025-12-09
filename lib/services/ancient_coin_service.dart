import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../widgets/custom_toaster.dart';
import 'token_auth_service.dart';

/// AncientCoin Payment Service
/// Handles AncientCoin wallet payments
class AncientCoinService {
  static const _storage = FlutterSecureStorage();
  
  static String get clientId => dotenv.env['ANCIENT_COIN_CLIENT_ID'] ?? '';
  static String get clientSecret => dotenv.env['ANCIENT_COIN_CLIENT_SECRET'] ?? '';
  static String get walletAddress => dotenv.env['ANCIENT_COIN_WALLET_ADDRESS'] ?? '';
  static const String redirectUri = 'https://ancientsflip.com/callback';
  
  static const String authorizeUrl = 'https://oauth.ancientscoin.com/api/v1/oauth/authorize';
  static const String tokenUrl = 'https://oauth.ancientscoin.com/api/v1/oauth/token';
  static const String cashableUrl = 'https://api.ancientscoin.com/api/v1/wallet/cashable';
  static const String payUrl = 'https://api.ancientscoin.com/api/v1/wallet/pay';
  static const String otpUrl = 'https://api.ancientscoin.com/api/v1/otp/';

  /// Get authorization URL for OAuth
  static String getAuthorizationUrl() {
    final queryParams = {
      'client_id': clientId,
      'redirect_uri': redirectUri,
    };
    
    final uri = Uri.https(
      'oauth.ancientscoin.com',
      '/api/v1/oauth/authorize',
      queryParams,
    );
    
    return uri.toString();
  }

  /// Exchange authorization code for access token
  static Future<bool> getAccessToken(String code, BuildContext context) async {
    try {
      final response = await http.post(
        Uri.parse(tokenUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'client_id': clientId,
          'client_secret': clientSecret,
          'code': code,
          'grant_type': 'authorization_code',
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final token = data['data']['token'];
        
        // Store token securely
        await _storage.write(key: 'ancient_coin_token', value: token);
        
        ToasterService.showSuccess(context, 'AncientCoin connected successfully!');
        return true;
      } else {
        print('❌ Failed to get token: ${response.body}');
        ToasterService.showError(context, 'Failed to connect AncientCoin');
        return false;
      }
    } catch (e) {
      print('❌ AncientCoinService.getAccessToken error: $e');
      ToasterService.showError(context, 'Error: $e');
      return false;
    }
  }

  /// Get stored access token
  static Future<String?> getStoredToken() async {
    return await _storage.read(key: 'ancient_coin_token');
  }

  /// Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    final token = await getStoredToken();
    return token != null && token.isNotEmpty;
  }

  /// Logout (invalidate token)
  static Future<void> logout(BuildContext context) async {
    await _storage.delete(key: 'ancient_coin_token');
    ToasterService.showSuccess(context, 'Logged out from AncientCoin');
  }

  /// Get cashable amount in user's wallet
  static Future<double?> getCashableAmount(String currency, BuildContext context) async {
    try {
      final token = await getStoredToken();
      if (token == null || token.isEmpty) {
        ToasterService.showError(context, 'Please connect AncientCoin first');
        return null;
      }

      final response = await http.get(
        Uri.parse('$cashableUrl?currency=$currency'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['data']['cashable'] as num).toDouble();
      } else {
        print('❌ Failed to get cashable amount: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ AncientCoinService.getCashableAmount error: $e');
      return null;
    }
  }

  /// Send OTP to email
  static Future<bool> sendOtp(String email, BuildContext context) async {
    try {
      final response = await http.post(
        Uri.parse(otpUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'recipient': email,
          'channel': 'email',
        }),
      );

      if (response.statusCode == 200) {
        ToasterService.showSuccess(context, 'OTP sent to $email');
        return true;
      } else {
        print('❌ Failed to send OTP: ${response.body}');
        ToasterService.showError(context, 'Failed to send OTP');
        return false;
      }
    } catch (e) {
      print('❌ AncientCoinService.sendOtp error: $e');
      ToasterService.showError(context, 'Error: $e');
      return false;
    }
  }

  /// Pay with AncientCoin wallet
  static Future<bool> payWithWallet({
    required double amount,
    required String otp,
    required String currency,
    required int coins,
    required BuildContext context,
  }) async {
    try {
      final token = await getStoredToken();
      if (token == null || token.isEmpty) {
        ToasterService.showError(context, 'Please connect AncientCoin first');
        return false;
      }

      final response = await http.post(
        Uri.parse(payUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'tokenName': 'ANC',
          'walletAddress': walletAddress,
          'amount': amount,
          'otp': otp,
          'currency': currency,
        }),
      );

      if (response.statusCode == 200) {
        // Payment successful, now credit coins
        final success = await _creditCoins(coins, context);
        if (success) {
          ToasterService.showSuccess(
            context,
            'Payment successful! $coins coins added to your account.',
          );
          return true;
        } else {
          ToasterService.showError(context, 'Payment successful but failed to credit coins');
          return false;
        }
      } else {
        final errorData = json.decode(response.body);
        final errorMessage = errorData['message'] ?? 'Payment failed';
        ToasterService.showError(context, errorMessage);
        return false;
      }
    } catch (e) {
      print('❌ AncientCoinService.payWithWallet error: $e');
      ToasterService.showError(context, 'Payment error: $e');
      return false;
    }
  }

  /// Credit coins to user's account after successful payment
  static Future<bool> _creditCoins(int coins, BuildContext context) async {
    try {
      final token = await TokenAuthService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.post(
        Uri.parse('https://flip-backend-mnpg.onrender.com/api/wallet/purchase'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'paymentMethod': 'ancientcoin',
          'coins': coins,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ AncientCoinService._creditCoins error: $e');
      return false;
    }
  }

  /// Map amount to coins (based on old app pricing)
  static int? amountToCoins(double amount) {
    final Map<double, int> mapping = {
      15.0: 8000,
      30.0: 16000,
      120.0: 64000,
      240.0: 128000,
      552.0: 320000,
      1056.0: 640000,
      1275.0: 800000,
    };
    return mapping[amount];
  }
}

