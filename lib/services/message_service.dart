/// Service for managing user-friendly messages and developer logging
class MessageService {
  // Authentication Messages
  static const Map<String, String> authMessages = {
    // Success messages
    'registration_success':
        '🎉 Welcome! Your account has been created successfully.',
    'login_success': '👋 Welcome back! You\'re now logged in.',
    'logout_success': '👋 You\'ve been logged out successfully.',
    'password_reset_sent':
        '📧 Password reset link sent! Check your email inbox.',
    'password_reset_success':
        '✅ Password updated successfully! Please log in with your new password.',
    'verification_success': '✅ Verification successful!',
    'biometric_setup_success': '🔐 Biometric authentication is now enabled.',
    'biometric_login_success': '🔐 Biometric login successful!',

    // Error messages
    'registration_failed':
        '😔 Couldn\'t create your account right now. Please try again.',
    'login_failed':
        '😔 Login failed. Please check your credentials and try again.',
    'invalid_email': '📧 Please enter a valid email address.',
    'weak_password':
        '🔒 Please choose a stronger password (8+ characters with uppercase, lowercase, and numbers).',
    'email_already_exists':
        '📧 This email is already registered. Try logging in instead.',
    'user_not_found':
        '👤 No account found with this email. Please check or sign up.',
    'wrong_password': '🔒 Incorrect password. Please try again.',
    'too_many_requests':
        '⏰ Too many attempts. Please wait a moment before trying again.',
    'network_error':
        '📶 Connection issue. Please check your internet and try again.',
    'backend_sync_failed':
        '⚠️ Account created but sync incomplete. You can continue or retry.',
    'verification_failed':
        '❌ Verification failed. Please check the code and try again.',
    'biometric_not_available':
        '🔐 Biometric authentication is not available on this device.',
    'biometric_setup_failed':
        '😔 Couldn\'t set up biometric authentication. Please try again.',

    // Warning messages
    'email_not_verified': '📧 Please verify your email address to continue.',
    'session_expired': '⏰ Your session has expired. Please log in again.',
    'account_disabled':
        '🚫 Your account has been temporarily disabled. Contact support.',

    // Info messages
    'loading': '⏳ Please wait...',
    'processing': '🔄 Processing your request...',
    'sending_code': '📱 Sending verification code...',
    'verifying': '🔍 Verifying...',
  };

  // Network Messages
  static const Map<String, String> networkMessages = {
    'connection_timeout':
        '⏰ Request timed out. Please check your connection and try again.',
    'server_error': '🔧 Server is having issues. Please try again in a moment.',
    'no_internet': '📶 No internet connection. Please check your network.',
    'sync_success': '✅ Data synced successfully!',
    'sync_failed':
        '📶 Sync failed. Your data will be saved when connection is restored.',
  };

  // General Messages
  static const Map<String, String> generalMessages = {
    'success': '✅ Success!',
    'error': '❌ Something went wrong. Please try again.',
    'warning': '⚠️ Please check and try again.',
    'info': 'ℹ️ Information',
    'coming_soon': '🚀 This feature is coming soon!',
    'feature_unavailable': '🔧 This feature is temporarily unavailable.',
    'invalid_input': '📝 Please check your input and try again.',
    'operation_cancelled': '🚫 Operation cancelled.',
    'permission_denied': '🔒 Permission required to continue.',
  };

  /// Get a user-friendly message by key
  static String getMessage(String key, [Map<String, String>? customMessages]) {
    // Check custom messages first
    if (customMessages != null && customMessages.containsKey(key)) {
      return customMessages[key]!;
    }

    // Check auth messages
    if (authMessages.containsKey(key)) {
      return authMessages[key]!;
    }

    // Check network messages
    if (networkMessages.containsKey(key)) {
      return networkMessages[key]!;
    }

    // Check general messages
    if (generalMessages.containsKey(key)) {
      return generalMessages[key]!;
    }

    // Fallback to a generic message
    return '📱 $key';
  }

  /// Get error message based on Firebase error code
  static String getFirebaseErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'user-not-found':
        return getMessage('user_not_found');
      case 'wrong-password':
        return getMessage('wrong_password');
      case 'email-already-in-use':
        return getMessage('email_already_exists');
      case 'weak-password':
        return getMessage('weak_password');
      case 'invalid-email':
        return getMessage('invalid_email');
      case 'too-many-requests':
        return getMessage('too_many_requests');
      case 'network-request-failed':
        return getMessage('network_error');
      case 'user-disabled':
        return getMessage('account_disabled');
      default:
        return getMessage('error');
    }
  }

  /// Get network error message based on exception type
  static String getNetworkErrorMessage(String exceptionType) {
    switch (exceptionType) {
      case 'SocketException':
        return getMessage('no_internet');
      case 'TimeoutException':
        return getMessage('connection_timeout');
      case 'HttpException':
        return getMessage('server_error');
      default:
        return getMessage('network_error');
    }
  }
}
