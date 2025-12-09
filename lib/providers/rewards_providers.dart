import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/daily_reward_model.dart';
import '../models/task_model.dart';
import '../models/ranking_model.dart';
import '../services/rewards_service.dart';
import '../services/tasks_service.dart';
import '../services/rankings_service.dart';

/// Daily Reward Status Provider
final dailyRewardStatusProvider =
    StateNotifierProvider<DailyRewardStatusNotifier, AsyncValue<DailyRewardStatus?>>((ref) {
  return DailyRewardStatusNotifier();
});

class DailyRewardStatusNotifier extends StateNotifier<AsyncValue<DailyRewardStatus?>> {
  DailyRewardStatusNotifier() : super(const AsyncValue.loading()) {
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    state = const AsyncValue.loading();
    try {
      final status = await RewardsService.getDailyRewardStatus();
      state = AsyncValue.data(status);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> refresh() async {
    await _loadStatus();
  }

  Future<Map<String, dynamic>> claimReward() async {
    final result = await RewardsService.claimDailyReward();
    if (result['success'] == true) {
      await _loadStatus(); // Refresh after claiming
    }
    return result;
  }
}

/// Reward History Provider
final rewardHistoryProvider =
    StateNotifierProvider<RewardHistoryNotifier, AsyncValue<List<DailyRewardModel>>>((ref) {
  return RewardHistoryNotifier();
});

class RewardHistoryNotifier extends StateNotifier<AsyncValue<List<DailyRewardModel>>> {
  RewardHistoryNotifier() : super(const AsyncValue.loading()) {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    state = const AsyncValue.loading();
    try {
      final history = await RewardsService.getRewardHistory();
      state = AsyncValue.data(history);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> refresh() async {
    await _loadHistory();
  }
}

/// Tasks Provider (with optional type filter)
final tasksProvider = StateNotifierProvider.family<TasksNotifier, AsyncValue<List<TaskModel>>, String?>(
  (ref, type) {
    return TasksNotifier(type);
  },
);

class TasksNotifier extends StateNotifier<AsyncValue<List<TaskModel>>> {
  final String? _type;

  TasksNotifier(this._type) : super(const AsyncValue.loading()) {
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    state = const AsyncValue.loading();
    try {
      final tasks = await TasksService.getTasks(type: _type);
      state = AsyncValue.data(tasks);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> refresh() async {
    await _loadTasks();
  }

  Future<Map<String, dynamic>> claimTaskReward(String taskId) async {
    final result = await TasksService.claimTaskReward(taskId);
    if (result['success'] == true) {
      await _loadTasks(); // Refresh after claiming
    }
    return result;
  }
}

/// Task Summary Provider
final taskSummaryProvider =
    StateNotifierProvider<TaskSummaryNotifier, AsyncValue<Map<String, int>?>>((ref) {
  return TaskSummaryNotifier();
});

class TaskSummaryNotifier extends StateNotifier<AsyncValue<Map<String, int>?>> {
  TaskSummaryNotifier() : super(const AsyncValue.loading()) {
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    state = const AsyncValue.loading();
    try {
      final summary = await TasksService.getTaskSummary();
      state = AsyncValue.data(summary);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> refresh() async {
    await _loadSummary();
  }
}

/// Rankings Provider
final rankingsProvider = StateNotifierProvider.family<
    RankingsNotifier,
    AsyncValue<Map<String, dynamic>?>,
    (RankingType, RankingPeriod)>((ref, params) {
  return RankingsNotifier(params.$1, params.$2);
});

class RankingsNotifier extends StateNotifier<AsyncValue<Map<String, dynamic>?>> {
  final RankingType _type;
  final RankingPeriod _period;

  RankingsNotifier(this._type, this._period) : super(const AsyncValue.loading()) {
    _loadRankings();
  }

  Future<void> _loadRankings() async {
    state = const AsyncValue.loading();
    try {
      final rankings = await RankingsService.getRankings(
        type: _type,
        period: _period,
      );
      state = AsyncValue.data(rankings);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> refresh() async {
    await _loadRankings();
  }

  Future<Map<String, dynamic>> claimReward(String periodStart) async {
    final result = await RankingsService.claimRankingReward(
      type: _type,
      period: _period,
      periodStart: periodStart,
    );
    if (result['success'] == true) {
      await _loadRankings(); // Refresh after claiming
    }
    return result;
  }
}

/// Ranking Rules Provider
final rankingRulesProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  return await RankingsService.getRankingRules();
});

