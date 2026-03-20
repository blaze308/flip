import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/custom_toaster.dart';

/// Theme Settings Screen
/// Choose app theme: System, Light, or Dark
class ThemeSettingsScreen extends ConsumerStatefulWidget {
  const ThemeSettingsScreen({super.key});

  @override
  ConsumerState<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends ConsumerState<ThemeSettingsScreen> {
  String _selectedTheme = 'system';

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(themeProvider.notifier).load());
  }

  String _themeFromMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      default:
        return 'system';
    }
  }

  Future<void> _setTheme(String theme) async {
    await ref.read(themeProvider.notifier).setTheme(theme);
    if (mounted) {
      setState(() => _selectedTheme = theme);
      ToasterService.showSuccess(context, 'Theme updated');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = ref.watch(themeProvider);
    if (themeNotifier.loaded) {
      _selectedTheme = _themeFromMode(themeNotifier.mode);
    }
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text('Theme', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1D1E33),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        children: [
          _buildThemeOption(
            value: 'system',
            title: 'System',
            subtitle: 'Follow device theme',
            icon: Icons.phone_android,
          ),
          _buildThemeOption(
            value: 'light',
            title: 'Light',
            subtitle: 'Light mode',
            icon: Icons.light_mode,
          ),
          _buildThemeOption(
            value: 'dark',
            title: 'Dark',
            subtitle: 'Dark mode',
            icon: Icons.dark_mode,
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedTheme == value;
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF4ECDC4)),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: Color(0xFF4ECDC4))
          : null,
      onTap: () => _setTheme(value),
    );
  }
}
