import 'package:flutter/material.dart';
import '../services/contextual_auth_service.dart';

/// Helper function to get user-friendly error messages
String _getErrorMessage(String error) {
  if (error.contains('network') || error.contains('connection')) {
    return 'Check your internet connection and try again';
  } else if (error.contains('timeout')) {
    return 'Request timed out. Please try again';
  } else if (error.contains('unauthorized') || error.contains('401')) {
    return 'Please sign in again to continue';
  } else if (error.contains('forbidden') || error.contains('403')) {
    return 'You don\'t have permission for this action';
  } else if (error.contains('not found') || error.contains('404')) {
    return 'Content not found';
  } else if (error.contains('server') || error.contains('500')) {
    return 'Server error. Please try again later';
  } else {
    return 'Something went wrong. Please try again';
  }
}

/// Examples of how to integrate contextual authentication into UI components
/// Following TikTok/Instagram pattern where auth is feature-gated, not route-gated

/// Example: Like button with contextual auth
class ContextualLikeButton extends StatefulWidget {
  final String postId;
  final bool isLiked;
  final int likeCount;
  final VoidCallback? onLikeChanged;

  const ContextualLikeButton({
    super.key,
    required this.postId,
    required this.isLiked,
    required this.likeCount,
    this.onLikeChanged,
  });

  @override
  State<ContextualLikeButton> createState() => _ContextualLikeButtonState();
}

class _ContextualLikeButtonState extends State<ContextualLikeButton> {
  bool _isLoading = false;

  Future<void> _handleLike() async {
    // Check auth contextually - only when user tries to like
    final canLike = await ContextualAuthService.canLike(context);
    if (!canLike) return; // User cancelled login or not authenticated

    setState(() => _isLoading = true);

    try {
      // Perform like action - implement these methods in PostService
      if (widget.isLiked) {
        // await PostService.unlikePost(widget.postId);
        print('Unlike post: ${widget.postId}');
      } else {
        // await PostService.likePost(widget.postId);
        print('Like post: ${widget.postId}');
      }
      widget.onLikeChanged?.call();

      // Show success message
      if (mounted) {
        ContextualAuthService.showActionSuccess(
          context,
          message: widget.isLiked ? 'Post unliked' : 'Post liked!',
        );
      }
    } catch (e) {
      if (mounted) {
        ContextualAuthService.showActionError(
          context,
          action: widget.isLiked ? 'unlike post' : 'like post',
          error: _getErrorMessage(e.toString()),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _isLoading ? null : _handleLike,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _isLoading
                ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : Icon(
                  widget.isLiked ? Icons.favorite : Icons.favorite_border,
                  color: widget.isLiked ? Colors.red : Colors.grey[600],
                  size: 20,
                ),
            const SizedBox(width: 4),
            Text(
              '${widget.likeCount}',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

/// Example: Comment button with contextual auth
class ContextualCommentButton extends StatelessWidget {
  final String postId;
  final int commentCount;

  const ContextualCommentButton({
    super.key,
    required this.postId,
    required this.commentCount,
  });

  Future<void> _handleComment(BuildContext context) async {
    // Check auth contextually - only when user tries to comment
    final canComment = await ContextualAuthService.canComment(context);
    if (!canComment) return; // User cancelled login

    try {
      // Show comment bottom sheet or navigate to comments
      // Implementation depends on your comment UI
      ContextualAuthService.showActionSuccess(
        context,
        message: 'Opening comments...',
      );

      // TODO: Implement actual comment functionality
      // await showCommentsBottomSheet(context, postId);
    } catch (e) {
      ContextualAuthService.showActionError(
        context,
        action: 'open comments',
        error: _getErrorMessage(e.toString()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _handleComment(context),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, color: Colors.grey[600], size: 20),
            const SizedBox(width: 4),
            Text(
              '$commentCount',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

/// Example: Follow button with contextual auth
class ContextualFollowButton extends StatefulWidget {
  final String userId;
  final bool isFollowing;
  final VoidCallback? onFollowChanged;

  const ContextualFollowButton({
    super.key,
    required this.userId,
    required this.isFollowing,
    this.onFollowChanged,
  });

  @override
  State<ContextualFollowButton> createState() => _ContextualFollowButtonState();
}

class _ContextualFollowButtonState extends State<ContextualFollowButton> {
  bool _isLoading = false;

  Future<void> _handleFollow() async {
    // Check auth contextually - only when user tries to follow
    final canFollow = await ContextualAuthService.canFollow(context);
    if (!canFollow) return; // User cancelled login

    setState(() => _isLoading = true);

    try {
      // Perform follow/unfollow action
      if (widget.isFollowing) {
        // await UserService.unfollowUser(widget.userId);
      } else {
        // await UserService.followUser(widget.userId);
      }
      widget.onFollowChanged?.call();

      // Show success message
      if (mounted) {
        ContextualAuthService.showActionSuccess(
          context,
          message: widget.isFollowing ? 'Unfollowed user' : 'Following user!',
        );
      }
    } catch (e) {
      if (mounted) {
        ContextualAuthService.showActionError(
          context,
          action: widget.isFollowing ? 'unfollow user' : 'follow user',
          error: _getErrorMessage(e.toString()),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handleFollow,
      style: ElevatedButton.styleFrom(
        backgroundColor:
            widget.isFollowing ? Colors.grey[300] : const Color(0xFF4ECDC4),
        foregroundColor: widget.isFollowing ? Colors.black : Colors.white,
        minimumSize: const Size(80, 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child:
          _isLoading
              ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
              : Text(
                widget.isFollowing ? 'Following' : 'Follow',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
    );
  }
}

/// Example: Create post FAB with contextual auth
class ContextualCreatePostFAB extends StatelessWidget {
  const ContextualCreatePostFAB({super.key});

  Future<void> _handleCreatePost(BuildContext context) async {
    // Check auth contextually - only when user tries to create post
    final canPost = await ContextualAuthService.canPost(context);
    if (!canPost) return; // User cancelled login

    try {
      // Navigate to create post screen
      Navigator.of(context).pushNamed('/create-post');

      // Show success message
      ContextualAuthService.showActionSuccess(
        context,
        message: 'Ready to create your post!',
      );
    } catch (e) {
      ContextualAuthService.showActionError(
        context,
        action: 'create post',
        error: _getErrorMessage(e.toString()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _handleCreatePost(context),
      backgroundColor: const Color(0xFF4ECDC4),
      child: const Icon(Icons.add, color: Colors.white),
    );
  }
}

/// Example: Profile access with contextual auth
class ContextualProfileButton extends StatelessWidget {
  const ContextualProfileButton({super.key});

  Future<void> _handleProfileAccess(BuildContext context) async {
    // Check if user can access profile
    if (ContextualAuthService.canPerformAction()) {
      // User is authenticated, go to profile
      Navigator.of(context).pushNamed('/profile');
    } else {
      // Show contextual auth prompt
      final canAccess = await ContextualAuthService.canAccessProfile(context);
      if (canAccess) {
        Navigator.of(context).pushNamed('/profile');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => _handleProfileAccess(context),
      icon: Icon(
        Icons.person,
        color:
            ContextualAuthService.canPerformAction()
                ? const Color(0xFF4ECDC4)
                : Colors.grey[600],
      ),
    );
  }
}

/// Example: Smart UI that shows different states based on auth
class SmartAuthAwareWidget extends StatelessWidget {
  const SmartAuthAwareWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = ContextualAuthService.canPerformAction();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isAuthenticated ? 'Welcome back!' : 'Explore as guest',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            isAuthenticated
                ? 'You have full access to all features'
                : 'Sign in to unlock all features like posting, liking, and following',
            style: TextStyle(color: Colors.grey[600]),
          ),
          if (!isAuthenticated) ...[
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                await ContextualAuthService.requireAuthForFeature(
                  context,
                  featureName: 'unlock all features',
                  customMessage:
                      'Join our community to share and connect with others',
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4ECDC4),
                foregroundColor: Colors.white,
              ),
              child: const Text('Sign In'),
            ),
          ],
        ],
      ),
    );
  }
}
