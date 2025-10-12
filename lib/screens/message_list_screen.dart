import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../models/chat_model.dart';
import '../services/chat_service.dart';
import '../services/socket_service.dart';
import '../services/user_service.dart';
import '../services/token_auth_service.dart';
import '../services/contextual_auth_service.dart';
import '../widgets/custom_toaster.dart';
import '../widgets/swipeable_chat_item.dart';
import '../models/user_model.dart';
import '../providers/chat_providers.dart';
import 'chat_screen.dart';

class MessageListScreen extends ConsumerStatefulWidget {
  const MessageListScreen({super.key});

  @override
  ConsumerState<MessageListScreen> createState() => _MessageListScreenState();
}

class _MessageListScreenState extends ConsumerState<MessageListScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Socket subscriptions
  StreamSubscription? _newMessageSubscription;
  StreamSubscription? _chatUpdateSubscription;
  StreamSubscription? _connectionSubscription;

  @override
  void initState() {
    super.initState();
    _setupSocketListeners();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _newMessageSubscription?.cancel();
    _chatUpdateSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }

  void _setupSocketListeners() {
    // Socket listeners are now handled by Riverpod providers
    final socketService = SocketService.instance;
    if (!socketService.isConnected) {
      socketService.connect();
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });

    // Debounce search
    Timer(const Duration(milliseconds: 500), () {
      if (_searchQuery == query) {
        ref.read(chatSearchProvider.notifier).search(query);
      }
    });
  }

  void _openChat(ChatModel chat) async {
    // Check authentication for messaging
    final canMessage = await ContextualAuthService.requireAuthForFeature(
      context,
      featureName: 'send messages',
      customMessage:
          'Sign in to start messaging with your friends and community.',
    );

    if (!canMessage) return;

    // Navigate to chat screen
    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => ChatScreen(chat: chat)));

    // Refresh chats if needed
    if (result == true) {
      ref.read(chatListProvider.notifier).refresh();
    }
  }

  void _showChatOptions() {
    _showFollowingUsers();
  }

  void _showFollowingUsers() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: Color(0xFF2A2A2A),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                const Text(
                  'Start a Chat',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose someone you follow to message',
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
                const SizedBox(height: 20),

                // Following users list
                Expanded(
                  child: FutureBuilder<UserListResult>(
                    future: UserService.getFollowingUsers(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF4ECDC4),
                            ),
                          ),
                        );
                      }

                      if (snapshot.hasError ||
                          !snapshot.hasData ||
                          !snapshot.data!.success) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Failed to load following users',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final users = snapshot.data!.users;

                      if (users.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 64,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'You\'re not following anyone yet',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Follow people to start messaging them',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final user = users[index];
                          return _buildFollowingUserItem(user);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildFollowingUserItem(UserModel user) {
    return GestureDetector(
      onTap: () => _startDirectChat(user),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF3A3A3A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // User avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[800],
              ),
              child:
                  user.bestAvatar != null
                      ? ClipOval(
                        child: Image.network(
                          user.bestAvatar!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildDefaultUserAvatar(user);
                          },
                        ),
                      )
                      : _buildDefaultUserAvatar(user),
            ),
            const SizedBox(width: 16),

            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.bestDisplayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@${user.username}',
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                ],
              ),
            ),

            // Message icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF4ECDC4).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.message,
                color: Color(0xFF4ECDC4),
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultUserAvatar(UserModel user) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF4ECDC4),
      ),
      child: Center(
        child: Text(
          user.bestDisplayName.isNotEmpty
              ? user.bestDisplayName[0].toUpperCase()
              : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<void> _startDirectChat(UserModel user) async {
    Navigator.of(context).pop(); // Close the bottom sheet

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4ECDC4)),
              ),
            ),
      );

      // Create or get existing direct chat
      final result = await ChatService.createChat(
        type: ChatType.direct,
        participants: [user.id],
      );

      // Close loading indicator
      if (mounted) Navigator.of(context).pop();

      if (result.success && result.chat != null) {
        // Navigate to the chat screen
        if (mounted) {
          final chatResult = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ChatScreen(chat: result.chat!),
            ),
          );

          // Refresh chats if needed
          if (chatResult == true) {
            ref.read(chatListProvider.notifier).refresh();
          }
        }
      } else {
        if (mounted) {
          ToasterService.showError(
            context,
            result.message.isNotEmpty ? result.message : 'Failed to start chat',
          );
        }
      }
    } catch (e) {
      // Close loading indicator if still showing
      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        ToasterService.showError(
          context,
          'Failed to start chat: ${e.toString()}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Column(
        children: [
          _buildHeader(),
          _buildQuickActions(),
          Expanded(child: _buildChatList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const Expanded(
                child: Center(
                  child: Text(
                    'Messages',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: _showChatOptions,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.more_horiz,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Search bar
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                const Icon(Icons.search, color: Colors.grey, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'search',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      height: 120,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildQuickAction(
            icon: Icons.headset_mic,
            label: 'Customer\nservice',
            color: const Color(0xFF4ECDC4),
            hasNotification: false,
          ),
          _buildQuickAction(
            icon: Icons.support_agent,
            label: 'Official\nassistance',
            color: const Color(0xFF4ECDC4),
            hasNotification: true,
          ),
          _buildQuickAction(
            icon: Icons.chat_bubble,
            label: 'Interactive\nmessage',
            color: const Color(0xFF4ECDC4),
            hasNotification: false,
          ),
          _buildQuickAction(
            icon: Icons.waving_hand,
            label: 'Greetings',
            color: const Color(0xFF4ECDC4),
            hasNotification: true,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required bool hasNotification,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        ToasterService.showInfo(context, 'Feature coming soon!');
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              if (hasNotification)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    final chatListAsync = ref.watch(chatListProvider);

    return chatListAsync.when(
      data: (chats) {
        if (chats.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 64,
                  color: Colors.grey[600],
                ),
                const SizedBox(height: 16),
                Text(
                  'No messages yet',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start a conversation to see your chats here',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _showChatOptions,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4ECDC4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Start Messaging',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await ref.read(chatListProvider.notifier).refresh();
          },
          color: const Color(0xFF25D366),
          backgroundColor: const Color(0xFF1F2C34),
          child: ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.zero,
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              return _buildChatItem(chat);
            },
          ),
        );
      },
      loading:
          () => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4ECDC4)),
            ),
          ),
      error:
          (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.grey[600]),
                const SizedBox(height: 16),
                Text(
                  'Failed to load chats',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed:
                      () => ref.read(chatListProvider.notifier).refresh(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4ECDC4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildChatItem(ChatModel chat) {
    final currentUserId = TokenAuthService.currentUser?.id ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: SwipeableChatItem(
        onArchive: () => _archiveChat(chat),
        onMore: () => _showChatMoreOptions(chat),
        child: GestureDetector(
          onTap: () => _openChat(chat),
          child: Container(
            margin: const EdgeInsets.only(bottom: 1),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(color: Color(0xFF1F2C34)),
            child: Row(
              children: [
                // Avatar - smaller like WhatsApp
                Stack(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[800],
                      ),
                      child:
                          chat.getChatAvatar(currentUserId) != null
                              ? ClipOval(
                                child: Image.network(
                                  chat.getChatAvatar(currentUserId)!,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return _buildDefaultAvatar(
                                      chat,
                                      currentUserId,
                                    );
                                  },
                                ),
                              )
                              : _buildDefaultAvatar(chat, currentUserId),
                    ),
                    // Online indicator (for direct chats)
                    if (chat.type == ChatType.direct)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: const Color(0xFF25D366),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF1F2C34),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),

                // Chat info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              chat.getDisplayName(currentUserId),
                              style: const TextStyle(
                                color: Color(0xFFE9EDEF),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            chat.getFormattedLastMessageTime(),
                            style: TextStyle(
                              color:
                                  chat.unreadCount > 0
                                      ? const Color(0xFF25D366)
                                      : Colors.grey[600],
                              fontSize: 12,
                              fontWeight:
                                  chat.unreadCount > 0
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              chat.getLastMessagePreview(),
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (chat.unreadCount > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: const BoxDecoration(
                                color: Color(0xFF25D366),
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 20,
                                minHeight: 20,
                              ),
                              child: Center(
                                child: Text(
                                  chat.unreadCount > 99
                                      ? '99+'
                                      : '${chat.unreadCount}',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _deleteChat(ChatModel chat) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF2A2A2A),
            title: const Text(
              'Delete Chat',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              'Are you sure you want to delete this chat? This will delete it only for you.',
              style: TextStyle(color: Colors.grey[400]),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true && mounted) {
      // TODO: Implement delete chat API
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Chat deleted'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 2),
        ),
      );
      // Refresh the chat list
      ref.read(chatListProvider.notifier).refresh();
    }
  }

  void _archiveChat(ChatModel chat) async {
    if (!mounted) return;

    // TODO: Implement archive functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Chat archived'),
        backgroundColor: const Color(0xFF128C7E),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: Colors.white,
          onPressed: () {
            // TODO: Undo archive
          },
        ),
      ),
    );
  }

  void _showChatMoreOptions(ChatModel chat) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF1F2C34),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Chat name
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      chat.getDisplayName(
                        TokenAuthService.currentUser?.id ?? '',
                      ),
                      style: const TextStyle(
                        color: Color(0xFFE9EDEF),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  // Options
                  _buildChatOptionItem(
                    Icons.archive_outlined,
                    'Archive chat',
                    () {
                      Navigator.pop(context);
                      _archiveChat(chat);
                    },
                  ),
                  _buildChatOptionItem(
                    Icons.volume_off_outlined,
                    'Mute notifications',
                    () {
                      Navigator.pop(context);
                      // TODO: Implement mute
                    },
                  ),
                  _buildChatOptionItem(
                    Icons.delete_outline_rounded,
                    'Delete chat',
                    () {
                      Navigator.pop(context);
                      _deleteChat(chat);
                    },
                    isDestructive: true,
                  ),
                  _buildChatOptionItem(Icons.pin_outlined, 'Pin chat', () {
                    Navigator.pop(context);
                    // TODO: Implement pin
                  }),
                  _buildChatOptionItem(
                    Icons.mark_chat_unread_outlined,
                    'Mark as unread',
                    () {
                      Navigator.pop(context);
                      // TODO: Implement mark unread
                    },
                  ),
                  _buildChatOptionItem(Icons.block_outlined, 'Block', () {
                    Navigator.pop(context);
                    // TODO: Implement block
                  }, isDestructive: true),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildChatOptionItem(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? Colors.red : const Color(0xFFE9EDEF),
              size: 24,
            ),
            const SizedBox(width: 20),
            Text(
              label,
              style: TextStyle(
                color: isDestructive ? Colors.red : const Color(0xFFE9EDEF),
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar(ChatModel chat, String currentUserId) {
    final displayName = chat.getDisplayName(currentUserId);
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[800],
      ),
      child: Center(
        child: Text(
          displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
