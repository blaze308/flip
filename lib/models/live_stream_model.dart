import 'user_model.dart';

/// LiveStream Model for MongoDB backend
/// Handles all types of live streaming: regular live, party live, audio party, PK battles
class LiveStreamModel {
  final String id;
  final String authorId;
  final int authorUid; // Agora/Zego UID
  final UserModel? author;

  // Live Stream Type
  final String liveType; // "live", "party", "audio", "battle"
  final String liveSubType; // "Talking", "Singing", "Dancing", "Friends", "Games"

  // Streaming Status
  final bool streaming;
  final String streamingChannel;

  // Title and Description
  final String title;
  final String streamingTags;

  // Privacy Settings
  final bool private;
  final List<String> privateViewersId;
  final String? privateLivePriceId;

  // Viewers and Statistics
  final int viewersCount;
  final List<String> viewersId;
  final List<int> viewersUid;
  final List<String> reachedPeople;
  final List<String> likes;

  // Diamonds/Coins
  final int streamingDiamonds;
  final int authorTotalDiamonds;
  final int giftsTotal;

  // Co-Host/Party Features
  final bool coHostAvailable;
  final String? coHostAuthorId;
  final int? coHostAuthorUid;
  final List<int> coHostUID;

  // Party Live Settings
  final int numberOfChairs; // 4, 6, or 9 seats
  final String partyType; // "video" or "audio"
  final String? partyTheme; // URL to theme image
  final List<int> invitedPartyUid;

  // User Management
  final List<String> removedUsersId;
  final List<String> mutedUsersId;
  final List<String> unMutedUsersId;
  final List<String> userSelfMutedAudio;

  // PK Battle Features
  final bool isPKBattle;
  final String? pkRequesterId;
  final String? pkReceiverId;

  // Invitation System
  final String? authorInvitedId;
  final int? authorInvitedUid;
  final String? invitedBroadCasterId;
  final bool invitationAccepted;
  final String? invitationLivePendingId;

  // Followers gained during live
  final List<String> newFollowers;

  // Admin Controls
  final bool endByAdmin;

  // First Live Flag
  final bool firstLive;

  // Streaming Time
  final String streamingTime;

  // Thumbnail/Cover Image
  final String? image;

  // Location
  final Map<String, dynamic>? geoPoint;

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  const LiveStreamModel({
    required this.id,
    required this.authorId,
    required this.authorUid,
    this.author,
    this.liveType = 'live',
    this.liveSubType = 'Talking',
    this.streaming = true,
    required this.streamingChannel,
    this.title = '',
    this.streamingTags = '',
    this.private = false,
    this.privateViewersId = const [],
    this.privateLivePriceId,
    this.viewersCount = 0,
    this.viewersId = const [],
    this.viewersUid = const [],
    this.reachedPeople = const [],
    this.likes = const [],
    this.streamingDiamonds = 0,
    this.authorTotalDiamonds = 0,
    this.giftsTotal = 0,
    this.coHostAvailable = false,
    this.coHostAuthorId,
    this.coHostAuthorUid,
    this.coHostUID = const [],
    this.numberOfChairs = 6,
    this.partyType = 'video',
    this.partyTheme,
    this.invitedPartyUid = const [],
    this.removedUsersId = const [],
    this.mutedUsersId = const [],
    this.unMutedUsersId = const [],
    this.userSelfMutedAudio = const [],
    this.isPKBattle = false,
    this.pkRequesterId,
    this.pkReceiverId,
    this.authorInvitedId,
    this.authorInvitedUid,
    this.invitedBroadCasterId,
    this.invitationAccepted = false,
    this.invitationLivePendingId,
    this.newFollowers = const [],
    this.endByAdmin = false,
    this.firstLive = false,
    this.streamingTime = '00:00',
    this.image,
    this.geoPoint,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Factory for creating LiveStreamModel from JSON (MongoDB format)
  factory LiveStreamModel.fromJson(Map<String, dynamic> json) {
    return LiveStreamModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      authorId: json['authorId'] as String? ?? '',
      authorUid: (json['authorUid'] as num?)?.toInt() ?? 0,
      author: json['author'] != null && json['author'] is Map
          ? UserModel.fromJson(json['author'] as Map<String, dynamic>)
          : null,
      liveType: json['liveType'] as String? ?? 'live',
      liveSubType: json['liveSubType'] as String? ?? 'Talking',
      streaming: json['streaming'] as bool? ?? true,
      streamingChannel: json['streamingChannel'] as String? ?? '',
      title: json['title'] as String? ?? '',
      streamingTags: json['streamingTags'] as String? ?? '',
      private: json['private'] as bool? ?? false,
      privateViewersId: (json['privateViewersId'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      privateLivePriceId: json['privateLivePrice']?.toString(),
      viewersCount: (json['viewersCount'] as num?)?.toInt() ?? 0,
      viewersId: (json['viewersId'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      viewersUid: (json['viewersUid'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          [],
      reachedPeople: (json['reachedPeople'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      likes: (json['likes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      streamingDiamonds: (json['streamingDiamonds'] as num?)?.toInt() ?? 0,
      authorTotalDiamonds: (json['authorTotalDiamonds'] as num?)?.toInt() ?? 0,
      giftsTotal: (json['giftsTotal'] as num?)?.toInt() ?? 0,
      coHostAvailable: json['coHostAvailable'] as bool? ?? false,
      coHostAuthorId: json['coHostAuthor']?.toString(),
      coHostAuthorUid: (json['coHostAuthorUid'] as num?)?.toInt(),
      coHostUID: (json['coHostUID'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          [],
      numberOfChairs: (json['numberOfChairs'] as num?)?.toInt() ?? 6,
      partyType: json['partyType'] as String? ?? 'video',
      partyTheme: json['partyTheme'] as String?,
      invitedPartyUid: (json['invitedPartyUid'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          [],
      removedUsersId: (json['removedUsersId'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      mutedUsersId: (json['mutedUsersId'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      unMutedUsersId: (json['unMutedUsersId'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      userSelfMutedAudio: (json['userSelfMutedAudio'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      isPKBattle: json['isPKBattle'] as bool? ?? false,
      pkRequesterId: json['pkRequester']?.toString(),
      pkReceiverId: json['pkReceiver']?.toString(),
      authorInvitedId: json['authorInvited']?.toString(),
      authorInvitedUid: (json['authorInvitedUid'] as num?)?.toInt(),
      invitedBroadCasterId: json['invitedBroadCasterId'] as String?,
      invitationAccepted: json['invitationAccepted'] as bool? ?? false,
      invitationLivePendingId: json['invitationLivePending']?.toString(),
      newFollowers: (json['newFollowers'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      endByAdmin: json['endByAdmin'] as bool? ?? false,
      firstLive: json['firstLive'] as bool? ?? false,
      streamingTime: json['streamingTime'] as String? ?? '00:00',
      image: json['image'] as String?,
      geoPoint: json['geoPoint'] as Map<String, dynamic>?,
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
      'authorUid': authorUid,
      'liveType': liveType,
      'liveSubType': liveSubType,
      'streaming': streaming,
      'streamingChannel': streamingChannel,
      'title': title,
      'streamingTags': streamingTags,
      'private': private,
      'privateViewersId': privateViewersId,
      'privateLivePriceId': privateLivePriceId,
      'viewersCount': viewersCount,
      'viewersId': viewersId,
      'viewersUid': viewersUid,
      'reachedPeople': reachedPeople,
      'likes': likes,
      'streamingDiamonds': streamingDiamonds,
      'authorTotalDiamonds': authorTotalDiamonds,
      'giftsTotal': giftsTotal,
      'coHostAvailable': coHostAvailable,
      'coHostAuthorId': coHostAuthorId,
      'coHostAuthorUid': coHostAuthorUid,
      'coHostUID': coHostUID,
      'numberOfChairs': numberOfChairs,
      'partyType': partyType,
      'partyTheme': partyTheme,
      'invitedPartyUid': invitedPartyUid,
      'removedUsersId': removedUsersId,
      'mutedUsersId': mutedUsersId,
      'unMutedUsersId': unMutedUsersId,
      'userSelfMutedAudio': userSelfMutedAudio,
      'isPKBattle': isPKBattle,
      'pkRequesterId': pkRequesterId,
      'pkReceiverId': pkReceiverId,
      'authorInvitedId': authorInvitedId,
      'authorInvitedUid': authorInvitedUid,
      'invitedBroadCasterId': invitedBroadCasterId,
      'invitationAccepted': invitationAccepted,
      'invitationLivePendingId': invitationLivePendingId,
      'newFollowers': newFollowers,
      'endByAdmin': endByAdmin,
      'firstLive': firstLive,
      'streamingTime': streamingTime,
      'image': image,
      'geoPoint': geoPoint,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Helper getters
  bool get isLive => streaming && !endByAdmin;
  bool get isParty => liveType == 'party' || liveType == 'audio';
  bool get isAudioParty => liveType == 'audio';
  bool get isVideoParty => liveType == 'party' && partyType == 'video';
  bool get isBattle => liveType == 'battle' || isPKBattle;
  int get liveViewersCount => viewersId.length;

  /// CopyWith method for updating fields
  LiveStreamModel copyWith({
    String? id,
    String? authorId,
    int? authorUid,
    UserModel? author,
    String? liveType,
    String? liveSubType,
    bool? streaming,
    String? streamingChannel,
    String? title,
    String? streamingTags,
    bool? private,
    List<String>? privateViewersId,
    String? privateLivePriceId,
    int? viewersCount,
    List<String>? viewersId,
    List<int>? viewersUid,
    List<String>? reachedPeople,
    List<String>? likes,
    int? streamingDiamonds,
    int? authorTotalDiamonds,
    int? giftsTotal,
    bool? coHostAvailable,
    String? coHostAuthorId,
    int? coHostAuthorUid,
    List<int>? coHostUID,
    int? numberOfChairs,
    String? partyType,
    String? partyTheme,
    List<int>? invitedPartyUid,
    List<String>? removedUsersId,
    List<String>? mutedUsersId,
    List<String>? unMutedUsersId,
    List<String>? userSelfMutedAudio,
    bool? isPKBattle,
    String? pkRequesterId,
    String? pkReceiverId,
    String? authorInvitedId,
    int? authorInvitedUid,
    String? invitedBroadCasterId,
    bool? invitationAccepted,
    String? invitationLivePendingId,
    List<String>? newFollowers,
    bool? endByAdmin,
    bool? firstLive,
    String? streamingTime,
    String? image,
    Map<String, dynamic>? geoPoint,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LiveStreamModel(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorUid: authorUid ?? this.authorUid,
      author: author ?? this.author,
      liveType: liveType ?? this.liveType,
      liveSubType: liveSubType ?? this.liveSubType,
      streaming: streaming ?? this.streaming,
      streamingChannel: streamingChannel ?? this.streamingChannel,
      title: title ?? this.title,
      streamingTags: streamingTags ?? this.streamingTags,
      private: private ?? this.private,
      privateViewersId: privateViewersId ?? this.privateViewersId,
      privateLivePriceId: privateLivePriceId ?? this.privateLivePriceId,
      viewersCount: viewersCount ?? this.viewersCount,
      viewersId: viewersId ?? this.viewersId,
      viewersUid: viewersUid ?? this.viewersUid,
      reachedPeople: reachedPeople ?? this.reachedPeople,
      likes: likes ?? this.likes,
      streamingDiamonds: streamingDiamonds ?? this.streamingDiamonds,
      authorTotalDiamonds: authorTotalDiamonds ?? this.authorTotalDiamonds,
      giftsTotal: giftsTotal ?? this.giftsTotal,
      coHostAvailable: coHostAvailable ?? this.coHostAvailable,
      coHostAuthorId: coHostAuthorId ?? this.coHostAuthorId,
      coHostAuthorUid: coHostAuthorUid ?? this.coHostAuthorUid,
      coHostUID: coHostUID ?? this.coHostUID,
      numberOfChairs: numberOfChairs ?? this.numberOfChairs,
      partyType: partyType ?? this.partyType,
      partyTheme: partyTheme ?? this.partyTheme,
      invitedPartyUid: invitedPartyUid ?? this.invitedPartyUid,
      removedUsersId: removedUsersId ?? this.removedUsersId,
      mutedUsersId: mutedUsersId ?? this.mutedUsersId,
      unMutedUsersId: unMutedUsersId ?? this.unMutedUsersId,
      userSelfMutedAudio: userSelfMutedAudio ?? this.userSelfMutedAudio,
      isPKBattle: isPKBattle ?? this.isPKBattle,
      pkRequesterId: pkRequesterId ?? this.pkRequesterId,
      pkReceiverId: pkReceiverId ?? this.pkReceiverId,
      authorInvitedId: authorInvitedId ?? this.authorInvitedId,
      authorInvitedUid: authorInvitedUid ?? this.authorInvitedUid,
      invitedBroadCasterId: invitedBroadCasterId ?? this.invitedBroadCasterId,
      invitationAccepted: invitationAccepted ?? this.invitationAccepted,
      invitationLivePendingId:
          invitationLivePendingId ?? this.invitationLivePendingId,
      newFollowers: newFollowers ?? this.newFollowers,
      endByAdmin: endByAdmin ?? this.endByAdmin,
      firstLive: firstLive ?? this.firstLive,
      streamingTime: streamingTime ?? this.streamingTime,
      image: image ?? this.image,
      geoPoint: geoPoint ?? this.geoPoint,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

