import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:developer' as developer;

import '../models/user_model.dart';
import 'storage_service.dart';
import 'backend_service.dart';

class UserService {
  static UserModel? _currentUser;
  static final List<Function(UserModel?)> _userChangeListeners = [];

  // Current user getter
  static UserModel? get currentUser => _currentUser;

  // Add listener for user changes
  static void addUserChangeListener(Function(UserModel?) listener) {
    _userChangeListeners.add(listener);
  }

  // Remove listener
  static void removeUserChangeListener(Function(UserModel?) listener) {
    _userChangeListeners.remove(listener);
  }

  // Notify all listeners of user changes
  static void _notifyUserChange() {
    for (final listener in _userChangeListeners) {
      try {
        listener(_currentUser);
      } catch (e) {
        developer.log('Error in user change listener: $e', name: 'UserService');
      }
    }
  }

  // Initialize user from storage
  static Future<void> initializeUser() async {
    try {
      final userData = await StorageService.getUserModelData();
      if (userData != null) {
        _currentUser = UserModel.fromJson(userData);
        _notifyUserChange();
        developer.log(
          'User initialized from storage: ${_currentUser?.username}',
          name: 'UserService',
        );

        // Try to refresh from backend in the background
        _refreshUserFromBackend();
      }
    } catch (e) {
      developer.log(
        'Failed to initialize user from storage: $e',
        name: 'UserService',
      );
    }
  }

  // Refresh user data from backend
  static Future<void> _refreshUserFromBackend() async {
    try {
      final syncResult = await BackendService.syncUser();
      if (syncResult.success && syncResult.user != null) {
        final updatedUser = UserModel.fromBackendUser(syncResult.user!);
        _currentUser = updatedUser;
        await _saveUserLocally(updatedUser);
        _notifyUserChange();

        developer.log(
          'User refreshed from backend: ${updatedUser.username}',
          name: 'UserService',
        );
      }
    } catch (e) {
      developer.log(
        'Failed to refresh user from backend: $e',
        name: 'UserService',
      );
      // Don't throw - this is a background operation
    }
  }

  // Create user from Firebase auth
  static Future<UserModel> createUserFromFirebase(
    User firebaseUser, {
    String? username,
    String? bio,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Create user model
      final userModel = UserModel.fromFirebaseUser(
        firebaseUser,
        username: username,
        bio: bio,
        additionalData: additionalData,
      );

      // Save to backend
      await _syncUserToBackend(userModel);

      // Save locally
      await _saveUserLocally(userModel);

      // Set as current user
      _currentUser = userModel;
      _notifyUserChange();

      developer.log(
        'User created successfully: ${userModel.username}',
        name: 'UserService',
      );
      return userModel;
    } catch (e) {
      developer.log(
        'Failed to create user from Firebase: $e',
        name: 'UserService',
      );
      rethrow;
    }
  }

  // Update current user
  static Future<UserModel> updateUser(UserModel updatedUser) async {
    try {
      final user = updatedUser.copyWith(updatedAt: DateTime.now());

      // Update backend
      await _syncUserToBackend(user);

      // Update locally
      await _saveUserLocally(user);

      // Update current user
      _currentUser = user;
      _notifyUserChange();

      developer.log(
        'User updated successfully: ${user.username}',
        name: 'UserService',
      );
      return user;
    } catch (e) {
      developer.log('Failed to update user: $e', name: 'UserService');
      rethrow;
    }
  }

  // Update user profile
  static Future<UserModel> updateProfile({
    String? displayName,
    String? bio,
    String? website,
    String? location,
    DateTime? dateOfBirth,
    List<String>? interests,
    String? profileImageUrl,
    String? coverImageUrl,
  }) async {
    if (_currentUser == null) {
      throw Exception('No current user to update');
    }

    final updatedUser = _currentUser!.copyWith(
      displayName: displayName,
      bio: bio,
      website: website,
      location: location,
      dateOfBirth: dateOfBirth,
      interests: interests,
      profileImageUrl: profileImageUrl,
      coverImageUrl: coverImageUrl,
    );

    return await updateUser(updatedUser);
  }

  // Update privacy settings
  static Future<UserModel> updatePrivacySettings(
    Map<String, bool> privacySettings,
  ) async {
    if (_currentUser == null) {
      throw Exception('No current user to update');
    }

    final updatedUser = _currentUser!.copyWith(
      privacySettings: {..._currentUser!.privacySettings, ...privacySettings},
    );

    return await updateUser(updatedUser);
  }

  // Update notification settings
  static Future<UserModel> updateNotificationSettings(
    Map<String, bool> notificationSettings,
  ) async {
    if (_currentUser == null) {
      throw Exception('No current user to update');
    }

    final updatedUser = _currentUser!.copyWith(
      notificationSettings: {
        ..._currentUser!.notificationSettings,
        ...notificationSettings,
      },
    );

    return await updateUser(updatedUser);
  }

  // Follow/Unfollow user
  static Future<void> followUser(String targetUserId) async {
    try {
      await _makeBackendRequest('POST', '/users/follow', {
        'targetUserId': targetUserId,
      });

      // Update local follower count
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(
          followingCount: _currentUser!.followingCount + 1,
        );
        await _saveUserLocally(_currentUser!);
        _notifyUserChange();
      }

      developer.log(
        'Successfully followed user: $targetUserId',
        name: 'UserService',
      );
    } catch (e) {
      developer.log('Failed to follow user: $e', name: 'UserService');
      rethrow;
    }
  }

  static Future<void> unfollowUser(String targetUserId) async {
    try {
      await _makeBackendRequest('POST', '/users/unfollow', {
        'targetUserId': targetUserId,
      });

      // Update local follower count
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(
          followingCount:
              (_currentUser!.followingCount - 1)
                  .clamp(0, double.infinity)
                  .toInt(),
        );
        await _saveUserLocally(_currentUser!);
        _notifyUserChange();
      }

      developer.log(
        'Successfully unfollowed user: $targetUserId',
        name: 'UserService',
      );
    } catch (e) {
      developer.log('Failed to unfollow user: $e', name: 'UserService');
      rethrow;
    }
  }

  // Block/Unblock user
  static Future<void> blockUser(String targetUserId) async {
    if (_currentUser == null) return;

    try {
      await _makeBackendRequest('POST', '/users/block', {
        'targetUserId': targetUserId,
      });

      // Update local blocked users list
      final blockedUsers = List<String>.from(_currentUser!.blockedUsers);
      if (!blockedUsers.contains(targetUserId)) {
        blockedUsers.add(targetUserId);
        _currentUser = _currentUser!.copyWith(blockedUsers: blockedUsers);
        await _saveUserLocally(_currentUser!);
        _notifyUserChange();
      }

      developer.log(
        'Successfully blocked user: $targetUserId',
        name: 'UserService',
      );
    } catch (e) {
      developer.log('Failed to block user: $e', name: 'UserService');
      rethrow;
    }
  }

  static Future<void> unblockUser(String targetUserId) async {
    if (_currentUser == null) return;

    try {
      await _makeBackendRequest('POST', '/users/unblock', {
        'targetUserId': targetUserId,
      });

      // Update local blocked users list
      final blockedUsers = List<String>.from(_currentUser!.blockedUsers);
      blockedUsers.remove(targetUserId);
      _currentUser = _currentUser!.copyWith(blockedUsers: blockedUsers);
      await _saveUserLocally(_currentUser!);
      _notifyUserChange();

      developer.log(
        'Successfully unblocked user: $targetUserId',
        name: 'UserService',
      );
    } catch (e) {
      developer.log('Failed to unblock user: $e', name: 'UserService');
      rethrow;
    }
  }

  // Search users
  static Future<List<UserModel>> searchUsers(
    String query, {
    int limit = 20,
  }) async {
    try {
      final response = await _makeBackendRequest('GET', '/users/search', {
        'query': query,
        'limit': limit.toString(),
      });

      final List<dynamic> usersJson = response['users'] ?? [];
      return usersJson.map((json) => UserModel.fromJson(json)).toList();
    } catch (e) {
      developer.log('Failed to search users: $e', name: 'UserService');
      return [];
    }
  }

  // Get user by ID
  static Future<UserModel?> getUserById(String userId) async {
    try {
      final response = await _makeBackendRequest('GET', '/users/$userId', {});
      if (response['user'] != null) {
        return UserModel.fromJson(response['user']);
      }
      return null;
    } catch (e) {
      developer.log('Failed to get user by ID: $e', name: 'UserService');
      return null;
    }
  }

  // Get user by username
  static Future<UserModel?> getUserByUsername(String username) async {
    try {
      final response = await _makeBackendRequest(
        'GET',
        '/users/username/$username',
        {},
      );
      if (response['user'] != null) {
        return UserModel.fromJson(response['user']);
      }
      return null;
    } catch (e) {
      developer.log('Failed to get user by username: $e', name: 'UserService');
      return null;
    }
  }

  // Get followers
  static Future<List<UserModel>> getFollowers(
    String userId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _makeBackendRequest(
        'GET',
        '/users/$userId/followers',
        {'limit': limit.toString(), 'offset': offset.toString()},
      );

      final List<dynamic> usersJson = response['followers'] ?? [];
      return usersJson.map((json) => UserModel.fromJson(json)).toList();
    } catch (e) {
      developer.log('Failed to get followers: $e', name: 'UserService');
      return [];
    }
  }

  // Get following
  static Future<List<UserModel>> getFollowing(
    String userId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _makeBackendRequest(
        'GET',
        '/users/$userId/following',
        {'limit': limit.toString(), 'offset': offset.toString()},
      );

      final List<dynamic> usersJson = response['following'] ?? [];
      return usersJson.map((json) => UserModel.fromJson(json)).toList();
    } catch (e) {
      developer.log('Failed to get following: $e', name: 'UserService');
      return [];
    }
  }

  // Update last active
  static Future<void> updateLastActive() async {
    if (_currentUser == null) return;

    try {
      _currentUser = _currentUser!.copyWith(lastActiveAt: DateTime.now());
      await _saveUserLocally(_currentUser!);

      // Update backend in background (don't await)
      _syncUserToBackend(_currentUser!).catchError((e) {
        developer.log(
          'Failed to sync last active to backend: $e',
          name: 'UserService',
        );
      });
    } catch (e) {
      developer.log('Failed to update last active: $e', name: 'UserService');
    }
  }

  // Clear user data (logout)
  static Future<void> clearUser() async {
    try {
      _currentUser = null;
      await StorageService.clearUserModelData();
      _notifyUserChange();
      developer.log('User data cleared', name: 'UserService');
    } catch (e) {
      developer.log('Failed to clear user data: $e', name: 'UserService');
    }
  }

  // Check if username is available
  static Future<bool> isUsernameAvailable(String username) async {
    try {
      final response = await _makeBackendRequest(
        'GET',
        '/users/check-username',
        {'username': username},
      );
      return response['available'] ?? false;
    } catch (e) {
      developer.log(
        'Failed to check username availability: $e',
        name: 'UserService',
      );
      return false;
    }
  }

  // Upload profile image
  static Future<String?> uploadProfileImage(File imageFile) async {
    try {
      // This would typically upload to a service like Firebase Storage
      // For now, return a placeholder URL
      await Future.delayed(const Duration(seconds: 2)); // Simulate upload
      final imageUrl =
          'https://example.com/profile/${_currentUser?.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Update user with new profile image
      if (_currentUser != null) {
        await updateProfile(profileImageUrl: imageUrl);
      }

      return imageUrl;
    } catch (e) {
      developer.log('Failed to upload profile image: $e', name: 'UserService');
      return null;
    }
  }

  // Private helper methods
  static Future<void> _syncUserToBackend(UserModel user) async {
    try {
      final syncResult = await BackendService.syncUser();

      // If sync was successful and we got user data back, update our local user
      if (syncResult.success && syncResult.user != null) {
        final updatedUser = UserModel.fromBackendUser(syncResult.user!);
        _currentUser = updatedUser;
        await _saveUserLocally(updatedUser);
        _notifyUserChange();

        developer.log(
          'User synced and updated from backend: ${updatedUser.username}',
          name: 'UserService',
        );
      } else {
        developer.log(
          'User synced to backend: ${user.username}',
          name: 'UserService',
        );
      }
    } catch (e) {
      developer.log('Failed to sync user to backend: $e', name: 'UserService');
      // Don't rethrow - allow local operations to continue
    }
  }

  static Future<void> _saveUserLocally(UserModel user) async {
    try {
      await StorageService.saveUserModelData(user.toJson());
      developer.log(
        'User saved locally: ${user.username}',
        name: 'UserService',
      );
    } catch (e) {
      developer.log('Failed to save user locally: $e', name: 'UserService');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> _makeBackendRequest(
    String method,
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    try {
      final url = Uri.parse('${BackendService.baseUrl}$endpoint');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization':
            'Bearer ${await FirebaseAuth.instance.currentUser?.getIdToken()}',
      };

      http.Response response;
      switch (method.toUpperCase()) {
        case 'GET':
          final queryParams = data.entries
              .map((e) => '${e.key}=${e.value}')
              .join('&');
          final getUrl =
              queryParams.isNotEmpty ? Uri.parse('$url?$queryParams') : url;
          response = await http.get(getUrl, headers: headers);
          break;
        case 'POST':
          response = await http.post(
            url,
            headers: headers,
            body: jsonEncode(data),
          );
          break;
        case 'PUT':
          response = await http.put(
            url,
            headers: headers,
            body: jsonEncode(data),
          );
          break;
        case 'DELETE':
          response = await http.delete(url, headers: headers);
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Backend request failed: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      developer.log('Backend request failed: $e', name: 'UserService');
      rethrow;
    }
  }

  // Utility methods
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
