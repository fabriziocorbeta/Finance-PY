import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/holding.dart';
import 'api_config.dart';

class HoldingsService {
  Future<Map<String, dynamic>> getHoldings({
    required String accessToken,
    String? accountId,
    int page = 1,
    int perPage = 100,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (accountId != null) {
      queryParams['account_id'] = accountId;
    }

    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/holdings')
        .replace(queryParameters: queryParams);

    try {
      final response = await http.get(
        url,
        headers: ApiConfig.getAuthHeaders(accessToken),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        final holdingsList = (responseData['holdings'] as List)
            .map((json) => Holding.fromJson(json as Map<String, dynamic>))
            .toList();

        return {
          'success': true,
          'holdings': holdingsList,
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
          'error': responseData['error'] ?? 'Failed to fetch holdings',
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
