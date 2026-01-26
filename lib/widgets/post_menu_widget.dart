import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import '../services/contextual_auth_service.dart';
import '../services/deep_link_service.dart';
import 'custom_toaster.dart';
import 'report_post_bottom_sheet.dart';

class PostMenuWidget extends StatelessWidget {
  final PostModel post;
  final VoidCallback? onPostUpdated;
  final VoidCallback? onPostHidden;
  final Function(String userId, bool isFollowing)? onFollowStatusChanged;

  const PostMenuWidget({
    Key? key,
    required this.post,
    this.onPostUpdated,
    this.onPostHidden,
    this.onFollowStatusChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white),
      color: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) => _handleMenuAction(context, value),
      itemBuilder:
          (BuildContext context) => [
            PopupMenuItem<String>(
              value: 'save',
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4ECDC4).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      post.isBookmarked
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      color: const Color(0xFF4ECDC4),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.isBookmarked ? 'Remove from Saved' : 'Save Post',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        post.isBookmarked
                            ? 'Remove from your saved items'
                            : 'Add to your saved items',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'notifications',
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.notifications_outlined,
                      color: Colors.orange,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Turn on notifications',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'for this post',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'hide',
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.visibility_off_outlined,
                      color: Colors.red,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hide Post',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'See fewer posts like this',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'share',
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.share_outlined,
                      color: Colors.green,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Share Post',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'Share with WhatsApp, Email, etc',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'unfollow',
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      post.isFollowingUser
                          ? Icons.person_remove
                          : Icons.person_add,
                      color: Colors.purple,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.isFollowingUser ? 'Unfollow' : 'Follow',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        post.isFollowingUser
                            ? 'Stop Seeing Post From This Page'
                            : 'See more posts from ${post.username}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'report',
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.flag_outlined,
                      color: Colors.red,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Report Post',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'Flag inappropriate content',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
    );
  }

  void _handleMenuAction(BuildContext context, String action) async {
    try {
      switch (action) {
        case 'save':
          await _toggleBookmark(context);
          break;
        case 'notifications':
          await _toggleNotifications(context);
          break;
        case 'hide':
          await _hidePost(context);
          break;
        case 'share':
          await _sharePostExternally(context);
          break;
        case 'unfollow':
          await _toggleFollow(context);
          break;
        case 'report':
          _showReportSheet(context);
          break;
      }
    } catch (e) {
      if (context.mounted) {
        ToasterService.showError(context, 'Action failed: ${e.toString()}');
      }
    }
  }

  Future<void> _toggleBookmark(BuildContext context) async {
    // Check authentication first
    final canBookmark = await ContextualAuthService.canBookmarkPosts(context);
    if (!canBookmark) return; // User cancelled login or not authenticated

    try {
      final result = await PostService.toggleBookmark(post.id);

      if (context.mounted) {
        ToasterService.showSuccess(context, result.message);
        onPostUpdated?.call();
      }
    } catch (e) {
      if (context.mounted) {
        ToasterService.showError(
          context,
          'Failed to ${post.isBookmarked ? 'remove bookmark' : 'bookmark post'}',
        );
      }
    }
  }

  Future<void> _toggleNotifications(BuildContext context) async {
    try {
      // Show notification settings dialog
      final result = await showDialog<Map<String, bool>>(
        context: context,
        builder: (context) => _NotificationSettingsDialog(),
      );

      if (result != null) {
        final updateResult = await PostService.updateNotifications(
          email: result['email'],
          push: result['push'],
          sms: result['sms'],
        );

        if (context.mounted) {
          ToasterService.showSuccess(context, updateResult.message);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ToasterService.showError(
          context,
          'Failed to update notification settings',
        );
      }
    }
  }

  Future<void> _hidePost(BuildContext context) async {
    // Check authentication first
    final canHide = await ContextualAuthService.canHidePosts(context);
    if (!canHide) return; // User cancelled login or not authenticated

    try {
      final result = await PostService.toggleHide(post.id);

      if (context.mounted) {
        ToasterService.showSuccess(context, result.message);
        onPostHidden?.call();
      }
    } catch (e) {
      if (context.mounted) {
        ToasterService.showError(context, 'Failed to hide post');
      }
    }
  }

  Future<void> _toggleFollow(BuildContext context) async {
    // Check authentication first
    final canFollow = await ContextualAuthService.canFollow(context);
    if (!canFollow) return; // User cancelled login or not authenticated

    try {
      final result = await PostService.toggleFollow(post.userId);

      if (context.mounted) {
        ToasterService.showSuccess(context, result.message);

        // Update follow status immediately for better UX
        final newFollowStatus = !post.isFollowingUser;
        onFollowStatusChanged?.call(post.userId, newFollowStatus);

        // Also call the general update callback
        onPostUpdated?.call();
      }
    } catch (e) {
      if (context.mounted) {
        ToasterService.showError(
          context,
          'Failed to ${post.isFollowingUser ? 'unfollow' : 'follow'} user',
        );
      }
    }
  }

  Future<void> _sharePostExternally(BuildContext context) async {
    try {
      // Generate deep link for the post
      final deepLink = DeepLinkService().generatePostLink(
        post.id,
        authorName: post.username,
      );

      // Create share message
      final message =
          'Check out this post by @${post.username} on AncientFlip!\n\n$deepLink\n\nDownload AncientFlip now!';

      // Open native share dialog
      await Share.share(message);

      if (context.mounted) {
        ToasterService.showSuccess(context, 'Post shared!');
      }
    } catch (e) {
      if (context.mounted) {
        ToasterService.showError(context, 'Failed to share post');
      }
    }
  }

  void _showReportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReportPostBottomSheet(postId: post.id),
    );
  }
}

class _NotificationSettingsDialog extends StatefulWidget {
  @override
  _NotificationSettingsDialogState createState() =>
      _NotificationSettingsDialogState();
}

class _NotificationSettingsDialogState
    extends State<_NotificationSettingsDialog> {
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _smsNotifications = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Notification Settings',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildNotificationOption(
            'Email Notifications',
            'Get notified via email',
            _emailNotifications,
            (value) => setState(() => _emailNotifications = value),
          ),
          const SizedBox(height: 16),
          _buildNotificationOption(
            'Push Notifications',
            'Get push notifications on your device',
            _pushNotifications,
            (value) => setState(() => _pushNotifications = value),
          ),
          const SizedBox(height: 16),
          _buildNotificationOption(
            'SMS Notifications',
            'Get notified via text message',
            _smsNotifications,
            (value) => setState(() => _smsNotifications = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop({
              'email': _emailNotifications,
              'push': _pushNotifications,
              'sms': _smsNotifications,
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4ECDC4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Save', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildNotificationOption(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF4ECDC4),
        ),
      ],
    );
  }
}
