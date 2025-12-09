import 'package:flip/screens/zego_livestreaming.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../models/live_stream_model.dart';
import '../services/live_streaming_service.dart';
import '../services/token_auth_service.dart';
import '../widgets/custom_toaster.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/user_badge_widget.dart';
import 'agora_video_party_screen.dart';
import 'agora_audio_party_screen.dart';

/// Live Streams List Screen
/// Shows all active live streams with filtering options
class LiveListScreen extends StatefulWidget {
  const LiveListScreen({super.key});

  @override
  State<LiveListScreen> createState() => _LiveListScreenState();
}

class _LiveListScreenState extends State<LiveListScreen>
    with AutomaticKeepAliveClientMixin {
  List<LiveStreamModel> _liveStreams = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // all, live, party, audio, battle
  Timer? _refreshTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadLiveStreams();

    // Auto-refresh every 10 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadLiveStreams(showLoading: false);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadLiveStreams({bool showLoading = true}) async {
    if (showLoading) {
      setState(() => _isLoading = true);
    }

    try {
      final liveStreams = await LiveStreamingService.getActiveLiveStreams(
        liveType: _selectedFilter == 'all' ? null : _selectedFilter,
        limit: 50,
      );

      if (mounted) {
        setState(() {
          _liveStreams = liveStreams;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading live streams: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        if (showLoading) {
          ToasterService.showError(context, 'Failed to load live streams');
        }
      }
    }
  }

  void _onFilterChanged(String filter) {
    if (_selectedFilter != filter) {
      setState(() {
        _selectedFilter = filter;
      });
      _loadLiveStreams();
    }
  }

  void _onLiveTap(LiveStreamModel live) async {
    HapticFeedback.lightImpact();

    // Navigate to appropriate screen based on live type
    if (live.liveType == 'live') {
      // ZegoCloud regular live - use our migrated screen
      final user = TokenAuthService.currentUser;
      final prefs = await SharedPreferences.getInstance();

      if (user == null) {
        ToasterService.showError(context, 'Please login first');
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => ZegoLivestreaming(
                liveID: live.streamingChannel,
                isHost: false, // Viewer mode
                currentUser: user,
                preferences: prefs,
                mLiveStreamingModel: live,
              ),
        ),
      ).then((_) => _loadLiveStreams(showLoading: false));
    } else if (live.liveType == 'party') {
      // Agora VIDEO party
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AgoraVideoPartyScreen(liveStream: live),
        ),
      ).then((_) => _loadLiveStreams(showLoading: false));
    } else if (live.liveType == 'audio') {
      // Agora AUDIO party
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AgoraAudioPartyScreen(liveStream: live),
        ),
      ).then((_) => _loadLiveStreams(showLoading: false));
    }
  }

  void _onStartLive() async {
    HapticFeedback.lightImpact();

    // Check authentication
    final user = TokenAuthService.currentUser;
    if (user == null) {
      ToasterService.showError(context, 'Please login to start a live');
      return;
    }

    // Show live type selection bottom sheet
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildLiveTypeSelector(),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: CustomScrollView(
        slivers: [_buildAppBar(), _buildFilterChips(), _buildLiveGrid()],
      ),
      floatingActionButton: _buildStartLiveButton(),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: const Color(0xFF2A2A2A),
      elevation: 0,
      floating: true,
      pinned: false,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'LIVE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Live Streams',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: () => _loadLiveStreams(),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    return SliverToBoxAdapter(
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _buildFilterChip('All', 'all', Icons.grid_view),
            const SizedBox(width: 8),
            _buildFilterChip('Live', 'live', Icons.videocam),
            const SizedBox(width: 8),
            _buildFilterChip('Party', 'party', Icons.people),
            const SizedBox(width: 8),
            _buildFilterChip('Audio', 'audio', Icons.mic),
            const SizedBox(width: 8),
            _buildFilterChip('Battle', 'battle', Icons.flash_on),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, IconData icon) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () => _onFilterChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4ECDC4) : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF4ECDC4) : const Color(0xFF3A3A3A),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.black : Colors.white,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveGrid() {
    if (_isLoading) {
      return SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => const LiveStreamShimmer(),
            childCount: 6,
          ),
        ),
      );
    }

    if (_liveStreams.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(60),
                ),
                child: const Icon(
                  Icons.videocam_off_outlined,
                  color: Color(0xFF4ECDC4),
                  size: 60,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'No Live Streams',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 48),
                child: Text(
                  'Be the first to go live!\nTap the button below to start streaming',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final live = _liveStreams[index];
          return _buildLiveCard(live);
        }, childCount: _liveStreams.length),
      ),
    );
  }

  Widget _buildLiveCard(LiveStreamModel live) {
    return GestureDetector(
      onTap: () => _onLiveTap(live),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFF2A2A2A),
        ),
        child: Stack(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child:
                  live.author?.profileImageUrl != null
                      ? CachedNetworkImage(
                        imageUrl: live.author!.profileImageUrl!,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        placeholder:
                            (context, url) => Container(
                              color: const Color(0xFF3A3A3A),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF4ECDC4),
                                ),
                              ),
                            ),
                        errorWidget:
                            (context, url, error) => Container(
                              color: const Color(0xFF3A3A3A),
                              child: const Icon(
                                Icons.person,
                                size: 60,
                                color: Colors.grey,
                              ),
                            ),
                      )
                      : Container(
                        color: const Color(0xFF3A3A3A),
                        child: const Icon(
                          Icons.person,
                          size: 60,
                          color: Colors.grey,
                        ),
                      ),
            ),

            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Live badge and viewers
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.visibility,
                              color: Colors.white,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatViewers(live.viewersCount),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Host info
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundImage:
                            live.author?.profileImageUrl != null
                                ? CachedNetworkImageProvider(
                                  live.author!.profileImageUrl!,
                                )
                                : null,
                        child:
                            live.author?.profileImageUrl == null
                                ? const Icon(Icons.person, size: 16)
                                : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    live.author?.displayName ?? 'Unknown',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (live.author != null) ...[
                                  const SizedBox(width: 4),
                                  UserBadgesRow(
                                    user: live.author!,
                                    badgeSize: 14.0,
                                    showLabels: false,
                                  ),
                                ],
                              ],
                            ),
                            if (live.title.isNotEmpty)
                              Text(
                                live.title,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Live type indicator
            Positioned(
              bottom: 12,
              right: 12,
              child: _buildLiveTypeIcon(live.liveType),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveTypeIcon(String liveType) {
    IconData icon;
    Color color;

    switch (liveType) {
      case 'party':
        icon = Icons.people;
        color = const Color(0xFF667eea);
        break;
      case 'audio':
        icon = Icons.mic;
        color = const Color(0xFFf093fb);
        break;
      case 'battle':
        icon = Icons.flash_on;
        color = const Color(0xFFfcb69f);
        break;
      default:
        icon = Icons.videocam;
        color = const Color(0xFF4ECDC4);
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 16),
    );
  }

  Widget _buildStartLiveButton() {
    return FloatingActionButton.extended(
      onPressed: _onStartLive,
      backgroundColor: const Color(0xFF4ECDC4),
      icon: const Icon(Icons.videocam, color: Colors.black),
      label: const Text(
        'Go Live',
        style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildLiveTypeSelector() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF2A2A2A),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Choose Live Type',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 24),

            // Live types
            _buildLiveTypeOption(
              'Live',
              'Stream video to your followers',
              Icons.videocam,
              const Color(0xFF4ECDC4),
              () async {
                Navigator.pop(context);

                // Get current user and preferences
                final user = TokenAuthService.currentUser;
                final prefs = await SharedPreferences.getInstance();

                if (user == null) {
                  ToasterService.showError(context, 'Please login first');
                  return;
                }

                // Create a new live stream
                try {
                  final liveStream =
                      await LiveStreamingService.createLiveStream(
                        liveType: 'live',
                        streamingChannel:
                            DateTime.now().millisecondsSinceEpoch.toString(),
                        authorUid: int.parse(
                          user.id.hashCode.toString().substring(0, 8),
                        ),
                      );

                  // Navigate to our new Zego live streaming screen
                  if (mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => ZegoLivestreaming(
                              liveID: liveStream.streamingChannel,
                              isHost: true,
                              currentUser: user,
                              preferences: prefs,
                              mLiveStreamingModel: liveStream,
                            ),
                      ),
                    );
                  }
                } catch (e) {
                  ToasterService.showError(
                    context,
                    'Failed to start live stream',
                  );
                }
              },
            ),

            _buildLiveTypeOption(
              'Party Live',
              'Video chat with multiple hosts',
              Icons.people,
              const Color(0xFF667eea),
              () async {
                Navigator.pop(context);

                // Get current user
                final user = TokenAuthService.currentUser;

                if (user == null) {
                  ToasterService.showError(context, 'Please login first');
                  return;
                }

                // Create a new live stream
                try {
                  final liveStream =
                      await LiveStreamingService.createLiveStream(
                        liveType: 'party',
                        streamingChannel:
                            DateTime.now().millisecondsSinceEpoch.toString(),
                        authorUid: int.parse(
                          user.id.hashCode.toString().substring(0, 8),
                        ),
                        partyType: 'video',
                        numberOfChairs: 6,
                      );

                  // Navigate to Agora video party screen
                  if (mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => AgoraVideoPartyScreen(
                              liveStream: liveStream,
                              isHost: true,
                            ),
                      ),
                    );
                  }
                } catch (e) {
                  ToasterService.showError(
                    context,
                    'Failed to start party live',
                  );
                }
              },
            ),

            _buildLiveTypeOption(
              'Audio Party',
              'Voice chat room with seats',
              Icons.mic,
              const Color(0xFFf093fb),
              () async {
                Navigator.pop(context);

                // Get current user
                final user = TokenAuthService.currentUser;

                if (user == null) {
                  ToasterService.showError(context, 'Please login first');
                  return;
                }

                // Create a new live stream
                try {
                  final liveStream =
                      await LiveStreamingService.createLiveStream(
                        liveType: 'audio',
                        streamingChannel:
                            DateTime.now().millisecondsSinceEpoch.toString(),
                        authorUid: int.parse(
                          user.id.hashCode.toString().substring(0, 8),
                        ),
                        partyType: 'audio',
                        numberOfChairs: 6,
                      );

                  // Navigate to Agora audio party screen
                  if (mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => AgoraVideoPartyScreen(
                              liveStream: liveStream,
                              isHost: true,
                            ),
                      ),
                    );
                  }
                } catch (e) {
                  ToasterService.showError(
                    context,
                    'Failed to start audio party',
                  );
                }
              },
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveTypeOption(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Colors.grey, fontSize: 14),
      ),
      onTap: onTap,
    );
  }

  String _formatViewers(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}
