import 'user_model.dart';

/// LiveMessage Model for MongoDB backend
/// Handles all messages in live streams
class LiveMessageModel {
  final String id;
  final String authorId;
  final UserModel? author;
  final String? authorName; // fallback name when full author object missing
  final String liveStreamId;
  final String message;
  final String messageType;

  // Gift Information (if messageType is GIFT)
  final String? giftLiveId;
  final String? giftId;

  // Co-Host Information (if messageType is HOST)
  final bool coHostAvailable;
  final String? coHostAuthorId;
  final int? coHostAuthorUid;

  final DateTime createdAt;
  final DateTime updatedAt;

  // Message Types
  static const String messageTypeComment = 'COMMENT';
  static const String messageTypeFollow = 'FOLLOW';
  static const String messageTypeGift = 'GIFT';
  static const String messageTypeSystem = 'SYSTEM';
  static const String messageTypeJoin = 'JOIN';
  static const String messageTypeCoHost = 'HOST';
  static const String messageTypeLeave = 'LEAVE';
  static const String messageTypeRemoved = 'REMOVED';
  static const String messageTypePlatform = 'PLATFORM';

  const LiveMessageModel({
    required this.id,
    required this.authorId,
    this.author,
    this.authorName,
    required this.liveStreamId,
    this.message = '',
    required this.messageType,
    this.giftLiveId,
    this.giftId,
    this.coHostAvailable = false,
    this.coHostAuthorId,
    this.coHostAuthorUid,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Factory for creating LiveMessageModel from JSON
  factory LiveMessageModel.fromJson(Map<String, dynamic> json) {
    return LiveMessageModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      authorId: json['authorId'] as String? ?? '',
      author: json['author'] != null && json['author'] is Map
          ? UserModel.fromJson(json['author'] as Map<String, dynamic>)
          : null,
      authorName: json['authorName'] as String? ??
          json['author_name'] as String? ??
          json['username'] as String?,
      liveStreamId: json['liveStreamId'] as String? ?? '',
      message: json['message'] as String? ?? '',
      messageType: json['messageType'] as String? ?? messageTypeComment,
      giftLiveId: json['giftLiveId'] as String?,
      giftId: json['giftId'] as String?,
      coHostAvailable: json['coHostAvailable'] as bool? ?? false,
      coHostAuthorId: json['coHostAuthorId'] as String?,
      coHostAuthorUid: (json['coHostAuthorUid'] as num?)?.toInt(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'authorId': authorId,
      if (authorName != null) 'authorName': authorName,
      'liveStreamId': liveStreamId,
      'message': message,
      'messageType': messageType,
      if (giftLiveId != null) 'giftLiveId': giftLiveId,
      if (giftId != null) 'giftId': giftId,
      'coHostAvailable': coHostAvailable,
      if (coHostAuthorId != null) 'coHostAuthorId': coHostAuthorId,
      if (coHostAuthorUid != null) 'coHostAuthorUid': coHostAuthorUid,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Helper getters
  bool get isComment => messageType == messageTypeComment;
  bool get isGift => messageType == messageTypeGift;
  bool get isSystem => messageType == messageTypeSystem;
  bool get isJoin => messageType == messageTypeJoin;
  bool get isLeave => messageType == messageTypeLeave;
  bool get isFollow => messageType == messageTypeFollow;
  bool get isCoHost => messageType == messageTypeCoHost;
  bool get isRemoved => messageType == messageTypeRemoved;
  bool get isPlatform => messageType == messageTypePlatform;

  /// CopyWith method
  LiveMessageModel copyWith({
    String? id,
    String? authorId,
    UserModel? author,
    String? authorName,
    String? liveStreamId,
    String? message,
    String? messageType,
    String? giftLiveId,
    String? giftId,
    bool? coHostAvailable,
    String? coHostAuthorId,
    int? coHostAuthorUid,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LiveMessageModel(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      author: author ?? this.author,
      authorName: authorName ?? this.authorName,
      liveStreamId: liveStreamId ?? this.liveStreamId,
      message: message ?? this.message,
      messageType: messageType ?? this.messageType,
      giftLiveId: giftLiveId ?? this.giftLiveId,
      giftId: giftId ?? this.giftId,
      coHostAvailable: coHostAvailable ?? this.coHostAvailable,
      coHostAuthorId: coHostAuthorId ?? this.coHostAuthorId,
      coHostAuthorUid: coHostAuthorUid ?? this.coHostAuthorUid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

