import 'package:flutter/material.dart';

enum PostType { text, image, video }

class PostModel {
  final String id;
  final String userId;
  final String username;
  final String? userAvatar;
  final DateTime createdAt;
  final PostType type;
  final String? content; // Text content for text posts
  final List<String>? imageUrls; // Multiple images for image posts
  final String? videoUrl; // Video URL for video posts
  final String? videoThumbnail; // Thumbnail for video posts
  final int likes;
  final int comments;
  final int shares;
  final bool isLiked;
  final bool isBookmarked;
  final bool isHidden;
  final bool isFollowingUser;

  // Text post styling options
  final Color? backgroundColor;
  final Color? textColor;
  final String? fontFamily;
  final double? fontSize;
  final FontWeight? fontWeight;
  final TextAlign? textAlign;

  // Video post options
  final Duration? videoDuration;

  // Engagement metrics
  final List<String>? likedBy;
  final List<String>? tags;
  final String? location;

  PostModel({
    required this.id,
    required this.userId,
    required this.username,
    this.userAvatar,
    required this.createdAt,
    required this.type,
    this.content,
    this.imageUrls,
    this.videoUrl,
    this.videoThumbnail,
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
    this.isLiked = false,
    this.isBookmarked = false,
    this.isHidden = false,
    this.isFollowingUser = false,
    this.backgroundColor,
    this.textColor,
    this.fontFamily,
    this.fontSize,
    this.fontWeight,
    this.textAlign,
    this.videoDuration,
    this.likedBy,
    this.tags,
    this.location,
  });

  // Helper method to get time ago string
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  // Helper method to format video duration
  String get formattedDuration {
    if (videoDuration == null) return '';
    final minutes = videoDuration!.inMinutes;
    final seconds = videoDuration!.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Copy with method for updating post data
  PostModel copyWith({
    String? id,
    String? userId,
    String? username,
    String? userAvatar,
    DateTime? createdAt,
    PostType? type,
    String? content,
    List<String>? imageUrls,
    String? videoUrl,
    String? videoThumbnail,
    int? likes,
    int? comments,
    int? shares,
    bool? isLiked,
    bool? isBookmarked,
    bool? isHidden,
    bool? isFollowingUser,
    Color? backgroundColor,
    Color? textColor,
    String? fontFamily,
    double? fontSize,
    FontWeight? fontWeight,
    TextAlign? textAlign,
    Duration? videoDuration,
    List<String>? likedBy,
    List<String>? tags,
    String? location,
  }) {
    return PostModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      userAvatar: userAvatar ?? this.userAvatar,
      createdAt: createdAt ?? this.createdAt,
      type: type ?? this.type,
      content: content ?? this.content,
      imageUrls: imageUrls ?? this.imageUrls,
      videoUrl: videoUrl ?? this.videoUrl,
      videoThumbnail: videoThumbnail ?? this.videoThumbnail,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      shares: shares ?? this.shares,
      isLiked: isLiked ?? this.isLiked,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      isHidden: isHidden ?? this.isHidden,
      isFollowingUser: isFollowingUser ?? this.isFollowingUser,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      textAlign: textAlign ?? this.textAlign,
      videoDuration: videoDuration ?? this.videoDuration,
      likedBy: likedBy ?? this.likedBy,
      tags: tags ?? this.tags,
      location: location ?? this.location,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'username': username,
      'userAvatar': userAvatar,
      'createdAt': createdAt.toIso8601String(),
      'type': type.toString().split('.').last,
      'content': content,
      'imageUrls': imageUrls,
      'videoUrl': videoUrl,
      'videoThumbnail': videoThumbnail,
      'likes': likes,
      'comments': comments,
      'shares': shares,
      'isLiked': isLiked,
      'isBookmarked': isBookmarked,
      'isHidden': isHidden,
      'isFollowingUser': isFollowingUser,
      'backgroundColor': backgroundColor?.value,
      'textColor': textColor?.value,
      'fontFamily': fontFamily,
      'fontSize': fontSize,
      'fontWeight': fontWeight?.index,
      'textAlign': textAlign?.index,
      'videoDuration': videoDuration?.inSeconds,
      'likedBy': likedBy,
      'tags': tags,
      'location': location,
    };
  }

  // Create from JSON
  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'],
      userId: json['userId'],
      username: json['username'],
      userAvatar: json['userAvatar'],
      createdAt: DateTime.parse(json['createdAt']),
      type: PostType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
      ),
      content: json['content'],
      imageUrls: json['imageUrls']?.cast<String>(),
      videoUrl: json['videoUrl'],
      videoThumbnail: json['videoThumbnail'],
      likes: json['likes'] ?? 0,
      comments: json['comments'] ?? 0,
      shares: json['shares'] ?? 0,
      isLiked: json['isLiked'] ?? false,
      isBookmarked: json['isBookmarked'] ?? false,
      isHidden: json['isHidden'] ?? false,
      isFollowingUser: json['isFollowingUser'] ?? false,
      backgroundColor:
          json['backgroundColor'] != null
              ? Color(json['backgroundColor'])
              : null,
      textColor: json['textColor'] != null ? Color(json['textColor']) : null,
      fontFamily: json['fontFamily'],
      fontSize: json['fontSize']?.toDouble(),
      fontWeight:
          json['fontWeight'] != null
              ? FontWeight.values[json['fontWeight']]
              : null,
      textAlign:
          json['textAlign'] != null
              ? TextAlign.values[json['textAlign']]
              : null,
      videoDuration:
          json['videoDuration'] != null
              ? Duration(seconds: json['videoDuration'])
              : null,
      likedBy: json['likedBy']?.cast<String>(),
      tags: json['tags']?.cast<String>(),
      location: json['location'],
    );
  }

  // Create from backend JSON (MongoDB format)
  factory PostModel.fromBackendJson(Map<String, dynamic> json) {
    // Parse text style if available
    Color? backgroundColor;
    Color? textColor;
    String? fontFamily;
    double? fontSize;
    FontWeight? fontWeight;
    TextAlign? textAlign;

    if (json['textStyle'] != null) {
      final textStyle = json['textStyle'] as Map<String, dynamic>;

      if (textStyle['backgroundColor'] != null) {
        final colorStr = textStyle['backgroundColor'] as String;
        backgroundColor = Color(
          int.parse(colorStr.substring(1), radix: 16) + 0xFF000000,
        );
      }

      if (textStyle['textColor'] != null) {
        final colorStr = textStyle['textColor'] as String;
        textColor = Color(
          int.parse(colorStr.substring(1), radix: 16) + 0xFF000000,
        );
      }

      fontFamily = textStyle['fontFamily'];
      fontSize = textStyle['fontSize']?.toDouble();

      if (textStyle['fontWeight'] != null) {
        final weightStr = textStyle['fontWeight'] as String;
        switch (weightStr) {
          case 'normal':
            fontWeight = FontWeight.normal;
            break;
          case 'bold':
            fontWeight = FontWeight.bold;
            break;
          case '100':
            fontWeight = FontWeight.w100;
            break;
          case '200':
            fontWeight = FontWeight.w200;
            break;
          case '300':
            fontWeight = FontWeight.w300;
            break;
          case '400':
            fontWeight = FontWeight.w400;
            break;
          case '500':
            fontWeight = FontWeight.w500;
            break;
          case '600':
            fontWeight = FontWeight.w600;
            break;
          case '700':
            fontWeight = FontWeight.w700;
            break;
          case '800':
            fontWeight = FontWeight.w800;
            break;
          case '900':
            fontWeight = FontWeight.w900;
            break;
        }
      }

      if (textStyle['textAlign'] != null) {
        final alignStr = textStyle['textAlign'] as String;
        switch (alignStr) {
          case 'left':
            textAlign = TextAlign.left;
            break;
          case 'center':
            textAlign = TextAlign.center;
            break;
          case 'right':
            textAlign = TextAlign.right;
            break;
          case 'justify':
            textAlign = TextAlign.justify;
            break;
        }
      }
    }

    // Handle userId - it might be a string or a populated user object
    String userId;
    String username = 'Unknown User';
    String? userAvatar;

    if (json['userId'] is String) {
      // userId is a string ID
      userId = json['userId'];
    } else if (json['userId'] is Map<String, dynamic>) {
      // userId is a populated user object
      final userObj = json['userId'] as Map<String, dynamic>;
      userId = userObj['_id'] ?? userObj['id'] ?? json['firebaseUid'];
      username =
          userObj['displayName'] ?? userObj['username'] ?? 'Unknown User';
      userAvatar = userObj['photoURL'] ?? userObj['profileImageUrl'];
    } else {
      // Fallback to firebaseUid
      userId = json['firebaseUid'] ?? '';
    }

    // Debug: Log parsing for posts with likes
    if ((json['likes'] ?? 0) > 0) {
      print('🔧 PostModel.fromBackendJson: Parsing post with likes');
      print('   - id: ${json['_id'] ?? json['id']}');
      print('   - likes: ${json['likes']}');
      print('   - isLiked from json: ${json['isLiked']}');
      print('   - isLiked type: ${json['isLiked'].runtimeType}');
    }

    return PostModel(
      id: json['_id'] ?? json['id'],
      userId: userId,
      username: username,
      userAvatar: userAvatar,
      createdAt: DateTime.parse(json['createdAt']),
      type: PostType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
      ),
      content: json['content'],
      imageUrls: json['imageUrls']?.cast<String>(),
      videoUrl: json['videoUrl'],
      videoThumbnail: json['videoThumbnail'],
      likes: json['likes'] ?? 0,
      comments: json['comments'] ?? 0,
      shares: json['shares'] ?? 0,
      isLiked: json['isLiked'] ?? false,
      isBookmarked: json['isBookmarked'] ?? false,
      isHidden: json['isHidden'] ?? false,
      isFollowingUser: json['isFollowingUser'] ?? false,
      backgroundColor: backgroundColor,
      textColor: textColor,
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      textAlign: textAlign,
      videoDuration:
          json['videoDuration'] != null
              ? Duration(seconds: json['videoDuration'])
              : null,
      likedBy: json['likedBy']?.cast<String>(),
      tags: json['tags']?.cast<String>(),
      location: json['location']?['name'],
    );
  }
}

// Sample data generator for testing
class PostSampleData {
  static List<PostModel> getSamplePosts() {
    return [
      // Text post with custom styling
      PostModel(
        id: '1',
        userId: 'user1',
        username: 'Alex Johnson',
        userAvatar: 'https://i.pravatar.cc/150?img=1',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        type: PostType.text,
        content:
            'Just finished an amazing workout! 💪 Feeling stronger every day. Remember, progress is progress no matter how small! 🔥',
        backgroundColor: const Color(0xFF4ECDC4),
        textColor: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        textAlign: TextAlign.center,
        likes: 124,
        comments: 23,
        shares: 8,
        isLiked: true,
        tags: ['fitness', 'motivation', 'workout'],
      ),

      // Image post with multiple images
      PostModel(
        id: '2',
        userId: 'user2',
        username: 'Sarah Chen',
        userAvatar: 'https://i.pravatar.cc/150?img=2',
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        type: PostType.image,
        content:
            'Beautiful sunset from my weekend hike! Nature never fails to amaze me 🌅',
        imageUrls: [
          'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800',
          'https://images.unsplash.com/photo-1469474968028-56623f02e42e?w=800',
          'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=800',
        ],
        likes: 89,
        comments: 15,
        shares: 12,
        isLiked: false,
        tags: ['nature', 'hiking', 'sunset'],
        location: 'Mountain View Trail',
      ),

      // Video post
      PostModel(
        id: '3',
        userId: 'user3',
        username: 'Mike Rodriguez',
        userAvatar: 'https://i.pravatar.cc/150?img=3',
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
        type: PostType.video,
        content: 'Quick cooking tutorial: Perfect pasta in 15 minutes! 🍝',
        videoUrl:
            'https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4',
        videoThumbnail:
            'https://images.unsplash.com/photo-1551782450-17144efb9c50?w=800',
        videoDuration: const Duration(minutes: 2, seconds: 30),
        likes: 256,
        comments: 42,
        shares: 18,
        isLiked: true,
        tags: ['cooking', 'tutorial', 'pasta'],
      ),

      // Another text post with different styling
      PostModel(
        id: '4',
        userId: 'user4',
        username: 'Emma Wilson',
        userAvatar: 'https://i.pravatar.cc/150?img=4',
        createdAt: DateTime.now().subtract(const Duration(hours: 12)),
        type: PostType.text,
        content:
            'Sometimes the smallest step in the right direction ends up being the biggest step of your life. Tip toe if you must, but take the step. ✨',
        backgroundColor: const Color(0xFF6C5CE7),
        textColor: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        textAlign: TextAlign.left,
        likes: 178,
        comments: 31,
        shares: 25,
        isLiked: false,
        tags: ['motivation', 'inspiration', 'life'],
      ),

      // Image post with single image
      PostModel(
        id: '5',
        userId: 'user5',
        username: 'David Kim',
        userAvatar: 'https://i.pravatar.cc/150?img=5',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        type: PostType.image,
        content:
            'New coffee shop discovery! ☕ The latte art here is incredible',
        imageUrls: [
          'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=800',
        ],
        likes: 67,
        comments: 8,
        shares: 3,
        isLiked: true,
        tags: ['coffee', 'latte', 'cafe'],
        location: 'Downtown Coffee Co.',
      ),
    ];
  }
}
