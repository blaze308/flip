import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';

class ShareService {
  static const String appName = 'Flip';
  static const String appUrl =
      'https://flip.app'; // Replace with your actual domain
  static const String appStoreUrl =
      'https://apps.apple.com/app/flip'; // Replace with actual
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.flip.app'; // Replace with actual

  /// Share a post with deep link (HTTPS URL for rich preview)
  static Future<void> sharePost({
    required String postId,
    required String authorName,
    String? content,
    String? imageUrl,
    BuildContext? context,
  }) async {
    try {
      // Share HTTPS URL - social media apps will show rich preview automatically
      final shareUrl = '$appUrl/post/$postId';

      await Share.share(
        shareUrl,
        subject: 'Check out this post by @$authorName on $appName',
      );

      print('📤 ShareService: Post shared with URL: $shareUrl');
    } catch (e) {
      print('❌ ShareService: Error sharing post: $e');
      rethrow;
    }
  }

  /// Share a reel/video with deep link (HTTPS URL for rich preview)
  static Future<void> shareReel({
    required String reelId,
    required String authorName,
    String? caption,
    String? thumbnailUrl,
    BuildContext? context,
  }) async {
    try {
      // Share HTTPS URL - social media apps will show rich preview automatically
      final shareUrl = '$appUrl/reel/$reelId';

      await Share.share(
        shareUrl,
        subject: 'Check out this reel by @$authorName on $appName',
      );

      print('📤 ShareService: Reel shared with URL: $shareUrl');
    } catch (e) {
      print('❌ ShareService: Error sharing reel: $e');
      rethrow;
    }
  }

  /// Share a user profile (HTTPS URL for rich preview)
  static Future<void> shareProfile({
    required String userId,
    required String username,
    String? displayName,
    String? bio,
  }) async {
    try {
      // Share HTTPS URL - social media apps will show rich preview automatically
      final shareUrl = '$appUrl/user/$userId';

      await Share.share(shareUrl, subject: 'Check out @$username on $appName');

      print('📤 ShareService: Profile shared with URL: $shareUrl');
    } catch (e) {
      print('❌ ShareService: Error sharing profile: $e');
      rethrow;
    }
  }

  /// Share app download link
  static Future<void> shareApp() async {
    try {
      const shareText = '''
🎬 Join me on $appName - the best social media app!

Create and share amazing content, connect with friends, and discover trending videos.

Download now:
📱 iOS: $appStoreUrl
🤖 Android: $playStoreUrl
''';

      await Share.share(shareText, subject: 'Join me on $appName');

      print('📤 ShareService: App shared successfully');
    } catch (e) {
      print('❌ ShareService: Error sharing app: $e');
      rethrow;
    }
  }

  /// Generate deep link for a resource
  static String generateDeepLink(String resourceType, String resourceId) {
    return '$appUrl/$resourceType/$resourceId';
  }

  /// Parse deep link to extract resource type and ID
  static Map<String, String>? parseDeepLink(String url) {
    try {
      final uri = Uri.parse(url);

      // Expected format: https://flip.app/post/123 or https://flip.app/reel/456
      final pathSegments = uri.pathSegments;

      if (pathSegments.length >= 2) {
        return {
          'type': pathSegments[0], // post, reel, user, etc.
          'id': pathSegments[1],
        };
      }

      return null;
    } catch (e) {
      print('❌ ShareService: Error parsing deep link: $e');
      return null;
    }
  }
}
