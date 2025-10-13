import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message_model.dart';

/// Cache for messages per chat - Industry standard approach
class MessagesCacheNotifier
    extends StateNotifier<Map<String, List<MessageModel>>> {
  MessagesCacheNotifier() : super({});

  /// Get cached messages for a chat
  List<MessageModel>? getCachedMessages(String chatId) {
    return state[chatId];
  }

  /// Cache messages for a chat
  void cacheMessages(String chatId, List<MessageModel> messages) {
    state = {...state, chatId: List.from(messages)};
  }

  /// Add a new message to cache (optimistic UI)
  void addMessage(String chatId, MessageModel message) {
    final cached = state[chatId] ?? [];
    state = {
      ...state,
      chatId: [...cached, message],
    };
  }

  /// Update a message in cache
  void updateMessage(String chatId, MessageModel updatedMessage) {
    final cached = state[chatId];
    if (cached == null) return;

    final index = cached.indexWhere((m) => m.id == updatedMessage.id);
    if (index != -1) {
      final updated = List<MessageModel>.from(cached);
      updated[index] = updatedMessage;
      state = {...state, chatId: updated};
    }
  }

  /// Remove a message from cache (optimistic delete)
  void removeMessage(String chatId, String messageId) {
    final cached = state[chatId];
    if (cached == null) return;

    state = {...state, chatId: cached.where((m) => m.id != messageId).toList()};
  }

  /// Clear cache for a specific chat
  void clearChat(String chatId) {
    final newState = Map<String, List<MessageModel>>.from(state);
    newState.remove(chatId);
    state = newState;
  }

  /// Clear all cache
  void clearAll() {
    state = {};
  }
}

/// Global messages cache provider
final messagesCacheProvider = StateNotifierProvider<
  MessagesCacheNotifier,
  Map<String, List<MessageModel>>
>((ref) {
  return MessagesCacheNotifier();
});
