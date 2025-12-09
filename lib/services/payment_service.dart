import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'token_auth_service.dart';

/// Payment method types
enum PaymentMethod {
  ancientFlipPay, // AncientFlip Pay (in-app credits)
  googlePlay, // Google Play In-App Purchase
  appStore, // App Store In-App Purchase
  paystack, // Paystack (Ghana, Nigeria, South Africa, Kenya)
}

/// Payment Service
/// Handles all payment methods and backend API integration
class PaymentService {
  static const String baseUrl = 'https://flip-backend-mnpg.onrender.com/api';

  // ============================================================================
  // BACKEND API CALLS - Payment Method Management
  // ============================================================================

  /// Set preferred payment method for user
  static Future<Map<String, dynamic>> setPreferredPaymentMethod({
    required String method,
  }) async {
    try {
      final token = await TokenAuthService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'No authentication token'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/payments/set-preferred-method'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'paymentMethod': method}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': data['success'] ?? true,
          'data': data['data'],
        };
      } else {
        final error = json.decode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Failed to set payment method',
        };
      }
    } catch (e) {
      print('❌ PaymentService.setPreferredPaymentMethod error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Get user's available payment methods
  static Future<List<String>> getAvailablePaymentMethods() async {
    try {
      final token = await TokenAuthService.getToken();
      if (token == null) {
        return [];
      }

      final response = await http.get(
        Uri.parse('$baseUrl/payments/available-methods'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final methods = data['data']['methods'] as List?;
        return methods?.cast<String>() ?? [];
      }
      return [];
    } catch (e) {
      print('❌ PaymentService.getAvailablePaymentMethods error: $e');
      return [];
    }
  }

  /// Get user's preferred payment method
  static Future<String?> getPreferredPaymentMethod() async {
    try {
      final token = await TokenAuthService.getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/payments/preferred-method'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data']['method'] as String?;
      }
      return null;
    } catch (e) {
      print('❌ PaymentService.getPreferredPaymentMethod error: $e');
      return null;
    }
  }

  // ============================================================================
  // PAYMENT PROCESSING - AncientFlip Pay (In-App Credits)
  // ============================================================================

  /// Process payment using AncientFlip Pay (existing coins/credits)
  static Future<Map<String, dynamic>> purchaseWithAncientFlipPay({
    required String packageId,
    required int amount,
    required String description,
  }) async {
    try {
      final token = await TokenAuthService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      print('💳 Processing AncientFlip Pay - Package: $packageId, Amount: $amount');

      final response = await http.post(
        Uri.parse('$baseUrl/payments/process-ancient-flip-pay'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'packageId': packageId,
          'amount': amount,
          'description': description,
          'paymentMethod': 'ancient_flip_pay',
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ AncientFlip Pay successful: ${data['data']}');
        return {
          'success': data['success'] ?? true,
          'transactionId': data['data']?['transactionId'],
          'message': 'Payment successful',
        };
      } else {
        final error = json.decode(response.body);
        print('❌ AncientFlip Pay failed: ${error['message']}');
        return {
          'success': false,
          'message': error['message'] ?? 'Payment failed',
        };
      }
    } catch (e) {
      print('❌ PaymentService.purchaseWithAncientFlipPay error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ============================================================================
  // PAYSTACK INTEGRATION
  // ============================================================================

  /// Initialize Paystack payment transaction
  static Future<Map<String, dynamic>> initializePaystackTransaction({
    required int amount,
    required String email,
    required String currency,
  }) async {
    try {
      final token = await TokenAuthService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      print('🔵 Initializing Paystack - Amount: $amount, Currency: $currency');

      final response = await http.post(
        Uri.parse('$baseUrl/payments/paystack/initialize'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'amount': amount,
          'email': email,
          'currency': currency,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Paystack initialized: ${data['data']}');
        return {
          'success': true,
          'reference': data['data']?['reference'],
          'authorizationUrl': data['data']?['authorization_url'],
          'accessCode': data['data']?['access_code'],
        };
      } else {
        final error = json.decode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Paystack initialization failed',
        };
      }
    } catch (e) {
      print('❌ PaymentService.initializePaystackTransaction error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Verify Paystack payment and complete transaction
  static Future<Map<String, dynamic>> verifyPaystackPayment({
    required String reference,
    required int coinAmount,
  }) async {
    try {
      final token = await TokenAuthService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      print('🔵 Verifying Paystack - Reference: $reference');

      final response = await http.post(
        Uri.parse('$baseUrl/payments/paystack/verify'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'reference': reference,
          'coinAmount': coinAmount,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Paystack verified: ${data['data']}');
        return {
          'success': true,
          'transactionId': data['data']?['transactionId'],
          'coinsAdded': data['data']?['coinsAdded'],
          'message': 'Payment verified and coins added',
        };
      } else {
        final error = json.decode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Payment verification failed',
        };
      }
    } catch (e) {
      print('❌ PaymentService.verifyPaystackPayment error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ============================================================================
  // GOOGLE PLAY & APP STORE IAP (Stubs for implementation)
  // ============================================================================

  /// Process Google Play In-App Purchase
  static Future<Map<String, dynamic>> processGooglePlayPurchase({
    required String productId,
    required String purchaseToken,
    required int coinAmount,
  }) async {
    try {
      final token = await TokenAuthService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      print('🟢 Processing Google Play - Product: $productId, Coins: $coinAmount');

      final response = await http.post(
        Uri.parse('$baseUrl/payments/google-play/verify'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'productId': productId,
          'purchaseToken': purchaseToken,
          'coinAmount': coinAmount,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Google Play verified: ${data['data']}');
        return {
          'success': true,
          'transactionId': data['data']?['transactionId'],
          'coinsAdded': data['data']?['coinsAdded'],
          'message': 'Purchase verified',
        };
      } else {
        final error = json.decode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Google Play verification failed',
        };
      }
    } catch (e) {
      print('❌ PaymentService.processGooglePlayPurchase error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Process App Store In-App Purchase
  static Future<Map<String, dynamic>> processAppStorePurchase({
    required String productId,
    required String receipt,
    required int coinAmount,
  }) async {
    try {
      final token = await TokenAuthService.getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      print('🍎 Processing App Store - Product: $productId, Coins: $coinAmount');

      final response = await http.post(
        Uri.parse('$baseUrl/payments/app-store/verify'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'productId': productId,
          'receipt': receipt,
          'coinAmount': coinAmount,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ App Store verified: ${data['data']}');
        return {
          'success': true,
          'transactionId': data['data']?['transactionId'],
          'coinsAdded': data['data']?['coinsAdded'],
          'message': 'Purchase verified',
        };
      } else {
        final error = json.decode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'App Store verification failed',
        };
      }
    } catch (e) {
      print('❌ PaymentService.processAppStorePurchase error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Get available payment methods based on platform and region
  static List<PaymentMethod> getAvailablePaymentMethodsByPlatform() {
    final methods = <PaymentMethod>[
      PaymentMethod.ancientFlipPay, // Always available
    ];

    if (Platform.isAndroid) {
      methods.add(PaymentMethod.googlePlay);
      methods.add(PaymentMethod.paystack);
    } else if (Platform.isIOS) {
      methods.add(PaymentMethod.appStore);
      methods.add(PaymentMethod.paystack);
    }

    return methods;
  }

  /// Get payment method display name
  static String getPaymentMethodName(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.ancientFlipPay:
        return 'AncientFlip Pay';
      case PaymentMethod.googlePlay:
        return 'Google Play';
      case PaymentMethod.appStore:
        return 'App Store';
      case PaymentMethod.paystack:
        return 'Paystack';
    }
  }

  /// Get payment method emoji
  static String getPaymentMethodEmoji(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.ancientFlipPay:
        return '💳';
      case PaymentMethod.googlePlay:
        return '🔵';
      case PaymentMethod.appStore:
        return '🍎';
      case PaymentMethod.paystack:
        return '🏦';
    }
  }
}

