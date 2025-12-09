import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../screens/viewer/immersive_viewer_screen.dart';
import 'post_service.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  // Domain for generating deep links
  static const String appDomain = 'flip-backend-mnpg.onrender.com';
  static const String appScheme = 'flip';

  /// Initialize deep link handling
  Future<void> initialize(BuildContext context) async {
    try {
      // Handle initial link if app was opened from a link
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        print('🔗 DeepLink: Initial link received: $initialLink');
        _handleDeepLink(context, initialLink);
      }

      // Listen for links while app is running
      _linkSubscription = _appLinks.uriLinkStream.listen(
        (uri) {
          print('🔗 DeepLink: Link received: $uri');
          _handleDeepLink(context, uri);
        },
        onError: (err) {
          print('❌ DeepLink: Error: $err');
        },
      );

      print('✅ DeepLink: Service initialized');
    } catch (e) {
      print('❌ DeepLink: Failed to initialize: $e');
    }
  }

  /// Handle incoming deep link
  void _handleDeepLink(BuildContext context, Uri uri) {
    try {
      print('🔗 DeepLink: Handling URI: $uri');
      print(
        '🔗 DeepLink: Scheme: ${uri.scheme}, Host: ${uri.host}, Path: ${uri.path}',
      );

      // Handle custom scheme: flip://open/post/123 or flip://open/reel/456
      if (uri.scheme == appScheme) {
        final pathSegments = uri.pathSegments;
        print('🔗 DeepLink: Custom scheme path segments: $pathSegments');

        if (pathSegments.length >= 2) {
          final action = pathSegments[0]; // 'open'
          final resourceType = pathSegments.length > 1 ? pathSegments[1] : null;
          final resourceId = pathSegments.length > 2 ? pathSegments[2] : null;

          print(
            '🔗 DeepLink: Action: $action, Type: $resourceType, ID: $resourceId',
          );

          if (resourceType != null && resourceId != null) {
            _handleResourceNavigation(context, resourceType, resourceId);
          }
        }
        return;
      }

      // Handle HTTPS links: https://flip-backend-mnpg.onrender.com/post/123
      final pathSegments = uri.pathSegments;
      print('🔗 DeepLink: HTTPS path segments: $pathSegments');

      if (pathSegments.isEmpty) {
        print('⚠️ DeepLink: No path segments found');
        return;
      }

      final resourceType = pathSegments[0];
      final resourceId = pathSegments.length > 1 ? pathSegments[1] : null;

      print('🔗 DeepLink: Type: $resourceType, ID: $resourceId');

      if (resourceId != null) {
        _handleResourceNavigation(context, resourceType, resourceId);
      }
    } catch (e) {
      print('❌ DeepLink: Error handling link: $e');
    }
  }

  /// Handle navigation based on resource type
  void _handleResourceNavigation(
    BuildContext context,
    String resourceType,
    String resourceId,
  ) {
    switch (resourceType) {
      case 'post':
        _navigateToPost(context, resourceId);
        break;

      case 'reel':
        _navigateToReel(context, resourceId);
        break;

      case 'user':
      case 'profile':
        _navigateToProfile(context, resourceId);
        break;

      case 'chat':
        _navigateToChat(context, resourceId);
        break;

      default:
        print('⚠️ DeepLink: Unknown resource type: $resourceType');
    }
  }

  /// Navigate to post with delay to ensure app is ready
  void _navigateToPost(BuildContext context, String postId) {
    print('📱 DeepLink: Navigating to post: $postId');

    // Add a small delay to ensure the app is fully loaded
    Future.delayed(const Duration(milliseconds: 500), () async {
      if (!context.mounted) return;

      try {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (context) => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
        );

        // Fetch the post
        final post = await PostService.getPost(postId);

        if (!context.mounted) return;

        // Close loading dialog
        Navigator.of(context).pop();

        // Navigate to immersive viewer with the post
        Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (context) =>
                    ImmersiveViewerScreen(posts: [post], initialIndex: 0),
          ),
        );

        print('✅ DeepLink: Successfully navigated to post: $postId');
      } catch (e) {
        print('❌ DeepLink: Error loading post: $e');

        if (!context.mounted) return;

        // Close loading dialog
        Navigator.of(context).pop();

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load post: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  /// Navigate to reel (reels are posts with video type)
  void _navigateToReel(BuildContext context, String reelId) {
    print('📱 DeepLink: Navigating to reel: $reelId');
    // Reels are just video posts, so use the same navigation
    _navigateToPost(context, reelId);
  }

  /// Navigate to user profile
  void _navigateToProfile(BuildContext context, String userId) {
    print('📱 DeepLink: Navigating to profile: $userId');

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!context.mounted) return;

      // TODO: Implement profile navigation when profile screen is available
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile viewing coming soon!'),
          backgroundColor: Colors.blue,
        ),
      );
    });
  }

  /// Navigate to chat
  void _navigateToChat(BuildContext context, String chatId) {
    print('📱 DeepLink: Navigating to chat: $chatId');

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!context.mounted) return;

      // TODO: Implement chat navigation when needed
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chat navigation coming soon!'),
          backgroundColor: Colors.blue,
        ),
      );
    });
  }

  /// Generate a deep link for a post
  String generatePostLink(String postId, {String? authorName}) {
    final uri = Uri.https(appDomain, '/post/$postId', {
      if (authorName != null) 'author': authorName,
      'utm_source': 'share',
      'utm_medium': 'app',
    });
    return uri.toString();
  }

  /// Generate a deep link for a reel
  String generateReelLink(String reelId, {String? authorName}) {
    final uri = Uri.https(appDomain, '/reel/$reelId', {
      if (authorName != null) 'author': authorName,
      'utm_source': 'share',
      'utm_medium': 'app',
    });
    return uri.toString();
  }

  /// Generate a deep link for a user profile
  String generateProfileLink(String userId, {String? username}) {
    final uri = Uri.https(appDomain, '/user/$userId', {
      if (username != null) 'username': username,
      'utm_source': 'share',
      'utm_medium': 'app',
    });
    return uri.toString();
  }

  /// Dispose resources
  void dispose() {
    _linkSubscription?.cancel();
  }
}

/// Deep link data model
class DeepLinkData {
  final String type; // post, reel, user, chat
  final String id;
  final Map<String, String>? queryParameters;

  DeepLinkData({required this.type, required this.id, this.queryParameters});

  factory DeepLinkData.fromUri(Uri uri) {
    final pathSegments = uri.pathSegments;
    return DeepLinkData(
      type: pathSegments.isNotEmpty ? pathSegments[0] : '',
      id: pathSegments.length > 1 ? pathSegments[1] : '',
      queryParameters: uri.queryParameters,
    );
  }
}
