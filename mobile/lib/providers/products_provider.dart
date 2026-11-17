import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../services/products_service.dart';
import '../services/log_service.dart';

class ProductsProvider with ChangeNotifier {
  final ProductsService _service = ProductsService();
  final LogService _log = LogService.instance;

  List<Product> _products = [];
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Product> get products => List.unmodifiable(_products);

  Future<void> fetchProducts({required String accessToken}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _service.getProducts(accessToken: accessToken);

      if (result['success'] == true) {
        _products = result['products'] as List<Product>;
        _errorMessage = null;
      } else {
        _errorMessage = result['error'] as String? ?? 'Failed to fetch products';
        _log.error('ProductsProvider', 'Failed to fetch: $_errorMessage');
      }
    } catch (e) {
      _errorMessage = 'Failed to load products';
      _log.error('ProductsProvider', 'Exception: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
    final result = await _service.createProduct(
      accessToken: accessToken,
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
    );
    if (result['success'] == true) {
      _products = [..._products, result['product'] as Product]..sort((a, b) => a.name.compareTo(b.name));
      notifyListeners();
    }
    return result;
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
    final result = await _service.updateProduct(
      accessToken: accessToken,
      productId: productId,
      name: name,
      sku: sku,
      category: category,
      supplier: supplier,
      buyPrice: buyPrice,
      sellPrice: sellPrice,
      currency: currency,
      minStock: minStock,
      description: description,
    );
    if (result['success'] == true) {
      final updated = result['product'] as Product;
      _products = _products.map((p) => p.id == productId ? updated : p).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      notifyListeners();
    }
    return result;
  }

  Future<Map<String, dynamic>> deleteProduct({
    required String accessToken,
    required String productId,
  }) async {
    final result = await _service.deleteProduct(accessToken: accessToken, productId: productId);
    if (result['success'] == true) {
      _products = _products.where((p) => p.id != productId).toList();
      notifyListeners();
    }
    return result;
  }

  void clear() {
    _products = [];
    _errorMessage = null;
    notifyListeners();
  }
}
