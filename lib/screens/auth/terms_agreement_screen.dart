import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Terms of Service and User Agreement Screen
/// Displays EULA that users must accept before registration
class TermsAgreementScreen extends StatefulWidget {
  final Function(bool)? onAccept;
  final bool showAcceptButton;

  const TermsAgreementScreen({
    super.key,
    this.onAccept,
    this.showAcceptButton = true,
  });

  @override
  State<TermsAgreementScreen> createState() => _TermsAgreementScreenState();
}

class _TermsAgreementScreenState extends State<TermsAgreementScreen> {
  bool _hasScrolledToBottom = false;
  final ScrollController _scrollController = ScrollController();
  bool _accepted = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      if (currentScroll >= maxScroll - 50) {
        if (!_hasScrolledToBottom) {
          setState(() {
            _hasScrolledToBottom = true;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C3E50),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C3E50),
        elevation: 0,
        title: const Text(
          'Terms of Service & User Agreement',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'End User License Agreement (EULA)',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Last Updated: ${DateTime.now().year}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 32),

                  _buildSection(
                    '1. Acceptance of Terms',
                    'By downloading, installing, or using Ancient.flip (the "App"), you agree to be bound by these Terms of Service and User Agreement. If you do not agree to these terms, do not use the App.',
                  ),

                  _buildSection(
                    '2. User-Generated Content',
                    'Ancient.flip allows users to create, post, and share content. By using this App, you agree that:\n\n'
                        '• You are solely responsible for all content you post, share, or transmit\n'
                        '• You will not post objectionable, harmful, or abusive content\n'
                        '• You will respect other users and their rights\n'
                        '• You will not engage in harassment, bullying, or hate speech',
                  ),

                  _buildSection(
                    '3. Zero Tolerance Policy',
                    'Ancient.flip has a ZERO TOLERANCE policy for:\n\n'
                        '• Objectionable content including but not limited to: hate speech, violence, explicit sexual content, illegal activities, harassment, or content that promotes harm\n'
                        '• Abusive behavior including: bullying, stalking, threats, intimidation, or any form of harassment\n'
                        '• Spam, scams, or fraudulent activities\n'
                        '• Impersonation or false representation\n\n'
                        'Users who violate this policy will have their accounts immediately suspended or terminated, and their content removed. We reserve the right to report illegal activities to law enforcement.',
                  ),

                  _buildSection(
                    '4. User Blocking and Reporting',
                    'You have the right to:\n\n'
                        '• Block any user who engages in objectionable or abusive behavior\n'
                        '• Report content or users that violate these terms\n'
                        '• Request removal of content that violates your rights\n\n'
                        'When you block a user, their content will be immediately removed from your feed, and they will not be able to contact you. All blocking actions are logged and reviewed by our moderation team.',
                  ),

                  _buildSection(
                    '5. Content Moderation',
                    'We actively moderate content to ensure a safe environment. Our moderation team reviews reported content and takes appropriate action, including:\n\n'
                        '• Removing objectionable content\n'
                        '• Suspending or terminating accounts\n'
                        '• Reporting illegal activities to authorities\n'
                        '• Implementing permanent bans for severe violations',
                  ),

                  _buildSection(
                    '6. Privacy and Data',
                    'Your privacy is important to us. Please review our Privacy Policy to understand how we collect, use, and protect your data. By using the App, you consent to our data practices as described in the Privacy Policy.',
                  ),

                  _buildSection(
                    '7. Account Responsibility',
                    'You are responsible for:\n\n'
                        '• Maintaining the security of your account\n'
                        '• All activities that occur under your account\n'
                        '• Ensuring your content complies with these terms\n'
                        '• Respecting intellectual property rights',
                  ),

                  _buildSection(
                    '8. Prohibited Activities',
                    'You agree NOT to:\n\n'
                        '• Post content that is illegal, harmful, or violates any laws\n'
                        '• Harass, threaten, or abuse other users\n'
                        '• Post spam, advertisements, or unsolicited content\n'
                        '• Impersonate others or provide false information\n'
                        '• Attempt to hack, disrupt, or damage the App\n'
                        '• Collect user data without permission\n'
                        '• Use automated systems to interact with the App',
                  ),

                  _buildSection(
                    '9. Intellectual Property',
                    'All content you post remains yours, but by posting, you grant Ancient.flip a license to display, distribute, and use your content within the App. You represent that you have the right to grant this license.',
                  ),

                  _buildSection(
                    '10. Termination',
                    'We reserve the right to suspend or terminate your account at any time for violations of these terms, without prior notice. You may also terminate your account at any time.',
                  ),

                  _buildSection(
                    '11. Disclaimer',
                    'The App is provided "as is" without warranties. We are not responsible for user-generated content or interactions between users.',
                  ),

                  _buildSection(
                    '12. Changes to Terms',
                    'We may update these terms at any time. Continued use of the App after changes constitutes acceptance of the new terms.',
                  ),

                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () {
                            _launchURL('https://ancientplustech.com/privacy');
                          },
                          icon: const Icon(
                            Icons.policy,
                            color: Color(0xFF4ECDC4),
                          ),
                          label: const Text(
                            'View Privacy Policy',
                            style: TextStyle(color: Color(0xFF4ECDC4)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          if (widget.showAcceptButton) ...[
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: const Color(0xFF34495E),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  if (!_hasScrolledToBottom)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.white.withOpacity(0.6),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Please scroll to read all terms',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      Checkbox(
                        value: _accepted,
                        onChanged:
                            _hasScrolledToBottom
                                ? (value) {
                                  setState(() {
                                    _accepted = value ?? false;
                                  });
                                }
                                : null,
                        activeColor: const Color(0xFF4ECDC4),
                        checkColor: Colors.white,
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap:
                              _hasScrolledToBottom
                                  ? () {
                                    setState(() {
                                      _accepted = !_accepted;
                                    });
                                  }
                                  : null,
                          child: Text(
                            'I have read and agree to the Terms of Service and User Agreement',
                            style: TextStyle(
                              color:
                                  _hasScrolledToBottom
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.5),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed:
                          _accepted && _hasScrolledToBottom
                              ? () {
                                if (widget.onAccept != null) {
                                  widget.onAccept!(true);
                                }
                                Navigator.of(context).pop(true);
                              }
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4ECDC4),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[700],
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Accept and Continue',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4ECDC4),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open URL: $url')));
      }
    }
  }
}
