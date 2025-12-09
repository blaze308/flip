import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../models/transaction_model.dart';
import '../models/gift_sent_model.dart';
import '../models/coin_package_model.dart';
import '../services/profile_service.dart';
import '../services/wallet_service.dart';
import '../services/gift_service.dart';
import '../services/gamification_service.dart';

/// Profile Provider - Caches user profile data
final profileProvider = StateNotifierProvider.family<ProfileNotifier,
    AsyncValue<UserModel?>, String?>((ref, userId) {
  return ProfileNotifier(userId);
});

class ProfileNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  ProfileNotifier(this.userId) : super(const AsyncValue.loading()) {
    _loadProfile();
  }

  final String? userId;
  UserModel? _cachedProfile;
  DateTime? _lastFetch;
  static const Duration cacheExpiry = Duration(minutes: 5);

  Future<void> _loadProfile() async {
    // Check cache
    if (_cachedProfile != null && _lastFetch != null) {
      final timeSinceLastFetch = DateTime.now().difference(_lastFetch!);
      if (timeSinceLastFetch < cacheExpiry) {
        state = AsyncValue.data(_cachedProfile);
        return;
      }
    }

    try {
      state = const AsyncValue.loading();

      final profile = userId == null
          ? await ProfileService.getMyProfile()
          : await ProfileService.getUserProfile(userId!);

      _cachedProfile = profile;
      _lastFetch = DateTime.now();
      state = AsyncValue.data(profile);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> refresh() async {
    _lastFetch = null;
    await _loadProfile();
  }

  void updateProfile(UserModel updatedProfile) {
    _cachedProfile = updatedProfile;
    _lastFetch = DateTime.now();
    state = AsyncValue.data(updatedProfile);
  }
}

/// Wallet Balance Provider
final walletBalanceProvider =
    StateNotifierProvider<WalletBalanceNotifier, AsyncValue<Map<String, int>>>(
        (ref) {
  return WalletBalanceNotifier();
});

class WalletBalanceNotifier extends StateNotifier<AsyncValue<Map<String, int>>> {
  WalletBalanceNotifier() : super(const AsyncValue.loading()) {
    _loadBalance();
  }

  Map<String, int> _balance = {'coins': 0, 'diamonds': 0, 'points': 0};
  DateTime? _lastFetch;
  static const Duration cacheExpiry = Duration(minutes: 1);

  Future<void> _loadBalance() async {
    // Check cache
    if (_lastFetch != null) {
      final timeSinceLastFetch = DateTime.now().difference(_lastFetch!);
      if (timeSinceLastFetch < cacheExpiry) {
        state = AsyncValue.data(_balance);
        return;
      }
    }

    try {
      final balance = await WalletService.getBalance();
      _balance = balance ?? {};
      _lastFetch = DateTime.now();
      state = AsyncValue.data(_balance);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> refresh() async {
    _lastFetch = null;
    await _loadBalance();
  }

  void updateBalance(Map<String, int> newBalance) {
    _balance = newBalance;
    _lastFetch = DateTime.now();
    state = AsyncValue.data(_balance);
  }
}

/// Coin Packages Provider
final coinPackagesProvider = StateNotifierProvider<CoinPackagesNotifier,
    AsyncValue<List<CoinPackageModel>>>((ref) {
  return CoinPackagesNotifier();
});

class CoinPackagesNotifier
    extends StateNotifier<AsyncValue<List<CoinPackageModel>>> {
  CoinPackagesNotifier() : super(const AsyncValue.loading()) {
    _loadPackages();
  }

  List<CoinPackageModel> _packages = [];
  DateTime? _lastFetch;
  static const Duration cacheExpiry = Duration(hours: 1);

  Future<void> _loadPackages() async {
    // Check cache
    if (_packages.isNotEmpty && _lastFetch != null) {
      final timeSinceLastFetch = DateTime.now().difference(_lastFetch!);
      if (timeSinceLastFetch < cacheExpiry) {
        state = AsyncValue.data(_packages);
        return;
      }
    }

    try {
      state = const AsyncValue.loading();
      final packages = await WalletService.getCoinPackages();
      _packages = packages;
      _lastFetch = DateTime.now();
      state = AsyncValue.data(_packages);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> refresh() async {
    _lastFetch = null;
    await _loadPackages();
  }
}

/// Transactions Provider
final transactionsProvider = StateNotifierProvider<TransactionsNotifier,
    AsyncValue<List<TransactionModel>>>((ref) {
  return TransactionsNotifier();
});

class TransactionsNotifier
    extends StateNotifier<AsyncValue<List<TransactionModel>>> {
  TransactionsNotifier() : super(const AsyncValue.loading()) {
    _loadTransactions();
  }

  List<TransactionModel> _transactions = [];

  Future<void> _loadTransactions() async {
    try {
      state = const AsyncValue.loading();

      final result = await WalletService.getTransactions();

      _transactions = result;
      state = AsyncValue.data(_transactions);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> refresh() async {
    await _loadTransactions();
  }
}

/// Received Gifts Provider
final receivedGiftsProvider = StateNotifierProvider<ReceivedGiftsNotifier,
    AsyncValue<List<GiftSentModel>>>((ref) {
  return ReceivedGiftsNotifier();
});

class ReceivedGiftsNotifier
    extends StateNotifier<AsyncValue<List<GiftSentModel>>> {
  ReceivedGiftsNotifier() : super(const AsyncValue.loading()) {
    _loadGifts();
  }

  List<GiftSentModel> _gifts = [];
  int _totalValue = 0;
  int _currentPage = 1;
  bool _hasMore = true;

  int get totalValue => _totalValue;

  Future<void> _loadGifts({bool loadMore = false}) async {
    try {
      if (loadMore && !_hasMore) return;

      if (!loadMore) {
        state = const AsyncValue.loading();
        _gifts = [];
        _currentPage = 1;
      }

      final result = await GiftService.getReceivedGifts(
        limit: 20,
        skip: loadMore ? _gifts.length : 0,
      );

      final giftsList = result['gifts'] as List;
      final newGifts = giftsList
          .map((g) => GiftSentModel.fromJson(g as Map<String, dynamic>))
          .toList();

      if (loadMore) {
        _gifts.addAll(newGifts);
        _currentPage++;
      } else {
        _gifts = newGifts;
        _totalValue = result['totalValue'] as int? ?? 0;
      }

      _hasMore = result['hasMore'] as bool? ?? false;
      state = AsyncValue.data(_gifts);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> refresh() async {
    await _loadGifts();
  }

  Future<void> loadMore() async {
    await _loadGifts(loadMore: true);
  }
}

/// Gamification Stats Provider
final gamificationStatsProvider = StateNotifierProvider<
    GamificationStatsNotifier, AsyncValue<Map<String, dynamic>>>((ref) {
  return GamificationStatsNotifier();
});

class GamificationStatsNotifier
    extends StateNotifier<AsyncValue<Map<String, dynamic>>> {
  GamificationStatsNotifier() : super(const AsyncValue.loading()) {
    _loadStats();
  }

  Map<String, dynamic>? _stats;
  DateTime? _lastFetch;
  static const Duration cacheExpiry = Duration(minutes: 5);

  Future<void> _loadStats() async {
    // Check cache
    if (_stats != null && _lastFetch != null) {
      final timeSinceLastFetch = DateTime.now().difference(_lastFetch!);
      if (timeSinceLastFetch < cacheExpiry) {
        state = AsyncValue.data(_stats!);
        return;
      }
    }

    try {
      state = const AsyncValue.loading();
      final stats = await GamificationService.getLevels();
      _stats = stats;
      _lastFetch = DateTime.now();
      state = AsyncValue.data(stats);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> refresh() async {
    _lastFetch = null;
    await _loadStats();
  }
}

