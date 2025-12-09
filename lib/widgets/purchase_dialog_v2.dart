import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/coin_package_model.dart';
import '../services/wallet_service.dart';
import '../services/paystack_service.dart';
import '../services/ancient_coin_service.dart';
import '../services/token_auth_service.dart';
import '../screens/paystack_webview_screen.dart';
import '../screens/ancient_coin_webview_screen.dart';
import '../widgets/custom_toaster.dart';

/// Purchase Dialog V2
/// Allows users to purchase coins using real packages from backend
class PurchaseDialogV2 extends StatefulWidget {
  const PurchaseDialogV2({super.key});

  @override
  State<PurchaseDialogV2> createState() => _PurchaseDialogV2State();
}

class _PurchaseDialogV2State extends State<PurchaseDialogV2> {
  CoinPackageModel? _selectedPackage;
  bool _isPurchasing = false;
  bool _isLoading = true;
  List<CoinPackageModel> _packages = [];

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    setState(() => _isLoading = true);

    try {
      final packages = await WalletService.getCoinPackages();
      if (mounted) {
        setState(() {
          _packages = packages;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToasterService.showError(context, 'Failed to load packages');
      }
    }
  }

  Future<void> _handlePurchase() async {
    if (_selectedPackage == null) {
      ToasterService.showError(context, 'Please select a package');
      return;
    }

    // Show payment method selection
    final paymentMethod = await _showPaymentMethodDialog();
    if (paymentMethod == null) return;

    if (paymentMethod == 'paystack') {
      await _handlePaystackPayment();
    } else if (paymentMethod == 'ancientcoin') {
      await _handleAncientCoinPayment();
    } else if (paymentMethod == 'iap') {
      ToasterService.showInfo(context, 'In-App Purchase coming soon!');
    }
  }

  Future<void> _handleAncientCoinPayment() async {
    setState(() => _isPurchasing = true);

    try {
      // Check if user is authenticated with AncientCoin
      final isAuthenticated = await AncientCoinService.isAuthenticated();
      
      if (!isAuthenticated) {
        // Show OAuth webview to connect AncientCoin
        final connected = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => const AncientCoinWebviewScreen(),
          ),
        );

        if (connected != true) {
          if (mounted) {
            setState(() => _isPurchasing = false);
            ToasterService.showError(context, 'AncientCoin connection cancelled');
          }
          return;
        }
      }

      // Show payment screen
      if (mounted) {
        setState(() => _isPurchasing = false);

        final success = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => AncientCoinPaymentScreen(
              amount: _selectedPackage!.priceUSD,
              currency: 'USD', // Default to USD for AncientCoin
              coins: _selectedPackage!.coins + _selectedPackage!.bonusCoins,
            ),
          ),
        );

        if (success == true && mounted) {
          Navigator.pop(context, true); // Close purchase dialog
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPurchasing = false);
        ToasterService.showError(context, 'Payment failed: ${e.toString()}');
      }
    }
  }

  Future<String?> _showPaymentMethodDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1D1E33),
        title: const Text(
          'Select Payment Method',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPaymentMethodTile(
              icon: Icons.credit_card,
              title: 'Paystack',
              subtitle: 'Card payment (GHS, NGN, ZAR, KES)',
              value: 'paystack',
            ),
            const SizedBox(height: 12),
            _buildPaymentMethodTile(
              icon: Icons.account_balance_wallet,
              title: 'AncientCoin',
              subtitle: 'Pay with AncientCoin wallet',
              value: 'ancientcoin',
            ),
            const SizedBox(height: 12),
            _buildPaymentMethodTile(
              icon: Icons.phone_android,
              title: 'In-App Purchase',
              subtitle: 'Google Pay / Apple Pay',
              value: 'iap',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
  }) {
    return InkWell(
      onTap: () => Navigator.pop(context, value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF4ECDC4).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF4ECDC4).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF4ECDC4)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePaystackPayment() async {
    setState(() => _isPurchasing = true);

    try {
      final user = TokenAuthService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final email = user.email ?? 'user@example.com';
      
      // Convert price to kobo (multiply by 100)
      final amountInKobo = (_selectedPackage!.priceUSD * 100).toInt();

      // Initialize Paystack transaction
      final result = await PaystackService.initializeTransaction(
        email: email,
        amount: amountInKobo,
        currency: 'GHS', // Default to GHS for Paystack
        context: context,
      );

      if (mounted) {
        setState(() => _isPurchasing = false);

        if (result != null && result['success'] == true) {
          // Open webview for payment
          final success = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => PaystackWebviewScreen(
                authorizationUrl: result['authorizationUrl'],
                reference: result['reference'],
                coins: _selectedPackage!.coins + _selectedPackage!.bonusCoins,
                diamonds: 0, // No diamonds in current model
              ),
            ),
          );

          if (success == true && mounted) {
            Navigator.pop(context, true); // Close purchase dialog
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPurchasing = false);
        ToasterService.showError(context, 'Payment failed: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1D1E33),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Text(
                  '💰 Buy Coins',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Loading or Packages
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF4ECDC4)),
                ),
              )
            else if (_packages.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'No packages available',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              Expanded(
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _packages.length,
                  itemBuilder: (context, index) {
                    return _buildPackageCard(_packages[index]);
                  },
                ),
              ),

            const SizedBox(height: 24),

            // Purchase Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isPurchasing ? null : _handlePurchase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4ECDC4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey,
                ),
                child: _isPurchasing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _selectedPackage != null
                            ? 'Purchase for \$${_selectedPackage!.priceUSD.toStringAsFixed(2)}'
                            : 'Select a package',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            // Note
            const SizedBox(height: 16),
            Text(
              'Note: This is a demo. In production, this would integrate with real payment providers (Stripe, PayPal, In-App Purchase).',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackageCard(CoinPackageModel package) {
    final isSelected = _selectedPackage?.id == package.id;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedPackage = package);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0E21),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF4ECDC4) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Stack(
          children: [
            // Badge
            if (package.badgeText != null)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Color(package.badgeColor!),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    package.badgeText!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            // Content
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '🪙',
                  style: TextStyle(fontSize: 40),
                ),
                const SizedBox(height: 8),
                Text(
                  NumberFormat('#,###').format(package.coins),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (package.hasBonus) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '+${NumberFormat('#,###').format(package.bonusCoins)} Bonus',
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  '\$${package.priceUSD.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFF4ECDC4),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (package.hasDiscount) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${package.discountPercent}% OFF',
                    style: TextStyle(
                      color: Colors.orange[300],
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

