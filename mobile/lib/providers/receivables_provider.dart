import 'package:flutter/foundation.dart';
import '../models/receivable.dart';
import '../services/receivables_service.dart';
import '../services/log_service.dart';

class ReceivablesProvider with ChangeNotifier {
  final ReceivablesService _service = ReceivablesService();
  final LogService _log = LogService.instance;

  List<Receivable> _items = [];
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Outstanding receivables (balance > 0), by convention the ones worth
  /// surfacing on a "who owes me money" screen; fully paid ones are hidden.
  List<Receivable> get outstanding => List.unmodifiable(_items.where((r) => !r.isPaidOff));

  double get totalOutstanding => outstanding.fold(0.0, (sum, r) => sum + r.balance);

  Future<void> fetchReceivables({required String accessToken}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _service.getReceivables(accessToken: accessToken);

      if (result['success'] == true) {
        _items = result['receivables'] as List<Receivable>;
        _errorMessage = null;
      } else {
        _errorMessage = result['error'] as String? ?? 'Failed to fetch receivables';
        _log.error('ReceivablesProvider', 'Failed to fetch: $_errorMessage');
      }
    } catch (e) {
      _errorMessage = 'Failed to load receivables';
      _log.error('ReceivablesProvider', 'Exception: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
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
    final result = await _service.createReceivable(
      accessToken: accessToken,
      name: name,
      totalAmount: totalAmount,
      currency: currency,
      installmentCount: installmentCount,
      dueDay: dueDay,
      firstDueDate: firstDueDate,
      notes: notes,
    );
    if (result['success'] == true) {
      _items = [..._items, result['receivable'] as Receivable];
      notifyListeners();
    }
    return result;
  }

  Future<Map<String, dynamic>> deleteReceivable({required String accessToken, required String receivableId}) async {
    final result = await _service.deleteReceivable(accessToken: accessToken, receivableId: receivableId);
    if (result['success'] == true) {
      _items = _items.where((r) => r.id != receivableId).toList();
      notifyListeners();
    }
    return result;
  }

  void clear() {
    _items = [];
    _errorMessage = null;
    notifyListeners();
  }
}
