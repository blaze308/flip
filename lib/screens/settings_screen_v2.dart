import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/token_auth_service.dart';
import '../widgets/custom_toaster.dart';
import 'account_security_screen.dart';
import 'privacy_settings_screen.dart';
import 'notification_settings_screen.dart';
import 'language_settings_screen.dart';
import 'help_center_screen.dart';
import 'feedback_screen.dart';
import 'about_screen.dart';

/// Settings Screen V2 (Riverpod)
/// Comprehensive settings and preferences
class SettingsScreenV2 extends ConsumerStatefulWidget {
  const SettingsScreenV2({super.key});

  @override
  ConsumerState<SettingsScreenV2> createState() => _SettingsScreenV2State();
}

class _SettingsScreenV2State extends ConsumerState<SettingsScreenV2> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _appVersion = 'Unknown';
        });
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1D1E33),
        title: const Text(
          'Logout',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4ECDC4),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await TokenAuthService.signOut();
      if (mounted) {
        ToasterService.showSuccess(context, 'Logged out successfully');
        // Navigate to login screen
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          'Settings',
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
            // Account & Security Section
            _buildSectionHeader('Account & Security'),
            _buildSettingsTile(
              icon: Icons.security,
              title: 'Account & Security',
              subtitle: 'Password, 2FA, phone binding',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AccountSecurityScreen()),
                );
              },
            ),
            const SizedBox(height: 24),

            // Privacy Section
            _buildSectionHeader('Privacy'),
            _buildSettingsTile(
              icon: Icons.privacy_tip,
              title: 'Privacy Settings',
              subtitle: 'Profile visibility, messaging, calls',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PrivacySettingsScreen()),
                );
              },
            ),
            const SizedBox(height: 24),

            // Notifications Section
            _buildSectionHeader('Notifications'),
            _buildSettingsTile(
              icon: Icons.notifications,
              title: 'Notification Settings',
              subtitle: 'Push, in-app, sound, vibration',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NotificationSettingsScreen()),
                );
              },
            ),
            const SizedBox(height: 24),

            // Preferences Section
            _buildSectionHeader('Preferences'),
            _buildSettingsTile(
              icon: Icons.language,
              title: 'Language',
              subtitle: 'Select your preferred language',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LanguageSettingsScreen()),
                );
              },
            ),
            const SizedBox(height: 24),

            // Support Section
            _buildSectionHeader('Support & Help'),
            _buildSettingsTile(
              icon: Icons.help_outline,
              title: 'Help Center',
              subtitle: 'FAQ and guides',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HelpCenterScreen()),
                );
              },
            ),
            _buildSettingsTile(
              icon: Icons.feedback,
              title: 'Feedback',
              subtitle: 'Send us your feedback',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FeedbackScreen()),
                );
              },
            ),
            _buildSettingsTile(
              icon: Icons.info_outline,
              title: 'About',
              subtitle: 'App information and legal',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AboutScreen()),
                );
              },
            ),
            const SizedBox(height: 24),

            // App Info
            _buildSectionHeader('App Information'),
            Card(
              color: const Color(0xFF1D1E33),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildInfoRow('Version', _appVersion),
                    const Divider(color: Colors.white30, height: 24),
                    _buildInfoRow('Build', 'Production'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Logout Button
            ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
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

  Widget _buildSettingsTile({
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

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

