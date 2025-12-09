import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/live_stream_model.dart';
import '../models/live_message_model.dart';
import '../models/audio_chat_user_model.dart';
import '../models/gift_model.dart';
import 'token_auth_service.dart';
import 'backend_service.dart';

/// Live Streaming Service
/// Handles all live streaming API calls
class LiveStreamingService {
  static const String baseUrl = BackendService.baseUrl;

  /// Get authentication headers
  static Future<Map<String, String>> _getHeaders() async {
    final headers = await TokenAuthService.getAuthHeaders();
    if (headers == null) {
      throw Exception('User not authenticated');
    }
    return headers;
  }

  // ========== LIVE STREAM MANAGEMENT ==========

  /// Create a new live stream
  static Future<LiveStreamModel> createLiveStream({
    required String liveType, // 'live', 'party', 'audio', 'battle'
    required String streamingChannel,
    required int authorUid,
    String? liveSubType,
    String? title,
    int? numberOfChairs,
    String? partyType,
    bool? isPrivate,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/live/create'),
        headers: headers,
        body: json.encode({
          'liveType': liveType,
          'streamingChannel': streamingChannel,
          'authorUid': authorUid,
          if (liveSubType != null) 'liveSubType': liveSubType,
          if (title != null) 'title': title,
          if (numberOfChairs != null) 'numberOfChairs': numberOfChairs,
          if (partyType != null) 'partyType': partyType,
          if (isPrivate != null) 'private': isPrivate,
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return LiveStreamModel.fromJson(data['data']);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to create live stream');
      }
    } catch (e) {
      print('❌ Create live stream error: $e');
      rethrow;
    }
  }

  /// Get all active live streams
  static Future<List<LiveStreamModel>> getActiveLiveStreams({
    String? liveType,
    int limit = 20,
    int skip = 0,
  }) async {
    try {
      final queryParams = {
        'limit': limit.toString(),
        'skip': skip.toString(),
        if (liveType != null && liveType != 'all') 'liveType': liveType,
      };

      final uri = Uri.parse('$baseUrl/api/live/active')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> liveStreamsJson = data['data'];
        return liveStreamsJson
            .map((json) => LiveStreamModel.fromJson(json))
            .toList();
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to fetch live streams');
      }
    } catch (e) {
      print('❌ Get active live streams error: $e');
      rethrow;
    }
  }

  /// Get live stream details
  static Future<LiveStreamModel> getLiveStreamDetails(String liveStreamId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/live/$liveStreamId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return LiveStreamModel.fromJson(data['data']);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to fetch live stream');
      }
    } catch (e) {
      print('❌ Get live stream details error: $e');
      rethrow;
    }
  }

  /// Join a live stream
  static Future<LiveStreamModel> joinLiveStream({
    required String liveStreamId,
    required int userUid,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/live/$liveStreamId/join'),
        headers: headers,
        body: json.encode({
          'userUid': userUid,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return LiveStreamModel.fromJson(data['data']['liveStream']);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to join live stream');
      }
    } catch (e) {
      print('❌ Join live stream error: $e');
      rethrow;
    }
  }

  /// Leave a live stream
  static Future<void> leaveLiveStream({
    required String liveStreamId,
    required int userUid,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/live/$liveStreamId/leave'),
        headers: headers,
        body: json.encode({
          'userUid': userUid,
        }),
      );

      if (response.statusCode != 200) {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to leave live stream');
      }
    } catch (e) {
      print('❌ Leave live stream error: $e');
      rethrow;
    }
  }

  /// End a live stream (host only)
  static Future<Map<String, dynamic>> endLiveStream(String liveStreamId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/live/$liveStreamId/end'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'];
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to end live stream');
      }
    } catch (e) {
      print('❌ End live stream error: $e');
      rethrow;
    }
  }

  /// Update live stream status (heartbeat/ping)
  static Future<void> updateLiveStreamStatus(String liveStreamId, {
    bool? streaming,
    int? viewersCount,
    String? streamingTime,
  }) async {
    try {
      final headers = await _getHeaders();
      final updateData = <String, dynamic>{};

      if (streaming != null) updateData['streaming'] = streaming;
      if (viewersCount != null) updateData['viewersCount'] = viewersCount;
      if (streamingTime != null) updateData['streamingTime'] = streamingTime;

      if (updateData.isEmpty) return;

      final response = await http.patch(
        Uri.parse('$baseUrl/api/live/$liveStreamId'),
        headers: headers,
        body: json.encode(updateData),
      );

      if (response.statusCode != 200) {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to update live stream status');
      }
    } catch (e) {
      print('❌ Update live stream status error: $e');
      rethrow;
    }
  }

  /// Force end abandoned live streams (admin/cleanup function)
  static Future<void> cleanupAbandonedStreams({int maxAgeMinutes = 30}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/live/cleanup'),
        headers: headers,
        body: json.encode({
          'maxAgeMinutes': maxAgeMinutes,
        }),
      );

      if (response.statusCode != 200) {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to cleanup abandoned streams');
      }
    } catch (e) {
      print('❌ Cleanup abandoned streams error: $e');
      rethrow;
    }
  }

  /// Get active live streams with status validation
  static Future<List<LiveStreamModel>> getValidatedActiveLiveStreams({
    String? liveType,
    int limit = 20,
    int skip = 0,
    int maxAgeMinutes = 30,
  }) async {
    try {
      // First cleanup any abandoned streams
      await cleanupAbandonedStreams(maxAgeMinutes: maxAgeMinutes);

      // Then get the active streams
      return getActiveLiveStreams(
        liveType: liveType,
        limit: limit,
        skip: skip,
      );
    } catch (e) {
      print('❌ Get validated active live streams error: $e');
      // Fallback to regular method if cleanup fails
      return getActiveLiveStreams(
        liveType: liveType,
        limit: limit,
        skip: skip,
      );
    }
  }

  // ========== MESSAGES ==========

  /// Send a message in live stream
  static Future<LiveMessageModel> sendMessage({
    required String liveStreamId,
    required String message,
    String messageType = 'COMMENT',
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/live/$liveStreamId/message'),
        headers: headers,
        body: json.encode({
          'message': message,
          'messageType': messageType,
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return LiveMessageModel.fromJson(data['data']);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to send message');
      }
    } catch (e) {
      print('❌ Send message error: $e');
      rethrow;
    }
  }

  /// Get live stream messages
  static Future<List<LiveMessageModel>> getMessages({
    required String liveStreamId,
    int limit = 50,
    DateTime? before,
  }) async {
    try {
      final queryParams = {
        'limit': limit.toString(),
        if (before != null) 'before': before.toIso8601String(),
      };

      final uri = Uri.parse('$baseUrl/api/live/$liveStreamId/messages')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> messagesJson = data['data'];
        return messagesJson
            .map((json) => LiveMessageModel.fromJson(json))
            .toList();
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to fetch messages');
      }
    } catch (e) {
      print('❌ Get messages error: $e');
      rethrow;
    }
  }

  // ========== VIEWERS ==========

  /// Get current viewers
  static Future<List<Map<String, dynamic>>> getViewers(String liveStreamId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/live/$liveStreamId/viewers'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data']);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to fetch viewers');
      }
    } catch (e) {
      print('❌ Get viewers error: $e');
      rethrow;
    }
  }

  // ========== PARTY SEATS ==========

  /// Get party room seats
  static Future<List<AudioChatUserModel>> getPartySeats(String liveStreamId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/live/$liveStreamId/seats'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> seatsJson = data['data'];
        return seatsJson
            .map((json) => AudioChatUserModel.fromJson(json))
            .toList();
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to fetch seats');
      }
    } catch (e) {
      print('❌ Get party seats error: $e');
      rethrow;
    }
  }

  /// Join a party seat
  static Future<AudioChatUserModel> joinPartySeat({
    required String liveStreamId,
    required int seatIndex,
    required int userUid,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/live/$liveStreamId/seats/$seatIndex/join'),
        headers: headers,
        body: json.encode({
          'userUid': userUid,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return AudioChatUserModel.fromJson(data['data']);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to join seat');
      }
    } catch (e) {
      print('❌ Join party seat error: $e');
      rethrow;
    }
  }

  /// Leave a party seat
  static Future<void> leavePartySeat({
    required String liveStreamId,
    required int seatIndex,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/live/$liveStreamId/seats/$seatIndex/leave'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to leave seat');
      }
    } catch (e) {
      print('❌ Leave party seat error: $e');
      rethrow;
    }
  }

  // ========== GIFTS ==========

  /// Get available gifts
  static Future<List<GiftModel>> getAvailableGifts() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/live/gifts/all'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> giftsJson = data['data'];
        return giftsJson.map((json) => GiftModel.fromJson(json)).toList();
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to fetch gifts');
      }
    } catch (e) {
      print('❌ Get available gifts error: $e');
      rethrow;
    }
  }

  // ========== UTILITY METHODS ==========

  /// Generate a unique channel name for live streaming
  static String generateChannelName(String userId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'live_${userId}_$timestamp';
  }

  /// Generate a unique call ID for live streaming
  static String generateCallID(String userId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'call_${userId}_$timestamp';
  }
}

