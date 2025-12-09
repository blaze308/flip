/// Daily Reward Model
class DailyRewardModel {
  final int day;
  final int coins;
  final int diamonds;
  final DateTime? claimedAt;
  final int streakCount;

  const DailyRewardModel({
    required this.day,
    required this.coins,
    required this.diamonds,
    this.claimedAt,
    required this.streakCount,
  });

  factory DailyRewardModel.fromJson(Map<String, dynamic> json) {
    return DailyRewardModel(
      day: (json['day'] as num).toInt(),
      coins: (json['coins'] as num).toInt(),
      diamonds: (json['diamonds'] as num).toInt(),
      claimedAt: json['claimedAt'] != null
          ? DateTime.parse(json['claimedAt'] as String)
          : null,
      streakCount: (json['streakCount'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'day': day,
      'coins': coins,
      'diamonds': diamonds,
      'claimedAt': claimedAt?.toIso8601String(),
      'streakCount': streakCount,
    };
  }
}

/// Daily Reward Status
class DailyRewardStatus {
  final bool canClaim;
  final int nextDay;
  final DailyRewardModel nextReward;
  final int streakCount;
  final DateTime? lastClaimedAt;
  final List<DailyRewardModel> allRewards;

  const DailyRewardStatus({
    required this.canClaim,
    required this.nextDay,
    required this.nextReward,
    required this.streakCount,
    this.lastClaimedAt,
    required this.allRewards,
  });

  factory DailyRewardStatus.fromJson(Map<String, dynamic> json) {
    return DailyRewardStatus(
      canClaim: json['canClaim'] as bool,
      nextDay: (json['nextDay'] as num).toInt(),
      nextReward: DailyRewardModel.fromJson(json['nextReward'] as Map<String, dynamic>),
      streakCount: (json['streakCount'] as num).toInt(),
      lastClaimedAt: json['lastClaimedAt'] != null
          ? DateTime.parse(json['lastClaimedAt'] as String)
          : null,
      allRewards: (json['allRewards'] as List)
          .map((r) => DailyRewardModel.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }
}

