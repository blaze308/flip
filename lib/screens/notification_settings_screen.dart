import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_providers.dart';
import '../widgets/custom_toaster.dart';

/// Notification Settings Screen
/// Manage push, in-app, sound, and vibration settings
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationSettingsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          'Notification Settings',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1D1E33),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: notificationsAsync.when(
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
                // Notification Types
                _buildSectionHeader('Notification Types'),
                Card(
                  color: const Color(0xFF1D1E33),
                  child: SwitchListTile(
                    value: settings['push'] ?? true,
                    onChanged: (value) async {
                      final result = await ref.read(notificationSettingsProvider.notifier).updateNotifications(
                            push: value,
                          );

                      if (mounted) {
                        if (result['success'] == true) {
                          ToasterService.showSuccess(context, 'Notification settings updated');
                        } else {
                          ToasterService.showError(context, result['message'] ?? 'Failed to update');
                        }
                      }
                    },
                    title: const Text('Push Notifications', style: TextStyle(color: Colors.white)),
                    subtitle: const Text(
                      'Receive push notifications',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    activeColor: const Color(0xFF4ECDC4),
                  ),
                ),
                Card(
                  color: const Color(0xFF1D1E33),
                  child: SwitchListTile(
                    value: settings['email'] ?? true,
                    onChanged: (value) async {
                      final result = await ref.read(notificationSettingsProvider.notifier).updateNotifications(
                            email: value,
                          );

                      if (mounted) {
                        if (result['success'] == true) {
                          ToasterService.showSuccess(context, 'Notification settings updated');
                        } else {
                          ToasterService.showError(context, result['message'] ?? 'Failed to update');
                        }
                      }
                    },
                    title: const Text('Email Notifications', style: TextStyle(color: Colors.white)),
                    subtitle: const Text(
                      'Receive email notifications',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    activeColor: const Color(0xFF4ECDC4),
                  ),
                ),
                Card(
                  color: const Color(0xFF1D1E33),
                  child: SwitchListTile(
                    value: settings['sms'] ?? false,
                    onChanged: (value) async {
                      final result = await ref.read(notificationSettingsProvider.notifier).updateNotifications(
                            sms: value,
                          );

                      if (mounted) {
                        if (result['success'] == true) {
                          ToasterService.showSuccess(context, 'Notification settings updated');
                        } else {
                          ToasterService.showError(context, result['message'] ?? 'Failed to update');
                        }
                      }
                    },
                    title: const Text('SMS Notifications', style: TextStyle(color: Colors.white)),
                    subtitle: const Text(
                      'Receive SMS notifications',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    activeColor: const Color(0xFF4ECDC4),
                  ),
                ),
                const SizedBox(height: 24),

                // Sound & Vibration
                _buildSectionHeader('Sound & Vibration'),
                _buildSettingsTile(
                  icon: Icons.volume_up,
                  title: 'Sound Settings',
                  subtitle: 'Manage notification sounds',
                  onTap: () {
                    ToasterService.showInfo(context, 'Sound settings feature coming soon');
                  },
                ),
                _buildSettingsTile(
                  icon: Icons.vibration,
                  title: 'Vibration Settings',
                  subtitle: 'Manage vibration patterns',
                  onTap: () {
                    ToasterService.showInfo(context, 'Vibration settings feature coming soon');
                  },
                ),
                const SizedBox(height: 24),

                // In-App Notifications
                _buildSectionHeader('In-App'),
                _buildSettingsTile(
                  icon: Icons.notifications_active,
                  title: 'In-App Notifications',
                  subtitle: 'Show notifications while using the app',
                  onTap: () {
                    ToasterService.showInfo(context, 'In-app notifications feature coming soon');
                  },
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
}

