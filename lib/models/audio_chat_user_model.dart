import 'user_model.dart';

/// AudioChatUser Model for MongoDB backend
/// Handles users in audio/video party rooms (seats/chairs)
class AudioChatUserModel {
  final String id;
  final String liveStreamId;
  final String? joinedUserId;
  final int? joinedUserUid;
  final UserModel? joinedUser;
  final int seatIndex;
  final bool canTalk;
  final bool enabledVideo;
  final bool enabledAudio;
  final bool leftRoom;
  final List<String> userSelfMutedAudio;
  final List<String> usersMutedByHostAudio;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AudioChatUserModel({
    required this.id,
    required this.liveStreamId,
    this.joinedUserId,
    this.joinedUserUid,
    this.joinedUser,
    required this.seatIndex,
    this.canTalk = false,
    this.enabledVideo = false,
    this.enabledAudio = true,
    this.leftRoom = false,
    this.userSelfMutedAudio = const [],
    this.usersMutedByHostAudio = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  /// Factory for creating AudioChatUserModel from JSON
  factory AudioChatUserModel.fromJson(Map<String, dynamic> json) {
    return AudioChatUserModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      liveStreamId: json['liveStreamId'] as String? ?? '',
      joinedUserId: json['joinedUserId'] as String?,
      joinedUserUid: (json['joinedUserUid'] as num?)?.toInt(),
      joinedUser: json['joinedUser'] != null && json['joinedUser'] is Map
          ? UserModel.fromJson(json['joinedUser'] as Map<String, dynamic>)
          : null,
      seatIndex: (json['seatIndex'] as num?)?.toInt() ?? 0,
      canTalk: json['canTalk'] as bool? ?? false,
      enabledVideo: json['enabledVideo'] as bool? ?? false,
      enabledAudio: json['enabledAudio'] as bool? ?? true,
      leftRoom: json['leftRoom'] as bool? ?? false,
      userSelfMutedAudio: (json['userSelfMutedAudio'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      usersMutedByHostAudio: (json['usersMutedByHostAudio'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
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
      'liveStreamId': liveStreamId,
      if (joinedUserId != null) 'joinedUserId': joinedUserId,
      if (joinedUserUid != null) 'joinedUserUid': joinedUserUid,
      'seatIndex': seatIndex,
      'canTalk': canTalk,
      'enabledVideo': enabledVideo,
      'enabledAudio': enabledAudio,
      'leftRoom': leftRoom,
      'userSelfMutedAudio': userSelfMutedAudio,
      'usersMutedByHostAudio': usersMutedByHostAudio,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Helper getters
  bool get isOccupied => joinedUserId != null && !leftRoom;
  bool get isEmpty => joinedUserId == null || leftRoom;
  bool get isMuted =>
      userSelfMutedAudio.isNotEmpty ||
      usersMutedByHostAudio.isNotEmpty ||
      !enabledAudio;
  bool get isMutedBySelf => userSelfMutedAudio.isNotEmpty;
  bool get isMutedByHost => usersMutedByHostAudio.isNotEmpty;

  /// CopyWith method
  AudioChatUserModel copyWith({
    String? id,
    String? liveStreamId,
    String? joinedUserId,
    int? joinedUserUid,
    UserModel? joinedUser,
    int? seatIndex,
    bool? canTalk,
    bool? enabledVideo,
    bool? enabledAudio,
    bool? leftRoom,
    List<String>? userSelfMutedAudio,
    List<String>? usersMutedByHostAudio,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AudioChatUserModel(
      id: id ?? this.id,
      liveStreamId: liveStreamId ?? this.liveStreamId,
      joinedUserId: joinedUserId ?? this.joinedUserId,
      joinedUserUid: joinedUserUid ?? this.joinedUserUid,
      joinedUser: joinedUser ?? this.joinedUser,
      seatIndex: seatIndex ?? this.seatIndex,
      canTalk: canTalk ?? this.canTalk,
      enabledVideo: enabledVideo ?? this.enabledVideo,
      enabledAudio: enabledAudio ?? this.enabledAudio,
      leftRoom: leftRoom ?? this.leftRoom,
      userSelfMutedAudio: userSelfMutedAudio ?? this.userSelfMutedAudio,
      usersMutedByHostAudio:
          usersMutedByHostAudio ?? this.usersMutedByHostAudio,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

