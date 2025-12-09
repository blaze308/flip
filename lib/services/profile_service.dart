import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import 'token_auth_service.dart';

/// Custom exception for profile service errors
class ProfileServiceException implements Exception {
  final String message;
  final int? statusCode;

  ProfileServiceException(this.message, {this.statusCode});

  @override
  String toString() =>
      'ProfileServiceException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}

/// Profile Service
/// Handles all profile-related API calls
class ProfileService {
  static const String baseUrl = 'https://flip-backend-mnpg.onrender.com/api';

  /// Get current user's profile
  static Future<UserModel?> getMyProfile() async {
    try {
      final headers = await TokenAuthService.getAuthHeaders();
      if (headers == null) {
        print('❌ ProfileService: No auth headers');
        throw ProfileServiceException('Authentication required');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/users/profile'),
        headers: headers,
      );

      print('📱 ProfileService.getMyProfile: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return UserModel.fromJson(data['data']['user']);
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Token invalid or expired
        throw ProfileServiceException(
          'Authentication failed',
          statusCode: response.statusCode,
        );
      } else if (response.statusCode == 404) {
        // User not found (token might be for deleted user)
        throw ProfileServiceException(
          'User not found',
          statusCode: response.statusCode,
        );
      }

      print('❌ ProfileService.getMyProfile failed: ${response.body}');
      throw ProfileServiceException(
        'Failed to load profile',
        statusCode: response.statusCode,
      );
    } catch (e) {
      print('❌ ProfileService.getMyProfile error: $e');
      return null;
    }
  }

  /// Get another user's profile by ID
  static Future<UserModel?> getUserProfile(String userId) async {
    try {
      final headers = await TokenAuthService.getAuthHeaders();
      if (headers == null) {
        print('❌ ProfileService: No auth headers');
        return null;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId'),
        headers: headers,
      );

      print('📱 ProfileService.getUserProfile: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return UserModel.fromJson(data['data']['user']);
        }
      }

      print('❌ ProfileService.getUserProfile failed: ${response.body}');
      return null;
    } catch (e) {
      print('❌ ProfileService.getUserProfile error: $e');
      return null;
    }
  }

  /// Update profile
  static Future<Map<String, dynamic>> updateProfile({
    String? displayName,
    String? photoURL,
    String? firstName,
    String? lastName,
    String? bio,
    DateTime? dateOfBirth,
    String? gender,
    String? country,
    String? state,
    String? city,
    String? website,
    String? occupation,
    List<String>? interests,
    String? coverPhotoURL,
    String? language,
    String? timezone,
  }) async {
    try {
      final headers = await TokenAuthService.getAuthHeaders();
      if (headers == null) {
        return {'success': false, 'message': 'Authentication required'};
      }

      final Map<String, dynamic> body = {};

      // Basic fields
      if (displayName != null) body['displayName'] = displayName;
      if (photoURL != null) body['photoURL'] = photoURL;

      // Profile fields
      final Map<String, dynamic> profile = {};
      if (firstName != null) profile['firstName'] = firstName;
      if (lastName != null) profile['lastName'] = lastName;
      if (bio != null) profile['bio'] = bio;
      if (dateOfBirth != null) {
        profile['dateOfBirth'] = dateOfBirth.toIso8601String();
      }
      if (gender != null) profile['gender'] = gender;
      if (website != null) profile['website'] = website;
      if (occupation != null) profile['occupation'] = occupation;
      if (interests != null) profile['interests'] = interests;
      if (coverPhotoURL != null) profile['coverPhotoURL'] = coverPhotoURL;

      // Location
      if (country != null || state != null || city != null) {
        profile['location'] = {};
        if (country != null) profile['location']['country'] = country;
        if (state != null) profile['location']['state'] = state;
        if (city != null) profile['location']['city'] = city;
      }

      // Preferences
      if (language != null || timezone != null) {
        profile['preferences'] = {};
        if (language != null) profile['preferences']['language'] = language;
        if (timezone != null) profile['preferences']['timezone'] = timezone;
      }

      if (profile.isNotEmpty) {
        body['profile'] = profile;
      }

      print('📤 ProfileService.updateProfile: $body');

      final response = await http.put(
        Uri.parse('$baseUrl/users/profile'),
        headers: headers,
        body: json.encode(body),
      );

      print('📱 ProfileService.updateProfile: ${response.statusCode}');

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        // Note: User will be refreshed on next app start or manual refresh

        return {
          'success': true,
          'message': data['message'] ?? 'Profile updated successfully',
          'user': data['data']?['user'],
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Failed to update profile',
        'errors': data['errors'],
      };
    } catch (e) {
      print('❌ ProfileService.updateProfile error: $e');
      return {'success': false, 'message': 'An error occurred: $e'};
    }
  }

  /// Update username
  static Future<Map<String, dynamic>> updateUsername(String username) async {
    try {
      final headers = await TokenAuthService.getAuthHeaders();
      if (headers == null) {
        return {'success': false, 'message': 'Authentication required'};
      }

      final response = await http.put(
        Uri.parse('$baseUrl/users/username'),
        headers: headers,
        body: json.encode({'username': username}),
      );

      print('📱 ProfileService.updateUsername: ${response.statusCode}');

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        // Refresh cached user
        await getMyProfile();

        return {
          'success': true,
          'message': data['message'] ?? 'Username updated successfully',
          'username': data['data']?['username'],
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Failed to update username',
        'code': data['code'],
      };
    } catch (e) {
      print('❌ ProfileService.updateUsername error: $e');
      return {'success': false, 'message': 'An error occurred: $e'};
    }
  }

  /// Follow/Unfollow a user
  static Future<Map<String, dynamic>> toggleFollow(String userId) async {
    try {
      final headers = await TokenAuthService.getAuthHeaders();
      if (headers == null) {
        return {'success': false, 'message': 'Authentication required'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/users/$userId/follow'),
        headers: headers,
      );

      print('📱 ProfileService.toggleFollow: ${response.statusCode}');

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'],
          'isFollowing': data['data']?['isFollowing'] ?? false,
          'followersCount': data['data']?['followersCount'] ?? 0,
          'followingCount': data['data']?['followingCount'] ?? 0,
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Failed to follow/unfollow user',
      };
    } catch (e) {
      print('❌ ProfileService.toggleFollow error: $e');
      return {'success': false, 'message': 'An error occurred: $e'};
    }
  }

  /// Get following list
  static Future<List<UserModel>> getFollowing() async {
    try {
      final token = await TokenAuthService.getToken();
      if (token == null) {
        print('❌ ProfileService: No auth token');
        return [];
      }

      final response = await http.get(
        Uri.parse('$baseUrl/users/following'),
        headers: await TokenAuthService.getAuthHeaders(),
      );

      print('📱 ProfileService.getFollowing: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> users = data['data']['users'] ?? [];
          return users.map((user) => UserModel.fromJson(user)).toList();
        }
      }

      return [];
    } catch (e) {
      print('❌ ProfileService.getFollowing error: $e');
      return [];
    }
  }

  /// Get followers list
  static Future<List<UserModel>> getFollowers() async {
    try {
      final token = await TokenAuthService.getToken();
      if (token == null) {
        print('❌ ProfileService: No auth token');
        return [];
      }

      final response = await http.get(
        Uri.parse('$baseUrl/users/followers'),
        headers: await TokenAuthService.getAuthHeaders(),
      );

      print('📱 ProfileService.getFollowers: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> users = data['data']['users'] ?? [];
          return users.map((user) => UserModel.fromJson(user)).toList();
        }
      }

      return [];
    } catch (e) {
      print('❌ ProfileService.getFollowers error: $e');
      return [];
    }
  }

  /// Update notification preferences
  static Future<Map<String, dynamic>> updateNotificationPreferences({
    bool? email,
    bool? push,
    bool? sms,
  }) async {
    try {
      final headers = await TokenAuthService.getAuthHeaders();
      if (headers == null) {
        return {'success': false, 'message': 'Authentication required'};
      }

      final Map<String, dynamic> body = {};
      if (email != null) body['email'] = email;
      if (push != null) body['push'] = push;
      if (sms != null) body['sms'] = sms;

      final response = await http.put(
        Uri.parse('$baseUrl/users/notifications'),
        headers: headers,
        body: json.encode(body),
      );

      print(
        '📱 ProfileService.updateNotificationPreferences: ${response.statusCode}',
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? 'Preferences updated successfully',
          'notifications': data['data']?['notifications'],
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Failed to update preferences',
      };
    } catch (e) {
      print('❌ ProfileService.updateNotificationPreferences error: $e');
      return {'success': false, 'message': 'An error occurred: $e'};
    }
  }
}
