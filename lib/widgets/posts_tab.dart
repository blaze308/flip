import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import '../widgets/shimmer_loading.dart';
import '../screens/viewer/immersive_viewer_screen.dart';

/// Posts Tab Widget
/// Displays user's posts in a grid layout
class PostsTab extends StatefulWidget {
  final String userId;

  const PostsTab({
    super.key,
    required this.userId,
  });

  @override
  State<PostsTab> createState() => _PostsTabState();
}

class _PostsTabState extends State<PostsTab>
    with AutomaticKeepAliveClientMixin {
  List<PostModel> _posts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  bool _hasMore = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts({bool loadMore = false}) async {
    if (loadMore && (_isLoadingMore || !_hasMore)) return;

    setState(() {
      if (loadMore) {
        _isLoadingMore = true;
      } else {
        _isLoading = true;
        _posts = [];
        _currentPage = 1;
      }
    });

    try {
      final result = await PostService.getUserPosts(
        widget.userId,
        page: loadMore ? _currentPage + 1 : 1,
        limit: 20,
      );

      if (mounted) {
        setState(() {
          if (loadMore) {
            _posts.addAll(result.posts);
            _currentPage++;
            _isLoadingMore = false;
          } else {
            _posts = result.posts;
            _isLoading = false;
          }
          _hasMore = result.pagination.hasMore;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_posts.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () => _loadPosts(),
      color: const Color(0xFF4ECDC4),
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (!_isLoadingMore &&
              _hasMore &&
              scrollInfo.metrics.pixels >=
                  scrollInfo.metrics.maxScrollExtent - 200) {
            _loadPosts(loadMore: true);
          }
          return false;
        },
        child: GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: _posts.length + (_isLoadingMore ? 3 : 0),
          itemBuilder: (context, index) {
            if (index >= _posts.length) {
              return _buildLoadingTile();
            }
            return _buildPostTile(_posts[index], index);
          },
        ),
      ),
    );
  }

  Widget _buildPostTile(PostModel post, int index) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ImmersiveViewerScreen(
              posts: _posts,
              initialIndex: index,
              onLikeToggle: (postId) {
                _loadPosts(); // Refresh after like
              },
              onPostUpdated: () {
                _loadPosts(); // Refresh after update
              },
            ),
          ),
        );
      },
      child: Container(
        color: const Color(0xFF1D1E33),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Post thumbnail based on type
            _buildPostThumbnail(post),

            // Post type indicator
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  _getPostTypeIcon(post.type),
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),

            // Engagement overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildEngagementItem(Icons.favorite, post.likes),
                    _buildEngagementItem(Icons.comment, post.comments),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostThumbnail(PostModel post) {
    switch (post.type) {
      case PostType.image:
        if (post.imageUrls != null && post.imageUrls!.isNotEmpty) {
          return CachedNetworkImage(
            imageUrl: post.imageUrls!.first,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: const Color(0xFF0A0E21),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF4ECDC4)),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: const Color(0xFF0A0E21),
              child: const Icon(Icons.image, color: Colors.grey, size: 32),
            ),
          );
        }
        return Container(
          color: const Color(0xFF0A0E21),
          child: const Icon(Icons.image, color: Colors.grey, size: 32),
        );

      case PostType.video:
        if (post.videoThumbnail != null) {
          return CachedNetworkImage(
            imageUrl: post.videoThumbnail!,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: const Color(0xFF0A0E21),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF4ECDC4)),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: const Color(0xFF0A0E21),
              child: const Icon(Icons.videocam, color: Colors.grey, size: 32),
            ),
          );
        }
        return Container(
          color: const Color(0xFF0A0E21),
          child: const Icon(Icons.videocam, color: Colors.grey, size: 32),
        );

      case PostType.text:
        return Container(
          color: post.backgroundColor ?? const Color(0xFF4ECDC4),
          padding: const EdgeInsets.all(8),
          child: Center(
            child: Text(
              post.content ?? '',
              style: TextStyle(
                color: post.textColor ?? Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        );
    }
  }

  Widget _buildEngagementItem(IconData icon, int count) {
    if (count == 0) return const SizedBox.shrink();

    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 12),
        const SizedBox(width: 2),
        Text(
          _formatCount(count),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  IconData _getPostTypeIcon(PostType type) {
    switch (type) {
      case PostType.image:
        return Icons.image;
      case PostType.video:
        return Icons.play_circle_filled;
      case PostType.text:
        return Icons.text_fields;
    }
  }

  Widget _buildLoadingTile() {
    return ShimmerLoading(
      width: double.infinity,
      height: double.infinity,
      borderRadius: BorderRadius.zero,
    );
  }

  Widget _buildLoadingState() {
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: 9,
      itemBuilder: (context, index) => _buildLoadingTile(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library,
            size: 64,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            'No posts yet',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Posts will appear here',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

