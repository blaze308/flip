/// Coin Package Model
/// Represents a purchasable coin package
class CoinPackageModel {
  final String id;
  final String productId;
  final int coins;
  final double priceUSD;
  final String displayName;
  final String? description;
  final String? image;
  final PackageType type;
  final int bonusCoins;
  final int discountPercent;
  final bool isActive;
  final String? googlePlayProductId;
  final String? appStoreProductId;
  final int sortOrder;

  const CoinPackageModel({
    required this.id,
    required this.productId,
    required this.coins,
    required this.priceUSD,
    required this.displayName,
    this.description,
    this.image,
    required this.type,
    required this.bonusCoins,
    required this.discountPercent,
    required this.isActive,
    this.googlePlayProductId,
    this.appStoreProductId,
    required this.sortOrder,
  });

  /// Factory for creating CoinPackageModel from JSON
  factory CoinPackageModel.fromJson(Map<String, dynamic> json) {
    return CoinPackageModel(
      id: json['_id'] as String? ?? json['id'] as String,
      productId: json['productId'] as String,
      coins: (json['coins'] as num).toInt(),
      priceUSD: (json['priceUSD'] as num).toDouble(),
      displayName: json['displayName'] as String,
      description: json['description'] as String?,
      image: json['image'] as String?,
      type: _parsePackageType(json['type'] as String?),
      bonusCoins: (json['bonusCoins'] as num?)?.toInt() ?? 0,
      discountPercent: (json['discountPercent'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      googlePlayProductId: json['googlePlayProductId'] as String?,
      appStoreProductId: json['appStoreProductId'] as String?,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'coins': coins,
      'priceUSD': priceUSD,
      'displayName': displayName,
      'description': description,
      'image': image,
      'type': type.value,
      'bonusCoins': bonusCoins,
      'discountPercent': discountPercent,
      'isActive': isActive,
      'googlePlayProductId': googlePlayProductId,
      'appStoreProductId': appStoreProductId,
      'sortOrder': sortOrder,
    };
  }

  /// Helper to parse package type from string
  static PackageType _parsePackageType(String? type) {
    switch (type) {
      case 'popular':
        return PackageType.popular;
      case 'hot':
        return PackageType.hot;
      case 'best_value':
        return PackageType.bestValue;
      case 'normal':
      default:
        return PackageType.normal;
    }
  }

  /// Get total coins (coins + bonus)
  int get totalCoins => coins + bonusCoins;

  /// Check if package has bonus
  bool get hasBonus => bonusCoins > 0;

  /// Check if package has discount
  bool get hasDiscount => discountPercent > 0;

  /// Get badge text based on type
  String? get badgeText {
    switch (type) {
      case PackageType.popular:
        return 'POPULAR';
      case PackageType.hot:
        return 'HOT';
      case PackageType.bestValue:
        return 'BEST VALUE';
      case PackageType.normal:
        return null;
    }
  }

  /// Get badge color based on type
  int? get badgeColor {
    switch (type) {
      case PackageType.popular:
        return 0xFF4ECDC4; // Teal
      case PackageType.hot:
        return 0xFFFF6B6B; // Red
      case PackageType.bestValue:
        return 0xFFFFD93D; // Gold
      case PackageType.normal:
        return null;
    }
  }
}

/// Package Type Enum
enum PackageType {
  normal,
  popular,
  hot,
  bestValue;

  String get value {
    switch (this) {
      case PackageType.normal:
        return 'normal';
      case PackageType.popular:
        return 'popular';
      case PackageType.hot:
        return 'hot';
      case PackageType.bestValue:
        return 'best_value';
    }
  }
}

