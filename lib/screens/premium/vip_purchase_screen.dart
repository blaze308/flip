import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/premium_package_model.dart';
import '../../services/gamification_service.dart';
import '../../providers/profile_providers.dart';
import '../../widgets/custom_toaster.dart';

/// VIP Purchase Screen
/// Allows users to purchase VIP subscriptions (Normal, Super, Diamond)
class VipPurchaseScreen extends ConsumerStatefulWidget {
  const VipPurchaseScreen({super.key});

  @override
  ConsumerState<VipPurchaseScreen> createState() => _VipPurchaseScreenState();
}

class _VipPurchaseScreenState extends ConsumerState<VipPurchaseScreen> {
  PremiumPackageModel? _selectedPackage;
  bool _isPurchasing = false;

  final List<PremiumPackageModel> _packages = PremiumPackageModel.getVipPackages();

  Future<void> _purchaseVip() async {
    if (_selectedPackage == null) {
      ToasterService.showError(context, 'Please select a VIP package');
      return;
    }

    setState(() => _isPurchasing = true);

    try {
      final result = await GamificationService.purchaseVip(
        tier: _selectedPackage!.tier!,
        durationDays: _selectedPackage!.durationDays,
      );

      if (mounted) {
        setState(() => _isPurchasing = false);

        if (result['success'] == true) {
          // Refresh profile to show new VIP status
          ref.read(profileProvider(null).notifier).refresh();
          ref.read(walletBalanceProvider.notifier).refresh();

          ToasterService.showSuccess(
            context,
            'VIP activated successfully! 🎉',
          );
          Navigator.pop(context, true);
        } else {
          ToasterService.showError(
            context,
            result['message'] ?? 'Failed to purchase VIP',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPurchasing = false);
        ToasterService.showError(context, 'An error occurred: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider(null));
    final walletBalanceAsync = ref.watch(walletBalanceProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          'VIP Membership',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1D1E33),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Current Balance
          walletBalanceAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (balance) => Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1D1E33),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF4ECDC4).withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Your Balance:',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  Row(
                    children: [
                      Image.asset(
                        'assets/images/coin_icon.png',
                        width: 24,
                        height: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${balance['coins'] ?? 0}',
                        style: const TextStyle(
                          color: Color(0xFF4ECDC4),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Current VIP Status
          profileAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (user) {
              if (user == null) return const SizedBox.shrink();
              if (!user.isVip) return const SizedBox.shrink();

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      user.isDiamondVip
                          ? const Color(0xFFFFD700)
                          : user.isSuperVip
                              ? const Color(0xFFC0C0C0)
                              : const Color(0xFFCD7F32),
                      const Color(0xFF1D1E33),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Image.asset(
                      user.vipIcon,
                      width: 40,
                      height: 40,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current: ${user.vipTier.toUpperCase()} VIP',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (user.vipExpiresAt != null)
                            Text(
                              'Expires: ${_formatDate(user.vipExpiresAt!)}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Package Selection
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _packages.length,
              itemBuilder: (context, index) {
                final package = _packages[index];
                final isSelected = _selectedPackage?.id == package.id;

                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedPackage = package);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D1E33),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF4ECDC4)
                            : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF4ECDC4).withOpacity(0.3),
                                blurRadius: 12,
                                spreadRadius: 2,
                              )
                            ]
                          : [],
                    ),
                    child: Stack(
                      children: [
                        // Package Content
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Image.asset(
                                    package.iconPath,
                                    width: 50,
                                    height: 50,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          package.name,
                                          style: TextStyle(
                                            color: package.color,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          package.description,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              
                              // Price
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: package.color.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.asset(
                                      'assets/images/coin_icon.png',
                                      width: 20,
                                      height: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${package.price}',
                                      style: TextStyle(
                                        color: package.color,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '/ ${package.durationText}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Benefits
                              ...package.benefits.map((benefit) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          color: package.color,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            benefit,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )),
                            ],
                          ),
                        ),
                        
                        // Badges
                        if (package.isPopular)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(14),
                                  bottomLeft: Radius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'POPULAR',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        if (package.isBestValue)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(14),
                                  bottomLeft: Radius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'BEST VALUE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Purchase Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1D1E33),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isPurchasing || _selectedPackage == null
                      ? null
                      : _purchaseVip,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4ECDC4),
                    disabledBackgroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isPurchasing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _selectedPackage == null
                              ? 'Select a Package'
                              : 'Purchase ${_selectedPackage!.name}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

