// Gift model for SVGA animations
class GiftModel {
  final String id;
  final String name;
  final String iconUrl;
  final String svgaUrl;
  final int weight; // Value/cost of the gift
  final GiftType type;

  GiftModel({
    required this.id,
    required this.name,
    required this.iconUrl,
    required this.svgaUrl,
    required this.weight,
    this.type = GiftType.svga,
  });

  factory GiftModel.fromJson(Map<String, dynamic> json) {
    return GiftModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      iconUrl: json['iconUrl'] ?? '',
      svgaUrl: json['svgaUrl'] ?? '',
      weight: json['weight'] ?? 0,
      type: GiftType.fromString(json['type'] ?? 'svga'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'iconUrl': iconUrl,
      'svgaUrl': svgaUrl,
      'weight': weight,
      'type': type.toString(),
    };
  }

  GiftModel copyWith({
    String? id,
    String? name,
    String? iconUrl,
    String? svgaUrl,
    int? weight,
    GiftType? type,
  }) {
    return GiftModel(
      id: id ?? this.id,
      name: name ?? this.name,
      iconUrl: iconUrl ?? this.iconUrl,
      svgaUrl: svgaUrl ?? this.svgaUrl,
      weight: weight ?? this.weight,
      type: type ?? this.type,
    );
  }
}

enum GiftType {
  svga,
  mp4,
  gif;

  static GiftType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'svga':
        return GiftType.svga;
      case 'mp4':
        return GiftType.mp4;
      case 'gif':
        return GiftType.gif;
      default:
        return GiftType.svga;
    }
  }

  @override
  String toString() {
    switch (this) {
      case GiftType.svga:
        return 'svga';
      case GiftType.mp4:
        return 'mp4';
      case GiftType.gif:
        return 'gif';
    }
  }
}

// Static list of available gifts
class GiftList {
  static final List<GiftModel> gifts = [
    GiftModel(
      id: 'blue_dragon',
      name: 'Blue Dragon',
      iconUrl:
          'https://flipbucket2aa19-dev.s3.amazonaws.com/020/blue+dragon.png',
      svgaUrl:
          'https://flipbucket2aa19-dev.s3.amazonaws.com/020/blue+dragon.svga',
      weight: 50000,
    ),
    GiftModel(
      id: 'blue_shoe',
      name: 'Blue Shoe',
      iconUrl: 'https://flipbucket2aa19-dev.s3.amazonaws.com/020/blue+shoe.png',
      svgaUrl:
          'https://flipbucket2aa19-dev.s3.amazonaws.com/020/blue+shoe.svga',
      weight: 30000,
    ),
    GiftModel(
      id: 'blue_tiger',
      name: 'Blue Tiger',
      iconUrl:
          'https://flipbucket2aa19-dev.s3.amazonaws.com/020/blue+tiger.png',
      svgaUrl:
          'https://flipbucket2aa19-dev.s3.amazonaws.com/020/blue+tiger.svga',
      weight: 20000,
    ),
    GiftModel(
      id: 'bluetail_fox',
      name: 'Bluetail Fox',
      iconUrl:
          'https://flipbucket2aa19-dev.s3.amazonaws.com/020/bluetail+fox.png',
      svgaUrl:
          'https://flipbucket2aa19-dev.s3.amazonaws.com/020/bluetail+fox.svga',
      weight: 20000,
    ),
    GiftModel(
      id: 'castle',
      name: 'Castle',
      iconUrl: 'https://flipbucket2aa19-dev.s3.amazonaws.com/020/castle.png',
      svgaUrl: 'https://flipbucket2aa19-dev.s3.amazonaws.com/020/castle.svga',
      weight: 30000,
    ),
    GiftModel(
      id: 'chalice',
      name: 'Chalice',
      iconUrl: 'https://flipbucket2aa19-dev.s3.amazonaws.com/020/chalice.png',
      svgaUrl: 'https://flipbucket2aa19-dev.s3.amazonaws.com/020/chalice.svga',
      weight: 30000,
    ),
    GiftModel(
      id: 'crown',
      name: 'Crown',
      iconUrl: 'https://flipbucket2aa19-dev.s3.amazonaws.com/020/crown.png',
      svgaUrl: 'https://flipbucket2aa19-dev.s3.amazonaws.com/020/crown.svga',
      weight: 30000,
    ),
    GiftModel(
      id: 'dragon',
      name: 'Dragon',
      iconUrl: 'https://flipbucket2aa19-dev.s3.amazonaws.com/020/dragon.png',
      svgaUrl: 'https://flipbucket2aa19-dev.s3.amazonaws.com/020/dragon.svga',
      weight: 20000,
    ),
    GiftModel(
      id: 'floating_castle',
      name: 'Floating Castle',
      iconUrl:
          'https://flipbucket2aa19-dev.s3.amazonaws.com/020/floating+castle.png',
      svgaUrl:
          'https://flipbucket2aa19-dev.s3.amazonaws.com/020/floating+castle.svga',
      weight: 50000,
    ),
    GiftModel(
      id: 'gold_dragon',
      name: 'Gold Dragon',
      iconUrl:
          'https://flipbucket2aa19-dev.s3.amazonaws.com/020/gold+dragon.png',
      svgaUrl:
          'https://flipbucket2aa19-dev.s3.amazonaws.com/020/gold+dragon.svga',
      weight: 40000,
    ),
    GiftModel(
      id: 'golden_bird',
      name: 'Golden Bird',
      iconUrl:
          'https://flipbucket2aa19-dev.s3.amazonaws.com/020/golden+bird.png',
      svgaUrl:
          'https://flipbucket2aa19-dev.s3.amazonaws.com/020/golden+bird.svga',
      weight: 70000,
    ),
    GiftModel(
      id: 'golden_cup',
      name: 'Golden Cup',
      iconUrl:
          'https://flipbucket2aa19-dev.s3.amazonaws.com/020/golden+cup.png',
      svgaUrl:
          'https://flipbucket2aa19-dev.s3.amazonaws.com/020/golden+cup.svga',
      weight: 30000,
    ),
    GiftModel(
      id: 'king',
      name: 'King',
      iconUrl: 'https://flipbucket2aa19-dev.s3.amazonaws.com/020/king.png',
      svgaUrl: 'https://flipbucket2aa19-dev.s3.amazonaws.com/020/king.svga',
      weight: 90000,
    ),
    GiftModel(
      id: 'mermaid',
      name: 'Mermaid',
      iconUrl: 'https://flipbucket2aa19-dev.s3.amazonaws.com/020/mermaid.png',
      svgaUrl: 'https://flipbucket2aa19-dev.s3.amazonaws.com/020/mermaid.svga',
      weight: 60000,
    ),
    GiftModel(
      id: 'pearl_mermaid',
      name: 'Pearl Mermaid',
      iconUrl:
          'https://flipbucket2aa19-dev.s3.amazonaws.com/020/pearl+mermaid.png',
      svgaUrl:
          'https://flipbucket2aa19-dev.s3.amazonaws.com/020/pearl+mermaid.svga',
      weight: 40000,
    ),
    GiftModel(
      id: 'pegasus',
      name: 'Pegasus',
      iconUrl: 'https://flipbucket2aa19-dev.s3.amazonaws.com/020/pegasus.png',
      svgaUrl: 'https://flipbucket2aa19-dev.s3.amazonaws.com/020/pegasus.svga',
      weight: 50000,
    ),
    GiftModel(
      id: 'pink_car',
      name: 'Pink Car',
      iconUrl: 'https://flipbucket2aa19-dev.s3.amazonaws.com/020/pink+car.png',
      svgaUrl: 'https://flipbucket2aa19-dev.s3.amazonaws.com/020/pink+car.svga',
      weight: 70000,
    ),
    GiftModel(
      id: 'red_dragon',
      name: 'Red Dragon',
      iconUrl:
          'https://flipbucket2aa19-dev.s3.amazonaws.com/020/red+dragon.png',
      svgaUrl:
          'https://flipbucket2aa19-dev.s3.amazonaws.com/020/red+dragon.svga',
      weight: 40000,
    ),
    GiftModel(
      id: 'red_porsche',
      name: 'Red Porsche',
      iconUrl:
          'https://flipbucket2aa19-dev.s3.amazonaws.com/020/red+porsche.png',
      svgaUrl:
          'https://flipbucket2aa19-dev.s3.amazonaws.com/020/red+porsche.svga',
      weight: 45000,
    ),
    GiftModel(
      id: 'rocket',
      name: 'Rocket',
      iconUrl: 'https://flipbucket2aa19-dev.s3.amazonaws.com/020/rocket.png',
      svgaUrl: 'https://flipbucket2aa19-dev.s3.amazonaws.com/020/rocket.svga',
      weight: 1000,
    ),
    GiftModel(
      id: 'white_tiger',
      name: 'White Tiger',
      iconUrl:
          'https://flipbucket2aa19-dev.s3.amazonaws.com/020/white+tiger.png',
      svgaUrl:
          'https://flipbucket2aa19-dev.s3.amazonaws.com/020/white+tiger.svga',
      weight: 35000,
    ),
    GiftModel(
      id: 'wine',
      name: 'Wine',
      iconUrl: 'https://flipbucket2aa19-dev.s3.amazonaws.com/020/wine.png',
      svgaUrl: 'https://flipbucket2aa19-dev.s3.amazonaws.com/020/wine.svga',
      weight: 25000,
    ),
  ];

  /// Query gift by name (case-insensitive)
  static GiftModel? queryGiftByName(String name) {
    final lowerName = name.toLowerCase();
    final index = gifts.indexWhere(
      (gift) => gift.name.toLowerCase() == lowerName,
    );
    return index != -1 ? gifts[index] : null;
  }

  /// Query gift by ID
  static GiftModel? queryGiftById(String id) {
    final index = gifts.indexWhere((gift) => gift.id == id);
    return index != -1 ? gifts[index] : null;
  }

  /// Get gifts sorted by weight (most expensive first)
  static List<GiftModel> getGiftsByWeight() {
    final sortedGifts = List<GiftModel>.from(gifts);
    sortedGifts.sort((a, b) => b.weight.compareTo(a.weight));
    return sortedGifts;
  }

  /// Get gifts within a weight range
  static List<GiftModel> getGiftsByWeightRange(int minWeight, int maxWeight) {
    return gifts.where((gift) {
      return gift.weight >= minWeight && gift.weight <= maxWeight;
    }).toList();
  }
}
