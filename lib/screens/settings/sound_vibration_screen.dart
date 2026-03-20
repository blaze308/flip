import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/custom_toaster.dart';

const String _soundKey = 'notification_sound';
const String _vibrationKey = 'notification_vibration';

/// Sound and Vibration Settings Screen
/// Local preferences for notification sound and vibration
class SoundVibrationScreen extends StatefulWidget {
  const SoundVibrationScreen({super.key});

  @override
  State<SoundVibrationScreen> createState() => _SoundVibrationScreenState();
}

class _SoundVibrationScreenState extends State<SoundVibrationScreen> {
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _soundEnabled = prefs.getBool(_soundKey) ?? true;
      _vibrationEnabled = prefs.getBool(_vibrationKey) ?? true;
      _loading = false;
    });
  }

  Future<void> _setSound(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundKey, value);
    setState(() => _soundEnabled = value);
    if (mounted) {
      ToasterService.showSuccess(context, 'Sound ${value ? "on" : "off"}');
    }
  }

  Future<void> _setVibration(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_vibrationKey, value);
    setState(() => _vibrationEnabled = value);
    if (mounted) {
      if (value) {
        HapticFeedback.mediumImpact();
      }
      ToasterService.showSuccess(context, 'Vibration ${value ? "on" : "off"}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text('Sound & Vibration', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1D1E33),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4ECDC4)),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: const Color(0xFF1D1E33),
                  child: SwitchListTile(
                    value: _soundEnabled,
                    onChanged: _setSound,
                    title: const Text('Notification Sound', style: TextStyle(color: Colors.white)),
                    subtitle: const Text(
                      'Play sound for notifications',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    activeColor: const Color(0xFF4ECDC4),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  color: const Color(0xFF1D1E33),
                  child: SwitchListTile(
                    value: _vibrationEnabled,
                    onChanged: _setVibration,
                    title: const Text('Vibration', style: TextStyle(color: Colors.white)),
                    subtitle: const Text(
                      'Vibrate for notifications',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    activeColor: const Color(0xFF4ECDC4),
                  ),
                ),
              ],
            ),
    );
  }
}
