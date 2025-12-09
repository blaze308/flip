import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/daily_reward_model.dart';
import '../../providers/rewards_providers.dart';
import '../../widgets/custom_toaster.dart';
import '../../widgets/shimmer_loading.dart';

/// Daily Rewards Screen
/// Displays 7-day reward cycle with claim functionality
class DailyRewardsScreen extends ConsumerStatefulWidget {
  const DailyRewardsScreen({super.key});

  @override
  ConsumerState<DailyRewardsScreen> createState() => _DailyRewardsScreenState();
}

class _DailyRewardsScreenState extends ConsumerState<DailyRewardsScreen> {
  bool _isClaiming = false;

  Future<void> _claimReward() async {
    if (_isClaiming) return;

    setState(() => _isClaiming = true);

    final result = await ref.read(dailyRewardStatusProvider.notifier).claimReward();

    if (mounted) {
      setState(() => _isClaiming = false);

      if (result['success'] == true) {
        final reward = result['reward'];
        ToasterService.showSuccess(
          context,
          'Claimed ${reward['coins']} coins! ${reward['diamonds'] > 0 ? '+ ${reward['diamonds']} diamonds!' : ''}',
        );
      } else {
        ToasterService.showError(
          context,
          result['message'] ?? 'Failed to claim reward',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rewardStatusAsync = ref.watch(dailyRewardStatusProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          'Daily Rewards',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1D1E33),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: rewardStatusAsync.when(
        loading: () => _buildLoadingState(),
        error: (error, stack) => _buildErrorState(),
        data: (rewardStatus) {
          if (rewardStatus == null) {
            return _buildErrorState();
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(dailyRewardStatusProvider.notifier).refresh(),
            color: const Color(0xFF4ECDC4),
            backgroundColor: const Color(0xFF1D1E33),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStreakCard(rewardStatus),
                  const SizedBox(height: 24),
                  _buildRewardGrid(rewardStatus),
                  const SizedBox(height: 24),
                  _buildClaimButton(rewardStatus),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShimmerLoading(
            width: 200,
            height: 100,
            borderRadius: BorderRadius.circular(16),
          ),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.8,
            ),
            itemCount: 7,
            itemBuilder: (context, index) => ShimmerLoading(
              width: double.infinity,
              height: double.infinity,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            'Failed to load rewards',
            style: TextStyle(color: Colors.grey[400], fontSize: 18),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.read(dailyRewardStatusProvider.notifier).refresh(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4ECDC4),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCard(DailyRewardStatus rewardStatus) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4ECDC4), Color(0xFF556270)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_fire_department,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${rewardStatus.streakCount} Day Streak',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  rewardStatus.canClaim
                      ? 'Claim your reward now!'
                      : 'Come back tomorrow!',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardGrid(DailyRewardStatus rewardStatus) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: rewardStatus.allRewards.length,
      itemBuilder: (context, index) {
        final reward = rewardStatus.allRewards[index];
        final isNextDay = reward.day == rewardStatus.nextDay;
        final isPastDay = reward.day < rewardStatus.nextDay ||
            (rewardStatus.streakCount >= 7 && reward.day < rewardStatus.nextDay);

        return _buildRewardCard(reward, isNextDay, isPastDay);
      },
    );
  }

  Widget _buildRewardCard(DailyRewardModel reward, bool isNextDay, bool isPastDay) {
    return Container(
      decoration: BoxDecoration(
        color: isNextDay
            ? const Color(0xFF4ECDC4).withOpacity(0.2)
            : const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isNextDay
              ? const Color(0xFF4ECDC4)
              : isPastDay
                  ? Colors.green.withOpacity(0.5)
                  : Colors.grey.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isPastDay)
            const Icon(Icons.check_circle, color: Colors.green, size: 20)
          else
            Text(
              'Day ${reward.day}',
              style: TextStyle(
                color: isNextDay ? const Color(0xFF4ECDC4) : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          const SizedBox(height: 8),
          const Icon(Icons.toll, color: Colors.amber, size: 24),
          const SizedBox(height: 4),
          Text(
            '${reward.coins}',
            style: TextStyle(
              color: isNextDay ? Colors.white : Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (reward.diamonds > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.diamond, color: Colors.cyan, size: 16),
                const SizedBox(width: 2),
                Text(
                  '+${reward.diamonds}',
                  style: const TextStyle(
                    color: Colors.cyan,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildClaimButton(DailyRewardStatus rewardStatus) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: rewardStatus.canClaim && !_isClaiming ? _claimReward : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4ECDC4),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          disabledBackgroundColor: Colors.grey[800],
        ),
        child: _isClaiming
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                rewardStatus.canClaim
                    ? 'Claim ${rewardStatus.nextReward.coins} Coins'
                    : 'Already Claimed Today',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}

