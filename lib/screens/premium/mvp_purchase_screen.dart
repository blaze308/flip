import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/premium_package_model.dart';
import '../../services/gamification_service.dart';
import '../../providers/profile_providers.dart';
import '../../widgets/custom_toaster.dart';

/// MVP Purchase Screen
/// Allows users to purchase MVP Premium subscriptions
class MvpPurchaseScreen extends ConsumerStatefulWidget {
  const MvpPurchaseScreen({super.key});

  @override
  ConsumerState<MvpPurchaseScreen> createState() => _MvpPurchaseScreenState();
}

class _MvpPurchaseScreenState extends ConsumerState<MvpPurchaseScreen> {
  PremiumPackageModel? _selectedPackage;
  bool _isPurchasing = false;

  final List<PremiumPackageModel> _packages = PremiumPackageModel.getMvpPackages();

  Future<void> _purchaseMvp() async {
    if (_selectedPackage == null) {
      ToasterService.showError(context, 'Please select an MVP package');
      return;
    }

    setState(() => _isPurchasing = true);

    try {
      final result = await GamificationService.purchaseMvp(
        durationDays: _selectedPackage!.durationDays,
      );

      if (mounted) {
        setState(() => _isPurchasing = false);

        if (result['success'] == true) {
          // Refresh profile to show new MVP status
          ref.read(profileProvider(null).notifier).refresh();
          ref.read(walletBalanceProvider.notifier).refresh();

          ToasterService.showSuccess(
            context,
            'MVP Premium activated! 🎉',
          );
          Navigator.pop(context, true);
        } else {
          ToasterService.showError(
            context,
            result['message'] ?? 'Failed to purchase MVP',
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
          'MVP Premium',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1D1E33),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Header Banner
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF9C27B0), Color(0xFF673AB7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Image.asset(
                  'assets/images/icon_mvp.png',
                  width: 80,
                  height: 80,
                ),
                const SizedBox(height: 16),
                const Text(
                  'MVP Premium Membership',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Unlock 11 exclusive privileges',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Current Balance
          walletBalanceAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (balance) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
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

          // Current MVP Status
          profileAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (user) {
              if (user == null) return const SizedBox.shrink();
              if (!user.isMVP) return const SizedBox.shrink();

              return Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9C27B0), Color(0xFF1D1E33)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Image.asset(
                      user.mvpIcon,
                      width: 40,
                      height: 40,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Current: MVP Premium',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (user.mvpExpiresAt != null)
                            Text(
                              'Expires: ${_formatDate(user.mvpExpiresAt!)}',
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

          const SizedBox(height: 8),

          // Package Selection
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.75,
              ),
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
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D1E33),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF9C27B0)
                            : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF9C27B0).withOpacity(0.3),
                                blurRadius: 12,
                                spreadRadius: 2,
                              )
                            ]
                          : [],
                    ),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                package.durationText,
                                style: const TextStyle(
                                  color: Color(0xFF9C27B0),
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    'assets/images/coin_icon.png',
                                    width: 24,
                                    height: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${package.price}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ...package.benefits.take(3).map(
                                    (benefit) => Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        benefit,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                            ],
                          ),
                        ),
                        if (package.isPopular)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
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
                                  fontSize: 10,
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
                                horizontal: 8,
                                vertical: 4,
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
                                  fontSize: 10,
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
                      : _purchaseMvp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9C27B0),
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
                              : 'Purchase MVP Premium',
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

