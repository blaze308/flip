import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';

import 'models/post_model.dart';
import 'widgets/post_menu_widget.dart';
import 'widgets/loading_button.dart';
import 'services/optimistic_ui_service.dart';
import 'services/post_service.dart';
import 'services/contextual_auth_service.dart';
import 'widgets/custom_toaster.dart';
import 'widgets/comments_bottom_sheet.dart';

class ImmersiveViewerScreen extends StatefulWidget {
  final List<PostModel> posts;
  final int initialIndex;
  final Function(String postId)? onLikeToggle;
  final VoidCallback? onPostUpdated;

  const ImmersiveViewerScreen({
    Key? key,
    required this.posts,
    required this.initialIndex,
    this.onLikeToggle,
    this.onPostUpdated,
  }) : super(key: key);

  @override
  State<ImmersiveViewerScreen> createState() => _ImmersiveViewerScreenState();
}

class _ImmersiveViewerScreenState extends State<ImmersiveViewerScreen>
    with TickerProviderStateMixin, OptimisticUIMixin {
  late PageController _pageController;
  int _currentIndex = 0;
  bool _isVisible = true;
  Timer? _hideTimer;

  // Image slider controllers map for each post
  final Map<String, PageController> _imagePageControllers = {};
  final Map<String, int> _currentImageIndex = {};

  // Video controllers map
  final Map<String, VideoPlayerController> _videoControllers = {};
  final Map<String, bool> _videoInitialized = {};

  // Animation controllers
  late AnimationController _overlayAnimationController;
  late Animation<double> _overlayAnimation;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    // Setup overlay animation
    _overlayAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _overlayAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _overlayAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    // Show overlay initially
    _overlayAnimationController.forward();
    _startHideTimer();

    // Initialize video for current post if it's a video
    _initializeCurrentVideo();

    // Set system UI overlay style for better experience while keeping safe areas
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _overlayAnimationController.dispose();
    _pageController.dispose();

    // Dispose all video controllers
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }

    // Dispose all image page controllers
    for (var controller in _imagePageControllers.values) {
      controller.dispose();
    }

    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isVisible) {
        setState(() {
          _isVisible = false;
        });
        _overlayAnimationController.reverse();
      }
    });
  }

  void _toggleOverlay() {
    setState(() {
      _isVisible = !_isVisible;
    });

    if (_isVisible) {
      _overlayAnimationController.forward();
      _startHideTimer();
    } else {
      _overlayAnimationController.reverse();
      _hideTimer?.cancel();
    }
  }

  void _initializeCurrentVideo() {
    final currentPost = widget.posts[_currentIndex];
    if (currentPost.type == PostType.video && currentPost.videoUrl != null) {
      _initializeVideo(currentPost);
    }
  }

  void _initializeVideo(PostModel post) {
    if (_videoControllers.containsKey(post.id)) return;

    final controller = VideoPlayerController.network(post.videoUrl!);
    _videoControllers[post.id] = controller;
    _videoInitialized[post.id] = false;

    controller
        .initialize()
        .then((_) {
          if (mounted) {
            setState(() {
              _videoInitialized[post.id] = true;
            });

            // Auto-play if this is the current post
            if (widget.posts[_currentIndex].id == post.id) {
              controller.play();
              controller.setLooping(true);
            }
          }
        })
        .catchError((error) {
          print('Error initializing video: $error');
        });
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });

    // Pause all videos
    for (var controller in _videoControllers.values) {
      controller.pause();
    }

    // Initialize and play current video if it's a video post
    final currentPost = widget.posts[index];
    if (currentPost.type == PostType.video && currentPost.videoUrl != null) {
      _initializeVideo(currentPost);

      // Play current video
      final controller = _videoControllers[currentPost.id];
      if (controller != null && _videoInitialized[currentPost.id] == true) {
        controller.play();
      }
    }

    // Preload next video if exists
    if (index + 1 < widget.posts.length) {
      final nextPost = widget.posts[index + 1];
      if (nextPost.type == PostType.video && nextPost.videoUrl != null) {
        _initializeVideo(nextPost);
      }
    }
  }

  Future<void> _toggleLike(String postId) async {
    // Check authentication first
    final canLike = await ContextualAuthService.canLike(context);
    if (!canLike) return; // User cancelled login or not authenticated

    HapticFeedback.lightImpact();

    // Find the post in our local list
    final postIndex = widget.posts.indexWhere((post) => post.id == postId);
    if (postIndex == -1) return;

    final post = widget.posts[postIndex];
    final originalIsLiked = post.isLiked;
    final originalLikes = post.likes;

    await performOptimisticAction(
      buttonId: 'like_$postId',
      optimisticUpdate: () {
        setState(() {
          widget.posts[postIndex] = post.copyWith(
            isLiked: !originalIsLiked,
            likes: originalIsLiked ? originalLikes - 1 : originalLikes + 1,
          );
        });
      },
      apiCall: () async {
        try {
          final result = await PostService.toggleLike(postId);
          return result.success;
        } catch (e) {
          return false;
        }
      },
      rollback: () {
        setState(() {
          widget.posts[postIndex] = post.copyWith(
            isLiked: originalIsLiked,
            likes: originalLikes,
          );
        });
      },
      onSuccess: () {
        widget.onLikeToggle?.call(postId);
      },
      onError: (error) {
        ToasterService.showError(
          context,
          'Failed to update like. Please try again.',
        );
      },
    );
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
              final postIndex = widget.posts.indexWhere((p) => p.id == post.id);
              if (postIndex != -1) {
                setState(() {
                  widget.posts[postIndex] = widget.posts[postIndex].copyWith(
                    comments: widget.posts[postIndex].comments + 1,
                  );
                });
              }
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              onPageChanged: _onPageChanged,
              itemCount: widget.posts.length,
              itemBuilder: (context, index) {
                final post = widget.posts[index];
                return GestureDetector(
                  onTap: _toggleOverlay,
                  child: _buildPostContent(post),
                );
              },
            ),

            // Overlay with controls
            AnimatedBuilder(
              animation: _overlayAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _overlayAnimation.value,
                  child: _buildOverlay(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostContent(PostModel post) {
    switch (post.type) {
      case PostType.image:
        return _buildImageViewer(post);
      case PostType.video:
        return _buildVideoViewer(post);
      case PostType.text:
        return _buildTextViewer(post);
    }
  }

  Widget _buildImageViewer(PostModel post) {
    if (post.imageUrls == null || post.imageUrls!.isEmpty) {
      return _buildPlaceholderContent(post, Icons.image, 'No images available');
    }

    // Initialize page controller for this post if not exists
    if (!_imagePageControllers.containsKey(post.id)) {
      _imagePageControllers[post.id] = PageController();
      _currentImageIndex[post.id] = 0;
    }

    final imageController = _imagePageControllers[post.id]!;
    final currentImageIdx = _currentImageIndex[post.id] ?? 0;
    final hasMultipleImages = post.imageUrls!.length > 1;

    return Stack(
      children: [
        InteractiveViewer(
          minScale: 1.0,
          maxScale: 4.0,
          child: PageView.builder(
            controller: imageController,
            itemCount: post.imageUrls!.length,
            onPageChanged: (index) {
              setState(() {
                _currentImageIndex[post.id] = index;
              });
            },
            itemBuilder: (context, imageIndex) {
              return Center(
                child: Image.network(
                  post.imageUrls![imageIndex],
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value:
                            loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                        color: const Color(0xFF4ECDC4),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return _buildPlaceholderContent(
                      post,
                      Icons.broken_image,
                      'Failed to load image',
                    );
                  },
                ),
              );
            },
          ),
        ),

        // Image counter and dots (only show if multiple images)
        if (hasMultipleImages) ...[
          // Counter at top right
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${currentImageIdx + 1}/${post.imageUrls!.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          // Dots indicator at bottom
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                post.imageUrls!.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        index == currentImageIdx
                            ? const Color(0xFF4ECDC4)
                            : Colors.white.withOpacity(0.5),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVideoViewer(PostModel post) {
    if (post.videoUrl == null) {
      return _buildPlaceholderContent(
        post,
        Icons.videocam_off,
        'No video available',
      );
    }

    final controller = _videoControllers[post.id];
    final isInitialized = _videoInitialized[post.id] ?? false;

    if (controller == null || !isInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF4ECDC4)),
            const SizedBox(height: 16),
            Text(
              'Loading video...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(controller),

            // Play/Pause overlay
            GestureDetector(
              onTap: () {
                setState(() {
                  if (controller.value.isPlaying) {
                    controller.pause();
                  } else {
                    controller.play();
                  }
                });
              },
              child: AnimatedOpacity(
                opacity: controller.value.isPlaying ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(20),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextViewer(PostModel post) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: post.backgroundColor ?? const Color(0xFF4ECDC4),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            post.content ?? '',
            style: TextStyle(
              color: post.textColor ?? Colors.white,
              fontSize: post.fontSize ?? 24,
              fontWeight: post.fontWeight ?? FontWeight.w500,
              fontFamily: post.fontFamily,
            ),
            textAlign: post.textAlign ?? TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderContent(
    PostModel post,
    IconData icon,
    String message,
  ) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.grey[900],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.5), size: 80),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
          if (post.content != null && post.content!.isNotEmpty) ...[
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                post.content!,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOverlay() {
    final currentPost = widget.posts[_currentIndex];

    return Stack(
      children: [
        // Top overlay with back button and post info
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.7), Colors.transparent],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[800],
                  ),
                  child:
                      currentPost.userAvatar != null
                          ? ClipOval(
                            child: Image.network(
                              currentPost.userAvatar!,
                              width: 32,
                              height: 32,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 16,
                                );
                              },
                            ),
                          )
                          : const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 16,
                          ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            currentPost.username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (currentPost.isFollowingUser) ...[
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
                      Text(
                        currentPost.timeAgo,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                PostMenuWidget(
                  post: currentPost,
                  onPostUpdated: widget.onPostUpdated,
                  onFollowStatusChanged: (userId, isFollowing) {
                    // Update follow status for all posts from this user
                    setState(() {
                      for (int i = 0; i < widget.posts.length; i++) {
                        if (widget.posts[i].userId == userId) {
                          widget.posts[i] = widget.posts[i].copyWith(
                            isFollowingUser: isFollowing,
                          );
                        }
                      }
                    });
                  },
                ),
              ],
            ),
          ),
        ),

        // Bottom overlay with actions
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.7), Colors.transparent],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Post content
                if (currentPost.content != null &&
                    currentPost.content!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      currentPost.content!,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),

                // Actions row
                Row(
                  children: [
                    OptimisticButton(
                      onPressed: () => _toggleLike(currentPost.id),
                      isActive: currentPost.isLiked,
                      activeColor: Colors.red,
                      inactiveColor: Colors.white,
                      isDisabled: isButtonDisabled('like_${currentPost.id}'),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            currentPost.isLiked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${currentPost.likes}',
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
                      onTap: () => _showCommentsModal(currentPost),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${currentPost.comments}',
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
                          Icons.share_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${currentPost.shares}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),

                    // Page indicator
                    Text(
                      '${_currentIndex + 1} / ${widget.posts.length}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
