import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:async';
import 'dart:io';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../services/chat_service.dart';
import '../services/socket_service.dart';
import '../services/token_auth_service.dart';
import '../services/audio_service.dart';
import '../services/jitsi_service.dart';
import '../services/cloudinary_service.dart';
import '../widgets/custom_toaster.dart';
import '../widgets/modern_message_bubble.dart';
import '../widgets/message_input.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final ChatModel chat;

  const ChatScreen({super.key, required this.chat});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with TickerProviderStateMixin {
  final List<MessageModel> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isTyping = false;
  bool _isRecording = false;

  // Socket subscriptions
  StreamSubscription? _newMessageSubscription;
  StreamSubscription? _messageUpdateSubscription;
  StreamSubscription? _typingSubscription;

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
        // Check if message already exists to prevent duplication
        final existingIndex = _messages.indexWhere((m) => m.id == message.id);
        if (existingIndex == -1) {
          final currentUserId = TokenAuthService.currentUser?.id ?? '';
          final isUserAtBottom = _isUserAtBottom();

          // Clear cache when new message arrives
          ChatService.clearMessageCache(widget.chat.id);

          setState(() {
            _messages.add(
              message,
            ); // Add to end since newest should be at bottom
          });

          // Auto-scroll to bottom if user sent the message or if user is already at bottom
          if (message.senderId == currentUserId || isUserAtBottom) {
            _scrollToBottom();
          }
        }

        // Mark message as delivered and read if not from current user
        final currentUserId = TokenAuthService.currentUser?.id ?? '';
        if (message.senderId != currentUserId) {
          // Mark as delivered first
          socketService.markMessageDelivered(widget.chat.id, message.id);
          // Then mark as read
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
          case MessageUpdateType.deleted:
            // Refresh the message
            _refreshMessage(event.messageId);
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
      setState(() {
        _typingUsers.remove(event.username);
      });
    });
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
          _messages.addAll(
            result.messages,
          ); // Don't reverse - backend should send in correct order
          _isLoading = false;
        });

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
      senderFirebaseUid: currentUser.firebaseUid,
      senderName: currentUser.displayName ?? 'You',
      senderAvatar: currentUser.photoURL,
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
                senderName: _replyToMessage!.senderName,
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
          setState(() {
            _messages[messageIndex] = result.message!.copyWith(
              status: MessageStatus.sent,
            );
          });
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

  Future<void> _sendMediaMessage(MessageType type, File file) async {
    try {
      print('🎵 ChatScreen: Sending ${type.name} message...');
      final result = await ChatService.sendMediaMessage(
        widget.chat.id,
        type,
        file,
        replyToMessageId: _replyToMessage?.id,
      );

      if (result.success && mounted) {
        print('🎵 ChatScreen: ${type.name} message sent successfully');
        _clearReply();

        // Refresh messages to show the new audio message
        await _loadMessages();
      } else {
        print(
          '🎵 ChatScreen: Failed to send ${type.name} message: ${result.resultMessage}',
        );
      }
    } catch (e) {
      print('🎵 ChatScreen: Error sending ${type.name} message: $e');
    }
  }

  void _showMediaPicker() {
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
                      onTap: () => _pickImage(ImageSource.camera),
                    ),
                    _buildMediaOption(
                      icon: Icons.photo_library,
                      label: 'Gallery',
                      onTap: () => _pickImage(ImageSource.gallery),
                    ),
                    _buildMediaOption(
                      icon: Icons.videocam,
                      label: 'Video',
                      onTap: () => _pickVideo(),
                    ),
                    _buildMediaOption(
                      icon: Icons.attach_file,
                      label: 'File',
                      onTap: () => _pickFile(),
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
                      onTap: () => _showLottieModal(),
                    ),
                    _buildMediaOption(
                      icon: Icons.play_circle_outline,
                      label: 'SVGA',
                      onTap: () => _showSvgaModal(),
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
  }

  Widget _buildMediaOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
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

  /// Show Lottie selection modal
  void _showLottieModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.6,
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 20),
                const Text(
                  'Choose Lottie Animation',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
            Expanded(
              child: CloudinaryService.getMockLottieFiles().isEmpty
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
                            'No Lottie animations available',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Add Lottie files to Cloudinary lotties folder',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1,
                          ),
                      itemCount: CloudinaryService.getMockLottieFiles().length,
                      itemBuilder: (context, index) {
                        final lottie =
                            CloudinaryService.getMockLottieFiles()[index];
                        return _buildLottieItem(lottie);
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.6,
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 20),
                const Text(
                  'Choose SVGA Animation',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
            Expanded(
              child: CloudinaryService.getMockSvgaFiles().isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.play_circle_outline,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No SVGA animations available',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Add SVGA files to Cloudinary svga folder',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1,
                          ),
                      itemCount: CloudinaryService.getMockSvgaFiles().length,
                      itemBuilder: (context, index) {
                        final svga = CloudinaryService.getMockSvgaFiles()[index];
                        return _buildSvgaItem(svga);
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        await _sendMediaMessage(MessageType.image, file);
      }
    } catch (e) {
      ToasterService.showError(context, 'Failed to pick image');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickVideo(source: ImageSource.gallery);

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        await _sendMediaMessage(MessageType.video, file);
      }
    } catch (e) {
      ToasterService.showError(context, 'Failed to pick video');
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

        await _sendMediaMessage(type, file);
      }
    } catch (e) {
      ToasterService.showError(context, 'Failed to pick file');
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
        });
      }
    } catch (e) {
      print('🎤 Recording error: $e');
    }
  }

  /// Pause audio recording
  Future<void> _pauseAudioRecording() async {
    try {
      // TODO: Implement pause functionality in AudioService
      print('🎤 Pause recording requested');
    } catch (e) {
      print('🎤 Pause error: $e');
    }
  }

  /// Stop audio recording and send
  Future<void> _stopAudioRecording() async {
    try {
      setState(() {
        _isRecording = false;
      });

      final audioFile = await AudioService.stopRecording();
      if (audioFile != null && mounted) {
        await _sendMediaMessage(MessageType.audio, audioFile);
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
      });
    }
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
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildReplyPreview(),
          _buildTypingIndicator(),
          MessageInput(
            controller: _messageController,
            onChanged: _onMessageChanged,
            onSend: _sendMessage,
            onAttachment: _showMediaPicker,
            onAudioRecord: _handleAudioRecording,
            onAudioPause: _pauseAudioRecording,
            onAudioStop: _stopAudioRecording,
            isRecording: _isRecording,
          ),
        ],
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
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4ECDC4)),
        ),
      );
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
}
