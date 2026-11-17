import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/recurring_transaction.dart';
import 'api_config.dart';

class RecurringTransactionsService {
  Future<Map<String, dynamic>> getRecurringTransactions({
    required String accessToken,
    int page = 1,
    int perPage = 50,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/recurring_transactions').replace(
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
        final rawList = responseData['recurring_transactions'] as List? ?? [];
        final list = rawList
            .map((json) => RecurringTransaction.fromJson(json as Map<String, dynamic>))
            .toList();

        return {
          'success': true,
          'recurring_transactions': list,
          'pagination': responseData['pagination'],
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
          'error': responseData['error'] ?? 'Failed to fetch recurring transactions',
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
