import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post_model.dart';

class PostService {
  // Update this URL to match your backend server
  static const String baseUrl = 'https://flip-backend-mnpg.onrender.com';
  static const Duration timeoutDuration = Duration(seconds: 30);

  // Development mode flag - set to true for local testing
  static const bool isDevelopmentMode = false;

  /// Get authentication headers with Firebase ID token
  static Future<Map<String, String>> _getHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw PostException(message: 'User not authenticated', statusCode: 401);
    }

    final token = await user.getIdToken();
    print('Firebase user: ${user.email}, UID: ${user.uid}'); // Debug log
    print(
      'Token length: ${token?.length}',
    ); // Debug log (don't print full token for security)

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Make HTTP request with error handling
  static Future<Map<String, dynamic>> _makeRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      print('Making $method request to: $uri'); // Debug log
      if (body != null) {
        print('Request body: ${json.encode(body)}'); // Debug log
      }
      final headers = await _getHeaders();

      http.Response response;

      switch (method.toUpperCase()) {
        case 'GET':
          response = await http
              .get(uri, headers: headers)
              .timeout(timeoutDuration);
          break;
        case 'POST':
          response = await http
              .post(
                uri,
                headers: headers,
                body: body != null ? json.encode(body) : null,
              )
              .timeout(timeoutDuration);
          break;
        case 'PUT':
          response = await http
              .put(
                uri,
                headers: headers,
                body: body != null ? json.encode(body) : null,
              )
              .timeout(timeoutDuration);
          break;
        case 'DELETE':
          response = await http
              .delete(
                uri,
                headers: headers,
                body: body != null ? json.encode(body) : null,
              )
              .timeout(timeoutDuration);
          break;
        default:
          throw PostException(
            message: 'Unsupported HTTP method: $method',
            statusCode: 400,
          );
      }

      print('Response status: ${response.statusCode}'); // Debug log
      print('Response headers: ${response.headers}'); // Debug log
      print(
        'Response body (first 500 chars): ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}',
      ); // Debug log

      // Handle specific error status codes
      if (response.statusCode == 502) {
        throw PostException(
          message:
              'Backend server error (502). The server may be overloaded or restarting.',
          statusCode: response.statusCode,
        );
      }

      if (response.statusCode == 401) {
        throw PostException(
          message: 'Authentication failed. Please log in again.',
          statusCode: response.statusCode,
        );
      }

      if (response.statusCode == 403) {
        throw PostException(
          message:
              'Access denied. You may not have permission to perform this action.',
          statusCode: response.statusCode,
        );
      }

      // Check if response is HTML (error page) instead of JSON
      if (response.body.trim().toLowerCase().startsWith('<!doctype html') ||
          response.body.trim().toLowerCase().startsWith('<html')) {
        throw PostException(
          message:
              'Server returned HTML error page. Status: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      Map<String, dynamic> responseData;
      try {
        responseData = json.decode(response.body) as Map<String, dynamic>;
      } catch (e) {
        throw PostException(
          message:
              'Invalid JSON response from server. Response: ${response.body.substring(0, 100)}...',
          statusCode: response.statusCode,
        );
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return responseData;
      } else {
        throw PostException(
          message: responseData['message'] ?? 'Request failed',
          statusCode: response.statusCode,
        );
      }
    } on SocketException {
      throw PostException(
        message: 'No internet connection. Please check your network.',
        statusCode: 0,
      );
    } on HttpException {
      throw PostException(
        message: 'Network error occurred. Please try again.',
        statusCode: 0,
      );
    } catch (e) {
      if (e is PostException) {
        rethrow;
      }
      throw PostException(
        message: 'Network error: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Get posts for user's feed
  static Future<PostFeedResult> getFeed({
    int page = 1,
    int limit = 20,
    PostType? type,
  }) async {
    try {
      String endpoint = '/posts/feed?page=$page&limit=$limit';
      if (type != null) {
        endpoint += '&type=${type.toString().split('.').last}';
      }

      final response = await _makeRequest('GET', endpoint);

      // Debug: Log raw backend response for first post
      if (response['data']['posts'] != null &&
          response['data']['posts'].isNotEmpty) {
        final firstPost = response['data']['posts'][0];
        print('🔧 PostService: Raw backend data for first post:');
        print('   - id: ${firstPost['_id']}');
        print('   - likes: ${firstPost['likes']}');
        print('   - isLiked: ${firstPost['isLiked']}');
        print('   - likedBy length: ${firstPost['likedBy']?.length ?? 0}');
      }

      return PostFeedResult.fromJson(response);
    } catch (e) {
      throw PostException(
        message: 'Failed to get feed: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Get posts by a specific user
  static Future<PostFeedResult> getUserPosts(
    String userId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _makeRequest(
        'GET',
        '/posts/user/$userId?page=$page&limit=$limit',
      );
      return PostFeedResult.fromJson(response);
    } catch (e) {
      throw PostException(
        message: 'Failed to get user posts: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Get a specific post by ID
  static Future<PostModel> getPost(String postId) async {
    try {
      final response = await _makeRequest('GET', '/posts/$postId');
      return PostModel.fromBackendJson(response['data']['post']);
    } catch (e) {
      throw PostException(
        message: 'Failed to get post: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Create a new post
  static Future<PostModel> createPost({
    required PostType type,
    String? content,
    List<String>? imageUrls,
    String? videoUrl,
    String? videoThumbnail,
    Duration? videoDuration,
    Color? backgroundColor,
    Color? textColor,
    String? fontFamily,
    double? fontSize,
    FontWeight? fontWeight,
    TextAlign? textAlign,
    List<String>? tags,
    String? locationName,
    bool isPublic = true,
  }) async {
    try {
      // Test backend connection first - fail fast if not available
      final isBackendAvailable = await testBackendConnection();
      if (!isBackendAvailable) {
        throw PostException(
          message:
              'Backend server is not available. Please check your internet connection and try again.',
          statusCode: 0,
        );
      }
      final Map<String, dynamic> postData = {
        'type': type.toString().split('.').last,
        'isPublic': isPublic,
      };

      if (content != null) postData['content'] = content;
      if (imageUrls != null) postData['imageUrls'] = imageUrls;
      if (videoUrl != null) postData['videoUrl'] = videoUrl;
      if (videoThumbnail != null) postData['videoThumbnail'] = videoThumbnail;
      if (videoDuration != null) {
        postData['videoDuration'] = videoDuration.inSeconds;
      }
      if (tags != null) postData['tags'] = tags;

      // Text styling
      if (type == PostType.text) {
        final textStyle = <String, dynamic>{};
        if (backgroundColor != null) {
          textStyle['backgroundColor'] =
              '#${backgroundColor.value.toRadixString(16).padLeft(8, '0').substring(2)}';
        }
        if (textColor != null) {
          textStyle['textColor'] =
              '#${textColor.value.toRadixString(16).padLeft(8, '0').substring(2)}';
        }
        if (fontFamily != null) textStyle['fontFamily'] = fontFamily;
        if (fontSize != null) textStyle['fontSize'] = fontSize.toInt();
        if (fontWeight != null) {
          // Convert Flutter FontWeight to backend format
          String weightValue;
          switch (fontWeight) {
            case FontWeight.w100:
              weightValue = '100';
              break;
            case FontWeight.w200:
              weightValue = '200';
              break;
            case FontWeight.w300:
              weightValue = '300';
              break;
            case FontWeight.w400:
              weightValue = '400';
              break;
            case FontWeight.w500:
              weightValue = '500';
              break;
            case FontWeight.w600:
              weightValue = '600';
              break;
            case FontWeight.w700:
              weightValue = '700';
              break;
            case FontWeight.w800:
              weightValue = '800';
              break;
            case FontWeight.w900:
              weightValue = '900';
              break;
            default:
              weightValue = '400';
          }
          textStyle['fontWeight'] = weightValue;
        }
        if (textAlign != null) {
          textStyle['textAlign'] = textAlign.toString().split('.').last;
        }

        if (textStyle.isNotEmpty) {
          postData['textStyle'] = textStyle;
        }
      }

      // Location
      if (locationName != null) {
        postData['location'] = {'name': locationName};
      }

      final response = await _makeRequest('POST', '/posts', body: postData);
      return PostModel.fromBackendJson(response['data']['post']);
    } catch (e) {
      throw PostException(
        message: 'Failed to create post: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Update a post
  static Future<PostModel> updatePost(
    String postId, {
    String? content,
    Color? backgroundColor,
    Color? textColor,
    String? fontFamily,
    double? fontSize,
    FontWeight? fontWeight,
    TextAlign? textAlign,
    List<String>? tags,
    String? locationName,
    bool? isPublic,
  }) async {
    try {
      final Map<String, dynamic> updateData = {};

      if (content != null) updateData['content'] = content;
      if (tags != null) updateData['tags'] = tags;
      if (isPublic != null) updateData['isPublic'] = isPublic;

      // Text styling
      final textStyle = <String, dynamic>{};
      if (backgroundColor != null) {
        textStyle['backgroundColor'] =
            '#${backgroundColor.value.toRadixString(16).padLeft(8, '0').substring(2)}';
      }
      if (textColor != null) {
        textStyle['textColor'] =
            '#${textColor.value.toRadixString(16).padLeft(8, '0').substring(2)}';
      }
      if (fontFamily != null) textStyle['fontFamily'] = fontFamily;
      if (fontSize != null) textStyle['fontSize'] = fontSize.toInt();
      if (fontWeight != null) {
        textStyle['fontWeight'] = fontWeight.toString().split('.').last;
      }
      if (textAlign != null) {
        textStyle['textAlign'] = textAlign.toString().split('.').last;
      }

      if (textStyle.isNotEmpty) {
        updateData['textStyle'] = textStyle;
      }

      // Location
      if (locationName != null) {
        updateData['location'] = {'name': locationName};
      }

      final response = await _makeRequest(
        'PUT',
        '/posts/$postId',
        body: updateData,
      );
      return PostModel.fromBackendJson(response['data']['post']);
    } catch (e) {
      throw PostException(
        message: 'Failed to update post: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Delete a post
  static Future<void> deletePost(String postId) async {
    try {
      await _makeRequest('DELETE', '/posts/$postId');
    } catch (e) {
      throw PostException(
        message: 'Failed to delete post: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Like or unlike a post
  static Future<PostLikeResult> toggleLike(String postId) async {
    try {
      final response = await _makeRequest('POST', '/posts/$postId/like');
      return PostLikeResult.fromJson(response);
    } catch (e) {
      throw PostException(
        message: 'Failed to toggle like: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Share a post
  static Future<PostShareResult> sharePost(String postId) async {
    try {
      final response = await _makeRequest('POST', '/posts/$postId/share');
      return PostShareResult.fromJson(response);
    } catch (e) {
      throw PostException(
        message: 'Failed to share post: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Bookmark or unbookmark a post
  static Future<PostBookmarkResult> toggleBookmark(String postId) async {
    try {
      final response = await _makeRequest('POST', '/posts/$postId/bookmark');
      return PostBookmarkResult.fromJson(response);
    } catch (e) {
      throw PostException(
        message: 'Failed to bookmark post: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Hide or unhide a post
  static Future<PostHideResult> toggleHide(String postId) async {
    try {
      final response = await _makeRequest('POST', '/posts/$postId/hide');
      return PostHideResult.fromJson(response);
    } catch (e) {
      throw PostException(
        message: 'Failed to hide post: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Follow or unfollow a user
  static Future<UserFollowResult> toggleFollow(String userId) async {
    try {
      final response = await _makeRequest('POST', '/users/$userId/follow');
      return UserFollowResult.fromJson(response);
    } catch (e) {
      throw PostException(
        message: 'Failed to follow user: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Update notification preferences
  static Future<NotificationUpdateResult> updateNotifications({
    bool? email,
    bool? push,
    bool? sms,
  }) async {
    try {
      final Map<String, dynamic> data = {};
      if (email != null) data['email'] = email;
      if (push != null) data['push'] = push;
      if (sms != null) data['sms'] = sms;

      final response = await _makeRequest(
        'PUT',
        '/users/notifications',
        body: data,
      );
      return NotificationUpdateResult.fromJson(response);
    } catch (e) {
      throw PostException(
        message: 'Failed to update notifications: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Test backend connectivity
  /// Upload an image file to Cloudinary via backend
  static Future<String> uploadImage(File imageFile) async {
    try {
      print('📸 PostService: Starting image upload...');

      // Create multipart request
      final uri = Uri.parse('$baseUrl/upload/image');
      final request = http.MultipartRequest('POST', uri);

      // Add headers
      final headers = await _getHeaders();
      request.headers.addAll(headers);

      // Add image file
      final imageStream = http.ByteStream(imageFile.openRead());
      final imageLength = await imageFile.length();

      // Determine MIME type from file extension
      String mimeType = 'image/jpeg'; // default
      final extension = imageFile.path.toLowerCase().split('.').last;
      switch (extension) {
        case 'png':
          mimeType = 'image/png';
          break;
        case 'jpg':
        case 'jpeg':
          mimeType = 'image/jpeg';
          break;
        case 'gif':
          mimeType = 'image/gif';
          break;
        case 'webp':
          mimeType = 'image/webp';
          break;
        default:
          mimeType = 'image/jpeg';
      }

      final multipartFile = http.MultipartFile(
        'image',
        imageStream,
        imageLength,
        filename: 'image_${DateTime.now().millisecondsSinceEpoch}.$extension',
        contentType: MediaType.parse(mimeType),
      );
      request.files.add(multipartFile);

      print('📸 PostService: Sending upload request...');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('📸 PostService: Upload response status: ${response.statusCode}');
      print('📸 PostService: Upload response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true &&
            responseData['data']['imageUrl'] != null) {
          final imageUrl = responseData['data']['imageUrl'] as String;
          print('📸 PostService: Image uploaded successfully: $imageUrl');
          return imageUrl;
        } else {
          throw Exception(
            'Upload failed: ${responseData['message'] ?? 'Unknown error'}',
          );
        }
      } else {
        throw Exception(
          'Upload failed with status ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      print('📸 PostService: Upload error: $e');
      throw Exception('Failed to upload image: $e');
    }
  }

  /// Upload multiple images to Cloudinary via backend
  static Future<List<String>> uploadMultipleImages(
    List<File> imageFiles,
  ) async {
    try {
      print('📸 PostService: Starting multiple images upload...');

      // Create multipart request
      final uri = Uri.parse('$baseUrl/upload/multiple-images');
      final request = http.MultipartRequest('POST', uri);

      // Add headers
      final headers = await _getHeaders();
      request.headers.addAll(headers);

      // Add image files
      for (int i = 0; i < imageFiles.length; i++) {
        final imageFile = imageFiles[i];
        final imageStream = http.ByteStream(imageFile.openRead());
        final imageLength = await imageFile.length();

        // Determine MIME type from file extension
        String mimeType = 'image/jpeg'; // default
        final extension = imageFile.path.toLowerCase().split('.').last;
        switch (extension) {
          case 'png':
            mimeType = 'image/png';
            break;
          case 'jpg':
          case 'jpeg':
            mimeType = 'image/jpeg';
            break;
          case 'gif':
            mimeType = 'image/gif';
            break;
          case 'webp':
            mimeType = 'image/webp';
            break;
          default:
            mimeType = 'image/jpeg';
        }

        final multipartFile = http.MultipartFile(
          'images',
          imageStream,
          imageLength,
          filename:
              'image_${DateTime.now().millisecondsSinceEpoch}_$i.$extension',
          contentType: MediaType.parse(mimeType),
        );
        request.files.add(multipartFile);
      }

      print('📸 PostService: Sending multiple images upload request...');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print(
        '📸 PostService: Multiple images upload response status: ${response.statusCode}',
      );
      print(
        '📸 PostService: Multiple images upload response body: ${response.body}',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true &&
            responseData['data']['images'] != null) {
          final images = responseData['data']['images'] as List;
          final imageUrls =
              images.map((img) => img['imageUrl'] as String).toList();
          print(
            '📸 PostService: Multiple images uploaded successfully: $imageUrls',
          );
          return imageUrls;
        } else {
          throw Exception(
            'Upload failed: ${responseData['message'] ?? 'Unknown error'}',
          );
        }
      } else {
        throw Exception(
          'Upload failed with status ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      print('📸 PostService: Multiple images upload error: $e');
      throw Exception('Failed to upload images: $e');
    }
  }

  /// Upload a video file to Cloudinary via backend
  static Future<Map<String, dynamic>> uploadVideo(File videoFile) async {
    try {
      print('🎥 PostService: Starting video upload...');

      // Create multipart request
      final uri = Uri.parse('$baseUrl/upload/video');
      final request = http.MultipartRequest('POST', uri);

      // Add headers
      final headers = await _getHeaders();
      request.headers.addAll(headers);

      // Add video file
      final videoStream = http.ByteStream(videoFile.openRead());
      final videoLength = await videoFile.length();

      // Determine MIME type from file extension
      String mimeType = 'video/mp4'; // default
      final extension = videoFile.path.toLowerCase().split('.').last;
      switch (extension) {
        case 'mp4':
          mimeType = 'video/mp4';
          break;
        case 'mov':
          mimeType = 'video/quicktime';
          break;
        case 'avi':
          mimeType = 'video/x-msvideo';
          break;
        case 'webm':
          mimeType = 'video/webm';
          break;
        case '3gp':
          mimeType = 'video/3gpp';
          break;
        default:
          mimeType = 'video/mp4';
      }

      final multipartFile = http.MultipartFile(
        'video',
        videoStream,
        videoLength,
        filename: 'video_${DateTime.now().millisecondsSinceEpoch}.$extension',
        contentType: MediaType.parse(mimeType),
      );
      request.files.add(multipartFile);

      print('🎥 PostService: Sending video upload request...');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print(
        '🎥 PostService: Video upload response status: ${response.statusCode}',
      );
      print('🎥 PostService: Video upload response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true &&
            responseData['data']['videoUrl'] != null) {
          final videoData = responseData['data'];
          final result = {
            'videoUrl': videoData['videoUrl'] as String,
            'thumbnailUrl': videoData['thumbnailUrl'] as String,
            'duration': videoData['duration'] as double? ?? 0.0,
            'width': videoData['width'] as int? ?? 0,
            'height': videoData['height'] as int? ?? 0,
            'size': videoData['size'] as int? ?? 0,
          };
          print(
            '🎥 PostService: Video uploaded successfully: ${result['videoUrl']}',
          );
          return result;
        } else {
          throw Exception(
            'Upload failed: ${responseData['message'] ?? 'Unknown error'}',
          );
        }
      } else {
        throw Exception(
          'Upload failed with status ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      print('🎥 PostService: Video upload error: $e');
      throw Exception('Failed to upload video: $e');
    }
  }

  static Future<bool> testBackendConnection() async {
    try {
      print('Testing backend connection to: $baseUrl');
      final response = await http
          .get(
            Uri.parse('$baseUrl/health'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      print('Backend health check response: ${response.statusCode}');
      print('Response body: ${response.body}');

      return response.statusCode == 200;
    } catch (e) {
      print('Backend connection test failed: $e');
      return false;
    }
  }
}

/// Custom exception for post-related errors
class PostException implements Exception {
  final String message;
  final int statusCode;

  PostException({required this.message, required this.statusCode});

  @override
  String toString() => message;
}

/// Result from post feed operation
class PostFeedResult {
  final bool success;
  final String message;
  final List<PostModel> posts;
  final PostPagination pagination;

  PostFeedResult({
    required this.success,
    required this.message,
    required this.posts,
    required this.pagination,
  });

  factory PostFeedResult.fromJson(Map<String, dynamic> json) {
    final postsData = json['data']['posts'] as List;
    final posts = postsData.map((p) => PostModel.fromBackendJson(p)).toList();

    return PostFeedResult(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      posts: posts,
      pagination: PostPagination.fromJson(json['data']['pagination']),
    );
  }
}

/// Pagination information for posts
class PostPagination {
  final int page;
  final int limit;
  final bool hasMore;

  PostPagination({
    required this.page,
    required this.limit,
    required this.hasMore,
  });

  factory PostPagination.fromJson(Map<String, dynamic> json) {
    return PostPagination(
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 20,
      hasMore: json['hasMore'] ?? false,
    );
  }
}

/// Result from like operation
class PostLikeResult {
  final bool success;
  final String message;
  final bool isLiked;
  final int likes;

  PostLikeResult({
    required this.success,
    required this.message,
    required this.isLiked,
    required this.likes,
  });

  factory PostLikeResult.fromJson(Map<String, dynamic> json) {
    return PostLikeResult(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      isLiked: json['data']['isLiked'] ?? false,
      likes: json['data']['likes'] ?? 0,
    );
  }
}

/// Result from share operation
class PostShareResult {
  final bool success;
  final String message;
  final int shares;

  PostShareResult({
    required this.success,
    required this.message,
    required this.shares,
  });

  factory PostShareResult.fromJson(Map<String, dynamic> json) {
    return PostShareResult(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      shares: json['data']['shares'] ?? 0,
    );
  }
}

/// Result from bookmark operation
class PostBookmarkResult {
  final bool success;
  final String message;
  final bool isBookmarked;

  PostBookmarkResult({
    required this.success,
    required this.message,
    required this.isBookmarked,
  });

  factory PostBookmarkResult.fromJson(Map<String, dynamic> json) {
    return PostBookmarkResult(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      isBookmarked: json['data']['isBookmarked'] ?? false,
    );
  }
}

/// Result from hide operation
class PostHideResult {
  final bool success;
  final String message;
  final bool isHidden;

  PostHideResult({
    required this.success,
    required this.message,
    required this.isHidden,
  });

  factory PostHideResult.fromJson(Map<String, dynamic> json) {
    return PostHideResult(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      isHidden: json['data']['isHidden'] ?? false,
    );
  }
}

/// Result from follow operation
class UserFollowResult {
  final bool success;
  final String message;
  final bool isFollowing;
  final int followersCount;
  final int followingCount;

  UserFollowResult({
    required this.success,
    required this.message,
    required this.isFollowing,
    required this.followersCount,
    required this.followingCount,
  });

  factory UserFollowResult.fromJson(Map<String, dynamic> json) {
    return UserFollowResult(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      isFollowing: json['data']['isFollowing'] ?? false,
      followersCount: json['data']['followersCount'] ?? 0,
      followingCount: json['data']['followingCount'] ?? 0,
    );
  }
}

/// Result from notification update operation
class NotificationUpdateResult {
  final bool success;
  final String message;
  final Map<String, bool> notifications;

  NotificationUpdateResult({
    required this.success,
    required this.message,
    required this.notifications,
  });

  factory NotificationUpdateResult.fromJson(Map<String, dynamic> json) {
    final notificationsData =
        json['data']['notifications'] as Map<String, dynamic>? ?? {};
    return NotificationUpdateResult(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      notifications: notificationsData.map(
        (key, value) => MapEntry(key, value as bool),
      ),
    );
  }
}
