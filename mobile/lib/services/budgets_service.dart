import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/budget.dart';
import 'api_config.dart';

class BudgetsService {
  Future<Map<String, dynamic>> getBudgets({
    required String accessToken,
    int page = 1,
    int perPage = 25,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/budgets').replace(
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
        final budgetsList = rawData
            .map((json) => Budget.fromJson(json as Map<String, dynamic>))
            .toList();

        return {
          'success': true,
          'budgets': budgetsList,
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
          'error': responseData['error'] ?? 'Failed to fetch budgets',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }
}
