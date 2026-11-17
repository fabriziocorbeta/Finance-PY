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

  Future<Map<String, dynamic>> createReceivable({
    required String accessToken,
    required String name,
    required double totalAmount,
    String? currency,
    int? installmentCount,
    int? dueDay,
    String? firstDueDate,
    String? notes,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/receivables');

    try {
      final response = await http.post(
        url,
        headers: {
          ...ApiConfig.getAuthHeaders(accessToken),
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'receivable': {
            'name': name,
            'total_amount': totalAmount,
            if (currency != null) 'currency': currency,
            if (installmentCount != null) 'installment_count': installmentCount,
            if (dueDay != null) 'due_day': dueDay,
            if (firstDueDate != null) 'first_due_date': firstDueDate,
            if (notes != null) 'notes': notes,
          },
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        return {'success': true, 'receivable': Receivable.fromJson(responseData['data'] as Map<String, dynamic>)};
      } else {
        final responseData = jsonDecode(response.body);
        return {'success': false, 'error': responseData['message'] ?? responseData['error'] ?? 'Failed to create receivable'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> deleteReceivable({
    required String accessToken,
    required String receivableId,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/receivables/$receivableId');

    try {
      final response = await http.delete(
        url,
        headers: ApiConfig.getAuthHeaders(accessToken),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return {'success': true};
      } else {
        final responseData = jsonDecode(response.body);
        return {'success': false, 'error': responseData['message'] ?? responseData['error'] ?? 'Failed to delete receivable'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }
}
