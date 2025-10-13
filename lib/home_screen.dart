import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'services/token_auth_service.dart';
import 'services/message_service.dart';
import 'services/post_service.dart';
import 'services/event_bus.dart';
import 'services/optimistic_ui_service.dart';
import 'services/contextual_auth_service.dart';
import 'services/video_downloader_service.dart';
import 'widgets/custom_toaster.dart';
import 'widgets/post_menu_widget.dart';
import 'widgets/loading_button.dart';
import 'widgets/shimmer_loading.dart';
import 'widgets/comments_bottom_sheet.dart';
import 'widgets/connection_status_indicator.dart';
import 'widgets/video_download_progress.dart';
import 'models/post_model.dart';
import 'models/story_model.dart';
import 'create_story_type_screen.dart';
import 'create_post_type_screen.dart';
import 'story_viewer_screen.dart';
import 'immersive_viewer_screen.dart';
import 'screens/message_list_screen.dart';
import 'complete_profile_screen.dart';
import 'providers/app_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin, OptimisticUIMixin {
  late PageController _pageController;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;
  late ScrollController _scrollController;
  StreamSubscription<PostCreatedEvent>? _postCreatedSubscription;

  // Double tap to exit
  DateTime? _lastBackPressed;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _scrollController = ScrollController();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeInOut),
    );
    _fabAnimationController.forward();

    // Listen for post creation events
    _postCreatedSubscription = EventBus().on<PostCreatedEvent>().listen((
      event,
    ) {
      debugPrint(
        '🔄 Post created event received: ${event.postType} post ${event.postId}',
      );
      _refreshAfterPostCreation();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
    _fabAnimationController.dispose();
    _postCreatedSubscription?.cancel();
    super.dispose();
  }

  // Removed manual auth state handling - now using Riverpod providers

  // Removed - using Riverpod providers instead

  Future<void> _handleLogout() async {
    try {
      await TokenAuthService.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      if (mounted) {
        context.showErrorToaster(
          MessageService.getMessage('error'),
          devMessage: 'Logout failed: ${e.toString()}',
        );
      }
    }
  }

  void _onBottomNavTap(int index) {
    ref.read(currentTabProvider.notifier).state = index;

    // Special handling for Reels tab - navigate to Reels screen
    if (index == 1) {
      _navigateToReels();
      return;
    }

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _navigateToReels() async {
    // Get all video posts
    final postsAsync = ref.read(postsProvider);
    final allPosts = postsAsync.maybeWhen(
      data: (posts) => posts,
      orElse: () => <PostModel>[],
    );

    // Filter video posts only
    final videoPosts =
        allPosts.where((post) => post.type == PostType.video).toList();

    if (videoPosts.isEmpty) {
      ToasterService.showInfo(context, 'No video posts available yet');
      return;
    }

    // Navigate to immersive viewer with video posts only
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => ImmersiveViewerScreen(
              posts: videoPosts,
              initialIndex: 0,
              onLikeToggle: (postId) {
                ref.read(postsProvider.notifier).refresh();
              },
              onPostUpdated: () {
                ref.read(postsProvider.notifier).refresh();
              },
            ),
      ),
    );

    // Reset tab to home after returning
    ref.read(currentTabProvider.notifier).state = 0;
  }

  Future<void> _toggleLike(String postId) async {
    // Check authentication first
    final canLike = await ContextualAuthService.canLike(context);
    if (!canLike) return;

    // Use Riverpod provider for like toggle
    await ref.read(postsProvider.notifier).toggleLike(postId);
  }

  // Method to refresh after post creation
  Future<void> _refreshAfterPostCreation() async {
    debugPrint('🔄 Refreshing home screen after post creation...');
    await ref.read(postsProvider.notifier).refresh();

    // Scroll to top to show the new post
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _sharePost(String postId) async {
    HapticFeedback.lightImpact();

    try {
      final result = await PostService.sharePost(postId);
      if (result.success) {
        await ref.read(postsProvider.notifier).refresh();
        if (mounted) {
          ToasterService.showSuccess(context, 'Post shared successfully!');
        }
      } else {
        if (mounted) {
          ToasterService.showError(
            context,
            'Failed to share post. Please try again.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ToasterService.showError(
          context,
          'Failed to share post. Please check your connection.',
        );
      }
    }
  }

  Future<void> _downloadPost(PostModel post) async {
    HapticFeedback.lightImpact();

    double downloadProgress = 0.0;
    OverlayEntry? progressOverlay;

    try {
      // Show download progress overlay
      progressOverlay = OverlayEntry(
        builder:
            (context) => Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Center(
                child: CompactDownloadProgress(progress: downloadProgress),
              ),
            ),
      );
      Overlay.of(context).insert(progressOverlay);

      if (post.type == PostType.video && post.videoUrl != null) {
        // Download video
        final fileName =
            'flip_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
        final result = await VideoDownloaderService.downloadVideo(
          videoUrl: post.videoUrl!,
          fileName: fileName,
          onProgress: (progress) {
            downloadProgress = progress;
            progressOverlay?.markNeedsBuild();
          },
        );

        progressOverlay.remove();

        if (mounted) {
          if (result.success) {
            // Show success indicator
            final successOverlay = OverlayEntry(
              builder:
                  (context) => const Positioned(
                    bottom: 100,
                    left: 0,
                    right: 0,
                    child: Center(child: DownloadSuccessIndicator()),
                  ),
            );
            Overlay.of(context).insert(successOverlay);
            await Future.delayed(const Duration(seconds: 2));
            successOverlay.remove();

            context.showSuccessToaster('Video saved to gallery!');
          } else {
            context.showErrorToaster(result.message);
          }
        }
      } else if (post.type == PostType.image &&
          post.imageUrls != null &&
          post.imageUrls!.isNotEmpty) {
        // Download first image (or all images if multiple)
        final imageUrl = post.imageUrls!.first;
        final fileName =
            'flip_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final result = await MediaDownloaderService.downloadImage(
          imageUrl: imageUrl,
          fileName: fileName,
          onProgress: (progress) {
            downloadProgress = progress;
            progressOverlay?.markNeedsBuild();
          },
        );

        progressOverlay.remove();

        if (mounted) {
          if (result.success) {
            // Show success indicator
            final successOverlay = OverlayEntry(
              builder:
                  (context) => const Positioned(
                    bottom: 100,
                    left: 0,
                    right: 0,
                    child: Center(child: DownloadSuccessIndicator()),
                  ),
            );
            Overlay.of(context).insert(successOverlay);
            await Future.delayed(const Duration(seconds: 2));
            successOverlay.remove();

            context.showSuccessToaster('Image saved to gallery!');
          } else {
            context.showErrorToaster(result.message);
          }
        }
      }
    } catch (e) {
      progressOverlay?.remove();
      if (mounted) {
        context.showErrorToaster('Failed to download. Please try again.');
      }
      print('❌ Error downloading post: $e');
    }
  }

  void _showCommentsSheet(PostModel post) {
    HapticFeedback.lightImpact();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => CommentsBottomSheet(
            post: post,
            onCommentAdded: () {
              // Refresh posts to update comment count
              ref.read(postsProvider.notifier).refresh();
            },
          ),
    );
  }

  Future<bool> _onWillPop() async {
    final now = DateTime.now();
    const exitTimeGap = Duration(seconds: 2);

    if (_lastBackPressed == null ||
        now.difference(_lastBackPressed!) > exitTimeGap) {
      _lastBackPressed = now;

      // Show toast message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Press back again to exit',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF2A2A2A),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );

      return false; // Don't exit
    }

    return true; // Exit the app
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);

    if (appState.isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            StoryShimmer(),
            SizedBox(height: 16),
            PostShimmer(),
            SizedBox(height: 16),
            PostShimmer(),
          ],
        ),
      );
    }

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        body: Column(
          children: [
            // Connection status indicator
            const ConnectionStatusIndicator(),
            // Main content
            Expanded(
              child: Stack(
                children: [
                  // Main content with bottom padding to avoid overlap
                  Positioned.fill(
                    bottom: 80, // Height of bottom navigation
                    child: PageView(
                      controller: _pageController,
                      physics:
                          const NeverScrollableScrollPhysics(), // Disable swipe
                      onPageChanged: (index) {
                        ref.read(currentTabProvider.notifier).state = index;
                      },
                      children: [
                        _buildHomeTab(), // Home/Feed
                        _buildHomeTab(), // Reels (handled by navigation)
                        _buildLiveTab(), // Live Streams
                        _buildChatTab(), // Chat/Messages
                        _buildProfileTab(), // Profile
                      ],
                    ),
                  ),

                  // Bottom navigation positioned on top
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(25),
                          topRight: Radius.circular(25),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        top: false,
                        child: Container(
                          height: 80,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildNavItem(Icons.home, 0, 'Home'),
                              _buildNavItem(
                                Icons.play_circle_outline,
                                1,
                                'Reels',
                              ),
                              _buildCenterNavItem(), // Center create button
                              _buildNavItem(
                                Icons.chat_bubble_outline,
                                3,
                                'Chat',
                              ),
                              _buildNavItem(Icons.person_outline, 4, 'Profile'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index, String label) {
    final currentTab = ref.watch(currentTabProvider);
    final isSelected = currentTab == index;
    return GestureDetector(
      onTap: () => _onBottomNavTap(index),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ), // Increased tap area
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color:
                  isSelected
                      ? const Color(0xFF4ECDC4)
                      : const Color(0xFF8E8E93),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color:
                    isSelected
                        ? const Color(0xFF4ECDC4)
                        : const Color(0xFF8E8E93),
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterNavItem() {
    final currentTab = ref.watch(currentTabProvider);
    final isSelected = currentTab == 2;
    return ScaleTransition(
      scale: _fabAnimation,
      child: GestureDetector(
        onTap: () => _onBottomNavTap(2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4ECDC4), Color(0xFF44A08D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4ECDC4).withOpacity(0.4),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(Icons.live_tv_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 4),
            Text(
              'Live',
              style: TextStyle(
                color:
                    isSelected
                        ? const Color(0xFF4ECDC4)
                        : const Color(0xFF8E8E93),
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          ref.read(postsProvider.notifier).refresh(),
          ref.read(storiesProvider.notifier).refresh(),
        ]);
      },
      color: const Color(0xFF4ECDC4),
      backgroundColor: const Color(0xFF2A2A2A),
      child: CustomScrollView(
        slivers: [_buildAppBar(), _buildStoriesSection(), _buildPostsList()],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: const Color(0xFF1A1A1A),
      elevation: 0,
      floating: true,
      pinned: false,
      leading: null,
      title: Row(
        children: [
          Image.asset('assets/images/logo.png', width: 32, height: 32),

          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'ANCIENT',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 4.0,
                    color: Colors.white,
                  ),
                ),
                TextSpan(
                  text: 'FLIP',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 4.0,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () {
            // Settings
          },
          icon: const Icon(Icons.settings, color: Colors.white),
        ),
        IconButton(
          onPressed: () {
            // Search
          },
          icon: const Icon(Icons.search, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildStoriesSection() {
    final storiesAsync = ref.watch(storiesProvider);

    return storiesAsync.when(
      data: (stories) {
        final currentUser = ref.watch(currentUserProvider);

        // Separate current user's stories and put them first
        final currentUserStories = <StoryFeedItem>[];
        final otherStories = <StoryFeedItem>[];

        for (final story in stories) {
          if (story.userId == currentUser?.id) {
            currentUserStories.add(story);
          } else {
            otherStories.add(story);
          }
        }

        // Build final list: current user's stories first, then others
        final orderedStories = [...currentUserStories, ...otherStories];

        // Always show the stories section (with create button), even if no stories exist
        return SliverToBoxAdapter(
          child: Container(
            height: 100,
            margin: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                // LEFT: Create button (constant, always visible)
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 8),
                  child: _buildCreateButton(),
                ),
                // RIGHT: Scrollable stories list (empty if no stories)
                if (orderedStories.isNotEmpty)
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(right: 16),
                      itemCount: orderedStories.length,
                      itemBuilder: (context, index) {
                        final storyFeedItem = orderedStories[index];

                        return GestureDetector(
                          onTap: () => _viewUserStories(storyFeedItem),
                          child: Container(
                            margin: const EdgeInsets.only(right: 16),
                            child: Column(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient:
                                        storyFeedItem.hasUnviewedStories
                                            ? const LinearGradient(
                                              colors: [
                                                Color(0xFF4ECDC4),
                                                Color(0xFF44A08D),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            )
                                            : null,
                                    border:
                                        !storyFeedItem.hasUnviewedStories
                                            ? Border.all(
                                              color: Colors.grey,
                                              width: 2,
                                            )
                                            : null,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(2),
                                    child: CircleAvatar(
                                      radius: 28,
                                      backgroundColor: Colors.grey[800],
                                      backgroundImage:
                                          storyFeedItem.userAvatar != null &&
                                                  storyFeedItem
                                                      .userAvatar!
                                                      .isNotEmpty
                                              ? NetworkImage(
                                                storyFeedItem.userAvatar!,
                                              )
                                              : null,
                                      child:
                                          storyFeedItem.userAvatar == null ||
                                                  storyFeedItem
                                                      .userAvatar!
                                                      .isEmpty
                                              ? Text(
                                                storyFeedItem
                                                        .username
                                                        .isNotEmpty
                                                    ? storyFeedItem.username[0]
                                                        .toUpperCase()
                                                    : '?',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              )
                                              : null,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: 60,
                                  child: Text(
                                    storyFeedItem.username,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
      loading:
          () => SliverToBoxAdapter(
            child: Container(
              height: 100,
              margin: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  // LEFT: Create button
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 8),
                    child: _buildCreateButton(),
                  ),
                  // RIGHT: Loading shimmers
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(right: 16),
                      itemCount: 5,
                      itemBuilder: (context, index) => const StoryShimmer(),
                    ),
                  ),
                ],
              ),
            ),
          ),
      error:
          (error, stack) => SliverToBoxAdapter(
            child: Container(
              height: 100,
              margin: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  // LEFT: Create button (always visible even on error)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 8),
                    child: _buildCreateButton(),
                  ),
                  // RIGHT: Error message
                  Expanded(
                    child: Center(
                      child: Text(
                        'Failed to load stories',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildCreateButton() {
    final currentUser = ref.watch(currentUserProvider);

    return GestureDetector(
      onTap: () => _showCreateOptions(context, userStory: null),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey, width: 2),
                ),
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.grey[800],
                  backgroundImage:
                      currentUser?.photoURL != null &&
                              currentUser!.photoURL!.isNotEmpty
                          ? NetworkImage(currentUser.photoURL!)
                          : null,
                  child:
                      currentUser?.photoURL == null ||
                              currentUser!.photoURL!.isEmpty
                          ? Text(
                            currentUser?.displayName?.isNotEmpty == true
                                ? currentUser!.displayName![0].toUpperCase()
                                : currentUser?.email?.isNotEmpty == true
                                ? currentUser!.email![0].toUpperCase()
                                : 'Y',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                          : null,
                ),
              ),
              // Plus button overlay
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4ECDC4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const SizedBox(
            width: 60,
            child: Text(
              'Create',
              style: TextStyle(color: Colors.white, fontSize: 12),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _viewUserStories(StoryFeedItem storyFeedItem) {
    final storiesAsync = ref.read(storiesProvider);
    storiesAsync.whenData((stories) {
      final userIndex = stories.indexOf(storyFeedItem);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (context) => StoryViewerScreen(
                storyFeedItems: stories,
                initialUserIndex: userIndex,
                initialStoryIndex: 0,
              ),
        ),
      );
    });
  }

  Widget _buildPostsList() {
    final postsAsync = ref.watch(postsProvider);

    return postsAsync.when(
      data: (posts) {
        if (posts.isEmpty) {
          return SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.post_add, size: 64, color: Colors.grey[600]),
                  const SizedBox(height: 16),
                  Text(
                    'No posts yet',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start creating posts to see them here',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      final result = await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const CreatePostTypeScreen(),
                        ),
                      );

                      // If a new post was created, refresh from database
                      if (result is PostModel) {
                        await ref.read(postsProvider.notifier).refresh();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4ECDC4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'Create Your First Post',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final post = posts[index];
            final isLastPost = index == posts.length - 1;

            return Column(
              children: [
                _buildPostCard(post),
                // Add extra bottom padding for the last post to ensure actions are visible
                if (isLastPost) const SizedBox(height: 100),
              ],
            );
          }, childCount: posts.length),
        );
      },
      loading:
          () => SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => const PostShimmer(),
              childCount: 3,
            ),
          ),
      error:
          (error, stack) => SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey[600]),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load posts',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => ref.read(postsProvider.notifier).refresh(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4ECDC4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'Retry',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildPostCard(PostModel post) {
    final postsAsync = ref.watch(postsProvider);
    final posts = postsAsync.maybeWhen(
      data: (posts) => posts,
      orElse: () => <PostModel>[],
    );

    return GestureDetector(
      onTap: () {
        // Navigate to immersive viewer with all posts
        final currentIndex = posts.indexWhere((p) => p.id == post.id);
        if (currentIndex != -1) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder:
                  (context) => ImmersiveViewerScreen(
                    posts: posts,
                    initialIndex: currentIndex,
                    onLikeToggle: (postId) {
                      // Refresh posts after like toggle
                      ref.read(postsProvider.notifier).refresh();
                    },
                    onPostUpdated: () {
                      // Refresh posts after update
                      ref.read(postsProvider.notifier).refresh();
                    },
                  ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Post header
            _buildPostHeader(post),

            // Post content based on type
            _buildPostContent(post),

            // Post actions
            _buildPostActions(post),
          ],
        ),
      ),
    );
  }

  Widget _buildPostHeader(PostModel post) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[800],
            ),
            child:
                post.userAvatar != null
                    ? ClipOval(
                      child: Image.network(
                        post.userAvatar!,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 20,
                          );
                        },
                      ),
                    )
                    : const Icon(Icons.person, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      post.username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (post.isFollowingUser) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4ECDC4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ],
                  ],
                ),
                Row(
                  children: [
                    Text(
                      post.timeAgo,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    if (post.location != null) ...[
                      const Text(
                        ' • ',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      Icon(Icons.location_on, color: Colors.grey, size: 12),
                      Text(
                        post.location!,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          PostMenuWidget(
            post: post,
            onPostUpdated: () {
              // Refresh the post data
              ref.read(postsProvider.notifier).refresh();
            },
            onPostHidden: () {
              // Database-first: refresh posts from backend
              ref.read(postsProvider.notifier).refresh();
            },
            onFollowStatusChanged: (String userId, bool isFollowing) {
              // Refresh posts to get updated follow status
              ref.read(postsProvider.notifier).refresh();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPostContent(PostModel post) {
    switch (post.type) {
      case PostType.text:
        return _buildTextPost(post);
      case PostType.image:
        return _buildImagePost(post);
      case PostType.video:
        return _buildVideoPost(post);
    }
  }

  Widget _buildTextPost(PostModel post) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: post.backgroundColor ?? const Color(0xFF4ECDC4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.content != null)
            Text(
              post.content!,
              style: TextStyle(
                color: post.textColor ?? Colors.white,
                fontSize: post.fontSize ?? 16,
                fontWeight: post.fontWeight ?? FontWeight.w500,
                fontFamily: post.fontFamily,
                height: 1.4,
              ),
              textAlign: post.textAlign ?? TextAlign.left,
            ),
        ],
      ),
    );
  }

  Widget _buildImagePost(PostModel post) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (post.content != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              post.content!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.4,
              ),
            ),
          ),
        const SizedBox(height: 12),
        if (post.imageUrls != null && post.imageUrls!.isNotEmpty)
          _ImageSliderWidget(imageUrls: post.imageUrls!),
      ],
    );
  }

  Widget _buildVideoPost(PostModel post) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (post.content != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              post.content!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.4,
              ),
            ),
          ),
        const SizedBox(height: 12),
        if (post.videoThumbnail != null)
          Container(
            height: 300,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    post.videoThumbnail!,
                    width: double.infinity,
                    height: 300,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: double.infinity,
                        height: 300,
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.video_library,
                          color: Colors.white,
                          size: 50,
                        ),
                      );
                    },
                  ),
                ),
                // Play button overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.play_circle_fill,
                        color: Colors.white,
                        size: 60,
                      ),
                    ),
                  ),
                ),
                // Duration badge
                if (post.videoDuration != null)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        post.formattedDuration,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPostActions(PostModel post) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          OptimisticButton(
            onPressed: () => _toggleLike(post.id),
            isActive: post.likes > 0, // Red if anyone liked it
            activeColor: post.isLiked ? Colors.red : Colors.white,
            inactiveColor: Colors.white,
            isDisabled: isButtonDisabled('like_${post.id}'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.favorite, size: 24),
                const SizedBox(width: 8),
                Text(
                  '${post.likes}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => _showCommentsSheet(post),
            child: Container(
              padding: const EdgeInsets.all(8), // Increased tap area
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.chat_bubble_outline,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${post.comments}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => _sharePost(post.id),
            child: Container(
              padding: const EdgeInsets.all(8), // Increased tap area
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.share, color: Colors.white, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    '${post.shares}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Download button for images and videos
          if (post.type == PostType.image || post.type == PostType.video) ...[
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => _downloadPost(post),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: const Icon(
                  Icons.download,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChatTab() {
    return const MessageListScreen();
  }

  Widget _buildLiveTab() {
    // TODO: Implement live streams when feature is developed
    // This will show all active live streams
    return Center(
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
              Icons.videocam_outlined,
              color: Color(0xFF4ECDC4),
              size: 60,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Live Streams',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Live streaming feature coming soon!\nWatch and interact with creators in real-time.',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4ECDC4),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'In Development',
                  style: TextStyle(
                    color: Color(0xFF4ECDC4),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    final currentUser = ref.watch(currentUserProvider);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[800],
                image:
                    currentUser?.photoURL != null
                        ? DecorationImage(
                          image: NetworkImage(currentUser!.photoURL!),
                          fit: BoxFit.cover,
                        )
                        : null,
              ),
              child:
                  currentUser?.photoURL == null
                      ? const Icon(Icons.person, color: Colors.white, size: 50)
                      : null,
            ),
            const SizedBox(height: 16),
            Text(
              currentUser?.displayName ?? 'User',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              currentUser?.email ?? currentUser?.phoneNumber ?? '',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 32),

            // Complete Profile Button
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const CompleteProfileScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.edit, color: Color(0xFF4ECDC4)),
              label: const Text(
                'Complete Profile',
                style: TextStyle(color: Color(0xFF4ECDC4)),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF4ECDC4), width: 2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Logout Button
            ElevatedButton(
              onPressed: _handleLogout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateOptions(
    BuildContext context, {
    StoryFeedItem? userStory,
  }) async {
    // Check authentication first - show auth modal for guests
    final canCreate = await ContextualAuthService.requireAuthForFeature(
      context,
      featureName: 'create content',
      customMessage: 'Sign in to share your moments with posts and stories.',
    );
    if (!canCreate) return;

    final hasStories = userStory != null;

    // Show modal with Story or Post options (+ View Story if user has stories)
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFF2A2A2A),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(25),
                topRight: Radius.circular(25),
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Title
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Create',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const Divider(color: Color(0xFF3A3A3A), height: 1),

                  // View Story option (only if user has stories)
                  if (hasStories) ...[
                    ListTile(
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.visibility_outlined,
                          color: Color(0xFF10B981),
                          size: 24,
                        ),
                      ),
                      title: const Text(
                        'View Your Story',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'See your active stories',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        _viewUserStories(userStory);
                      },
                    ),
                    const Divider(color: Color(0xFF3A3A3A), height: 1),
                  ],

                  // Story option
                  ListTile(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4ECDC4).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Color(0xFF4ECDC4),
                        size: 24,
                      ),
                    ),
                    title: const Text(
                      'Story',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Share a moment that disappears in 24 hours',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const CreateStoryTypeScreen(),
                        ),
                      );
                    },
                  ),

                  const Divider(color: Color(0xFF3A3A3A), height: 1),

                  // Post option
                  ListTile(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF667eea).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.post_add,
                        color: Color(0xFF667eea),
                        size: 24,
                      ),
                    ),
                    title: const Text(
                      'Post',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Create a permanent post to share with everyone',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    onTap: () async {
                      Navigator.of(context).pop();
                      final result = await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const CreatePostTypeScreen(),
                        ),
                      );

                      // If a new post was created, refresh from database
                      if (result is PostModel && mounted) {
                        await ref.read(postsProvider.notifier).refresh();
                      }
                    },
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
    );
  }
}

// Data models

// Stateful widget for image slider with dots
class _ImageSliderWidget extends StatefulWidget {
  final List<String> imageUrls;

  const _ImageSliderWidget({required this.imageUrls});

  @override
  State<_ImageSliderWidget> createState() => _ImageSliderWidgetState();
}

class _ImageSliderWidgetState extends State<_ImageSliderWidget> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child:
          widget.imageUrls.length == 1
              ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  widget.imageUrls.first,
                  width: double.infinity,
                  height: 300,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: double.infinity,
                      height: 300,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.image,
                        color: Colors.white,
                        size: 50,
                      ),
                    );
                  },
                ),
              )
              : Stack(
                children: [
                  // Image PageView
                  PageView.builder(
                    controller: _pageController,
                    itemCount: widget.imageUrls.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          widget.imageUrls[index],
                          width: double.infinity,
                          height: 300,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: double.infinity,
                              height: 300,
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.image,
                                color: Colors.white,
                                size: 50,
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),

                  // Image counter badge
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_currentIndex + 1}/${widget.imageUrls.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  // Dots indicator
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        widget.imageUrls.length,
                        (index) => Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                index == _currentIndex
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
    );
  }
}
