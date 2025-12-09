import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// About Screen
/// App information, terms, privacy policy
class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
  String _appVersion = '';
  String _buildNumber = '';

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
          _appVersion = packageInfo.version;
          _buildNumber = packageInfo.buildNumber;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _appVersion = 'Unknown';
          _buildNumber = 'Unknown';
        });
      }
    }
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          'About',
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
            // App Logo and Info
            Card(
              color: const Color(0xFF1D1E33),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(
                      Icons.flip,
                      size: 80,
                      color: Color(0xFF4ECDC4),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Flip',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Version $_appVersion (Build $_buildNumber)',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Connect, Stream, and Earn',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Legal
            _buildSectionHeader('Legal'),
            _buildLinkTile(
              icon: Icons.description,
              title: 'Terms of Service',
              onTap: () {
                _launchURL('https://flip.com/terms');
              },
            ),
            _buildLinkTile(
              icon: Icons.privacy_tip,
              title: 'Privacy Policy',
              onTap: () {
                _launchURL('https://flip.com/privacy');
              },
            ),
            _buildLinkTile(
              icon: Icons.gavel,
              title: 'Community Guidelines',
              onTap: () {
                _launchURL('https://flip.com/guidelines');
              },
            ),
            const SizedBox(height: 24),

            // Company
            _buildSectionHeader('Company'),
            _buildLinkTile(
              icon: Icons.info,
              title: 'About Us',
              onTap: () {
                _launchURL('https://flip.com/about');
              },
            ),
            _buildLinkTile(
              icon: Icons.work,
              title: 'Careers',
              onTap: () {
                _launchURL('https://flip.com/careers');
              },
            ),
            _buildLinkTile(
              icon: Icons.article,
              title: 'Blog',
              onTap: () {
                _launchURL('https://flip.com/blog');
              },
            ),
            const SizedBox(height: 24),

            // Social Media
            _buildSectionHeader('Follow Us'),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSocialButton(
                  icon: Icons.facebook,
                  onTap: () => _launchURL('https://facebook.com/flip'),
                ),
                _buildSocialButton(
                  icon: Icons.camera_alt,
                  onTap: () => _launchURL('https://instagram.com/flip'),
                ),
                _buildSocialButton(
                  icon: Icons.chat,
                  onTap: () => _launchURL('https://twitter.com/flip'),
                ),
                _buildSocialButton(
                  icon: Icons.play_arrow,
                  onTap: () => _launchURL('https://youtube.com/flip'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Copyright
            Center(
              child: Text(
                '© ${DateTime.now().year} Flip. All rights reserved.',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
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

  Widget _buildLinkTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      color: const Color(0xFF1D1E33),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF4ECDC4)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        trailing: const Icon(Icons.open_in_new, color: Colors.white70, size: 16),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1D1E33),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: const Color(0xFF4ECDC4), size: 28),
      ),
    );
  }
}

