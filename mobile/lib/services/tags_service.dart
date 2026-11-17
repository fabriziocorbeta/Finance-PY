import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/tag.dart';
import 'api_config.dart';

class TagsService {
  Future<Map<String, dynamic>> getTags({required String accessToken}) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/tags');

    try {
      final response = await http.get(
        url,
        headers: ApiConfig.getAuthHeaders(accessToken),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final rawList = responseData is List ? responseData : <dynamic>[];
        final tags = rawList.map((json) => Tag.fromJson(json as Map<String, dynamic>)).toList();
        return {'success': true, 'tags': tags};
      } else if (response.statusCode == 401) {
        return {'success': false, 'error': 'unauthorized'};
      } else {
        final responseData = jsonDecode(response.body);
        return {'success': false, 'error': responseData['error'] ?? 'Failed to fetch tags'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }
}
