import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sale.dart';
import 'api_config.dart';

class SalesService {
  Future<Map<String, dynamic>> getSales({
    required String accessToken,
    int page = 1,
    int perPage = 50,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/sales').replace(
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
        final sales = rawData.map((json) => Sale.fromJson(json as Map<String, dynamic>)).toList();
        return {'success': true, 'sales': sales};
      } else if (response.statusCode == 401) {
        return {'success': false, 'error': 'unauthorized'};
      } else {
        final responseData = jsonDecode(response.body);
        return {'success': false, 'error': responseData['error'] ?? 'Failed to fetch sales'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> createSale({
    required String accessToken,
    required String accountId,
    String? clientName,
    String? currency,
    String? paymentMethod,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/sales');

    try {
      final response = await http.post(
        url,
        headers: {
          ...ApiConfig.getAuthHeaders(accessToken),
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'sale': {
            'account_id': accountId,
            if (clientName != null) 'client_name': clientName,
            if (currency != null) 'currency': currency,
            if (paymentMethod != null) 'payment_method': paymentMethod,
            if (notes != null) 'notes': notes,
            'sale_items_attributes': items,
          },
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        return {'success': true, 'sale': Sale.fromJson(responseData['data'] as Map<String, dynamic>)};
      } else {
        final responseData = jsonDecode(response.body);
        return {'success': false, 'error': responseData['message'] ?? responseData['error'] ?? 'Failed to create sale'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> deleteSale({
    required String accessToken,
    required String saleId,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/sales/$saleId');

    try {
      final response = await http.delete(
        url,
        headers: ApiConfig.getAuthHeaders(accessToken),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 204) {
        return {'success': true};
      } else {
        final responseData = jsonDecode(response.body);
        return {'success': false, 'error': responseData['message'] ?? responseData['error'] ?? 'Failed to delete sale'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> completeSale({
    required String accessToken,
    required String saleId,
  }) async {
    return _transition(accessToken: accessToken, saleId: saleId, action: 'complete');
  }

  Future<Map<String, dynamic>> cancelSale({
    required String accessToken,
    required String saleId,
  }) async {
    return _transition(accessToken: accessToken, saleId: saleId, action: 'cancel');
  }

  Future<Map<String, dynamic>> _transition({
    required String accessToken,
    required String saleId,
    required String action,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/sales/$saleId/$action');

    try {
      final response = await http.post(
        url,
        headers: ApiConfig.getAuthHeaders(accessToken),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {'success': true, 'sale': Sale.fromJson(responseData['data'] as Map<String, dynamic>)};
      } else {
        final responseData = jsonDecode(response.body);
        return {'success': false, 'error': responseData['message'] ?? responseData['error'] ?? 'Failed to $action sale'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }
}
