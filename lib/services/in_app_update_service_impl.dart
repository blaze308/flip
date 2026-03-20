import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

/// Android implementation of In-App Updates via Google Play Core.
/// See: https://pub.dev/packages/in_app_update
class InAppUpdateService {
  InAppUpdateService._();
  static final InAppUpdateService _instance = InAppUpdateService._();
  static InAppUpdateService get instance => _instance;

  bool _isChecking = false;
  bool _flexibleUpdateReady = false;

  bool get isSupported {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  bool get isFlexibleUpdateReady => _flexibleUpdateReady;

  void _showUpdateReadyModal(BuildContext context) {
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1D1E33),
        title: Row(
          children: [
            Icon(Icons.download_done, color: const Color(0xFF4ECDC4)),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Update ready',
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
          ],
        ),
        content: const Text(
          'The update has been downloaded. Install now to use the latest version. The app will restart after installing.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              completeFlexibleUpdate(context);
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4ECDC4)),
            child: const Text('Install'),
          ),
        ],
      ),
    );
  }

  Future<void> checkForUpdate(BuildContext context) async {
    if (!isSupported || _isChecking) return;
    _isChecking = true;

    void showErrorModal(String message) {
      if (!context.mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1D1E33),
          title: const Text('Update failed', style: TextStyle(color: Colors.white)),
          content: Text(message, style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }

    try {
      final info = await InAppUpdate.checkForUpdate();
      if (!context.mounted) return;

      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        _isChecking = false;
        return;
      }

      // Show "An update is available" first; start download/update only if user taps Update
      if (info.flexibleUpdateAllowed) {
        if (!context.mounted) return;
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1D1E33),
            title: Row(
              children: [
                Icon(Icons.system_update, color: const Color(0xFF4ECDC4)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'An update is available',
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                ),
              ],
            ),
            content: const Text(
              'A new version of the app is available. You can keep using the app while the update downloads in the background.',
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Later'),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await InAppUpdate.startFlexibleUpdate();
                  if (!context.mounted) return;
                  _flexibleUpdateReady = true;
                  _showUpdateReadyModal(context);
                },
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4ECDC4)),
                child: const Text('Update'),
              ),
            ],
          ),
        );
        return;
      }

      if (info.immediateUpdateAllowed) {
        if (!context.mounted) return;
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1D1E33),
            title: Row(
              children: [
                Icon(Icons.system_update, color: const Color(0xFF4ECDC4)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'An update is available',
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                ),
              ],
            ),
            content: const Text(
              'A new version of the app is available. You need to update to continue using the app.',
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  InAppUpdate.performImmediateUpdate();
                },
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4ECDC4)),
                child: const Text('Update'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        final msg = e.toString();
        if (!msg.contains('API_NOT_AVAILABLE') && !msg.contains('not implemented')) {
          showErrorModal('Update check failed: $msg');
        }
      }
    } finally {
      _isChecking = false;
    }
  }

  Future<void> completeFlexibleUpdate(BuildContext context) async {
    if (!_flexibleUpdateReady || !isSupported) return;

    void showModal(String title, String message, {bool isError = false}) {
      if (!context.mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1D1E33),
          title: Text(
            title,
            style: TextStyle(color: isError ? Colors.red.shade300 : Colors.white),
          ),
          content: Text(message, style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }

    try {
      await InAppUpdate.completeFlexibleUpdate();
      if (context.mounted) {
        showModal('Update', 'App will restart to complete the update.');
      }
      _flexibleUpdateReady = false;
    } catch (e) {
      if (context.mounted) showModal('Install failed', e.toString(), isError: true);
    }
  }
}
