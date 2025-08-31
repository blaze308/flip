import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://flip-backend-mnpg.onrender.com/api';
  static const Duration timeoutDuration = Duration(seconds: 30);

  // Headers for API requests
  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Headers with authentication token
  static Map<String, String> _headersWithAuth(String token) => {
    ..._headers,
    'Authorization': 'Bearer $token',
  };

  // Handle HTTP exceptions
  static ApiException _handleHttpError(http.Response response) {
    final Map<String, dynamic> errorData;

    try {
      errorData = json.decode(response.body);
    } catch (e) {
      return ApiException(
        message: 'Network error occurred',
        statusCode: response.statusCode,
      );
    }

    return ApiException(
      message: errorData['message'] ?? 'An error occurred',
      statusCode: response.statusCode,
      errors: errorData['errors'],
    );
  }

  // Generic GET request
  static Future<Map<String, dynamic>> _get(
    String endpoint, {
    String? token,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final headers = token != null ? _headersWithAuth(token) : _headers;

      final response = await http
          .get(uri, headers: headers)
          .timeout(timeoutDuration);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(response.body);
      } else {
        throw _handleHttpError(response);
      }
    } on SocketException {
      throw ApiException(
        message: 'No internet connection. Please check your network.',
        statusCode: 0,
      );
    } on HttpException {
      throw ApiException(
        message: 'Network error occurred. Please try again.',
        statusCode: 0,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'An unexpected error occurred: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  // Generic POST request
  static Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, dynamic> data, {
    String? token,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final headers = token != null ? _headersWithAuth(token) : _headers;

      final response = await http
          .post(uri, headers: headers, body: json.encode(data))
          .timeout(timeoutDuration);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(response.body);
      } else {
        throw _handleHttpError(response);
      }
    } on SocketException {
      throw ApiException(
        message: 'No internet connection. Please check your network.',
        statusCode: 0,
      );
    } on HttpException {
      throw ApiException(
        message: 'Network error occurred. Please try again.',
        statusCode: 0,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'An unexpected error occurred: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  // Register user
  static Future<AuthResponse> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final data = {'fullName': fullName, 'email': email, 'password': password};

    final response = await _post('/auth/register', data);
    return AuthResponse.fromJson(response);
  }

  // Login user
  static Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final data = {'email': email, 'password': password};

    final response = await _post('/auth/login', data);
    return AuthResponse.fromJson(response);
  }

  // Get user profile
  static Future<UserProfile> getProfile(String token) async {
    final response = await _get('/auth/me', token: token);
    return UserProfile.fromJson(response['data']);
  }

  // Health check
  static Future<Map<String, dynamic>> healthCheck() async {
    return await _get('/health');
  }
}

// Custom exception class for API errors
class ApiException implements Exception {
  final String message;
  final int statusCode;
  final List<String>? errors;

  ApiException({required this.message, required this.statusCode, this.errors});

  @override
  String toString() {
    if (errors != null && errors!.isNotEmpty) {
      return '${errors!.join(', ')}';
    }
    return message;
  }
}

// Auth response model
class AuthResponse {
  final bool success;
  final String message;
  final UserData? user;
  final String? token;

  AuthResponse({
    required this.success,
    required this.message,
    this.user,
    this.token,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      user:
          json['data']?['user'] != null
              ? UserData.fromJson(json['data']['user'])
              : null,
      token: json['data']?['token'],
    );
  }
}

// User data model
class UserData {
  final String id;
  final String fullName;
  final String email;
  final bool isEmailVerified;
  final DateTime? createdAt;
  final DateTime? lastLogin;

  UserData({
    required this.id,
    required this.fullName,
    required this.email,
    required this.isEmailVerified,
    this.createdAt,
    this.lastLogin,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      id: json['id'] ?? '',
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
      isEmailVerified: json['isEmailVerified'] ?? false,
      createdAt:
          json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      lastLogin:
          json['lastLogin'] != null ? DateTime.parse(json['lastLogin']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'isEmailVerified': isEmailVerified,
      'createdAt': createdAt?.toIso8601String(),
      'lastLogin': lastLogin?.toIso8601String(),
    };
  }
}

// User profile model (for profile endpoint)
class UserProfile {
  final UserData user;

  UserProfile({required this.user});

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(user: UserData.fromJson(json['user']));
  }
}
