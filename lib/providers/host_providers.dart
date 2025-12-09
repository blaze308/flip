import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/host_service.dart';

/// Host Dashboard Provider
final hostDashboardProvider =
    StateNotifierProvider<HostDashboardNotifier, AsyncValue<Map<String, dynamic>?>>((ref) {
  return HostDashboardNotifier();
});

class HostDashboardNotifier extends StateNotifier<AsyncValue<Map<String, dynamic>?>> {
  HostDashboardNotifier() : super(const AsyncValue.loading()) {
    _loadDashboard();
  }

  Map<String, dynamic>? _cachedData;
  DateTime? _lastFetch;
  static const Duration cacheExpiry = Duration(minutes: 5);

  Future<void> _loadDashboard() async {
    // Check cache
    if (_cachedData != null && _lastFetch != null) {
      final timeSinceLastFetch = DateTime.now().difference(_lastFetch!);
      if (timeSinceLastFetch < cacheExpiry) {
        state = AsyncValue.data(_cachedData);
        return;
      }
    }

    try {
      state = const AsyncValue.loading();

      final data = await HostService.getHostDashboard();

      _cachedData = data;
      _lastFetch = DateTime.now();
      state = AsyncValue.data(data);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> refresh() async {
    _lastFetch = null;
    await _loadDashboard();
  }
}

/// Earnings Report Provider
final earningsReportProvider = StateNotifierProvider.family<
    EarningsReportNotifier, AsyncValue<Map<String, dynamic>?>, String>((ref, period) {
  return EarningsReportNotifier(period);
});

class EarningsReportNotifier extends StateNotifier<AsyncValue<Map<String, dynamic>?>> {
  EarningsReportNotifier(this.period) : super(const AsyncValue.loading()) {
    _loadReport();
  }

  final String period;

  Future<void> _loadReport() async {
    try {
      state = const AsyncValue.loading();

      final data = await HostService.getEarningsReport(period: period);

      state = AsyncValue.data(data);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> refresh() async {
    await _loadReport();
  }
}

/// Live Statistics Provider
final liveStatisticsProvider = StateNotifierProvider.family<
    LiveStatisticsNotifier, AsyncValue<Map<String, dynamic>?>, String>((ref, streamId) {
  return LiveStatisticsNotifier(streamId);
});

class LiveStatisticsNotifier extends StateNotifier<AsyncValue<Map<String, dynamic>?>> {
  LiveStatisticsNotifier(this.streamId) : super(const AsyncValue.loading()) {
    _loadStatistics();
  }

  final String streamId;

  Future<void> _loadStatistics() async {
    try {
      state = const AsyncValue.loading();

      final data = await HostService.getLiveStatistics(streamId);

      state = AsyncValue.data(data);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> refresh() async {
    await _loadStatistics();
  }
}

/// Host Application Provider
final hostApplicationProvider =
    StateNotifierProvider<HostApplicationNotifier, AsyncValue<bool>>((ref) {
  return HostApplicationNotifier();
});

class HostApplicationNotifier extends StateNotifier<AsyncValue<bool>> {
  HostApplicationNotifier() : super(const AsyncValue.data(false));

  Future<Map<String, dynamic>> applyForHost({
    required String reason,
    required String experience,
    String? socialMedia,
  }) async {
    try {
      state = const AsyncValue.loading();

      final result = await HostService.applyForHost(
        reason: reason,
        experience: experience,
        socialMedia: socialMedia,
      );

      if (result['success'] == true) {
        state = const AsyncValue.data(true);
      } else {
        state = AsyncValue.error(
          result['message'] ?? 'Failed to submit application',
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

/// Host Application Status Provider
final hostApplicationStatusProvider =
    StateNotifierProvider<HostApplicationStatusNotifier, AsyncValue<Map<String, dynamic>?>>((ref) {
  return HostApplicationStatusNotifier();
});

class HostApplicationStatusNotifier extends StateNotifier<AsyncValue<Map<String, dynamic>?>> {
  HostApplicationStatusNotifier() : super(const AsyncValue.loading()) {
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      state = const AsyncValue.loading();

      final status = await HostService.getHostApplicationStatus();

      state = AsyncValue.data(status);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> refresh() async {
    await _loadStatus();
  }
}

/// Host Rewards Provider
final hostRewardsProvider =
    StateNotifierProvider<HostRewardsNotifier, AsyncValue<List<Map<String, dynamic>>>>((ref) {
  return HostRewardsNotifier();
});

class HostRewardsNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  HostRewardsNotifier() : super(const AsyncValue.loading()) {
    _loadRewards();
  }

  List<Map<String, dynamic>> _rewards = [];

  Future<void> _loadRewards() async {
    try {
      state = const AsyncValue.loading();

      final rewards = await HostService.getHostRewards();

      _rewards = rewards;
      state = AsyncValue.data(_rewards);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> refresh() async {
    await _loadRewards();
  }
}

