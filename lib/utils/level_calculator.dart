/// Level Calculator Utility
/// Calculates level progress for Wealth and Live levels
class LevelCalculator {
  // Wealth Level Thresholds (200 levels based on coins sent)
  static const List<int> wealthThresholds = [
    0, 3000, 6000, 16000, 30000, 52000, 85000, 137000, 214000, 323000, 492000,
    741000, 1100000, 1690000, 2528000, 3637000, 5137000, 7337000, 10137000,
    14137000, 19137000, 26137000, 35137000, 47137000, 62137000, 81137000,
    105137000, 135137000, 172137000, 218137000, 275137000, 345137000,
    430137000, 533137000, 657137000, 805137000, 981137000, 1189137000,
    1433137000, 1717137000, 2047137000, // ... (200 levels total)
  ];

  // Live Level Thresholds (40 levels based on gifts received)
  static const List<int> liveThresholds = [
    0, 10000, 70000, 250000, 630000, 1410000, 3010000, 5710000, 10310000,
    18110000, 31010000, 52010000, 85010000, 137010000, 214010000, 323010000,
    492010000, 741010000, 1100010000, 1689010000, 2528010000, 3637010000,
    5137010000, 7337010000, 10137010000, 14137010000, 19137010000, 26137010000,
    35137010000, 47137010000, 62137010000, 81137010000, 105137010000,
    135137010000, 172137010000, 218137010000, 275137010000, 345137010000,
    430137010000, 533137010000, 657137010000, // 40 levels total
  ];

  /// Calculate wealth level progress
  /// Returns: {level, current, required, progress}
  static Map<String, dynamic> calculateWealthProgress(int creditsSent, int currentLevel) {
    if (currentLevel >= wealthThresholds.length - 1) {
      // Max level reached
      return {
        'level': currentLevel,
        'current': creditsSent,
        'required': creditsSent,
        'progress': 1.0,
        'isMaxLevel': true,
      };
    }

    final currentThreshold = wealthThresholds[currentLevel];
    final nextThreshold = wealthThresholds[currentLevel + 1];
    final progress = (creditsSent - currentThreshold) / (nextThreshold - currentThreshold);

    return {
      'level': currentLevel,
      'current': creditsSent - currentThreshold,
      'required': nextThreshold - currentThreshold,
      'progress': progress.clamp(0.0, 1.0),
      'isMaxLevel': false,
      'nextLevel': currentLevel + 1,
    };
  }

  /// Calculate live level progress
  /// Returns: {level, current, required, progress}
  static Map<String, dynamic> calculateLiveProgress(int giftsReceived, int currentLevel) {
    if (currentLevel >= liveThresholds.length - 1) {
      // Max level reached
      return {
        'level': currentLevel,
        'current': giftsReceived,
        'required': giftsReceived,
        'progress': 1.0,
        'isMaxLevel': true,
      };
    }

    final currentThreshold = liveThresholds[currentLevel];
    final nextThreshold = liveThresholds[currentLevel + 1];
    final progress = (giftsReceived - currentThreshold) / (nextThreshold - currentThreshold);

    return {
      'level': currentLevel,
      'current': giftsReceived - currentThreshold,
      'required': nextThreshold - currentThreshold,
      'progress': progress.clamp(0.0, 1.0),
      'isMaxLevel': false,
      'nextLevel': currentLevel + 1,
    };
  }

  /// Format number with K, M, B suffixes
  static String formatNumber(int number) {
    if (number >= 1000000000) {
      return '${(number / 1000000000).toStringAsFixed(1)}B';
    } else if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}

