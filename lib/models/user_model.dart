/// Full user model for profiles and detailed user information
class UserModel {
  final String id;
  final String username;
  final String displayName;
  final String? profileImageUrl;
  final String? bio;
  final String? website;
  final String? location;
  final String accountBadge;
  final int postsCount;
  final int followersCount;
  final int followingCount;
  final int likesCount;

  const UserModel({
    required this.id,
    required this.username,
    required this.displayName,
    this.profileImageUrl,
    this.bio,
    this.website,
    this.location,
    this.accountBadge = '',
    this.postsCount = 0,
    this.followersCount = 0,
    this.followingCount = 0,
    this.likesCount = 0,
  });

  // Helper getters for the profile widget
  bool get hasBio => bio != null && bio!.isNotEmpty;
  bool get hasWebsite => website != null && website!.isNotEmpty;
  bool get hasLocation => location != null && location!.isNotEmpty;
  bool get hasProfileImage =>
      profileImageUrl != null && profileImageUrl!.isNotEmpty;

  String get initials {
    if (displayName.isNotEmpty) {
      final parts = displayName.split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return displayName[0].toUpperCase();
    }
    return username.isNotEmpty ? username[0].toUpperCase() : '?';
  }

  /// Get the best available avatar URL (for chat compatibility)
  String? get bestAvatar => profileImageUrl;

  /// Get display name or fallback to username (for chat compatibility)
  String get bestDisplayName => displayName.isNotEmpty ? displayName : username;

  /// Get username for display (preferred for chats to avoid showing emails)
  String get bestUsername =>
      username.isNotEmpty && username != 'user' ? username : displayName;

  /// Factory for creating UserModel from JSON (chat API format)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Handle both _id (MongoDB) and id fields
    final String userId =
        (json['id'] as String?) ?? (json['_id'] as String?) ?? '';

    // Extract username from nested profile or top level
    final String? profileUsername =
        json['profile'] is Map<String, dynamic>
            ? (json['profile'] as Map<String, dynamic>)['username'] as String?
            : null;

    final String username =
        profileUsername ??
        json['username'] as String? ??
        json['displayName'] as String? ??
        'user';

    return UserModel(
      id: userId,
      username: username,
      displayName:
          json['displayName'] as String? ??
          json['fullName'] as String? ??
          username,
      profileImageUrl:
          json['photoURL'] as String? ??
          json['avatar'] as String? ??
          json['profileImageUrl'] as String?,
      bio: json['bio'] as String?,
      website: json['website'] as String?,
      location: json['location'] as String?,
      accountBadge: json['accountBadge'] as String? ?? '',
      postsCount: (json['postsCount'] as num?)?.toInt() ?? 0,
      followersCount: (json['followersCount'] as num?)?.toInt() ?? 0,
      followingCount: (json['followingCount'] as num?)?.toInt() ?? 0,
      likesCount: (json['likesCount'] as num?)?.toInt() ?? 0,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'displayName': displayName,
      'photoURL': profileImageUrl,
      'avatar': profileImageUrl,
      'bio': bio,
      'website': website,
      'location': location,
      'accountBadge': accountBadge,
      'postsCount': postsCount,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'likesCount': likesCount,
    };
  }
}
