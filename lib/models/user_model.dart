/// Full user model for profiles and detailed user information
class UserModel {
  final String id;
  final String username;
  final String displayName;
  final String? email;
  final String? phoneNumber;
  final String? profileImageUrl;
  final String? coverPhotoURL;
  final String? bio;
  final String? website;
  final String? location;
  final String? country;
  final String? state;
  final String? city;
  final String? gender;
  final String? occupation;
  final List<String>? interests;
  final String accountBadge;
  final int postsCount;
  final int followersCount;
  final int followingCount;
  final int likesCount;
  final bool isFollowing;
  final bool isFollower;
  final DateTime? createdAt;

  // Gamification fields
  final int creditsSent;
  final int giftsReceived;
  final int wealthLevel;
  final int liveLevel;
  final int coins;
  final int diamonds;
  final int points;
  final bool isNormalVip;
  final bool isSuperVip;
  final bool isDiamondVip;
  final DateTime? vipExpiresAt;
  final bool isMVP;
  final DateTime? mvpExpiresAt;
  final String? guardianType; // 'silver', 'gold', 'king'
  final DateTime? guardianExpiresAt;
  final String? guardingUserId;
  final String? guardedByUserId;
  final int experiencePoints;

  const UserModel({
    required this.id,
    required this.username,
    required this.displayName,
    this.email,
    this.phoneNumber,
    this.profileImageUrl,
    this.coverPhotoURL,
    this.bio,
    this.website,
    this.location,
    this.country,
    this.state,
    this.city,
    this.gender,
    this.occupation,
    this.interests,
    this.accountBadge = '',
    this.postsCount = 0,
    this.followersCount = 0,
    this.followingCount = 0,
    this.likesCount = 0,
    this.isFollowing = false,
    this.isFollower = false,
    this.createdAt,
    // Gamification defaults
    this.creditsSent = 0,
    this.giftsReceived = 0,
    this.wealthLevel = 0,
    this.liveLevel = 0,
    this.coins = 0,
    this.diamonds = 0,
    this.points = 0,
    this.isNormalVip = false,
    this.isSuperVip = false,
    this.isDiamondVip = false,
    this.vipExpiresAt,
    this.isMVP = false,
    this.mvpExpiresAt,
    this.guardianType,
    this.guardianExpiresAt,
    this.guardingUserId,
    this.guardedByUserId,
    this.experiencePoints = 0,
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

  // Gamification helper getters
  bool get hasWealthLevel => wealthLevel > 0;
  bool get hasLiveLevel => liveLevel > 0;
  bool get isVip => isNormalVip || isSuperVip || isDiamondVip;
  bool get hasGuardian => guardianType != null;
  bool get isGuarding => guardingUserId != null;
  
  String get vipTier {
    if (isDiamondVip) return 'diamond';
    if (isSuperVip) return 'super';
    if (isNormalVip) return 'normal';
    return '';
  }

  /// Get wealth level badge icon path (SVG placeholder)
  String get wealthLevelIcon => 'assets/svg/wealth_level.svg';

  /// Get live level badge icon path (SVG placeholder)
  String get liveLevelIcon => 'assets/svg/live_level.svg';

  /// Get VIP badge icon path (SVG placeholder)
  String get vipIcon => 'assets/svg/vip_badge.svg';

  /// Get MVP badge icon path (SVG placeholder)
  String get mvpIcon => isMVP ? 'assets/svg/mvp_badge.svg' : '';

  /// Get Guardian badge icon path (SVG placeholder)
  String get guardianIcon => hasGuardian ? 'assets/svg/guardian_badge.svg' : '';

  /// Factory for creating UserModel from JSON (backend API format)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Handle both _id (MongoDB) and id fields
    final String userId =
        (json['id'] as String?) ?? (json['_id'] as String?) ?? '';

    // Extract profile data
    final Map<String, dynamic>? profile =
        json['profile'] is Map<String, dynamic>
            ? json['profile'] as Map<String, dynamic>
            : null;

    // Extract location data
    final Map<String, dynamic>? locationData =
        profile?['location'] is Map<String, dynamic>
            ? profile!['location'] as Map<String, dynamic>
            : null;

    // Extract gamification data
    final Map<String, dynamic>? gamification =
        json['gamification'] is Map<String, dynamic>
            ? json['gamification'] as Map<String, dynamic>
            : null;

    // Extract username
    final String username =
        profile?['username'] as String? ??
        json['username'] as String? ??
        json['displayName'] as String? ??
        'user';

    // Extract interests
    final List<String>? interests = profile?['interests'] is List
        ? (profile!['interests'] as List).map((e) => e.toString()).toList()
        : null;

    // Parse createdAt
    DateTime? createdAt;
    if (json['createdAt'] != null) {
      try {
        createdAt = DateTime.parse(json['createdAt'] as String);
      } catch (e) {
        createdAt = null;
      }
    }

    // Parse VIP expiration
    DateTime? vipExpiresAt;
    if (gamification?['vipExpiresAt'] != null) {
      try {
        vipExpiresAt = DateTime.parse(gamification!['vipExpiresAt'] as String);
      } catch (e) {
        vipExpiresAt = null;
      }
    }

    // Parse MVP expiration
    DateTime? mvpExpiresAt;
    if (gamification?['mvpExpiresAt'] != null) {
      try {
        mvpExpiresAt = DateTime.parse(gamification!['mvpExpiresAt'] as String);
      } catch (e) {
        mvpExpiresAt = null;
      }
    }

    // Parse Guardian expiration
    DateTime? guardianExpiresAt;
    if (gamification?['guardianExpiresAt'] != null) {
      try {
        guardianExpiresAt = DateTime.parse(gamification!['guardianExpiresAt'] as String);
      } catch (e) {
        guardianExpiresAt = null;
      }
    }

    return UserModel(
      id: userId,
      username: username,
      displayName:
          json['displayName'] as String? ??
          json['fullName'] as String? ??
          username,
      email: json['email'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      profileImageUrl:
          json['photoURL'] as String? ??
          json['avatar'] as String? ??
          json['profileImageUrl'] as String?,
      coverPhotoURL: profile?['coverPhotoURL'] as String?,
      bio: profile?['bio'] as String? ?? json['bio'] as String?,
      website: profile?['website'] as String? ?? json['website'] as String?,
      location: locationData != null
          ? '${locationData['city'] ?? ''}, ${locationData['country'] ?? ''}'.trim().replaceAll(RegExp(r'^,\s*|,\s*$'), '')
          : json['location'] as String?,
      country: locationData?['country'] as String?,
      state: locationData?['state'] as String?,
      city: locationData?['city'] as String?,
      gender: profile?['gender'] as String?,
      occupation: profile?['occupation'] as String?,
      interests: interests,
      accountBadge: json['accountBadge'] as String? ?? '',
      postsCount: (json['postsCount'] as num?)?.toInt() ?? 0,
      followersCount: (json['followersCount'] as num?)?.toInt() ?? 0,
      followingCount: (json['followingCount'] as num?)?.toInt() ?? 0,
      likesCount: (json['likesCount'] as num?)?.toInt() ?? 0,
      isFollowing: json['isFollowing'] as bool? ?? false,
      isFollower: json['isFollower'] as bool? ?? false,
      createdAt: createdAt,
      // Gamification fields
      creditsSent: (gamification?['creditsSent'] as num?)?.toInt() ?? 0,
      giftsReceived: (gamification?['giftsReceived'] as num?)?.toInt() ?? 0,
      wealthLevel: (gamification?['wealthLevel'] as num?)?.toInt() ?? 0,
      liveLevel: (gamification?['liveLevel'] as num?)?.toInt() ?? 0,
      coins: (gamification?['coins'] as num?)?.toInt() ?? 0,
      diamonds: (gamification?['diamonds'] as num?)?.toInt() ?? 0,
      points: (gamification?['points'] as num?)?.toInt() ?? 0,
      isNormalVip: gamification?['isNormalVip'] as bool? ?? false,
      isSuperVip: gamification?['isSuperVip'] as bool? ?? false,
      isDiamondVip: gamification?['isDiamondVip'] as bool? ?? false,
      vipExpiresAt: vipExpiresAt,
      isMVP: gamification?['isMVP'] as bool? ?? false,
      mvpExpiresAt: mvpExpiresAt,
      guardianType: gamification?['guardianType'] as String?,
      guardianExpiresAt: guardianExpiresAt,
      guardingUserId: gamification?['guardingUserId'] as String?,
      guardedByUserId: gamification?['guardedByUserId'] as String?,
      experiencePoints: (gamification?['experiencePoints'] as num?)?.toInt() ?? 0,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'displayName': displayName,
      'email': email,
      'phoneNumber': phoneNumber,
      'photoURL': profileImageUrl,
      'avatar': profileImageUrl,
      'coverPhotoURL': coverPhotoURL,
      'bio': bio,
      'website': website,
      'location': location,
      'country': country,
      'state': state,
      'city': city,
      'gender': gender,
      'occupation': occupation,
      'interests': interests,
      'accountBadge': accountBadge,
      'postsCount': postsCount,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'likesCount': likesCount,
      'isFollowing': isFollowing,
      'isFollower': isFollower,
      'createdAt': createdAt?.toIso8601String(),
      'gamification': {
        'creditsSent': creditsSent,
        'giftsReceived': giftsReceived,
        'wealthLevel': wealthLevel,
        'liveLevel': liveLevel,
        'coins': coins,
        'diamonds': diamonds,
        'points': points,
        'isNormalVip': isNormalVip,
        'isSuperVip': isSuperVip,
        'isDiamondVip': isDiamondVip,
        'vipExpiresAt': vipExpiresAt?.toIso8601String(),
        'isMVP': isMVP,
        'mvpExpiresAt': mvpExpiresAt?.toIso8601String(),
        'guardianType': guardianType,
        'guardianExpiresAt': guardianExpiresAt?.toIso8601String(),
        'guardingUserId': guardingUserId,
        'guardedByUserId': guardedByUserId,
        'experiencePoints': experiencePoints,
      },
    };
  }

  /// Copy with method for immutability
  UserModel copyWith({
    String? id,
    String? username,
    String? displayName,
    String? email,
    String? phoneNumber,
    String? profileImageUrl,
    String? coverPhotoURL,
    String? bio,
    String? website,
    String? location,
    String? country,
    String? state,
    String? city,
    String? gender,
    String? occupation,
    List<String>? interests,
    String? accountBadge,
    int? postsCount,
    int? followersCount,
    int? followingCount,
    int? likesCount,
    bool? isFollowing,
    bool? isFollower,
    DateTime? createdAt,
    int? creditsSent,
    int? giftsReceived,
    int? wealthLevel,
    int? liveLevel,
    int? coins,
    int? diamonds,
    int? points,
    bool? isNormalVip,
    bool? isSuperVip,
    bool? isDiamondVip,
    DateTime? vipExpiresAt,
    bool? isMVP,
    DateTime? mvpExpiresAt,
    String? guardianType,
    DateTime? guardianExpiresAt,
    String? guardingUserId,
    String? guardedByUserId,
    int? experiencePoints,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      coverPhotoURL: coverPhotoURL ?? this.coverPhotoURL,
      bio: bio ?? this.bio,
      website: website ?? this.website,
      location: location ?? this.location,
      country: country ?? this.country,
      state: state ?? this.state,
      city: city ?? this.city,
      gender: gender ?? this.gender,
      occupation: occupation ?? this.occupation,
      interests: interests ?? this.interests,
      accountBadge: accountBadge ?? this.accountBadge,
      postsCount: postsCount ?? this.postsCount,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      likesCount: likesCount ?? this.likesCount,
      isFollowing: isFollowing ?? this.isFollowing,
      isFollower: isFollower ?? this.isFollower,
      createdAt: createdAt ?? this.createdAt,
      creditsSent: creditsSent ?? this.creditsSent,
      giftsReceived: giftsReceived ?? this.giftsReceived,
      wealthLevel: wealthLevel ?? this.wealthLevel,
      liveLevel: liveLevel ?? this.liveLevel,
      coins: coins ?? this.coins,
      diamonds: diamonds ?? this.diamonds,
      points: points ?? this.points,
      isNormalVip: isNormalVip ?? this.isNormalVip,
      isSuperVip: isSuperVip ?? this.isSuperVip,
      isDiamondVip: isDiamondVip ?? this.isDiamondVip,
      vipExpiresAt: vipExpiresAt ?? this.vipExpiresAt,
      isMVP: isMVP ?? this.isMVP,
      mvpExpiresAt: mvpExpiresAt ?? this.mvpExpiresAt,
      guardianType: guardianType ?? this.guardianType,
      guardianExpiresAt: guardianExpiresAt ?? this.guardianExpiresAt,
      guardingUserId: guardingUserId ?? this.guardingUserId,
      guardedByUserId: guardedByUserId ?? this.guardedByUserId,
      experiencePoints: experiencePoints ?? this.experiencePoints,
    );
  }
}

