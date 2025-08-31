import 'dart:math';

/// Utility class to generate random usernames similar to TikTok style
class UsernameGenerator {
  static final Random _random = Random();

  // Cool adjectives for username generation
  static const List<String> _adjectives = [
    'cool',
    'epic',
    'super',
    'mega',
    'ultra',
    'pro',
    'ace',
    'star',
    'fire',
    'ice',
    'neon',
    'cyber',
    'pixel',
    'nova',
    'zen',
    'flux',
    'vibe',
    'wave',
    'glow',
    'spark',
    'bolt',
    'dash',
    'swift',
    'flash',
    'ghost',
    'shadow',
    'mystic',
    'cosmic',
    'lunar',
    'solar',
    'royal',
    'elite',
    'prime',
    'alpha',
    'beta',
    'gamma',
    'delta',
    'omega',
    'turbo',
    'nitro',
    'hyper',
    'max',
    'plus',
    'x',
    'neo',
    'retro',
  ];

  // Fun nouns for username generation
  static const List<String> _nouns = [
    'user',
    'player',
    'gamer',
    'ninja',
    'warrior',
    'hero',
    'legend',
    'master',
    'chief',
    'captain',
    'pilot',
    'rider',
    'hunter',
    'seeker',
    'creator',
    'builder',
    'maker',
    'artist',
    'dancer',
    'singer',
    'dreamer',
    'explorer',
    'adventurer',
    'traveler',
    'wanderer',
    'phoenix',
    'dragon',
    'tiger',
    'wolf',
    'eagle',
    'falcon',
    'hawk',
    'lion',
    'panther',
    'shark',
    'dolphin',
    'whale',
    'fox',
    'bear',
    'storm',
    'thunder',
    'lightning',
    'comet',
    'meteor',
    'galaxy',
    'planet',
    'star',
    'moon',
    'sun',
    'ocean',
    'mountain',
    'forest',
  ];

  /// Generate a random username using timestamp-based approach
  /// Format: adjective + noun + timestamp_suffix
  /// Example: cooluser123456, epicninja789012
  static String generateFromTimestamp({DateTime? timestamp}) {
    final now = timestamp ?? DateTime.now();

    // Use milliseconds since epoch for uniqueness
    final timeString = now.millisecondsSinceEpoch.toString();

    // Take last 6 digits for shorter suffix
    final suffix = timeString.substring(timeString.length - 6);

    // Random adjective and noun
    final adjective = _adjectives[_random.nextInt(_adjectives.length)];
    final noun = _nouns[_random.nextInt(_nouns.length)];

    return '$adjective$noun$suffix';
  }

  /// Generate a random username using date-based approach
  /// Format: adjective + noun + YYMMDD + random_digits
  /// Example: cooluser250125, epicninja250125
  static String generateFromDate({DateTime? date}) {
    final now = date ?? DateTime.now();

    // Format: YYMMDD
    final year = (now.year % 100).toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final dateString = '$year$month$day';

    // Add 2 random digits for uniqueness
    final randomDigits = _random.nextInt(100).toString().padLeft(2, '0');

    // Random adjective and noun
    final adjective = _adjectives[_random.nextInt(_adjectives.length)];
    final noun = _nouns[_random.nextInt(_nouns.length)];

    return '$adjective$noun$dateString$randomDigits';
  }

  /// Generate a TikTok-style username
  /// Format: user + random_numbers (6-8 digits)
  /// Example: user123456, user78901234
  static String generateTikTokStyle() {
    // Generate 6-8 digit number
    final digitCount = 6 + _random.nextInt(3); // 6, 7, or 8 digits
    final maxNumber = pow(10, digitCount).toInt() - 1;
    final minNumber = pow(10, digitCount - 1).toInt();

    final number = minNumber + _random.nextInt(maxNumber - minNumber);

    return 'user$number';
  }

  /// Generate a username with phone number suffix
  /// Format: user + last_4_digits_of_phone + random_digits
  /// Example: user1234567, user987654321
  static String generateFromPhone(String phoneNumber) {
    // Extract digits from phone number
    final digits = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    // Get last 4 digits of phone number
    final phoneSuffix =
        digits.length >= 4
            ? digits.substring(digits.length - 4)
            : digits.padLeft(4, '0');

    // Add 2-3 random digits
    final randomDigits = _random.nextInt(1000).toString().padLeft(3, '0');

    return 'user$phoneSuffix$randomDigits';
  }

  /// Generate multiple username suggestions
  static List<String> generateSuggestions({
    int count = 5,
    String? phoneNumber,
    DateTime? signupDate,
  }) {
    final suggestions = <String>[];

    for (int i = 0; i < count; i++) {
      switch (i % 4) {
        case 0:
          suggestions.add(generateTikTokStyle());
          break;
        case 1:
          suggestions.add(generateFromTimestamp(timestamp: signupDate));
          break;
        case 2:
          suggestions.add(generateFromDate(date: signupDate));
          break;
        case 3:
          if (phoneNumber != null) {
            suggestions.add(generateFromPhone(phoneNumber));
          } else {
            suggestions.add(generateTikTokStyle());
          }
          break;
      }
    }

    // Remove duplicates and return
    return suggestions.toSet().toList();
  }

  /// Validate if a username is available (placeholder for backend check)
  static Future<bool> isUsernameAvailable(String username) async {
    // TODO: Implement backend check
    // For now, return true as placeholder
    return true;
  }

  /// Generate a guaranteed unique username by adding suffix if needed
  static Future<String> generateUniqueUsername({
    String? phoneNumber,
    DateTime? signupDate,
  }) async {
    String baseUsername = generateTikTokStyle();

    // Try the base username first
    if (await isUsernameAvailable(baseUsername)) {
      return baseUsername;
    }

    // If not available, try with different suffixes
    for (int i = 1; i <= 10; i++) {
      final modifiedUsername = '${baseUsername}_$i';
      if (await isUsernameAvailable(modifiedUsername)) {
        return modifiedUsername;
      }
    }

    // Fallback: generate completely new username
    return generateFromTimestamp(timestamp: signupDate);
  }
}
