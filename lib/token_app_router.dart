import 'package:flutter/material.dart';

import 'services/token_auth_service.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/home_screen.dart';

/// Simple app router that follows TikTok/Instagram pattern
/// Always routes to homepage after onboarding, no auth-based routing
class TokenAppRouter extends StatefulWidget {
  const TokenAppRouter({super.key});

  @override
  State<TokenAppRouter> createState() => _TokenAppRouterState();
}

class _TokenAppRouterState extends State<TokenAppRouter> {
  bool _showOnboarding = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    print('🚀 TokenAppRouter: Initializing authentication service...');

    // Initialize authentication service first
    await TokenAuthService.initialize();

    print(
      '🚀 TokenAppRouter: Auth initialized. Checking authentication state...',
    );
    print('   - Is Authenticated: ${TokenAuthService.isAuthenticated}');
    print(
      '   - Current User: ${TokenAuthService.currentUser?.displayName ?? 'None'}',
    );

    // Then check if we should show onboarding
    final shouldShowOnboarding = await TokenAuthService.shouldShowOnboarding();
    print('🚀 TokenAppRouter: Should show onboarding: $shouldShowOnboarding');

    if (mounted) {
      setState(() {
        _showOnboarding = shouldShowOnboarding;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SplashScreen();
    }

    // Simple routing: Onboarding → Homepage (always)
    return _showOnboarding ? const OnboardingScreen() : const HomeScreen();
  }

  /// Called when onboarding is completed (skip or finish)
  void completeOnboarding() {
    if (mounted) {
      setState(() {
        _showOnboarding = false;
      });
    }
  }
}
