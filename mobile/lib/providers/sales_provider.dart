import 'package:flutter/foundation.dart';
import '../models/sale.dart';
import '../services/sales_service.dart';
import '../services/log_service.dart';

class SalesProvider with ChangeNotifier {
  final SalesService _service = SalesService();
  final LogService _log = LogService.instance;

  List<Sale> _sales = [];
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Sale> get sales => List.unmodifiable(_sales);

  Future<void> fetchSales({required String accessToken}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _service.getSales(accessToken: accessToken);

      if (result['success'] == true) {
        _sales = result['sales'] as List<Sale>;
        _errorMessage = null;
      } else {
        _errorMessage = result['error'] as String? ?? 'Failed to fetch sales';
        _log.error('SalesProvider', 'Failed to fetch: $_errorMessage');
      }
    } catch (e) {
      _errorMessage = 'Failed to load sales';
      _log.error('SalesProvider', 'Exception: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _sales = [];
    _errorMessage = null;
    notifyListeners();
  }
}
