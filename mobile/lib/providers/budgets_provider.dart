import 'package:flutter/foundation.dart';
import '../models/budget.dart';
import '../services/budgets_service.dart';
import '../services/log_service.dart';

class BudgetsProvider with ChangeNotifier {
  final BudgetsService _budgetsService = BudgetsService();
  final LogService _log = LogService.instance;

  List<Budget> _budgets = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Budget> get budgets => List.unmodifiable(_budgets);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// The budget flagged as the active period by the server, falling back to
  /// the most recent one (budgets are ordered start_date desc by the API).
  Budget? get currentBudget {
    if (_budgets.isEmpty) return null;
    try {
      return _budgets.firstWhere((b) => b.current);
    } catch (_) {
      return _budgets.first;
    }
  }

  Future<void> fetchBudgets({required String accessToken}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _budgetsService.getBudgets(accessToken: accessToken);

      if (result['success'] == true) {
        _budgets = result['budgets'] as List<Budget>;
        _errorMessage = null;
      } else {
        _errorMessage = result['error'] as String? ?? 'Failed to fetch budgets';
        _log.error('BudgetsProvider', 'Failed to fetch budgets: $_errorMessage');
      }
    } catch (e) {
      _errorMessage = 'Failed to load budgets';
      _log.error('BudgetsProvider', 'Exception fetching budgets: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _budgets = [];
    _errorMessage = null;
    notifyListeners();
  }
}
