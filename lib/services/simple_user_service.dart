import 'dart:developer' as developer;
import 'token_auth_service.dart';
import 'backend_service.dart';

/// Simplified user service that works with token-based authentication
/// Replaces the complex UserService that relied on local storage and Riverpod
class SimpleUserService {
  /// Get current user from token auth service
  static TokenUser? get currentUser => TokenAuthService.currentUser;

  /// Check if user is authenticated
  static bool get isAuthenticated => TokenAuthService.isAuthenticated;

  /// Update user profile
  static Future<TokenUser?> updateProfile({
    String? displayName,
    String? bio,
    String? website,
    String? location,
    DateTime? dateOfBirth,
    List<String>? interests,
    String? profileImageUrl,
    String? coverImageUrl,
  }) async {
    try {
      final profileData = <String, dynamic>{};

      if (displayName != null) profileData['displayName'] = displayName;
      if (bio != null) profileData['bio'] = bio;
      if (website != null) profileData['website'] = website;
      if (location != null) profileData['location'] = location;
      if (dateOfBirth != null)
        profileData['dateOfBirth'] = dateOfBirth.toIso8601String();
      if (interests != null) profileData['interests'] = interests;
      if (profileImageUrl != null)
        profileData['profileImageUrl'] = profileImageUrl;
      if (coverImageUrl != null) profileData['coverImageUrl'] = coverImageUrl;

      final backendUser = await BackendService.updateUserProfile(profileData);

      // Convert backend user to token user (simplified)
      final updatedUser = TokenUser(
        id: backendUser.id,
        firebaseUid: backendUser.firebaseUid,
        email: backendUser.email,
        displayName: backendUser.displayName,
        phoneNumber: backendUser.phoneNumber,
        photoURL: backendUser.photoURL,
        emailVerified: backendUser.emailVerified,
        role: backendUser.role,
        isActive: backendUser.isActive,
        createdAt: backendUser.createdAt,
        lastLogin: backendUser.lastLogin,
      );

      developer.log(
        'User profile updated successfully',
        name: 'SimpleUserService',
      );
      return updatedUser;
    } catch (e) {
      developer.log(
        'Failed to update user profile: $e',
        name: 'SimpleUserService',
      );
      rethrow;
    }
  }

  /// Search users
  static Future<List<TokenUser>> searchUsers(
    String query, {
    int limit = 20,
  }) async {
    try {
      // This would need to be implemented in the backend service
      // For now, return empty list
      developer.log(
        'User search not implemented yet',
        name: 'SimpleUserService',
      );
      return [];
    } catch (e) {
      developer.log('Failed to search users: $e', name: 'SimpleUserService');
      return [];
    }
  }

  /// Get user by ID
  static Future<TokenUser?> getUserById(String userId) async {
    try {
      // This would need to be implemented in the backend service
      developer.log(
        'Get user by ID not implemented yet',
        name: 'SimpleUserService',
      );
      return null;
    } catch (e) {
      developer.log('Failed to get user by ID: $e', name: 'SimpleUserService');
      return null;
    }
  }

  /// Utility methods
  static String formatFollowerCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  static String getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  static bool isValidUsername(String username) {
    if (username.length < 3 || username.length > 30) return false;
    return RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username);
  }

  static bool isValidBio(String bio) {
    return bio.length <= 150;
  }
}
