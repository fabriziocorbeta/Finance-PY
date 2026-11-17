import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/report_summary.dart';
import 'api_config.dart';

class ReportsService {
  Future<Map<String, dynamic>> getSummary({
    required String accessToken,
    String periodType = 'monthly',
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/reports/summary').replace(
      queryParameters: {'period_type': periodType},
    );

    try {
      final response = await http.get(
        url,
        headers: ApiConfig.getAuthHeaders(accessToken),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {
          'success': true,
          'summary': ReportSummary.fromJson(responseData as Map<String, dynamic>),
        };
      } else if (response.statusCode == 401) {
        return {'success': false, 'error': 'unauthorized'};
      } else {
        final responseData = jsonDecode(response.body);
        return {'success': false, 'error': responseData['error'] ?? 'Failed to fetch report'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }
}
