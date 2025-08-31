import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class CommentService {
  static const String baseUrl = 'https://flip-backend-mnpg.onrender.com';
  static const Duration timeoutDuration = Duration(seconds: 30);

  /// Get authentication headers with Firebase ID token
  static Future<Map<String, String>> _getHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final token = await user.getIdToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Get comments for a post
  static Future<CommentResult> getComments(
    String postId, {
    int page = 1,
    int limit = 20,
    String sortBy = 'createdAt',
    String sortOrder = 'desc',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/comments/post/$postId').replace(
        queryParameters: {
          'page': page.toString(),
          'limit': limit.toString(),
          'sortBy': sortBy,
          'sortOrder': sortOrder,
        },
      );

      print('🔄 CommentService: Getting comments for post $postId');
      print('🔄 CommentService: Request URL: $uri');

      final headers = await _getHeaders();
      final response = await http
          .get(uri, headers: headers)
          .timeout(timeoutDuration);

      print('🔄 CommentService: Response status: ${response.statusCode}');
      print('🔄 CommentService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final comments =
              (data['data']['comments'] as List)
                  .map((commentJson) => Comment.fromJson(commentJson))
                  .toList();

          final pagination = CommentPagination.fromJson(
            data['data']['pagination'],
          );

          return CommentResult(
            success: true,
            comments: comments,
            pagination: pagination,
          );
        } else {
          throw Exception(data['message'] ?? 'Failed to get comments');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to get comments');
      }
    } catch (e) {
      print('❌ CommentService: Error getting comments: $e');
      return CommentResult(success: false, error: e.toString(), comments: []);
    }
  }

  // Create a new comment
  static Future<CommentResult> createComment(
    String postId,
    String content, {
    String? parentCommentId,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/comments');

      final body = {
        'postId': postId,
        'content': content,
        if (parentCommentId != null) 'parentCommentId': parentCommentId,
      };

      print('🔄 CommentService: Creating comment for post $postId');
      print('🔄 CommentService: Request body: ${json.encode(body)}');

      final headers = await _getHeaders();
      final response = await http
          .post(uri, headers: headers, body: json.encode(body))
          .timeout(timeoutDuration);

      print('🔄 CommentService: Response status: ${response.statusCode}');
      print('🔄 CommentService: Response body: ${response.body}');

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final comment = Comment.fromJson(data['data']);
          return CommentResult(success: true, comments: [comment]);
        } else {
          throw Exception(data['message'] ?? 'Failed to create comment');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to create comment');
      }
    } catch (e) {
      print('❌ CommentService: Error creating comment: $e');
      return CommentResult(success: false, error: e.toString(), comments: []);
    }
  }

  // Update a comment
  static Future<CommentResult> updateComment(
    String commentId,
    String content,
  ) async {
    try {
      final uri = Uri.parse('$baseUrl/comments/$commentId');

      final body = {'content': content};

      print('🔄 CommentService: Updating comment $commentId');
      print('🔄 CommentService: Request body: ${json.encode(body)}');

      final headers = await _getHeaders();
      final response = await http
          .put(uri, headers: headers, body: json.encode(body))
          .timeout(timeoutDuration);

      print('🔄 CommentService: Response status: ${response.statusCode}');
      print('🔄 CommentService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final comment = Comment.fromJson(data['data']);
          return CommentResult(success: true, comments: [comment]);
        } else {
          throw Exception(data['message'] ?? 'Failed to update comment');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to update comment');
      }
    } catch (e) {
      print('❌ CommentService: Error updating comment: $e');
      return CommentResult(success: false, error: e.toString(), comments: []);
    }
  }

  // Delete a comment
  static Future<CommentResult> deleteComment(String commentId) async {
    try {
      final uri = Uri.parse('$baseUrl/comments/$commentId');

      print('🔄 CommentService: Deleting comment $commentId');

      final headers = await _getHeaders();
      final response = await http
          .delete(uri, headers: headers)
          .timeout(timeoutDuration);

      print('🔄 CommentService: Response status: ${response.statusCode}');
      print('🔄 CommentService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return CommentResult(success: true, comments: []);
        } else {
          throw Exception(data['message'] ?? 'Failed to delete comment');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to delete comment');
      }
    } catch (e) {
      print('❌ CommentService: Error deleting comment: $e');
      return CommentResult(success: false, error: e.toString(), comments: []);
    }
  }

  // Toggle like on a comment
  static Future<CommentLikeResult> toggleCommentLike(String commentId) async {
    try {
      final uri = Uri.parse('$baseUrl/comments/$commentId/like');

      print('🔄 CommentService: Toggling like for comment $commentId');

      final headers = await _getHeaders();
      final response = await http
          .post(uri, headers: headers)
          .timeout(timeoutDuration);

      print('🔄 CommentService: Response status: ${response.statusCode}');
      print('🔄 CommentService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return CommentLikeResult(
            success: true,
            isLiked: data['data']['isLiked'],
            likes: data['data']['likes'],
          );
        } else {
          throw Exception(data['message'] ?? 'Failed to toggle comment like');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
          errorData['message'] ?? 'Failed to toggle comment like',
        );
      }
    } catch (e) {
      print('❌ CommentService: Error toggling comment like: $e');
      return CommentLikeResult(success: false, error: e.toString());
    }
  }

  // Get replies for a comment
  static Future<CommentResult> getReplies(
    String commentId, {
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/comments/$commentId/replies').replace(
        queryParameters: {'page': page.toString(), 'limit': limit.toString()},
      );

      print('🔄 CommentService: Getting replies for comment $commentId');

      final headers = await _getHeaders();
      final response = await http
          .get(uri, headers: headers)
          .timeout(timeoutDuration);

      print('🔄 CommentService: Response status: ${response.statusCode}');
      print('🔄 CommentService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final replies =
              (data['data']['replies'] as List)
                  .map((replyJson) => Comment.fromJson(replyJson))
                  .toList();

          return CommentResult(success: true, comments: replies);
        } else {
          throw Exception(data['message'] ?? 'Failed to get replies');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to get replies');
      }
    } catch (e) {
      print('❌ CommentService: Error getting replies: $e');
      return CommentResult(success: false, error: e.toString(), comments: []);
    }
  }
}

// Comment model
class Comment {
  final String id;
  final String postId;
  final String author;
  final String avatar;
  final String content;
  final String timeAgo;
  final int likes;
  final bool isLiked;
  final bool isEdited;
  final String? parentCommentId;
  final int replyCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  Comment({
    required this.id,
    required this.postId,
    required this.author,
    required this.avatar,
    required this.content,
    required this.timeAgo,
    required this.likes,
    required this.isLiked,
    required this.isEdited,
    this.parentCommentId,
    required this.replyCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['_id'] ?? '',
      postId: json['postId'] ?? '',
      author: json['author'] ?? 'Unknown User',
      avatar: json['avatar'] ?? '',
      content: json['content'] ?? '',
      timeAgo: json['timeAgo'] ?? '',
      likes: json['likes'] ?? 0,
      isLiked: json['isLiked'] ?? false,
      isEdited: json['isEdited'] ?? false,
      parentCommentId: json['parentCommentId'],
      replyCount: json['replyCount'] ?? 0,
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updatedAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Comment copyWith({
    String? id,
    String? postId,
    String? author,
    String? avatar,
    String? content,
    String? timeAgo,
    int? likes,
    bool? isLiked,
    bool? isEdited,
    String? parentCommentId,
    int? replyCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Comment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      author: author ?? this.author,
      avatar: avatar ?? this.avatar,
      content: content ?? this.content,
      timeAgo: timeAgo ?? this.timeAgo,
      likes: likes ?? this.likes,
      isLiked: isLiked ?? this.isLiked,
      isEdited: isEdited ?? this.isEdited,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      replyCount: replyCount ?? this.replyCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// Comment pagination model
class CommentPagination {
  final int currentPage;
  final int totalPages;
  final int totalComments;
  final bool hasNextPage;
  final bool hasPrevPage;

  CommentPagination({
    required this.currentPage,
    required this.totalPages,
    required this.totalComments,
    required this.hasNextPage,
    required this.hasPrevPage,
  });

  factory CommentPagination.fromJson(Map<String, dynamic> json) {
    return CommentPagination(
      currentPage: json['currentPage'] ?? 1,
      totalPages: json['totalPages'] ?? 1,
      totalComments: json['totalComments'] ?? 0,
      hasNextPage: json['hasNextPage'] ?? false,
      hasPrevPage: json['hasPrevPage'] ?? false,
    );
  }
}

// Comment result model
class CommentResult {
  final bool success;
  final List<Comment> comments;
  final CommentPagination? pagination;
  final String? error;

  CommentResult({
    required this.success,
    required this.comments,
    this.pagination,
    this.error,
  });
}

// Comment like result model
class CommentLikeResult {
  final bool success;
  final bool? isLiked;
  final int? likes;
  final String? error;

  CommentLikeResult({
    required this.success,
    this.isLiked,
    this.likes,
    this.error,
  });
}
