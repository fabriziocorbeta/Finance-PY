import 'package:flutter/foundation.dart';
import '../models/purchase_order.dart';
import '../services/purchase_orders_service.dart';
import '../services/log_service.dart';

class PurchaseOrdersProvider with ChangeNotifier {
  final PurchaseOrdersService _service = PurchaseOrdersService();
  final LogService _log = LogService.instance;

  List<PurchaseOrder> _orders = [];
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<PurchaseOrder> get orders => List.unmodifiable(_orders);

  Future<void> fetchPurchaseOrders({required String accessToken}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _service.getPurchaseOrders(accessToken: accessToken);

      if (result['success'] == true) {
        _orders = result['purchase_orders'] as List<PurchaseOrder>;
        _errorMessage = null;
      } else {
        _errorMessage = result['error'] as String? ?? 'Failed to fetch purchase orders';
        _log.error('PurchaseOrdersProvider', 'Failed to fetch: $_errorMessage');
      }
    } catch (e) {
      _errorMessage = 'Failed to load purchase orders';
      _log.error('PurchaseOrdersProvider', 'Exception: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _orders = [];
    _errorMessage = null;
    notifyListeners();
  }
}
