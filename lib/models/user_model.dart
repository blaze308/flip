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

  /// Factory for creating UserModel from JSON (chat API format)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      username:
          json['username'] as String? ??
          json['displayName'] as String? ??
          'user',
      displayName: json['displayName'] as String? ?? 'User',
      profileImageUrl: json['photoURL'] as String? ?? json['avatar'] as String?,
      bio: json['bio'] as String?,
      website: json['website'] as String?,
      location: json['location'] as String?,
      accountBadge: json['accountBadge'] as String? ?? '',
      postsCount: json['postsCount'] as int? ?? 0,
      followersCount: json['followersCount'] as int? ?? 0,
      followingCount: json['followingCount'] as int? ?? 0,
      likesCount: json['likesCount'] as int? ?? 0,
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
