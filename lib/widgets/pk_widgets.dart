import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import '../models/pk_gift_model.dart';
import '../services/token_auth_service.dart';
import '../providers/pk_battle_providers.dart';

class PKWidgets {
  /// PKTimerWidget dynamically listens to `pkBattleProvider`
  Widget PKTimerWidget() {
    return Consumer(
      builder: (context, ref, child) {
        final state = ref.watch(pkBattleProvider);
        return CircleAvatar(
          backgroundColor: Colors.white.withOpacity(0.9),
          radius: 30,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Since we don't have the PK_text.png, we use text for now
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "PK",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF4ECDC4),
                    ),
                  ),
                  Text(
                    state.formattedTime,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4ECDC4),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget TreasureWidget(TokenUser user, WidgetRef ref) {
    final List<PKGiftModel> gifts = [
      PKGiftModel(
        giftId: '01',
        giftName: "100 coins",
        value: 100,
        rarity: PKRarity.Common,
        lottieAsset: "assets/lotties/Gold.json",
        message: "Congrats!!!🎉 \n You have received 100 coins",
      ),
      PKGiftModel(
        giftId: '02',
        giftName: "200 coins",
        value: 200,
        rarity: PKRarity.Common,
        lottieAsset: "assets/lotties/Gold.json",
        message: "Congrats!!!🎉 \n You have received 200 coins",
      ),
      PKGiftModel(
        giftId: '09',
        giftName: "Platform Speaker",
        value: 1000,
        rarity: PKRarity.Legendary,
        lottieAsset: "assets/lotties/megaphone.json",
        message:
            "Congrats!!!🎉 \n You have received 1000 coins and a Platform Speaker",
      ),
    ];

    PKGiftModel selectedGiftByRarity() {
      int totalWeight = gifts.fold(0, (sum, gift) => sum + gift.rarity.weight);
      int randomValue = Random().nextInt(totalWeight);

      int weightSum = 0;
      for (var gift in gifts) {
        weightSum += gift.rarity.weight;
        if (randomValue < weightSum) {
          return gift;
        }
      }
      return gifts.first;
    }

    final state = ref.watch(pkBattleProvider);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () async {
            if (!state.canTap) {
              ScaffoldMessenger.of(ref.context).showSnackBar(
                const SnackBar(
                  content: Text("Please wait for the timer to reset!"),
                  duration: Duration(seconds: 2),
                ),
              );
              return;
            }

            // Reset timer on tap
            ref.read(pkBattleProvider.notifier).resetGiftTimer();

            // Handle gift selection
            PKGiftModel selectedGift = selectedGiftByRarity();

            // Show result
            showDialog(
              context: ref.context,
              builder:
                  (context) => Dialog(
                    backgroundColor: Colors.transparent,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Lottie.asset(
                          selectedGift.lottieAsset,
                          width: 150,
                          height: 150,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Text(
                            selectedGift.message,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
            );
          },
          child: Lottie.asset("assets/lotties/ic_gift.json", height: 40),
        ),
        Text(
          state.formattedGiftTime,
          style: const TextStyle(color: Colors.white, fontSize: 10),
        ),
      ],
    );
  }
}
