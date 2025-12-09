import 'user_model.dart';
import 'gift_model.dart';

/// Gift Sent Model
/// Represents a gift transaction (sent or received)
class GiftSentModel {
  final String id;
  final UserModel? author;
  final String authorId;
  final UserModel? receiver;
  final String receiverId;
  final GiftModel? gift;
  final String giftId;
  final int diamondsQuantity;
  final String context; // live, profile, chat, post
  final String? liveStreamId;
  final DateTime createdAt;

  const GiftSentModel({
    required this.id,
    this.author,
    required this.authorId,
    this.receiver,
    required this.receiverId,
    this.gift,
    required this.giftId,
    required this.diamondsQuantity,
    required this.context,
    this.liveStreamId,
    required this.createdAt,
  });

  /// Factory for creating GiftSentModel from JSON
  factory GiftSentModel.fromJson(Map<String, dynamic> json) {
    return GiftSentModel(
      id: json['_id'] as String? ?? json['id'] as String,
      author: json['author'] != null && json['author'] is Map
          ? UserModel.fromJson(json['author'] as Map<String, dynamic>)
          : null,
      authorId: json['authorId'] as String,
      receiver: json['receiver'] != null && json['receiver'] is Map
          ? UserModel.fromJson(json['receiver'] as Map<String, dynamic>)
          : null,
      receiverId: json['receiverId'] as String,
      gift: json['gift'] != null && json['gift'] is Map
          ? GiftModel.fromJson(json['gift'] as Map<String, dynamic>)
          : null,
      giftId: json['giftId'] as String,
      diamondsQuantity: (json['diamondsQuantity'] as num).toInt(),
      context: json['context'] as String? ?? 'live',
      liveStreamId: json['liveStreamId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'authorId': authorId,
      'receiverId': receiverId,
      'giftId': giftId,
      'diamondsQuantity': diamondsQuantity,
      'context': context,
      'liveStreamId': liveStreamId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Get context display text
  String get contextDisplay {
    switch (context) {
      case 'live':
        return 'Live Stream';
      case 'profile':
        return 'Profile';
      case 'chat':
        return 'Chat';
      case 'post':
        return 'Post';
      default:
        return context;
    }
  }

  /// Get context icon
  String get contextIcon {
    switch (context) {
      case 'live':
        return '🎥';
      case 'profile':
        return '👤';
      case 'chat':
        return '💬';
      case 'post':
        return '📝';
      default:
        return '🎁';
    }
  }
}

