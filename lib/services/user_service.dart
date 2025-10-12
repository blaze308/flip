import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'token_auth_service.dart';
import '../models/user_model.dart';

class UserListResult {
  final bool success;
  final List<UserModel> users;
  final String message;

  UserListResult({
    required this.success,
    required this.users,
    this.message = '',
  });
}

class UserService {
  static const String baseUrl = 'https://flip-backend-mnpg.onrender.com';
  static const Duration timeoutDuration = Duration(seconds: 30);

  /// Get authentication headers
  static Future<Map<String, String>> _getHeaders() async {
    final headers = await TokenAuthService.getAuthHeaders();
    if (headers == null) {
      throw Exception('Not authenticated');
    }
    return headers;
  }

  /// Upload an image to Cloudinary via backend
  static Future<String> uploadImage(File imageFile) async {
    try {
      print('📸 UserService: Starting image upload...');

      // Create multipart request
      final uri = Uri.parse('$baseUrl/api/upload/image');
      final request = http.MultipartRequest('POST', uri);

      // Add headers
      final headers = await _getHeaders();
      request.headers.addAll(headers);

      // Add image file
      final imageBytes = await imageFile.readAsBytes();
      final multipartFile = http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: imageFile.path.split('/').last,
      );
      request.files.add(multipartFile);

      print('📸 UserService: Sending upload request...');
      final streamedResponse = await request.send().timeout(timeoutDuration);
      final response = await http.Response.fromStream(streamedResponse);

      print('📸 UserService: Upload response status: ${response.statusCode}');
      print('📸 UserService: Upload response body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final imageUrl = data['data']['imageUrl'] as String;
          print('📸 UserService: Image uploaded successfully: $imageUrl');
          return imageUrl;
        } else {
          throw Exception(data['message'] ?? 'Failed to upload image');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to upload image');
      }
    } catch (e) {
      print('❌ UserService: Error uploading image: $e');
      rethrow;
    }
  }

  /// Update user profile
  static Future<Map<String, dynamic>> updateProfile({
    String? displayName,
    String? bio,
    String? photoURL,
    String? coverPhotoURL,
    String? firstName,
    String? lastName,
    String? dateOfBirth,
    String? gender,
    String? country,
    String? state,
    String? city,
    String? website,
    String? occupation,
    List<String>? interests,
    String? language,
    String? theme,
  }) async {
    try {
      print('👤 UserService: Updating profile...');

      final uri = Uri.parse('$baseUrl/api/users/profile');
      final headers = await _getHeaders();

      // Build request body
      final Map<String, dynamic> body = {};

      if (displayName != null) body['displayName'] = displayName;

      // Profile object
      final Map<String, dynamic> profile = {};

      if (firstName != null) profile['firstName'] = firstName;
      if (lastName != null) profile['lastName'] = lastName;
      if (bio != null) profile['bio'] = bio;
      if (dateOfBirth != null) profile['dateOfBirth'] = dateOfBirth;
      if (gender != null) profile['gender'] = gender;
      if (website != null) profile['website'] = website;
      if (occupation != null) profile['occupation'] = occupation;
      if (interests != null) profile['interests'] = interests;

      // Location object
      if (country != null || state != null || city != null) {
        profile['location'] = {};
        if (country != null) profile['location']['country'] = country;
        if (state != null) profile['location']['state'] = state;
        if (city != null) profile['location']['city'] = city;
      }

      // Preferences object
      if (language != null || theme != null) {
        profile['preferences'] = {};
        if (language != null) profile['preferences']['language'] = language;
        if (theme != null) profile['preferences']['theme'] = theme;
      }

      if (profile.isNotEmpty) {
        body['profile'] = profile;
      }

      // Add photoURL and coverPhotoURL to the body if provided
      if (photoURL != null) body['photoURL'] = photoURL;
      if (coverPhotoURL != null) {
        // coverPhotoURL goes in the profile object
        if (body['profile'] == null) {
          body['profile'] = {};
        }
        body['profile']['coverPhotoURL'] = coverPhotoURL;
      }

      print('👤 UserService: Request body: ${json.encode(body)}');

      final response = await http
          .put(uri, headers: headers, body: json.encode(body))
          .timeout(timeoutDuration);

      print('👤 UserService: Response status: ${response.statusCode}');
      print('👤 UserService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          print('👤 UserService: Profile updated successfully');
          return data['data'];
        } else {
          throw Exception(data['message'] ?? 'Failed to update profile');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to update profile');
      }
    } catch (e) {
      print('❌ UserService: Error updating profile: $e');
      rethrow;
    }
  }

  /// Get user profile
  static Future<Map<String, dynamic>> getProfile() async {
    try {
      print('👤 UserService: Getting profile...');

      final uri = Uri.parse('$baseUrl/api/users/profile');
      final headers = await _getHeaders();

      final response = await http
          .get(uri, headers: headers)
          .timeout(timeoutDuration);

      print('👤 UserService: Response status: ${response.statusCode}');
      print('👤 UserService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          print('👤 UserService: Profile retrieved successfully');
          return data['data'];
        } else {
          throw Exception(data['message'] ?? 'Failed to get profile');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to get profile');
      }
    } catch (e) {
      print('❌ UserService: Error getting profile: $e');
      rethrow;
    }
  }

  /// Complete profile with all data (profile image + details)
  static Future<void> completeProfile({
    required String bio,
    required String location,
    required List<String> interests,
    File? profileImage,
    File? coverImage,
    String? website,
    String? occupation,
  }) async {
    try {
      print('👤 UserService: Starting complete profile flow...');

      String? profileImageUrl;
      String? coverImageUrl;

      // Step 1: Upload profile image if provided
      if (profileImage != null) {
        print('👤 UserService: Uploading profile image...');
        profileImageUrl = await uploadImage(profileImage);
      }

      // Step 2: Upload cover image if provided
      if (coverImage != null) {
        print('👤 UserService: Uploading cover image...');
        coverImageUrl = await uploadImage(coverImage);
      }

      // Step 3: Update profile with all data including photo URLs
      print('👤 UserService: Updating profile with all data...');
      await updateProfile(
        photoURL: profileImageUrl,
        bio: bio,
        city: location, // Assuming location is city for now
        interests: interests,
        website: website,
        occupation: occupation,
        coverPhotoURL: coverImageUrl,
      );

      // Step 4: Refresh current user data to update UI
      print('👤 UserService: Refreshing current user data...');
      await TokenAuthService.refreshCurrentUser();

      print('👤 UserService: Complete profile flow finished successfully');
    } catch (e) {
      print('❌ UserService: Error in complete profile flow: $e');
      rethrow;
    }
  }

  /// Create or update user from Firebase Auth
  static Future<void> createUserFromFirebase(
    dynamic firebaseUser, {
    String? username,
  }) async {
    try {
      print('👤 UserService: Creating/updating user from Firebase...');
      // This is handled by the backend token exchange
      // Just a placeholder for compatibility
      print('👤 UserService: User creation handled by token exchange');
    } catch (e) {
      print('❌ UserService: Error in createUserFromFirebase: $e');
      rethrow;
    }
  }

  /// Initialize user data (compatibility method)
  static Future<void> initializeUser() async {
    try {
      print('👤 UserService: Initializing user...');
      // Fetch current user profile
      await getProfile();
    } catch (e) {
      print('❌ UserService: Error initializing user: $e');
    }
  }

  /// Update last active timestamp
  static Future<void> updateLastActive() async {
    try {
      // This is handled automatically by the backend on each request
      print('👤 UserService: Last active updated automatically');
    } catch (e) {
      print('❌ UserService: Error updating last active: $e');
    }
  }

  /// Clear user data (for logout)
  static Future<void> clearUser() async {
    try {
      print('👤 UserService: Clearing user data...');
      // Clear any local caches if needed
    } catch (e) {
      print('❌ UserService: Error clearing user: $e');
    }
  }

  /// Format follower count for display (e.g., 1.2K, 3.5M)
  static String formatFollowerCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return count.toString();
    }
  }

  /// Get users that the current user is following
  static Future<UserListResult> getFollowingUsers() async {
    try {
      print('👥 UserService: Getting following users...');

      final uri = Uri.parse('$baseUrl/api/users/following');
      final headers = await _getHeaders();

      final response = await http
          .get(uri, headers: headers)
          .timeout(timeoutDuration);

      print('👥 UserService: Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> usersJson = data['data']['users'] ?? [];
          final users =
              usersJson.map((json) => UserModel.fromJson(json)).toList();
          print('👥 UserService: Retrieved ${users.length} following users');
          return UserListResult(success: true, users: users);
        } else {
          return UserListResult(
            success: false,
            users: [],
            message: data['message'] ?? 'Failed to get following users',
          );
        }
      } else {
        final errorData = json.decode(response.body);
        return UserListResult(
          success: false,
          users: [],
          message: errorData['message'] ?? 'Failed to get following users',
        );
      }
    } catch (e) {
      print('❌ UserService: Error getting following users: $e');
      return UserListResult(success: false, users: [], message: e.toString());
    }
  }
}
