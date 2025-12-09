import 'user_model.dart';

/// Ranking Model
class RankingModel {
  final int rank;
  final UserModel user;
  final int score;
  final int rewardCoins;
  final bool rewardClaimed;

  const RankingModel({
    required this.rank,
    required this.user,
    required this.score,
    required this.rewardCoins,
    required this.rewardClaimed,
  });

  factory RankingModel.fromJson(Map<String, dynamic> json) {
    return RankingModel(
      rank: (json['rank'] as num).toInt(),
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      score: (json['score'] as num).toInt(),
      rewardCoins: (json['rewardCoins'] as num).toInt(),
      rewardClaimed: json['rewardClaimed'] as bool,
    );
  }

  String get medalIcon {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '';
    }
  }

  bool get hasMedal => rank <= 3;
}

/// User Ranking (for current user)
class UserRanking {
  final int rank;
  final int score;
  final int rewardCoins;
  final bool rewardClaimed;

  const UserRanking({
    required this.rank,
    required this.score,
    required this.rewardCoins,
    required this.rewardClaimed,
  });

  factory UserRanking.fromJson(Map<String, dynamic> json) {
    return UserRanking(
      rank: (json['rank'] as num).toInt(),
      score: (json['score'] as num).toInt(),
      rewardCoins: (json['rewardCoins'] as num).toInt(),
      rewardClaimed: json['rewardClaimed'] as bool,
    );
  }
}

enum RankingType {
  host, // Gifts received
  rich, // Coins sent
}

enum RankingPeriod {
  daily,
  weekly,
}

