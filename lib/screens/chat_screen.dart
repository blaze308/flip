import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';
import 'dart:io';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../models/gift_model.dart';
import '../models/lottie_model.dart';
import '../services/chat_service.dart';
import '../services/socket_service.dart';
import '../services/token_auth_service.dart';
import '../services/audio_service.dart';
import '../services/jitsi_service.dart';
import '../services/cloudinary_service.dart';
import '../widgets/custom_toaster.dart';
import '../widgets/modern_message_bubble.dart';
import '../widgets/message_input.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/waveform_animation.dart';
import '../providers/messages_cache_provider.dart';
import '../widgets/modern_image_preview.dart';
import '../widgets/modern_video_preview.dart';
import '../widgets/modern_file_preview.dart';
import '../widgets/modern_svga_preview.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final ChatModel chat;

  const ChatScreen({super.key, required this.chat});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final List<MessageModel> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isTyping = false;
  bool _isRecording = false;
  File? _recordedAudioFile;
  bool _isPlayingRecordedAudio = false;
  Timer? _recordingTimer;
  int _recordingDuration = 0;
  bool _isRecordingLocked = false; // After 2 seconds, recording is locked
  bool _isRecordingPaused = false; // Pause state

  @override
  bool get wantKeepAlive => true; // Keep the state alive

  // Socket subscriptions
  StreamSubscription? _newMessageSubscription;
  StreamSubscription? _messageUpdateSubscription;
  StreamSubscription? _typingSubscription;
  StreamSubscription? _connectionSubscription;

  // Connection state
  bool _isConnected = true;
  final List<Map<String, dynamic>> _messageQueue = [];

  // Typing indicator
  Timer? _typingTimer;
  final Set<String> _typingUsers = {};

  // Reply functionality
  MessageModel? _replyToMessage;

  // Animation controllers
  late AnimationController _replyAnimationController;
  late Animation<double> _replyAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadMessages();
    _setupSocketListeners();
    _setupConnectionListener(); // Add connection state monitoring
    _scrollController.addListener(_onScroll);

    // Join chat room for real-time updates
    SocketService.instance.joinChat(widget.chat.id);

    // Mark chat as read when opening
    SocketService.instance.markChatRead(widget.chat.id);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _replyAnimationController.dispose();
    _newMessageSubscription?.cancel();
    _messageUpdateSubscription?.cancel();
    _typingSubscription?.cancel();
    _connectionSubscription?.cancel(); // Cancel connection listener
    _typingTimer?.cancel();

    // Leave chat room
    SocketService.instance.leaveChat(widget.chat.id);

    super.dispose();
  }

  void _setupAnimations() {
    _replyAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _replyAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _replyAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  void _setupSocketListeners() {
    final socketService = SocketService.instance;

    // Listen for new messages in this chat
    _newMessageSubscription = socketService.onNewMessage.listen((message) {
      if (message.chatId == widget.chat.id) {
        final currentUserId = TokenAuthService.currentUser?.id ?? '';

        // For own messages, we only need to update status (already in UI optimistically)
        if (message.senderId == currentUserId) {
          print(
            '📨 ChatScreen: Received own message from socket - updating status',
          );

          // Find and update the optimistic message with the real one
          final optimisticIndex = _messages.indexWhere(
            (m) => m.id.startsWith('temp_') && m.content == message.content,
          );

          if (optimisticIndex != -1) {
            setState(() {
              _messages[optimisticIndex] = message;
            });

            // Update cache
            ref
                .read(messagesCacheProvider.notifier)
                .updateMessage(widget.chat.id, message);
          }

          // Don't add duplicate message to list
          return;
        }

        // Check if message already exists to prevent duplication
        final existingIndex = _messages.indexWhere((m) => m.id == message.id);
        if (existingIndex == -1) {
          final isUserAtBottom = _isUserAtBottom();

          // Clear old cache when new message arrives
          ChatService.clearMessageCache(widget.chat.id);

          setState(() {
            _messages.add(
              message,
            ); // Add to end since newest should be at bottom
          });

          // Update provider cache with new message
          ref
              .read(messagesCacheProvider.notifier)
              .addMessage(widget.chat.id, message);

          // Auto-scroll to bottom if user is already at bottom
          if (isUserAtBottom) {
            _scrollToBottom();
          }

          // Mark message as delivered and read
          socketService.markMessageDelivered(widget.chat.id, message.id);
          socketService.markMessageRead(widget.chat.id, message.id);
        }
      }
    });

    // Listen for message updates (reactions, read receipts, etc.)
    _messageUpdateSubscription = socketService.onMessageUpdate.listen((event) {
      _handleMessageUpdate(event);
    });

    // Listen for typing indicators
    _typingSubscription = socketService.onTyping.listen((event) {
      if (event.chatId == widget.chat.id) {
        _handleTypingEvent(event);
      }
    });
  }

  void _handleMessageUpdate(MessageUpdateEvent event) {
    setState(() {
      final messageIndex = _messages.indexWhere((m) => m.id == event.messageId);
      if (messageIndex != -1) {
        // Update the message based on the update type
        switch (event.updateType) {
          case MessageUpdateType.reactionAdded:
          case MessageUpdateType.reactionRemoved:
            // Refresh the specific message to get updated reactions
            _refreshMessage(event.messageId);
            break;
          case MessageUpdateType.read:
            // Update message status to read
            final message = _messages[messageIndex];
            _messages[messageIndex] = message.copyWith(
              status: MessageStatus.read,
            );
            break;
          case MessageUpdateType.delivered:
            // Update message status to delivered
            final message = _messages[messageIndex];
            _messages[messageIndex] = message.copyWith(
              status: MessageStatus.delivered,
            );
            break;
          case MessageUpdateType.edited:
            // Refresh the message
            _refreshMessage(event.messageId);
            break;
          case MessageUpdateType.deleted:
            // Remove the message from the list
            _messages.removeWhere((m) => m.id == event.messageId);
            break;
        }
      }
    });
  }

  void _handleTypingEvent(TypingEvent event) {
    final currentUserId = TokenAuthService.currentUser?.id ?? '';
    if (event.userId == currentUserId) return; // Ignore own typing

    setState(() {
      if (event.isTyping) {
        _typingUsers.add(event.username);
      } else {
        _typingUsers.remove(event.username);
      }
    });

    // Auto-remove typing indicator after 3 seconds
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _typingUsers.remove(event.username);
        });
      }
    });
  }

  void _setupConnectionListener() {
    final socketService = SocketService.instance;

    _connectionSubscription = socketService.onConnection.listen((event) {
      if (!mounted) return;

      switch (event.type) {
        case ConnectionEventType.connected:
          print('🔌 ChatScreen: Connected to socket');
          setState(() {
            _isConnected = true;
          });

          // Sync missed messages on reconnect
          _syncMissedMessages();

          // Send queued messages
          _sendQueuedMessages();
          break;

        case ConnectionEventType.disconnected:
          print('🔌 ChatScreen: Disconnected from socket');
          setState(() {
            _isConnected = false;
          });
          break;

        case ConnectionEventType.error:
          print('🔌 ChatScreen: Socket connection error');
          setState(() {
            _isConnected = false;
          });
          break;
      }
    });
  }

  Future<void> _syncMissedMessages() async {
    print('🔄 ChatScreen: Syncing missed messages...');
    try {
      await _refreshMessagesInBackground();
      print('✅ ChatScreen: Sync complete');
    } catch (e) {
      print('❌ ChatScreen: Sync failed: $e');
    }
  }

  Future<void> _sendQueuedMessages() async {
    if (_messageQueue.isEmpty) return;

    print('📤 ChatScreen: Sending ${_messageQueue.length} queued messages...');

    final queue = List<Map<String, dynamic>>.from(_messageQueue);
    _messageQueue.clear();

    for (final queuedMsg in queue) {
      try {
        final type = queuedMsg['type'] as String;
        final content = queuedMsg['content'] as String?;

        if (type == 'text' && content != null) {
          await ChatService.sendTextMessage(widget.chat.id, content);
        }

        print('✅ ChatScreen: Queued message sent');
      } catch (e) {
        print('❌ ChatScreen: Failed to send queued message: $e');
        _messageQueue.add(queuedMsg);
      }
    }
  }

  Future<void> _refreshMessage(String messageId) async {
    // Don't reload all messages for individual message updates
    // The socket events should handle message updates efficiently
    print('💬 ChatScreen: Message $messageId updated via socket');
  }

  void _onScroll() {
    // Load more messages when scrolling to top
    if (_scrollController.position.pixels <= 200) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadMessages() async {
    if (!mounted) return;

    // INDUSTRY STANDARD: Check cache first
    final cachedMessages = ref
        .read(messagesCacheProvider.notifier)
        .getCachedMessages(widget.chat.id);

    if (cachedMessages != null && cachedMessages.isNotEmpty) {
      // Show cached data immediately - NO SHIMMER!
      setState(() {
        _messages.clear();
        _messages.addAll(cachedMessages);
        _isLoading = false; // Already have data, no loading state
      });

      // Scroll to bottom immediately
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });

      // Fetch fresh data in background
      _refreshMessagesInBackground();
    } else {
      // No cache - show loading state
      setState(() {
        _isLoading = true;
      });

      try {
        final result = await ChatService.getMessages(
          widget.chat.id,
          page: 1,
          limit: 50,
        );

        if (mounted) {
          setState(() {
            _messages.clear();
            _messages.addAll(result.messages);
            _isLoading = false;
          });

          // Cache the messages
          ref
              .read(messagesCacheProvider.notifier)
              .cacheMessages(widget.chat.id, result.messages);

          // Scroll to bottom after loading
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ToasterService.showError(context, 'Failed to load messages');
        }
      }
    }
  }

  /// Background refresh - updates cache silently
  Future<void> _refreshMessagesInBackground() async {
    try {
      final result = await ChatService.getMessages(
        widget.chat.id,
        page: 1,
        limit: 50,
      );

      if (mounted) {
        // Update cache
        ref
            .read(messagesCacheProvider.notifier)
            .cacheMessages(widget.chat.id, result.messages);

        // Check if there are messages we don't have yet
        final newMessages =
            result.messages.where((serverMsg) {
              return !_messages.any((localMsg) => localMsg.id == serverMsg.id);
            }).toList();

        if (newMessages.isNotEmpty) {
          print(
            '💬 ChatScreen: Found ${newMessages.length} new messages from server',
          );
          setState(() {
            // Add new messages to existing list (maintaining socket updates)
            _messages.addAll(newMessages);
            // Sort by timestamp to maintain order
            _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          });
        }
      }
    } catch (e) {
      // Silent fail - already showing cached data
      print('Background refresh failed: $e');
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || _messages.isEmpty) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final result = await ChatService.getMessages(
        widget.chat.id,
        page: (_messages.length ~/ 50) + 1,
        limit: 50,
        before: _messages.first.createdAt,
      );

      if (mounted) {
        setState(() {
          _messages.insertAll(
            0,
            result.messages,
          ); // Insert older messages at beginning
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  bool _isUserAtBottom() {
    if (!_scrollController.hasClients) return true;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    return (maxScroll - currentScroll) < 100; // Within 100 pixels of bottom
  }

  void _onMessageChanged(String text) {
    // Handle typing indicator
    if (text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      SocketService.instance.startTyping(widget.chat.id);
    } else if (text.isEmpty && _isTyping) {
      _isTyping = false;
      SocketService.instance.stopTyping(widget.chat.id);
    }

    // Reset typing timer
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isTyping) {
        _isTyping = false;
        SocketService.instance.stopTyping(widget.chat.id);
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final currentUser = TokenAuthService.currentUser;
    if (currentUser == null) return;

    // Create optimistic message
    final optimisticMessage = MessageModel(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      chatId: widget.chat.id,
      senderId: currentUser.id,
      sender: UserModel(
        id: currentUser.id,
        displayName: currentUser.displayName ?? '',
        username: '', // TokenUser doesn't have username
        profileImageUrl: currentUser.photoURL,
        bio: '',
        postsCount: 0,
        followersCount: 0,
        followingCount: 0,
        likesCount: 0,
      ),
      type: MessageType.text,
      content: text,
      status: MessageStatus.sending,
      reactions: [],
      mentions: [],
      readBy: [],
      deliveredTo: [],
      isEdited: false,
      isDeleted: false,
      deletedFor: [],
      priority: MessagePriority.normal,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      replyTo:
          _replyToMessage != null
              ? MessageReference(
                messageId: _replyToMessage!.id,
                senderId: _replyToMessage!.senderId,
                sender: _replyToMessage!.sender,
                content: _replyToMessage!.content ?? '',
                type: _replyToMessage!.type,
                timestamp: _replyToMessage!.createdAt,
              )
              : null,
    );

    // Add optimistic message to UI
    setState(() {
      _messages.add(optimisticMessage);
    });

    // Clear input immediately
    _messageController.clear();
    _clearReply();

    // Stop typing indicator
    if (_isTyping) {
      _isTyping = false;
      SocketService.instance.stopTyping(widget.chat.id);
    }

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    try {
      // Check if offline - queue the message
      if (!_isConnected) {
        print('📴 ChatScreen: Offline - queueing message');
        _messageQueue.add({
          'type': 'text',
          'content': text,
          'replyTo': _replyToMessage?.id,
        });
        return;
      }

      final result = await ChatService.sendTextMessage(
        widget.chat.id,
        text,
        replyToMessageId: _replyToMessage?.id,
      );

      if (result.success && mounted) {
        // Replace optimistic message with real message
        final messageIndex = _messages.indexWhere(
          (m) => m.id == optimisticMessage.id,
        );
        if (messageIndex != -1) {
          final sentMessage = result.message!.copyWith(
            status: MessageStatus.sent,
          );
          setState(() {
            _messages[messageIndex] = sentMessage;
          });

          // Note: Chat list will be updated via socket event (onNewMessage)
          // No need to manually update here to avoid double updates
        }
      } else {
        // Mark optimistic message as failed
        final messageIndex = _messages.indexWhere(
          (m) => m.id == optimisticMessage.id,
        );
        if (messageIndex != -1) {
          setState(() {
            _messages[messageIndex] = optimisticMessage.copyWith(
              status: MessageStatus.failed,
            );
          });
        }
      }
    } catch (e) {
      // Mark optimistic message as failed
      final messageIndex = _messages.indexWhere(
        (m) => m.id == optimisticMessage.id,
      );
      if (messageIndex != -1) {
        setState(() {
          _messages[messageIndex] = optimisticMessage.copyWith(
            status: MessageStatus.failed,
          );
        });
      }
    }
  }

  Future<void> _sendMediaMessage(
    MessageType type,
    File file, {
    String? caption,
  }) async {
    try {
      print('🎵 ChatScreen: Sending ${type.name} message...');

      // Get current user info
      final currentUser = TokenAuthService.currentUser;
      if (currentUser == null) return;

      final optimisticMessage = MessageModel(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        chatId: widget.chat.id,
        senderId: currentUser.id,
        sender: UserModel(
          id: currentUser.id,
          displayName: currentUser.displayName ?? '',
          username: '', // TokenUser doesn't have username
          profileImageUrl: currentUser.photoURL,
          bio: '',
          postsCount: 0,
          followersCount: 0,
          followingCount: 0,
          likesCount: 0,
        ),
        type: type,
        content: caption, // Include caption with media
        media: null, // Will be populated after upload
        localFilePath: file.path, // For immediate UI display
        status: MessageStatus.sending,
        reactions: const [],
        mentions: const [],
        readBy: const [],
        deliveredTo: const [],
        isEdited: false,
        isDeleted: false,
        deletedFor: const [],
        priority: MessagePriority.normal,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Add optimistic message to UI immediately at the end (newest at bottom)
      setState(() {
        _messages.add(optimisticMessage);
      });

      // Update cache with optimistic message
      ref
          .read(messagesCacheProvider.notifier)
          .addMessage(widget.chat.id, optimisticMessage);

      _scrollToBottom();

      // Upload media in background
      final result = await ChatService.sendMediaMessage(
        widget.chat.id,
        type,
        file,
        content: caption, // Pass caption to backend
        replyToMessageId: _replyToMessage?.id,
      );

      if (result.success && mounted) {
        print('🎵 ChatScreen: ${type.name} message sent successfully');
        _clearReply();

        // Replace optimistic message with real message
        final messageIndex = _messages.indexWhere(
          (m) => m.id == optimisticMessage.id,
        );
        if (messageIndex != -1) {
          final sentMessage = result.message!.copyWith(
            status: MessageStatus.sent,
          );
          setState(() {
            _messages[messageIndex] = sentMessage;
          });

          // Update cache with sent message
          ref
              .read(messagesCacheProvider.notifier)
              .updateMessage(widget.chat.id, sentMessage);

          // Note: Chat list will be updated via socket event (onNewMessage)
          // No need to manually update here to avoid double updates
        }
      } else {
        print(
          '🎵 ChatScreen: Failed to send ${type.name} message: ${result.resultMessage}',
        );
        // Mark optimistic message as failed
        final messageIndex = _messages.indexWhere(
          (m) => m.id == optimisticMessage.id,
        );
        if (messageIndex != -1) {
          setState(() {
            _messages[messageIndex] = optimisticMessage.copyWith(
              status: MessageStatus.failed,
            );
          });
        }
      }
    } catch (e) {
      print('🎵 ChatScreen: Error sending ${type.name}: $e');
      // Find and mark as failed
      final failedMessage = _messages.firstWhere(
        (m) => m.id.startsWith('temp_') && m.type == type,
        orElse: () => _messages.first,
      );
      final messageIndex = _messages.indexOf(failedMessage);
      if (messageIndex != -1) {
        setState(() {
          _messages[messageIndex] = failedMessage.copyWith(
            status: MessageStatus.failed,
          );
        });
      }
    }
  }

  Future<void> _showMediaPicker() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: false,
      builder:
          (bottomSheetContext) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFF2A2A2A),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
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
                  'Send Media',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),

                // Media options
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMediaOption(
                      icon: Icons.photo_camera,
                      label: 'Camera',
                      onTap: () => Navigator.pop(bottomSheetContext, 'camera'),
                    ),
                    _buildMediaOption(
                      icon: Icons.photo_library,
                      label: 'Gallery',
                      onTap: () => Navigator.pop(bottomSheetContext, 'gallery'),
                    ),
                    _buildMediaOption(
                      icon: Icons.videocam,
                      label: 'Video',
                      onTap: () => Navigator.pop(bottomSheetContext, 'video'),
                    ),
                    _buildMediaOption(
                      icon: Icons.attach_file,
                      label: 'File',
                      onTap: () => Navigator.pop(bottomSheetContext, 'file'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Animation options
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMediaOption(
                      icon: Icons.animation,
                      label: 'Lottie',
                      onTap: () => Navigator.pop(bottomSheetContext, 'lottie'),
                    ),
                    _buildMediaOption(
                      icon: Icons.play_circle_outline,
                      label: 'SVGA',
                      onTap: () => Navigator.pop(bottomSheetContext, 'svga'),
                    ),
                    const SizedBox(width: 60), // Spacer
                    const SizedBox(width: 60), // Spacer
                  ],
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
    );

    // Handle the result after bottom sheet is closed
    if (result != null && mounted) {
      // Add a small delay to ensure bottom sheet animation completes
      await Future.delayed(const Duration(milliseconds: 200));

      if (!mounted) return;

      switch (result) {
        case 'camera':
          await _pickImage(ImageSource.camera);
          break;
        case 'gallery':
          await _pickImage(ImageSource.gallery);
          break;
        case 'video':
          await _pickVideo();
          break;
        case 'file':
          await _pickFile();
          break;
        case 'lottie':
          _showLottieModal();
          break;
        case 'svga':
          _showSvgaModal();
          break;
      }
    }
  }

  Widget _buildMediaOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap, // Just call the onTap directly, don't pop here
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF4ECDC4).withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: const Color(0xFF4ECDC4), size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// Show Lottie selection modal with categories
  void _showLottieModal() {
    final lotties = LottieList.getLottiesByWeight();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                const SizedBox(height: 16),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Send Animation',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Color(0xFF2A2A2A), thickness: 1),
                const SizedBox(height: 8),
                // Grid of lotties
                Expanded(
                  child:
                      lotties.isEmpty
                          ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.animation,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No animations available',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                          : GridView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 4,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.75,
                                ),
                            itemCount: lotties.length,
                            itemBuilder: (context, index) {
                              final lottie = lotties[index];
                              return _buildLottieItemNew(lottie);
                            },
                          ),
                ),
              ],
            ),
          ),
    );
  }

  /// Show SVGA selection modal
  void _showSvgaModal() {
    final gifts = GiftList.getGiftsByWeight(); // Get gifts sorted by weight

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                const SizedBox(height: 16),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Send Gift',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Color(0xFF2A2A2A), thickness: 1),
                const SizedBox(height: 8),
                // Grid of gifts
                Expanded(
                  child:
                      gifts.isEmpty
                          ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.card_giftcard,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No gifts available',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                          : GridView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 4,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.75,
                                ),
                            itemCount: gifts.length,
                            itemBuilder: (context, index) {
                              final gift = gifts[index];
                              return _buildGiftItem(gift);
                            },
                          ),
                ),
              ],
            ),
          ),
    );
  }

  /// Build Lottie item widget
  Widget _buildLottieItem(CloudinaryAsset lottie) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _sendLottieMessage(lottie);
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF4ECDC4), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.animation, color: Color(0xFF4ECDC4), size: 40),
            const SizedBox(height: 8),
            Text(
              lottie.fileName,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// Build SVGA item widget
  Widget _buildSvgaItem(SvgaAsset svga) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _sendSvgaMessage(svga);
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF4ECDC4), width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child:
              svga.imageUrl != null
                  ? Image.network(
                    svga.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildSvgaFallback(svga);
                    },
                  )
                  : _buildSvgaFallback(svga),
        ),
      ),
    );
  }

  /// Build SVGA fallback widget
  Widget _buildSvgaFallback(SvgaAsset svga) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.play_circle_outline,
          color: Color(0xFF4ECDC4),
          size: 40,
        ),
        const SizedBox(height: 8),
        Text(
          svga.fileName,
          style: const TextStyle(color: Colors.white, fontSize: 12),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// Build Gift item widget
  Widget _buildGiftItem(GiftModel gift) {
    // Format weight/price
    String formatWeight(int weight) {
      if (weight >= 1000) {
        return '${(weight / 1000).toStringAsFixed(weight % 1000 == 0 ? 0 : 1)}K';
      }
      return weight.toString();
    }

    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _showSvgaPreview(gift);
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF4ECDC4).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Gift icon/image
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: Image.network(
                  gift.iconUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.card_giftcard,
                      color: Color(0xFF4ECDC4),
                      size: 32,
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF4ECDC4),
                          ),
                          value:
                              loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            // Gift name and price
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    gift.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.monetization_on,
                        color: Color(0xFFFFD700),
                        size: 10,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        formatWeight(gift.weight),
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build Lottie item widget (new model)
  Widget _buildLottieItemNew(LottieModel lottie) {
    // Format weight/price
    String formatWeight(int weight) {
      if (weight >= 1000) {
        return '${(weight / 1000).toStringAsFixed(weight % 1000 == 0 ? 0 : 1)}K';
      }
      return weight.toString();
    }

    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _sendLottieMessageNew(lottie);
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                lottie.category == LottieCategory.vip
                    ? const Color(0xFFFFD700).withOpacity(0.5)
                    : const Color(0xFF4ECDC4).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Lottie animation preview
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Lottie.asset(
                  lottie.lottieUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.animation,
                      color:
                          lottie.category == LottieCategory.vip
                              ? const Color(0xFFFFD700)
                              : const Color(0xFF4ECDC4),
                      size: 32,
                    );
                  },
                ),
              ),
            ),
            // Lottie name and price
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        lottie.category.emoji,
                        style: const TextStyle(fontSize: 8),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          lottie.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.monetization_on,
                        color: Color(0xFFFFD700),
                        size: 10,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        formatWeight(lottie.weight),
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Send Lottie message (new model)
  Future<void> _sendLottieMessageNew(LottieModel lottie) async {
    try {
      print('🎭 ChatScreen: Sending lottie: ${lottie.name}');

      // Get current user
      final currentUser = TokenAuthService.currentUser;
      if (currentUser == null) return;

      // Create optimistic message
      final optimisticMessage = MessageModel(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        chatId: widget.chat.id,
        senderId: currentUser.id,
        sender: UserModel(
          id: currentUser.id,
          displayName: currentUser.displayName ?? '',
          username: '',
          profileImageUrl: currentUser.photoURL,
          bio: '',
          postsCount: 0,
          followersCount: 0,
          followingCount: 0,
          likesCount: 0,
        ),
        type: MessageType.lottie,
        content: lottie.lottieUrl,
        status: MessageStatus.sending,
        reactions: [],
        mentions: [],
        readBy: [],
        deliveredTo: [],
        isEdited: false,
        isDeleted: false,
        deletedFor: [],
        priority: MessagePriority.normal,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Add optimistic message to UI
      if (mounted) {
        setState(() {
          _messages.add(optimisticMessage);
        });
        ref
            .read(messagesCacheProvider.notifier)
            .addMessage(widget.chat.id, optimisticMessage);
        _scrollToBottom();
      }

      // Send via API as text message (backend will detect Lottie asset path)
      final result = await ChatService.sendTextMessage(
        widget.chat.id,
        lottie.lottieUrl,
      );

      if (result.success && mounted) {
        print('🎭 ChatScreen: Lottie sent successfully: ${lottie.name}');

        // Replace optimistic message with real message
        final messageIndex = _messages.indexWhere(
          (m) => m.id == optimisticMessage.id,
        );
        if (messageIndex != -1) {
          final sentMessage = result.message!.copyWith(
            status: MessageStatus.sent,
          );
          setState(() {
            _messages[messageIndex] = sentMessage;
          });
          // Update cache
          ref
              .read(messagesCacheProvider.notifier)
              .addMessage(widget.chat.id, sentMessage);
        }
      }
    } catch (e) {
      print('❌ ChatScreen: Error sending lottie: $e');
      // Remove failed message
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.id.startsWith('temp_'));
        });
      }
    }
  }

  /// Send Lottie message
  Future<void> _sendLottieMessage(CloudinaryAsset lottie) async {
    try {
      // For now, send as a text message with the URL
      // TODO: Implement proper Lottie file sending
      await ChatService.sendTextMessage(
        widget.chat.id,
        '🎭 Lottie: ${lottie.fileName}\n${lottie.url}',
      );
    } catch (e) {
      print('Error sending Lottie: $e');
    }
  }

  /// Send SVGA message
  Future<void> _sendSvgaMessage(SvgaAsset svga) async {
    try {
      // For now, send as a text message with the URL
      // TODO: Implement proper SVGA file sending
      await ChatService.sendTextMessage(
        widget.chat.id,
        '🎬 SVGA: ${svga.fileName}\n${svga.svgaUrl}',
      );
    } catch (e) {
      print('Error sending SVGA: $e');
    }
  }

  /// Show SVGA gift preview
  void _showSvgaPreview(GiftModel gift) {
    // Calculate recipient name
    String recipientName = 'User';
    if (widget.chat.type == ChatType.direct) {
      final otherMember = widget.chat.members.firstWhere(
        (m) => m.userId != TokenAuthService.currentUser?.id,
        orElse: () => widget.chat.members.first,
      );
      recipientName =
          otherMember.username.isNotEmpty
              ? otherMember.username
              : (otherMember.displayName.isNotEmpty
                  ? otherMember.displayName
                  : 'User');
    } else {
      recipientName = widget.chat.name ?? 'Group';
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder:
            (context) => ModernSvgaPreview(
              gift: gift,
              recipientName: recipientName,
              onCancel: () {
                Navigator.pop(context);
              },
              onSend: (caption) {
                Navigator.pop(context);
                _sendGiftMessage(gift, caption: caption);
              },
            ),
      ),
    );
  }

  /// Send Gift message (SVGA gift)
  Future<void> _sendGiftMessage(GiftModel gift, {String? caption}) async {
    try {
      print('🎁 ChatScreen: Sending gift: ${gift.name}');

      // Get current user
      final currentUser = TokenAuthService.currentUser;
      if (currentUser == null) return;

      // Create optimistic message
      final optimisticMessage = MessageModel(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        chatId: widget.chat.id,
        senderId: currentUser.id,
        sender: UserModel(
          id: currentUser.id,
          displayName: currentUser.displayName ?? '',
          username: '', // TokenUser doesn't have username
          profileImageUrl: currentUser.photoURL,
          bio: '',
          postsCount: 0,
          followersCount: 0,
          followingCount: 0,
          likesCount: 0,
        ),
        type: MessageType.svga,
        content: gift.svgaUrl,
        status: MessageStatus.sending,
        reactions: [],
        mentions: [],
        readBy: [],
        deliveredTo: [],
        isEdited: false,
        isDeleted: false,
        deletedFor: [],
        priority: MessagePriority.normal,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Add optimistic message to UI
      if (mounted) {
        setState(() {
          _messages.add(optimisticMessage);
        });
        // Cache the new message
        ref
            .read(messagesCacheProvider.notifier)
            .addMessage(widget.chat.id, optimisticMessage);
        _scrollToBottom();
      }

      // Send via API as text message (backend will detect SVGA URL)
      final result = await ChatService.sendTextMessage(
        widget.chat.id,
        gift.svgaUrl,
      );

      if (result.success && mounted) {
        print('🎁 ChatScreen: Gift sent successfully: ${gift.name}');

        // Replace optimistic message with real message
        final messageIndex = _messages.indexWhere(
          (m) => m.id == optimisticMessage.id,
        );
        if (messageIndex != -1) {
          final sentMessage = result.message!.copyWith(
            status: MessageStatus.sent,
          );
          setState(() {
            _messages[messageIndex] = sentMessage;
          });
          // Update cache
          ref
              .read(messagesCacheProvider.notifier)
              .addMessage(widget.chat.id, sentMessage);
        }
      }
    } catch (e) {
      print('❌ ChatScreen: Error sending gift: $e');
      // Remove failed message
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.id.startsWith('temp_'));
        });
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      print('📸 ChatScreen: Starting image picker from ${source.name}');
      print('📸 ChatScreen: Mounted state: $mounted');

      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);

      print('📸 ChatScreen: Image picked: ${pickedFile?.path ?? "null"}');
      print('📸 ChatScreen: Mounted state after pick: $mounted');

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        print('📸 ChatScreen: Showing media preview');

        // Use a post-frame callback to ensure we're back in the widget tree
        if (mounted) {
          await _showMediaPreview(file, MessageType.image);
          print('📸 ChatScreen: Media preview completed');
        } else {
          print('⚠️ ChatScreen: Widget unmounted, cannot show preview');
          // Store the file path and show preview when widget rebuilds
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _showMediaPreview(file, MessageType.image);
            }
          });
        }
      } else {
        print('📸 ChatScreen: User cancelled image selection');
      }
    } catch (e) {
      print('❌ ChatScreen: Error picking image: $e');
      if (mounted) {
        ToasterService.showError(context, 'Failed to pick image: $e');
      }
    }
  }

  Future<void> _pickVideo() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickVideo(source: ImageSource.gallery);

      if (pickedFile != null && mounted) {
        final file = File(pickedFile.path);
        // Show preview before sending
        await _showMediaPreview(file, MessageType.video);
      }
    } catch (e) {
      if (mounted) {
        ToasterService.showError(context, 'Failed to pick video');
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);

        // Determine file type based on extension
        final extension = result.files.single.extension?.toLowerCase();
        MessageType type = MessageType.file;

        if (extension == 'json') {
          type = MessageType.lottie;
        } else if (extension == 'svga') {
          type = MessageType.svga;
        }

        // Show preview before sending
        await _showMediaPreview(file, type);
      }
    } catch (e) {
      ToasterService.showError(context, 'Failed to pick file');
    }
  }

  /// Show media preview before sending (Modern WhatsApp-style)
  Future<void> _showMediaPreview(File file, MessageType type) async {
    // Get recipient username (not email)
    final recipientName =
        widget.chat.type == ChatType.direct
            ? (widget.chat.members
                    .firstWhere(
                      (m) => m.userId != TokenAuthService.currentUser?.id,
                      orElse: () => widget.chat.members.first,
                    )
                    .user
                    ?.username ??
                widget.chat.members
                    .firstWhere(
                      (m) => m.userId != TokenAuthService.currentUser?.id,
                      orElse: () => widget.chat.members.first,
                    )
                    .user
                    ?.displayName ??
                'User')
            : widget.chat.name ?? 'Group';

    if (type == MessageType.image) {
      // Show modern image preview
      await Navigator.push(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder:
              (context) => ModernImagePreview(
                imageFile: file,
                recipientName: recipientName,
                onSend: (imageFile, caption) async {
                  Navigator.pop(context);
                  await _sendMediaMessage(
                    MessageType.image,
                    imageFile,
                    caption: caption,
                  );
                },
                onCancel: () {
                  Navigator.pop(context);
                },
              ),
        ),
      );
    } else if (type == MessageType.video) {
      // Show modern video preview
      await Navigator.push(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder:
              (context) => ModernVideoPreview(
                videoFile: file,
                recipientName: recipientName,
                onSend: (videoFile, caption) async {
                  Navigator.pop(context);
                  await _sendMediaMessage(
                    MessageType.video,
                    videoFile,
                    caption: caption,
                  );
                },
                onCancel: () {
                  Navigator.pop(context);
                },
              ),
        ),
      );
    } else if (type == MessageType.file ||
        type == MessageType.lottie ||
        type == MessageType.svga) {
      // Show modern file preview
      await Navigator.push(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder:
              (context) => ModernFilePreview(
                file: file,
                recipientName: recipientName,
                onSend: (caption) async {
                  Navigator.pop(context);
                  await _sendMediaMessage(type, file, caption: caption);
                },
                onCancel: () {
                  Navigator.pop(context);
                },
              ),
        ),
      );
    } else {
      // Fallback for audio or other types (directly send without preview)
      await _sendMediaMessage(type, file);
    }
  }

  void _setReplyMessage(MessageModel message) {
    setState(() {
      _replyToMessage = message;
    });
    _replyAnimationController.forward();
  }

  void _clearReply() {
    _replyAnimationController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _replyToMessage = null;
        });
      }
    });
  }

  void _forwardMessage(MessageModel message) {
    // TODO: Implement forward message functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Forward feature coming soon'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showMessageOptions(MessageModel message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFF2A2A2A),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                // Options
                ListTile(
                  leading: const Icon(Icons.reply, color: Color(0xFF4ECDC4)),
                  title: const Text(
                    'Reply',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _setReplyMessage(message);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.copy, color: Color(0xFF4ECDC4)),
                  title: const Text(
                    'Copy',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    Clipboard.setData(
                      ClipboardData(text: message.displayContent),
                    );
                    ToasterService.showSuccess(context, 'Message copied');
                  },
                ),
                if (message.type == MessageType.text)
                  ListTile(
                    leading: const Icon(
                      Icons.add_reaction,
                      color: Color(0xFF4ECDC4),
                    ),
                    title: const Text(
                      'React',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      _showReactionPicker(message);
                    },
                  ),
                // Show resend option for failed messages
                if (message.status == MessageStatus.failed &&
                    message.senderId ==
                        (TokenAuthService.currentUser?.id ?? ''))
                  ListTile(
                    leading: const Icon(
                      Icons.refresh,
                      color: Color(0xFF4ECDC4),
                    ),
                    title: const Text(
                      'Resend',
                      style: TextStyle(color: Color(0xFF4ECDC4)),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      _resendMessage(message);
                    },
                  ),
                // Show delete option only for user's own messages
                if (message.senderId ==
                    (TokenAuthService.currentUser?.id ?? ''))
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text(
                      'Delete',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      _confirmDeleteMessage(message);
                    },
                  ),
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  void _showReactionPicker(MessageModel message) {
    final reactions = ['❤️', '😂', '😮', '😢', '😡', '👍', '👎'];

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF2A2A2A),
            title: const Text(
              'React to message',
              style: TextStyle(color: Colors.white),
            ),
            content: Wrap(
              children:
                  reactions.map((emoji) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                        _addReaction(message, emoji);
                      },
                      child: Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3A3A3A),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
    );
  }

  Future<void> _addReaction(MessageModel message, String emoji) async {
    final success = await ChatService.addReaction(
      widget.chat.id,
      message.id,
      emoji,
    );
    if (!success) {
      ToasterService.showError(context, 'Failed to add reaction');
    }
  }

  /// Show delete confirmation dialog
  void _confirmDeleteMessage(MessageModel message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF2A2A2A),
            title: const Text(
              'Delete Message',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Are you sure you want to delete this message? This action cannot be undone.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _deleteMessage(message);
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  /// Delete a message
  Future<void> _deleteMessage(MessageModel message) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF2A2A2A),
            title: const Text(
              'Delete Message',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Are you sure you want to delete this message? This action cannot be undone.',
              style: TextStyle(color: Colors.white70),
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

    if (confirmed != true) return;

    // Optimistically remove from UI
    setState(() {
      _messages.removeWhere((m) => m.id == message.id);
    });

    // Update cache immediately
    ref
        .read(messagesCacheProvider.notifier)
        .removeMessage(widget.chat.id, message.id);

    // Delete from backend
    final success = await ChatService.deleteMessage(widget.chat.id, message.id);

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message deleted'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      // Restore message if deletion failed
      setState(() {
        _messages.add(message);
        _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      });

      // Restore to cache
      ref
          .read(messagesCacheProvider.notifier)
          .cacheMessages(widget.chat.id, _messages);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete message'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Resend a failed message
  Future<void> _resendMessage(MessageModel message) async {
    // Update message status to sending
    final messageIndex = _messages.indexWhere((m) => m.id == message.id);
    if (messageIndex != -1) {
      setState(() {
        _messages[messageIndex] = message.copyWith(
          status: MessageStatus.sending,
        );
      });
    }

    // Resend based on message type
    if (message.type == MessageType.text) {
      final result = await ChatService.sendTextMessage(
        widget.chat.id,
        message.content ?? '',
        replyToMessageId: message.replyTo?.messageId,
      );

      if (result.success && mounted) {
        // Replace with new message
        if (messageIndex != -1) {
          setState(() {
            _messages[messageIndex] = result.message!.copyWith(
              status: MessageStatus.sent,
            );
          });
        }
        ToasterService.showSuccess(context, 'Message sent');
      } else {
        // Mark as failed again
        if (messageIndex != -1 && mounted) {
          setState(() {
            _messages[messageIndex] = message.copyWith(
              status: MessageStatus.failed,
            );
          });
        }
        ToasterService.showError(context, 'Failed to resend message');
      }
    } else if (message.localFilePath != null) {
      // Resend media message
      final file = File(message.localFilePath!);
      if (await file.exists()) {
        final result = await ChatService.sendMediaMessage(
          widget.chat.id,
          message.type,
          file,
          replyToMessageId: message.replyTo?.messageId,
        );

        if (result.success && mounted) {
          // Replace with new message
          if (messageIndex != -1) {
            setState(() {
              _messages[messageIndex] = result.message!.copyWith(
                status: MessageStatus.sent,
              );
            });
          }
          ToasterService.showSuccess(context, 'Message sent');
        } else {
          // Mark as failed again
          if (messageIndex != -1 && mounted) {
            setState(() {
              _messages[messageIndex] = message.copyWith(
                status: MessageStatus.failed,
              );
            });
          }
          ToasterService.showError(context, 'Failed to resend message');
        }
      } else {
        ToasterService.showError(context, 'Media file not found');
        if (messageIndex != -1 && mounted) {
          setState(() {
            _messages[messageIndex] = message.copyWith(
              status: MessageStatus.failed,
            );
          });
        }
      }
    }
  }

  /// Handle audio recording (tap and hold)
  Future<void> _handleAudioRecording() async {
    if (_isRecording) {
      // Stop recording and send audio
      await _stopAudioRecording();
    } else {
      // Start recording
      await _startAudioRecording();
    }
  }

  /// Start audio recording
  Future<void> _startAudioRecording() async {
    try {
      final success = await AudioService.startRecording();
      if (success && mounted) {
        setState(() {
          _isRecording = true;
          _recordingDuration = 0;
          _isRecordingLocked = false;
        });

        // Start timer to track recording duration
        _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (
          timer,
        ) {
          setState(() {
            _recordingDuration = timer.tick * 100; // Duration in milliseconds

            // Lock recording after 2 seconds
            if (_recordingDuration >= 2000 && !_isRecordingLocked) {
              _isRecordingLocked = true;
              print('🎤 Recording locked after 2 seconds');
            }
          });
        });
      }
    } catch (e) {
      print('🎤 Recording error: $e');
    }
  }

  /// Pause/Resume audio recording
  Future<void> _togglePauseRecording() async {
    try {
      if (_isRecordingPaused) {
        // Resume recording
        print('🎤 Resuming recording');
        setState(() {
          _isRecordingPaused = false;
        });
        // Resume timer
        _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (
          timer,
        ) {
          setState(() {
            _recordingDuration += 100;
          });
        });
      } else {
        // Pause recording
        print('🎤 Pausing recording');
        setState(() {
          _isRecordingPaused = true;
        });
        // Pause timer
        _recordingTimer?.cancel();
        _recordingTimer = null;
      }
    } catch (e) {
      print('🎤 Pause/Resume error: $e');
    }
  }

  /// Stop audio recording and show preview
  Future<void> _stopAudioRecording({bool canceled = false}) async {
    try {
      // Cancel timer
      _recordingTimer?.cancel();
      _recordingTimer = null;

      setState(() {
        _isRecording = false;
      });

      final audioFile = await AudioService.stopRecording();

      // If recording was less than 2 seconds and not locked, auto-cancel
      if (_recordingDuration < 2000 && !_isRecordingLocked) {
        print('🎤 Recording canceled (duration: ${_recordingDuration}ms)');
        if (audioFile != null) {
          audioFile.deleteSync();
        }
        if (mounted) {
          ToasterService.showInfo(context, 'Hold for 2 seconds to record');
        }
        setState(() {
          _recordingDuration = 0;
          _isRecordingLocked = false;
        });
        return;
      }

      if (audioFile != null && mounted) {
        // Store the recorded audio file for preview
        setState(() {
          _recordedAudioFile = audioFile;
          _recordingDuration = 0;
          _isRecordingLocked = false;
        });
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
        _recordingDuration = 0;
        _isRecordingLocked = false;
      });
      _recordingTimer?.cancel();
      _recordingTimer = null;
      if (mounted) {
        ToasterService.showError(context, 'Failed to stop recording');
      }
    }
  }

  /// Delete recorded audio
  void _deleteRecordedAudio() {
    if (_recordedAudioFile != null) {
      // Delete the file
      _recordedAudioFile!.deleteSync();
      setState(() {
        _recordedAudioFile = null;
        _isPlayingRecordedAudio = false;
      });
    }
  }

  /// Re-record audio
  Future<void> _reRecordAudio() async {
    _deleteRecordedAudio();
    await _startAudioRecording();
  }

  /// Play/pause recorded audio preview
  Future<void> _toggleRecordedAudioPlayback() async {
    if (_recordedAudioFile == null) return;

    try {
      if (_isPlayingRecordedAudio) {
        await AudioService.stopAudio();
        setState(() {
          _isPlayingRecordedAudio = false;
        });
      } else {
        final success = await AudioService.playAudioFile(_recordedAudioFile!);
        if (success) {
          setState(() {
            _isPlayingRecordedAudio = true;
          });

          // Listen for audio completion
          AudioService.player.onPlayerComplete.listen((_) {
            if (mounted) {
              setState(() {
                _isPlayingRecordedAudio = false;
              });
            }
          });
        }
      }
    } catch (e) {
      print('Error playing recorded audio: $e');
    }
  }

  /// Send recorded audio
  Future<void> _sendRecordedAudio() async {
    if (_recordedAudioFile == null) return;

    final file = _recordedAudioFile!;
    setState(() {
      _recordedAudioFile = null;
      _isPlayingRecordedAudio = false;
    });

    await _sendMediaMessage(MessageType.audio, file);
  }

  /// Start a call (audio or video)
  Future<void> _startCall(CallType type) async {
    try {
      final currentUserId = TokenAuthService.currentUser?.id ?? '';
      final participants =
          widget.chat.members
              .where((member) => member.userId != currentUserId)
              .map((member) => member.userId)
              .toList();

      if (participants.isEmpty) {
        ToasterService.showError(context, 'No participants to call');
        return;
      }

      // Show loading
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

      // Create call
      final result = await JitsiService.createCall(
        chatId: widget.chat.id,
        participants: participants,
        type: type,
      );

      // Hide loading
      if (mounted) Navigator.of(context).pop();

      if (result.success && result.roomId != null) {
        // Join the call
        final currentUser = TokenAuthService.currentUser;
        final displayName = currentUser?.displayName ?? 'User';

        final joined = await JitsiService.joinCall(
          roomId: result.roomId!,
          displayName: displayName,
          type: type,
          avatar: currentUser?.photoURL,
        );

        if (!joined) {
          ToasterService.showError(context, 'Failed to join call');
        }
      } else {
        ToasterService.showError(context, result.message);
      }
    } catch (e) {
      // Hide loading if still showing
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      ToasterService.showError(
        context,
        'Failed to start call: ${e.toString()}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return PopScope(
      canPop: true,
      onPopInvoked: (bool didPop) {
        if (didPop) {
          print('🔙 ChatScreen: Screen was popped');
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFF1A1A1A),
        appBar: _buildAppBar(),
        body: Column(
          children: [
            // Connection status banner
            if (!_isConnected) _buildConnectionBanner(),
            Expanded(child: _buildMessageList()),
            _buildReplyPreview(),
            _buildTypingIndicator(),
            if (_recordedAudioFile != null) _buildAudioPreview(),
            MessageInput(
              controller: _messageController,
              onChanged: _onMessageChanged,
              onSend: _sendMessage,
              onAttachment: _showMediaPicker,
              onAudioRecord: _handleAudioRecording,
              onAudioPause: _togglePauseRecording,
              onAudioStop: _stopAudioRecording,
              isRecording: _isRecording,
              recordingDuration: _recordingDuration,
              isRecordingLocked: _isRecordingLocked,
              isRecordingPaused: _isRecordingPaused,
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final currentUserId = TokenAuthService.currentUser?.id ?? '';

    return AppBar(
      backgroundColor: const Color(0xFF2A2A2A),
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(true),
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
      ),
      title: Row(
        children: [
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[800],
            ),
            child:
                widget.chat.getChatAvatar(currentUserId) != null
                    ? ClipOval(
                      child: Image.network(
                        widget.chat.getChatAvatar(currentUserId)!,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildDefaultAvatar();
                        },
                      ),
                    )
                    : _buildDefaultAvatar(),
          ),
          const SizedBox(width: 12),

          // Name and status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.chat.getDisplayName(currentUserId),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  widget.chat.type == ChatType.group
                      ? '${widget.chat.activeMemberCount} members'
                      : 'Online', // In a real app, you'd track online status
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () => _startCall(CallType.video),
          icon: const Icon(Icons.videocam, color: Colors.white),
        ),
        IconButton(
          onPressed: () => _startCall(CallType.audio),
          icon: const Icon(Icons.call, color: Colors.white),
        ),
        IconButton(
          onPressed: () {
            // Chat info
            ToasterService.showInfo(context, 'Chat info coming soon!');
          },
          icon: const Icon(Icons.info_outline, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildDefaultAvatar() {
    final currentUserId = TokenAuthService.currentUser?.id ?? '';
    final displayName = widget.chat.getDisplayName(currentUserId);

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[800],
      ),
      child: Center(
        child: Text(
          displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    if (_isLoading && _messages.isEmpty) {
      return const MessageShimmer();
    }

    if (_messages.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No messages yet',
              style: TextStyle(color: Colors.grey, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'Start the conversation!',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 100),
      itemCount: _messages.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == 0 && _isLoadingMore) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4ECDC4)),
              ),
            ),
          );
        }

        final messageIndex = _isLoadingMore ? index - 1 : index;
        final message = _messages[messageIndex];
        final currentUserId = TokenAuthService.currentUser?.id ?? '';

        return ModernMessageBubble(
          message: message,
          isFromCurrentUser: message.senderId == currentUserId,
          onLongPress: () => _showMessageOptions(message),
          onReactionTap: (emoji) => _addReaction(message, emoji),
          onReply: () => _setReplyMessage(message),
          onDelete: () => _deleteMessage(message),
          onForward: () => _forwardMessage(message),
        );
      },
    );
  }

  Widget _buildReplyPreview() {
    if (_replyToMessage == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _replyAnimation,
      builder: (context, child) {
        return SizeTransition(
          sizeFactor: _replyAnimation,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
              border: Border(
                left: BorderSide(color: const Color(0xFF4ECDC4), width: 4),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Replying to ${_replyToMessage!.senderName}',
                        style: const TextStyle(
                          color: Color(0xFF4ECDC4),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _replyToMessage!.displayContent,
                        style: TextStyle(color: Colors.grey[400], fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _clearReply,
                  icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildConnectionBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6),
      color: const Color(0xFFFF9800),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Connecting...',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    if (_typingUsers.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _typingUsers.length == 1
                      ? '${_typingUsers.first} is typing'
                      : '${_typingUsers.length} people are typing',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.grey[400]!,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioPreview() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4ECDC4), Color(0xFF44A08D)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4ECDC4).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Play/Pause button
          GestureDetector(
            onTap: _toggleRecordedAudioPlayback,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                _isPlayingRecordedAudio ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Animated Waveform
          Expanded(
            child: WaveformAnimation(
              isRecording: _isPlayingRecordedAudio,
              color: Colors.white,
              height: 40,
              barCount: 25,
            ),
          ),
          const SizedBox(width: 12),

          // Delete button
          GestureDetector(
            onTap: _deleteRecordedAudio,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.delete_outline,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Re-record button
          GestureDetector(
            onTap: _reRecordAudio,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.mic, color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 8),

          // Send button
          GestureDetector(
            onTap: _sendRecordedAudio,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.send, color: Color(0xFF4ECDC4), size: 22),
            ),
          ),
        ],
      ),
    );
  }
}
