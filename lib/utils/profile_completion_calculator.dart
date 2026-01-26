import '../models/user_model.dart';

/// Calculate profile completion percentage
class ProfileCompletionCalculator {
  /// Calculate completion percentage (0-100)
  static int calculate(UserModel user) {
    int totalPoints = 0;
    int earnedPoints = 0;

    // Required fields (50 points total)
    // Display name (10 points)
    totalPoints += 10;
    if (user.displayName.isNotEmpty &&
        user.displayName != 'user${user.id.substring(0, 8)}') {
      earnedPoints += 10;
    }

    // Username (10 points)
    totalPoints += 10;
    if (user.username.isNotEmpty &&
        user.username != 'user${user.id.substring(0, 8)}') {
      earnedPoints += 10;
    }

    // Profile photo (15 points)
    totalPoints += 15;
    if (user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty) {
      earnedPoints += 15;
    }

    // Bio (15 points)
    totalPoints += 15;
    if (user.bio != null && user.bio!.isNotEmpty) {
      earnedPoints += 15;
    }

    // Optional fields (50 points total)
    // Cover photo (10 points)
    totalPoints += 10;
    if (user.coverPhotoURL != null && user.coverPhotoURL!.isNotEmpty) {
      earnedPoints += 10;
    }

    // Location (5 points)
    totalPoints += 5;
    if (user.location != null && user.location!.isNotEmpty) {
      earnedPoints += 5;
    }

    // Occupation (5 points)
    totalPoints += 5;
    if (user.occupation != null && user.occupation!.isNotEmpty) {
      earnedPoints += 5;
    }

    // Website (5 points)
    totalPoints += 5;
    if (user.website != null && user.website!.isNotEmpty) {
      earnedPoints += 5;
    }

    // Interests (10 points)
    totalPoints += 10;
    if (user.interests != null && user.interests!.isNotEmpty) {
      earnedPoints += 10;
    }

    // Gender (5 points)
    totalPoints += 5;
    if (user.gender != null && user.gender!.isNotEmpty) {
      earnedPoints += 5;
    }

    // Date of birth (5 points)
    totalPoints += 5;
    if (user.dateOfBirth != null) {
      earnedPoints += 5;
    }

    // Language (5 points)
    totalPoints += 5;
    if (user.language != null && user.language!.isNotEmpty) {
      earnedPoints += 5;
    }

    // Calculate percentage
    return ((earnedPoints / totalPoints) * 100).round();
  }

  /// Get missing fields
  static List<String> getMissingFields(UserModel user) {
    List<String> missing = [];

    // Check required fields
    if (user.displayName.isEmpty ||
        user.displayName == 'user${user.id.substring(0, 8)}') {
      missing.add('Display Name');
    }

    if (user.username.isEmpty ||
        user.username == 'user${user.id.substring(0, 8)}') {
      missing.add('Username');
    }

    if (user.profileImageUrl == null || user.profileImageUrl!.isEmpty) {
      missing.add('Profile Photo');
    }

    if (user.bio == null || user.bio!.isEmpty) {
      missing.add('Bio');
    }

    // Check optional but recommended fields
    if (user.coverPhotoURL == null || user.coverPhotoURL!.isEmpty) {
      missing.add('Cover Photo');
    }

    if (user.location == null || user.location!.isEmpty) {
      missing.add('Location');
    }

    if (user.interests == null || user.interests!.isEmpty) {
      missing.add('Interests');
    }

    return missing;
  }

  /// Check if profile is complete enough (at least 60%)
  static bool isComplete(UserModel user) {
    return calculate(user) >= 60;
  }

  /// Get completion status message
  static String getStatusMessage(int percentage) {
    if (percentage >= 90) {
      return 'Your profile is looking great! 🎉';
    } else if (percentage >= 70) {
      return 'Almost there! Add a few more details.';
    } else if (percentage >= 50) {
      return 'Good start! Complete your profile to stand out.';
    } else {
      return 'Complete your profile to get discovered!';
    }
  }
}
