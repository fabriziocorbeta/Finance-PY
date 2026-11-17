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

  Future<Map<String, dynamic>> createPurchaseOrder({
    required String accessToken,
    required String accountId,
    String? supplierName,
    String? currency,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    final result = await _service.createPurchaseOrder(
      accessToken: accessToken,
      accountId: accountId,
      supplierName: supplierName,
      currency: currency,
      notes: notes,
      items: items,
    );
    if (result['success'] == true) {
      _orders = [result['purchase_order'] as PurchaseOrder, ..._orders];
      notifyListeners();
    }
    return result;
  }

  Future<Map<String, dynamic>> deletePurchaseOrder({required String accessToken, required String purchaseOrderId}) async {
    final result = await _service.deletePurchaseOrder(accessToken: accessToken, purchaseOrderId: purchaseOrderId);
    if (result['success'] == true) {
      _orders = _orders.where((o) => o.id != purchaseOrderId).toList();
      notifyListeners();
    }
    return result;
  }

  Future<Map<String, dynamic>> receivePurchaseOrder({required String accessToken, required String purchaseOrderId}) async {
    final result = await _service.receivePurchaseOrder(accessToken: accessToken, purchaseOrderId: purchaseOrderId);
    if (result['success'] == true) {
      final updated = result['purchase_order'] as PurchaseOrder;
      _orders = _orders.map((o) => o.id == purchaseOrderId ? updated : o).toList();
      notifyListeners();
    }
    return result;
  }

  Future<Map<String, dynamic>> cancelPurchaseOrder({required String accessToken, required String purchaseOrderId}) async {
    final result = await _service.cancelPurchaseOrder(accessToken: accessToken, purchaseOrderId: purchaseOrderId);
    if (result['success'] == true) {
      final updated = result['purchase_order'] as PurchaseOrder;
      _orders = _orders.map((o) => o.id == purchaseOrderId ? updated : o).toList();
      notifyListeners();
    }
    return result;
  }

  void clear() {
    _orders = [];
    _errorMessage = null;
    notifyListeners();
  }
}
