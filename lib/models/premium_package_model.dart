import 'package:flutter/material.dart';

/// Premium Package Types
enum PremiumType {
  vip,
  mvp,
  guardian,
}

/// VIP Tiers
enum VipTier {
  normal, // Bronze
  superVip, // Silver
  diamond, // Gold
}

/// Guardian Tiers
enum GuardianTier {
  silver,
  gold,
  king,
}

/// Premium Package Model
/// Represents VIP, MVP, or Guardian subscription packages
class PremiumPackageModel {
  final String id;
  final PremiumType type;
  final String name;
  final String description;
  final int price; // In coins
  final int durationDays;
  final List<String> benefits;
  final String? tier; // For VIP and Guardian
  final int? dailyCoins; // Daily coin bonus for VIP
  final int? dailyFloatTags; // Daily float tags for VIP
  final int? dailySpeakers; // Daily speakers for VIP
  final Color color;
  final String iconPath;
  final bool isPopular;
  final bool isBestValue;

  const PremiumPackageModel({
    required this.id,
    required this.type,
    required this.name,
    required this.description,
    required this.price,
    required this.durationDays,
    required this.benefits,
    this.tier,
    this.dailyCoins,
    this.dailyFloatTags,
    this.dailySpeakers,
    required this.color,
    required this.iconPath,
    this.isPopular = false,
    this.isBestValue = false,
  });

  String get durationText {
    if (durationDays == 30) return '1 Month';
    if (durationDays == 90) return '3 Months';
    if (durationDays == 180) return '6 Months';
    if (durationDays == 365) return '1 Year';
    return '$durationDays Days';
  }

  String get priceText => '$price Coins';

  /// VIP Packages
  static List<PremiumPackageModel> getVipPackages() {
    return [
      // Normal VIP (Bronze)
      PremiumPackageModel(
        id: 'vip_normal_30',
        type: PremiumType.vip,
        name: 'Normal VIP',
        description: 'Bronze Tier - Essential Benefits',
        price: 95000,
        durationDays: 30,
        tier: 'normal',
        dailyCoins: 3500,
        dailyFloatTags: 1,
        dailySpeakers: 1,
        benefits: [
          '+3,500 coins/day',
          '+1 live float tag/day',
          '+1 platform speaker/day',
          'Ranking forward',
          'Distinguished logo',
          'Live translation',
          'Exclusive data card',
        ],
        color: const Color(0xFFCD7F32), // Bronze
        iconPath: 'assets/images/icon_vip_1.png',
      ),
      
      // Super VIP (Silver)
      PremiumPackageModel(
        id: 'vip_super_30',
        type: PremiumType.vip,
        name: 'Super VIP',
        description: 'Silver Tier - Enhanced Benefits',
        price: 100000,
        durationDays: 30,
        tier: 'super',
        dailyCoins: 16000,
        dailyFloatTags: 3,
        dailySpeakers: 3,
        benefits: [
          '+16,000 coins/day',
          '+3 live float tags/day',
          '+3 platform speakers/day',
          'All Normal VIP features',
          'Enhanced presence',
          'Priority support',
        ],
        color: const Color(0xFFC0C0C0), // Silver
        iconPath: 'assets/images/icon_vip_2.png',
        isPopular: true,
      ),
      
      // Diamond VIP (Gold)
      PremiumPackageModel(
        id: 'vip_diamond_30',
        type: PremiumType.vip,
        name: 'Diamond VIP',
        description: 'Gold Tier - Ultimate Benefits',
        price: 250000,
        durationDays: 30,
        tier: 'diamond',
        dailyCoins: 35000,
        dailyFloatTags: 5,
        dailySpeakers: 5,
        benefits: [
          '+35,000 coins/day',
          '+5 live float tags/day',
          '+5 platform speakers/day',
          'All Super VIP features',
          'Invisible visitor mode',
          'Exclusive badge & frame',
          'VIP customer service',
        ],
        color: const Color(0xFFFFD700), // Gold
        iconPath: 'assets/images/icon_vip_3.png',
        isBestValue: true,
      ),
    ];
  }

  /// MVP Packages
  static List<PremiumPackageModel> getMvpPackages() {
    return [
      // 1 Month
      PremiumPackageModel(
        id: 'mvp_30',
        type: PremiumType.mvp,
        name: 'MVP Premium',
        description: '1 Month Subscription',
        price: 7085,
        durationDays: 30,
        benefits: [
          'Exclusive social footprint',
          'Level up acceleration',
          'Family privileges',
          'Enhanced presence',
          'Exclusive vehicle',
          'Premium badge/frame',
          'True love indicator',
          'Mini profile background',
          'Status symbol',
          'Exclusive wallpaper',
          'Wealth privileges',
        ],
        color: const Color(0xFF9C27B0), // Purple
        iconPath: 'assets/images/icon_mvp.png',
      ),
      
      // 3 Months
      PremiumPackageModel(
        id: 'mvp_90',
        type: PremiumType.mvp,
        name: 'MVP Premium',
        description: '3 Months Subscription',
        price: 20000,
        durationDays: 90,
        benefits: [
          'All 1-month benefits',
          'Save 5% compared to monthly',
          'Extended premium status',
        ],
        color: const Color(0xFF9C27B0),
        iconPath: 'assets/images/icon_mvp.png',
        isPopular: true,
      ),
      
      // 6 Months
      PremiumPackageModel(
        id: 'mvp_180',
        type: PremiumType.mvp,
        name: 'MVP Premium',
        description: '6 Months Subscription',
        price: 38000,
        durationDays: 180,
        benefits: [
          'All 1-month benefits',
          'Save 10% compared to monthly',
          'Extended premium status',
        ],
        color: const Color(0xFF9C27B0),
        iconPath: 'assets/images/icon_mvp.png',
      ),
      
      // 12 Months
      PremiumPackageModel(
        id: 'mvp_365',
        type: PremiumType.mvp,
        name: 'MVP Premium',
        description: '12 Months Subscription',
        price: 70000,
        durationDays: 365,
        benefits: [
          'All 1-month benefits',
          'Save 17% compared to monthly',
          'Full year premium status',
          'Best value!',
        ],
        color: const Color(0xFF9C27B0),
        iconPath: 'assets/images/icon_mvp.png',
        isBestValue: true,
      ),
    ];
  }

  /// Guardian Packages
  static List<PremiumPackageModel> getGuardianPackages() {
    return [
      // Silver Guardian
      PremiumPackageModel(
        id: 'guardian_silver_30',
        type: PremiumType.guardian,
        name: 'Silver Guardian',
        description: 'Protect your favorite creator',
        price: 15000,
        durationDays: 30,
        tier: 'silver',
        benefits: [
          'Ranking forward',
          'Distinguished logo',
          'Entry effects',
          'Exclusive bubble',
          'Guardian badge',
        ],
        color: const Color(0xFFC0C0C0), // Silver
        iconPath: 'assets/images/icon_sh_1.png',
      ),
      
      // Gold Guardian
      PremiumPackageModel(
        id: 'guardian_gold_30',
        type: PremiumType.guardian,
        name: 'Gold Guardian',
        description: 'Enhanced protection & benefits',
        price: 30000,
        durationDays: 30,
        tier: 'gold',
        benefits: [
          'All Silver features',
          'Enhanced effects',
          'Priority in chat',
          'Exclusive animations',
          'Gold guardian badge',
        ],
        color: const Color(0xFFFFD700), // Gold
        iconPath: 'assets/images/icon_sh_2.png',
        isPopular: true,
      ),
      
      // King Guardian
      PremiumPackageModel(
        id: 'guardian_king_30',
        type: PremiumType.guardian,
        name: 'King Guardian',
        description: 'Ultimate protection & prestige',
        price: 150000,
        durationDays: 30,
        tier: 'king',
        benefits: [
          'All Gold features',
          'Premium effects',
          'Maximum privileges',
          'Exclusive king badge',
          'Top priority everywhere',
          'Legendary status',
        ],
        color: const Color(0xFFFF4500), // Red-Orange
        iconPath: 'assets/images/icon_sh_3.png',
        isBestValue: true,
      ),
    ];
  }
}

