import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import 'token_auth_service.dart';

class ChatService {
  // Update this URL to match your backend server
  static const String baseUrl = 'https://flip-backend-mnpg.onrender.com';
  static const Duration timeoutDuration = Duration(seconds: 30);

  // Message cache
  static final Map<String, List<MessageModel>> _messageCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration cacheExpiry = Duration(minutes: 5);

  /// Clear message cache for a specific chat
  static void clearMessageCache(String chatId) {
    _messageCache.remove(chatId);
    _cacheTimestamps.remove(chatId);
  }

  /// Clear all message cache
  static void clearAllMessageCache() {
    _messageCache.clear();
    _cacheTimestamps.clear();
  }

  /// Get authentication headers (returns null for guest users)
  static Future<Map<String, String>?> _getHeaders() async {
    // Check if user is authenticated
    if (TokenAuthService.isAuthenticated) {
      final headers = await TokenAuthService.getAuthHeaders();
      if (headers != null) {
        print('💬 ChatService: Using JWT token for authenticated user');
        return headers;
      }
    }

    // Guest user - no authentication headers
    print('💬 ChatService: Guest user - no authentication headers');
    return null;
  }

  /// Get authentication headers for upload operations (throws if not authenticated)
  static Future<Map<String, String>> _getAuthHeaders() async {
    final headers = await _getHeaders();
    if (headers == null) {
      throw Exception('Authentication required for this operation');
    }
    return headers;
  }

  /// Wake up the backend if it's hibernating (Render free tier)
  static Future<void> _wakeUpBackend() async {
    try {
      print('💬 ChatService: Waking up backend...');
      final response = await http
          .get(
            Uri.parse('$baseUrl/health'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        print('💬 ChatService: Backend is awake');
      } else {
        print('💬 ChatService: Backend responded with ${response.statusCode}');
      }
    } catch (e) {
      print('💬 ChatService: Failed to wake backend: $e');
      // Continue anyway, the main request might still work
    }
  }

  /// Get all chats for the current user
  static Future<ChatListResult> getChats({
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    try {
      print('💬 ChatService: Fetching chats (page: $page, limit: $limit)');

      final headers = await _getAuthHeaders();
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final uri = Uri.parse(
        '$baseUrl/api/chats',
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: headers)
          .timeout(timeoutDuration);

      print('💬 ChatService: Response status: ${response.statusCode}');
      print('💬 ChatService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        // Handle case where data might not have expected structure
        if (data['data'] == null) {
          print('💬 ChatService: Warning - No data field in response');
          return ChatListResult(
            success: true,
            chats: [],
            message: data['message']?.toString() ?? 'No chats available',
          );
        }

        final chatsData = data['data'] as Map<String, dynamic>;
        final chatsList = (chatsData['chats'] as List<dynamic>?) ?? [];

        final chats =
            chatsList.map((chatJson) {
              final chat = ChatModel.fromJson(chatJson as Map<String, dynamic>);
              // Log chat details for debugging
              print('💬 ChatService: Chat ${chat.id}:');
              print('  - Type: ${chat.type.name}');
              print('  - Name: ${chat.name}');
              print('  - Members count: ${chat.members.length}');
              for (var i = 0; i < chat.members.length; i++) {
                final member = chat.members[i];
                print('  - Member $i:');
                print('    - userId: ${member.userId}');
                print('    - displayName: ${member.displayName}');
                print('    - username: ${member.username}');
                print(
                  '    - user object: ${member.user != null ? "populated" : "null"}',
                );
                if (member.user != null) {
                  print('    - user.username: ${member.user!.username}');
                  print('    - user.displayName: ${member.user!.displayName}');
                }
              }
              return chat;
            }).toList();

        print('💬 ChatService: Successfully loaded ${chats.length} chats');

        return ChatListResult(
          success: true,
          chats: chats,
          message: data['message']?.toString() ?? 'Chats loaded successfully',
        );
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        throw Exception(errorData['message'] ?? 'Failed to load chats');
      }
    } catch (e) {
      print('💬 ChatService: Error loading chats: $e');
      return ChatListResult(
        success: false,
        chats: [],
        message: 'Failed to load chats: ${e.toString()}',
      );
    }
  }

  /// Get a specific chat by ID
  static Future<ChatResult> getChat(String chatId) async {
    try {
      print('💬 ChatService: Fetching chat $chatId');

      final headers = await _getAuthHeaders();
      final uri = Uri.parse('$baseUrl/api/chats/$chatId');

      final response = await http
          .get(uri, headers: headers)
          .timeout(timeoutDuration);

      print('💬 ChatService: Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final chatData = data['data'] as Map<String, dynamic>;
        final chat = ChatModel.fromJson(
          chatData['chat'] as Map<String, dynamic>,
        );

        print('💬 ChatService: Successfully loaded chat ${chat.id}');

        return ChatResult(
          success: true,
          chat: chat,
          message: data['message']?.toString() ?? 'Chat loaded successfully',
        );
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        throw Exception(errorData['message'] ?? 'Failed to load chat');
      }
    } catch (e) {
      print('💬 ChatService: Error loading chat: $e');
      return ChatResult(
        success: false,
        chat: null,
        message: 'Failed to load chat: ${e.toString()}',
      );
    }
  }

  /// Create a new chat
  static Future<ChatResult> createChat({
    required ChatType type,
    required List<String> participants,
    String? name,
    String? description,
  }) async {
    try {
      print(
        '💬 ChatService: Creating ${type.name} chat with ${participants.length} participants',
      );

      final headers = await _getAuthHeaders();
      final uri = Uri.parse('$baseUrl/api/chats');

      final body = {
        'type': type.name,
        'participants': participants,
        if (name != null) 'name': name,
        if (description != null) 'description': description,
      };

      final response = await http
          .post(uri, headers: headers, body: json.encode(body))
          .timeout(timeoutDuration);

      print('💬 ChatService: Response status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final chatData = data['data'] as Map<String, dynamic>;
        final chat = ChatModel.fromJson(
          chatData['chat'] as Map<String, dynamic>,
        );

        print('💬 ChatService: Successfully created chat ${chat.id}');

        return ChatResult(
          success: true,
          chat: chat,
          message: data['message']?.toString() ?? 'Chat created successfully',
        );
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        throw Exception(errorData['message'] ?? 'Failed to create chat');
      }
    } catch (e) {
      print('💬 ChatService: Error creating chat: $e');
      return ChatResult(
        success: false,
        chat: null,
        message: 'Failed to create chat: ${e.toString()}',
      );
    }
  }

  /// Get messages in a chat
  static Future<MessageListResult> getMessages(
    String chatId, {
    int page = 1,
    int limit = 50,
    DateTime? before,
    DateTime? after,
    MessageType? type,
    bool useCache = true,
  }) async {
    try {
      // Check cache first (only for first page without filters)
      if (useCache &&
          page == 1 &&
          before == null &&
          after == null &&
          type == null) {
        final cacheKey = chatId;
        final cachedMessages = _messageCache[cacheKey];
        final cacheTime = _cacheTimestamps[cacheKey];

        if (cachedMessages != null && cacheTime != null) {
          final isExpired = DateTime.now().difference(cacheTime) > cacheExpiry;
          if (!isExpired) {
            print('💬 ChatService: Using cached messages for chat $chatId');
            return MessageListResult(
              success: true,
              messages: cachedMessages,
              message: 'Messages loaded from cache',
            );
          }
        }
      }

      print(
        '💬 ChatService: Fetching messages for chat $chatId (page: $page, limit: $limit)',
      );

      final headers = await _getAuthHeaders();
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (before != null) {
        queryParams['before'] = before.toIso8601String();
      }
      if (after != null) {
        queryParams['after'] = after.toIso8601String();
      }
      if (type != null) {
        queryParams['type'] = type.name;
      }

      final uri = Uri.parse(
        '$baseUrl/api/chats/$chatId/messages',
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: headers)
          .timeout(timeoutDuration);

      print('💬 ChatService: Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final messagesData = data['data'] as Map<String, dynamic>;
        final messagesList = messagesData['messages'] as List<dynamic>;

        final messages =
            messagesList
                .map(
                  (messageJson) => MessageModel.fromJson(
                    messageJson as Map<String, dynamic>,
                  ),
                )
                .toList();

        print(
          '💬 ChatService: Successfully loaded ${messages.length} messages',
        );

        // Cache messages (only for first page without filters)
        if (page == 1 && before == null && after == null && type == null) {
          _messageCache[chatId] = messages;
          _cacheTimestamps[chatId] = DateTime.now();
        }

        return MessageListResult(
          success: true,
          messages: messages,
          message:
              data['message']?.toString() ?? 'Messages loaded successfully',
        );
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        throw Exception(errorData['message'] ?? 'Failed to load messages');
      }
    } catch (e) {
      print('💬 ChatService: Error loading messages: $e');
      return MessageListResult(
        success: false,
        messages: [],
        message: 'Failed to load messages: ${e.toString()}',
      );
    }
  }

  /// Send a text message
  static Future<MessageResult> sendTextMessage(
    String chatId,
    String content, {
    String? replyToMessageId,
    MessageType? messageType,
  }) async {
    try {
      final type = messageType ?? MessageType.text;
      print('💬 ChatService: Sending $type message to chat $chatId');

      final headers = await _getAuthHeaders();
      final uri = Uri.parse('$baseUrl/api/chats/$chatId/messages');

      final body = {
        'type': type.toString().split('.').last,
        'content': content,
        if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
      };

      final response = await http
          .post(uri, headers: headers, body: json.encode(body))
          .timeout(timeoutDuration);

      print('💬 ChatService: Response status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final messageData = data['data'] as Map<String, dynamic>;
        final message = MessageModel.fromJson(
          messageData['message'] as Map<String, dynamic>,
        );

        print('💬 ChatService: Successfully sent message ${message.id}');

        return MessageResult(
          success: true,
          message: message,
          resultMessage:
              data['message']?.toString() ?? 'Message sent successfully',
        );
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        throw Exception(errorData['message'] ?? 'Failed to send message');
      }
    } catch (e) {
      print('💬 ChatService: Error sending message: $e');
      return MessageResult(
        success: false,
        message: null,
        resultMessage: 'Failed to send message: ${e.toString()}',
      );
    }
  }

  /// Send a media message (image, video, audio, lottie, svga, file)
  static Future<MessageResult> sendMediaMessage(
    String chatId,
    MessageType type,
    File file, {
    String? content,
    String? replyToMessageId,
  }) async {
    try {
      print('💬 ChatService: Sending ${type.name} message to chat $chatId');

      // Wake up backend if it's hibernating
      await _wakeUpBackend();

      final headers = await _getAuthHeaders();
      headers.remove('Content-Type'); // Remove for multipart

      final uri = Uri.parse('$baseUrl/api/chats/$chatId/messages');
      final request = http.MultipartRequest('POST', uri);

      // Add headers
      request.headers.addAll(headers);

      // Add form fields
      request.fields['type'] = type.name;
      if (content != null && content.isNotEmpty) {
        request.fields['content'] = content;
      }
      if (replyToMessageId != null) {
        request.fields['replyToMessageId'] = replyToMessageId;
      }

      // Add file
      final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
      final multipartFile = await http.MultipartFile.fromPath(
        'media',
        file.path,
        contentType: MediaType.parse(mimeType),
      );
      request.files.add(multipartFile);

      final streamedResponse = await request.send().timeout(timeoutDuration);
      final response = await http.Response.fromStream(streamedResponse);

      print('💬 ChatService: Response status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final data = json.decode(response.body) as Map<String, dynamic>;
          final messageData = data['data'] as Map<String, dynamic>;
          final message = MessageModel.fromJson(
            messageData['message'] as Map<String, dynamic>,
          );

          print(
            '💬 ChatService: Successfully sent ${type.name} message ${message.id}',
          );

          return MessageResult(
            success: true,
            message: message,
            resultMessage:
                data['message']?.toString() ?? 'Message sent successfully',
          );
        } catch (e) {
          print('💬 ChatService: Error parsing response: $e');
          print('💬 ChatService: Response body: ${response.body}');
          throw Exception('Failed to parse server response');
        }
      } else {
        print('💬 ChatService: Error response body: ${response.body}');
        try {
          if (response.body.isNotEmpty) {
            final errorData =
                json.decode(response.body) as Map<String, dynamic>;
            throw Exception(errorData['message'] ?? 'Failed to send message');
          } else {
            throw Exception('Server error (${response.statusCode})');
          }
        } catch (e) {
          if (e is FormatException) {
            throw Exception('Server error (${response.statusCode})');
          }
          rethrow;
        }
      }
    } catch (e) {
      print('💬 ChatService: Error sending ${type.name} message: $e');
      return MessageResult(
        success: false,
        message: null,
        resultMessage: 'Failed to send message: ${e.toString()}',
      );
    }
  }

  /// Send a location message
  static Future<MessageResult> sendLocationMessage(
    String chatId,
    double latitude,
    double longitude, {
    String? address,
    String? name,
    String? replyToMessageId,
  }) async {
    try {
      print('💬 ChatService: Sending location message to chat $chatId');

      final headers = await _getAuthHeaders();
      final uri = Uri.parse('$baseUrl/api/chats/$chatId/messages');

      final body = {
        'type': 'location',
        'location': {
          'latitude': latitude,
          'longitude': longitude,
          if (address != null) 'address': address,
          if (name != null) 'name': name,
        },
        if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
      };

      final response = await http
          .post(uri, headers: headers, body: json.encode(body))
          .timeout(timeoutDuration);

      print('💬 ChatService: Response status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final messageData = data['data'] as Map<String, dynamic>;
        final message = MessageModel.fromJson(
          messageData['message'] as Map<String, dynamic>,
        );

        print(
          '💬 ChatService: Successfully sent location message ${message.id}',
        );

        return MessageResult(
          success: true,
          message: message,
          resultMessage:
              data['message']?.toString() ?? 'Location sent successfully',
        );
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        throw Exception(errorData['message'] ?? 'Failed to send location');
      }
    } catch (e) {
      print('💬 ChatService: Error sending location: $e');
      return MessageResult(
        success: false,
        message: null,
        resultMessage: 'Failed to send location: ${e.toString()}',
      );
    }
  }

  /// Send a contact message
  static Future<MessageResult> sendContactMessage(
    String chatId,
    String name, {
    String? phoneNumber,
    String? email,
    String? avatar,
    String? replyToMessageId,
  }) async {
    try {
      print('💬 ChatService: Sending contact message to chat $chatId');

      final headers = await _getAuthHeaders();
      final uri = Uri.parse('$baseUrl/api/chats/$chatId/messages');

      final body = {
        'type': 'contact',
        'contact': {
          'name': name,
          if (phoneNumber != null) 'phoneNumber': phoneNumber,
          if (email != null) 'email': email,
          if (avatar != null) 'avatar': avatar,
        },
        if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
      };

      final response = await http
          .post(uri, headers: headers, body: json.encode(body))
          .timeout(timeoutDuration);

      print('💬 ChatService: Response status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final messageData = data['data'] as Map<String, dynamic>;
        final message = MessageModel.fromJson(
          messageData['message'] as Map<String, dynamic>,
        );

        print(
          '💬 ChatService: Successfully sent contact message ${message.id}',
        );

        return MessageResult(
          success: true,
          message: message,
          resultMessage:
              data['message']?.toString() ?? 'Contact sent successfully',
        );
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        throw Exception(errorData['message'] ?? 'Failed to send contact');
      }
    } catch (e) {
      print('💬 ChatService: Error sending contact: $e');
      return MessageResult(
        success: false,
        message: null,
        resultMessage: 'Failed to send contact: ${e.toString()}',
      );
    }
  }

  /// Mark a message as read
  static Future<bool> markMessageAsRead(String chatId, String messageId) async {
    try {
      print('💬 ChatService: Marking message $messageId as read');

      final headers = await _getAuthHeaders();
      final uri = Uri.parse(
        '$baseUrl/api/chats/$chatId/messages/$messageId/read',
      );

      final response = await http
          .put(uri, headers: headers)
          .timeout(timeoutDuration);

      print('💬 ChatService: Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('💬 ChatService: Successfully marked message as read');
        return true;
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        print(
          '💬 ChatService: Failed to mark as read: ${errorData['message']}',
        );
        return false;
      }
    } catch (e) {
      print('💬 ChatService: Error marking message as read: $e');
      return false;
    }
  }

  /// Add reaction to a message
  static Future<bool> addReaction(
    String chatId,
    String messageId,
    String emoji,
  ) async {
    try {
      print('💬 ChatService: Adding reaction $emoji to message $messageId');

      final headers = await _getAuthHeaders();
      final uri = Uri.parse(
        '$baseUrl/api/chats/$chatId/messages/$messageId/reactions',
      );

      final body = {'emoji': emoji};

      final response = await http
          .post(uri, headers: headers, body: json.encode(body))
          .timeout(timeoutDuration);

      print('💬 ChatService: Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('💬 ChatService: Successfully added reaction');
        return true;
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        print(
          '💬 ChatService: Failed to add reaction: ${errorData['message']}',
        );
        return false;
      }
    } catch (e) {
      print('💬 ChatService: Error adding reaction: $e');
      return false;
    }
  }

  /// Remove reaction from a message
  static Future<bool> removeReaction(String chatId, String messageId) async {
    try {
      print('💬 ChatService: Removing reaction from message $messageId');

      final headers = await _getAuthHeaders();
      final uri = Uri.parse(
        '$baseUrl/api/chats/$chatId/messages/$messageId/reactions',
      );

      final response = await http
          .delete(uri, headers: headers)
          .timeout(timeoutDuration);

      print('💬 ChatService: Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('💬 ChatService: Successfully removed reaction');
        return true;
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        print(
          '💬 ChatService: Failed to remove reaction: ${errorData['message']}',
        );
        return false;
      }
    } catch (e) {
      print('💬 ChatService: Error removing reaction: $e');
      return false;
    }
  }

  /// Delete a message
  static Future<bool> deleteMessage(String chatId, String messageId) async {
    try {
      print('💬 ChatService: Deleting message $messageId from chat $chatId');

      final headers = await _getAuthHeaders();
      final uri = Uri.parse(
        '$baseUrl/api/chats/$chatId/messages/$messageId',
      );

      final response = await http
          .delete(uri, headers: headers)
          .timeout(timeoutDuration);

      print('💬 ChatService: Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('💬 ChatService: Successfully deleted message');
        // Clear cache when message is deleted
        clearMessageCache(chatId);
        return true;
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        print(
          '💬 ChatService: Failed to delete message: ${errorData['message']}',
        );
        return false;
      }
    } catch (e) {
      print('💬 ChatService: Error deleting message: $e');
      return false;
    }
  }
}

/// Result classes for API responses

class ChatListResult {
  final bool success;
  final List<ChatModel> chats;
  final String message;

  const ChatListResult({
    required this.success,
    required this.chats,
    required this.message,
  });
}

class ChatResult {
  final bool success;
  final ChatModel? chat;
  final String message;

  const ChatResult({
    required this.success,
    required this.chat,
    required this.message,
  });
}

class MessageListResult {
  final bool success;
  final List<MessageModel> messages;
  final String message;

  const MessageListResult({
    required this.success,
    required this.messages,
    required this.message,
  });
}

class MessageResult {
  final bool success;
  final MessageModel? message;
  final String resultMessage;

  const MessageResult({
    required this.success,
    required this.message,
    required this.resultMessage,
  });
}
