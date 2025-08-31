import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

class BackendService {
  // Update this URL to your backend server
  static const String baseUrl =
      'https://flip-backend-mnpg.onrender.com'; // Replace with your computer's IP address

  // Timeout duration for HTTP requests
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

  /// Get device information for tracking and security
  static Future<Map<String, dynamic>> _getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    final packageInfo = await PackageInfo.fromPlatform();

    Map<String, dynamic> deviceData = {'appVersion': packageInfo.version};

    if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      deviceData.addAll({
        'deviceType': 'ios',
        'deviceId': iosInfo.identifierForVendor ?? 'unknown',
        'deviceName': iosInfo.name,
        'osVersion': iosInfo.systemVersion,
        'platform': 'iOS',
      });
    } else if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      deviceData.addAll({
        'deviceType': 'android',
        'deviceId': androidInfo.id,
        'deviceName': '${androidInfo.brand} ${androidInfo.model}',
        'osVersion': androidInfo.version.release,
        'platform': 'Android',
      });
    } else {
      deviceData.addAll({
        'deviceType': 'other',
        'deviceId': 'unknown',
        'deviceName': 'Unknown Device',
        'platform': Platform.operatingSystem,
      });
    }

    return deviceData;
  }

  /// Make HTTP request with error handling
  static Future<Map<String, dynamic>> _makeRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? additionalHeaders,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final headers = await _getHeaders();

      if (additionalHeaders != null) {
        headers.addAll(additionalHeaders);
      }

      http.Response response;

      switch (method.toUpperCase()) {
        case 'GET':
          response = await http
              .get(uri, headers: headers)
              .timeout(timeoutDuration);
          break;
        case 'POST':
          response = await http
              .post(
                uri,
                headers: headers,
                body: body != null ? json.encode(body) : null,
              )
              .timeout(timeoutDuration);
          break;
        case 'PUT':
          response = await http
              .put(
                uri,
                headers: headers,
                body: body != null ? json.encode(body) : null,
              )
              .timeout(timeoutDuration);
          break;
        case 'DELETE':
          response = await http
              .delete(
                uri,
                headers: headers,
                body: body != null ? json.encode(body) : null,
              )
              .timeout(timeoutDuration);
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      final responseData = json.decode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return responseData;
      } else {
        throw BackendException(
          message: responseData['message'] ?? 'Request failed',
          statusCode: response.statusCode,
          code: responseData['code'],
        );
      }
    } catch (e) {
      if (e is BackendException) {
        rethrow;
      }
      throw BackendException(
        message: 'Network error: ${e.toString()}',
        statusCode: 0,
        code: 'NETWORK_ERROR',
      );
    }
  }

  /// Sync user data with backend after Firebase authentication
  /// This should be called after every successful Firebase auth
  static Future<BackendSyncResult> syncUser({bool forceUpdate = false}) async {
    try {
      final deviceInfo = await _getDeviceInfo();

      final response = await _makeRequest(
        'POST',
        '/auth/sync-user',
        body: {'deviceInfo': deviceInfo, 'forceUpdate': forceUpdate},
      );

      return BackendSyncResult.fromJson(response);
    } catch (e) {
      throw BackendException(
        message: 'Failed to sync user: ${e.toString()}',
        statusCode: 0,
        code: 'SYNC_FAILED',
      );
    }
  }

  /// Verify if user exists in backend database
  static Future<BackendVerifyResult> verifyUser() async {
    try {
      final response = await _makeRequest('GET', '/auth/verify');
      return BackendVerifyResult.fromJson(response);
    } catch (e) {
      if (e is BackendException && e.code == 'USER_NOT_SYNCED') {
        return BackendVerifyResult(
          success: false,
          message: 'User not synced',
          syncRequired: true,
        );
      }
      rethrow;
    }
  }

  /// Logout user and end session
  static Future<void> logout({String? sessionId}) async {
    try {
      await _makeRequest(
        'POST',
        '/auth/logout',
        body: sessionId != null ? {'sessionId': sessionId} : null,
      );
    } catch (e) {
      // Don't throw on logout errors - user should still be logged out locally
      print('Backend logout error: $e');
    }
  }

  /// Get user profile from backend
  static Future<BackendUser> getUserProfile() async {
    try {
      final response = await _makeRequest('GET', '/users/profile');
      return BackendUser.fromJson(response['data']['user']);
    } catch (e) {
      throw BackendException(
        message: 'Failed to get user profile: ${e.toString()}',
        statusCode: 0,
        code: 'PROFILE_FETCH_FAILED',
      );
    }
  }

  /// Update user profile
  static Future<BackendUser> updateUserProfile(
    Map<String, dynamic> profileData,
  ) async {
    try {
      final response = await _makeRequest(
        'PUT',
        '/users/profile',
        body: profileData,
      );
      return BackendUser.fromJson(response['data']['user']);
    } catch (e) {
      throw BackendException(
        message: 'Failed to update profile: ${e.toString()}',
        statusCode: 0,
        code: 'PROFILE_UPDATE_FAILED',
      );
    }
  }

  /// Delete user account
  static Future<void> deleteAccount() async {
    try {
      await _makeRequest(
        'DELETE',
        '/users/account',
        body: {'confirmDeletion': 'DELETE_MY_ACCOUNT'},
      );
    } catch (e) {
      throw BackendException(
        message: 'Failed to delete account: ${e.toString()}',
        statusCode: 0,
        code: 'ACCOUNT_DELETE_FAILED',
      );
    }
  }

  /// Get user's active sessions
  static Future<List<BackendSession>> getUserSessions() async {
    try {
      final response = await _makeRequest('GET', '/users/sessions');
      final sessions = response['data']['sessions'] as List;
      return sessions.map((s) => BackendSession.fromJson(s)).toList();
    } catch (e) {
      throw BackendException(
        message: 'Failed to get sessions: ${e.toString()}',
        statusCode: 0,
        code: 'SESSIONS_FETCH_FAILED',
      );
    }
  }

  /// End a specific session
  static Future<void> endSession(String sessionId) async {
    try {
      await _makeRequest('DELETE', '/users/sessions/$sessionId');
    } catch (e) {
      throw BackendException(
        message: 'Failed to end session: ${e.toString()}',
        statusCode: 0,
        code: 'SESSION_END_FAILED',
      );
    }
  }

  /// Get user's audit logs
  static Future<List<BackendAuditLog>> getAuditLogs({
    int limit = 50,
    int page = 1,
  }) async {
    try {
      final response = await _makeRequest(
        'GET',
        '/users/audit-logs?limit=$limit&page=$page',
      );
      final logs = response['data']['logs'] as List;
      return logs.map((l) => BackendAuditLog.fromJson(l)).toList();
    } catch (e) {
      throw BackendException(
        message: 'Failed to get audit logs: ${e.toString()}',
        statusCode: 0,
        code: 'AUDIT_LOGS_FETCH_FAILED',
      );
    }
  }

  /// Check backend server health
  static Future<Map<String, dynamic>> checkHealth() async {
    try {
      final uri = Uri.parse('$baseUrl/health');
      final response = await http.get(uri).timeout(timeoutDuration);
      return json.decode(response.body);
    } catch (e) {
      throw BackendException(
        message: 'Health check failed: ${e.toString()}',
        statusCode: 0,
        code: 'HEALTH_CHECK_FAILED',
      );
    }
  }
}

/// Custom exception for backend errors
class BackendException implements Exception {
  final String message;
  final int statusCode;
  final String? code;

  BackendException({
    required this.message,
    required this.statusCode,
    this.code,
  });

  @override
  String toString() => message;
}

/// Result from user sync operation
class BackendSyncResult {
  final bool success;
  final String message;
  final BackendUser? user;
  final bool isNewUser;
  final String? sessionId;

  BackendSyncResult({
    required this.success,
    required this.message,
    this.user,
    this.isNewUser = false,
    this.sessionId,
  });

  factory BackendSyncResult.fromJson(Map<String, dynamic> json) {
    return BackendSyncResult(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      user:
          json['data']?['user'] != null
              ? BackendUser.fromJson(json['data']['user'])
              : null,
      isNewUser: json['data']?['isNewUser'] ?? false,
      sessionId: json['data']?['sessionId'],
    );
  }
}

/// Result from user verification
class BackendVerifyResult {
  final bool success;
  final String message;
  final bool syncRequired;
  final BackendUser? user;

  BackendVerifyResult({
    required this.success,
    required this.message,
    required this.syncRequired,
    this.user,
  });

  factory BackendVerifyResult.fromJson(Map<String, dynamic> json) {
    return BackendVerifyResult(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      syncRequired: json['data']?['syncRequired'] ?? true,
      user:
          json['data']?['user'] != null
              ? BackendUser.fromJson(json['data']['user'])
              : null,
    );
  }
}

/// Backend user model
class BackendUser {
  final String id;
  final String firebaseUid;
  final String? email;
  final String? displayName;
  final String? phoneNumber;
  final String? photoURL;
  final List<String> providers;
  final bool emailVerified;
  final String role;
  final bool isActive;
  final Map<String, dynamic>? profile;
  final Map<String, dynamic>? subscription;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLogin;

  BackendUser({
    required this.id,
    required this.firebaseUid,
    this.email,
    this.displayName,
    this.phoneNumber,
    this.photoURL,
    required this.providers,
    required this.emailVerified,
    required this.role,
    required this.isActive,
    this.profile,
    this.subscription,
    this.createdAt,
    this.updatedAt,
    this.lastLogin,
  });

  factory BackendUser.fromJson(Map<String, dynamic> json) {
    return BackendUser(
      id: json['id'] ?? '',
      firebaseUid: json['firebaseUid'] ?? '',
      email: json['email'],
      displayName: json['displayName'],
      phoneNumber: json['phoneNumber'],
      photoURL: json['photoURL'],
      providers: List<String>.from(json['providers'] ?? []),
      emailVerified: json['emailVerified'] ?? false,
      role: json['role'] ?? 'user',
      isActive: json['isActive'] ?? true,
      profile: json['profile'],
      subscription: json['subscription'],
      createdAt:
          json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt:
          json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      lastLogin:
          json['lastLogin'] != null ? DateTime.parse(json['lastLogin']) : null,
    );
  }
}

/// Backend session model
class BackendSession {
  final String sessionId;
  final Map<String, dynamic>? deviceInfo;
  final String ipAddress;
  final DateTime startTime;
  final DateTime? endTime;
  final bool isActive;

  BackendSession({
    required this.sessionId,
    this.deviceInfo,
    required this.ipAddress,
    required this.startTime,
    this.endTime,
    required this.isActive,
  });

  factory BackendSession.fromJson(Map<String, dynamic> json) {
    return BackendSession(
      sessionId: json['sessionId'] ?? '',
      deviceInfo: json['deviceInfo'],
      ipAddress: json['ipAddress'] ?? '',
      startTime: DateTime.parse(json['startTime']),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      isActive: json['isActive'] ?? false,
    );
  }
}

/// Backend audit log model
class BackendAuditLog {
  final String action;
  final bool success;
  final String? errorMessage;
  final Map<String, dynamic>? details;
  final DateTime createdAt;

  BackendAuditLog({
    required this.action,
    required this.success,
    this.errorMessage,
    this.details,
    required this.createdAt,
  });

  factory BackendAuditLog.fromJson(Map<String, dynamic> json) {
    return BackendAuditLog(
      action: json['action'] ?? '',
      success: json['success'] ?? false,
      errorMessage: json['errorMessage'],
      details: json['details'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
