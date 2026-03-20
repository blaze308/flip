import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_providers.dart';
import '../../widgets/custom_toaster.dart';

/// Privacy Settings Screen
/// Manage profile visibility, messaging, calls, and invisible mode
class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends ConsumerState<PrivacySettingsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(privacySettingsProvider.notifier).loadFromBackend());
  }

  @override
  Widget build(BuildContext context) {
    final privacyAsync = ref.watch(privacySettingsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          'Privacy Settings',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1D1E33),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: privacyAsync.when(
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
            ],
          ),
        ),
        data: (settings) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile Visibility
                _buildSectionHeader('Profile'),
                Card(
                  color: const Color(0xFF1D1E33),
                  child: SwitchListTile(
                    value: settings['profileVisible'] ?? true,
                    onChanged: (value) async {
                      final result = await ref.read(privacySettingsProvider.notifier).updatePrivacy(
                            profileVisible: value,
                          );

                      if (mounted) {
                        if (result['success'] == true) {
                          ToasterService.showSuccess(context, 'Privacy settings updated');
                        } else {
                          ToasterService.showError(context, result['message'] ?? 'Failed to update');
                        }
                      }
                    },
                    title: const Text('Profile Visible', style: TextStyle(color: Colors.white)),
                    subtitle: const Text(
                      'Allow others to view your profile',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    activeColor: const Color(0xFF4ECDC4),
                  ),
                ),
                Card(
                  color: const Color(0xFF1D1E33),
                  child: SwitchListTile(
                    value: settings['showEmail'] ?? false,
                    onChanged: (value) async {
                      final result = await ref.read(privacySettingsProvider.notifier).updatePrivacy(
                            showEmail: value,
                          );

                      if (mounted) {
                        if (result['success'] == true) {
                          ToasterService.showSuccess(context, 'Privacy settings updated');
                        } else {
                          ToasterService.showError(context, result['message'] ?? 'Failed to update');
                        }
                      }
                    },
                    title: const Text('Show Email', style: TextStyle(color: Colors.white)),
                    subtitle: const Text(
                      'Display email on your profile',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    activeColor: const Color(0xFF4ECDC4),
                  ),
                ),
                Card(
                  color: const Color(0xFF1D1E33),
                  child: SwitchListTile(
                    value: settings['showPhone'] ?? false,
                    onChanged: (value) async {
                      final result = await ref.read(privacySettingsProvider.notifier).updatePrivacy(
                            showPhone: value,
                          );

                      if (mounted) {
                        if (result['success'] == true) {
                          ToasterService.showSuccess(context, 'Privacy settings updated');
                        } else {
                          ToasterService.showError(context, result['message'] ?? 'Failed to update');
                        }
                      }
                    },
                    title: const Text('Show Phone', style: TextStyle(color: Colors.white)),
                    subtitle: const Text(
                      'Display phone number on your profile',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    activeColor: const Color(0xFF4ECDC4),
                  ),
                ),
                const SizedBox(height: 24),

                // Communication
                _buildSectionHeader('Communication'),
                _buildWhoCanTile(
                  icon: Icons.message,
                  title: 'Who Can Message Me',
                  value: settings['messageWhoCan'] ?? 'everyone',
                  options: const [
                    ('everyone', 'Everyone'),
                    ('followers', 'Followers only'),
                    ('friends', 'Friends only'),
                    ('nobody', 'Nobody'),
                  ],
                  onSelect: (value) async {
                    final result = await ref.read(privacySettingsProvider.notifier).updatePrivacy(
                          messageWhoCan: value,
                        );
                    if (mounted) {
                      if (result['success'] == true) {
                        ToasterService.showSuccess(context, 'Message privacy updated');
                      } else {
                        ToasterService.showError(context, result['message'] ?? 'Failed');
                      }
                    }
                  },
                ),
                _buildWhoCanTile(
                  icon: Icons.call,
                  title: 'Who Can Call Me',
                  value: settings['callWhoCan'] ?? 'everyone',
                  options: const [
                    ('everyone', 'Everyone'),
                    ('followers', 'Followers only'),
                    ('friends', 'Friends only'),
                    ('nobody', 'Nobody'),
                  ],
                  onSelect: (value) async {
                    final result = await ref.read(privacySettingsProvider.notifier).updatePrivacy(
                          callWhoCan: value,
                        );
                    if (mounted) {
                      if (result['success'] == true) {
                        ToasterService.showSuccess(context, 'Call privacy updated');
                      } else {
                        ToasterService.showError(context, result['message'] ?? 'Failed');
                      }
                    }
                  },
                ),
                const SizedBox(height: 24),

                // Invisible Mode
                _buildSectionHeader('Visibility'),
                Card(
                  color: const Color(0xFF1D1E33),
                  child: SwitchListTile(
                    value: settings['invisibleMode'] == true,
                    onChanged: (value) async {
                      final result = await ref.read(privacySettingsProvider.notifier).updatePrivacy(
                            invisibleMode: value,
                          );
                      if (mounted) {
                        if (result['success'] == true) {
                          ToasterService.showSuccess(context, 'Invisible mode ${value ? "on" : "off"}');
                        } else {
                          ToasterService.showError(context, result['message'] ?? 'Failed');
                        }
                      }
                    },
                    title: const Text('Invisible Mode', style: TextStyle(color: Colors.white)),
                    subtitle: const Text(
                      'Hide your online status from others',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    activeColor: const Color(0xFF4ECDC4),
                  ),
                ),
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

  Widget _buildWhoCanTile({
    required IconData icon,
    required String title,
    required String value,
    required List<(String, String)> options,
    required Future<void> Function(String) onSelect,
  }) {
    final label = options.firstWhere(
      (o) => o.$1 == value,
      orElse: () => options.first,
    ).$2;
    return Card(
      color: const Color(0xFF1D1E33),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF4ECDC4)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        subtitle: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
        onTap: () async {
          final selected = await showModalBottomSheet<String>(
            context: context,
            backgroundColor: const Color(0xFF1D1E33),
            builder: (ctx) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: options.map((o) => ListTile(
                  title: Text(o.$2, style: const TextStyle(color: Colors.white)),
                  onTap: () => Navigator.pop(ctx, o.$1),
                )).toList(),
              ),
            ),
          );
          if (selected != null) await onSelect(selected);
        },
      ),
    );
  }
}

