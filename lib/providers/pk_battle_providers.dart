import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PKBattleStatus { none, accepted, started, completed }

class PKBattleState {
  final int remainingSeconds;
  final bool isPKRunning;
  final int giftSeconds;
  final bool canTap;
  final PKBattleStatus status;

  PKBattleState({
    this.remainingSeconds = 300,
    this.isPKRunning = false,
    this.giftSeconds = 120,
    this.canTap = true,
    this.status = PKBattleStatus.none,
  });

  PKBattleState copyWith({
    int? remainingSeconds,
    bool? isPKRunning,
    int? giftSeconds,
    bool? canTap,
    PKBattleStatus? status,
  }) {
    return PKBattleState(
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isPKRunning: isPKRunning ?? this.isPKRunning,
      giftSeconds: giftSeconds ?? this.giftSeconds,
      canTap: canTap ?? this.canTap,
      status: status ?? this.status,
    );
  }

  String get formattedTime {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedGiftTime {
    final mins = giftSeconds ~/ 60;
    final secs = giftSeconds % 60;
    return "${mins.toString().padLeft(2, "0")} : ${secs.toString().padLeft(2, "0")}";
  }
}

class PKBattleNotifier extends StateNotifier<PKBattleState> {
  Timer? _pkTimer;
  Timer? _giftTimer;

  PKBattleNotifier() : super(PKBattleState());

  void startPKTimer({void Function()? onTimerComplete}) {
    _pkTimer?.cancel();
    state = state.copyWith(
      remainingSeconds: 300,
      isPKRunning: true,
      status: PKBattleStatus.started,
    );

    _pkTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.remainingSeconds > 0) {
        state = state.copyWith(remainingSeconds: state.remainingSeconds - 1);
      } else {
        _pkTimer?.cancel();
        state = state.copyWith(
          remainingSeconds: 300,
          isPKRunning: false,
          status: PKBattleStatus.completed,
        );
        if (onTimerComplete != null) onTimerComplete();
      }
    });
  }

  void resetPKTimer() {
    _pkTimer?.cancel();
    state = state.copyWith(
      remainingSeconds: 300,
      isPKRunning: false,
      status: PKBattleStatus.none,
    );
  }

  void startGiftTimer({void Function()? onGiftTimerComplete}) {
    _giftTimer?.cancel();
    state = state.copyWith(giftSeconds: 120, canTap: false);

    _giftTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.giftSeconds > 0) {
        state = state.copyWith(giftSeconds: state.giftSeconds - 1);
      } else {
        _giftTimer?.cancel();
        state = state.copyWith(giftSeconds: 120, canTap: true);
        if (onGiftTimerComplete != null) onGiftTimerComplete();
      }
    });
  }

  void resetGiftTimer() {
    if (!state.canTap) return;
    startGiftTimer();
  }

  void stopGiftTimer() {
    _giftTimer?.cancel();
    state = state.copyWith(giftSeconds: 120, canTap: true);
  }

  @override
  void dispose() {
    _pkTimer?.cancel();
    _giftTimer?.cancel();
    super.dispose();
  }
}

final pkBattleProvider = StateNotifierProvider<PKBattleNotifier, PKBattleState>(
  (ref) {
    return PKBattleNotifier();
  },
);
