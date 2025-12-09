import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'contact_us_screen.dart';
import 'report_screen.dart';

/// Help Center Screen
/// FAQ, guides, and support resources
class HelpCenterScreen extends ConsumerWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          'Help Center',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1D1E33),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Quick Actions
            _buildSectionHeader('Quick Actions'),
            _buildActionTile(
              context,
              icon: Icons.contact_support,
              title: 'Contact Us',
              subtitle: 'Get in touch with our support team',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ContactUsScreen()),
                );
              },
            ),
            _buildActionTile(
              context,
              icon: Icons.report,
              title: 'Report',
              subtitle: 'Report users or content',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ReportScreen()),
                );
              },
            ),
            const SizedBox(height: 24),

            // FAQ Section
            _buildSectionHeader('Frequently Asked Questions'),
            _buildFAQItem(
              'How do I purchase coins?',
              'Go to your wallet, tap "Buy Coins", select a package, and choose your payment method.',
            ),
            _buildFAQItem(
              'How do I become VIP?',
              'Navigate to Premium Hub from your profile, select VIP, choose a package, and complete the purchase.',
            ),
            _buildFAQItem(
              'How do I join an agency?',
              'Go to Agency section, enter the agency ID provided by your agent, and submit your application.',
            ),
            _buildFAQItem(
              'How do I start a live stream?',
              'Tap the "Go Live" button on the home screen, set up your stream details, and start broadcasting.',
            ),
            _buildFAQItem(
              'How do I report a user?',
              'Go to the user\'s profile, tap the menu icon, and select "Report". Choose a reason and submit.',
            ),
            _buildFAQItem(
              'How do I delete my account?',
              'Go to Settings > Account & Security > Delete Account. This action is permanent and cannot be undone.',
            ),
            const SizedBox(height: 24),

            // Guides Section
            _buildSectionHeader('Guides'),
            _buildGuideTile(
              context,
              icon: Icons.star,
              title: 'Getting Started',
              subtitle: 'Learn the basics of using the app',
            ),
            _buildGuideTile(
              context,
              icon: Icons.live_tv,
              title: 'Live Streaming Guide',
              subtitle: 'How to start and manage live streams',
            ),
            _buildGuideTile(
              context,
              icon: Icons.account_balance_wallet,
              title: 'Wallet & Payments',
              subtitle: 'Understanding coins, diamonds, and payments',
            ),
            _buildGuideTile(
              context,
              icon: Icons.business,
              title: 'Agency System',
              subtitle: 'How the agency system works',
            ),
          ],
        ),
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

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      color: const Color(0xFF1D1E33),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF4ECDC4)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
        onTap: onTap,
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Card(
      color: const Color(0xFF1D1E33),
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        iconColor: const Color(0xFF4ECDC4),
        collapsedIconColor: Colors.white70,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              answer,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Card(
      color: const Color(0xFF1D1E33),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF4ECDC4)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
        onTap: () {
          // TODO: Navigate to guide detail screen
        },
      ),
    );
  }
}

