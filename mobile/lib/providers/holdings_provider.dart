import 'package:flutter/foundation.dart';
import '../models/holding.dart';
import '../services/holdings_service.dart';
import '../services/log_service.dart';

class HoldingsProvider with ChangeNotifier {
  final HoldingsService _holdingsService = HoldingsService();
  final LogService _log = LogService.instance;

  List<Holding> _holdings = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Holding> get holdings => List.unmodifiable(_holdings);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Holdings grouped by account id, each account's list sorted by value desc.
  Map<String, List<Holding>> get holdingsByAccount {
    final grouped = <String, List<Holding>>{};
    for (final holding in _holdings) {
      grouped.putIfAbsent(holding.account.id, () => []).add(holding);
    }
    for (final list in grouped.values) {
      list.sort((a, b) => b.amountAsDouble.compareTo(a.amountAsDouble));
    }
    return grouped;
  }

  double totalValueForAccount(String accountId) {
    return _holdings
        .where((h) => h.account.id == accountId)
        .fold(0.0, (sum, h) => sum + h.amountAsDouble);
  }

  Future<void> fetchHoldings({required String accessToken}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _holdingsService.getHoldings(accessToken: accessToken);

      if (result['success'] == true) {
        _holdings = result['holdings'] as List<Holding>;
        _errorMessage = null;
      } else {
        _errorMessage = result['error'] as String? ?? 'Failed to fetch holdings';
        _log.error('HoldingsProvider', 'Failed to fetch holdings: $_errorMessage');
      }
    } catch (e) {
      _errorMessage = 'Failed to load holdings';
      _log.error('HoldingsProvider', 'Exception fetching holdings: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _holdings = [];
    _errorMessage = null;
    notifyListeners();
  }
}
