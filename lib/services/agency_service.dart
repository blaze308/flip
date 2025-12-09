import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/agency_model.dart';
import '../models/agency_member_model.dart';
import 'token_auth_service.dart';

/// Agency Service
/// Handles all agency-related API calls
class AgencyService {
  static const String baseUrl = 'https://flip-backend-mnpg.onrender.com/api';

  /// Get authentication headers
  static Future<Map<String, String>?> _getHeaders() async {
    final token = await TokenAuthService.getToken();
    if (token == null) {
      print('❌ AgencyService: No auth token');
      return null;
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Create a new agency (owner)
  static Future<Map<String, dynamic>> createAgency({
    required String name,
    String? description,
  }) async {
    try {
      final headers = await _getHeaders();
      if (headers == null) {
        return {
          'success': false,
          'message': 'No authentication token',
        };
      }

      final response = await http.post(
        Uri.parse('$baseUrl/agency/create'),
        headers: headers,
        body: json.encode({
          'name': name,
          'description': description ?? '',
        }),
      );

      print('📱 AgencyService.createAgency: ${response.statusCode}');

      final data = json.decode(response.body);

      if (response.statusCode == 201 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? 'Agency created successfully',
          'agency': data['data']?['agency'] != null
              ? AgencyModel.fromJson(data['data']['agency'])
              : null,
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Failed to create agency',
        'errors': data['errors'],
      };
    } catch (e) {
      print('❌ AgencyService.createAgency error: $e');
      return {
        'success': false,
        'message': 'An error occurred: $e',
      };
    }
  }

  /// Join an agency by agency ID
  static Future<Map<String, dynamic>> joinAgency({
    required String agencyId,
  }) async {
    try {
      final headers = await _getHeaders();
      if (headers == null) {
        return {
          'success': false,
          'message': 'No authentication token',
        };
      }

      final response = await http.post(
        Uri.parse('$baseUrl/agency/join'),
        headers: headers,
        body: json.encode({
          'agencyId': agencyId,
        }),
      );

      print('📱 AgencyService.joinAgency: ${response.statusCode}');

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? 'Application submitted successfully',
          'membership': data['data']?['membership'] != null
              ? AgencyMemberModel.fromJson(data['data']['membership'])
              : null,
          'agency': data['data']?['agency'] != null
              ? AgencyModel.fromJson(data['data']['agency'])
              : null,
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Failed to join agency',
        'errors': data['errors'],
      };
    } catch (e) {
      print('❌ AgencyService.joinAgency error: $e');
      return {
        'success': false,
        'message': 'An error occurred: $e',
      };
    }
  }

  /// Get current user's agency info
  static Future<AgencyMemberModel?> getMyAgency() async {
    try {
      final headers = await _getHeaders();
      if (headers == null) {
        print('❌ AgencyService: No auth token');
        return null;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/agency/my-agency'),
        headers: headers,
      );

      print('📱 AgencyService.getMyAgency: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          if (data['data']['membership'] == null) {
            return null; // Not a member of any agency
          }
          return AgencyMemberModel.fromJson(data['data']['membership']);
        }
      }

      print('❌ AgencyService.getMyAgency failed: ${response.body}');
      return null;
    } catch (e) {
      print('❌ AgencyService.getMyAgency error: $e');
      return null;
    }
  }

  /// Leave current agency
  static Future<Map<String, dynamic>> leaveAgency() async {
    try {
      final headers = await _getHeaders();
      if (headers == null) {
        return {
          'success': false,
          'message': 'No authentication token',
        };
      }

      final response = await http.post(
        Uri.parse('$baseUrl/agency/leave'),
        headers: headers,
      );

      print('📱 AgencyService.leaveAgency: ${response.statusCode}');

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? 'Left agency successfully',
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Failed to leave agency',
      };
    } catch (e) {
      print('❌ AgencyService.leaveAgency error: $e');
      return {
        'success': false,
        'message': 'An error occurred: $e',
      };
    }
  }

  /// Get agency statistics (for agents/owners)
  static Future<Map<String, dynamic>?> getAgencyStats() async {
    try {
      final headers = await _getHeaders();
      if (headers == null) {
        print('❌ AgencyService: No auth token');
        return null;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/agency/stats'),
        headers: headers,
      );

      print('📱 AgencyService.getAgencyStats: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return data['data']['stats'] as Map<String, dynamic>?;
        }
      }

      print('❌ AgencyService.getAgencyStats failed: ${response.body}');
      return null;
    } catch (e) {
      print('❌ AgencyService.getAgencyStats error: $e');
      return null;
    }
  }
}

