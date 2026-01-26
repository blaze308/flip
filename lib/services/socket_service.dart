import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/message_model.dart';
import 'token_auth_service.dart';

/// Socket.IO service for real-time messaging
class SocketService {
  static SocketService? _instance;
  static SocketService get instance => _instance ??= SocketService._();

  SocketService._();

  IO.Socket? _socket;
  bool _isConnected = false;
  String? _currentUserId;

  // Stream controllers for real-time events
  final StreamController<MessageModel> _newMessageController =
      StreamController.broadcast();
  final StreamController<MessageUpdateEvent> _messageUpdateController =
      StreamController.broadcast();
  final StreamController<ChatUpdateEvent> _chatUpdateController =
      StreamController.broadcast();
  final StreamController<UserStatusEvent> _userStatusController =
      StreamController.broadcast();
  final StreamController<TypingEvent> _typingController =
      StreamController.broadcast();
  final StreamController<ConnectionEvent> _connectionController =
      StreamController.broadcast();
  final StreamController<CallInvitationEvent> _callInvitationController =
      StreamController.broadcast();
  final StreamController<CallEndedEvent> _callEndedController =
      StreamController.broadcast();
  final StreamController<GiftReceiptEvent> _giftReceiptController =
      StreamController.broadcast();

  // Streams for listening to events
  Stream<MessageModel> get onNewMessage => _newMessageController.stream;
  Stream<MessageUpdateEvent> get onMessageUpdate =>
      _messageUpdateController.stream;
  Stream<ChatUpdateEvent> get onChatUpdate => _chatUpdateController.stream;
  Stream<UserStatusEvent> get onUserStatus => _userStatusController.stream;
  Stream<TypingEvent> get onTyping => _typingController.stream;
  Stream<ConnectionEvent> get onConnection => _connectionController.stream;
  Stream<CallInvitationEvent> get onCallInvitation =>
      _callInvitationController.stream;
  Stream<CallEndedEvent> get onCallEnded => _callEndedController.stream;
  Stream<GiftReceiptEvent> get onGiftReceived => _giftReceiptController.stream;

  // Getters
  bool get isConnected => _isConnected;
  String? get currentUserId => _currentUserId;
  IO.Socket? get socket => _socket; // Expose socket for live streaming events

  /// Initialize and connect to Socket.IO server
  Future<void> connect() async {
    if (_socket != null && _isConnected) {
      print('🔌 SocketService: Already connected');
      return;
    }

    try {
      // Get authentication token using JWT token system
      String? token;

      if (TokenAuthService.isAuthenticated) {
        // Use JWT token system - the primary authentication system
        final headers = await TokenAuthService.getAuthHeaders();
        if (headers != null && headers.containsKey('Authorization')) {
          token = headers['Authorization']!.replaceFirst('Bearer ', '');
          final currentUser = TokenAuthService.currentUser;
          if (currentUser != null) {
            _currentUserId = currentUser.id;
          }
          print('🔌 SocketService: Using JWT token for authentication');
        }
      }

      if (token == null) {
        print('🔌 SocketService: No authentication token available');
        return;
      }

      print('🔌 SocketService: Connecting to socket server...');

      // Create socket connection
      _socket = IO.io(
        'https://flip-backend-mnpg.onrender.com',
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(5)
            .setReconnectionDelay(1000)
            .setAuth({'token': token})
            .build(),
      );

      _setupEventListeners();

      print('🔌 SocketService: Socket connection initiated');
    } catch (e) {
      print('🔌 SocketService: Connection error: $e');
      _connectionController.add(
        ConnectionEvent(
          type: ConnectionEventType.error,
          message: 'Failed to connect: $e',
        ),
      );
    }
  }

  /// Disconnect from Socket.IO server
  void disconnect() {
    print('🔌 SocketService: Disconnecting...');

    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _currentUserId = null;

    _connectionController.add(
      ConnectionEvent(
        type: ConnectionEventType.disconnected,
        message: 'Disconnected from server',
      ),
    );
  }

  /// Setup event listeners
  void _setupEventListeners() {
    if (_socket == null) return;

    // Connection events
    _socket!.onConnect((_) {
      print('🔌 SocketService: Connected to server');
      _isConnected = true;
      _connectionController.add(
        ConnectionEvent(
          type: ConnectionEventType.connected,
          message: 'Connected to server',
        ),
      );
    });

    _socket!.onDisconnect((data) {
      print('🔌 SocketService: Disconnected from server: $data');
      _isConnected = false;
      _connectionController.add(
        ConnectionEvent(
          type: ConnectionEventType.disconnected,
          message: 'Disconnected from server',
        ),
      );

      // If disconnected due to auth error, try to reconnect with fresh token
      final reason = data?.toString() ?? '';
      if (reason.contains('auth') ||
          reason.contains('token') ||
          reason.contains('expired')) {
        print(
          '🔌 SocketService: Auth-related disconnect, will retry with fresh token',
        );
        Future.delayed(const Duration(seconds: 2), () {
          if (!_isConnected) {
            disconnect();
            connect();
          }
        });
      }
    });

    _socket!.onConnectError((data) {
      print('🔌 SocketService: Connection error: $data');
      _isConnected = false;
      _connectionController.add(
        ConnectionEvent(
          type: ConnectionEventType.error,
          message: 'Connection error: $data',
        ),
      );
    });

    _socket!.onError((data) {
      print('🔌 SocketService: Socket error: $data');
      _connectionController.add(
        ConnectionEvent(
          type: ConnectionEventType.error,
          message: 'Socket error: $data',
        ),
      );
    });

    // Chat events
    _socket!.on('new_message', (data) {
      try {
        print('🔌 SocketService: Received new message');
        final messageData = data['message'] as Map<String, dynamic>;
        final message = MessageModel.fromJson(messageData);
        _newMessageController.add(message);
      } catch (e) {
        print('🔌 SocketService: Error parsing new message: $e');
      }
    });

    _socket!.on('message_update', (data) {
      try {
        print('🔌 SocketService: Received message update');
        final updateEvent = MessageUpdateEvent.fromJson(
          data as Map<String, dynamic>,
        );
        _messageUpdateController.add(updateEvent);
      } catch (e) {
        print('🔌 SocketService: Error parsing message update: $e');
      }
    });

    _socket!.on('chat_update', (data) {
      try {
        print('🔌 SocketService: Received chat update');
        final updateEvent = ChatUpdateEvent.fromJson(
          data as Map<String, dynamic>,
        );
        _chatUpdateController.add(updateEvent);
      } catch (e) {
        print('🔌 SocketService: Error parsing chat update: $e');
      }
    });

    // User status events
    _socket!.on('user_online', (data) {
      try {
        final statusEvent = UserStatusEvent(
          userId: data['userId'] as String? ?? '',
          username: data['username'] as String? ?? 'Unknown',
          displayName: data['displayName'] as String?,
          status: UserStatus.online,
          timestamp: DateTime.now(),
        );
        _userStatusController.add(statusEvent);
      } catch (e) {
        print('🔌 SocketService: Error parsing user online event: $e');
      }
    });

    _socket!.on('user_offline', (data) {
      try {
        final statusEvent = UserStatusEvent(
          userId: data['userId'] as String? ?? '',
          username: data['username'] as String? ?? 'Unknown',
          displayName: null,
          status: UserStatus.offline,
          timestamp:
              data['lastSeen'] != null
                  ? DateTime.parse(data['lastSeen'] as String)
                  : DateTime.now(),
        );
        _userStatusController.add(statusEvent);
      } catch (e) {
        print('🔌 SocketService: Error parsing user offline event: $e');
      }
    });

    // Typing events
    _socket!.on('user_typing', (data) {
      try {
        final typingEvent = TypingEvent(
          userId: data['userId'] as String? ?? '',
          username: data['username'] as String? ?? 'Unknown',
          displayName: data['displayName'] as String?,
          chatId: data['chatId'] as String? ?? '',
          isTyping: true,
        );
        _typingController.add(typingEvent);
      } catch (e) {
        print('🔌 SocketService: Error parsing typing event: $e');
      }
    });

    _socket!.on('user_stopped_typing', (data) {
      try {
        final typingEvent = TypingEvent(
          userId: data['userId'] as String? ?? '',
          username: data['username'] as String? ?? 'Unknown',
          displayName: null,
          chatId: data['chatId'] as String? ?? '',
          isTyping: false,
        );
        _typingController.add(typingEvent);
      } catch (e) {
        print('🔌 SocketService: Error parsing stop typing event: $e');
      }
    });

    // Read receipt events
    _socket!.on('message_read_update', (data) {
      try {
        final updateEvent = MessageUpdateEvent(
          messageId: data['messageId'] as String? ?? '',
          updateType: MessageUpdateType.read,
          data: data as Map<String, dynamic>? ?? {},
          timestamp: DateTime.now(),
        );
        _messageUpdateController.add(updateEvent);
      } catch (e) {
        print('🔌 SocketService: Error parsing read update: $e');
      }
    });

    // Delivery receipt events
    _socket!.on('message_delivery_update', (data) {
      try {
        final updateEvent = MessageUpdateEvent(
          messageId: data['messageId'] as String? ?? '',
          updateType: MessageUpdateType.delivered,
          data: data as Map<String, dynamic>? ?? {},
          timestamp: DateTime.now(),
        );
        _messageUpdateController.add(updateEvent);
      } catch (e) {
        print('🔌 SocketService: Error parsing delivery update: $e');
      }
    });

    _socket!.on('chat_read_update', (data) {
      try {
        final updateEvent = ChatUpdateEvent(
          chatId: data['chatId'] as String,
          updateType: ChatUpdateType.messagesRead,
          data: data,
          timestamp: DateTime.now(),
        );
        _chatUpdateController.add(updateEvent);
      } catch (e) {
        print('🔌 SocketService: Error parsing chat read update: $e');
      }
    });

    // Response events
    _socket!.on('joined_chat', (data) {
      print('🔌 SocketService: Successfully joined chat ${data['chatId']}');
    });

    _socket!.on('left_chat', (data) {
      print('🔌 SocketService: Successfully left chat ${data['chatId']}');
    });

    _socket!.on('chat_marked_read', (data) {
      print(
        '🔌 SocketService: Chat marked as read: ${data['messageCount']} messages',
      );
    });

    // Call invitation events
    _socket!.on('call_invitation', (data) {
      try {
        print('📞 SocketService: Received call invitation');
        final invitationEvent = CallInvitationEvent.fromJson(
          data as Map<String, dynamic>,
        );
        _callInvitationController.add(invitationEvent);
      } catch (e) {
        print('📞 SocketService: Error parsing call invitation: $e');
      }
    });

    _socket!.on('call_ended', (data) {
      try {
        print('📞 SocketService: Call ended notification received');
        final callEndedEvent = CallEndedEvent.fromJson(
          data as Map<String, dynamic>,
        );
        _callEndedController.add(callEndedEvent);
      } catch (e) {
        print('📞 SocketService: Error parsing call ended: $e');
      }
    });

    // Gift Events
    _socket!.on('gift_received', (data) {
      try {
        print('🎁 SocketService: Gift received notification');
        final giftEvent = GiftReceiptEvent.fromJson(
          data as Map<String, dynamic>,
        );
        _giftReceiptController.add(giftEvent);
      } catch (e) {
        print('🎁 SocketService: Error parsing gift receipt: $e');
      }
    });

    _socket!.on('live:gift:sent', (data) {
      try {
        print('🎁 SocketService: Live room gift event');
        final giftEvent = GiftReceiptEvent.fromJson(
          data as Map<String, dynamic>,
        );
        _giftReceiptController.add(giftEvent);
      } catch (e) {
        print('🎁 SocketService: Error parsing live gift receipt: $e');
      }
    });
  }

  /// Join a chat room
  void joinChat(String chatId) {
    if (_socket != null && _isConnected) {
      print('🔌 SocketService: Joining chat $chatId');
      _socket!.emit('join_chat', chatId);
    }
  }

  /// Leave a chat room
  void leaveChat(String chatId) {
    if (_socket != null && _isConnected) {
      print('🔌 SocketService: Leaving chat $chatId');
      _socket!.emit('leave_chat', chatId);
    }
  }

  /// Send typing indicator
  void startTyping(String chatId) {
    if (_socket != null && _isConnected) {
      _socket!.emit('typing_start', {'chatId': chatId});
    }
  }

  /// Stop typing indicator
  void stopTyping(String chatId) {
    if (_socket != null && _isConnected) {
      _socket!.emit('typing_stop', {'chatId': chatId});
    }
  }

  /// Mark message as delivered
  void markMessageDelivered(String chatId, String messageId) {
    if (_socket != null && _isConnected) {
      _socket!.emit('message_delivered', {
        'chatId': chatId,
        'messageId': messageId,
      });
    }
  }

  /// Mark message as read
  void markMessageRead(String chatId, String messageId) {
    if (_socket != null && _isConnected) {
      _socket!.emit('message_read', {'chatId': chatId, 'messageId': messageId});
    }
  }

  /// Mark entire chat as read
  void markChatRead(String chatId) {
    if (_socket != null && _isConnected) {
      print('🔌 SocketService: Marking chat $chatId as read');
      _socket!.emit('mark_chat_read', {'chatId': chatId});
    }
  }

  /// Update user presence
  void updatePresence(UserStatus status) {
    if (_socket != null && _isConnected) {
      _socket!.emit('update_presence', {'status': status.name});
    }
  }

  /// Update online status (for app lifecycle management)
  void updateOnlineStatus(bool isOnline) {
    if (_socket != null && _isConnected) {
      print(
        '🔌 SocketService: Updating online status: ${isOnline ? "online" : "away"}',
      );
      _socket!.emit('update_status', {
        'status': isOnline ? 'online' : 'away',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } else {
      print('🔌 SocketService: Cannot update status - not connected');
    }
  }

  /// Generic emit method for custom events
  void emit(String event, dynamic data) {
    if (_socket != null && _isConnected) {
      print('🔌 SocketService: Emitting event: $event');
      _socket!.emit(event, data);
    } else {
      print('🔌 SocketService: Cannot emit $event - not connected');
    }
  }

  /// Generic on method for custom events
  void on(String event, Function(dynamic) callback) {
    if (_socket != null) {
      _socket!.on(event, callback);
    }
  }

  /// Remove event listener
  void off(String event) {
    if (_socket != null) {
      _socket!.off(event);
    }
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    _newMessageController.close();
    _messageUpdateController.close();
    _chatUpdateController.close();
    _userStatusController.close();
    _typingController.close();
    _connectionController.close();
    _callInvitationController.close();
    _callEndedController.close();
    _giftReceiptController.close();
  }
}

/// Event models for Socket.IO events

enum ConnectionEventType { connected, disconnected, error }

enum UserStatus { online, offline, away, busy }

enum MessageUpdateType {
  edited,
  deleted,
  reactionAdded,
  reactionRemoved,
  read,
  delivered,
}

enum ChatUpdateType {
  memberAdded,
  memberRemoved,
  infoUpdated,
  settingsChanged,
  messagesRead,
}

class ConnectionEvent {
  final ConnectionEventType type;
  final String message;

  const ConnectionEvent({required this.type, required this.message});
}

class UserStatusEvent {
  final String userId;
  final String username;
  final String? displayName;
  final UserStatus status;
  final DateTime timestamp;

  const UserStatusEvent({
    required this.userId,
    required this.username,
    this.displayName,
    required this.status,
    required this.timestamp,
  });
}

class TypingEvent {
  final String userId;
  final String username;
  final String? displayName;
  final String chatId;
  final bool isTyping;

  const TypingEvent({
    required this.userId,
    required this.username,
    this.displayName,
    required this.chatId,
    required this.isTyping,
  });
}

class MessageUpdateEvent {
  final String messageId;
  final MessageUpdateType updateType;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  const MessageUpdateEvent({
    required this.messageId,
    required this.updateType,
    required this.data,
    required this.timestamp,
  });

  factory MessageUpdateEvent.fromJson(Map<String, dynamic> json) {
    return MessageUpdateEvent(
      messageId: json['messageId'] as String,
      updateType: MessageUpdateType.values.firstWhere(
        (e) => e.name == json['updateType'],
        orElse: () => MessageUpdateType.edited,
      ),
      data: json['data'] as Map<String, dynamic>? ?? {},
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

class ChatUpdateEvent {
  final String chatId;
  final ChatUpdateType updateType;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  const ChatUpdateEvent({
    required this.chatId,
    required this.updateType,
    required this.data,
    required this.timestamp,
  });

  factory ChatUpdateEvent.fromJson(Map<String, dynamic> json) {
    return ChatUpdateEvent(
      chatId: json['chatId'] as String,
      updateType: ChatUpdateType.values.firstWhere(
        (e) => e.name == json['updateType'],
        orElse: () => ChatUpdateType.infoUpdated,
      ),
      data: json['data'] as Map<String, dynamic>? ?? {},
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

class CallInvitationEvent {
  final String callId;
  final String roomId;
  final String chatId;
  final String callerId;
  final String callerName;
  final String? callerAvatar;
  final String type; // 'audio' or 'video'
  final DateTime createdAt;

  const CallInvitationEvent({
    required this.callId,
    required this.roomId,
    required this.chatId,
    required this.callerId,
    required this.callerName,
    this.callerAvatar,
    required this.type,
    required this.createdAt,
  });

  factory CallInvitationEvent.fromJson(Map<String, dynamic> json) {
    return CallInvitationEvent(
      callId: json['callId'] as String,
      roomId: json['roomId'] as String,
      chatId: json['chatId'] as String,
      callerId: json['callerId'] as String,
      callerName: json['callerName'] as String,
      callerAvatar: json['callerAvatar'] as String?,
      type: json['type'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class CallEndedEvent {
  final String callId;
  final String endedBy;
  final DateTime endedAt;

  const CallEndedEvent({
    required this.callId,
    required this.endedBy,
    required this.endedAt,
  });

  factory CallEndedEvent.fromJson(Map<String, dynamic> json) {
    return CallEndedEvent(
      callId: json['callId'] as String,
      endedBy: json['endedBy'] as String,
      endedAt: DateTime.parse(json['endedAt'] as String),
    );
  }
}

class GiftReceiptEvent {
  final String giftId;
  final String giftName;
  final String? giftIcon;
  final String? animation;
  final int coins;
  final int quantity;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final bool isSenderMVP;
  final String receiverId;
  final String receiverName;
  final String context;
  final String? contextId;
  final DateTime timestamp;

  const GiftReceiptEvent({
    required this.giftId,
    required this.giftName,
    this.giftIcon,
    this.animation,
    required this.coins,
    required this.quantity,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    this.isSenderMVP = false,
    required this.receiverId,
    required this.receiverName,
    required this.context,
    this.contextId,
    required this.timestamp,
  });

  factory GiftReceiptEvent.fromJson(Map<String, dynamic> json) {
    final gift = json['gift'] as Map<String, dynamic>;
    final sender = json['sender'] as Map<String, dynamic>;
    final receiver = json['receiver'] as Map<String, dynamic>;

    return GiftReceiptEvent(
      giftId: gift['id'] as String,
      giftName: gift['name'] as String,
      giftIcon: gift['icon'] as String?,
      animation: gift['animation'] as String?,
      coins: (gift['coins'] as num).toInt(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      senderId: sender['userId'] as String,
      senderName: sender['displayName'] as String,
      senderAvatar: sender['photoURL'] as String?,
      isSenderMVP: sender['isMVP'] as bool? ?? false,
      receiverId: receiver['userId'] as String,
      receiverName: receiver['displayName'] as String,
      context: json['context'] as String,
      contextId: json['contextId'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
