import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/ranking_model.dart';
import '../../providers/rewards_providers.dart';
import '../../widgets/custom_toaster.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/user_badge_widget.dart';

/// Rankings Screen
/// Displays Host and Rich leaderboards with daily/weekly periods
class RankingsScreen extends ConsumerStatefulWidget {
  const RankingsScreen({super.key});

  @override
  ConsumerState<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends ConsumerState<RankingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  RankingType _currentType = RankingType.host;
  RankingPeriod _currentPeriod = RankingPeriod.daily;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    setState(() {
      _currentType = _tabController.index == 0 ? RankingType.host : RankingType.rich;
    });
  }

  void _togglePeriod() {
    setState(() {
      _currentPeriod =
          _currentPeriod == RankingPeriod.daily ? RankingPeriod.weekly : RankingPeriod.daily;
    });
  }

  Future<void> _claimReward(String periodStart) async {
    final result = await ref
        .read(rankingsProvider((_currentType, _currentPeriod)).notifier)
        .claimReward(periodStart);

    if (mounted) {
      if (result['success'] == true) {
        ToasterService.showSuccess(
          context,
          'Claimed ${result['rewardCoins']} coins!',
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
    final rankingsAsync = ref.watch(rankingsProvider((_currentType, _currentPeriod)));

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text('Rankings', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1D1E33),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Period Toggle Button
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _togglePeriod,
              icon: Icon(
                _currentPeriod == RankingPeriod.daily ? Icons.today : Icons.calendar_month,
                color: const Color(0xFF4ECDC4),
              ),
              label: Text(
                _currentPeriod == RankingPeriod.daily ? 'Daily' : 'Weekly',
                style: const TextStyle(color: Color(0xFF4ECDC4), fontWeight: FontWeight.bold),
              ),
            ),
          ),
          // Rules Button
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: () => _showRulesDialog(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF4ECDC4),
          labelColor: const Color(0xFF4ECDC4),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Host Ranking'),
            Tab(text: 'Rich Ranking'),
          ],
        ),
      ),
      body: rankingsAsync.when(
        loading: () => _buildLoadingState(),
        error: (error, stack) => _buildErrorState(),
        data: (data) {
          if (data == null) {
            return _buildErrorState();
          }

          final rankings = data['rankings'] as List<RankingModel>;
          final userRanking = data['userRanking'] as UserRanking?;
          final period = data['period'] as Map<String, dynamic>;

          if (rankings.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(rankingsProvider((_currentType, _currentPeriod)).notifier).refresh(),
            color: const Color(0xFF4ECDC4),
            backgroundColor: const Color(0xFF1D1E33),
            child: Column(
              children: [
                // Period Info Card
                _buildPeriodInfoCard(period),

                // User's Ranking Card (if ranked)
                if (userRanking != null) _buildUserRankingCard(userRanking, period),

                // Rankings List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: rankings.length,
                    itemBuilder: (context, index) => _buildRankingCard(
                      rankings[index],
                      userRanking,
                      period,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPeriodInfoCard(Map<String, dynamic> period) {
    final start = DateTime.parse(period['start'] as String);
    final end = DateTime.parse(period['end'] as String);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4ECDC4), Color(0xFF556270)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _currentType == RankingType.host ? '🏆 Host Ranking' : '💰 Rich Ranking',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_formatDate(start)} - ${_formatDate(end)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _currentPeriod == RankingPeriod.daily ? 'DAILY' : 'WEEKLY',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserRankingCard(UserRanking userRanking, Map<String, dynamic> period) {
    final canClaim = userRanking.rewardCoins > 0 && !userRanking.rewardClaimed;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: canClaim ? const Color(0xFF4ECDC4) : Colors.grey.withOpacity(0.3),
          width: canClaim ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // Rank Badge
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF4ECDC4).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '#${userRanking.rank}',
                style: const TextStyle(
                  color: Color(0xFF4ECDC4),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Ranking',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${userRanking.score} ${_currentType == RankingType.host ? 'gifts received' : 'coins sent'}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          // Reward/Claim Button
          if (userRanking.rewardCoins > 0)
            ElevatedButton(
              onPressed: canClaim ? () => _claimReward(period['start'] as String) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4ECDC4),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                disabledBackgroundColor: Colors.grey[800],
              ),
              child: Text(
                canClaim ? 'Claim ${userRanking.rewardCoins}' : 'Claimed',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRankingCard(
    RankingModel ranking,
    UserRanking? userRanking,
    Map<String, dynamic> period,
  ) {
    final isCurrentUser = userRanking?.rank == ranking.rank;
    final medal = _getMedal(ranking.rank);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrentUser ? const Color(0xFF4ECDC4).withOpacity(0.1) : const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentUser ? const Color(0xFF4ECDC4) : Colors.grey.withOpacity(0.3),
          width: isCurrentUser ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // Rank Badge
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _getRankColor(ranking.rank).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: medal != null
                  ? Text(medal, style: const TextStyle(fontSize: 24))
                  : Text(
                      '#${ranking.rank}',
                      style: TextStyle(
                        color: _getRankColor(ranking.rank),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // User Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey[800],
            backgroundImage: ranking.user.profileImageUrl != null
                ? CachedNetworkImageProvider(ranking.user.profileImageUrl!)
                : null,
            child: ranking.user.profileImageUrl == null
                ? Text(
                    ranking.user.displayName[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        ranking.user.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    UserBadgesRow(
                      user: ranking.user,
                      badgeSize: 14.0,
                      showLabels: false,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${ranking.score} ${_currentType == RankingType.host ? 'gifts' : 'coins'}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          // Reward
          if (ranking.rewardCoins > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.toll, color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${ranking.rewardCoins}',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String? _getMedal(int rank) {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return null;
    }
  }

  Color _getRankColor(int rank) {
    if (rank <= 3) return Colors.amber;
    if (rank <= 10) return const Color(0xFF4ECDC4);
    return Colors.grey;
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}';
  }

  void _showRulesDialog() {
    final rulesAsync = ref.read(rankingRulesProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1D1E33),
        title: const Text('Ranking Rules', style: TextStyle(color: Colors.white)),
        content: rulesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => const Text(
            'Failed to load rules',
            style: TextStyle(color: Colors.grey),
          ),
          data: (rules) {
            if (rules == null) {
              return const Text('No rules available', style: TextStyle(color: Colors.grey));
            }

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildRuleSection('Host Ranking', rules['host'] as Map<String, dynamic>?),
                  const SizedBox(height: 16),
                  _buildRuleSection('Rich Ranking', rules['rich'] as Map<String, dynamic>?),
                  const SizedBox(height: 16),
                  _buildRewardsSection('Rewards', rules['rewards'] as Map<String, dynamic>?),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Color(0xFF4ECDC4))),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleSection(String title, Map<String, dynamic>? rules) {
    if (rules == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF4ECDC4),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          rules['description'] as String? ?? '',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Text(
          'Top ${rules['topCount'] ?? 40} positions',
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildRewardsSection(String title, Map<String, dynamic>? rewards) {
    if (rewards == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF4ECDC4),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...rewards.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${entry.key}: ${entry.value} coins',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 10,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ShimmerLoading(
          width: double.infinity,
          height: 80,
          borderRadius: BorderRadius.circular(12),
        ),
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
            'Failed to load rankings',
            style: TextStyle(color: Colors.grey[400], fontSize: 18),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () =>
                ref.read(rankingsProvider((_currentType, _currentPeriod)).notifier).refresh(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4ECDC4),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.leaderboard, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            'No rankings yet',
            style: TextStyle(color: Colors.grey[400], fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to rank!',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }
}

