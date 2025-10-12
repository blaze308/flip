import 'package:intl/intl.dart';
import 'user_model.dart';

/// Enum for chat types
enum ChatType { direct, group }

/// Enum for chat status
enum ChatStatus { active, archived, deleted }

/// Enum for member roles
enum MemberRole { admin, moderator, member }

/// Chat member model - SIMPLIFIED to only store reference and chat-specific data
/// User details come from UserModel via population
class ChatMember {
  final String userId;
  final UserModel? user; // Populated user data (null if not populated)
  final MemberRole role;
  final DateTime joinedAt;
  final DateTime lastSeenAt;
  final bool isActive;
  final NotificationSettings notifications;

  const ChatMember({
    required this.userId,
    this.user,
    required this.role,
    required this.joinedAt,
    required this.lastSeenAt,
    required this.isActive,
    required this.notifications,
  });

  /// Get display name from populated user or fallback
  String get displayName =>
      user?.bestDisplayName ?? 'User ${userId.substring(0, 8)}';

  /// Get username from populated user or fallback
  String get username => user?.username ?? 'user_${userId.substring(0, 8)}';

  /// Get best name for chat display (prefers username to avoid emails)
  String get bestChatName {
    if (user != null) {
      final uname = user!.username;
      // If username is valid (not default), use it
      if (uname.isNotEmpty && uname != 'user') {
        return '@$uname';
      }
      // Otherwise use displayName
      return user!.bestDisplayName;
    }
    return 'User ${userId.substring(0, 8)}';
  }

  /// Get avatar from populated user
  String? get avatar => user?.bestAvatar;

  factory ChatMember.fromJson(Map<String, dynamic> json) {
    // Handle populated userId (when user data is populated)
    final userIdData = json['userId'];
    final String userId;
    UserModel? user;

    if (userIdData is Map<String, dynamic>) {
      // User data is populated - convert to UserModel
      userId =
          (userIdData['_id'] as String?) ?? (userIdData['id'] as String?) ?? '';
      user = UserModel.fromJson(userIdData);
    } else if (userIdData is String) {
      // userId is just a string reference
      userId = userIdData;
      user = null;
    } else {
      // Fallback for null or unexpected type
      userId = '';
      user = null;
    }

    return ChatMember(
      userId: userId,
      user: user,
      role: MemberRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => MemberRole.member,
      ),
      joinedAt:
          DateTime.tryParse(json['joinedAt'] as String? ?? '') ??
          DateTime.now(),
      lastSeenAt:
          DateTime.tryParse(json['lastSeenAt'] as String? ?? '') ??
          DateTime.now(),
      isActive: json['isActive'] as bool? ?? true,
      notifications: NotificationSettings.fromJson(
        json['notifications'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'role': role.name,
      'joinedAt': joinedAt.toIso8601String(),
      'lastSeenAt': lastSeenAt.toIso8601String(),
      'isActive': isActive,
      'notifications': notifications.toJson(),
    };
  }

  ChatMember copyWith({
    String? userId,
    UserModel? user,
    MemberRole? role,
    DateTime? joinedAt,
    DateTime? lastSeenAt,
    bool? isActive,
    NotificationSettings? notifications,
  }) {
    return ChatMember(
      userId: userId ?? this.userId,
      user: user ?? this.user,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      isActive: isActive ?? this.isActive,
      notifications: notifications ?? this.notifications,
    );
  }
}

/// Notification settings for chat members
class NotificationSettings {
  final bool enabled;
  final bool sound;
  final bool vibration;

  const NotificationSettings({
    required this.enabled,
    required this.sound,
    required this.vibration,
  });

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      enabled: json['enabled'] as bool? ?? true,
      sound: json['sound'] as bool? ?? true,
      vibration: json['vibration'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {'enabled': enabled, 'sound': sound, 'vibration': vibration};
  }
}

/// Last message preview model - SIMPLIFIED
class LastMessage {
  final String messageId;
  final String content;
  final String type;
  final String senderId;
  final UserModel? sender; // Populated sender data (null if not populated)
  final DateTime timestamp;

  const LastMessage({
    required this.messageId,
    required this.content,
    required this.type,
    required this.senderId,
    this.sender,
    required this.timestamp,
  });

  /// Get sender name from populated user or fallback
  String get senderName =>
      sender?.bestDisplayName ?? 'User ${senderId.substring(0, 8)}';

  factory LastMessage.fromJson(Map<String, dynamic> json) {
    // Handle populated senderId (when sender data is populated)
    final senderIdData = json['senderId'];
    final String senderId;
    UserModel? sender;

    if (senderIdData is Map<String, dynamic>) {
      // Sender data is populated - convert to UserModel
      senderId =
          (senderIdData['_id'] as String?) ??
          (senderIdData['id'] as String?) ??
          '';
      sender = UserModel.fromJson(senderIdData);
    } else if (senderIdData is String) {
      // senderId is just a string reference
      senderId = senderIdData;
      sender = null;
    } else {
      // Fallback for null or unexpected type
      senderId = '';
      sender = null;
    }

    return LastMessage(
      messageId: (json['messageId'] as String?) ?? '',
      content: json['content'] as String? ?? '',
      type: (json['type'] as String?) ?? 'text',
      senderId: senderId,
      sender: sender,
      timestamp:
          DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'messageId': messageId,
      'content': content,
      'type': type,
      'senderId': senderId,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Chat settings model
class ChatSettings {
  final String whoCanAddMembers;
  final String whoCanEditInfo;
  final String whoCanSendMessages;
  final int maxMembers;
  final AutoDeleteSettings autoDeleteMessages;

  const ChatSettings({
    required this.whoCanAddMembers,
    required this.whoCanEditInfo,
    required this.whoCanSendMessages,
    required this.maxMembers,
    required this.autoDeleteMessages,
  });

  factory ChatSettings.fromJson(Map<String, dynamic> json) {
    return ChatSettings(
      whoCanAddMembers: json['whoCanAddMembers'] as String? ?? 'admin',
      whoCanEditInfo: json['whoCanEditInfo'] as String? ?? 'admin',
      whoCanSendMessages: json['whoCanSendMessages'] as String? ?? 'all',
      maxMembers: json['maxMembers'] as int? ?? 256,
      autoDeleteMessages: AutoDeleteSettings.fromJson(
        json['autoDeleteMessages'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'whoCanAddMembers': whoCanAddMembers,
      'whoCanEditInfo': whoCanEditInfo,
      'whoCanSendMessages': whoCanSendMessages,
      'maxMembers': maxMembers,
      'autoDeleteMessages': autoDeleteMessages.toJson(),
    };
  }
}

/// Auto-delete settings model
class AutoDeleteSettings {
  final bool enabled;
  final int duration; // in hours

  const AutoDeleteSettings({required this.enabled, required this.duration});

  factory AutoDeleteSettings.fromJson(Map<String, dynamic> json) {
    return AutoDeleteSettings(
      enabled: json['enabled'] as bool? ?? false,
      duration: json['duration'] as int? ?? 24,
    );
  }

  Map<String, dynamic> toJson() {
    return {'enabled': enabled, 'duration': duration};
  }
}

/// Main Chat model - Industry Standard (TikTok/Instagram style)
/// Stores only chat-specific data, user details come from UserModel
class ChatModel {
  final String id;
  final ChatType type;
  final String? name;
  final String? description;
  final String? avatar;
  final List<ChatMember> members;
  final String createdBy;
  final ChatStatus status;
  final LastMessage? lastMessage;
  final int messageCount;
  final ChatSettings settings;
  final List<String> participants; // For direct chats
  final DateTime createdAt;
  final DateTime updatedAt;
  final int unreadCount;

  const ChatModel({
    required this.id,
    required this.type,
    this.name,
    this.description,
    this.avatar,
    required this.members,
    required this.createdBy,
    required this.status,
    this.lastMessage,
    required this.messageCount,
    required this.settings,
    required this.participants,
    required this.createdAt,
    required this.updatedAt,
    this.unreadCount = 0,
  });

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    return ChatModel(
      id: json['_id'] as String,
      type: ChatType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ChatType.direct,
      ),
      name: json['name'] as String?,
      description: json['description'] as String?,
      avatar: json['avatar'] as String?,
      members:
          (json['members'] as List<dynamic>?)
              ?.map((m) => ChatMember.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      createdBy: json['createdBy'] as String,
      status: ChatStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ChatStatus.active,
      ),
      lastMessage:
          json['lastMessage'] != null
              ? LastMessage.fromJson(
                json['lastMessage'] as Map<String, dynamic>,
              )
              : null,
      messageCount:
          json['messageCount'] != null
              ? (json['messageCount'] as num).toInt()
              : 0,
      settings: ChatSettings.fromJson(
        json['settings'] as Map<String, dynamic>? ?? {},
      ),
      participants:
          (json['participants'] as List<dynamic>?)
              ?.map((p) => p as String)
              .toList() ??
          [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      unreadCount:
          json['unreadCount'] != null
              ? (json['unreadCount'] as num).toInt()
              : 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'type': type.name,
      'name': name,
      'description': description,
      'avatar': avatar,
      'members': members.map((m) => m.toJson()).toList(),
      'createdBy': createdBy,
      'status': status.name,
      'lastMessage': lastMessage?.toJson(),
      'messageCount': messageCount,
      'settings': settings.toJson(),
      'participants': participants,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'unreadCount': unreadCount,
    };
  }

  ChatModel copyWith({
    String? id,
    ChatType? type,
    String? name,
    String? description,
    String? avatar,
    List<ChatMember>? members,
    String? createdBy,
    ChatStatus? status,
    LastMessage? lastMessage,
    int? messageCount,
    ChatSettings? settings,
    List<String>? participants,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? unreadCount,
  }) {
    return ChatModel(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      description: description ?? this.description,
      avatar: avatar ?? this.avatar,
      members: members ?? this.members,
      createdBy: createdBy ?? this.createdBy,
      status: status ?? this.status,
      lastMessage: lastMessage ?? this.lastMessage,
      messageCount: messageCount ?? this.messageCount,
      settings: settings ?? this.settings,
      participants: participants ?? this.participants,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  /// Get display name for the chat
  String getDisplayName(String currentUserId) {
    if (type == ChatType.group) {
      return name ?? 'Group Chat';
    }

    // For direct chats, return the other participant's best chat name
    try {
      final otherMember = members.firstWhere(
        (member) => member.userId != currentUserId && member.isActive,
      );
      return otherMember.bestChatName;
    } catch (e) {
      return members.isNotEmpty ? members.first.bestChatName : 'User';
    }
  }

  /// Get avatar for the chat
  String? getChatAvatar(String currentUserId) {
    if (type == ChatType.group) {
      return avatar;
    }

    // For direct chats, return the other participant's avatar
    try {
      final otherMember = members.firstWhere(
        (member) => member.userId != currentUserId && member.isActive,
      );
      return otherMember.avatar;
    } catch (e) {
      return members.isNotEmpty ? members.first.avatar : null;
    }
  }

  /// Get formatted last message time
  String getFormattedLastMessageTime() {
    if (lastMessage == null) return '';

    final now = DateTime.now();
    final messageTime = lastMessage!.timestamp;
    final difference = now.difference(messageTime);

    if (difference.inDays > 0) {
      if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return DateFormat('EEEE').format(messageTime); // Day name
      } else {
        return DateFormat('MMM d').format(messageTime); // Month day
      }
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  /// Get preview of last message content
  String getLastMessagePreview() {
    if (lastMessage == null) return 'No messages yet';

    switch (lastMessage!.type) {
      case 'text':
        return lastMessage!.content.isNotEmpty
            ? lastMessage!.content
            : 'Message';
      case 'image':
        return '📷 Photo';
      case 'video':
        return '🎥 Video';
      case 'audio':
        return '🎵 Audio';
      case 'lottie':
        return '✨ Animation';
      case 'svga':
        return '🎬 Animation';
      case 'file':
        return '📎 File';
      case 'location':
        return '📍 Location';
      case 'contact':
        return '👤 Contact';
      default:
        return 'Message';
    }
  }

  /// Check if current user is admin
  bool isCurrentUserAdmin(String currentUserId) {
    try {
      final currentMember = members.firstWhere(
        (member) => member.userId == currentUserId,
      );
      return currentMember.role == MemberRole.admin;
    } catch (e) {
      return false;
    }
  }

  /// Get active member count
  int get activeMemberCount {
    return members.where((member) => member.isActive).length;
  }
}
