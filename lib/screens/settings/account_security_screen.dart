import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_providers.dart';
import '../../widgets/custom_toaster.dart';

/// Account & Security Screen
/// Manage password, 2FA, phone binding, and sessions
class AccountSecurityScreen extends ConsumerStatefulWidget {
  const AccountSecurityScreen({super.key});

  @override
  ConsumerState<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends ConsumerState<AccountSecurityScreen> {
  @override
  void initState() {
    super.initState();
    // Load sessions
    Future.microtask(() => ref.read(sessionsProvider.notifier).refresh());
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1D1E33),
        title: const Text(
          'Delete Account',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently deleted.',
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
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await ref.read(deleteAccountProvider.notifier).deleteAccount();

      if (mounted) {
        if (result['success'] == true) {
          ToasterService.showSuccess(context, result['message'] ?? 'Account deleted successfully');
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        } else {
          ToasterService.showError(context, result['message'] ?? 'Failed to delete account');
        }
        ref.read(deleteAccountProvider.notifier).reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(sessionsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          'Account & Security',
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
            // Security Options
            _buildSectionHeader('Security'),
            _buildSettingsTile(
              icon: Icons.lock,
              title: 'Change Password',
              subtitle: 'Update your password',
              onTap: () {
                ToasterService.showInfo(context, 'Change password feature coming soon');
              },
            ),
            _buildSettingsTile(
              icon: Icons.email,
              title: 'Email Verification',
              subtitle: 'Verify your email address',
              onTap: () {
                ToasterService.showInfo(context, 'Email verification feature coming soon');
              },
            ),
            _buildSettingsTile(
              icon: Icons.phone,
              title: 'Phone Binding',
              subtitle: 'Link your phone number',
              onTap: () {
                ToasterService.showInfo(context, 'Phone binding feature coming soon');
              },
            ),
            _buildSettingsTile(
              icon: Icons.security,
              title: 'Two-Factor Authentication',
              subtitle: 'Add an extra layer of security',
              onTap: () {
                ToasterService.showInfo(context, '2FA feature coming soon');
              },
            ),
            const SizedBox(height: 24),

            // Active Sessions
            _buildSectionHeader('Active Sessions'),
            sessionsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: Color(0xFF4ECDC4)),
                ),
              ),
              error: (error, stack) => Card(
                color: const Color(0xFF1D1E33),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Failed to load sessions: $error',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
              data: (sessions) {
                if (sessions.isEmpty) {
                  return Card(
                    color: const Color(0xFF1D1E33),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: const Text(
                        'No active sessions',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  );
                }

                return Column(
                  children: sessions.map((session) {
                    return Card(
                      color: const Color(0xFF1D1E33),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.devices, color: Color(0xFF4ECDC4)),
                        title: Text(
                          session['deviceInfo']?['platform'] ?? 'Unknown Device',
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          'Last active: ${_formatDate(session['lastActive'])}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            final sessionId = session['_id'] ?? session['id'];
                            if (sessionId != null) {
                              final result = await ref.read(sessionsProvider.notifier).deleteSession(sessionId);
                              if (mounted) {
                                if (result['success'] == true) {
                                  ToasterService.showSuccess(context, 'Session deleted');
                                } else {
                                  ToasterService.showError(context, result['message'] ?? 'Failed to delete session');
                                }
                              }
                            }
                          },
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 24),

            // Danger Zone
            _buildSectionHeader('Danger Zone'),
            ref.watch(deleteAccountProvider).when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(color: Color(0xFF4ECDC4)),
                    ),
                  ),
                  error: (_, __) => ElevatedButton.icon(
                    onPressed: _deleteAccount,
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Delete Account'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  data: (_) => ElevatedButton.icon(
                    onPressed: _deleteAccount,
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Delete Account'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
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

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';
    try {
      final dateTime = date is DateTime ? date : DateTime.parse(date.toString());
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return 'Unknown';
    }
  }
}

