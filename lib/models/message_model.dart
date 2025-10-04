import 'package:intl/intl.dart';

/// Enum for message types
enum MessageType {
  text,
  image,
  video,
  audio,
  lottie,
  svga,
  file,
  location,
  contact,
  system,
}

/// Enum for message status
enum MessageStatus { sending, sent, delivered, read, failed }

/// Enum for message priority
enum MessagePriority { low, normal, high, urgent }

/// Message reaction model
class MessageReaction {
  final String id;
  final String userId;
  final String username;
  final String emoji;
  final DateTime createdAt;

  const MessageReaction({
    required this.id,
    required this.userId,
    required this.username,
    required this.emoji,
    required this.createdAt,
  });

  factory MessageReaction.fromJson(Map<String, dynamic> json) {
    return MessageReaction(
      id: json['_id'] as String,
      userId: json['userId'] as String,
      username: json['username'] as String,
      emoji: json['emoji'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'userId': userId,
      'username': username,
      'emoji': emoji,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

/// Message media model
class MessageMedia {
  final String url;
  final String? thumbnailUrl;
  final String fileName;
  final int fileSize;
  final String mimeType;
  final int? duration; // in seconds
  final MessageDimensions? dimensions;
  final Map<String, dynamic>? lottieData;
  final Map<String, dynamic>? svgaData;

  const MessageMedia({
    required this.url,
    this.thumbnailUrl,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    this.duration,
    this.dimensions,
    this.lottieData,
    this.svgaData,
  });

  factory MessageMedia.fromJson(Map<String, dynamic> json) {
    return MessageMedia(
      url: json['url'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      fileName: json['fileName'] as String,
      fileSize: (json['fileSize'] as num).toInt(),
      mimeType: json['mimeType'] as String,
      duration:
          json['duration'] != null ? (json['duration'] as num).toInt() : null,
      dimensions:
          json['dimensions'] != null
              ? MessageDimensions.fromJson(
                json['dimensions'] as Map<String, dynamic>,
              )
              : null,
      lottieData: json['lottieData'] as Map<String, dynamic>?,
      svgaData: json['svgaData'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'thumbnailUrl': thumbnailUrl,
      'fileName': fileName,
      'fileSize': fileSize,
      'mimeType': mimeType,
      'duration': duration,
      'dimensions': dimensions?.toJson(),
      'lottieData': lottieData,
      'svgaData': svgaData,
    };
  }

  /// Get formatted file size
  String get formattedFileSize {
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var size = fileSize.toDouble();
    var suffixIndex = 0;

    while (size >= 1024 && suffixIndex < suffixes.length - 1) {
      size /= 1024;
      suffixIndex++;
    }

    return '${size.toStringAsFixed(size < 10 ? 1 : 0)} ${suffixes[suffixIndex]}';
  }

  /// Get formatted duration
  String get formattedDuration {
    if (duration == null) return '';

    final minutes = duration! ~/ 60;
    final seconds = duration! % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Message dimensions model
class MessageDimensions {
  final int width;
  final int height;

  const MessageDimensions({required this.width, required this.height});

  factory MessageDimensions.fromJson(Map<String, dynamic> json) {
    return MessageDimensions(
      width: (json['width'] as num).toInt(),
      height: (json['height'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'width': width, 'height': height};
  }

  /// Get aspect ratio
  double get aspectRatio => width / height;
}

/// Message location model
class MessageLocation {
  final double latitude;
  final double longitude;
  final String? address;
  final String? name;

  const MessageLocation({
    required this.latitude,
    required this.longitude,
    this.address,
    this.name,
  });

  factory MessageLocation.fromJson(Map<String, dynamic> json) {
    return MessageLocation(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: json['address'] as String?,
      name: json['name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'name': name,
    };
  }
}

/// Message contact model
class MessageContact {
  final String name;
  final String? phoneNumber;
  final String? email;
  final String? avatar;

  const MessageContact({
    required this.name,
    this.phoneNumber,
    this.email,
    this.avatar,
  });

  factory MessageContact.fromJson(Map<String, dynamic> json) {
    return MessageContact(
      name: json['name'] as String,
      phoneNumber: json['phoneNumber'] as String?,
      email: json['email'] as String?,
      avatar: json['avatar'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'email': email,
      'avatar': avatar,
    };
  }
}

/// Message reference model (for replies and forwards)
class MessageReference {
  final String messageId;
  final String senderId;
  final String senderName;
  final String content;
  final MessageType type;
  final DateTime timestamp;

  const MessageReference({
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.type,
    required this.timestamp,
  });

  factory MessageReference.fromJson(Map<String, dynamic> json) {
    return MessageReference(
      messageId: json['messageId'] as String,
      senderId: json['senderId'] as String,
      senderName: json['senderName'] as String,
      content: json['content'] as String? ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MessageType.text,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'messageId': messageId,
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Message mention model
class MessageMention {
  final String userId;
  final String username;
  final int startIndex;
  final int length;

  const MessageMention({
    required this.userId,
    required this.username,
    required this.startIndex,
    required this.length,
  });

  factory MessageMention.fromJson(Map<String, dynamic> json) {
    return MessageMention(
      userId: json['userId'] as String,
      username: json['username'] as String,
      startIndex: json['startIndex'] as int,
      length: json['length'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'startIndex': startIndex,
      'length': length,
    };
  }
}

/// Read receipt model
class ReadReceipt {
  final String userId;
  final String username;
  final DateTime readAt;

  const ReadReceipt({
    required this.userId,
    required this.username,
    required this.readAt,
  });

  factory ReadReceipt.fromJson(Map<String, dynamic> json) {
    return ReadReceipt(
      userId: json['userId'] as String,
      username: json['username'] as String,
      readAt: DateTime.parse(json['readAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'readAt': readAt.toIso8601String(),
    };
  }
}

/// Delivery receipt model
class DeliveryReceipt {
  final String userId;
  final String username;
  final DateTime deliveredAt;

  const DeliveryReceipt({
    required this.userId,
    required this.username,
    required this.deliveredAt,
  });

  factory DeliveryReceipt.fromJson(Map<String, dynamic> json) {
    return DeliveryReceipt(
      userId: json['userId'] as String,
      username: json['username'] as String,
      deliveredAt: DateTime.parse(json['deliveredAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'deliveredAt': deliveredAt.toIso8601String(),
    };
  }
}

/// Main Message model
class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String senderFirebaseUid;
  final String senderName;
  final String? senderAvatar;
  final MessageType type;
  final String? content;
  final MessageMedia? media;
  final MessageLocation? location;
  final MessageContact? contact;
  final MessageStatus status;
  final List<MessageReaction> reactions;
  final MessageReference? replyTo;
  final MessageReference? forwardedFrom;
  final List<MessageMention> mentions;
  final String? threadId;
  final List<ReadReceipt> readBy;
  final List<DeliveryReceipt> deliveredTo;
  final bool isEdited;
  final DateTime? editedAt;
  final bool isDeleted;
  final DateTime? deletedAt;
  final List<String> deletedFor;
  final Map<String, dynamic>? systemData;
  final MessagePriority priority;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderFirebaseUid,
    required this.senderName,
    this.senderAvatar,
    required this.type,
    this.content,
    this.media,
    this.location,
    this.contact,
    required this.status,
    required this.reactions,
    this.replyTo,
    this.forwardedFrom,
    required this.mentions,
    this.threadId,
    required this.readBy,
    required this.deliveredTo,
    required this.isEdited,
    this.editedAt,
    required this.isDeleted,
    this.deletedAt,
    required this.deletedFor,
    this.systemData,
    required this.priority,
    this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    // Handle populated senderId (when sender data is populated)
    final senderIdData = json['senderId'];
    final String senderId;
    final String senderName;
    final String? senderAvatar;

    if (senderIdData is Map<String, dynamic>) {
      // Sender data is populated
      senderId = senderIdData['_id'] as String;
      senderName =
          senderIdData['displayName'] as String? ??
          senderIdData['profile']?['username'] as String? ??
          senderIdData['email']?.toString().split('@')[0] ??
          'User';
      senderAvatar = senderIdData['photoURL'] as String?;
    } else {
      // Legacy format or senderId is just a string
      senderId = senderIdData as String;
      senderName = json['senderName'] as String? ?? 'User';
      senderAvatar = json['senderAvatar'] as String?;
    }

    return MessageModel(
      id: json['_id'] as String,
      chatId: json['chatId'] as String,
      senderId: senderId,
      senderFirebaseUid: json['senderFirebaseUid'] as String? ?? '',
      senderName: senderName,
      senderAvatar: senderAvatar,
      type: MessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MessageType.text,
      ),
      content: json['content'] as String?,
      media:
          json['media'] != null
              ? MessageMedia.fromJson(json['media'] as Map<String, dynamic>)
              : null,
      location:
          json['location'] != null
              ? MessageLocation.fromJson(
                json['location'] as Map<String, dynamic>,
              )
              : null,
      contact:
          json['contact'] != null
              ? MessageContact.fromJson(json['contact'] as Map<String, dynamic>)
              : null,
      status: MessageStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => MessageStatus.sent,
      ),
      reactions:
          (json['reactions'] as List<dynamic>?)
              ?.map((r) => MessageReaction.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      replyTo:
          json['replyTo'] != null
              ? MessageReference.fromJson(
                json['replyTo'] as Map<String, dynamic>,
              )
              : null,
      forwardedFrom:
          json['forwardedFrom'] != null
              ? MessageReference.fromJson(
                json['forwardedFrom'] as Map<String, dynamic>,
              )
              : null,
      mentions:
          (json['mentions'] as List<dynamic>?)
              ?.map((m) => MessageMention.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      threadId: json['threadId'] as String?,
      readBy:
          (json['readBy'] as List<dynamic>?)
              ?.map((r) => ReadReceipt.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      deliveredTo:
          (json['deliveredTo'] as List<dynamic>?)
              ?.map((d) => DeliveryReceipt.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
      isEdited: json['isEdited'] as bool? ?? false,
      editedAt:
          json['editedAt'] != null
              ? DateTime.parse(json['editedAt'] as String)
              : null,
      isDeleted: json['isDeleted'] as bool? ?? false,
      deletedAt:
          json['deletedAt'] != null
              ? DateTime.parse(json['deletedAt'] as String)
              : null,
      deletedFor:
          (json['deletedFor'] as List<dynamic>?)
              ?.map((d) => d as String)
              .toList() ??
          [],
      systemData: json['systemData'] as Map<String, dynamic>?,
      priority: MessagePriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => MessagePriority.normal,
      ),
      expiresAt:
          json['expiresAt'] != null
              ? DateTime.parse(json['expiresAt'] as String)
              : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'chatId': chatId,
      'senderId': senderId,
      'senderFirebaseUid': senderFirebaseUid,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'type': type.name,
      'content': content,
      'media': media?.toJson(),
      'location': location?.toJson(),
      'contact': contact?.toJson(),
      'status': status.name,
      'reactions': reactions.map((r) => r.toJson()).toList(),
      'replyTo': replyTo?.toJson(),
      'forwardedFrom': forwardedFrom?.toJson(),
      'mentions': mentions.map((m) => m.toJson()).toList(),
      'threadId': threadId,
      'readBy': readBy.map((r) => r.toJson()).toList(),
      'deliveredTo': deliveredTo.map((d) => d.toJson()).toList(),
      'isEdited': isEdited,
      'editedAt': editedAt?.toIso8601String(),
      'isDeleted': isDeleted,
      'deletedAt': deletedAt?.toIso8601String(),
      'deletedFor': deletedFor,
      'systemData': systemData,
      'priority': priority.name,
      'expiresAt': expiresAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  MessageModel copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? senderFirebaseUid,
    String? senderName,
    String? senderAvatar,
    MessageType? type,
    String? content,
    MessageMedia? media,
    MessageLocation? location,
    MessageContact? contact,
    MessageStatus? status,
    List<MessageReaction>? reactions,
    MessageReference? replyTo,
    MessageReference? forwardedFrom,
    List<MessageMention>? mentions,
    String? threadId,
    List<ReadReceipt>? readBy,
    List<DeliveryReceipt>? deliveredTo,
    bool? isEdited,
    DateTime? editedAt,
    bool? isDeleted,
    DateTime? deletedAt,
    List<String>? deletedFor,
    Map<String, dynamic>? systemData,
    MessagePriority? priority,
    DateTime? expiresAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MessageModel(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      senderFirebaseUid: senderFirebaseUid ?? this.senderFirebaseUid,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      type: type ?? this.type,
      content: content ?? this.content,
      media: media ?? this.media,
      location: location ?? this.location,
      contact: contact ?? this.contact,
      status: status ?? this.status,
      reactions: reactions ?? this.reactions,
      replyTo: replyTo ?? this.replyTo,
      forwardedFrom: forwardedFrom ?? this.forwardedFrom,
      mentions: mentions ?? this.mentions,
      threadId: threadId ?? this.threadId,
      readBy: readBy ?? this.readBy,
      deliveredTo: deliveredTo ?? this.deliveredTo,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedFor: deletedFor ?? this.deletedFor,
      systemData: systemData ?? this.systemData,
      priority: priority ?? this.priority,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get formatted time
  String get formattedTime {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      if (difference.inDays == 1) {
        return 'Yesterday ${DateFormat('HH:mm').format(createdAt)}';
      } else if (difference.inDays < 7) {
        return DateFormat('EEEE HH:mm').format(createdAt);
      } else {
        return DateFormat('MMM d, HH:mm').format(createdAt);
      }
    } else {
      return DateFormat('HH:mm').format(createdAt);
    }
  }

  /// Get short time format
  String get shortTime {
    return DateFormat('HH:mm').format(createdAt);
  }

  /// Check if message is read by user
  bool isReadByUser(String userId) {
    return readBy.any((receipt) => receipt.userId == userId);
  }

  /// Check if message is delivered to user
  bool isDeliveredToUser(String userId) {
    return deliveredTo.any((receipt) => receipt.userId == userId);
  }

  /// Check if message is from current user
  bool isFromCurrentUser(String currentUserId) {
    return senderId == currentUserId;
  }

  /// Check if message is deleted for user
  bool isDeletedForUser(String userId) {
    return isDeleted || deletedFor.contains(userId);
  }

  /// Get grouped reactions
  Map<String, List<MessageReaction>> get groupedReactions {
    final Map<String, List<MessageReaction>> grouped = {};
    for (final reaction in reactions) {
      if (!grouped.containsKey(reaction.emoji)) {
        grouped[reaction.emoji] = [];
      }
      grouped[reaction.emoji]!.add(reaction);
    }
    return grouped;
  }

  /// Get display content based on type
  String get displayContent {
    if (isDeleted) return 'This message was deleted';

    switch (type) {
      case MessageType.text:
        return content ?? '';
      case MessageType.image:
        return '📷 Photo';
      case MessageType.video:
        return '🎥 Video';
      case MessageType.audio:
        return '🎵 Audio';
      case MessageType.lottie:
        return '✨ Animation';
      case MessageType.svga:
        return '🎬 Animation';
      case MessageType.file:
        return '📎 ${media?.fileName ?? 'File'}';
      case MessageType.location:
        return '📍 ${location?.name ?? 'Location'}';
      case MessageType.contact:
        return '👤 ${contact?.name ?? 'Contact'}';
      case MessageType.system:
        return content ?? 'System message';
    }
  }

  /// Check if message has media
  bool get hasMedia {
    return [
      MessageType.image,
      MessageType.video,
      MessageType.audio,
      MessageType.lottie,
      MessageType.svga,
      MessageType.file,
    ].contains(type);
  }

  /// Check if message is expired
  bool get isExpired {
    return expiresAt != null && DateTime.now().isAfter(expiresAt!);
  }
}
