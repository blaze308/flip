import 'package:flip/widgets/shimmer_loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/post_model.dart';
import '../services/comment_service.dart';
import '../services/contextual_auth_service.dart';

class CommentsBottomSheet extends StatefulWidget {
  final PostModel post;
  final VoidCallback? onCommentAdded;

  const CommentsBottomSheet({
    super.key,
    required this.post,
    this.onCommentAdded,
  });

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet>
    with TickerProviderStateMixin {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  bool _isSubmitting = false;
  bool _isLoading = true;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  // Real comments data from API
  List<Comment> _comments = [];

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    // Add listener to update send button state
    _commentController.addListener(() {
      setState(() {});
    });

    _slideController.forward();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    _scrollController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print(
        '💬 CommentsBottomSheet: Loading comments for post ${widget.post.id}',
      );

      final result = await CommentService.getComments(widget.post.id);

      if (result.success) {
        setState(() {
          _comments = result.comments;
          _isLoading = false;
        });
        print(
          '💬 CommentsBottomSheet: Loaded ${result.comments.length} comments',
        );
      } else {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? 'Failed to load comments'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('❌ CommentsBottomSheet: Error loading comments: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load comments: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty || _isSubmitting) return;

    // Check authentication first
    final canComment = await ContextualAuthService.canComment(context);
    if (!canComment) return; // User cancelled login or not authenticated

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Add haptic feedback
      HapticFeedback.lightImpact();

      print(
        '💬 CommentsBottomSheet: Submitting comment for post ${widget.post.id}',
      );

      final result = await CommentService.createComment(
        widget.post.id,
        _commentController.text.trim(),
      );

      if (result.success && result.comments.isNotEmpty) {
        final newComment = result.comments.first;

        setState(() {
          _comments.insert(0, newComment);
          _commentController.clear();
        });

        // Scroll to top to show new comment
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }

        widget.onCommentAdded?.call();
        print('💬 CommentsBottomSheet: Comment submitted successfully');
      } else {
        throw Exception(result.error ?? 'Failed to create comment');
      }
    } catch (e) {
      print('❌ CommentsBottomSheet: Error submitting comment: $e');
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post comment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _toggleCommentLike(String commentId) async {
    // Check authentication first
    final canLike = await ContextualAuthService.canLike(context);
    if (!canLike) return; // User cancelled login or not authenticated

    // Find comment and optimistically update UI
    final commentIndex = _comments.indexWhere((c) => c.id == commentId);
    if (commentIndex == -1) return;

    final comment = _comments[commentIndex];
    final originalIsLiked = comment.isLiked;
    final originalLikes = comment.likes;

    // Optimistic update
    setState(() {
      _comments[commentIndex] = comment.copyWith(
        isLiked: !originalIsLiked,
        likes: originalIsLiked ? originalLikes - 1 : originalLikes + 1,
      );
    });

    HapticFeedback.lightImpact();

    try {
      print('💬 CommentsBottomSheet: Toggling like for comment $commentId');

      final result = await CommentService.toggleCommentLike(commentId);

      if (result.success) {
        final isLiked = result.isLiked ?? !originalIsLiked;

        // Update with server response
        setState(() {
          _comments[commentIndex] = comment.copyWith(
            isLiked: isLiked,
            likes:
                result.likes ??
                (originalIsLiked ? originalLikes - 1 : originalLikes + 1),
          );
        });

        // Show toast notification
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(isLiked ? 'Comment liked' : 'Comment unliked'),
                ],
              ),
              backgroundColor:
                  isLiked ? const Color(0xFF4ECDC4) : Colors.grey[800],
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
            ),
          );
        }

        print('💬 CommentsBottomSheet: Comment like toggled successfully');
      } else {
        // Revert optimistic update
        setState(() {
          _comments[commentIndex] = comment.copyWith(
            isLiked: originalIsLiked,
            likes: originalLikes,
          );
        });
        throw Exception(result.error ?? 'Failed to toggle like');
      }
    } catch (e) {
      print('❌ CommentsBottomSheet: Error toggling comment like: $e');
      // Revert optimistic update
      setState(() {
        _comments[commentIndex] = comment.copyWith(
          isLiked: originalIsLiked,
          likes: originalLikes,
        );
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Failed to update like')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom, // Keyboard padding
      ),
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[800]!, width: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Comments',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_comments.length}',
                      style: TextStyle(color: Colors.grey[400], fontSize: 16),
                    ),
                  ],
                ),
              ),

              // Comments list
              Expanded(
                child:
                    _isLoading
                        ? _buildLoadingState()
                        : _comments.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _comments.length,
                          itemBuilder: (context, index) {
                            return _buildCommentItem(_comments[index]);
                          },
                        ),
              ),

              // Comment input
              _buildCommentInput(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) => const CommentShimmer(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            'No comments yet',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to comment!',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(Comment comment) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[800],
            ),
            child:
                comment.avatar.isNotEmpty
                    ? ClipOval(
                      child: Image.network(
                        comment.avatar,
                        width: 36,
                        height: 36,
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

          // Comment content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author and time
                Row(
                  children: [
                    Text(
                      comment.author,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      comment.timeAgo,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                // Comment text
                Text(
                  comment.content,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Like button at the end of the row
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => _toggleCommentLike(comment.id),
                child: Icon(
                  comment.isLiked ? Icons.favorite : Icons.favorite_border,
                  size: 20,
                  color: comment.isLiked ? Colors.red : Colors.grey[500],
                ),
              ),
              if (comment.likes > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '${comment.likes}',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        border: Border(top: BorderSide(color: Colors.grey[800]!, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // User avatar
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[800],
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 18),
              ),

              const SizedBox(width: 12),

              // Text input
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A3A3A),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextField(
                    controller: _commentController,
                    focusNode: _commentFocusNode,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      hintStyle: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 16,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      isDense: false,
                    ),
                    maxLines: null,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    cursorColor: const Color(0xFF4ECDC4),
                    onSubmitted: (_) => _submitComment(),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Send button
              GestureDetector(
                onTap: _submitComment,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color:
                        _commentController.text.trim().isNotEmpty
                            ? const Color(0xFF4ECDC4)
                            : Colors.grey[700],
                    shape: BoxShape.circle,
                  ),
                  child:
                      _isSubmitting
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : const Icon(
                            Icons.send,
                            color: Colors.white,
                            size: 18,
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
