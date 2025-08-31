import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'services/firebase_auth_service.dart';
import 'services/message_service.dart';
import 'services/user_service.dart';
import 'services/post_service.dart';
import 'services/event_bus.dart';
import 'widgets/custom_toaster.dart';
import 'widgets/post_menu_widget.dart';
import 'models/user_model.dart';
import 'models/post_model.dart';
import 'create_post_type_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  UserModel? _currentUser;
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

  // Story users - will be populated dynamically
  List<StoryUser> _storyUsers = [];

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
      await UserService.initializeUser();
      final currentUser = UserService.currentUser;

      // Log user data
      if (currentUser != null) {
        print('🏠 HomeScreen: User loaded successfully');
        print('   - UID: ${currentUser.uid}');
        print('   - Email: ${currentUser.email}');
        print('   - Display Name: ${currentUser.displayName}');
        print(
          '   - Profile Image: ${currentUser.profileImageUrl ?? "No image"}',
        );
        print('   - Username: ${currentUser.username}');
        print('   - Is Active: ${currentUser.isActive}');
        print('   - Account Type: ${currentUser.accountType}');
      } else {
        print('🏠 HomeScreen: No user data available');
      }

      if (mounted) {
        setState(() {
          _currentUser = currentUser;
          _populateStoryUsers();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('🏠 HomeScreen: Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _populateStoryUsers() {
    // Debug logging for story avatar
    print('🏠 HomeScreen: Populating story users...');
    print('   - Current user profile image: ${_currentUser?.profileImageUrl}');
    print(
      '   - Using avatar URL: ${_currentUser?.profileImageUrl ?? 'https://i.pravatar.cc/150?img=0'}',
    );

    _storyUsers = [
      StoryUser(
        name: 'You',
        avatar:
            _currentUser?.profileImageUrl ?? 'https://i.pravatar.cc/150?img=0',
        hasStory: false,
        isCurrentUser: true,
      ),
      StoryUser(
        name: 'Jacob',
        avatar: 'https://i.pravatar.cc/150?img=3',
        hasStory: true,
      ),
      StoryUser(
        name: 'Luna',
        avatar: 'https://i.pravatar.cc/150?img=4',
        hasStory: true,
      ),
      StoryUser(
        name: 'John',
        avatar: 'https://i.pravatar.cc/150?img=5',
        hasStory: true,
      ),
      StoryUser(
        name: 'Natali',
        avatar: 'https://i.pravatar.cc/150?img=6',
        hasStory: true,
      ),
    ];
  }

  Future<void> _handleLogout() async {
    try {
      final result = await FirebaseAuthService.signOut();
      if (result.success && mounted) {
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
    // Haptic feedback
    HapticFeedback.lightImpact();

    try {
      print('🏠 HomeScreen: Toggling like for post $postId');

      // Call backend to toggle like
      final result = await PostService.toggleLike(postId);

      if (result.success) {
        // Database-first approach: refresh posts from backend to get accurate state
        await _loadPosts();
        print(
          '🏠 HomeScreen: Like toggled successfully - refreshed from database',
        );
      } else {
        // Show error to user
        ToasterService.showError(
          context,
          'Failed to update like. Please try again.',
        );
        print('🏠 HomeScreen: Like toggle failed - ${result.message}');
      }
    } catch (e) {
      // Show error to user
      ToasterService.showError(
        context,
        'Failed to update like. Please check your connection.',
      );
      print('🏠 HomeScreen: Like toggle error: $e');
    }
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
    print('🏠 HomeScreen: Refreshing posts...');
    await _loadPosts();
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

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: PageView(
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
      floatingActionButton: ScaleTransition(
        scale: _fabAnimation,
        child: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: Color(0xFF4ECDC4),
            shape: BoxShape.circle,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
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
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.home, 0),
          _buildNavItem(Icons.chat_bubble_outline, 1),
          const SizedBox(width: 56), // Space for FAB
          _buildNavItem(Icons.play_arrow, 3),
          _buildNavItem(Icons.person_outline, 4),
        ],
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
    return SliverToBoxAdapter(
      child: Container(
        height: 100,
        margin: const EdgeInsets.symmetric(vertical: 16),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _storyUsers.length,
          itemBuilder: (context, index) {
            final user = _storyUsers[index];
            return GestureDetector(
              onTap: () {
                if (user.isCurrentUser) {
                  _showCreateOptions(context);
                } else {
                  // Handle viewing other user's story
                  ToasterService.showInfo(
                    context,
                    'Viewing ${user.name}\'s story',
                  );
                }
              },
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
                            border: Border.all(
                              color:
                                  user.hasStory
                                      ? const Color(0xFF4ECDC4)
                                      : Colors.grey,
                              width: user.hasStory ? 3 : 1,
                            ),
                          ),
                          child: ClipOval(
                            child:
                                user.avatar.isNotEmpty
                                    ? Image.network(
                                      user.avatar,
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      errorBuilder: (
                                        context,
                                        error,
                                        stackTrace,
                                      ) {
                                        return Container(
                                          color: Colors.grey[800],
                                          child: const Icon(
                                            Icons.person,
                                            color: Colors.white,
                                            size: 30,
                                          ),
                                        );
                                      },
                                    )
                                    : Container(
                                      color: Colors.grey[800],
                                      child: const Icon(
                                        Icons.person,
                                        color: Colors.white,
                                        size: 30,
                                      ),
                                    ),
                          ),
                        ),
                        if (user.isCurrentUser)
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
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      user.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
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
        return _buildPostCard(post);
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
                Text(
                  post.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
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
          GestureDetector(
            onTap: () => _toggleLike(post.id),
            child: Row(
              children: [
                Icon(
                  post.isLiked ? Icons.favorite : Icons.favorite_border,
                  color: post.isLiked ? Colors.red : Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  '${post.likes}',
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
          Row(
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
            _currentUser?.fullName ?? 'User',
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

  void _showCreateOptions(BuildContext context) {
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
                    ToasterService.showInfo(
                      context,
                      'Story creation coming soon!',
                    );
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
class StoryUser {
  final String name;
  final String avatar;
  final bool hasStory;
  final bool isCurrentUser;

  StoryUser({
    required this.name,
    required this.avatar,
    required this.hasStory,
    this.isCurrentUser = false,
  });
}

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
