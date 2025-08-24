import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'storage_service.dart';

class BiometricAuthService {
  static final LocalAuthentication _localAuth = LocalAuthentication();

  /// Check if biometric authentication is available on the device
  static Future<BiometricAvailability> checkBiometricAvailability() async {
    try {
      // Check if device supports biometrics
      final bool isAvailable = await _localAuth.canCheckBiometrics;
      if (!isAvailable) {
        return BiometricAvailability(
          isAvailable: false,
          availableTypes: [],
          message: 'Biometric authentication is not available on this device',
        );
      }

      // Get available biometric types
      final List<BiometricType> availableBiometrics =
          await _localAuth.getAvailableBiometrics();

      if (availableBiometrics.isEmpty) {
        return BiometricAvailability(
          isAvailable: false,
          availableTypes: [],
          message:
              'No biometric authentication methods are set up on this device',
        );
      }

      return BiometricAvailability(
        isAvailable: true,
        availableTypes: availableBiometrics,
        message: 'Biometric authentication is available',
      );
    } catch (e) {
      return BiometricAvailability(
        isAvailable: false,
        availableTypes: [],
        message: 'Error checking biometric availability: ${e.toString()}',
      );
    }
  }

  /// Authenticate using biometrics
  static Future<BiometricAuthResult> authenticateWithBiometrics({
    required String reason,
    bool useErrorDialogs = true,
    bool stickyAuth = true,
  }) async {
    try {
      // Check if biometrics are available
      final availability = await checkBiometricAvailability();
      if (!availability.isAvailable) {
        return BiometricAuthResult(
          success: false,
          message: availability.message,
          errorType: BiometricErrorType.notAvailable,
        );
      }

      // Perform biometric authentication
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          useErrorDialogs: useErrorDialogs,
          stickyAuth: stickyAuth,
          biometricOnly: true,
        ),
      );

      if (didAuthenticate) {
        return BiometricAuthResult(
          success: true,
          message: 'Biometric authentication successful',
          errorType: null,
        );
      } else {
        return BiometricAuthResult(
          success: false,
          message: 'Biometric authentication failed or was cancelled',
          errorType: BiometricErrorType.authenticationFailed,
        );
      }
    } on PlatformException catch (e) {
      BiometricErrorType errorType;
      String message;

      switch (e.code) {
        case 'NotAvailable':
          errorType = BiometricErrorType.notAvailable;
          message = 'Biometric authentication is not available';
          break;
        case 'NotEnrolled':
          errorType = BiometricErrorType.notEnrolled;
          message = 'No biometric credentials are enrolled on this device';
          break;
        case 'LockedOut':
          errorType = BiometricErrorType.lockedOut;
          message =
              'Biometric authentication is temporarily locked due to too many failed attempts';
          break;
        case 'PermanentlyLockedOut':
          errorType = BiometricErrorType.permanentlyLockedOut;
          message =
              'Biometric authentication is permanently locked. Please use device passcode';
          break;
        case 'UserCancel':
          errorType = BiometricErrorType.userCancel;
          message = 'User cancelled biometric authentication';
          break;
        case 'UserFallback':
          errorType = BiometricErrorType.userFallback;
          message = 'User chose to use device passcode instead';
          break;
        case 'SystemCancel':
          errorType = BiometricErrorType.systemCancel;
          message = 'System cancelled biometric authentication';
          break;
        case 'InvalidContext':
          errorType = BiometricErrorType.invalidContext;
          message = 'Invalid authentication context';
          break;
        case 'NotRecognized':
          errorType = BiometricErrorType.notRecognized;
          message = 'Biometric not recognized. Please try again';
          break;
        default:
          errorType = BiometricErrorType.unknown;
          message = 'Unknown biometric authentication error: ${e.message}';
      }

      return BiometricAuthResult(
        success: false,
        message: message,
        errorType: errorType,
      );
    } catch (e) {
      return BiometricAuthResult(
        success: false,
        message:
            'Unexpected error during biometric authentication: ${e.toString()}',
        errorType: BiometricErrorType.unknown,
      );
    }
  }

  /// Enable biometric authentication for the current user
  static Future<bool> enableBiometricAuth() async {
    try {
      // Check if biometrics are available
      final availability = await checkBiometricAvailability();
      if (!availability.isAvailable) {
        return false;
      }

      // Test biometric authentication
      final authResult = await authenticateWithBiometrics(
        reason: 'Enable biometric authentication for quick login',
      );

      if (authResult.success) {
        // Save biometric preference
        await StorageService.setBiometricEnabled(true);
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('Error enabling biometric auth: $e');
      return false;
    }
  }

  /// Disable biometric authentication
  static Future<void> disableBiometricAuth() async {
    try {
      await StorageService.setBiometricEnabled(false);
    } catch (e) {
      print('Error disabling biometric auth: $e');
    }
  }

  /// Check if biometric authentication is enabled for the current user
  static Future<bool> isBiometricEnabled() async {
    try {
      return await StorageService.isBiometricEnabled();
    } catch (e) {
      print('Error checking biometric status: $e');
      return false;
    }
  }

  /// Get user-friendly biometric type names
  static String getBiometricTypeName(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return 'Face ID';
      case BiometricType.fingerprint:
        return 'Fingerprint';
      case BiometricType.iris:
        return 'Iris';
      case BiometricType.strong:
        return 'Strong Biometric';
      case BiometricType.weak:
        return 'Weak Biometric';
    }
  }

  /// Get available biometric types as user-friendly strings
  static Future<List<String>> getAvailableBiometricNames() async {
    try {
      final availability = await checkBiometricAvailability();
      if (!availability.isAvailable) {
        return [];
      }

      return availability.availableTypes
          .map((type) => getBiometricTypeName(type))
          .toList();
    } catch (e) {
      print('Error getting biometric names: $e');
      return [];
    }
  }

  /// Quick login using biometrics (for existing users)
  static Future<BiometricAuthResult> quickLogin() async {
    try {
      // Check if biometric is enabled
      final isEnabled = await isBiometricEnabled();
      if (!isEnabled) {
        return BiometricAuthResult(
          success: false,
          message: 'Biometric authentication is not enabled',
          errorType: BiometricErrorType.notEnabled,
        );
      }

      // Perform biometric authentication
      return await authenticateWithBiometrics(
        reason: 'Use your biometric to sign in quickly',
      );
    } catch (e) {
      return BiometricAuthResult(
        success: false,
        message: 'Error during quick login: ${e.toString()}',
        errorType: BiometricErrorType.unknown,
      );
    }
  }
}

/// Result of biometric availability check
class BiometricAvailability {
  final bool isAvailable;
  final List<BiometricType> availableTypes;
  final String message;

  BiometricAvailability({
    required this.isAvailable,
    required this.availableTypes,
    required this.message,
  });
}

/// Result of biometric authentication
class BiometricAuthResult {
  final bool success;
  final String message;
  final BiometricErrorType? errorType;

  BiometricAuthResult({
    required this.success,
    required this.message,
    this.errorType,
  });
}

/// Types of biometric authentication errors
enum BiometricErrorType {
  notAvailable,
  notEnrolled,
  notEnabled,
  lockedOut,
  permanentlyLockedOut,
  userCancel,
  userFallback,
  systemCancel,
  invalidContext,
  notRecognized,
  authenticationFailed,
  unknown,
}
