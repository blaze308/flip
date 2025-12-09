import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../widgets/custom_toaster.dart';
import 'token_auth_service.dart';

/// Paystack Payment Service
/// Handles Paystack payments for Ghana, Nigeria, South Africa, Kenya
class PaystackService {
  static String get secretKey => dotenv.env['PAYSTACK_SECRET_KEY'] ?? '';
  static String get publicKey => dotenv.env['PAYSTACK_PUBLIC_KEY'] ?? '';
  
  static const String initializeUrl = 'https://api.paystack.co/transaction/initialize';
  static const String verifyUrl = 'https://api.paystack.co/transaction/verify';

  /// Initialize a payment transaction
  /// Returns authorization URL and reference
  static Future<Map<String, dynamic>?> initializeTransaction({
    required String email,
    required int amount, // Amount in kobo/cents (multiply by 100)
    required String currency, // GHS, NGN, ZAR, KES
    required BuildContext context,
  }) async {
    if (secretKey.isEmpty) {
      ToasterService.showError(
        context,
        'Paystack not configured. Please contact support.',
      );
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse(initializeUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $secretKey',
        },
        body: json.encode({
          'email': email,
          'amount': amount.toString(), // Amount in smallest currency unit
          'currency': currency,
        }),
      );

      final jsonResponse = json.decode(response.body);

      if (response.statusCode == 200 && jsonResponse['status'] == true) {
        return {
          'success': true,
          'reference': jsonResponse['data']['reference'],
          'authorizationUrl': jsonResponse['data']['authorization_url'],
          'accessCode': jsonResponse['data']['access_code'],
        };
      } else {
        final message = jsonResponse['message'] ?? 'Payment initialization failed';
        ToasterService.showError(context, message);
        return {'success': false, 'message': message};
      }
    } catch (e) {
      print('❌ PaystackService.initializeTransaction error: $e');
      ToasterService.showError(context, 'Payment error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Verify a payment transaction
  /// Call this after user completes payment
  static Future<Map<String, dynamic>?> verifyTransaction({
    required String reference,
    required BuildContext context,
  }) async {
    if (secretKey.isEmpty) {
      ToasterService.showError(
        context,
        'Paystack not configured. Please contact support.',
      );
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse('$verifyUrl/$reference'),
        headers: {
          'Authorization': 'Bearer $secretKey',
        },
      );

      final jsonResponse = json.decode(response.body);

      if (response.statusCode == 200 && jsonResponse['data']['status'] == 'success') {
        final amount = jsonResponse['data']['amount']; // Amount in kobo/cents
        final currency = jsonResponse['data']['currency'];
        
        return {
          'success': true,
          'reference': reference,
          'amount': amount,
          'currency': currency,
          'paidAt': jsonResponse['data']['paid_at'],
        };
      } else {
        final message = jsonResponse['data']['gateway_response'] ?? 'Payment verification failed';
        ToasterService.showError(context, message);
        return {'success': false, 'message': message};
      }
    } catch (e) {
      print('❌ PaystackService.verifyTransaction error: $e');
      ToasterService.showError(context, 'Verification error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Complete coin purchase after successful payment
  /// This credits coins to the user's account
  static Future<bool> completeCoinPurchase({
    required String reference,
    required int coins,
    required BuildContext context,
  }) async {
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
          'paymentMethod': 'paystack',
          'paymentReference': reference,
          'coins': coins,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          ToasterService.showSuccess(
            context,
            'Payment successful! $coins coins added to your account.',
          );
          return true;
        }
      }

      ToasterService.showError(context, 'Failed to credit coins');
      return false;
    } catch (e) {
      print('❌ PaystackService.completeCoinPurchase error: $e');
      ToasterService.showError(context, 'Error: $e');
      return false;
    }
  }

  /// Get exchange rate for currency conversion
  static Future<double> getExchangeRate(String fromCurrency, String toCurrency) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.exchangerate-api.com/v4/latest/$fromCurrency'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['rates'].containsKey(toCurrency)) {
          return (data['rates'][toCurrency] as num).toDouble();
        }
      }
      return 1.0; // Fallback
    } catch (e) {
      print('❌ PaystackService.getExchangeRate error: $e');
      return 1.0; // Fallback
    }
  }

  /// Convert amount from GHS to user's currency
  static Future<double> convertAmount(double ghsAmount, String userCurrency) async {
    if (userCurrency == 'GHS') return ghsAmount;
    final rate = await getExchangeRate('GHS', userCurrency);
    return ghsAmount * rate;
  }
}

