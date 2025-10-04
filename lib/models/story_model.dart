import 'package:flutter/material.dart';

enum StoryMediaType { text, image, video, audio }

enum StoryReactionType { like, love, haha, wow, sad, angry, fire, clap }

enum StoryPrivacyType { public, friends, closeFriends, custom }

class StoryTextStyle {
  final Color backgroundColor;
  final Color textColor;
  final String fontFamily;
  final double fontSize;
  final FontWeight fontWeight;
  final TextAlign textAlign;
  final String? backgroundGradient;
  final String? backgroundImage;

  const StoryTextStyle({
    this.backgroundColor = Colors.black,
    this.textColor = Colors.white,
    this.fontFamily = 'Roboto',
    this.fontSize = 24.0,
    this.fontWeight = FontWeight.normal,
    this.textAlign = TextAlign.center,
    this.backgroundGradient,
    this.backgroundImage,
  });

  factory StoryTextStyle.fromJson(Map<String, dynamic> json) {
    return StoryTextStyle(
      backgroundColor: Color(json['backgroundColor'] ?? 0xff000000),
      textColor: Color(json['textColor'] ?? 0xffffffff),
      fontFamily: json['fontFamily'] ?? 'Roboto',
      fontSize: (json['fontSize'] ?? 24.0).toDouble(),
      fontWeight: _fontWeightFromIndex(json['fontWeight'] ?? 4),
      textAlign: _textAlignFromIndex(json['textAlign'] ?? 1),
      backgroundGradient: json['backgroundGradient'],
      backgroundImage: json['backgroundImage'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'backgroundColor': backgroundColor.value,
      'textColor': textColor.value,
      'fontFamily': fontFamily,
      'fontSize': fontSize,
      'fontWeight': _fontWeightToIndex(fontWeight),
      'textAlign': _textAlignToIndex(textAlign),
      'backgroundGradient': backgroundGradient,
      'backgroundImage': backgroundImage,
    };
  }

  static FontWeight _fontWeightFromIndex(int index) {
    const weights = [
      FontWeight.w100,
      FontWeight.w200,
      FontWeight.w300,
      FontWeight.w400,
      FontWeight.w500,
      FontWeight.w600,
      FontWeight.w700,
      FontWeight.w800,
      FontWeight.w900,
    ];
    return weights[index.clamp(0, weights.length - 1)];
  }

  static int _fontWeightToIndex(FontWeight weight) {
    const weights = [
      FontWeight.w100,
      FontWeight.w200,
      FontWeight.w300,
      FontWeight.w400,
      FontWeight.w500,
      FontWeight.w600,
      FontWeight.w700,
      FontWeight.w800,
      FontWeight.w900,
    ];
    return weights.indexOf(weight).clamp(0, weights.length - 1);
  }

  static TextAlign _textAlignFromIndex(int index) {
    const aligns = [
      TextAlign.left,
      TextAlign.center,
      TextAlign.right,
      TextAlign.justify,
    ];
    return aligns[index.clamp(0, aligns.length - 1)];
  }

  static int _textAlignToIndex(TextAlign align) {
    const aligns = [
      TextAlign.left,
      TextAlign.center,
      TextAlign.right,
      TextAlign.justify,
    ];
    return aligns.indexOf(align).clamp(0, aligns.length - 1);
  }
}

class StoryReaction {
  final String id;
  final String userId;
  final String username;
  final String? userAvatar;
  final StoryReactionType type;
  final DateTime createdAt;

  const StoryReaction({
    required this.id,
    required this.userId,
    required this.username,
    this.userAvatar,
    required this.type,
    required this.createdAt,
  });

  factory StoryReaction.fromJson(Map<String, dynamic> json) {
    return StoryReaction(
      id: json['_id'] ?? '',
      userId: json['userId'] ?? '',
      username: json['username'] ?? '',
      userAvatar: json['userAvatar'],
      type: _reactionTypeFromString(json['type'] ?? 'like'),
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'userId': userId,
      'username': username,
      'userAvatar': userAvatar,
      'type': type.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static StoryReactionType _reactionTypeFromString(String type) {
    switch (type) {
      case 'like':
        return StoryReactionType.like;
      case 'love':
        return StoryReactionType.love;
      case 'haha':
        return StoryReactionType.haha;
      case 'wow':
        return StoryReactionType.wow;
      case 'sad':
        return StoryReactionType.sad;
      case 'angry':
        return StoryReactionType.angry;
      case 'fire':
        return StoryReactionType.fire;
      case 'clap':
        return StoryReactionType.clap;
      default:
        return StoryReactionType.like;
    }
  }
}

class StoryViewer {
  final String userId;
  final String username;
  final String? userAvatar;
  final DateTime viewedAt;

  const StoryViewer({
    required this.userId,
    required this.username,
    this.userAvatar,
    required this.viewedAt,
  });

  factory StoryViewer.fromJson(Map<String, dynamic> json) {
    return StoryViewer(
      userId: json['userId'] ?? '',
      username: json['username'] ?? '',
      userAvatar: json['userAvatar'],
      viewedAt: DateTime.parse(
        json['viewedAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'userAvatar': userAvatar,
      'viewedAt': viewedAt.toIso8601String(),
    };
  }
}

class StoryModel {
  final String id;
  final String userId;
  final String username;
  final String? userAvatar;
  final StoryMediaType mediaType;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final String? textContent;
  final StoryTextStyle? textStyle;
  final Duration? duration;
  final String? caption;
  final List<String> mentions;
  final List<String> hashtags;
  final StoryPrivacyType privacy;
  final List<String> customViewers;
  final List<StoryViewer> viewers;
  final List<StoryReaction> reactions;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isActive;
  final bool allowReplies;
  final bool allowReactions;
  final bool allowScreenshot;
  final Map<String, dynamic> metadata;

  const StoryModel({
    required this.id,
    required this.userId,
    required this.username,
    this.userAvatar,
    required this.mediaType,
    this.mediaUrl,
    this.thumbnailUrl,
    this.textContent,
    this.textStyle,
    this.duration,
    this.caption,
    this.mentions = const [],
    this.hashtags = const [],
    this.privacy = StoryPrivacyType.public,
    this.customViewers = const [],
    this.viewers = const [],
    this.reactions = const [],
    required this.createdAt,
    required this.expiresAt,
    this.isActive = true,
    this.allowReplies = true,
    this.allowReactions = true,
    this.allowScreenshot = true,
    this.metadata = const {},
  });

  // Helper getters
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isActiveAndValid => isActive && !isExpired;
  int get viewCount => viewers.length;
  int get reactionCount => reactions.length;

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  String get formattedDuration {
    if (duration == null) return '';
    final minutes = duration!.inMinutes;
    final seconds = duration!.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Helper methods
  bool hasViewedBy(String userId) {
    return viewers.any((viewer) => viewer.userId == userId);
  }

  bool hasReactedBy(String userId) {
    return reactions.any((reaction) => reaction.userId == userId);
  }

  StoryReaction? getReactionBy(String userId) {
    try {
      return reactions.firstWhere((reaction) => reaction.userId == userId);
    } catch (e) {
      return null;
    }
  }

  Map<StoryReactionType, List<StoryReaction>> get groupedReactions {
    final Map<StoryReactionType, List<StoryReaction>> grouped = {};

    for (final reaction in reactions) {
      if (!grouped.containsKey(reaction.type)) {
        grouped[reaction.type] = [];
      }
      grouped[reaction.type]!.add(reaction);
    }

    return grouped;
  }

  factory StoryModel.fromJson(Map<String, dynamic> json) {
    return StoryModel(
      id: json['_id'] ?? '',
      userId: json['userId'] ?? '',
      username: json['username'] ?? '',
      userAvatar: json['userAvatar'],
      mediaType: _mediaTypeFromString(json['mediaType'] ?? 'text'),
      mediaUrl: json['mediaUrl'],
      thumbnailUrl: json['thumbnailUrl'],
      textContent: json['textContent'],
      textStyle:
          json['textStyle'] != null
              ? StoryTextStyle.fromJson(json['textStyle'])
              : null,
      duration:
          json['duration'] != null
              ? Duration(milliseconds: (json['duration'] as num).toInt())
              : null,
      caption: json['caption'],
      mentions: List<String>.from(json['mentions'] ?? []),
      hashtags: List<String>.from(json['hashtags'] ?? []),
      privacy: _privacyTypeFromString(json['privacy'] ?? 'public'),
      customViewers: List<String>.from(json['customViewers'] ?? []),
      viewers:
          (json['viewers'] as List<dynamic>?)
              ?.map((v) => StoryViewer.fromJson(v))
              .toList() ??
          [],
      reactions:
          (json['reactions'] as List<dynamic>?)
              ?.map((r) => StoryReaction.fromJson(r))
              .toList() ??
          [],
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      expiresAt: DateTime.parse(
        json['expiresAt'] ??
            DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
      ),
      isActive: json['isActive'] ?? true,
      allowReplies: json['allowReplies'] ?? true,
      allowReactions: json['allowReactions'] ?? true,
      allowScreenshot: json['allowScreenshot'] ?? true,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'userId': userId,
      'username': username,
      'userAvatar': userAvatar,
      'mediaType': mediaType.name,
      'mediaUrl': mediaUrl,
      'thumbnailUrl': thumbnailUrl,
      'textContent': textContent,
      'textStyle': textStyle?.toJson(),
      'duration': duration?.inMilliseconds,
      'caption': caption,
      'mentions': mentions,
      'hashtags': hashtags,
      'privacy': privacy.name,
      'customViewers': customViewers,
      'viewers': viewers.map((v) => v.toJson()).toList(),
      'reactions': reactions.map((r) => r.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'isActive': isActive,
      'allowReplies': allowReplies,
      'allowReactions': allowReactions,
      'allowScreenshot': allowScreenshot,
      'metadata': metadata,
    };
  }

  StoryModel copyWith({
    String? id,
    String? userId,
    String? username,
    String? userAvatar,
    StoryMediaType? mediaType,
    String? mediaUrl,
    String? thumbnailUrl,
    String? textContent,
    StoryTextStyle? textStyle,
    Duration? duration,
    String? caption,
    List<String>? mentions,
    List<String>? hashtags,
    StoryPrivacyType? privacy,
    List<String>? customViewers,
    List<StoryViewer>? viewers,
    List<StoryReaction>? reactions,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? isActive,
    bool? allowReplies,
    bool? allowReactions,
    bool? allowScreenshot,
    Map<String, dynamic>? metadata,
  }) {
    return StoryModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      userAvatar: userAvatar ?? this.userAvatar,
      mediaType: mediaType ?? this.mediaType,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      textContent: textContent ?? this.textContent,
      textStyle: textStyle ?? this.textStyle,
      duration: duration ?? this.duration,
      caption: caption ?? this.caption,
      mentions: mentions ?? this.mentions,
      hashtags: hashtags ?? this.hashtags,
      privacy: privacy ?? this.privacy,
      customViewers: customViewers ?? this.customViewers,
      viewers: viewers ?? this.viewers,
      reactions: reactions ?? this.reactions,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isActive: isActive ?? this.isActive,
      allowReplies: allowReplies ?? this.allowReplies,
      allowReactions: allowReactions ?? this.allowReactions,
      allowScreenshot: allowScreenshot ?? this.allowScreenshot,
      metadata: metadata ?? this.metadata,
    );
  }

  static StoryMediaType _mediaTypeFromString(String type) {
    switch (type) {
      case 'text':
        return StoryMediaType.text;
      case 'image':
        return StoryMediaType.image;
      case 'video':
        return StoryMediaType.video;
      case 'audio':
        return StoryMediaType.audio;
      default:
        return StoryMediaType.text;
    }
  }

  static StoryPrivacyType _privacyTypeFromString(String privacy) {
    switch (privacy) {
      case 'public':
        return StoryPrivacyType.public;
      case 'friends':
        return StoryPrivacyType.friends;
      case 'closeFriends':
        return StoryPrivacyType.closeFriends;
      case 'custom':
        return StoryPrivacyType.custom;
      default:
        return StoryPrivacyType.public;
    }
  }
}

// Story feed model for grouped stories by user
class StoryFeedItem {
  final String userId;
  final String username;
  final String? userAvatar;
  final List<StoryModel> stories;
  final DateTime lastStoryTime;
  final bool hasUnviewedStories;

  const StoryFeedItem({
    required this.userId,
    required this.username,
    this.userAvatar,
    required this.stories,
    required this.lastStoryTime,
    this.hasUnviewedStories = false,
  });

  factory StoryFeedItem.fromJson(Map<String, dynamic> json) {
    return StoryFeedItem(
      userId: json['_id'] ?? '',
      username: json['username'] ?? 'User',
      userAvatar: json['userAvatar'],
      stories:
          (json['stories'] as List<dynamic>?)
              ?.map((s) => StoryModel.fromJson(s))
              .toList() ??
          [],
      lastStoryTime: DateTime.parse(
        json['lastStoryTime'] ?? DateTime.now().toIso8601String(),
      ),
      hasUnviewedStories:
          json['hasUnviewedStories'] is bool
              ? json['hasUnviewedStories']
              : (json['hasUnviewedStories'] ?? 0) > 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': userId,
      'username': username,
      'userAvatar': userAvatar,
      'stories': stories.map((s) => s.toJson()).toList(),
      'lastStoryTime': lastStoryTime.toIso8601String(),
      'hasUnviewedStories': hasUnviewedStories ? 1 : 0,
    };
  }
}
