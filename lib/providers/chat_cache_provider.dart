import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_model.dart';

// Chat list cache provider
final chatCacheProvider = StateNotifierProvider<ChatCacheNotifier, List<ChatModel>>((ref) {
  return ChatCacheNotifier();
});

class ChatCacheNotifier extends StateNotifier<List<ChatModel>> {
  ChatCacheNotifier() : super([]);

  List<ChatModel> get cachedChats => state;
  
  bool get hasCache => state.isNotEmpty;

  void cacheChats(List<ChatModel> chats) {
    state = [...chats];
  }

  void updateChat(ChatModel chat) {
    final index = state.indexWhere((c) => c.id == chat.id);
    if (index != -1) {
      final updatedChats = [...state];
      updatedChats[index] = chat;
      state = updatedChats;
    }
  }

  void addChat(ChatModel chat) {
    // Add to top of list if not already present
    final exists = state.any((c) => c.id == chat.id);
    if (!exists) {
      state = [chat, ...state];
    }
  }

  void removeChat(String chatId) {
    state = state.where((c) => c.id != chatId).toList();
  }

  void moveToTop(String chatId) {
    final index = state.indexWhere((c) => c.id == chatId);
    if (index != -1 && index != 0) {
      final chat = state[index];
      final updatedChats = [...state];
      updatedChats.removeAt(index);
      updatedChats.insert(0, chat);
      state = updatedChats;
    }
  }

  void clearCache() {
    state = [];
  }
}

