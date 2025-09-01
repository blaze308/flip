import 'package:flutter/material.dart';
import '../services/contextual_auth_service.dart';

/// A wrapper widget that handles authentication for protected actions
/// Usage: Wrap any widget that requires auth with this component
class AuthRequiredWrapper extends StatelessWidget {
  final Widget child;
  final String featureName;
  final String? customMessage;
  final VoidCallback onAuthSuccess;
  final VoidCallback? onAuthFailed;
  final bool showAuthPrompt;

  const AuthRequiredWrapper({
    super.key,
    required this.child,
    required this.featureName,
    required this.onAuthSuccess,
    this.customMessage,
    this.onAuthFailed,
    this.showAuthPrompt = true,
  });

  Future<void> _handleTap(BuildContext context) async {
    // Check if user is already authenticated
    if (ContextualAuthService.canPerformAction()) {
      onAuthSuccess();
      return;
    }

    // Show auth prompt if enabled
    if (showAuthPrompt) {
      final canProceed = await ContextualAuthService.requireAuthForFeature(
        context,
        featureName: featureName,
        customMessage: customMessage,
      );

      if (canProceed) {
        onAuthSuccess();
      } else {
        onAuthFailed?.call();
      }
    } else {
      onAuthFailed?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: () => _handleTap(context), child: child);
  }
}

/// A specialized button that requires authentication
class AuthRequiredButton extends StatefulWidget {
  final String text;
  final IconData? icon;
  final String featureName;
  final String? customMessage;
  final VoidCallback onAuthSuccess;
  final VoidCallback? onAuthFailed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool isLoading;

  const AuthRequiredButton({
    super.key,
    required this.text,
    required this.featureName,
    required this.onAuthSuccess,
    this.icon,
    this.customMessage,
    this.onAuthFailed,
    this.backgroundColor,
    this.foregroundColor,
    this.isLoading = false,
  });

  @override
  State<AuthRequiredButton> createState() => _AuthRequiredButtonState();
}

class _AuthRequiredButtonState extends State<AuthRequiredButton> {
  bool _isProcessing = false;

  Future<void> _handlePress() async {
    if (_isProcessing || widget.isLoading) return;

    setState(() => _isProcessing = true);

    try {
      // Check if user is already authenticated
      if (ContextualAuthService.canPerformAction()) {
        widget.onAuthSuccess();
        return;
      }

      // Show auth prompt
      final canProceed = await ContextualAuthService.requireAuthForFeature(
        context,
        featureName: widget.featureName,
        customMessage: widget.customMessage,
      );

      if (canProceed) {
        widget.onAuthSuccess();
      } else {
        widget.onAuthFailed?.call();
      }
    } catch (e) {
      ContextualAuthService.showActionError(
        context,
        action: widget.featureName,
        error: e.toString(),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = _isProcessing || widget.isLoading;

    return ElevatedButton.icon(
      onPressed: isLoading ? null : _handlePress,
      icon:
          isLoading
              ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
              : (widget.icon != null
                  ? Icon(widget.icon)
                  : const SizedBox.shrink()),
      label: Text(widget.text),
      style: ElevatedButton.styleFrom(
        backgroundColor: widget.backgroundColor ?? const Color(0xFF4ECDC4),
        foregroundColor: widget.foregroundColor ?? Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// A floating action button that requires authentication
class AuthRequiredFAB extends StatelessWidget {
  final IconData icon;
  final String featureName;
  final String? customMessage;
  final VoidCallback onAuthSuccess;
  final VoidCallback? onAuthFailed;
  final Color? backgroundColor;

  const AuthRequiredFAB({
    super.key,
    required this.icon,
    required this.featureName,
    required this.onAuthSuccess,
    this.customMessage,
    this.onAuthFailed,
    this.backgroundColor,
  });

  Future<void> _handlePress(BuildContext context) async {
    try {
      // Check if user is already authenticated
      if (ContextualAuthService.canPerformAction()) {
        onAuthSuccess();
        return;
      }

      // Show auth prompt
      final canProceed = await ContextualAuthService.requireAuthForFeature(
        context,
        featureName: featureName,
        customMessage: customMessage,
      );

      if (canProceed) {
        onAuthSuccess();
      } else {
        onAuthFailed?.call();
      }
    } catch (e) {
      ContextualAuthService.showActionError(
        context,
        action: featureName,
        error: e.toString(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _handlePress(context),
      backgroundColor: backgroundColor ?? const Color(0xFF4ECDC4),
      child: Icon(icon, color: Colors.white),
    );
  }
}

/// Example usage widgets
class ExampleUsage extends StatelessWidget {
  const ExampleUsage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Example 1: Wrap any widget with auth requirement
        AuthRequiredWrapper(
          featureName: 'like posts',
          customMessage: 'Sign up to show love for amazing content!',
          onAuthSuccess: () {
            // Handle like action
            print('User authenticated - performing like action');
          },
          child: const Icon(Icons.favorite_border),
        ),

        const SizedBox(height: 16),

        // Example 2: Auth-required button
        AuthRequiredButton(
          text: 'Follow User',
          icon: Icons.person_add,
          featureName: 'follow creators',
          onAuthSuccess: () {
            // Handle follow action
            print('User authenticated - following user');
          },
        ),

        const SizedBox(height: 16),

        // Example 3: Auth-required FAB
        AuthRequiredFAB(
          icon: Icons.add,
          featureName: 'create posts',
          onAuthSuccess: () {
            // Navigate to create post
            Navigator.of(context).pushNamed('/create-post');
          },
        ),
      ],
    );
  }
}
