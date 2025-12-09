import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/token_auth_service.dart';
import '../widgets/custom_toaster.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Settings Screen
/// Comprehensive settings and preferences
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = '';
  String _selectedCurrency = 'USD (\$)';

  // Popular currencies
  final List<Map<String, String>> _currencies = [
    {'code': 'USD', 'symbol': '\$', 'name': 'US Dollar'},
    {'code': 'EUR', 'symbol': '€', 'name': 'Euro'},
    {'code': 'GBP', 'symbol': '£', 'name': 'British Pound'},
    {'code': 'GHS', 'symbol': '₵', 'name': 'Ghanaian Cedi'},
    {'code': 'NGN', 'symbol': '₦', 'name': 'Nigerian Naira'},
    {'code': 'ZAR', 'symbol': 'R', 'name': 'South African Rand'},
    {'code': 'KES', 'symbol': 'KSh', 'name': 'Kenyan Shilling'},
    {'code': 'JPY', 'symbol': '¥', 'name': 'Japanese Yen'},
    {'code': 'CNY', 'symbol': '¥', 'name': 'Chinese Yuan'},
    {'code': 'INR', 'symbol': '₹', 'name': 'Indian Rupee'},
  ];

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

  Future<void> _clearCache() async {
    try {
      await DefaultCacheManager().emptyCache();
      if (mounted) {
        ToasterService.showSuccess(context, 'Cache cleared successfully');
      }
    } catch (e) {
      if (mounted) {
        ToasterService.showError(context, 'Failed to clear cache');
      }
    }
  }

  Future<void> _showCurrencyPicker() async {
    final selected = await showDialog<Map<String, String>>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1D1E33),
            title: const Text(
              'Select Currency',
              style: TextStyle(color: Colors.white),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _currencies.length,
                itemBuilder: (context, index) {
                  final currency = _currencies[index];
                  return ListTile(
                    leading: Text(
                      currency['symbol']!,
                      style: const TextStyle(
                        color: Color(0xFF4ECDC4),
                        fontSize: 24,
                      ),
                    ),
                    title: Text(
                      currency['name']!,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      currency['code']!,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    onTap: () => Navigator.pop(context, currency),
                  );
                },
              ),
            ),
          ),
    );

    if (selected != null) {
      setState(() {
        _selectedCurrency = '${selected['code']} (${selected['symbol']})';
      });
      ToasterService.showSuccess(
        context,
        'Currency updated to ${selected['name']}',
      );
      // TODO: Save to backend user preferences
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1D1E33),
            title: const Text('Logout', style: TextStyle(color: Colors.white)),
            content: const Text(
              'Are you sure you want to logout?',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Logout'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      await TokenAuthService.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    }
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ToasterService.showError(context, 'Could not open link');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1D1E33),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        children: [
          // Account & Security Section
          _buildSectionHeader('Account & Security'),
          _buildSettingsTile(
            icon: Icons.lock,
            title: 'Account & Security',
            subtitle: 'Password, email, phone',
            onTap: () {
              // TODO: Navigate to account security screen
              ToasterService.showInfo(context, 'Coming soon');
            },
          ),
          _buildSettingsTile(
            icon: Icons.privacy_tip,
            title: 'Privacy',
            subtitle: 'Control your privacy settings',
            onTap: () {
              // TODO: Navigate to privacy screen
              ToasterService.showInfo(context, 'Coming soon');
            },
          ),
          _buildSettingsTile(
            icon: Icons.block,
            title: 'Blocked Users',
            subtitle: 'Manage blocked users',
            onTap: () {
              // TODO: Navigate to blocked users screen
              ToasterService.showInfo(context, 'Coming soon');
            },
          ),

          // Notifications Section
          _buildSectionHeader('Notifications'),
          _buildSettingsTile(
            icon: Icons.notifications,
            title: 'Push Notifications',
            subtitle: 'Manage notification preferences',
            onTap: () {
              // TODO: Navigate to notifications screen
              ToasterService.showInfo(context, 'Coming soon');
            },
          ),
          _buildSettingsTile(
            icon: Icons.message,
            title: 'Message Notifications',
            subtitle: 'Chat and message alerts',
            onTap: () {
              // TODO: Navigate to message notifications screen
              ToasterService.showInfo(context, 'Coming soon');
            },
          ),

          // Preferences Section
          _buildSectionHeader('Preferences'),
          _buildSettingsTile(
            icon: Icons.language,
            title: 'Language',
            subtitle: 'English',
            onTap: () {
              // TODO: Navigate to language screen
              ToasterService.showInfo(context, 'Coming soon');
            },
          ),
          _buildSettingsTile(
            icon: Icons.attach_money,
            title: 'Currency',
            subtitle: _selectedCurrency,
            onTap: _showCurrencyPicker,
          ),
          _buildSettingsTile(
            icon: Icons.dark_mode,
            title: 'Theme',
            subtitle: 'Dark mode',
            onTap: () {
              // TODO: Navigate to theme screen
              ToasterService.showInfo(context, 'Coming soon');
            },
          ),

          // App Settings Section
          _buildSectionHeader('App Settings'),
          _buildSettingsTile(
            icon: Icons.cleaning_services,
            title: 'Clear Cache',
            subtitle: 'Free up storage space',
            onTap: _clearCache,
          ),
          _buildSettingsTile(
            icon: Icons.storage,
            title: 'Storage',
            subtitle: 'Manage app storage',
            onTap: () {
              // TODO: Navigate to storage screen
              ToasterService.showInfo(context, 'Coming soon');
            },
          ),

          // About Section
          _buildSectionHeader('About'),
          _buildSettingsTile(
            icon: Icons.info,
            title: 'About',
            subtitle: 'App information',
            onTap: () {
              _showAboutDialog();
            },
          ),
          _buildSettingsTile(
            icon: Icons.description,
            title: 'Terms of Service',
            onTap: () {
              _launchURL('https://ancientplustech.com/terms');
            },
          ),
          _buildSettingsTile(
            icon: Icons.policy,
            title: 'Privacy Policy',
            onTap: () {
              _launchURL('https://ancientplustech.com/privacy');
            },
          ),
          _buildSettingsTile(
            icon: Icons.star,
            title: 'Rate App',
            onTap: () {
              // TODO: Open app store for rating
              ToasterService.showInfo(context, 'Coming soon');
            },
          ),
          _buildSettingsTile(
            icon: Icons.help,
            title: 'Help & Support',
            onTap: () {
              _launchURL('https://ancientplustech.com/support');
            },
          ),
          _buildSettingsTile(
            icon: Icons.apps,
            title: 'Version',
            subtitle: _appVersion,
            trailing: const SizedBox.shrink(),
          ),

          // Danger Zone
          _buildSectionHeader('Danger Zone'),
          _buildSettingsTile(
            icon: Icons.logout,
            title: 'Logout',
            titleColor: Colors.red,
            onTap: _logout,
          ),
          _buildSettingsTile(
            icon: Icons.delete_forever,
            title: 'Delete Account',
            titleColor: Colors.red,
            onTap: () {
              // TODO: Navigate to delete account screen
              ToasterService.showInfo(context, 'Coming soon');
            },
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF4ECDC4),
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? titleColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: titleColor ?? const Color(0xFF4ECDC4)),
        title: Text(
          title,
          style: TextStyle(
            color: titleColor ?? Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle:
            subtitle != null
                ? Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                )
                : null,
        trailing:
            trailing ?? Icon(Icons.chevron_right, color: Colors.grey[600]),
        onTap: onTap,
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1D1E33),
            title: const Text(
              'About Flip',
              style: TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Flip - Social Media App',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Version: $_appVersion',
                  style: TextStyle(color: Colors.grey[400]),
                ),
                const SizedBox(height: 16),
                Text(
                  'A modern social media platform for sharing moments, connecting with friends, and discovering new content.',
                  style: TextStyle(color: Colors.grey[300], height: 1.5),
                ),
                const SizedBox(height: 16),
                Text(
                  '© 2024 Ancient Plus Tech',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }
}
