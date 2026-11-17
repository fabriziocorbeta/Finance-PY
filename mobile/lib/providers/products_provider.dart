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

  void clear() {
    _products = [];
    _errorMessage = null;
    notifyListeners();
  }
}
