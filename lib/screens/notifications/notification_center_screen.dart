import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/notification_providers.dart';
import '../../widgets/custom_toaster.dart';

/// Notification Center Screen
/// Lists in-app notifications (likes, comments, follows, gifts, etc.)
class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends ConsumerState<NotificationCenterScreen> {
  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1D1E33),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          notificationsAsync.maybeWhen(
            data: (list) {
              final hasUnread = list.any((n) => n['isRead'] != true);
              if (!hasUnread) return const SizedBox.shrink();
              return TextButton(
                onPressed: () async {
                  await ref.read(notificationsProvider.notifier).markAllAsRead();
                  ref.read(unreadCountProvider.notifier).refresh();
                  if (mounted) {
                    ToasterService.showSuccess(context, 'All marked as read');
                  }
                },
                child: const Text('Mark all read', style: TextStyle(color: Color(0xFF4ECDC4))),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF4ECDC4)),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Failed to load notifications',
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => ref.read(notificationsProvider.notifier).refresh(),
                child: const Text('Retry', style: TextStyle(color: Color(0xFF4ECDC4))),
              ),
            ],
          ),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 80, color: Colors.white.withOpacity(0.4)),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Likes, comments, follows and gifts will appear here',
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(notificationsProvider.notifier).refresh();
              ref.read(unreadCountProvider.notifier).refresh();
            },
            color: const Color(0xFF4ECDC4),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: notifications.length + 1,
              itemBuilder: (context, index) {
                if (index == notifications.length) {
                  return const SizedBox(height: 24);
                }
                final n = notifications[index];
                return _NotificationTile(
                  notification: n,
                  onTap: () => _onNotificationTap(n),
                  onMarkRead: () async {
                    final id = n['_id'] ?? n['id'];
                    if (id != null) {
                      await ref.read(notificationsProvider.notifier).markAsRead(id.toString());
                      ref.read(unreadCountProvider.notifier).refresh();
                    }
                  },
                  onDelete: () => _onDelete(n),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _onNotificationTap(Map<String, dynamic> n) async {
    final id = n['_id'] ?? n['id'];
    if (id != null && n['isRead'] != true) {
      await ref.read(notificationsProvider.notifier).markAsRead(id.toString());
      ref.read(unreadCountProvider.notifier).refresh();
    }
    // TODO: Navigate to post, profile, chat, etc. based on n['type'] and n['data']
    // e.g. postId -> post detail, followerId -> profile, chatId -> chat
  }

  Future<void> _onDelete(Map<String, dynamic> n) async {
    final id = n['_id'] ?? n['id'];
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1D1E33),
        title: const Text('Delete notification?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This notification will be removed.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(notificationsProvider.notifier).deleteNotification(id.toString());
      ref.read(unreadCountProvider.notifier).refresh();
    }
  }
}

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onTap;
  final VoidCallback onMarkRead;
  final VoidCallback onDelete;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onMarkRead,
    required this.onDelete,
  });

  IconData _iconForType(String? type) {
    switch (type) {
      case 'like':
        return Icons.favorite;
      case 'comment':
        return Icons.comment;
      case 'follow':
        return Icons.person_add;
      case 'gift':
        return Icons.card_giftcard;
      case 'chat':
        return Icons.chat;
      case 'live':
        return Icons.live_tv;
      case 'mention':
        return Icons.alternate_email;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRead = notification['isRead'] == true;
    final title = notification['title'] as String? ?? 'Notification';
    final body = notification['body'] as String? ?? '';
    final type = notification['type'] as String? ?? 'system';

    return Dismissible(
      key: Key(notification['_id']?.toString() ?? notification['id']?.toString() ?? ''),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: isRead
              ? const Color(0xFF1D1E33)
              : const Color(0xFF4ECDC4).withOpacity(0.3),
          child: Icon(_iconForType(type), color: const Color(0xFF4ECDC4), size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
          ),
        ),
        subtitle: body.isNotEmpty
            ? Text(
                body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              )
            : null,
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white70),
          color: const Color(0xFF1D1E33),
          onSelected: (value) {
            if (value == 'read' && !isRead) onMarkRead();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (ctx) => [
            if (!isRead)
              const PopupMenuItem(
                value: 'read',
                child: Text('Mark as read', style: TextStyle(color: Colors.white)),
              ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }
}
