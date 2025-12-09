import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/task_model.dart';
import 'token_auth_service.dart';

/// Tasks Service
/// Handles task management and progress tracking
class TasksService {
  static const String baseUrl = 'https://flip-backend-mnpg.onrender.com/api';

  /// Get all tasks with user progress
  static Future<List<TaskModel>> getTasks({String? type}) async {
    try {
      final token = await TokenAuthService.getToken();
      if (token == null) throw Exception('Authentication token not found');

      final uri = type != null
          ? Uri.parse('$baseUrl/tasks?type=$type')
          : Uri.parse('$baseUrl/tasks');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📱 TasksService.getTasks: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final tasks = data['data']['tasks'] as List;
          return tasks
              .map((t) => TaskModel.fromJson(t as Map<String, dynamic>))
              .toList();
        }
      }

      print('❌ TasksService.getTasks failed: ${response.body}');
      return [];
    } catch (e) {
      print('❌ TasksService.getTasks error: $e');
      return [];
    }
  }

  /// Claim task rewards
  static Future<Map<String, dynamic>> claimTaskReward(String taskId) async {
    try {
      final token = await TokenAuthService.getToken();
      if (token == null) throw Exception('Authentication token not found');

      final response = await http.post(
        Uri.parse('$baseUrl/tasks/$taskId/claim'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📱 TasksService.claimTaskReward: ${response.statusCode}');

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'rewards': data['data']['rewards'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to claim reward',
        };
      }
    } catch (e) {
      print('❌ TasksService.claimTaskReward error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  /// Get task completion summary
  static Future<Map<String, int>?> getTaskSummary() async {
    try {
      final token = await TokenAuthService.getToken();
      if (token == null) throw Exception('Authentication token not found');

      final response = await http.get(
        Uri.parse('$baseUrl/tasks/summary'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📱 TasksService.getTaskSummary: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return {
            'totalTasks': (data['data']['totalTasks'] as num).toInt(),
            'completedTasks': (data['data']['completedTasks'] as num).toInt(),
            'claimedTasks': (data['data']['claimedTasks'] as num).toInt(),
          };
        }
      }

      print('❌ TasksService.getTaskSummary failed: ${response.body}');
      return null;
    } catch (e) {
      print('❌ TasksService.getTaskSummary error: $e');
      return null;
    }
  }
}

