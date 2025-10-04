import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/story_model.dart';
import 'token_auth_service.dart';

class StoryService {
  // Update this URL to match your backend server
  static const String baseUrl = 'https://flip-backend-mnpg.onrender.com';
  static const Duration timeoutDuration = Duration(seconds: 30);

  // Development mode flag - set to true for local testing
  static const bool isDevelopmentMode = false;

  /// Get authentication headers (returns null for guest users)
  static Future<Map<String, String>?> _getHeaders() async {
    // Check if user is authenticated
    if (TokenAuthService.isAuthenticated) {
      final headers = await TokenAuthService.getAuthHeaders();
      if (headers != null) {
        print('📖 StoryService: Using JWT token for authenticated user');
        return headers;
      }
    }

    // For guest users, try Firebase auth as fallback
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final token = await user.getIdToken();
      print('📖 StoryService: Firebase user: ${user.email}, UID: ${user.uid}');
      return {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
    }

    // Guest user - no authentication headers
    print('📖 StoryService: Guest user - no authentication headers');
    return null;
  }

  /// Get basic headers for public requests
  static Map<String, String> _getPublicHeaders() {
    return {'Content-Type': 'application/json'};
  }

  /// Get stories feed for the current user
  static Future<List<StoryFeedItem>> getStoriesFeed({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      print(
        '📖 StoryService: Fetching stories feed (page: $page, limit: $limit)',
      );

      final headers = await _getHeaders();

      // Choose endpoint based on authentication status
      final endpoint =
          headers != null ? '/api/stories/feed' : '/api/stories/public';
      final offset = (page - 1) * limit;
      final fullUrl = '$baseUrl$endpoint?limit=$limit&offset=$offset';

      print('📖 StoryService: Making request to: $fullUrl');
      print('📖 StoryService: Headers present: ${headers != null}');

      final response = await http
          .get(Uri.parse(fullUrl), headers: headers ?? _getPublicHeaders())
          .timeout(timeoutDuration);

      print(
        '📖 StoryService: Stories feed response status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final feedData = data['data'];
        final List<dynamic> storiesData = feedData['feed'] ?? [];

        // Backend now populates user details, just parse them
        final stories =
            storiesData
                .map((storyData) => StoryFeedItem.fromJson(storyData))
                .toList();

        print(
          '📖 StoryService: Successfully loaded ${stories.length} story feed items',
        );
        return stories;
      } else {
        print(
          '📖 StoryService: Failed to load stories feed: ${response.statusCode}',
        );
        print('📖 StoryService: Response body: ${response.body}');

        // Return empty list instead of throwing exception for better UX
        return [];
      }
    } catch (e) {
      print('📖 StoryService: Error fetching stories feed: $e');

      // Return empty list instead of throwing exception for better UX
      return [];
    }
  }

  /// Get stories for a specific user
  static Future<List<StoryModel>> getUserStories(String userId) async {
    try {
      print('📖 StoryService: Fetching stories for user: $userId');

      final headers = await _getHeaders() ?? _getPublicHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/api/stories/user/$userId'), headers: headers)
          .timeout(timeoutDuration);

      print(
        '📖 StoryService: User stories response status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> storiesData = data['data'] ?? [];

        final stories =
            storiesData
                .map((storyData) => StoryModel.fromJson(storyData))
                .toList();

        print(
          '📖 StoryService: Successfully loaded ${stories.length} stories for user',
        );
        return stories;
      } else {
        print(
          '📖 StoryService: Failed to load user stories: ${response.statusCode}',
        );
        throw Exception('Failed to load user stories: ${response.statusCode}');
      }
    } catch (e) {
      print('📖 StoryService: Error fetching user stories: $e');
      throw Exception('Failed to fetch user stories: $e');
    }
  }

  /// Get a specific story by ID
  static Future<StoryModel> getStory(String storyId) async {
    try {
      print('📖 StoryService: Fetching story: $storyId');

      final headers = await _getHeaders() ?? _getPublicHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/api/stories/$storyId'), headers: headers)
          .timeout(timeoutDuration);

      print('📖 StoryService: Story response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final story = StoryModel.fromJson(data['data']);

        print('📖 StoryService: Successfully loaded story');
        return story;
      } else {
        print('📖 StoryService: Failed to load story: ${response.statusCode}');
        throw Exception('Failed to load story: ${response.statusCode}');
      }
    } catch (e) {
      print('📖 StoryService: Error fetching story: $e');
      throw Exception('Failed to fetch story: $e');
    }
  }

  /// Create a text story
  static Future<StoryResult> createTextStory({
    required String textContent,
    StoryTextStyle? textStyle,
    String? caption,
    List<String>? mentions,
    List<String>? hashtags,
    StoryPrivacyType privacy = StoryPrivacyType.public,
    List<String>? customViewers,
    bool allowReplies = true,
    bool allowReactions = true,
    bool allowScreenshot = true,
  }) async {
    try {
      print('📖 StoryService: Creating text story');

      final headers = await _getHeaders();
      if (headers == null) {
        throw Exception('Authentication required to create stories');
      }

      final body = {
        'mediaType': 'text',
        'textContent': textContent,
        'textStyle': textStyle?.toJson(),
        'caption': caption,
        'mentions': mentions ?? [],
        'hashtags': hashtags ?? [],
        'privacy': privacy.name,
        'customViewers': customViewers ?? [],
        'allowReplies': allowReplies,
        'allowReactions': allowReactions,
        'allowScreenshot': allowScreenshot,
      };

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/stories'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(timeoutDuration);

      print(
        '📖 StoryService: Create text story response status: ${response.statusCode}',
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final story = StoryModel.fromJson(data['data']);

        print('📖 StoryService: Successfully created text story');
        return StoryResult.success('Story created successfully', story: story);
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage =
            errorData['message'] ?? 'Failed to create text story';
        print('📖 StoryService: Failed to create text story: $errorMessage');
        return StoryResult.error(errorMessage);
      }
    } catch (e) {
      print('📖 StoryService: Error creating text story: $e');
      return StoryResult.error('Failed to create text story: $e');
    }
  }

  /// Create a media story (image, video, audio)
  static Future<StoryResult> createMediaStory({
    required File mediaFile,
    required StoryMediaType mediaType,
    String? caption,
    List<String>? mentions,
    List<String>? hashtags,
    StoryPrivacyType privacy = StoryPrivacyType.public,
    List<String>? customViewers,
    bool allowReplies = true,
    bool allowReactions = true,
    bool allowScreenshot = true,
  }) async {
    try {
      print('📖 StoryService: Creating ${mediaType.name} story');

      final headers = await _getHeaders();
      if (headers == null) {
        throw Exception('Authentication required to create stories');
      }

      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/stories'),
      );

      // Add headers (remove Content-Type as it will be set automatically for multipart)
      final authHeaders = Map<String, String>.from(headers);
      authHeaders.remove('Content-Type');
      request.headers.addAll(authHeaders);

      // Add file
      final mediaTypeStr = _getMediaTypeString(mediaFile.path);
      print('📹 Media file debug:');
      print('  - File path: ${mediaFile.path}');
      print('  - Media type string: $mediaTypeStr');
      print('  - File exists: ${await mediaFile.exists()}');
      print('  - File size: ${await mediaFile.length()} bytes');

      request.files.add(
        await http.MultipartFile.fromPath(
          'media',
          mediaFile.path,
          contentType: MediaType.parse(mediaTypeStr),
        ),
      );

      print('📹 Added file to multipart request');

      // Add form fields
      request.fields['mediaType'] = mediaType.name;
      if (caption != null) request.fields['caption'] = caption;
      if (mentions != null) request.fields['mentions'] = jsonEncode(mentions);
      if (hashtags != null) request.fields['hashtags'] = jsonEncode(hashtags);
      request.fields['privacy'] = privacy.name;
      if (customViewers != null)
        request.fields['customViewers'] = jsonEncode(customViewers);
      request.fields['allowReplies'] = allowReplies.toString();
      request.fields['allowReactions'] = allowReactions.toString();
      request.fields['allowScreenshot'] = allowScreenshot.toString();

      final response = await request.send().timeout(timeoutDuration);
      final responseBody = await response.stream.bytesToString();

      print(
        '📖 StoryService: Create media story response status: ${response.statusCode}',
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(responseBody);
        final story = StoryModel.fromJson(data['data']);

        print('📖 StoryService: Successfully created ${mediaType.name} story');
        return StoryResult.success('Story created successfully', story: story);
      } else {
        final errorData = jsonDecode(responseBody);
        final errorMessage =
            errorData['message'] ?? 'Failed to create media story';
        print('📖 StoryService: Failed to create media story: $errorMessage');
        return StoryResult.error(errorMessage);
      }
    } catch (e) {
      print('📖 StoryService: Error creating media story: $e');
      return StoryResult.error('Failed to create media story: $e');
    }
  }

  /// Mark story as viewed
  static Future<void> markStoryAsViewed(String storyId) async {
    try {
      print('📖 StoryService: Marking story as viewed: $storyId');

      final headers = await _getHeaders();
      if (headers == null) {
        print('📖 StoryService: No auth headers, skipping view tracking');
        return;
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/stories/$storyId/view'),
            headers: headers,
          )
          .timeout(timeoutDuration);

      print(
        '📖 StoryService: Mark viewed response status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        print('📖 StoryService: Successfully marked story as viewed');
      } else {
        print(
          '📖 StoryService: Failed to mark story as viewed: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('📖 StoryService: Error marking story as viewed: $e');
      // Don't throw error for view tracking failures
    }
  }

  /// React to a story
  static Future<void> reactToStory(
    String storyId,
    StoryReactionType reactionType,
  ) async {
    try {
      print(
        '📖 StoryService: Reacting to story: $storyId with ${reactionType.name}',
      );

      final headers = await _getHeaders();
      if (headers == null) {
        throw Exception('Authentication required to react to stories');
      }

      final body = {'reactionType': reactionType.name};

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/stories/$storyId/react'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(timeoutDuration);

      print('📖 StoryService: React response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('📖 StoryService: Successfully reacted to story');
      } else {
        final errorData = jsonDecode(response.body);
        print(
          '📖 StoryService: Failed to react to story: ${errorData['message']}',
        );
        throw Exception(errorData['message'] ?? 'Failed to react to story');
      }
    } catch (e) {
      print('📖 StoryService: Error reacting to story: $e');
      throw Exception('Failed to react to story: $e');
    }
  }

  /// Remove reaction from story
  static Future<void> removeReactionFromStory(String storyId) async {
    try {
      print('📖 StoryService: Removing reaction from story: $storyId');

      final headers = await _getHeaders();
      if (headers == null) {
        throw Exception('Authentication required to remove reactions');
      }

      final response = await http
          .delete(
            Uri.parse('$baseUrl/api/stories/$storyId/react'),
            headers: headers,
          )
          .timeout(timeoutDuration);

      print(
        '📖 StoryService: Remove reaction response status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        print('📖 StoryService: Successfully removed reaction from story');
      } else {
        final errorData = jsonDecode(response.body);
        print(
          '📖 StoryService: Failed to remove reaction: ${errorData['message']}',
        );
        throw Exception(errorData['message'] ?? 'Failed to remove reaction');
      }
    } catch (e) {
      print('📖 StoryService: Error removing reaction: $e');
      throw Exception('Failed to remove reaction: $e');
    }
  }

  /// Delete a story
  static Future<void> deleteStory(String storyId) async {
    try {
      print('📖 StoryService: Deleting story: $storyId');

      final headers = await _getHeaders();
      if (headers == null) {
        throw Exception('Authentication required to delete stories');
      }

      final response = await http
          .delete(Uri.parse('$baseUrl/api/stories/$storyId'), headers: headers)
          .timeout(timeoutDuration);

      print(
        '📖 StoryService: Delete story response status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        print('📖 StoryService: Successfully deleted story');
      } else {
        final errorData = jsonDecode(response.body);
        print(
          '📖 StoryService: Failed to delete story: ${errorData['message']}',
        );
        throw Exception(errorData['message'] ?? 'Failed to delete story');
      }
    } catch (e) {
      print('📖 StoryService: Error deleting story: $e');
      throw Exception('Failed to delete story: $e');
    }
  }

  /// Get story viewers
  static Future<List<StoryViewer>> getStoryViewers(String storyId) async {
    try {
      print('📖 StoryService: Fetching story viewers: $storyId');

      final headers = await _getHeaders();
      if (headers == null) {
        throw Exception('Authentication required to view story viewers');
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/api/stories/$storyId/viewers'),
            headers: headers,
          )
          .timeout(timeoutDuration);

      print(
        '📖 StoryService: Story viewers response status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> viewersData = data['data'] ?? [];

        final viewers =
            viewersData
                .map((viewerData) => StoryViewer.fromJson(viewerData))
                .toList();

        print(
          '📖 StoryService: Successfully loaded ${viewers.length} story viewers',
        );
        return viewers;
      } else {
        final errorData = jsonDecode(response.body);
        print(
          '📖 StoryService: Failed to load story viewers: ${errorData['message']}',
        );
        throw Exception(errorData['message'] ?? 'Failed to load story viewers');
      }
    } catch (e) {
      print('📖 StoryService: Error fetching story viewers: $e');
      throw Exception('Failed to fetch story viewers: $e');
    }
  }

  /// Get story reactions
  static Future<List<StoryReaction>> getStoryReactions(String storyId) async {
    try {
      print('📖 StoryService: Fetching story reactions: $storyId');

      final headers = await _getHeaders();
      if (headers == null) {
        throw Exception('Authentication required to view story reactions');
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/api/stories/$storyId/reactions'),
            headers: headers,
          )
          .timeout(timeoutDuration);

      print(
        '📖 StoryService: Story reactions response status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> reactionsData = data['data'] ?? [];

        final reactions =
            reactionsData
                .map((reactionData) => StoryReaction.fromJson(reactionData))
                .toList();

        print(
          '📖 StoryService: Successfully loaded ${reactions.length} story reactions',
        );
        return reactions;
      } else {
        final errorData = jsonDecode(response.body);
        print(
          '📖 StoryService: Failed to load story reactions: ${errorData['message']}',
        );
        throw Exception(
          errorData['message'] ?? 'Failed to load story reactions',
        );
      }
    } catch (e) {
      print('📖 StoryService: Error fetching story reactions: $e');
      throw Exception('Failed to fetch story reactions: $e');
    }
  }

  /// Helper method to get media type string for file
  static String _getMediaTypeString(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();

    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'm4a':
        return 'audio/mp4';
      default:
        return 'application/octet-stream';
    }
  }
}

/// Result class for story operations
class StoryResult {
  final bool success;
  final String message;
  final StoryModel? story;

  const StoryResult({required this.success, required this.message, this.story});

  factory StoryResult.success(String message, {StoryModel? story}) {
    return StoryResult(success: true, message: message, story: story);
  }

  factory StoryResult.error(String message) {
    return StoryResult(success: false, message: message);
  }
}
