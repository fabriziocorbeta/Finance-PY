import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/purchase_order.dart';
import 'api_config.dart';

class PurchaseOrdersService {
  Future<Map<String, dynamic>> getPurchaseOrders({
    required String accessToken,
    int page = 1,
    int perPage = 50,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/purchase_orders').replace(
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
        final orders = rawData.map((json) => PurchaseOrder.fromJson(json as Map<String, dynamic>)).toList();
        return {'success': true, 'purchase_orders': orders};
      } else if (response.statusCode == 401) {
        return {'success': false, 'error': 'unauthorized'};
      } else {
        final responseData = jsonDecode(response.body);
        return {'success': false, 'error': responseData['error'] ?? 'Failed to fetch purchase orders'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> createPurchaseOrder({
    required String accessToken,
    required String accountId,
    String? supplierName,
    String? currency,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/purchase_orders');

    try {
      final response = await http.post(
        url,
        headers: {
          ...ApiConfig.getAuthHeaders(accessToken),
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'purchase_order': {
            'account_id': accountId,
            if (supplierName != null) 'supplier_name': supplierName,
            if (currency != null) 'currency': currency,
            if (notes != null) 'notes': notes,
            'purchase_order_items_attributes': items,
          },
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        return {'success': true, 'purchase_order': PurchaseOrder.fromJson(responseData['data'] as Map<String, dynamic>)};
      } else {
        final responseData = jsonDecode(response.body);
        return {'success': false, 'error': responseData['message'] ?? responseData['error'] ?? 'Failed to create purchase order'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> deletePurchaseOrder({
    required String accessToken,
    required String purchaseOrderId,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/purchase_orders/$purchaseOrderId');

    try {
      final response = await http.delete(
        url,
        headers: ApiConfig.getAuthHeaders(accessToken),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 204) {
        return {'success': true};
      } else {
        final responseData = jsonDecode(response.body);
        return {'success': false, 'error': responseData['message'] ?? responseData['error'] ?? 'Failed to delete purchase order'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> receivePurchaseOrder({
    required String accessToken,
    required String purchaseOrderId,
  }) async {
    return _transition(accessToken: accessToken, purchaseOrderId: purchaseOrderId, action: 'receive');
  }

  Future<Map<String, dynamic>> cancelPurchaseOrder({
    required String accessToken,
    required String purchaseOrderId,
  }) async {
    return _transition(accessToken: accessToken, purchaseOrderId: purchaseOrderId, action: 'cancel');
  }

  Future<Map<String, dynamic>> _transition({
    required String accessToken,
    required String purchaseOrderId,
    required String action,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/purchase_orders/$purchaseOrderId/$action');

    try {
      final response = await http.post(
        url,
        headers: ApiConfig.getAuthHeaders(accessToken),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {'success': true, 'purchase_order': PurchaseOrder.fromJson(responseData['data'] as Map<String, dynamic>)};
      } else {
        final responseData = jsonDecode(response.body);
        return {'success': false, 'error': responseData['message'] ?? responseData['error'] ?? 'Failed to $action purchase order'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }
}
