import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math';
import 'dart:developer' as developer;

import 'providers/auth_provider.dart';
import 'services/storage_service.dart';
import 'splash_screen.dart';
import 'onboarding_screen.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class AppRouter extends ConsumerStatefulWidget {
  const AppRouter({super.key});

  @override
  ConsumerState<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends ConsumerState<AppRouter> {
  @override
  Widget build(BuildContext context) {
    final authData = ref.watch(authProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _buildCurrentScreen(authData),
    );
  }

  Widget _buildCurrentScreen(AuthData authData) {
    switch (authData.state) {
      case AuthState.initial:
      case AuthState.loading:
        return const SplashScreen();

      case AuthState.authenticated:
        return const HomeScreen();

      case AuthState.unauthenticated:
        if (authData.shouldShowOnboarding) {
          return _buildOnboardingFlow();
        } else {
          return const LoginScreen();
        }

      case AuthState.error:
        return _buildErrorScreen(authData.errorMessage);
    }
  }

  Widget _buildOnboardingFlow() {
    // Use the original onboarding screen instead of the new flow
    return const OnboardingScreen();
  }

  Widget _buildErrorScreen(String? errorMessage) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C3E50),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage ?? 'Unknown error occurred',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                ref.read(authProvider.notifier).clearError();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4ECDC4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleOnboardingSkip() async {
    try {
      // Increment onboarding view count
      await StorageService.incrementOnboardingViewCount();

      // Get current count
      final viewCount = await StorageService.getOnboardingViewCount();

      // Random chance to show onboarding again (3-5 times total)
      final random = Random();
      final maxViews = 3 + random.nextInt(3); // 3-5 views

      if (viewCount >= maxViews) {
        // Mark as completed after random number of views
        await StorageService.setOnboardingCompleted(true);
        developer.log(
          'Onboarding completed after $viewCount views',
          name: 'AppRouter',
        );
      }

      // Navigate to login
      ref.read(authProvider.notifier).clearError();
    } catch (e) {
      developer.log('Error handling onboarding skip: $e', name: 'AppRouter');
    }
  }
}
