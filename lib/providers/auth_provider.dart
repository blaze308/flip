import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;

import '../models/user_model.dart';
import '../services/user_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/storage_service.dart';

// Auth state enum
enum AuthState { initial, loading, authenticated, unauthenticated, error }

// Auth data class
class AuthData {
  final AuthState state;
  final UserModel? user;
  final User? firebaseUser;
  final String? errorMessage;
  final bool rememberMe;
  final bool shouldShowOnboarding;

  const AuthData({
    required this.state,
    this.user,
    this.firebaseUser,
    this.errorMessage,
    this.rememberMe = false,
    this.shouldShowOnboarding = false,
  });

  AuthData copyWith({
    AuthState? state,
    UserModel? user,
    User? firebaseUser,
    String? errorMessage,
    bool? rememberMe,
    bool? shouldShowOnboarding,
  }) {
    return AuthData(
      state: state ?? this.state,
      user: user ?? this.user,
      firebaseUser: firebaseUser ?? this.firebaseUser,
      errorMessage: errorMessage ?? this.errorMessage,
      rememberMe: rememberMe ?? this.rememberMe,
      shouldShowOnboarding: shouldShowOnboarding ?? this.shouldShowOnboarding,
    );
  }

  bool get isAuthenticated => state == AuthState.authenticated && user != null;
  bool get isLoading => state == AuthState.loading;
  bool get hasError => state == AuthState.error;
}

// Auth provider
class AuthNotifier extends StateNotifier<AuthData> {
  AuthNotifier() : super(const AuthData(state: AuthState.initial)) {
    _initialize();
  }

  // Initialize auth state
  Future<void> _initialize() async {
    try {
      state = state.copyWith(state: AuthState.loading);

      // Ensure splash screen shows for at least 2 seconds
      final stopwatch = Stopwatch()..start();
      const minSplashDuration = Duration(seconds: 2);

      // Check if user is already signed in
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        // Initialize user service
        await UserService.initializeUser();
        final currentUser = UserService.currentUser;

        if (currentUser != null) {
          // Check remember me preference
          final rememberMe = await StorageService.getRememberMe();

          // Wait for minimum splash duration
          final elapsed = stopwatch.elapsed;
          if (elapsed < minSplashDuration) {
            await Future.delayed(minSplashDuration - elapsed);
          }

          state = state.copyWith(
            state: AuthState.authenticated,
            user: currentUser,
            firebaseUser: firebaseUser,
            rememberMe: rememberMe,
          );

          developer.log(
            'User auto-signed in: ${currentUser.username}',
            name: 'AuthProvider',
          );
          return;
        }
      }

      // Check if should show onboarding
      final shouldShowOnboarding = await _shouldShowOnboarding();

      // Wait for minimum splash duration
      final elapsed = stopwatch.elapsed;
      if (elapsed < minSplashDuration) {
        await Future.delayed(minSplashDuration - elapsed);
      }

      state = state.copyWith(
        state: AuthState.unauthenticated,
        shouldShowOnboarding: shouldShowOnboarding,
      );
    } catch (e) {
      developer.log('Auth initialization error: $e', name: 'AuthProvider');

      state = state.copyWith(
        state: AuthState.error,
        errorMessage: e.toString(),
      );
    }
  }

  // Sign in with email and password
  Future<bool> signInWithEmailAndPassword({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    try {
      state = state.copyWith(state: AuthState.loading);

      final result = await FirebaseAuthService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.success && result.user != null) {
        // Get user model
        await UserService.initializeUser();
        final currentUser = UserService.currentUser;

        if (currentUser != null) {
          // Save remember me preference
          await StorageService.setRememberMe(rememberMe);

          state = state.copyWith(
            state: AuthState.authenticated,
            user: currentUser,
            firebaseUser: result.user,
            rememberMe: rememberMe,
            errorMessage: null,
          );

          developer.log(
            'User signed in: ${currentUser.username}',
            name: 'AuthProvider',
          );
          return true;
        }
      }

      state = state.copyWith(
        state: AuthState.error,
        errorMessage: result.message,
      );
      return false;
    } catch (e) {
      developer.log('Sign in error: $e', name: 'AuthProvider');
      state = state.copyWith(
        state: AuthState.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  // Register with email and password
  Future<bool> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
    bool rememberMe = false,
  }) async {
    try {
      state = state.copyWith(state: AuthState.loading);

      final result = await FirebaseAuthService.registerWithEmailAndPassword(
        email: email,
        password: password,
        fullName: fullName,
      );

      if (result.success && result.user != null) {
        // Get user model
        await UserService.initializeUser();
        final currentUser = UserService.currentUser;

        if (currentUser != null) {
          // Save remember me preference
          await StorageService.setRememberMe(rememberMe);

          // Mark that user has seen onboarding (since they just registered)
          await _markOnboardingCompleted();

          state = state.copyWith(
            state: AuthState.authenticated,
            user: currentUser,
            firebaseUser: result.user,
            rememberMe: rememberMe,
            errorMessage: null,
          );

          developer.log(
            'User registered: ${currentUser.username}',
            name: 'AuthProvider',
          );
          return true;
        }
      }

      state = state.copyWith(
        state: AuthState.error,
        errorMessage: result.message,
      );
      return false;
    } catch (e) {
      developer.log('Registration error: $e', name: 'AuthProvider');
      state = state.copyWith(
        state: AuthState.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  // Sign in with Google
  Future<bool> signInWithGoogle({bool rememberMe = false}) async {
    try {
      state = state.copyWith(state: AuthState.loading);

      final result = await FirebaseAuthService.signInWithGoogle();

      if (result.success && result.user != null) {
        await UserService.initializeUser();
        final currentUser = UserService.currentUser;

        if (currentUser != null) {
          await StorageService.setRememberMe(rememberMe);
          await _markOnboardingCompleted();

          state = state.copyWith(
            state: AuthState.authenticated,
            user: currentUser,
            firebaseUser: result.user,
            rememberMe: rememberMe,
            errorMessage: null,
          );
          return true;
        }
      }

      state = state.copyWith(
        state: AuthState.error,
        errorMessage: result.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        state: AuthState.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  // Sign in with Apple
  Future<bool> signInWithApple({bool rememberMe = false}) async {
    try {
      state = state.copyWith(state: AuthState.loading);

      final result = await FirebaseAuthService.signInWithApple();

      if (result.success && result.user != null) {
        await UserService.initializeUser();
        final currentUser = UserService.currentUser;

        if (currentUser != null) {
          await StorageService.setRememberMe(rememberMe);
          await _markOnboardingCompleted();

          state = state.copyWith(
            state: AuthState.authenticated,
            user: currentUser,
            firebaseUser: result.user,
            rememberMe: rememberMe,
            errorMessage: null,
          );
          return true;
        }
      }

      state = state.copyWith(
        state: AuthState.error,
        errorMessage: result.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        state: AuthState.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      state = state.copyWith(state: AuthState.loading);

      await FirebaseAuthService.signOut();
      await StorageService.setRememberMe(false);

      state = const AuthData(state: AuthState.unauthenticated);

      developer.log('User signed out', name: 'AuthProvider');
    } catch (e) {
      developer.log('Sign out error: $e', name: 'AuthProvider');
      state = state.copyWith(
        state: AuthState.error,
        errorMessage: e.toString(),
      );
    }
  }

  // Update user data
  void updateUser(UserModel user) {
    if (state.isAuthenticated) {
      state = state.copyWith(user: user);
    }
  }

  // Clear error
  void clearError() {
    state = state.copyWith(
      state: AuthState.unauthenticated,
      errorMessage: null,
    );
  }

  // Mark onboarding as completed
  Future<void> markOnboardingCompleted() async {
    await _markOnboardingCompleted();
    state = state.copyWith(shouldShowOnboarding: false);
  }

  // Private helper methods
  Future<bool> _shouldShowOnboarding() async {
    try {
      final hasCompletedOnboarding =
          await StorageService.hasCompletedOnboarding();

      // If user has completed onboarding, don't show it
      if (hasCompletedOnboarding) return false;

      // Check if this is the first time opening the app
      final onboardingCount = await StorageService.getOnboardingViewCount();

      // Show onboarding only once - on first app launch
      return onboardingCount == 0;
    } catch (e) {
      developer.log(
        'Error checking onboarding status: $e',
        name: 'AuthProvider',
      );
      return true; // Default to showing onboarding if error
    }
  }

  Future<void> _markOnboardingCompleted() async {
    await StorageService.setOnboardingCompleted(true);
  }
}

// Provider instances
final authProvider = StateNotifierProvider<AuthNotifier, AuthData>((ref) {
  return AuthNotifier();
});

// Convenience providers
final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authProvider).user;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});

final isLoadingProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isLoading;
});

final shouldShowOnboardingProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).shouldShowOnboarding;
});
