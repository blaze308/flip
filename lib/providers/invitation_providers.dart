import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/invitation_service.dart';

/// Referral Code Provider
final referralCodeProvider =
    StateNotifierProvider<ReferralCodeNotifier, AsyncValue<Map<String, dynamic>>>((ref) {
  return ReferralCodeNotifier();
});

class ReferralCodeNotifier extends StateNotifier<AsyncValue<Map<String, dynamic>>> {
  ReferralCodeNotifier() : super(const AsyncValue.loading()) {
    _loadReferralCode();
  }

  Map<String, dynamic>? _cachedData;
  DateTime? _lastFetch;
  static const Duration cacheExpiry = Duration(minutes: 10);

  Future<void> _loadReferralCode() async {
    // Check cache
    if (_cachedData != null && _lastFetch != null) {
      final timeSinceLastFetch = DateTime.now().difference(_lastFetch!);
      if (timeSinceLastFetch < cacheExpiry) {
        state = AsyncValue.data(_cachedData!);
        return;
      }
    }

    try {
      state = const AsyncValue.loading();

      final result = await InvitationService.getReferralCode();

      if (result['success'] == true && result['data'] != null) {
        _cachedData = result['data'];
        _lastFetch = DateTime.now();
        state = AsyncValue.data(_cachedData!);
      } else {
        state = AsyncValue.error(
          result['message'] ?? 'Failed to load referral code',
          StackTrace.current,
        );
      }
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> refresh() async {
    _lastFetch = null;
    await _loadReferralCode();
  }
}

/// Invitation History Provider
final invitationHistoryProvider =
    StateNotifierProvider<InvitationHistoryNotifier, AsyncValue<List<Map<String, dynamic>>>>((ref) {
  return InvitationHistoryNotifier();
});

class InvitationHistoryNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  InvitationHistoryNotifier() : super(const AsyncValue.loading()) {
    _loadHistory();
  }

  List<Map<String, dynamic>> _history = [];

  Future<void> _loadHistory() async {
    try {
      state = const AsyncValue.loading();

      final history = await InvitationService.getInvitationHistory();

      _history = history;
      state = AsyncValue.data(_history);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> refresh() async {
    await _loadHistory();
  }
}

/// Send Invitation Provider
final sendInvitationProvider =
    StateNotifierProvider<SendInvitationNotifier, AsyncValue<bool>>((ref) {
  return SendInvitationNotifier(ref);
});

class SendInvitationNotifier extends StateNotifier<AsyncValue<bool>> {
  SendInvitationNotifier(this.ref) : super(const AsyncValue.data(false));

  final Ref ref;

  Future<Map<String, dynamic>> sendInvitation({
    required String method,
    String? recipient,
  }) async {
    try {
      state = const AsyncValue.loading();

      final result = await InvitationService.sendInvitation(
        method: method,
        recipient: recipient,
      );

      if (result['success'] == true) {
        // Refresh referral code to update stats
        ref.read(referralCodeProvider.notifier).refresh();
        state = const AsyncValue.data(true);
      } else {
        state = AsyncValue.error(
          result['message'] ?? 'Failed to send invitation',
          StackTrace.current,
        );
      }

      return result;
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      return {
        'success': false,
        'message': 'An error occurred: $e',
      };
    }
  }

  void reset() {
    state = const AsyncValue.data(false);
  }
}

/// Claim Referral Reward Provider
final claimReferralRewardProvider =
    StateNotifierProvider<ClaimReferralRewardNotifier, AsyncValue<bool>>((ref) {
  return ClaimReferralRewardNotifier(ref);
});

class ClaimReferralRewardNotifier extends StateNotifier<AsyncValue<bool>> {
  ClaimReferralRewardNotifier(this.ref) : super(const AsyncValue.data(false));

  final Ref ref;

  Future<Map<String, dynamic>> claimReward(String invitationId) async {
    try {
      state = const AsyncValue.loading();

      final result = await InvitationService.claimReferralReward(invitationId);

      if (result['success'] == true) {
        // Refresh referral code and history
        ref.read(referralCodeProvider.notifier).refresh();
        ref.read(invitationHistoryProvider.notifier).refresh();
        state = const AsyncValue.data(true);
      } else {
        state = AsyncValue.error(
          result['message'] ?? 'Failed to claim reward',
          StackTrace.current,
        );
      }

      return result;
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      return {
        'success': false,
        'message': 'An error occurred: $e',
      };
    }
  }

  void reset() {
    state = const AsyncValue.data(false);
  }
}

