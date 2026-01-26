import 'package:flutter/material.dart';
import '../../models/ranking_model.dart';
import '../../services/rankings_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class GiftLeaderboardScreen extends StatefulWidget {
  static const String route = "/utility/gift-leaderboard";

  const GiftLeaderboardScreen({Key? key}) : super(key: key);

  @override
  _GiftLeaderboardScreenState createState() => _GiftLeaderboardScreenState();
}

class _GiftLeaderboardScreenState extends State<GiftLeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  RankingPeriod _period = RankingPeriod.daily;
  bool _isLoading = false;
  List<RankingModel> _rankings = [];
  UserRanking? _userRanking;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadRankings();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    _loadRankings();
  }

  Future<void> _loadRankings() async {
    setState(() => _isLoading = true);

    final type =
        _tabController.index == 0 ? RankingType.host : RankingType.rich;
    final data = await RankingsService.getRankings(type: type, period: _period);

    if (mounted) {
      setState(() {
        _rankings = data?['rankings'] ?? [];
        _userRanking = data?['userRanking'];
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Rankings',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white),
            onPressed: () => _showRulesDialog(),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 100),
            _buildPeriodToggle(),
            _buildTabs(),
            Expanded(
              child:
                  _isLoading
                      ? const Center(
                        child: CircularProgressIndicator(
                          color: Colors.pinkAccent,
                        ),
                      )
                      : _rankings.isEmpty
                      ? _buildEmptyState()
                      : _buildRankingsList(),
            ),
            if (_userRanking != null) _buildCurrentUserRanking(),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          _buildToggleButton('Daily', RankingPeriod.daily),
          _buildToggleButton('Weekly', RankingPeriod.weekly),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String title, RankingPeriod period) {
    final isSelected = _period == period;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_period != period) {
            setState(() => _period = period);
            _loadRankings();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.pinkAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow:
                isSelected
                    ? [
                      BoxShadow(
                        color: Colors.pinkAccent.withOpacity(0.5),
                        blurRadius: 10,
                      ),
                    ]
                    : [],
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return TabBar(
      controller: _tabController,
      indicatorColor: Colors.pinkAccent,
      indicatorWeight: 3,
      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      tabs: const [Tab(text: 'Top Hosts'), Tab(text: 'Top Gifters')],
    );
  }

  Widget _buildRankingsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: _rankings.length,
      itemBuilder: (context, index) {
        final ranking = _rankings[index];
        return _buildRankingItem(ranking);
      },
    );
  }

  Widget _buildRankingItem(RankingModel ranking) {
    final isTop3 = ranking.rank <= 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border:
            isTop3
                ? Border.all(
                  color: _getMedalColor(ranking.rank).withOpacity(0.5),
                  width: 1,
                )
                : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              ranking.rank.toString(),
              style: TextStyle(
                color: isTop3 ? _getMedalColor(ranking.rank) : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          _buildAvatar(ranking.user.profileImageUrl, ranking.rank),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ranking.user.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Score: ${ranking.score}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (ranking.hasMedal)
            Text(ranking.medalIcon, style: const TextStyle(fontSize: 24)),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? url, int rank) {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (rank <= 3)
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  _getMedalColor(rank),
                  _getMedalColor(rank).withOpacity(0.3),
                ],
              ),
            ),
          ),
        CircleAvatar(
          radius: 24,
          backgroundImage: url != null ? CachedNetworkImageProvider(url) : null,
          child:
              url == null
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
        ),
      ],
    );
  }

  Color _getMedalColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // Gold
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return Colors.transparent;
    }
  }

  Widget _buildCurrentUserRanking() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F3D),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'My Rank',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  _userRanking!.rank > 0
                      ? '#${_userRanking!.rank}'
                      : 'Unranked',
                  style: const TextStyle(
                    color: Colors.pinkAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'My Score',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  _userRanking!.score.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.emoji_events_outlined,
            size: 80,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          const Text(
            'No rankings yet for this period',
            style: TextStyle(color: Colors.white60, fontSize: 16),
          ),
        ],
      ),
    );
  }

  void _showRulesDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            title: const Text(
              'Ranking Rules',
              style: TextStyle(color: Colors.white),
            ),
            content: const SingleChildScrollView(
              child: Text(
                '1. Host Ranking is based on the total value of gifts received.\n\n'
                '2. Rich Ranking is based on the total coins spent on gifts.\n\n'
                '3. Daily rankings reset at midnight UTC.\n\n'
                '4. Weekly rankings reset every Monday at midnight UTC.\n\n'
                '5. Top 40 users in each category are eligible for bonus rewards!',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Got it',
                  style: TextStyle(color: Colors.pinkAccent),
                ),
              ),
            ],
          ),
    );
  }
}
