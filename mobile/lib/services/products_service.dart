import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import 'api_config.dart';

class ProductsService {
  Future<Map<String, dynamic>> getProducts({
    required String accessToken,
    int page = 1,
    int perPage = 50,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/products').replace(
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
        final products = rawData.map((json) => Product.fromJson(json as Map<String, dynamic>)).toList();
        return {'success': true, 'products': products};
      } else if (response.statusCode == 401) {
        return {'success': false, 'error': 'unauthorized'};
      } else {
        final responseData = jsonDecode(response.body);
        return {'success': false, 'error': responseData['error'] ?? 'Failed to fetch products'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  Map<String, dynamic> _productBody({
    required String name,
    String? sku,
    String? category,
    String? supplier,
    required double buyPrice,
    required double sellPrice,
    required String currency,
    int? minStock,
    String? description,
    int? initialStock,
  }) {
    return {
      'product': {
        'name': name,
        if (sku != null) 'sku': sku,
        if (category != null) 'category': category,
        if (supplier != null) 'supplier': supplier,
        'buy_price': buyPrice,
        'sell_price': sellPrice,
        'currency': currency,
        if (minStock != null) 'min_stock': minStock,
        if (description != null) 'description': description,
        if (initialStock != null) 'initial_stock': initialStock,
      },
    };
  }

  Future<Map<String, dynamic>> createProduct({
    required String accessToken,
    required String name,
    String? sku,
    String? category,
    String? supplier,
    required double buyPrice,
    required double sellPrice,
    required String currency,
    int? minStock,
    String? description,
    int initialStock = 0,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/products');

    try {
      final response = await http.post(
        url,
        headers: {
          ...ApiConfig.getAuthHeaders(accessToken),
          'Content-Type': 'application/json',
        },
        body: jsonEncode(_productBody(
          name: name,
          sku: sku,
          category: category,
          supplier: supplier,
          buyPrice: buyPrice,
          sellPrice: sellPrice,
          currency: currency,
          minStock: minStock,
          description: description,
          initialStock: initialStock,
        )),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        return {'success': true, 'product': Product.fromJson(responseData['data'] as Map<String, dynamic>)};
      } else {
        final responseData = jsonDecode(response.body);
        return {'success': false, 'error': responseData['message'] ?? responseData['error'] ?? 'Failed to create product'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> updateProduct({
    required String accessToken,
    required String productId,
    required String name,
    String? sku,
    String? category,
    String? supplier,
    required double buyPrice,
    required double sellPrice,
    required String currency,
    int? minStock,
    String? description,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/products/$productId');

    try {
      final response = await http.patch(
        url,
        headers: {
          ...ApiConfig.getAuthHeaders(accessToken),
          'Content-Type': 'application/json',
        },
        body: jsonEncode(_productBody(
          name: name,
          sku: sku,
          category: category,
          supplier: supplier,
          buyPrice: buyPrice,
          sellPrice: sellPrice,
          currency: currency,
          minStock: minStock,
          description: description,
        )),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {'success': true, 'product': Product.fromJson(responseData['data'] as Map<String, dynamic>)};
      } else {
        final responseData = jsonDecode(response.body);
        return {'success': false, 'error': responseData['message'] ?? responseData['error'] ?? 'Failed to update product'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> deleteProduct({
    required String accessToken,
    required String productId,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/products/$productId');

    try {
      final response = await http.delete(
        url,
        headers: ApiConfig.getAuthHeaders(accessToken),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 204) {
        return {'success': true};
      } else {
        final responseData = jsonDecode(response.body);
        return {'success': false, 'error': responseData['message'] ?? responseData['error'] ?? 'Failed to delete product'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }
}
