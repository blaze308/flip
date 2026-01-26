import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../widgets/custom_toaster.dart';
import 'payment_service.dart';

/// Google Play In-App Purchase Service
/// Handles Google Play and App Store in-app purchases
class GooglePlayIAPService {
  static final InAppPurchase _iap = InAppPurchase.instance;
  static StreamSubscription<List<PurchaseDetails>>? _subscription;
  static bool _isInitialized = false;

  /// Product IDs for coin packages
  /// These must match the product IDs configured in Google Play Console
  static const List<String> productIds = [
    'coins_8000', // 8,000 coins - $0.99
    'coins_16000', // 16,000 coins - $1.99
    'coins_64000', // 64,000 coins - $4.99
    'coins_128000', // 128,000 coins - $9.99
    'coins_320000', // 320,000 coins - $19.99
    'coins_640000', // 640,000 coins - $49.99
    'coins_800000', // 800,000 coins - $99.99
  ];

  /// Map product IDs to coin amounts
  static const Map<String, int> productCoins = {
    'coins_8000': 8000,
    'coins_16000': 16000,
    'coins_64000': 64000,
    'coins_128000': 128000,
    'coins_320000': 320000,
    'coins_640000': 640000,
    'coins_800000': 800000,
  };

  /// Initialize IAP and listen to purchase updates
  static Future<bool> initialize(BuildContext context) async {
    if (_isInitialized) return true;

    try {
      final available = await _iap.isAvailable();
      if (!available) {
        print('❌ In-App Purchase not available on this device');
        return false;
      }

      // Set up purchase listener
      final purchaseUpdated = _iap.purchaseStream;
      _subscription = purchaseUpdated.listen(
        (purchases) => _handlePurchaseUpdates(purchases, context),
        onDone: () => _subscription?.cancel(),
        onError: (error) {
          print('❌ Purchase stream error: $error');
          ToasterService.showError(context, 'Purchase error: $error');
        },
      );

      _isInitialized = true;
      print('✅ Google Play IAP initialized successfully');
      return true;
    } catch (e) {
      print('❌ GooglePlayIAPService.initialize error: $e');
      return false;
    }
  }

  /// Load available products from store
  static Future<List<ProductDetails>> loadProducts() async {
    try {
      final response = await _iap.queryProductDetails(productIds.toSet());

      if (response.error != null) {
        print('❌ Error loading products: ${response.error}');
        return [];
      }

      if (response.productDetails.isEmpty) {
        print(
          '⚠️ No products found. Make sure products are configured in store.',
        );
        return [];
      }

      print('✅ Loaded ${response.productDetails.length} products');
      return response.productDetails;
    } catch (e) {
      print('❌ GooglePlayIAPService.loadProducts error: $e');
      return [];
    }
  }

  /// Purchase a product
  static Future<bool> purchaseProduct(ProductDetails product) async {
    try {
      final purchaseParam = PurchaseParam(productDetails: product);

      // For consumable products (coins), use buyConsumable
      final success = await _iap.buyConsumable(
        purchaseParam: purchaseParam,
        autoConsume: false, // We'll consume after backend verification
      );

      return success;
    } catch (e) {
      print('❌ GooglePlayIAPService.purchaseProduct error: $e');
      return false;
    }
  }

  /// Handle purchase updates from the stream
  static Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchases,
    BuildContext context,
  ) async {
    for (final purchase in purchases) {
      print('📱 Purchase update: ${purchase.status}');

      if (purchase.status == PurchaseStatus.pending) {
        _showPendingUI(context);
      } else if (purchase.status == PurchaseStatus.error) {
        _handleError(purchase.error!, context);
        await _completePurchase(purchase);
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _verifyAndCompletePurchase(purchase, context);
      } else if (purchase.status == PurchaseStatus.canceled) {
        ToasterService.showInfo(context, 'Purchase cancelled');
        await _completePurchase(purchase);
      }
    }
  }

  /// Verify purchase with backend and credit coins
  static Future<void> _verifyAndCompletePurchase(
    PurchaseDetails purchase,
    BuildContext context,
  ) async {
    try {
      // Get coin amount for this product
      final coinAmount = productCoins[purchase.productID] ?? 0;
      if (coinAmount == 0) {
        print('❌ Unknown product ID: ${purchase.productID}');
        await _completePurchase(purchase);
        return;
      }

      // Get purchase token/receipt
      String purchaseToken;
      if (Platform.isAndroid) {
        // For Android, use verificationData.serverVerificationData
        purchaseToken = purchase.verificationData.serverVerificationData;
      } else if (Platform.isIOS) {
        // For iOS, use verificationData.serverVerificationData (receipt)
        purchaseToken = purchase.verificationData.serverVerificationData;
      } else {
        print('❌ Unsupported platform');
        await _completePurchase(purchase);
        return;
      }

      print('🔍 Verifying purchase with backend...');

      // Verify with backend
      final result =
          Platform.isAndroid
              ? await PaymentService.processGooglePlayPurchase(
                productId: purchase.productID,
                purchaseToken: purchaseToken,
                coinAmount: coinAmount,
              )
              : await PaymentService.processAppStorePurchase(
                productId: purchase.productID,
                receipt: purchaseToken,
                coinAmount: coinAmount,
              );

      if (result['success'] == true) {
        print('✅ Purchase verified and coins credited');
        if (context.mounted) {
          ToasterService.showSuccess(
            context,
            'Purchase successful! $coinAmount coins added to your account.',
          );
        }
      } else {
        print('❌ Purchase verification failed: ${result['message']}');
        if (context.mounted) {
          ToasterService.showError(
            context,
            result['message'] ?? 'Purchase verification failed',
          );
        }
      }

      // Complete the purchase
      await _completePurchase(purchase);
    } catch (e) {
      print('❌ _verifyAndCompletePurchase error: $e');
      if (context.mounted) {
        ToasterService.showError(context, 'Verification error: $e');
      }
      await _completePurchase(purchase);
    }
  }

  /// Complete a purchase (mark as done)
  static Future<void> _completePurchase(PurchaseDetails purchase) async {
    if (purchase.pendingCompletePurchase) {
      await _iap.completePurchase(purchase);
    }
  }

  /// Show pending UI
  static void _showPendingUI(BuildContext context) {
    if (context.mounted) {
      ToasterService.showInfo(context, 'Processing payment...');
    }
  }

  /// Handle purchase error
  static void _handleError(IAPError error, BuildContext context) {
    print('❌ Purchase error: ${error.message}');
    if (context.mounted) {
      ToasterService.showError(context, error.message);
    }
  }

  /// Restore previous purchases
  static Future<void> restorePurchases(BuildContext context) async {
    try {
      await _iap.restorePurchases();
      if (context.mounted) {
        ToasterService.showSuccess(context, 'Purchases restored');
      }
    } catch (e) {
      print('❌ GooglePlayIAPService.restorePurchases error: $e');
      if (context.mounted) {
        ToasterService.showError(context, 'Failed to restore purchases');
      }
    }
  }

  /// Dispose and clean up
  static void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _isInitialized = false;
  }
}
