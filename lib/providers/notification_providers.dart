import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/notification_service.dart';

/// Notifications Provider
final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, AsyncValue<List<Map<String, dynamic>>>>((ref) {
  return NotificationsNotifier();
});

class NotificationsNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  NotificationsNotifier() : super(const AsyncValue.loading()) {
    _loadNotifications();
  }

  List<Map<String, dynamic>> _notifications = [];
  int _currentPage = 1;
  bool _hasMore = true;

  Future<void> _loadNotifications({bool loadMore = false}) async {
    try {
      if (loadMore && !_hasMore) return;

      if (!loadMore) {
        state = const AsyncValue.loading();
        _notifications = [];
        _currentPage = 1;
      }

      final notifications = await NotificationService.getNotifications(
        page: _currentPage,
        limit: 20,
      );

      if (loadMore) {
        _notifications.addAll(notifications);
        _currentPage++;
      } else {
        _notifications = notifications;
      }

      _hasMore = notifications.length >= 20;
      state = AsyncValue.data(_notifications);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> refresh() async {
    await _loadNotifications();
  }

  Future<void> loadMore() async {
    await _loadNotifications(loadMore: true);
  }

  Future<Map<String, dynamic>> markAsRead(String notificationId) async {
    final result = await NotificationService.markAsRead(notificationId);

    if (result['success'] == true) {
      // Update local state
      _notifications = _notifications.map((n) {
        if (n['_id'] == notificationId || n['id'] == notificationId) {
          return {...n, 'isRead': true};
        }
        return n;
      }).toList();
      state = AsyncValue.data([..._notifications]);
    }

    return result;
  }

  Future<Map<String, dynamic>> markAllAsRead() async {
    final result = await NotificationService.markAllAsRead();

    if (result['success'] == true) {
      // Update local state
      _notifications = _notifications.map((n) => {...n, 'isRead': true}).toList();
      state = AsyncValue.data([..._notifications]);
    }

    return result;
  }

  Future<Map<String, dynamic>> deleteNotification(String notificationId) async {
    final result = await NotificationService.deleteNotification(notificationId);

    if (result['success'] == true) {
      // Remove from local state
      _notifications.removeWhere((n) => n['_id'] == notificationId || n['id'] == notificationId);
      state = AsyncValue.data([..._notifications]);
    }

    return result;
  }
}

/// Unread Count Provider
final unreadCountProvider =
    StateNotifierProvider<UnreadCountNotifier, AsyncValue<int>>((ref) {
  return UnreadCountNotifier();
});

class UnreadCountNotifier extends StateNotifier<AsyncValue<int>> {
  UnreadCountNotifier() : super(const AsyncValue.loading()) {
    _loadCount();
  }

  Future<void> _loadCount() async {
    try {
      state = const AsyncValue.loading();

      final count = await NotificationService.getUnreadCount();

      state = AsyncValue.data(count);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> refresh() async {
    await _loadCount();
  }

  void decrement() {
    final currentCount = state.value ?? 0;
    if (currentCount > 0) {
      state = AsyncValue.data(currentCount - 1);
    }
  }

  void reset() {
    state = const AsyncValue.data(0);
  }
}

