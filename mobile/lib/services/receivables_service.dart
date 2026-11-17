import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/receivable.dart';
import 'api_config.dart';

class ReceivablesService {
  Future<Map<String, dynamic>> getReceivables({
    required String accessToken,
    int page = 1,
    int perPage = 50,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/receivables').replace(
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
        final items = rawData.map((json) => Receivable.fromJson(json as Map<String, dynamic>)).toList();
        return {'success': true, 'receivables': items};
      } else if (response.statusCode == 401) {
        return {'success': false, 'error': 'unauthorized'};
      } else {
        final responseData = jsonDecode(response.body);
        return {'success': false, 'error': responseData['error'] ?? 'Failed to fetch receivables'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }
}
