import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Token-based authentication service that replaces Riverpod/Provider
/// Uses JWT tokens from backend for authentication state management
class TokenAuthService {
  static const String _baseUrl = 'https://flip-backend-mnpg.onrender.com';
  static const Duration _timeoutDuration = Duration(seconds: 30);

  // Secure storage for tokens
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    lOptions: LinuxOptions(),
    wOptions: WindowsOptions(useBackwardCompatibility: false),
    mOptions: MacOsOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // Storage keys
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userDataKey = 'user_data';
  static const String _rememberMeKey = 'remember_me';
  static const String _onboardingCompletedKey = 'onboarding_completed';
  static const String _firstLaunchKey = 'first_launch';

  // Current authentication state
  static AuthState _currentState = AuthState.initial;
  static TokenUser? _currentUser;
  static String? _accessToken;
  static String? _refreshToken;

  // Listeners for auth state changes
  static final List<Function(AuthState, TokenUser?)> _listeners = [];

  /// Get current authentication state
  static AuthState get currentState => _currentState;

  /// Get current user
  static TokenUser? get currentUser => _currentUser;

  /// Check if user is authenticated
  static bool get isAuthenticated =>
      _currentState == AuthState.authenticated &&
      _currentUser != null &&
      _accessToken != null;

  /// Check if user is loading
  static bool get isLoading => _currentState == AuthState.loading;

  /// Add listener for auth state changes
  static void addListener(Function(AuthState, TokenUser?) listener) {
    _listeners.add(listener);
  }

  /// Remove listener
  static void removeListener(Function(AuthState, TokenUser?) listener) {
    _listeners.remove(listener);
  }

  /// Notify all listeners of state changes
  static void _notifyListeners() {
    for (final listener in _listeners) {
      try {
        listener(_currentState, _currentUser);
      } catch (e) {
        developer.log('Error in auth listener: $e', name: 'TokenAuthService');
      }
    }
  }

  /// Update authentication state
  static void _updateState(AuthState newState, {TokenUser? user}) {
    _currentState = newState;
    if (user != null) {
      _currentUser = user;
    } else if (newState == AuthState.unauthenticated) {
      _currentUser = null;
    }
    _notifyListeners();
  }

  /// Initialize authentication service
  static Future<void> initialize() async {
    try {
      print('🔐 TokenAuthService: Starting initialization...');
      _updateState(AuthState.loading);

      // Check if we have stored tokens
      _accessToken = await _secureStorage.read(key: _accessTokenKey);
      _refreshToken = await _secureStorage.read(key: _refreshTokenKey);

      print(
        '🔐 TokenAuthService: Tokens from storage - Access: ${_accessToken != null ? 'Present' : 'Missing'}, Refresh: ${_refreshToken != null ? 'Present' : 'Missing'}',
      );

      if (_accessToken != null && _refreshToken != null) {
        // Try to validate the token and get user data
        final isValid = await _validateToken();
        print('🔐 TokenAuthService: Token validation result: $isValid');

        if (isValid) {
          // Load user data from storage
          final userData = await _getUserDataFromStorage();
          print(
            '🔐 TokenAuthService: User data from storage: ${userData != null ? 'Found' : 'Missing'}',
          );

          if (userData != null) {
            _currentUser = userData;
            _updateState(AuthState.authenticated, user: userData);
            print(
              '🔐 TokenAuthService: User authenticated from stored token - ${userData.displayName}',
            );
            return;
          } else {
            print('🔐 TokenAuthService: Token valid but no user data found');
          }
        } else {
          print(
            '🔐 TokenAuthService: Token validation failed, trying refresh...',
          );
          // Try to refresh the token
          final refreshed = await _refreshAccessToken();
          if (refreshed) {
            final userData = await _getUserDataFromStorage();
            if (userData != null) {
              _currentUser = userData;
              _updateState(AuthState.authenticated, user: userData);
              print(
                '🔐 TokenAuthService: User authenticated after token refresh - ${userData.displayName}',
              );
              return;
            }
          }
        }
      }

      // Check if this is first launch to show onboarding
      final showOnboarding = await shouldShowOnboarding();
      _updateState(
        showOnboarding ? AuthState.initial : AuthState.unauthenticated,
      );

      developer.log('User not authenticated', name: 'TokenAuthService');
    } catch (e) {
      developer.log('Auth initialization error: $e', name: 'TokenAuthService');
      _updateState(AuthState.error);
    }
  }

  /// Validate current access token
  static Future<bool> _validateToken() async {
    if (_accessToken == null) {
      print('🔐 TokenAuthService: No access token to validate');
      return false;
    }

    try {
      print('🔐 TokenAuthService: Validating access token...');
      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/token/verify'),
            headers: {
              'Authorization': 'Bearer $_accessToken',
              'Content-Type': 'application/json',
            },
          )
          .timeout(_timeoutDuration);

      print(
        '🔐 TokenAuthService: Token validation response: ${response.statusCode}',
      );
      if (response.statusCode != 200) {
        print('🔐 TokenAuthService: Token validation failed: ${response.body}');
      }
      return response.statusCode == 200;
    } catch (e) {
      developer.log('Token validation failed: $e', name: 'TokenAuthService');
      return false;
    }
  }

  /// Refresh access token using refresh token
  static Future<bool> _refreshAccessToken() async {
    if (_refreshToken == null) return false;

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/token/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': _refreshToken}),
          )
          .timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['data']['accessToken'];
        await _secureStorage.write(key: _accessTokenKey, value: _accessToken);
        return true;
      }
    } catch (e) {
      developer.log('Token refresh failed: $e', name: 'TokenAuthService');
    }
    return false;
  }

  /// Exchange Firebase token for JWT tokens
  static Future<TokenExchangeResult> _exchangeFirebaseToken(
    User firebaseUser, {
    bool rememberMe = false,
  }) async {
    try {
      final firebaseToken = await firebaseUser.getIdToken();
      final deviceInfo = await _getDeviceInfo();

      print('🔐 TokenAuthService: Exchanging Firebase token...');
      print('🔐 TokenAuthService: Device info: $deviceInfo');
      print('🔐 TokenAuthService: Remember me: $rememberMe');

      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/token/exchange'),
            headers: {
              'Authorization': 'Bearer $firebaseToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'deviceInfo': deviceInfo,
              'rememberMe': rememberMe,
            }),
          )
          .timeout(_timeoutDuration);

      print('🔐 TokenAuthService: Response status: ${response.statusCode}');
      print('🔐 TokenAuthService: Response body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final tokenData = data['data'];
        final tokens = tokenData['tokens'];
        _accessToken = tokens['accessToken'];
        _refreshToken = tokens['refreshToken'];

        // Store tokens securely
        print('🔐 TokenAuthService: Saving tokens to secure storage...');
        print('   - Access Token Length: ${_accessToken?.length ?? 0}');
        print('   - Refresh Token Length: ${_refreshToken?.length ?? 0}');

        await Future.wait([
          _secureStorage.write(key: _accessTokenKey, value: _accessToken),
          _secureStorage.write(key: _refreshTokenKey, value: _refreshToken),
          _secureStorage.write(
            key: _rememberMeKey,
            value: rememberMe.toString(),
          ),
        ]);

        print('🔐 TokenAuthService: Tokens saved successfully!');

        // Verify tokens were actually saved
        final savedAccessToken = await _secureStorage.read(
          key: _accessTokenKey,
        );
        final savedRefreshToken = await _secureStorage.read(
          key: _refreshTokenKey,
        );
        print(
          '🔐 TokenAuthService: Verification - Access: ${savedAccessToken != null ? 'Found' : 'Missing'}, Refresh: ${savedRefreshToken != null ? 'Found' : 'Missing'}',
        );

        // Create user object
        final user = TokenUser.fromBackendData(tokenData['user']);
        await _saveUserDataToStorage(user);

        // Update authentication state
        _currentUser = user;
        _updateState(AuthState.authenticated, user: user);
        print(
          '🔐 TokenAuthService: Authentication state updated to authenticated',
        );

        return TokenExchangeResult(
          success: true,
          user: user,
          isNewUser: data['data']['isNewUser'] ?? false,
        );
      } else {
        return TokenExchangeResult(
          success: false,
          error: data['message'] ?? 'Token exchange failed',
        );
      }
    } catch (e) {
      developer.log('Token exchange failed: $e', name: 'TokenAuthService');
      return TokenExchangeResult(
        success: false,
        error: 'Network error: ${e.toString()}',
      );
    }
  }

  /// Sign in with email and password
  static Future<AuthResult> signInWithEmailAndPassword({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    try {
      _updateState(AuthState.loading);

      // Sign in with Firebase
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Exchange Firebase token for JWT
        final exchangeResult = await _exchangeFirebaseToken(
          credential.user!,
          rememberMe: rememberMe,
        );

        if (exchangeResult.success && exchangeResult.user != null) {
          _updateState(AuthState.authenticated, user: exchangeResult.user);
          return AuthResult(success: true, message: 'Welcome back!');
        } else {
          _updateState(AuthState.error);
          return AuthResult(
            success: false,
            message: exchangeResult.error ?? 'Authentication failed',
          );
        }
      } else {
        _updateState(AuthState.error);
        return AuthResult(success: false, message: 'Sign in failed');
      }
    } on FirebaseAuthException catch (e) {
      _updateState(AuthState.error);
      return AuthResult(success: false, message: _getFirebaseErrorMessage(e));
    } catch (e) {
      _updateState(AuthState.error);
      return AuthResult(
        success: false,
        message: 'An unexpected error occurred',
      );
    }
  }

  /// Register with email and password
  static Future<AuthResult> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      _updateState(AuthState.loading);

      // Check if user already exists
      final signInMethods = await FirebaseAuth.instance
          .fetchSignInMethodsForEmail(email);
      if (signInMethods.isNotEmpty) {
        _updateState(AuthState.error);
        return AuthResult(
          success: false,
          message:
              'An account with this email already exists. Please sign in instead.',
        );
      }

      // Create Firebase account
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      if (credential.user != null) {
        // Update display name
        await credential.user!.updateDisplayName(fullName);
        await credential.user!.sendEmailVerification();
        await credential.user!.reload();

        // Exchange Firebase token for JWT
        final exchangeResult = await _exchangeFirebaseToken(credential.user!);

        if (exchangeResult.success && exchangeResult.user != null) {
          // Mark onboarding as completed for new users
          await _markOnboardingCompleted();

          _updateState(AuthState.authenticated, user: exchangeResult.user);
          return AuthResult(success: true, message: 'Registration successful!');
        } else {
          _updateState(AuthState.error);
          return AuthResult(
            success: false,
            message: exchangeResult.error ?? 'Registration failed',
          );
        }
      } else {
        _updateState(AuthState.error);
        return AuthResult(success: false, message: 'Registration failed');
      }
    } on FirebaseAuthException catch (e) {
      _updateState(AuthState.error);
      return AuthResult(success: false, message: _getFirebaseErrorMessage(e));
    } catch (e) {
      _updateState(AuthState.error);
      return AuthResult(
        success: false,
        message: 'An unexpected error occurred',
      );
    }
  }

  /// Sign in with Google
  static Future<AuthResult> signInWithGoogle() async {
    try {
      _updateState(AuthState.loading);

      // Import Google Sign In
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        _updateState(AuthState.unauthenticated);
        return AuthResult(
          success: false,
          message: 'Google sign in was cancelled',
        );
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      if (userCredential.user != null) {
        // Exchange Firebase token for JWT
        final exchangeResult = await _exchangeFirebaseToken(
          userCredential.user!,
        );

        if (exchangeResult.success && exchangeResult.user != null) {
          if (exchangeResult.isNewUser) {
            await _markOnboardingCompleted();
          }

          _updateState(AuthState.authenticated, user: exchangeResult.user);
          return AuthResult(
            success: true,
            message: 'Successfully signed in with Google!',
          );
        } else {
          _updateState(AuthState.error);
          return AuthResult(
            success: false,
            message: exchangeResult.error ?? 'Google sign in failed',
          );
        }
      } else {
        _updateState(AuthState.error);
        return AuthResult(success: false, message: 'Google sign in failed');
      }
    } catch (e) {
      _updateState(AuthState.error);
      return AuthResult(
        success: false,
        message: 'Google sign in failed: ${e.toString()}',
      );
    }
  }

  /// Sign in with Apple
  static Future<AuthResult> signInWithApple() async {
    try {
      _updateState(AuthState.loading);

      // Import Apple Sign In
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider(
        "apple.com",
      ).credential(idToken: appleCredential.identityToken);

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        oauthCredential,
      );

      if (userCredential.user != null) {
        // Update display name if available
        if (userCredential.user!.displayName == null &&
            appleCredential.givenName != null) {
          final fullName =
              '${appleCredential.givenName} ${appleCredential.familyName ?? ''}'
                  .trim();
          await userCredential.user!.updateDisplayName(fullName);
          await userCredential.user!.reload();
        }

        // Exchange Firebase token for JWT
        final exchangeResult = await _exchangeFirebaseToken(
          userCredential.user!,
        );

        if (exchangeResult.success && exchangeResult.user != null) {
          if (exchangeResult.isNewUser) {
            await _markOnboardingCompleted();
          }

          _updateState(AuthState.authenticated, user: exchangeResult.user);
          return AuthResult(
            success: true,
            message: 'Successfully signed in with Apple!',
          );
        } else {
          _updateState(AuthState.error);
          return AuthResult(
            success: false,
            message: exchangeResult.error ?? 'Apple sign in failed',
          );
        }
      } else {
        _updateState(AuthState.error);
        return AuthResult(success: false, message: 'Apple sign in failed');
      }
    } catch (e) {
      _updateState(AuthState.error);
      return AuthResult(
        success: false,
        message: 'Apple sign in failed: ${e.toString()}',
      );
    }
  }

  /// Sign out
  static Future<void> signOut() async {
    try {
      _updateState(AuthState.loading);

      // Sign out from Firebase
      await FirebaseAuth.instance.signOut();

      // Clear stored tokens and data
      await Future.wait([
        _secureStorage.delete(key: _accessTokenKey),
        _secureStorage.delete(key: _refreshTokenKey),
        _secureStorage.delete(key: _rememberMeKey),
        _clearUserDataFromStorage(),
      ]);

      _accessToken = null;
      _refreshToken = null;
      _currentUser = null;

      _updateState(AuthState.unauthenticated);
      developer.log('User signed out successfully', name: 'TokenAuthService');
    } catch (e) {
      developer.log('Sign out error: $e', name: 'TokenAuthService');
      _updateState(AuthState.error);
    }
  }

  /// Get authorization headers for API requests
  static Future<Map<String, String>?> getAuthHeaders() async {
    if (_accessToken == null) return null;

    // Check if token needs refresh
    final isValid = await _validateToken();
    if (!isValid) {
      final refreshed = await _refreshAccessToken();
      if (!refreshed) {
        // Token refresh failed, sign out user
        await signOut();
        return null;
      }
    }

    return {
      'Authorization': 'Bearer $_accessToken',
      'Content-Type': 'application/json',
    };
  }

  /// Check if should show onboarding (first launch)
  static Future<bool> shouldShowOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isFirstLaunch = prefs.getBool(_firstLaunchKey) ?? true;
      final hasCompletedOnboarding =
          prefs.getBool(_onboardingCompletedKey) ?? false;

      // Show onboarding if it's first launch and user hasn't completed onboarding
      return isFirstLaunch && !hasCompletedOnboarding;
    } catch (e) {
      developer.log(
        'Failed to check onboarding status: $e',
        name: 'TokenAuthService',
      );
      return true; // Default to showing onboarding on error
    }
  }

  /// Mark onboarding as completed
  static Future<void> _markOnboardingCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setBool(_onboardingCompletedKey, true),
        prefs.setBool(_firstLaunchKey, false),
      ]);
    } catch (e) {
      developer.log(
        'Failed to mark onboarding completed: $e',
        name: 'TokenAuthService',
      );
    }
  }

  /// Mark onboarding as completed (public method for skip functionality)
  static Future<void> completeOnboarding() async {
    await _markOnboardingCompleted();
    _updateState(AuthState.unauthenticated);
  }

  /// Mark onboarding as completed without changing auth state
  /// Used in new contextual auth flow
  static Future<void> markOnboardingCompleted() async {
    await _markOnboardingCompleted();
  }

  /// Skip to home screen without authentication (guest mode)
  static Future<void> skipToHome() async {
    await _markOnboardingCompleted();
    // Set state to a special guest state that allows home access
    _updateState(AuthState.unauthenticated);
  }

  /// Check if user is in guest mode (can access home without auth)
  static bool get isGuestMode =>
      _currentState == AuthState.unauthenticated && _currentUser == null;

  /// Check if Remember Me is enabled for current session
  static Future<bool> get isRememberMeEnabled async {
    try {
      final rememberMeValue = await _secureStorage.read(key: _rememberMeKey);
      return rememberMeValue == 'true';
    } catch (e) {
      return false;
    }
  }

  /// Get current session info for debugging
  static Future<Map<String, dynamic>> getSessionInfo() async {
    try {
      final rememberMe = await isRememberMeEnabled;
      return {
        'isAuthenticated': isAuthenticated,
        'rememberMe': rememberMe,
        'hasAccessToken': _accessToken != null,
        'hasRefreshToken': _refreshToken != null,
        'currentUser': _currentUser?.toJson(),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Save user data to storage
  static Future<void> _saveUserDataToStorage(TokenUser user) async {
    try {
      print('🔐 TokenAuthService: Saving user data to storage...');
      print('   - User: ${user.displayName} (${user.email})');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userDataKey, jsonEncode(user.toJson()));

      print('🔐 TokenAuthService: User data saved successfully!');
    } catch (e) {
      print('🔐 TokenAuthService: Failed to save user data: $e');
      developer.log('Failed to save user data: $e', name: 'TokenAuthService');
    }
  }

  /// Get user data from storage
  static Future<TokenUser?> _getUserDataFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userDataKey);
      if (userJson != null) {
        return TokenUser.fromJson(jsonDecode(userJson));
      }
    } catch (e) {
      developer.log('Failed to get user data: $e', name: 'TokenAuthService');
    }
    return null;
  }

  /// Clear user data from storage
  static Future<void> _clearUserDataFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userDataKey);
    } catch (e) {
      developer.log('Failed to clear user data: $e', name: 'TokenAuthService');
    }
  }

  /// Get device info for token exchange
  static Future<Map<String, dynamic>> _getDeviceInfo() async {
    // Detect platform dynamically
    String deviceType = 'android'; // Default to android

    // You can use Platform.isIOS, Platform.isAndroid from 'dart:io'
    // or kIsWeb from 'package:flutter/foundation.dart' for web detection
    try {
      if (Platform.isIOS) {
        deviceType = 'ios';
      } else if (Platform.isAndroid) {
        deviceType = 'android';
      } else {
        deviceType = 'web'; // Fallback for other platforms
      }
    } catch (e) {
      // If Platform is not available (web), default to web
      deviceType = 'web';
    }

    return {
      'deviceType': deviceType,
      'platform': 'flutter',
      'appVersion': '1.0.0',
    };
  }

  /// Get Firebase error message
  static String _getFirebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password is too weak. Please choose a stronger password.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }
}

/// Authentication states
enum AuthState { initial, loading, authenticated, unauthenticated, error }

/// Token user model
class TokenUser {
  final String id;
  final String firebaseUid;
  final String? email;
  final String? displayName;
  final String? phoneNumber;
  final String? photoURL;
  final bool emailVerified;
  final String role;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? lastLogin;

  TokenUser({
    required this.id,
    required this.firebaseUid,
    this.email,
    this.displayName,
    this.phoneNumber,
    this.photoURL,
    required this.emailVerified,
    required this.role,
    required this.isActive,
    this.createdAt,
    this.lastLogin,
  });

  factory TokenUser.fromBackendData(Map<String, dynamic> data) {
    return TokenUser(
      id: data['id'] ?? '',
      firebaseUid: data['firebaseUid'] ?? '',
      email: data['email'],
      displayName: data['displayName'],
      phoneNumber: data['phoneNumber'],
      photoURL: data['photoURL'],
      emailVerified: data['emailVerified'] ?? false,
      role: data['role'] ?? 'user',
      isActive: data['isActive'] ?? true,
      createdAt:
          data['createdAt'] != null ? DateTime.parse(data['createdAt']) : null,
      lastLogin:
          data['lastLogin'] != null ? DateTime.parse(data['lastLogin']) : null,
    );
  }

  factory TokenUser.fromJson(Map<String, dynamic> json) {
    return TokenUser(
      id: json['id'] ?? '',
      firebaseUid: json['firebaseUid'] ?? '',
      email: json['email'],
      displayName: json['displayName'],
      phoneNumber: json['phoneNumber'],
      photoURL: json['photoURL'],
      emailVerified: json['emailVerified'] ?? false,
      role: json['role'] ?? 'user',
      isActive: json['isActive'] ?? true,
      createdAt:
          json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      lastLogin:
          json['lastLogin'] != null ? DateTime.parse(json['lastLogin']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firebaseUid': firebaseUid,
      'email': email,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'photoURL': photoURL,
      'emailVerified': emailVerified,
      'role': role,
      'isActive': isActive,
      'createdAt': createdAt?.toIso8601String(),
      'lastLogin': lastLogin?.toIso8601String(),
    };
  }
}

/// Result from token exchange
class TokenExchangeResult {
  final bool success;
  final TokenUser? user;
  final bool isNewUser;
  final String? error;

  TokenExchangeResult({
    required this.success,
    this.user,
    this.isNewUser = false,
    this.error,
  });
}

/// Authentication result
class AuthResult {
  final bool success;
  final String message;

  AuthResult({required this.success, required this.message});
}
