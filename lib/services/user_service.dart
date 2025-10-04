import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import 'token_auth_service.dart';

class UserService {
  // Update this URL to match your backend server
  static const String baseUrl = 'https://flip-backend-mnpg.onrender.com';
  static const Duration timeoutDuration = Duration(seconds: 30);

  /// Get authentication headers (throws if not authenticated)
  static Future<Map<String, String>> _getAuthHeaders() async {
    final headers = await TokenAuthService.getAuthHeaders();
    if (headers == null) {
      throw Exception('Authentication required for this operation');
    }
    return headers;
  }

  /// Get list of users that the current user is following
  static Future<UserListResult> getFollowingUsers() async {
    try {
      print('👥 UserService: Fetching following users');

      final headers = await _getAuthHeaders();
      final uri = Uri.parse('$baseUrl/api/users/following');

      final response = await http
          .get(uri, headers: headers)
          .timeout(timeoutDuration);

      print('👥 UserService: Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final usersData = data['data'] as Map<String, dynamic>;
        final usersList = usersData['users'] as List<dynamic>;

        final users =
            usersList
                .map(
                  (userJson) =>
                      UserModel.fromJson(userJson as Map<String, dynamic>),
                )
                .toList();

        print(
          '👥 UserService: Successfully loaded ${users.length} following users',
        );

        return UserListResult(
          success: true,
          users: users,
          message:
              data['message'] as String? ??
              'Following users loaded successfully',
        );
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        throw Exception(
          errorData['message'] ?? 'Failed to load following users',
        );
      }
    } catch (e) {
      print('👥 UserService: Error loading following users: $e');
      return UserListResult(
        success: false,
        users: [],
        message: 'Failed to load following users: ${e.toString()}',
      );
    }
  }

  /// Create/sync user from Firebase user data
  static Future<void> createUserFromFirebase(
    dynamic firebaseUser, {
    String? username,
  }) async {
    // This method syncs Firebase user data with your backend
    // For now, we'll just log the action since the backend sync
    // is handled elsewhere in your app
    print('👥 UserService: Syncing Firebase user ${firebaseUser.uid}');

    // You can implement actual backend sync logic here if needed
    // For example, calling your backend API to create/update user
  }

  /// Initialize user data after login
  static Future<void> initializeUser() async {
    print('👥 UserService: Initializing user');
    // Initialize user data, load preferences, etc.
  }

  /// Update user's last active timestamp
  static Future<void> updateLastActive() async {
    print('👥 UserService: Updating last active timestamp');
    // Update last active time in backend if needed
  }

  /// Clear user data (for logout)
  static Future<void> clearUser() async {
    print('👥 UserService: Clearing user data');
    // Clear any cached user data here
  }

  /// Format follower count for display (e.g., 1.2K, 1.5M)
  static String formatFollowerCount(int count) {
    if (count < 1000) {
      return count.toString();
    } else if (count < 1000000) {
      double k = count / 1000.0;
      return k % 1 == 0 ? '${k.toInt()}K' : '${k.toStringAsFixed(1)}K';
    } else {
      double m = count / 1000000.0;
      return m % 1 == 0 ? '${m.toInt()}M' : '${m.toStringAsFixed(1)}M';
    }
  }
}

/// Result class for user list API responses
class UserListResult {
  final bool success;
  final List<UserModel> users;
  final String message;

  const UserListResult({
    required this.success,
    required this.users,
    required this.message,
  });
}
