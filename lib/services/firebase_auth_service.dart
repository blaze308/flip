import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'storage_service.dart';
import 'backend_service.dart';

class FirebaseAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Get current user
  static User? get currentUser => _auth.currentUser;

  // Auth state stream
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // User state stream (includes profile changes)
  static Stream<User?> get userChanges => _auth.userChanges();

  // Check if user is signed in
  static bool get isSignedIn => _auth.currentUser != null;

  // Get current user's email
  static String? get currentUserEmail => _auth.currentUser?.email;

  // Get current user's display name
  static String? get currentUserDisplayName => _auth.currentUser?.displayName;

  // Get current user's phone number
  static String? get currentUserPhoneNumber => _auth.currentUser?.phoneNumber;

  // Get current user's photo URL
  static String? get currentUserPhotoURL => _auth.currentUser?.photoURL;

  // Get current user's UID
  static String? get currentUserUID => _auth.currentUser?.uid;

  // Check if email is verified
  static bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  // Register with email and password
  static Future<AuthResult> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      // Check if user already exists with this email
      final signInMethods = await _auth.fetchSignInMethodsForEmail(email);
      if (signInMethods.isNotEmpty) {
        return AuthResult(
          success: false,
          message:
              'An account with this email already exists. Please sign in instead.',
          user: null,
        );
      }

      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = result.user;
      if (user != null) {
        // Update display name
        await user.updateDisplayName(fullName);
        await user.reload();

        // Send email verification
        await user.sendEmailVerification();

        // Save user data locally
        await _saveUserDataLocally(user);

        // Sync with backend
        try {
          await BackendService.syncUser();
        } catch (e) {
          print('Backend sync failed during registration: $e');
          // Continue even if backend sync fails
        }

        return AuthResult(
          success: true,
          message:
              'Registration successful! Please check your email to verify your account.',
          user: user,
          shouldShowBiometricSetup: true,
        );
      } else {
        return AuthResult(
          success: false,
          message: 'Registration failed. Please try again.',
          user: null,
        );
      }
    } on FirebaseAuthException catch (e) {
      return AuthResult(
        success: false,
        message: _getErrorMessage(e),
        user: null,
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'An unexpected error occurred: ${e.toString()}',
        user: null,
      );
    }
  }

  // Sign in with email and password
  static Future<AuthResult> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = result.user;
      if (user != null) {
        await _saveUserDataLocally(user);

        // Sync with backend
        try {
          await BackendService.syncUser();
        } catch (e) {
          print('Backend sync failed during login: $e');
          // Continue even if backend sync fails
        }

        return AuthResult(success: true, message: 'Welcome back!', user: user);
      } else {
        return AuthResult(
          success: false,
          message: 'Sign in failed. Please try again.',
          user: null,
        );
      }
    } on FirebaseAuthException catch (e) {
      return AuthResult(
        success: false,
        message: _getErrorMessage(e),
        user: null,
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'An unexpected error occurred: ${e.toString()}',
        user: null,
      );
    }
  }

  // Sign in with Google
  static Future<AuthResult> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return AuthResult(
          success: false,
          message: 'Google sign in was cancelled',
          user: null,
        );
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Check if user exists with this email using different provider
      final String email = googleUser.email;
      final signInMethods = await _auth.fetchSignInMethodsForEmail(email);

      if (signInMethods.isNotEmpty && !signInMethods.contains('google.com')) {
        // User exists with different provider, link accounts
        return await _linkAccountWithGoogle(credential, email);
      }

      // Sign in to Firebase with the Google credential
      final UserCredential result = await _auth.signInWithCredential(
        credential,
      );
      final User? user = result.user;

      if (user != null) {
        await _saveUserDataLocally(user);

        // Sync with backend
        try {
          await BackendService.syncUser();
        } catch (e) {
          print('Backend sync failed during Google sign in: $e');
          // Continue even if backend sync fails
        }

        return AuthResult(
          success: true,
          message: 'Successfully signed in with Google!',
          user: user,
        );
      } else {
        return AuthResult(
          success: false,
          message: 'Google sign in failed. Please try again.',
          user: null,
        );
      }
    } on FirebaseAuthException catch (e) {
      return AuthResult(
        success: false,
        message: _getErrorMessage(e),
        user: null,
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Google sign in failed: ${e.toString()}',
        user: null,
      );
    }
  }

  // Sign in with Apple
  static Future<AuthResult> signInWithApple() async {
    try {
      // Generate a random nonce
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      // Request credential for the currently signed in Apple account
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      // Create an `OAuthCredential` from the credential returned by Apple
      final oauthCredential = OAuthProvider(
        "apple.com",
      ).credential(idToken: appleCredential.identityToken, rawNonce: rawNonce);

      // Check if user exists with this email using different provider
      if (appleCredential.email != null) {
        final signInMethods = await _auth.fetchSignInMethodsForEmail(
          appleCredential.email!,
        );

        if (signInMethods.isNotEmpty && !signInMethods.contains('apple.com')) {
          // User exists with different provider, link accounts
          return await _linkAccountWithApple(
            oauthCredential,
            appleCredential.email!,
          );
        }
      }

      // Sign in the user with Firebase
      final UserCredential result = await _auth.signInWithCredential(
        oauthCredential,
      );
      final User? user = result.user;

      if (user != null) {
        // Update display name if available and not already set
        if (user.displayName == null && appleCredential.givenName != null) {
          final fullName =
              '${appleCredential.givenName} ${appleCredential.familyName ?? ''}'
                  .trim();
          await user.updateDisplayName(fullName);
          await user.reload();
        }

        await _saveUserDataLocally(user);

        // Sync with backend
        try {
          await BackendService.syncUser();
        } catch (e) {
          print('Backend sync failed during Apple sign in: $e');
          // Continue even if backend sync fails
        }

        return AuthResult(
          success: true,
          message: 'Successfully signed in with Apple!',
          user: user,
        );
      } else {
        return AuthResult(
          success: false,
          message: 'Apple sign in failed. Please try again.',
          user: null,
        );
      }
    } on FirebaseAuthException catch (e) {
      return AuthResult(
        success: false,
        message: _getErrorMessage(e),
        user: null,
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Apple sign in failed: ${e.toString()}',
        user: null,
      );
    }
  }

  // Send phone verification code
  static Future<AuthResult> sendPhoneVerificationCode({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onVerificationFailed,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification completed (Android only)
          final result = await _signInWithPhoneCredential(credential);
          if (result.success) {
            onCodeSent('auto-verified');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          onVerificationFailed(_getErrorMessage(e));
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // Auto-retrieval timeout
        },
        timeout: const Duration(seconds: 60),
      );

      return AuthResult(
        success: true,
        message: 'Verification code sent successfully',
        user: null,
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(
        success: false,
        message: _getErrorMessage(e),
        user: null,
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Failed to send verification code: ${e.toString()}',
        user: null,
      );
    }
  }

  // Verify phone number with code
  static Future<AuthResult> verifyPhoneNumber({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      return await _signInWithPhoneCredential(credential);
    } on FirebaseAuthException catch (e) {
      return AuthResult(
        success: false,
        message: _getErrorMessage(e),
        user: null,
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Phone verification failed: ${e.toString()}',
        user: null,
      );
    }
  }

  // Sign in with phone credential
  static Future<AuthResult> _signInWithPhoneCredential(
    PhoneAuthCredential credential,
  ) async {
    try {
      final UserCredential result = await _auth.signInWithCredential(
        credential,
      );
      final User? user = result.user;

      if (user != null) {
        await _saveUserDataLocally(user);

        // Sync with backend
        try {
          await BackendService.syncUser();
        } catch (e) {
          print('Backend sync failed during phone verification: $e');
          // Continue even if backend sync fails
        }

        return AuthResult(
          success: true,
          message: 'Phone verification successful!',
          user: user,
        );
      } else {
        return AuthResult(
          success: false,
          message: 'Phone verification failed. Please try again.',
          user: null,
        );
      }
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Phone verification failed: ${e.toString()}',
        user: null,
      );
    }
  }

  // Link Google account with existing account
  static Future<AuthResult> _linkAccountWithGoogle(
    AuthCredential credential,
    String email,
  ) async {
    try {
      // First, get the existing user to sign in
      final signInMethods = await _auth.fetchSignInMethodsForEmail(email);

      if (signInMethods.contains('password')) {
        return AuthResult(
          success: false,
          message:
              'An account with this email already exists. Please sign in with your email and password first, then link your Google account in settings.',
          user: null,
        );
      }

      // For other providers, we can't automatically link without user interaction
      return AuthResult(
        success: false,
        message:
            'An account with this email already exists with a different sign-in method. Please use that method to sign in.',
        user: null,
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Account linking failed: ${e.toString()}',
        user: null,
      );
    }
  }

  // Link Apple account with existing account
  static Future<AuthResult> _linkAccountWithApple(
    AuthCredential credential,
    String email,
  ) async {
    try {
      // Similar logic to Google linking
      final signInMethods = await _auth.fetchSignInMethodsForEmail(email);

      if (signInMethods.contains('password')) {
        return AuthResult(
          success: false,
          message:
              'An account with this email already exists. Please sign in with your email and password first, then link your Apple account in settings.',
          user: null,
        );
      }

      return AuthResult(
        success: false,
        message:
            'An account with this email already exists with a different sign-in method. Please use that method to sign in.',
        user: null,
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Account linking failed: ${e.toString()}',
        user: null,
      );
    }
  }

  // Link provider to current user
  static Future<AuthResult> linkProvider(AuthCredential credential) async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        return AuthResult(
          success: false,
          message: 'No user is currently signed in',
          user: null,
        );
      }

      final UserCredential result = await user.linkWithCredential(credential);
      await _saveUserDataLocally(result.user!);

      return AuthResult(
        success: true,
        message: 'Account linked successfully!',
        user: result.user,
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(
        success: false,
        message: _getErrorMessage(e),
        user: null,
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Account linking failed: ${e.toString()}',
        user: null,
      );
    }
  }

  // Send password reset email
  static Future<AuthResult> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return AuthResult(
        success: true,
        message: 'Password reset email sent successfully',
        user: null,
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(
        success: false,
        message: _getErrorMessage(e),
        user: null,
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Failed to send password reset email: ${e.toString()}',
        user: null,
      );
    }
  }

  // Send email verification
  static Future<AuthResult> sendEmailVerification() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        return AuthResult(
          success: false,
          message: 'No user is currently signed in',
          user: null,
        );
      }

      await user.sendEmailVerification();
      return AuthResult(
        success: true,
        message: 'Verification email sent successfully',
        user: user,
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(
        success: false,
        message: _getErrorMessage(e),
        user: null,
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Failed to send verification email: ${e.toString()}',
        user: null,
      );
    }
  }

  // Reload current user
  static Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }

  // Sign out
  static Future<AuthResult> signOut() async {
    try {
      // Logout from backend first
      try {
        await BackendService.logout();
      } catch (e) {
        print('Backend logout failed: $e');
        // Continue with local logout even if backend fails
      }

      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
        StorageService.clearAuthData(),
      ]);

      return AuthResult(
        success: true,
        message: 'Signed out successfully',
        user: null,
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Sign out failed: ${e.toString()}',
        user: null,
      );
    }
  }

  // Delete user account
  static Future<AuthResult> deleteAccount() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        return AuthResult(
          success: false,
          message: 'No user is currently signed in',
          user: null,
        );
      }

      await user.delete();
      await StorageService.clearAuthData();

      return AuthResult(
        success: true,
        message: 'Account deleted successfully',
        user: null,
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(
        success: false,
        message: _getErrorMessage(e),
        user: null,
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Failed to delete account: ${e.toString()}',
        user: null,
      );
    }
  }

  // Save user data locally
  static Future<void> _saveUserDataLocally(User user) async {
    final userData = UserData(
      id: user.uid,
      fullName: user.displayName ?? 'User',
      email: user.email ?? '',
      isEmailVerified: user.emailVerified,
      createdAt: user.metadata.creationTime,
      lastLogin: user.metadata.lastSignInTime,
      phoneNumber: user.phoneNumber,
      photoURL: user.photoURL,
    );

    final token = await user.getIdToken();
    if (token != null) {
      await StorageService.saveAuthData(token: token, user: userData);
    }
  }

  // Generate nonce for Apple Sign In
  static String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  // SHA256 hash for Apple Sign In
  static String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Get user-friendly error messages
  static String _getErrorMessage(FirebaseAuthException e) {
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
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled. Please contact support.';
      case 'invalid-verification-code':
        return 'Invalid verification code. Please try again.';
      case 'invalid-verification-id':
        return 'Invalid verification ID. Please request a new code.';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try again later.';
      case 'credential-already-in-use':
        return 'This account is already linked to another user.';
      case 'requires-recent-login':
        return 'This operation requires recent authentication. Please sign in again.';
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }
}

// Auth result model
class AuthResult {
  final bool success;
  final String message;
  final User? user;
  final bool shouldShowBiometricSetup;

  AuthResult({
    required this.success,
    required this.message,
    this.user,
    this.shouldShowBiometricSetup = false,
  });
}

// Updated UserData model to work with Firebase
class UserData {
  final String id;
  final String fullName;
  final String email;
  final bool isEmailVerified;
  final DateTime? createdAt;
  final DateTime? lastLogin;
  final String? phoneNumber;
  final String? photoURL;

  UserData({
    required this.id,
    required this.fullName,
    required this.email,
    required this.isEmailVerified,
    this.createdAt,
    this.lastLogin,
    this.phoneNumber,
    this.photoURL,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      id: json['id'] ?? '',
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
      isEmailVerified: json['isEmailVerified'] ?? false,
      createdAt:
          json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      lastLogin:
          json['lastLogin'] != null ? DateTime.parse(json['lastLogin']) : null,
      phoneNumber: json['phoneNumber'],
      photoURL: json['photoURL'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'isEmailVerified': isEmailVerified,
      'createdAt': createdAt?.toIso8601String(),
      'lastLogin': lastLogin?.toIso8601String(),
      'phoneNumber': phoneNumber,
      'photoURL': photoURL,
    };
  }
}
