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
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
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
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4ECDC4).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_add,
                    size: 40,
                    color: Color(0xFF4ECDC4),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Join to $featureName',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  customMessage ??
                      'Create an account or sign in to unlock this feature and connect with the community.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Login form embedded
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: const _EmbeddedLoginForm(),
            ),
          ),

          // Cancel button
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Maybe later',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Embedded login form for the modal
class _EmbeddedLoginForm extends StatefulWidget {
  const _EmbeddedLoginForm();

  @override
  State<_EmbeddedLoginForm> createState() => _EmbeddedLoginFormState();
}

class _EmbeddedLoginFormState extends State<_EmbeddedLoginForm> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError('Please fill in all fields');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await TokenAuthService.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (result.success) {
        if (mounted) {
          Navigator.of(context).pop(true); // Return success
        }
      } else {
        _showError(result.message);
      }
    } catch (e) {
      _showError('Login failed: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      final result = await TokenAuthService.signInWithGoogle();
      if (result.success) {
        if (mounted) {
          Navigator.of(context).pop(true); // Return success
        }
      } else {
        _showError(result.message);
      }
    } catch (e) {
      _showError('Google sign-in failed: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Email field
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 16),

          // Password field
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Login button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4ECDC4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child:
                  _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                        'Sign In',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
            ),
          ),
          const SizedBox(height: 16),

          // Divider
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey[300])),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('or', style: TextStyle(color: Colors.grey[600])),
              ),
              Expanded(child: Divider(color: Colors.grey[300])),
            ],
          ),
          const SizedBox(height: 16),

          // Google sign-in button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _handleGoogleSignIn,
              icon: const Icon(Icons.g_mobiledata, size: 24),
              label: const Text('Continue with Google'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Sign up link
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF4ECDC4).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Text(
                  'New here?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Join thousands of users sharing amazing content',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                    // Navigate to register screen - implementation depends on your routing
                    // Navigator.of(context).pushNamed('/register');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4ECDC4),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Create Account',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
