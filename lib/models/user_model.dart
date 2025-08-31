import 'package:firebase_auth/firebase_auth.dart';

class UserModel {
  // Basic Identity
  final String uid;
  final String email;
  final String username;
  final String displayName;
  final String? phoneNumber;

  // Profile Information
  final String? profileImageUrl;
  final String? coverImageUrl;
  final String? bio;
  final String? website;
  final DateTime? dateOfBirth;
  final String? location;

  // Social Stats
  final int followersCount;
  final int followingCount;
  final int postsCount;
  final int likesCount;
  final int viewsCount;

  // Content Preferences
  final List<String> interests;
  final List<String> preferredLanguages;
  final bool isPrivateAccount;
  final bool allowComments;
  final bool allowDuets;
  final bool allowStitch;

  // Verification & Status
  final bool isVerified;
  final bool isInfluencer;
  final bool isCreator;
  final String accountType; // 'personal', 'business', 'creator'
  final bool isActive;
  final bool isBanned;

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastActiveAt;

  // Device & Auth Info
  final List<String> authProviders; // ['email', 'google', 'apple', 'phone']
  final bool biometricEnabled;
  final String? deviceToken; // For push notifications
  final String? lastLoginDevice;

  // Social Features
  final List<String> blockedUsers;
  final List<String> mutedUsers;
  final List<String> closeFriends;

  // Content Settings
  final Map<String, bool> privacySettings;
  final Map<String, bool> notificationSettings;
  final String contentLanguage;
  final bool showInDiscovery;

  // Analytics (for creators)
  final Map<String, dynamic>? analyticsData;

  const UserModel({
    required this.uid,
    required this.email,
    required this.username,
    required this.displayName,
    this.phoneNumber,
    this.profileImageUrl,
    this.coverImageUrl,
    this.bio,
    this.website,
    this.dateOfBirth,
    this.location,
    this.followersCount = 0,
    this.followingCount = 0,
    this.postsCount = 0,
    this.likesCount = 0,
    this.viewsCount = 0,
    this.interests = const [],
    this.preferredLanguages = const ['en'],
    this.isPrivateAccount = false,
    this.allowComments = true,
    this.allowDuets = true,
    this.allowStitch = true,
    this.isVerified = false,
    this.isInfluencer = false,
    this.isCreator = false,
    this.accountType = 'personal',
    this.isActive = true,
    this.isBanned = false,
    required this.createdAt,
    required this.updatedAt,
    this.lastActiveAt,
    this.authProviders = const ['email'],
    this.biometricEnabled = false,
    this.deviceToken,
    this.lastLoginDevice,
    this.blockedUsers = const [],
    this.mutedUsers = const [],
    this.closeFriends = const [],
    this.privacySettings = const {},
    this.notificationSettings = const {},
    this.contentLanguage = 'en',
    this.showInDiscovery = true,
    this.analyticsData,
  });

  // Create from BackendUser (from backend_service.dart)
  factory UserModel.fromBackendUser(dynamic backendUser) {
    final now = DateTime.now();
    return UserModel(
      uid: backendUser.firebaseUid,
      email: backendUser.email ?? '',
      username: backendUser.displayName ?? 'User',
      displayName: backendUser.displayName ?? '',
      phoneNumber: backendUser.phoneNumber,
      profileImageUrl: backendUser.photoURL, // This is the key fix!
      bio: backendUser.profile?['bio'],
      createdAt: backendUser.createdAt ?? now,
      updatedAt: backendUser.updatedAt ?? now,
      lastActiveAt: backendUser.lastLogin,
      authProviders: backendUser.providers,
      privacySettings: _getDefaultPrivacySettings(),
      notificationSettings: _getDefaultNotificationSettings(),
    );
  }

  // Create from Firebase User
  factory UserModel.fromFirebaseUser(
    User firebaseUser, {
    String? username,
    String? bio,
    Map<String, dynamic>? additionalData,
  }) {
    final now = DateTime.now();

    return UserModel(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      username:
          username ?? _generateUsernameFromEmail(firebaseUser.email ?? ''),
      displayName: firebaseUser.displayName ?? username ?? 'User',
      phoneNumber: firebaseUser.phoneNumber,
      profileImageUrl: firebaseUser.photoURL,
      bio: bio,
      createdAt: now,
      updatedAt: now,
      lastActiveAt: now,
      authProviders: _getAuthProviders(firebaseUser),
      privacySettings: _getDefaultPrivacySettings(),
      notificationSettings: _getDefaultNotificationSettings(),
    );
  }

  // Create from JSON (for backend/storage)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? '',
      email: json['email'] ?? '',
      username: json['username'] ?? '',
      displayName: json['displayName'] ?? '',
      phoneNumber: json['phoneNumber'],
      profileImageUrl:
          json['profileImageUrl'] ??
          json['photoURL'], // Handle both field names
      coverImageUrl: json['coverImageUrl'],
      bio: json['bio'],
      website: json['website'],
      dateOfBirth:
          json['dateOfBirth'] != null
              ? DateTime.parse(json['dateOfBirth'])
              : null,
      location: json['location'],
      followersCount: json['followersCount'] ?? 0,
      followingCount: json['followingCount'] ?? 0,
      postsCount: json['postsCount'] ?? 0,
      likesCount: json['likesCount'] ?? 0,
      viewsCount: json['viewsCount'] ?? 0,
      interests: List<String>.from(json['interests'] ?? []),
      preferredLanguages: List<String>.from(
        json['preferredLanguages'] ?? ['en'],
      ),
      isPrivateAccount: json['isPrivateAccount'] ?? false,
      allowComments: json['allowComments'] ?? true,
      allowDuets: json['allowDuets'] ?? true,
      allowStitch: json['allowStitch'] ?? true,
      isVerified: json['isVerified'] ?? false,
      isInfluencer: json['isInfluencer'] ?? false,
      isCreator: json['isCreator'] ?? false,
      accountType: json['accountType'] ?? 'personal',
      isActive: json['isActive'] ?? true,
      isBanned: json['isBanned'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      lastActiveAt:
          json['lastActiveAt'] != null
              ? DateTime.parse(json['lastActiveAt'])
              : null,
      authProviders: List<String>.from(json['authProviders'] ?? ['email']),
      biometricEnabled: json['biometricEnabled'] ?? false,
      deviceToken: json['deviceToken'],
      lastLoginDevice: json['lastLoginDevice'],
      blockedUsers: List<String>.from(json['blockedUsers'] ?? []),
      mutedUsers: List<String>.from(json['mutedUsers'] ?? []),
      closeFriends: List<String>.from(json['closeFriends'] ?? []),
      privacySettings: Map<String, bool>.from(json['privacySettings'] ?? {}),
      notificationSettings: Map<String, bool>.from(
        json['notificationSettings'] ?? {},
      ),
      contentLanguage: json['contentLanguage'] ?? 'en',
      showInDiscovery: json['showInDiscovery'] ?? true,
      analyticsData: json['analyticsData'],
    );
  }

  // Create from backend JSON (MongoDB format)
  factory UserModel.fromBackendJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['firebaseUid'] ?? json['uid'] ?? '',
      email: json['email'] ?? '',
      username: json['username'] ?? json['displayName'] ?? '',
      displayName: json['displayName'] ?? '',
      phoneNumber: json['phoneNumber'],
      profileImageUrl:
          json['photoURL'] ?? json['profileImageUrl'], // Backend uses photoURL
      coverImageUrl: json['coverImageUrl'],
      bio: json['profile']?['bio'],
      website: json['profile']?['website'],
      dateOfBirth:
          json['profile']?['dateOfBirth'] != null
              ? DateTime.parse(json['profile']['dateOfBirth'])
              : null,
      location: json['profile']?['location']?['city'] ?? json['location'],
      followersCount: json['stats']?['followersCount'] ?? 0,
      followingCount: json['stats']?['followingCount'] ?? 0,
      postsCount: json['stats']?['postsCount'] ?? 0,
      likesCount: json['stats']?['likesCount'] ?? 0,
      viewsCount: json['stats']?['viewsCount'] ?? 0,
      interests: List<String>.from(json['profile']?['interests'] ?? []),
      preferredLanguages: List<String>.from(
        json['profile']?['preferredLanguages'] ?? ['en'],
      ),
      isPrivateAccount: json['profile']?['privacy']?['profileVisible'] == false,
      allowComments: json['allowComments'] ?? true,
      allowDuets: json['allowDuets'] ?? true,
      allowStitch: json['allowStitch'] ?? true,
      isVerified: json['isVerified'] ?? false,
      isInfluencer: json['isInfluencer'] ?? false,
      isCreator: json['isCreator'] ?? false,
      accountType: json['accountType'] ?? 'personal',
      isActive: json['isActive'] ?? true,
      isBanned: json['isBanned'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      lastActiveAt:
          json['lastActiveAt'] != null
              ? DateTime.parse(json['lastActiveAt'])
              : null,
      authProviders: List<String>.from(json['providers'] ?? ['email']),
      biometricEnabled: json['biometricEnabled'] ?? false,
      deviceToken: json['deviceToken'],
      lastLoginDevice: json['lastLoginDevice'],
      blockedUsers: List<String>.from(json['blockedUsers'] ?? []),
      mutedUsers: List<String>.from(json['mutedUsers'] ?? []),
      closeFriends: List<String>.from(json['closeFriends'] ?? []),
      privacySettings: Map<String, bool>.from(
        json['profile']?['preferences']?['privacy'] ?? {},
      ),
      notificationSettings: Map<String, bool>.from(
        json['profile']?['preferences']?['notifications'] ?? {},
      ),
      contentLanguage: json['profile']?['preferences']?['language'] ?? 'en',
      showInDiscovery: json['showInDiscovery'] ?? true,
      analyticsData: json['analyticsData'],
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'profileImageUrl': profileImageUrl,
      'coverImageUrl': coverImageUrl,
      'bio': bio,
      'website': website,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'location': location,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'postsCount': postsCount,
      'likesCount': likesCount,
      'viewsCount': viewsCount,
      'interests': interests,
      'preferredLanguages': preferredLanguages,
      'isPrivateAccount': isPrivateAccount,
      'allowComments': allowComments,
      'allowDuets': allowDuets,
      'allowStitch': allowStitch,
      'isVerified': isVerified,
      'isInfluencer': isInfluencer,
      'isCreator': isCreator,
      'accountType': accountType,
      'isActive': isActive,
      'isBanned': isBanned,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastActiveAt': lastActiveAt?.toIso8601String(),
      'authProviders': authProviders,
      'biometricEnabled': biometricEnabled,
      'deviceToken': deviceToken,
      'lastLoginDevice': lastLoginDevice,
      'blockedUsers': blockedUsers,
      'mutedUsers': mutedUsers,
      'closeFriends': closeFriends,
      'privacySettings': privacySettings,
      'notificationSettings': notificationSettings,
      'contentLanguage': contentLanguage,
      'showInDiscovery': showInDiscovery,
      'analyticsData': analyticsData,
    };
  }

  // Copy with modifications
  UserModel copyWith({
    String? email,
    String? username,
    String? displayName,
    String? phoneNumber,
    String? profileImageUrl,
    String? coverImageUrl,
    String? bio,
    String? website,
    DateTime? dateOfBirth,
    String? location,
    int? followersCount,
    int? followingCount,
    int? postsCount,
    int? likesCount,
    int? viewsCount,
    List<String>? interests,
    List<String>? preferredLanguages,
    bool? isPrivateAccount,
    bool? allowComments,
    bool? allowDuets,
    bool? allowStitch,
    bool? isVerified,
    bool? isInfluencer,
    bool? isCreator,
    String? accountType,
    bool? isActive,
    bool? isBanned,
    DateTime? updatedAt,
    DateTime? lastActiveAt,
    List<String>? authProviders,
    bool? biometricEnabled,
    String? deviceToken,
    String? lastLoginDevice,
    List<String>? blockedUsers,
    List<String>? mutedUsers,
    List<String>? closeFriends,
    Map<String, bool>? privacySettings,
    Map<String, bool>? notificationSettings,
    String? contentLanguage,
    bool? showInDiscovery,
    Map<String, dynamic>? analyticsData,
  }) {
    return UserModel(
      uid: uid, // UID never changes
      email: email ?? this.email,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      bio: bio ?? this.bio,
      website: website ?? this.website,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      location: location ?? this.location,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      postsCount: postsCount ?? this.postsCount,
      likesCount: likesCount ?? this.likesCount,
      viewsCount: viewsCount ?? this.viewsCount,
      interests: interests ?? this.interests,
      preferredLanguages: preferredLanguages ?? this.preferredLanguages,
      isPrivateAccount: isPrivateAccount ?? this.isPrivateAccount,
      allowComments: allowComments ?? this.allowComments,
      allowDuets: allowDuets ?? this.allowDuets,
      allowStitch: allowStitch ?? this.allowStitch,
      isVerified: isVerified ?? this.isVerified,
      isInfluencer: isInfluencer ?? this.isInfluencer,
      isCreator: isCreator ?? this.isCreator,
      accountType: accountType ?? this.accountType,
      isActive: isActive ?? this.isActive,
      isBanned: isBanned ?? this.isBanned,
      createdAt: createdAt, // Created date never changes
      updatedAt: updatedAt ?? DateTime.now(),
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      authProviders: authProviders ?? this.authProviders,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      deviceToken: deviceToken ?? this.deviceToken,
      lastLoginDevice: lastLoginDevice ?? this.lastLoginDevice,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      mutedUsers: mutedUsers ?? this.mutedUsers,
      closeFriends: closeFriends ?? this.closeFriends,
      privacySettings: privacySettings ?? this.privacySettings,
      notificationSettings: notificationSettings ?? this.notificationSettings,
      contentLanguage: contentLanguage ?? this.contentLanguage,
      showInDiscovery: showInDiscovery ?? this.showInDiscovery,
      analyticsData: analyticsData ?? this.analyticsData,
    );
  }

  // Utility methods
  bool get hasProfileImage =>
      profileImageUrl != null && profileImageUrl!.isNotEmpty;
  bool get hasCoverImage => coverImageUrl != null && coverImageUrl!.isNotEmpty;
  bool get hasBio => bio != null && bio!.isNotEmpty;
  bool get hasWebsite => website != null && website!.isNotEmpty;
  bool get hasLocation => location != null && location!.isNotEmpty;

  String get fullName => displayName.isNotEmpty ? displayName : username;
  String get initials => _getInitials(fullName);

  bool get isPopular => followersCount >= 10000;
  bool get isMegaInfluencer => followersCount >= 1000000;

  double get engagementRate {
    if (postsCount == 0) return 0.0;
    return (likesCount / (followersCount * postsCount)).clamp(0.0, 1.0);
  }

  String get accountBadge {
    if (isVerified) return '✓';
    if (isInfluencer) return '⭐';
    if (isCreator) return '🎨';
    return '';
  }

  // Helper methods
  static String _generateUsernameFromEmail(String email) {
    if (email.isEmpty) return 'user${DateTime.now().millisecondsSinceEpoch}';
    final username = email.split('@').first.toLowerCase();
    return username.replaceAll(RegExp(r'[^a-z0-9_]'), '_');
  }

  static List<String> _getAuthProviders(User firebaseUser) {
    return firebaseUser.providerData
        .map((info) => info.providerId)
        .where((provider) => provider != 'firebase')
        .toList();
  }

  static Map<String, bool> _getDefaultPrivacySettings() {
    return {
      'showEmail': false,
      'showPhone': false,
      'showLocation': false,
      'showLastActive': true,
      'allowMessageRequests': true,
      'showInSearch': true,
      'allowTagging': true,
      'showActivity': false,
    };
  }

  static Map<String, bool> _getDefaultNotificationSettings() {
    return {
      'likes': true,
      'comments': true,
      'follows': true,
      'mentions': true,
      'directMessages': true,
      'liveStreams': false,
      'recommendations': true,
      'marketing': false,
    };
  }

  static String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final words = name.trim().split(' ');
    if (words.length == 1) {
      return words[0].substring(0, 1).toUpperCase();
    }
    return '${words[0].substring(0, 1)}${words[1].substring(0, 1)}'
        .toUpperCase();
  }

  @override
  String toString() {
    return 'UserModel(uid: $uid, username: $username, displayName: $displayName, followers: $followersCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;
}

// Enum for account types
enum AccountType {
  personal('personal'),
  business('business'),
  creator('creator');

  const AccountType(this.value);
  final String value;
}

// Enum for content privacy levels
enum PrivacyLevel {
  public('public'),
  friends('friends'),
  private('private');

  const PrivacyLevel(this.value);
  final String value;
}
