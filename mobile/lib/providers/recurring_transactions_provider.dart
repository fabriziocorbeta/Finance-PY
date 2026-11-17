import 'package:flutter/foundation.dart';
import '../models/recurring_transaction.dart';
import '../services/recurring_transactions_service.dart';
import '../services/log_service.dart';

class RecurringTransactionsProvider with ChangeNotifier {
  final RecurringTransactionsService _service = RecurringTransactionsService();
  final LogService _log = LogService.instance;

  List<RecurringTransaction> _items = [];
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<RecurringTransaction> get items => List.unmodifiable(_items);

  Future<void> fetchRecurringTransactions({required String accessToken}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _service.getRecurringTransactions(accessToken: accessToken);

      if (result['success'] == true) {
        _items = result['recurring_transactions'] as List<RecurringTransaction>;
        _errorMessage = null;
      } else {
        _errorMessage = result['error'] as String? ?? 'Failed to fetch recurring transactions';
        _log.error('RecurringTransactionsProvider', 'Failed to fetch: $_errorMessage');
      }
    } catch (e) {
      _errorMessage = 'Failed to load recurring transactions';
      _log.error('RecurringTransactionsProvider', 'Exception: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _items = [];
    _errorMessage = null;
    notifyListeners();
  }
}
