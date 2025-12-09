import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart' as share_plus;
import '../providers/invitation_providers.dart';
import '../widgets/custom_toaster.dart';
import 'invitation_history_screen.dart';

/// Invitation Screen
/// Invite friends and earn rewards
class InvitationScreen extends ConsumerWidget {
  const InvitationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final referralAsync = ref.watch(referralCodeProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          'Invite Friends',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1D1E33),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const InvitationHistoryScreen()),
              );
            },
          ),
        ],
      ),
      body: referralAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF4ECDC4)),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error: $error',
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(referralCodeProvider.notifier).refresh(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4ECDC4),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (data) {
          final referralCode = data['referralCode'] ?? '';
          final totalInvites = data['totalInvites'] ?? 0;
          final totalRewards = data['totalRewards'] ?? 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Referral Code Card
                Card(
                  color: const Color(0xFF1D1E33),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.card_giftcard,
                          size: 64,
                          color: Color(0xFF4ECDC4),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Your Referral Code',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF4ECDC4), width: 2),
                          ),
                          child: Text(
                            referralCode,
                            style: const TextStyle(
                              color: Color(0xFF4ECDC4),
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: referralCode));
                                ToasterService.showSuccess(context, 'Referral code copied!');
                              },
                              icon: const Icon(Icons.copy, size: 18),
                              label: const Text('Copy'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4ECDC4),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: () {
                                share_plus.Share.share(
                                  'Join Flip using my referral code: $referralCode\nDownload: https://flip.com/download',
                                  subject: 'Join Flip!',
                                );
                              },
                              icon: const Icon(Icons.share, size: 18),
                              label: const Text('Share'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4ECDC4),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Stats
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Total Invites',
                        totalInvites.toString(),
                        Icons.people,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Total Rewards',
                        '$totalRewards coins',
                        Icons.monetization_on,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Rewards Info
                _buildSectionHeader('Referral Rewards'),
                _buildRewardItem('100 coins', 'For each friend who joins'),
                _buildRewardItem('500 coins', 'When they make their first purchase'),
                _buildRewardItem('10% bonus', 'On all their purchases (lifetime)'),
                const SizedBox(height: 24),

                // How It Works
                _buildSectionHeader('How It Works'),
                _buildStepItem('1', 'Share your referral code'),
                _buildStepItem('2', 'Friend signs up using your code'),
                _buildStepItem('3', 'You both get rewards!'),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF4ECDC4),
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Card(
      color: const Color(0xFF1D1E33),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF4ECDC4), size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRewardItem(String reward, String description) {
    return Card(
      color: const Color(0xFF1D1E33),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.star, color: Color(0xFF4ECDC4), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reward,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    description,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepItem(String number, String description) {
    return Card(
      color: const Color(0xFF1D1E33),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFF4ECDC4),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  number,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                description,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

