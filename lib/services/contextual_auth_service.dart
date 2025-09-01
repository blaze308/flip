import 'package:flutter/material.dart';
import 'token_auth_service.dart';

/// Service for contextual authentication - checks auth only when needed for specific features
/// Follows TikTok/Instagram pattern where auth is feature-gated, not route-gated
class ContextualAuthService {
  /// Check if user is authenticated for a protected feature
  /// Shows login modal if not authenticated
  /// Returns true if authenticated, false if user cancelled login
  static Future<bool> requireAuthForFeature(
    BuildContext context, {
    required String featureName,
    String? customMessage,
  }) async {
    // If already authenticated, allow access
    if (TokenAuthService.isAuthenticated) {
      return true;
    }

    // Show contextual login prompt
    return await _showLoginPrompt(
      context,
      featureName: featureName,
      customMessage: customMessage,
    );
  }

  /// Show login prompt with context about why login is needed
  static Future<bool> _showLoginPrompt(
    BuildContext context, {
    required String featureName,
    String? customMessage,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder:
          (context) => _LoginPromptModal(
            featureName: featureName,
            customMessage: customMessage,
          ),
    );

    return result ?? false;
  }

  /// Show a simple error message for failed actions
  static void showActionError(
    BuildContext context, {
    required String action,
    required String error,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Failed to $action',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(error, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[600],
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Show success message for completed actions
  static void showActionSuccess(
    BuildContext context, {
    required String message,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              message,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ],
        ),
        backgroundColor: Colors.green[600],
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Quick auth checks for specific features
  static Future<bool> canPost(BuildContext context) async {
    return await requireAuthForFeature(
      context,
      featureName: 'share your content',
      customMessage:
          'Join our community to share your moments, thoughts, and creativity with others. Your voice matters!',
    );
  }

  static Future<bool> canLike(BuildContext context) async {
    return await requireAuthForFeature(
      context,
      featureName: 'like posts',
      customMessage:
          'Create an account to show love for posts you enjoy and help creators know what resonates with you.',
    );
  }

  static Future<bool> canComment(BuildContext context) async {
    return await requireAuthForFeature(
      context,
      featureName: 'join conversations',
      customMessage:
          'Sign up to share your thoughts, ask questions, and connect with others through meaningful discussions.',
    );
  }

  static Future<bool> canFollow(BuildContext context) async {
    return await requireAuthForFeature(
      context,
      featureName: 'follow creators',
      customMessage:
          'Create your account to follow amazing creators and never miss their latest content in your personalized feed.',
    );
  }

  static Future<bool> canAccessProfile(BuildContext context) async {
    return await requireAuthForFeature(
      context,
      featureName: 'access your profile',
      customMessage:
          'Sign in to customize your profile, track your activity, and manage your account settings.',
    );
  }

  static Future<bool> canHidePosts(BuildContext context) async {
    return await requireAuthForFeature(
      context,
      featureName: 'hide posts',
      customMessage:
          'Sign in to customize your feed by hiding posts you don\'t want to see. Take control of your experience.',
    );
  }

  static Future<bool> canBookmarkPosts(BuildContext context) async {
    return await requireAuthForFeature(
      context,
      featureName: 'bookmark posts',
      customMessage:
          'Sign in to save posts you want to revisit later. Build your personal collection of favorite content.',
    );
  }

  /// Check if user can perform action without showing prompt
  /// Useful for UI state (showing/hiding buttons)
  static bool canPerformAction() {
    return TokenAuthService.isAuthenticated;
  }
}

/// Modal that shows login prompt with context
class _LoginPromptModal extends StatelessWidget {
  final String featureName;
  final String? customMessage;

  const _LoginPromptModal({required this.featureName, this.customMessage});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF4ECDC4).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_outline,
              color: Color(0xFF4ECDC4),
              size: 32,
            ),
          ),

          const SizedBox(height: 20),

          // Title
          const Text(
            'Sign in required',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 12),

          // Message
          const Text(
            'You have to be signed in to perform this action',
            style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.4),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // Buttons
          Row(
            children: [
              // Cancel button
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Colors.grey),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Login button
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(false); // Close modal first
                    Navigator.of(
                      context,
                    ).pushNamed('/login'); // Navigate to login screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4ECDC4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Login',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
