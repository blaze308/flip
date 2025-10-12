import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

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
      final pathSegments = uri.pathSegments;

      if (pathSegments.isEmpty) {
        print('⚠️ DeepLink: No path segments found');
        return;
      }

      final resourceType = pathSegments[0];
      final resourceId = pathSegments.length > 1 ? pathSegments[1] : null;

      print('🔗 DeepLink: Type: $resourceType, ID: $resourceId');

      switch (resourceType) {
        case 'post':
          if (resourceId != null) {
            _navigateToPost(context, resourceId);
          }
          break;

        case 'reel':
          if (resourceId != null) {
            _navigateToReel(context, resourceId);
          }
          break;

        case 'user':
        case 'profile':
          if (resourceId != null) {
            _navigateToProfile(context, resourceId);
          }
          break;

        case 'chat':
          if (resourceId != null) {
            _navigateToChat(context, resourceId);
          }
          break;

        default:
          print('⚠️ DeepLink: Unknown resource type: $resourceType');
      }
    } catch (e) {
      print('❌ DeepLink: Error handling link: $e');
    }
  }

  /// Navigate to post
  void _navigateToPost(BuildContext context, String postId) {
    print('📱 DeepLink: Navigating to post: $postId');
    // TODO: Implement navigation to post detail screen
    // Navigator.of(context).pushNamed('/post', arguments: postId);
  }

  /// Navigate to reel
  void _navigateToReel(BuildContext context, String reelId) {
    print('📱 DeepLink: Navigating to reel: $reelId');
    // TODO: Implement navigation to reel screen
    // Navigator.of(context).pushNamed('/reel', arguments: reelId);
  }

  /// Navigate to user profile
  void _navigateToProfile(BuildContext context, String userId) {
    print('📱 DeepLink: Navigating to profile: $userId');
    // TODO: Implement navigation to profile screen
    // Navigator.of(context).pushNamed('/profile', arguments: userId);
  }

  /// Navigate to chat
  void _navigateToChat(BuildContext context, String chatId) {
    print('📱 DeepLink: Navigating to chat: $chatId');
    // TODO: Implement navigation to chat screen
    // Navigator.of(context).pushNamed('/chat', arguments: chatId);
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
