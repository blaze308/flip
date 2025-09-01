import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'services/token_auth_service.dart';
import 'services/message_service.dart';
import 'services/post_service.dart';
import 'services/story_service.dart';
import 'services/event_bus.dart';
import 'services/optimistic_ui_service.dart';
import 'services/contextual_auth_service.dart';
import 'widgets/custom_toaster.dart';
import 'widgets/post_menu_widget.dart';
import 'widgets/loading_button.dart';
import 'models/post_model.dart';
import 'models/story_model.dart';
import 'create_post_type_screen.dart';
import 'immersive_viewer_screen.dart';
import 'widgets/comments_bottom_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, OptimisticUIMixin {
  TokenUser? _currentUser;
  bool _isLoading = true;
  int _currentIndex = 0;
  late PageController _pageController;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;
  late ScrollController _scrollController;

  // Posts data - will be loaded from API
  final List<PostModel> _posts = [];
  bool _isLoadingPosts = false;
  StreamSubscription<PostCreatedEvent>? _postCreatedSubscription;

  // Stories data - will be loaded from API
  List<StoryFeedItem> _storyFeed = [];
  bool _isLoadingStories = false;

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
    _loadUserData();
    _loadPosts();
    _loadStories();

    // Listen for post creation events
    _postCreatedSubscription = EventBus().on<PostCreatedEvent>().listen((
      event,
    ) {
      print(
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

  Future<void> _loadUserData() async {
    try {
      print('🏠 HomeScreen: Loading user data...');

      // In contextual auth flow, we don't block on user data
      // Just check if user is authenticated and load accordingly
      final currentUser = TokenAuthService.currentUser;

      if (currentUser != null) {
        print('🏠 HomeScreen: Authenticated user found');
        print('   - ID: ${currentUser.id}');
        print('   - Display Name: ${currentUser.displayName}');
      } else {
        print('🏠 HomeScreen: Guest user - showing public content');
      }

      if (mounted) {
        setState(() {
          _currentUser = currentUser;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('🏠 HomeScreen: Error loading user data: $e');
      // Don't block the UI - show content anyway
      if (mounted) {
        setState(() {
          _currentUser = null; // Guest mode
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadStories() async {
    if (_isLoadingStories) return;

    setState(() {
      _isLoadingStories = true;
    });

    try {
      print('📖 HomeScreen: Loading stories feed...');

      final stories = await StoryService.getStoriesFeed();

      if (mounted) {
        setState(() {
          _storyFeed = stories;
          _isLoadingStories = false;
        });
        print(
          '📖 HomeScreen: Successfully loaded ${stories.length} story feed items',
        );
      }
    } catch (e) {
      print('📖 HomeScreen: Error loading stories: $e');
      if (mounted) {
        setState(() {
          _isLoadingStories = false;
        });
      }
      // Don't show error to user for stories - just fail silently
    }
  }

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
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _toggleLike(String postId) async {
    // Check authentication first
    final canLike = await ContextualAuthService.canLike(context);
    if (!canLike) return; // User cancelled login or not authenticated

    // Haptic feedback
    HapticFeedback.lightImpact();

    // Find the post in our local list
    final postIndex = _posts.indexWhere((post) => post.id == postId);
    if (postIndex == -1) {
      print('🏠 HomeScreen: Post $postId not found in local list');
      return;
    }

    final post = _posts[postIndex];
    final originalIsLiked = post.isLiked;
    final originalLikes = post.likes;

    print('🏠 HomeScreen: Optimistically toggling like for post $postId');

    await performOptimisticAction(
      buttonId: 'like_$postId',
      optimisticUpdate: () {
        // Immediately update the UI
        setState(() {
          _posts[postIndex] = post.copyWith(
            isLiked: !originalIsLiked,
            likes: originalIsLiked ? originalLikes - 1 : originalLikes + 1,
          );
        });
        print(
          '🏠 HomeScreen: Optimistic update applied - isLiked: ${!originalIsLiked}, likes: ${originalIsLiked ? originalLikes - 1 : originalLikes + 1}',
        );
      },
      apiCall: () async {
        try {
          final result = await PostService.toggleLike(postId);
          return result.success;
        } catch (e) {
          print('🏠 HomeScreen: API call failed: $e');
          return false;
        }
      },
      rollback: () {
        // Revert the UI change if API fails
        setState(() {
          _posts[postIndex] = post.copyWith(
            isLiked: originalIsLiked,
            likes: originalLikes,
          );
        });
        print('🏠 HomeScreen: Rolled back like state for post $postId');
      },
      onSuccess: () {
        print('🏠 HomeScreen: Like toggle confirmed by server');
        // Optionally refresh from server to ensure consistency
        // _loadPosts();
      },
      onError: (error) {
        ToasterService.showError(
          context,
          'Failed to update like. Please try again.',
        );
        print('🏠 HomeScreen: Like toggle error: $error');
      },
    );
  }

  void _updateFollowStatusForUser(String userId, bool isFollowing) {
    setState(() {
      for (int i = 0; i < _posts.length; i++) {
        if (_posts[i].userId == userId) {
          _posts[i] = _posts[i].copyWith(isFollowingUser: isFollowing);
        }
      }
    });
  }

  void _showCommentsModal(PostModel post) async {
    // Check authentication first for commenting
    final canComment = await ContextualAuthService.canComment(context);
    if (!canComment) return; // User cancelled login or not authenticated

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => CommentsBottomSheet(
            post: post,
            onCommentAdded: () {
              // Update comment count in the post
              final postIndex = _posts.indexWhere((p) => p.id == post.id);
              if (postIndex != -1) {
                setState(() {
                  _posts[postIndex] = _posts[postIndex].copyWith(
                    comments: _posts[postIndex].comments + 1,
                  );
                });
              }
            },
          ),
    );
  }

  void _openImmersiveViewer(int postIndex) {
    // Filter posts to only include image and video posts for immersive viewing
    final immersivePosts =
        _posts
            .where(
              (post) =>
                  post.type == PostType.image || post.type == PostType.video,
            )
            .toList();

    if (immersivePosts.isEmpty) return;

    // Find the index of the tapped post in the filtered list
    final tappedPost = _posts[postIndex];
    final immersiveIndex = immersivePosts.indexWhere(
      (post) => post.id == tappedPost.id,
    );

    if (immersiveIndex == -1) return;

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) => ImmersiveViewerScreen(
              posts: immersivePosts,
              initialIndex: immersiveIndex,
              onLikeToggle: (postId) {
                // Update the like status in the main posts list
                final mainPostIndex = _posts.indexWhere(
                  (post) => post.id == postId,
                );
                if (mainPostIndex != -1) {
                  // The like status is already updated by the immersive viewer
                  // We just need to trigger a rebuild if needed
                  setState(() {});
                }
              },
              onPostUpdated: () {
                // Refresh posts when something changes
                _refreshPosts();
              },
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Future<void> _loadPosts() async {
    if (_isLoadingPosts) return;

    setState(() {
      _isLoadingPosts = true;
    });

    try {
      print('🏠 HomeScreen: Loading posts from backend...');
      final result = await PostService.getFeed();

      if (mounted) {
        setState(() {
          _posts.clear();
          _posts.addAll(result.posts);
          _isLoadingPosts = false;
        });
        print('🏠 HomeScreen: Loaded ${result.posts.length} posts');

        // Debug: Log like states for first few posts
        for (int i = 0; i < result.posts.length && i < 3; i++) {
          final post = result.posts[i];
          print(
            '🏠 Post ${i + 1}: id=${post.id}, likes=${post.likes}, isLiked=${post.isLiked}',
          );
        }
      }
    } catch (e) {
      print('🏠 HomeScreen: Error loading posts: $e');
      if (mounted) {
        setState(() {
          _isLoadingPosts = false;
        });

        // Show error message to user
        ToasterService.showError(
          context,
          'Failed to load posts. Please try again.',
        );
      }
    }
  }

  Future<void> _refreshPosts() async {
    print('🏠 HomeScreen: Refreshing posts and stories...');
    await Future.wait([_loadPosts(), _loadStories()]);
  }

  // Method to refresh after post creation
  Future<void> _refreshAfterPostCreation() async {
    print('🔄 Refreshing home screen after post creation...');
    await _refreshPosts();

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
    // Haptic feedback
    HapticFeedback.lightImpact();

    try {
      print('🏠 HomeScreen: Sharing post $postId');

      // Call backend to share post
      final result = await PostService.sharePost(postId);

      if (result.success) {
        // Database-first approach: refresh posts from backend to get accurate state
        await _loadPosts();
        ToasterService.showSuccess(context, 'Post shared successfully!');
        print(
          '🏠 HomeScreen: Post shared successfully - refreshed from database',
        );
      } else {
        // Show error to user
        ToasterService.showError(
          context,
          'Failed to share post. Please try again.',
        );
        print('🏠 HomeScreen: Share failed - ${result.message}');
      }
    } catch (e) {
      // Show error to user
      ToasterService.showError(
        context,
        'Failed to share post. Please check your connection.',
      );
      print('🏠 HomeScreen: Share error: $e');
    }
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
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A1A),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4ECDC4)),
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        body: Stack(
          children: [
            // Main content with bottom padding to avoid overlap
            Positioned.fill(
              bottom: 80, // Height of bottom navigation
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                children: [
                  _buildHomeTab(),
                  _buildChatTab(),
                  _buildCreateTab(),
                  _buildLiveTab(),
                  _buildProfileTab(),
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
                        _buildNavItem(Icons.home, 0),
                        _buildNavItem(Icons.chat_bubble_outline, 1),
                        _buildCenterNavItem(), // Center create button
                        _buildNavItem(Icons.play_arrow, 3),
                        _buildNavItem(Icons.person_outline, 4),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onBottomNavTap(index),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Icon(
          icon,
          color: isSelected ? const Color(0xFF4ECDC4) : const Color(0xFF8E8E93),
          size: 24,
        ),
      ),
    );
  }

  Widget _buildCenterNavItem() {
    final isSelected = _currentIndex == 2;
    return ScaleTransition(
      scale: _fabAnimation,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentIndex = 2;
          });
          _pageController.animateToPage(
            2,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color:
                isSelected ? const Color(0xFF4ECDC4) : const Color(0xFF4ECDC4),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  Widget _buildHomeTab() {
    return RefreshIndicator(
      onRefresh: _refreshPosts,
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
    // Always show the "Your Story" option for everyone (guests and authenticated users)
    final totalItems = _storyFeed.length + 1; // Always add 1 for "Your Story"

    // Never hide the stories section - always show at least "Your Story"

    return SliverToBoxAdapter(
      child: Container(
        height: 100,
        margin: const EdgeInsets.symmetric(vertical: 16),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: totalItems,
          itemBuilder: (context, index) {
            // First item is always "Your Story" option (for everyone)
            if (index == 0) {
              return _buildCurrentUserStoryItem();
            }

            // Adjust index for story feed items
            final storyIndex = index - 1;
            final storyFeedItem = _storyFeed[storyIndex];

            return GestureDetector(
              onTap: () => _viewUserStories(storyFeedItem),
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                child: Column(
                  children: [
                    Stack(
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
                                    ? Border.all(color: Colors.grey, width: 2)
                                    : null,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.grey[800],
                              backgroundImage:
                                  storyFeedItem.userAvatar != null &&
                                          storyFeedItem.userAvatar!.isNotEmpty
                                      ? NetworkImage(storyFeedItem.userAvatar!)
                                      : null,
                              child:
                                  storyFeedItem.userAvatar == null ||
                                          storyFeedItem.userAvatar!.isEmpty
                                      ? Text(
                                        storyFeedItem.username.isNotEmpty
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
                      ],
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
    );
  }

  Widget _buildCurrentUserStoryItem() {
    return GestureDetector(
      onTap: () => _showCreateOptions(context),
      child: Container(
        margin: const EdgeInsets.only(right: 16),
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
                        _currentUser?.photoURL != null &&
                                _currentUser!.photoURL!.isNotEmpty
                            ? NetworkImage(_currentUser!.photoURL!)
                            : null,
                    child:
                        _currentUser?.photoURL == null ||
                                _currentUser!.photoURL!.isEmpty
                            ? Text(
                              _currentUser?.displayName?.isNotEmpty == true
                                  ? _currentUser!.displayName![0].toUpperCase()
                                  : 'Y', // Show 'Y' for "Your Story" even for guests
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                            : null,
                  ),
                ),
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
                'Your Story',
                style: TextStyle(color: Colors.white, fontSize: 12),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _viewUserStories(StoryFeedItem storyFeedItem) {
    // TODO: Implement story viewer screen
    ToasterService.showInfo(
      context,
      'Viewing ${storyFeedItem.username}\'s ${storyFeedItem.stories.length} stories',
    );
  }

  void _showStoryCreationOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFF2A2A2A),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                const Text(
                  'Create Story',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),

                // Story creation options
                _buildStoryOption(
                  context,
                  icon: Icons.text_fields,
                  title: 'Text Story',
                  subtitle: 'Share your thoughts with custom styling',
                  onTap: () {
                    Navigator.of(context).pop();
                    _createTextStory();
                  },
                ),
                const SizedBox(height: 15),
                _buildStoryOption(
                  context,
                  icon: Icons.photo_camera,
                  title: 'Photo Story',
                  subtitle: 'Share a photo from camera or gallery',
                  onTap: () {
                    Navigator.of(context).pop();
                    ToasterService.showInfo(
                      context,
                      'Photo story creation coming soon!',
                    );
                  },
                ),
                const SizedBox(height: 15),
                _buildStoryOption(
                  context,
                  icon: Icons.videocam,
                  title: 'Video Story',
                  subtitle: 'Record or upload a video',
                  onTap: () {
                    Navigator.of(context).pop();
                    ToasterService.showInfo(
                      context,
                      'Video story creation coming soon!',
                    );
                  },
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
    );
  }

  Widget _buildStoryOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF3A3A3A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF4ECDC4).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF4ECDC4), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
          ],
        ),
      ),
    );
  }

  void _createTextStory() {
    // Simple text story creation
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF2A2A2A),
            title: const Text(
              'Create Text Story',
              style: TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'What\'s on your mind?',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF4ECDC4)),
                    ),
                  ),
                  maxLines: 3,
                  onChanged: (value) {
                    // Store the text value
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();

                  try {
                    // Create a simple text story
                    await StoryService.createTextStory(
                      textContent: 'Hello World! This is my first story.',
                      privacy: StoryPrivacyType.public,
                    );

                    ToasterService.showSuccess(
                      context,
                      'Story created successfully!',
                    );

                    // Refresh stories
                    await _loadStories();
                  } catch (e) {
                    ToasterService.showError(
                      context,
                      'Failed to create story: $e',
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4ECDC4),
                ),
                child: const Text(
                  'Share',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildPostsList() {
    if (_isLoadingPosts && _posts.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4ECDC4)),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading posts...',
                style: TextStyle(color: Colors.grey[400], fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (_posts.isEmpty) {
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
                    await _loadPosts(); // Database-first: reload all posts
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
        final post = _posts[index];
        final isLastPost = index == _posts.length - 1;

        return Column(
          children: [
            _buildPostCard(post),
            // Add extra bottom padding for the last post to ensure actions are visible
            if (isLastPost) const SizedBox(height: 100),
          ],
        );
      }, childCount: _posts.length),
    );
  }

  Widget _buildPostCard(PostModel post) {
    return Container(
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
              _refreshPosts();
            },
            onPostHidden: () {
              // Database-first: refresh posts from backend
              _loadPosts();
            },
            onFollowStatusChanged: (String userId, bool isFollowing) {
              // Update follow status for all posts from this user
              _updateFollowStatusForUser(userId, isFollowing);
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
    final postIndex = _posts.indexWhere((p) => p.id == post.id);

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
          _ImageSliderWidget(
            imageUrls: post.imageUrls!,
            onTap: () => _openImmersiveViewer(postIndex),
          ),
      ],
    );
  }

  Widget _buildVideoPost(PostModel post) {
    final postIndex = _posts.indexWhere((p) => p.id == post.id);

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
          GestureDetector(
            onTap: () => _openImmersiveViewer(postIndex),
            child: Container(
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
            isActive: post.isLiked,
            activeColor: Colors.red,
            inactiveColor: Colors.white,
            isDisabled: isButtonDisabled('like_${post.id}'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  post.isLiked ? Icons.favorite : Icons.favorite_border,
                  size: 24,
                ),
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
          const SizedBox(width: 24),
          GestureDetector(
            onTap: () => _showCommentsModal(post),
            child: Row(
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
          const SizedBox(width: 24),
          GestureDetector(
            onTap: () => _sharePost(post.id),
            child: Row(
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
        ],
      ),
    );
  }

  Widget _buildChatTab() {
    return const Center(
      child: Text('Chat', style: TextStyle(color: Colors.white, fontSize: 24)),
    );
  }

  Widget _buildCreateTab() {
    return const Center(
      child: Text(
        'Create',
        style: TextStyle(color: Colors.white, fontSize: 24),
      ),
    );
  }

  Widget _buildLiveTab() {
    return const Center(
      child: Text('Live', style: TextStyle(color: Colors.white, fontSize: 24)),
    );
  }

  Widget _buildProfileTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[800],
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 50),
          ),
          const SizedBox(height: 16),
          Text(
            _currentUser?.displayName ?? 'User',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currentUser?.email ?? '',
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _handleLogout,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showCreateOptions(BuildContext context) async {
    // Check authentication first - show auth modal for guests
    final canCreateStory = await ContextualAuthService.requireAuthForFeature(
      context,
      featureName: 'create stories',
      customMessage:
          'Sign in to share your moments with stories that disappear in 24 hours.',
    );
    if (!canCreateStory) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(25),
                topRight: Radius.circular(25),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                const Text(
                  'Create',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),

                // Options
                _buildCreateOption(
                  context,
                  icon: Icons.post_add,
                  title: 'Create Post',
                  subtitle: 'Share photos, videos, or thoughts',
                  onTap: () async {
                    Navigator.of(context).pop();
                    final result = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const CreatePostTypeScreen(),
                      ),
                    );

                    // If a new post was created, refresh from database
                    if (result is PostModel) {
                      await _loadPosts(); // Database-first: reload all posts
                    }
                  },
                ),
                const SizedBox(height: 15),
                _buildCreateOption(
                  context,
                  icon: Icons.auto_stories,
                  title: 'Create Story',
                  subtitle: 'Share a moment that disappears in 24h',
                  onTap: () {
                    Navigator.of(context).pop();
                    _showStoryCreationOptions(context);
                  },
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
    );
  }

  Widget _buildCreateOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[800]!, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF4ECDC4).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF4ECDC4), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.grey[500], size: 16),
          ],
        ),
      ),
    );
  }
}

// Data models

// Stateful widget for image slider with dots
class _ImageSliderWidget extends StatefulWidget {
  final List<String> imageUrls;
  final VoidCallback? onTap;

  const _ImageSliderWidget({required this.imageUrls, this.onTap});

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
                      return GestureDetector(
                        onTap: widget.onTap,
                        child: ClipRRect(
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
