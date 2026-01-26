import 'user_model.dart';

enum PKRarity {
  Common(70),
  UnCommon(50),
  Rare(30),
  Legendary(10);

  final int weight;
  const PKRarity(this.weight);
}

class PKGiftModel {
  final String giftId;
  final String giftName;
  final int value;
  final PKRarity rarity;
  final String lottieAsset;
  final UserModel? receiver;
  final String message;

  PKGiftModel({
    required this.giftId,
    required this.giftName,
    required this.value,
    required this.rarity,
    required this.lottieAsset,
    this.receiver,
    required this.message,
  });
}
