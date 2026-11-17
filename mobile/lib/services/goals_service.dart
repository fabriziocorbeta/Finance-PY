import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/goal.dart';
import 'api_config.dart';

class GoalsService {
  Future<Map<String, dynamic>> getGoals({
    required String accessToken,
    int page = 1,
    int perPage = 50,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/goals').replace(
      queryParameters: {
        'page': page.toString(),
        'per_page': perPage.toString(),
      },
    );

    try {
      final response = await http.get(
        url,
        headers: ApiConfig.getAuthHeaders(accessToken),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final rawData = responseData['data'] as List? ?? [];
        final goalsList = rawData
            .map((json) => Goal.fromJson(json as Map<String, dynamic>))
            .toList();

        return {
          'success': true,
          'goals': goalsList,
          'meta': responseData['meta'],
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'unauthorized',
          'message': 'Session expired. Please login again.',
        };
      } else {
        final responseData = jsonDecode(response.body);
        return {
          'success': false,
          'error': responseData['error'] ?? 'Failed to fetch goals',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> createGoal({
    required String accessToken,
    required String name,
    required double targetAmount,
    String? currency,
    String? targetDate,
    required List<String> accountIds,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/goals');

    try {
      final response = await http.post(
        url,
        headers: {
          ...ApiConfig.getAuthHeaders(accessToken),
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': name,
          'target_amount': targetAmount,
          if (currency != null) 'currency': currency,
          if (targetDate != null) 'target_date': targetDate,
          'account_ids': accountIds,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        return {'success': true, 'goal': Goal.fromJson(responseData['data'] as Map<String, dynamic>)};
      } else {
        final responseData = jsonDecode(response.body);
        return {'success': false, 'error': responseData['message'] ?? responseData['error'] ?? 'Failed to create goal'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> updateGoal({
    required String accessToken,
    required String goalId,
    String? name,
    double? targetAmount,
    String? targetDate,
    String? state,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/goals/$goalId');

    try {
      final response = await http.patch(
        url,
        headers: {
          ...ApiConfig.getAuthHeaders(accessToken),
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          if (name != null) 'name': name,
          if (targetAmount != null) 'target_amount': targetAmount,
          if (targetDate != null) 'target_date': targetDate,
          if (state != null) 'state': state,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {'success': true, 'goal': Goal.fromJson(responseData['data'] as Map<String, dynamic>)};
      } else {
        final responseData = jsonDecode(response.body);
        return {'success': false, 'error': responseData['message'] ?? responseData['error'] ?? 'Failed to update goal'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }
}
