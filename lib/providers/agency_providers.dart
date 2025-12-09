import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/agency_member_model.dart';
import '../services/agency_service.dart';

/// My Agency Provider - Current user's agency membership
final myAgencyProvider =
    StateNotifierProvider<MyAgencyNotifier, AsyncValue<AgencyMemberModel?>>((ref) {
  return MyAgencyNotifier();
});

class MyAgencyNotifier extends StateNotifier<AsyncValue<AgencyMemberModel?>> {
  MyAgencyNotifier() : super(const AsyncValue.loading()) {
    _loadAgency();
  }

  AgencyMemberModel? _cachedMembership;
  DateTime? _lastFetch;
  static const Duration cacheExpiry = Duration(minutes: 5);

  Future<void> _loadAgency() async {
    // Check cache
    if (_cachedMembership != null && _lastFetch != null) {
      final timeSinceLastFetch = DateTime.now().difference(_lastFetch!);
      if (timeSinceLastFetch < cacheExpiry) {
        state = AsyncValue.data(_cachedMembership);
        return;
      }
    }

    try {
      state = const AsyncValue.loading();

      final membership = await AgencyService.getMyAgency();

      _cachedMembership = membership;
      _lastFetch = DateTime.now();
      state = AsyncValue.data(membership);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> refresh() async {
    _lastFetch = null;
    await _loadAgency();
  }

  void updateMembership(AgencyMemberModel? membership) {
    _cachedMembership = membership;
    _lastFetch = DateTime.now();
    state = AsyncValue.data(membership);
  }

  void clearMembership() {
    _cachedMembership = null;
    _lastFetch = null;
    state = const AsyncValue.data(null);
  }
}

/// Agency Stats Provider - For agents/owners
final agencyStatsProvider =
    StateNotifierProvider<AgencyStatsNotifier, AsyncValue<Map<String, dynamic>?>>((ref) {
  return AgencyStatsNotifier();
});

class AgencyStatsNotifier
    extends StateNotifier<AsyncValue<Map<String, dynamic>?>> {
  AgencyStatsNotifier() : super(const AsyncValue.loading()) {
    _loadStats();
  }

  Map<String, dynamic>? _cachedStats;
  DateTime? _lastFetch;
  static const Duration cacheExpiry = Duration(minutes: 5);

  Future<void> _loadStats() async {
    // Check cache
    if (_cachedStats != null && _lastFetch != null) {
      final timeSinceLastFetch = DateTime.now().difference(_lastFetch!);
      if (timeSinceLastFetch < cacheExpiry) {
        state = AsyncValue.data(_cachedStats);
        return;
      }
    }

    try {
      state = const AsyncValue.loading();

      final stats = await AgencyService.getAgencyStats();

      _cachedStats = stats;
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

  void updateStats(Map<String, dynamic>? stats) {
    _cachedStats = stats;
    _lastFetch = DateTime.now();
    state = AsyncValue.data(stats);
  }
}

/// Create Agency Action Provider
final createAgencyProvider =
    StateNotifierProvider<CreateAgencyNotifier, AsyncValue<bool>>((ref) {
  return CreateAgencyNotifier(ref);
});

class CreateAgencyNotifier extends StateNotifier<AsyncValue<bool>> {
  CreateAgencyNotifier(this.ref) : super(const AsyncValue.data(false));

  final Ref ref;

  Future<Map<String, dynamic>> createAgency({
    required String name,
    String? description,
  }) async {
    try {
      state = const AsyncValue.loading();

      final result = await AgencyService.createAgency(
        name: name,
        description: description,
      );

      if (result['success'] == true) {
        // Refresh my agency provider
        ref.read(myAgencyProvider.notifier).refresh();
        state = const AsyncValue.data(true);
      } else {
        state = AsyncValue.error(
          result['message'] ?? 'Failed to create agency',
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

/// Join Agency Action Provider
final joinAgencyProvider =
    StateNotifierProvider<JoinAgencyNotifier, AsyncValue<bool>>((ref) {
  return JoinAgencyNotifier(ref);
});

class JoinAgencyNotifier extends StateNotifier<AsyncValue<bool>> {
  JoinAgencyNotifier(this.ref) : super(const AsyncValue.data(false));

  final Ref ref;

  Future<Map<String, dynamic>> joinAgency({required String agencyId}) async {
    try {
      state = const AsyncValue.loading();

      final result = await AgencyService.joinAgency(agencyId: agencyId);

      if (result['success'] == true) {
        // Refresh my agency provider
        ref.read(myAgencyProvider.notifier).refresh();
        state = const AsyncValue.data(true);
      } else {
        state = AsyncValue.error(
          result['message'] ?? 'Failed to join agency',
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

/// Leave Agency Action Provider
final leaveAgencyProvider =
    StateNotifierProvider<LeaveAgencyNotifier, AsyncValue<bool>>((ref) {
  return LeaveAgencyNotifier(ref);
});

class LeaveAgencyNotifier extends StateNotifier<AsyncValue<bool>> {
  LeaveAgencyNotifier(this.ref) : super(const AsyncValue.data(false));

  final Ref ref;

  Future<Map<String, dynamic>> leaveAgency() async {
    try {
      state = const AsyncValue.loading();

      final result = await AgencyService.leaveAgency();

      if (result['success'] == true) {
        // Clear my agency provider
        ref.read(myAgencyProvider.notifier).clearMembership();
        // Clear stats if user is agent/owner
        ref.read(agencyStatsProvider.notifier).updateStats(null);
        state = const AsyncValue.data(true);
      } else {
        state = AsyncValue.error(
          result['message'] ?? 'Failed to leave agency',
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

