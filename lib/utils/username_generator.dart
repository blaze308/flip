import 'dart:math';

/// Utility class for generating and managing usernames
class UsernameGenerator {
  /// Generate a consistent display name based on user data and signup method
  ///
  /// Priority:
  /// 1. Google Sign-in: displayName (e.g., "John Doe")
  /// 2. Email Sign-up: firstName from profile
  /// 3. Phone Sign-up: Generate random username (TikTok style)
  /// 4. Fallback: "user" + random 7-digit number
  static String generateDisplayName({
    String? displayName,
    String? firstName,
    String? email,
    String? phoneNumber,
    String? userId,
  }) {
    // 1. If displayName exists (Google sign-in), use it
    if (displayName != null && displayName.trim().isNotEmpty) {
      return displayName.trim();
    }

    // 2. If firstName exists (email sign-up with full name), use it
    if (firstName != null && firstName.trim().isNotEmpty) {
      return firstName.trim();
    }

    // 3. If email exists, use the part before @
    if (email != null && email.trim().isNotEmpty) {
      final emailUsername = email.split('@')[0];
      // Capitalize first letter
      return emailUsername[0].toUpperCase() + emailUsername.substring(1);
    }

    // 4. If phone number exists, generate TikTok-style username
    if (phoneNumber != null && phoneNumber.trim().isNotEmpty) {
      return generateRandomUsername(seed: phoneNumber);
    }

    // 5. Use userId as seed for consistent random username
    if (userId != null && userId.isNotEmpty) {
      return generateRandomUsername(seed: userId);
    }

    // 6. Last fallback
    return 'user${Random().nextInt(9999999)}';
  }

  /// Generate a TikTok-style username: "user" + 7 random digits/letters
  /// Uses seed for consistency (same user always gets same random username)
  static String generateRandomUsername({String? seed}) {
    if (seed != null && seed.isNotEmpty) {
      // Use seed to generate consistent random numbers
      final random = Random(seed.hashCode);
      final chars = '0123456789abcdefghijklmnopqrstuvwxyz';
      final code =
          List.generate(
            7,
            (index) => chars[random.nextInt(chars.length)],
          ).join();
      return 'user$code';
    }

    // Truly random if no seed
    final random = Random();
    final chars = '0123456789abcdefghijklmnopqrstuvwxyz';
    final code =
        List.generate(7, (index) => chars[random.nextInt(chars.length)]).join();
    return 'user$code';
  }

  /// Get username for stories/posts (short form)
  /// Priority:
  /// 1. displayName first word (e.g., "John" from "John Doe")
  /// 2. firstName
  /// 3. Email username
  /// 4. Random username
  static String getShortUsername({
    String? displayName,
    String? firstName,
    String? email,
    String? phoneNumber,
    String? userId,
  }) {
    // If displayName exists, get first word
    if (displayName != null && displayName.trim().isNotEmpty) {
      final parts = displayName.trim().split(' ');
      return parts[0]; // Just first name
    }

    // Otherwise use full logic
    return generateDisplayName(
      displayName: displayName,
      firstName: firstName,
      email: email,
      phoneNumber: phoneNumber,
      userId: userId,
    );
  }

  /// Check if username is a generated random one (starts with "user")
  static bool isGeneratedUsername(String username) {
    return username.toLowerCase().startsWith('user') &&
        username.length > 4 &&
        RegExp(r'^user[0-9a-z]+$').hasMatch(username.toLowerCase());
  }

  /// Format full name from firstName and lastName
  static String formatFullName(String? firstName, String? lastName) {
    if (firstName == null || firstName.trim().isEmpty) {
      return lastName?.trim() ?? '';
    }
    if (lastName == null || lastName.trim().isEmpty) {
      return firstName.trim();
    }
    return '${firstName.trim()} ${lastName.trim()}';
  }
}
