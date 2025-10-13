import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../services/chat_service.dart';
import '../services/socket_service.dart';
import '../services/token_auth_service.dart';

// Chat list provider with caching (kept alive to maintain socket listeners)
final chatListProvider =
    StateNotifierProvider<ChatListNotifier, AsyncValue<List<ChatModel>>>((ref) {
      // Keep the provider alive even when not being watched
      ref.keepAlive();
      return ChatListNotifier(ref);
    });

class ChatListNotifier extends StateNotifier<AsyncValue<List<ChatModel>>> {
  ChatListNotifier(this.ref) : super(const AsyncValue.loading()) {
    _loadChats();
    _setupSocketListeners();
  }

  final Ref ref;
  List<ChatModel> _chats = [];
  StreamSubscription? _newMessageSubscription;
  StreamSubscription? _chatUpdateSubscription;

  Future<void> _loadChats() async {
    try {
      // Show data from previous state if available (no loading spinner on refresh)
      if (_chats.isNotEmpty) {
        // Keep showing current data while refreshing
        print('💬 ChatListNotifier: Refreshing with ${_chats.length} existing chats');
      } else {
        // First load - show loading
        state = const AsyncValue.loading();
      }

      final result = await ChatService.getChats(page: 1, limit: 50);

      if (result.success) {
        _chats = result.chats;
        state = AsyncValue.data(_chats);
        print('💬 ChatListNotifier: Loaded ${_chats.length} chats');
      } else {
        // Only show error if we don't have data
        if (_chats.isEmpty) {
          state = AsyncValue.error(result.message, StackTrace.current);
        }
      }
    } catch (e, stackTrace) {
      // Only show error if we don't have data
      if (_chats.isEmpty) {
        state = AsyncValue.error(e, stackTrace);
      }
      print('💬 ChatListNotifier: Error loading chats: $e');
    }
  }

  void _setupSocketListeners() {
    final socketService = SocketService.instance;

    print('💬 ChatListNotifier: Setting up socket listeners');

    // Cancel existing subscriptions if any
    _newMessageSubscription?.cancel();
    _chatUpdateSubscription?.cancel();

    // Listen for new messages to update chat list
    _newMessageSubscription = socketService.onNewMessage.listen((message) {
      print(
        '💬 ChatListNotifier: Received new message for chat ${message.chatId}',
      );
      updateChatWithNewMessage(message.chatId, message);
    });

    // Listen for chat updates
    _chatUpdateSubscription = socketService.onChatUpdate.listen((event) {
      print('💬 ChatListNotifier: Received chat update');
      _handleChatUpdate(event);
    });
  }

  @override
  void dispose() {
    _newMessageSubscription?.cancel();
    _chatUpdateSubscription?.cancel();
    super.dispose();
  }

  void updateChatWithNewMessage(String chatId, MessageModel message) {
    print('💬 ChatListNotifier: Updating chat $chatId with new message');

    final chatIndex = _chats.indexWhere((chat) => chat.id == chatId);
    if (chatIndex != -1) {
      // Move chat to top and update last message
      final chat = _chats.removeAt(chatIndex);

      // Don't increment unread count if it's from current user
      final currentUserId = TokenAuthService.currentUser?.id ?? '';
      final isFromCurrentUser = message.senderId == currentUserId;

      final updatedChat = chat.copyWith(
        unreadCount:
            isFromCurrentUser ? chat.unreadCount : chat.unreadCount + 1,
        lastMessage: LastMessage(
          messageId: message.id,
          content: message.content ?? _getMessageTypeLabel(message.type),
          type: message.type.name,
          senderId: message.senderId,
          sender: message.sender,
          timestamp: message.createdAt,
        ),
      );
      _chats.insert(0, updatedChat);
      state = AsyncValue.data([..._chats]);

      print('💬 ChatListNotifier: Chat updated and moved to top');
    } else {
      print('💬 ChatListNotifier: Chat not found in list, refreshing...');
      // Chat not in list, refresh to get it
      refresh();
    }
  }

  String _getMessageTypeLabel(MessageType type) {
    switch (type) {
      case MessageType.image:
        return '📷 Photo';
      case MessageType.video:
        return '🎥 Video';
      case MessageType.audio:
        return '🎤 Voice message';
      case MessageType.file:
        return '📎 File';
      case MessageType.lottie:
        return '🎭 Sticker';
      case MessageType.svga:
        return '🎨 Animation';
      default:
        return '';
    }
  }

  void _handleChatUpdate(ChatUpdateEvent event) {
    print(
      '💬 ChatListNotifier: Handling chat update type: ${event.updateType}',
    );

    switch (event.updateType) {
      case ChatUpdateType.messagesRead:
        // Reset unread count for this chat
        _resetUnreadCount(event.chatId);
        break;
      case ChatUpdateType.memberAdded:
      case ChatUpdateType.memberRemoved:
      case ChatUpdateType.infoUpdated:
      case ChatUpdateType.settingsChanged:
        // For other updates, refresh the list
        refresh();
        break;
    }
  }

  void _resetUnreadCount(String chatId) {
    final chatIndex = _chats.indexWhere((chat) => chat.id == chatId);
    if (chatIndex != -1) {
      final chat = _chats[chatIndex];
      if (chat.unreadCount > 0) {
        final updatedChat = chat.copyWith(unreadCount: 0);
        _chats[chatIndex] = updatedChat;
        state = AsyncValue.data([..._chats]);

        print('💬 ChatListNotifier: Reset unread count for chat $chatId');
      }
    }
  }

  Future<void> refresh() async {
    await _loadChats();
  }

  Future<void> loadMore() async {
    // Implement pagination if needed
    try {
      final result = await ChatService.getChats(
        page: (_chats.length ~/ 20) + 1,
        limit: 20,
      );

      if (result.success && result.chats.isNotEmpty) {
        _chats.addAll(result.chats);
        state = AsyncValue.data([..._chats]);
      }
    } catch (e) {
      // Handle error silently for pagination
    }
  }
}

// Messages provider for a specific chat with caching
final messagesProvider = StateNotifierProvider.family<
  MessagesNotifier,
  AsyncValue<List<MessageModel>>,
  String
>((ref, chatId) {
  return MessagesNotifier(ref, chatId);
});

class MessagesNotifier extends StateNotifier<AsyncValue<List<MessageModel>>> {
  MessagesNotifier(this.ref, this.chatId) : super(const AsyncValue.loading()) {
    _loadMessages();
    _setupSocketListeners();
  }

  final Ref ref;
  final String chatId;
  List<MessageModel> _messages = [];
  bool _isLoadingMore = false;

  Future<void> _loadMessages() async {
    try {
      state = const AsyncValue.loading();
      final result = await ChatService.getMessages(chatId, page: 1, limit: 50);

      if (result.success) {
        _messages = result.messages;
        state = AsyncValue.data(_messages);
      } else {
        state = AsyncValue.error(result.message, StackTrace.current);
      }
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  void _setupSocketListeners() {
    final socketService = SocketService.instance;

    // Listen for new messages in this chat
    socketService.onNewMessage.listen((message) {
      if (message.chatId == chatId) {
        addMessage(message);
      }
    });

    // Listen for message updates
    socketService.onMessageUpdate.listen((event) {
      if (_messages.any((m) => m.id == event.messageId)) {
        _handleMessageUpdate(event);
      }
    });
  }

  void addMessage(MessageModel message) {
    // Check if message already exists to prevent duplication
    final existingIndex = _messages.indexWhere((m) => m.id == message.id);
    if (existingIndex == -1) {
      _messages.add(message);
      state = AsyncValue.data([..._messages]);

      // Clear cache when new message arrives
      ChatService.clearMessageCache(chatId);
    }
  }

  void _handleMessageUpdate(MessageUpdateEvent event) {
    final messageIndex = _messages.indexWhere((m) => m.id == event.messageId);
    if (messageIndex != -1) {
      // Handle different update types
      switch (event.updateType) {
        case MessageUpdateType.reactionAdded:
        case MessageUpdateType.reactionRemoved:
        case MessageUpdateType.edited:
        case MessageUpdateType.deleted:
          // For now, just refresh the message list
          // In a real app, you'd update the specific message
          refresh();
          break;
        case MessageUpdateType.read:
        case MessageUpdateType.delivered:
          // Update message status without full refresh
          break;
      }
    }
  }

  Future<void> refresh() async {
    await _loadMessages();
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || _messages.isEmpty) return;

    _isLoadingMore = true;
    try {
      final result = await ChatService.getMessages(
        chatId,
        page: (_messages.length ~/ 50) + 1,
        limit: 50,
        before: _messages.first.createdAt,
      );

      if (result.success && result.messages.isNotEmpty) {
        _messages.insertAll(0, result.messages);
        state = AsyncValue.data([..._messages]);
      }
    } catch (e) {
      // Handle error silently for pagination
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> sendTextMessage(
    String content, {
    String? replyToMessageId,
  }) async {
    try {
      final result = await ChatService.sendTextMessage(
        chatId,
        content,
        replyToMessageId: replyToMessageId,
      );

      if (!result.success) {
        throw Exception(result.resultMessage);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> sendMediaMessage(
    MessageType type,
    dynamic file, {
    String? replyToMessageId,
  }) async {
    try {
      final result = await ChatService.sendMediaMessage(
        chatId,
        type,
        file,
        replyToMessageId: replyToMessageId,
      );

      if (!result.success) {
        throw Exception(result.resultMessage);
      }
    } catch (e) {
      rethrow;
    }
  }

  bool get isLoadingMore => _isLoadingMore;
}

// Current chat provider
final currentChatProvider = StateProvider<ChatModel?>((ref) => null);

// Typing users provider for a specific chat
final typingUsersProvider =
    StateNotifierProvider.family<TypingUsersNotifier, Set<String>, String>((
      ref,
      chatId,
    ) {
      return TypingUsersNotifier(ref, chatId);
    });

class TypingUsersNotifier extends StateNotifier<Set<String>> {
  TypingUsersNotifier(this.ref, this.chatId) : super({}) {
    _setupSocketListeners();
  }

  final Ref ref;
  final String chatId;

  void _setupSocketListeners() {
    final socketService = SocketService.instance;

    socketService.onTyping.listen((event) {
      if (event.chatId == chatId) {
        final currentUserId = TokenAuthService.currentUser?.id ?? '';
        if (event.userId == currentUserId) return; // Ignore own typing

        if (event.isTyping) {
          state = {...state, event.username};
        } else {
          state = {...state}..remove(event.username);
        }

        // Auto-remove typing indicator after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          state = {...state}..remove(event.username);
        });
      }
    });
  }
}

// Socket connection provider
final socketConnectionProvider =
    StateNotifierProvider<SocketConnectionNotifier, SocketConnectionState>((
      ref,
    ) {
      return SocketConnectionNotifier(ref);
    });

class SocketConnectionNotifier extends StateNotifier<SocketConnectionState> {
  SocketConnectionNotifier(this.ref)
    : super(SocketConnectionState.disconnected) {
    _setupSocketConnection();
  }

  final Ref ref;

  void _setupSocketConnection() {
    final socketService = SocketService.instance;

    socketService.onConnection.listen((event) {
      switch (event.type) {
        case ConnectionEventType.connected:
          state = SocketConnectionState.connected;
          break;
        case ConnectionEventType.disconnected:
          state = SocketConnectionState.disconnected;
          break;
        case ConnectionEventType.error:
          state = SocketConnectionState.error;
          break;
      }
    });

    // Connect if not already connected
    if (!socketService.isConnected) {
      socketService.connect();
    }
  }

  void connect() {
    SocketService.instance.connect();
  }

  void disconnect() {
    SocketService.instance.disconnect();
  }
}

enum SocketConnectionState { connected, disconnected, reconnecting, error }

// Chat search provider
final chatSearchProvider =
    StateNotifierProvider<ChatSearchNotifier, AsyncValue<List<ChatModel>>>((
      ref,
    ) {
      return ChatSearchNotifier(ref);
    });

class ChatSearchNotifier extends StateNotifier<AsyncValue<List<ChatModel>>> {
  ChatSearchNotifier(this.ref) : super(const AsyncValue.data([]));

  final Ref ref;
  String _currentQuery = '';

  Future<void> search(String query) async {
    if (query.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }

    if (query == _currentQuery) return;
    _currentQuery = query;

    try {
      state = const AsyncValue.loading();
      final result = await ChatService.getChats(
        page: 1,
        limit: 20,
        search: query,
      );

      if (result.success) {
        state = AsyncValue.data(result.chats);
      } else {
        state = AsyncValue.error(result.message, StackTrace.current);
      }
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  void clear() {
    _currentQuery = '';
    state = const AsyncValue.data([]);
  }
}
