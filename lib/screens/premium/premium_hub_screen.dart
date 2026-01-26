import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/profile_providers.dart';
import 'vip_purchase_screen.dart';
import 'mvp_purchase_screen.dart';
import 'guardian_purchase_screen.dart';
import 'subscription_history_screen.dart'; // NEW

/// Premium Hub Screen
/// Central hub for all premium features (VIP, MVP, Guardian)
class PremiumHubScreen extends ConsumerWidget {
  const PremiumHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider(null));

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          'Premium Features',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1D1E33),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4ECDC4), Color(0xFF556270)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Premium Account',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.history, color: Colors.white),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) =>
                                      const SubscriptionHistoryScreen(),
                            ),
                          );
                        },
                        tooltip: 'Subscription History',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Get exclusive benefits and stand out',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  profileAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (user) {
                      if (user == null) return const SizedBox.shrink();

                      final List<Widget> statusWidgets = [];

                      if (user.isVip) {
                        statusWidgets.add(
                          _buildStatusChip(
                            'VIP: ${user.vipTier.toUpperCase()}',
                            user.vipExpiresAt,
                            const Color(0xFFFFD700),
                          ),
                        );
                      }

                      if (user.isMVP) {
                        statusWidgets.add(
                          _buildStatusChip(
                            'MVP',
                            user.mvpExpiresAt,
                            const Color(0xFF9C27B0),
                          ),
                        );
                      }

                      if (user.hasGuardian) {
                        statusWidgets.add(
                          _buildStatusChip(
                            '${user.guardianType?.toUpperCase()} Guardian',
                            user.guardianExpiresAt,
                            const Color(0xFFC0C0C0),
                          ),
                        );
                      }

                      if (statusWidgets.isEmpty) {
                        return const Text(
                          'No active premium features',
                          style: TextStyle(color: Colors.white60, fontSize: 14),
                        );
                      }

                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: statusWidgets,
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // VIP Card
            _buildPremiumCard(
              context,
              title: 'VIP Membership',
              description: '3 tiers with daily coins & exclusive perks',
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFCD7F32)],
              ),
              icon: Icons.star,
              iconPath: 'assets/images/icon_vip_3.png',
              benefits: [
                'Daily coin bonuses up to 35,000',
                'Live float tags & platform speakers',
                'Distinguished logo & ranking boost',
                'Invisible visitor mode (Diamond)',
              ],
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const VipPurchaseScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // MVP Card
            _buildPremiumCard(
              context,
              title: 'MVP Premium',
              description: '11 exclusive privileges for true MVPs',
              gradient: const LinearGradient(
                colors: [Color(0xFF9C27B0), Color(0xFF673AB7)],
              ),
              icon: Icons.workspace_premium,
              iconPath: 'assets/images/icon_mvp.png',
              benefits: [
                'Exclusive social footprint',
                'Level up acceleration',
                'Premium badge & frame',
                'Wealth privileges',
              ],
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MvpPurchaseScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // Guardian Card
            _buildPremiumCard(
              context,
              title: 'Guardian System',
              description: 'Protect your favorite creators',
              gradient: const LinearGradient(
                colors: [Color(0xFFFF4500), Color(0xFFFFD700)],
              ),
              icon: Icons.shield,
              iconPath: 'assets/images/icon_sh_3.png',
              benefits: [
                'Silver, Gold, or King tier',
                'Entry effects & exclusive bubble',
                'Distinguished logo',
                'Priority in chat',
              ],
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GuardianPurchaseScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Benefits Comparison
            const Text(
              'Why Go Premium?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildBenefitItem(
              Icons.monetization_on,
              'Earn More',
              'Get daily coin bonuses and rewards',
              const Color(0xFFFFD700),
            ),
            _buildBenefitItem(
              Icons.trending_up,
              'Level Up Faster',
              'Accelerate your progress and ranking',
              const Color(0xFF4ECDC4),
            ),
            _buildBenefitItem(
              Icons.visibility,
              'Stand Out',
              'Exclusive badges, frames, and effects',
              const Color(0xFF9C27B0),
            ),
            _buildBenefitItem(
              Icons.support,
              'VIP Support',
              'Priority customer service',
              const Color(0xFFFF4500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumCard(
    BuildContext context, {
    required String title,
    required String description,
    required Gradient gradient,
    required IconData icon,
    required String iconPath,
    required List<String> benefits,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1D1E33).withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 28, color: Colors.white),
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
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          description,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...benefits.map(
                (benefit) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xFF4ECDC4),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          benefit,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitItem(
    IconData icon,
    String title,
    String description,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
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
                  description,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, DateTime? expiresAt, Color color) {
    String expiryText = '';
    if (expiresAt != null) {
      final now = DateTime.now();
      final difference = expiresAt.difference(now).inDays;
      if (difference < 0) {
        expiryText = ' (Expired)';
      } else if (difference == 0) {
        expiryText = ' (Expires today)';
      } else {
        expiryText = ' ($difference days left)';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$label$expiryText',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
