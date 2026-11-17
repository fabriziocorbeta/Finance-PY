import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/csv_import.dart';
import 'api_config.dart';

class ImportsService {
  Future<Map<String, dynamic>> getImports({required String accessToken}) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/imports');

    try {
      final response = await http.get(
        url,
        headers: ApiConfig.getAuthHeaders(accessToken),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final rawData = responseData['data'] as List? ?? [];
        final imports = rawData.map((json) => CsvImport.fromJson(json as Map<String, dynamic>)).toList();
        return {'success': true, 'imports': imports};
      } else if (response.statusCode == 401) {
        return {'success': false, 'error': 'unauthorized'};
      } else {
        final responseData = jsonDecode(response.body);
        return {'success': false, 'error': responseData['error'] ?? 'Failed to fetch imports'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  /// Creates a transaction CSV import from raw file text. The backend
  /// auto-detects columns from the header row; if it can't map everything
  /// confidently, the import is created but status_detail.configured comes
  /// back false and finishing the column mapping requires the web.
  Future<Map<String, dynamic>> createImport({
    required String accessToken,
    required String accountId,
    required String csvContent,
    bool publishIfReady = true,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/imports');

    try {
      final response = await http.post(
        url,
        headers: {
          ...ApiConfig.getAuthHeaders(accessToken),
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'type': 'TransactionImport',
          'account_id': accountId,
          'raw_file_content': csvContent,
          if (publishIfReady) 'publish': 'true',
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        return {
          'success': true,
          'import': CsvImport.fromJson(responseData['data'] as Map<String, dynamic>),
        };
      } else if (response.statusCode == 401) {
        return {'success': false, 'error': 'unauthorized'};
      } else {
        final responseData = jsonDecode(response.body);
        return {'success': false, 'error': responseData['message'] ?? responseData['error'] ?? 'Failed to create import'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> publishImport({
    required String accessToken,
    required String importId,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/imports/$importId/publish');

    try {
      final response = await http.post(
        url,
        headers: ApiConfig.getAuthHeaders(accessToken),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {
          'success': true,
          'import': CsvImport.fromJson(responseData['data'] as Map<String, dynamic>),
        };
      } else {
        final responseData = jsonDecode(response.body);
        return {'success': false, 'error': responseData['message'] ?? responseData['error'] ?? 'Failed to publish import'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }
}
