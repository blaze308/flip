import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'firebase_auth_service.dart';

class StorageService {
  // Secure storage for sensitive data (tokens)
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

  // Keys for secure storage
  static const String _tokenKey = 'auth_token';

  // Keys for regular storage
  static const String _userKey = 'user_data';
  static const String _userModelKey = 'user_model_data';
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _rememberMeKey = 'remember_me';
  static const String _onboardingCompletedKey = 'onboarding_completed';
  static const String _onboardingViewCountKey = 'onboarding_view_count';

  // Save authentication data
  static Future<void> saveAuthData({
    required String token,
    required UserData user,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await Future.wait([
      _secureStorage.write(
        key: _tokenKey,
        value: token,
      ), // Store token securely
      prefs.setString(_userKey, json.encode(user.toJson())),
      prefs.setBool(_isLoggedInKey, true),
    ]);
  }

  // Get stored token from secure storage
  static Future<String?> getToken() async {
    try {
      return await _secureStorage.read(key: _tokenKey);
    } catch (e) {
      // If there's an error reading from secure storage, return null
      return null;
    }
  }

  // Get stored user data
  static Future<UserData?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);

    if (userJson != null) {
      try {
        final userMap = json.decode(userJson) as Map<String, dynamic>;
        return UserData.fromJson(userMap);
      } catch (e) {
        // If there's an error parsing, clear the corrupted data
        await clearAuthData();
        return null;
      }
    }

    return null;
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  // Clear all authentication data (logout)
  static Future<void> clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();

    await Future.wait([
      _secureStorage.delete(key: _tokenKey), // Clear token from secure storage
      prefs.remove(_userKey),
      prefs.setBool(_isLoggedInKey, false),
      prefs.remove(_biometricEnabledKey),
    ]);
  }

  // Update user data
  static Future<void> updateUserData(UserData user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, json.encode(user.toJson()));
  }

  // Check if token exists and is valid format
  static Future<bool> hasValidToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // Clear all secure storage (for complete reset)
  static Future<void> clearAllSecureData() async {
    try {
      await _secureStorage.deleteAll();
    } catch (e) {
      // If there's an error, try to delete individual keys
      await _secureStorage.delete(key: _tokenKey);
    }
  }

  // Check if secure storage is available
  static Future<bool> isSecureStorageAvailable() async {
    try {
      await _secureStorage.containsKey(key: 'test_key');
      return true;
    } catch (e) {
      return false;
    }
  }

  // Get all stored keys (for debugging - use carefully)
  static Future<Map<String, String>> getAllSecureData() async {
    try {
      return await _secureStorage.readAll();
    } catch (e) {
      return {};
    }
  }

  // Migrate token from SharedPreferences to SecureStorage (if needed)
  static Future<void> migrateTokenToSecureStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final oldToken = prefs.getString('old_auth_token');

      if (oldToken != null && oldToken.isNotEmpty) {
        // Save to secure storage
        await _secureStorage.write(key: _tokenKey, value: oldToken);
        // Remove from SharedPreferences
        await prefs.remove('old_auth_token');
      }
    } catch (e) {
      // Migration failed, but continue normally
    }
  }

  // Biometric authentication preferences
  static Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, enabled);
  }

  static Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }

  // Save user model data
  static Future<void> saveUserModelData(
    Map<String, dynamic> userModelData,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userModelKey, json.encode(userModelData));
  }

  // Get user model data
  static Future<Map<String, dynamic>?> getUserModelData() async {
    final prefs = await SharedPreferences.getInstance();
    final userModelJson = prefs.getString(_userModelKey);
    if (userModelJson != null) {
      return json.decode(userModelJson) as Map<String, dynamic>;
    }
    return null;
  }

  // Clear user model data
  static Future<void> clearUserModelData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userModelKey);
  }

  // Remember Me functionality
  static Future<void> setRememberMe(bool rememberMe) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, rememberMe);
  }

  static Future<bool> getRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberMeKey) ?? false;
  }

  // Onboarding functionality
  static Future<void> setOnboardingCompleted(bool completed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompletedKey, completed);
  }

  static Future<bool> hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingCompletedKey) ?? false;
  }

  static Future<int> getOnboardingViewCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_onboardingViewCountKey) ?? 0;
  }

  static Future<void> incrementOnboardingViewCount() async {
    final prefs = await SharedPreferences.getInstance();
    final currentCount = await getOnboardingViewCount();
    await prefs.setInt(_onboardingViewCountKey, currentCount + 1);
  }

  static Future<void> resetOnboardingData() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_onboardingCompletedKey),
      prefs.remove(_onboardingViewCountKey),
    ]);
  }
}
