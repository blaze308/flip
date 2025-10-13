// Lottie animation model for chat
class LottieModel {
  final String id;
  final String name;
  final String lottieUrl;
  final int weight; // Value/cost of the lottie
  final LottieCategory category;
  final String? description;

  LottieModel({
    required this.id,
    required this.name,
    required this.lottieUrl,
    required this.weight,
    required this.category,
    this.description,
  });

  factory LottieModel.fromJson(Map<String, dynamic> json) {
    return LottieModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      lottieUrl: json['lottieUrl'] ?? '',
      weight: json['weight'] ?? 0,
      category: LottieCategory.fromString(json['category'] ?? 'classic'),
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'lottieUrl': lottieUrl,
      'weight': weight,
      'category': category.toString(),
      'description': description,
    };
  }

  LottieModel copyWith({
    String? id,
    String? name,
    String? lottieUrl,
    int? weight,
    LottieCategory? category,
    String? description,
  }) {
    return LottieModel(
      id: id ?? this.id,
      name: name ?? this.name,
      lottieUrl: lottieUrl ?? this.lottieUrl,
      weight: weight ?? this.weight,
      category: category ?? this.category,
      description: description ?? this.description,
    );
  }
}

enum LottieCategory {
  vip, // Exclusive premium animations
  threeD, // 3D style animations
  classic, // Classic/standard animations
  fun, // Fun and playful
  rewards, // Achievement and reward animations
  social, // Social interactions
  tech, // Technical/UI icons
  animals, // Animal animations
  effects; // Special effects

  static LottieCategory fromString(String category) {
    switch (category.toLowerCase()) {
      case 'vip':
        return LottieCategory.vip;
      case '3d':
      case 'threed':
        return LottieCategory.threeD;
      case 'classic':
        return LottieCategory.classic;
      case 'fun':
        return LottieCategory.fun;
      case 'rewards':
        return LottieCategory.rewards;
      case 'social':
        return LottieCategory.social;
      case 'tech':
        return LottieCategory.tech;
      case 'animals':
        return LottieCategory.animals;
      case 'effects':
        return LottieCategory.effects;
      default:
        return LottieCategory.classic;
    }
  }

  String get displayName {
    switch (this) {
      case LottieCategory.vip:
        return 'VIP';
      case LottieCategory.threeD:
        return '3D';
      case LottieCategory.classic:
        return 'Classic';
      case LottieCategory.fun:
        return 'Fun';
      case LottieCategory.rewards:
        return 'Rewards';
      case LottieCategory.social:
        return 'Social';
      case LottieCategory.tech:
        return 'Tech';
      case LottieCategory.animals:
        return 'Animals';
      case LottieCategory.effects:
        return 'Effects';
    }
  }

  String get emoji {
    switch (this) {
      case LottieCategory.vip:
        return '👑';
      case LottieCategory.threeD:
        return '🎯';
      case LottieCategory.classic:
        return '⭐';
      case LottieCategory.fun:
        return '🎉';
      case LottieCategory.rewards:
        return '🏆';
      case LottieCategory.social:
        return '💬';
      case LottieCategory.tech:
        return '⚙️';
      case LottieCategory.animals:
        return '🦊';
      case LottieCategory.effects:
        return '✨';
    }
  }

  @override
  String toString() {
    switch (this) {
      case LottieCategory.vip:
        return 'vip';
      case LottieCategory.threeD:
        return '3d';
      case LottieCategory.classic:
        return 'classic';
      case LottieCategory.fun:
        return 'fun';
      case LottieCategory.rewards:
        return 'rewards';
      case LottieCategory.social:
        return 'social';
      case LottieCategory.tech:
        return 'tech';
      case LottieCategory.animals:
        return 'animals';
      case LottieCategory.effects:
        return 'effects';
    }
  }
}

// Static list of available lotties
class LottieList {
  static final List<LottieModel> lotties = [
    // VIP Category - Most Expensive (50K - 100K)
    LottieModel(
      id: 'vip',
      name: 'VIP',
      lottieUrl: 'assets/lotties/VIP.json',
      weight: 100000,
      category: LottieCategory.vip,
      description: 'Exclusive VIP animation',
    ),
    LottieModel(
      id: 'mvp',
      name: 'MVP',
      lottieUrl: 'assets/lotties/MVP.json',
      weight: 85000,
      category: LottieCategory.vip,
      description: 'Most Valuable Player badge',
    ),
    LottieModel(
      id: 'diamond',
      name: 'Diamond',
      lottieUrl: 'assets/lotties/Diamond.json',
      weight: 75000,
      category: LottieCategory.vip,
      description: 'Premium diamond effect',
    ),
    LottieModel(
      id: 'gold',
      name: 'Gold',
      lottieUrl: 'assets/lotties/Gold.json',
      weight: 60000,
      category: LottieCategory.vip,
      description: 'Gold tier animation',
    ),

    // Rewards Category - High Value (30K - 50K)
    LottieModel(
      id: 'rewards',
      name: 'Rewards',
      lottieUrl: 'assets/lotties/Rewards.json',
      weight: 45000,
      category: LottieCategory.rewards,
      description: 'Achievement unlocked',
    ),
    LottieModel(
      id: 'badges',
      name: 'Badges',
      lottieUrl: 'assets/lotties/Badges.json',
      weight: 40000,
      category: LottieCategory.rewards,
      description: 'Badge collection',
    ),
    LottieModel(
      id: 'guardians',
      name: 'Guardians',
      lottieUrl: 'assets/lotties/Guardians.json',
      weight: 38000,
      category: LottieCategory.rewards,
      description: 'Guardian status',
    ),
    LottieModel(
      id: 'fan_club',
      name: 'Fan Club',
      lottieUrl: 'assets/lotties/FanClub.json',
      weight: 35000,
      category: LottieCategory.rewards,
      description: 'Fan club member',
    ),
    LottieModel(
      id: 'silver',
      name: 'Silver',
      lottieUrl: 'assets/lotties/Silver.json',
      weight: 35000,
      category: LottieCategory.rewards,
      description: 'Silver tier',
    ),
    LottieModel(
      id: 'bronze',
      name: 'Bronze',
      lottieUrl: 'assets/lotties/Bronze.json',
      weight: 30000,
      category: LottieCategory.rewards,
      description: 'Bronze tier',
    ),

    // Animals Category - Medium Value (15K - 25K)
    LottieModel(
      id: 'running_horse',
      name: 'Running Horse',
      lottieUrl: 'assets/lotties/running_horse.json',
      weight: 25000,
      category: LottieCategory.animals,
      description: 'Majestic running horse',
    ),
    LottieModel(
      id: 'running_fox',
      name: 'Running Fox',
      lottieUrl: 'assets/lotties/running_fox.json',
      weight: 22000,
      category: LottieCategory.animals,
      description: 'Swift running fox',
    ),

    // Effects Category - Medium Value (10K - 20K)
    LottieModel(
      id: 'fire',
      name: 'Fire',
      lottieUrl: 'assets/lotties/fire.json',
      weight: 20000,
      category: LottieCategory.effects,
      description: 'Blazing fire effect',
    ),
    LottieModel(
      id: 'audio_spectrum',
      name: 'Audio Spectrum',
      lottieUrl: 'assets/lotties/61928-circular-audio-spectrum.json',
      weight: 18000,
      category: LottieCategory.effects,
      description: 'Circular audio visualizer',
    ),
    LottieModel(
      id: 'sound_animation',
      name: 'Sound Animation',
      lottieUrl: 'assets/lotties/sound_animation.json',
      weight: 15000,
      category: LottieCategory.effects,
      description: 'Sound wave animation',
    ),

    // Social Category - Medium Value (8K - 15K)
    LottieModel(
      id: 'megaphone',
      name: 'Megaphone',
      lottieUrl: 'assets/lotties/megaphone.json',
      weight: 15000,
      category: LottieCategory.social,
      description: 'Announcement megaphone',
    ),
    LottieModel(
      id: 'live_start',
      name: 'Live Start',
      lottieUrl: 'assets/lotties/ic_live_start.json',
      weight: 12000,
      category: LottieCategory.social,
      description: 'Go live animation',
    ),
    LottieModel(
      id: 'live_animation',
      name: 'Live',
      lottieUrl: 'assets/lotties/ic_live_animation.json',
      weight: 10000,
      category: LottieCategory.social,
      description: 'Live streaming',
    ),
    LottieModel(
      id: 'share_live',
      name: 'Share Live',
      lottieUrl: 'assets/lotties/ic_share_live.json',
      weight: 10000,
      category: LottieCategory.social,
      description: 'Share live stream',
    ),
    LottieModel(
      id: 'video_call',
      name: 'Video Call',
      lottieUrl: 'assets/lotties/ic_video_call.json',
      weight: 9000,
      category: LottieCategory.social,
      description: 'Video call icon',
    ),

    // Fun Category - Low-Medium Value (5K - 10K)
    LottieModel(
      id: 'gift',
      name: 'Gift',
      lottieUrl: 'assets/lotties/ic_gift.json',
      weight: 10000,
      category: LottieCategory.fun,
      description: 'Gift box animation',
    ),
    LottieModel(
      id: 'strawberry',
      name: 'Strawberry',
      lottieUrl: 'assets/lotties/strawberry.json',
      weight: 8000,
      category: LottieCategory.fun,
      description: 'Sweet strawberry',
    ),
    LottieModel(
      id: 'check_in',
      name: 'Check In',
      lottieUrl: 'assets/lotties/CheckIn.json',
      weight: 7000,
      category: LottieCategory.fun,
      description: 'Daily check-in',
    ),
    LottieModel(
      id: 'party',
      name: 'Party',
      lottieUrl: 'assets/lotties/tab_party.json',
      weight: 6000,
      category: LottieCategory.fun,
      description: 'Party time',
    ),

    // Classic Category - Medium Value (3K - 8K)
    LottieModel(
      id: 'backpacks',
      name: 'Backpacks',
      lottieUrl: 'assets/lotties/Backpacks.json',
      weight: 8000,
      category: LottieCategory.classic,
      description: 'Backpack collection',
    ),
    LottieModel(
      id: 'level',
      name: 'Level Up',
      lottieUrl: 'assets/lotties/Level.json',
      weight: 7000,
      category: LottieCategory.classic,
      description: 'Level up badge',
    ),
    LottieModel(
      id: 'shop',
      name: 'Shop',
      lottieUrl: 'assets/lotties/Shop.json',
      weight: 6000,
      category: LottieCategory.classic,
      description: 'Shopping cart',
    ),
    LottieModel(
      id: 'family',
      name: 'Family',
      lottieUrl: 'assets/lotties/Family.json',
      weight: 5000,
      category: LottieCategory.classic,
      description: 'Family members',
    ),
    LottieModel(
      id: 'farm',
      name: 'Farm',
      lottieUrl: 'assets/lotties/Farm.json',
      weight: 5000,
      category: LottieCategory.classic,
      description: 'Farm animals',
    ),
    LottieModel(
      id: 'reels',
      name: 'Reels',
      lottieUrl: 'assets/lotties/reels.json',
      weight: 4000,
      category: LottieCategory.classic,
      description: 'Video reels',
    ),

    // Tech Category - Low Value (1K - 5K)
    LottieModel(
      id: 'account',
      name: 'Account',
      lottieUrl: 'assets/lotties/account.json',
      weight: 3000,
      category: LottieCategory.tech,
      description: 'User account',
    ),
    LottieModel(
      id: 'setting',
      name: 'Settings',
      lottieUrl: 'assets/lotties/setting.json',
      weight: 3000,
      category: LottieCategory.tech,
      description: 'Settings gear',
    ),
    LottieModel(
      id: 'chat',
      name: 'Chat',
      lottieUrl: 'assets/lotties/chat.json',
      weight: 2500,
      category: LottieCategory.tech,
      description: 'Chat bubble',
    ),
    LottieModel(
      id: 'feed',
      name: 'Feed',
      lottieUrl: 'assets/lotties/feed.json',
      weight: 2500,
      category: LottieCategory.tech,
      description: 'News feed',
    ),
    LottieModel(
      id: 'live',
      name: 'Live',
      lottieUrl: 'assets/lotties/live.json',
      weight: 2000,
      category: LottieCategory.tech,
      description: 'Live indicator',
    ),
    LottieModel(
      id: 'comment',
      name: 'Comment',
      lottieUrl: 'assets/lotties/ic_comment.json',
      weight: 2000,
      category: LottieCategory.tech,
      description: 'Comment icon',
    ),
    LottieModel(
      id: 'viewer',
      name: 'Viewer',
      lottieUrl: 'assets/lotties/ic_viewer.json',
      weight: 2000,
      category: LottieCategory.tech,
      description: 'Viewer count',
    ),
    LottieModel(
      id: 'online',
      name: 'Online',
      lottieUrl: 'assets/lotties/ic_online.json',
      weight: 1500,
      category: LottieCategory.tech,
      description: 'Online status',
    ),
    LottieModel(
      id: 'offline',
      name: 'Offline',
      lottieUrl: 'assets/lotties/ic_offline.json',
      weight: 1500,
      category: LottieCategory.tech,
      description: 'Offline status',
    ),
    LottieModel(
      id: 'activated_mic',
      name: 'Mic On',
      lottieUrl: 'assets/lotties/ic_activated_mic.json',
      weight: 1000,
      category: LottieCategory.tech,
      description: 'Microphone on',
    ),
    LottieModel(
      id: 'disabled_mic',
      name: 'Mic Off',
      lottieUrl: 'assets/lotties/ic_disabled_mic.json',
      weight: 1000,
      category: LottieCategory.tech,
      description: 'Microphone off',
    ),
    LottieModel(
      id: 'enabled_video',
      name: 'Camera On',
      lottieUrl: 'assets/lotties/ic_enabled_video.json',
      weight: 1000,
      category: LottieCategory.tech,
      description: 'Camera on',
    ),
    LottieModel(
      id: 'disabled_video',
      name: 'Camera Off',
      lottieUrl: 'assets/lotties/ic_disabled_video.json',
      weight: 1000,
      category: LottieCategory.tech,
      description: 'Camera off',
    ),
    LottieModel(
      id: 'switch_camera',
      name: 'Switch Camera',
      lottieUrl: 'assets/lotties/ic_switch_camera.json',
      weight: 1000,
      category: LottieCategory.tech,
      description: 'Switch camera',
    ),
    LottieModel(
      id: 'message_mic',
      name: 'Voice Message',
      lottieUrl: 'assets/lotties/ic_message_mic.json',
      weight: 1000,
      category: LottieCategory.tech,
      description: 'Voice message',
    ),
    LottieModel(
      id: 'menu',
      name: 'Menu',
      lottieUrl: 'assets/lotties/ic_menu.json',
      weight: 500,
      category: LottieCategory.tech,
      description: 'Menu icon',
    ),
    LottieModel(
      id: 'menu_grid',
      name: 'Grid Menu',
      lottieUrl: 'assets/lotties/ic_menu_grid.json',
      weight: 500,
      category: LottieCategory.tech,
      description: 'Grid menu',
    ),
    LottieModel(
      id: 'menu_plus',
      name: 'Add Menu',
      lottieUrl: 'assets/lotties/ic_menu_plus.json',
      weight: 500,
      category: LottieCategory.tech,
      description: 'Add menu',
    ),
    LottieModel(
      id: 'empty_box',
      name: 'Empty Box',
      lottieUrl: 'assets/lotties/empty_box.json',
      weight: 500,
      category: LottieCategory.tech,
      description: 'Empty state',
    ),
    LottieModel(
      id: 'empty',
      name: 'Empty',
      lottieUrl: 'assets/lotties/empty.json',
      weight: 500,
      category: LottieCategory.tech,
      description: 'No content',
    ),
  ];

  /// Query lottie by name (case-insensitive)
  static LottieModel? queryLottieByName(String name) {
    final lowerName = name.toLowerCase();
    final index = lotties.indexWhere(
      (lottie) => lottie.name.toLowerCase() == lowerName,
    );
    return index != -1 ? lotties[index] : null;
  }

  /// Query lottie by ID
  static LottieModel? queryLottieById(String id) {
    final index = lotties.indexWhere((lottie) => lottie.id == id);
    return index != -1 ? lotties[index] : null;
  }

  /// Get lotties sorted by weight (most expensive first)
  static List<LottieModel> getLottiesByWeight() {
    final sortedLotties = List<LottieModel>.from(lotties);
    sortedLotties.sort((a, b) => b.weight.compareTo(a.weight));
    return sortedLotties;
  }

  /// Get lotties within a weight range
  static List<LottieModel> getLottiesByWeightRange(
    int minWeight,
    int maxWeight,
  ) {
    return lotties.where((lottie) {
      return lottie.weight >= minWeight && lottie.weight <= maxWeight;
    }).toList();
  }

  /// Get lotties by category
  static List<LottieModel> getLottiesByCategory(LottieCategory category) {
    return lotties.where((lottie) => lottie.category == category).toList();
  }

  /// Get all categories with their lottie count
  static Map<LottieCategory, int> getCategoryCounts() {
    final counts = <LottieCategory, int>{};
    for (final lottie in lotties) {
      counts[lottie.category] = (counts[lottie.category] ?? 0) + 1;
    }
    return counts;
  }

  /// Get lotties grouped by category
  static Map<LottieCategory, List<LottieModel>> getLottiesGroupedByCategory() {
    final grouped = <LottieCategory, List<LottieModel>>{};
    for (final lottie in lotties) {
      grouped[lottie.category] = grouped[lottie.category] ?? [];
      grouped[lottie.category]!.add(lottie);
    }
    return grouped;
  }
}
