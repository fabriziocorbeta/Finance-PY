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

  /// Current holdings grouped by account id: only the latest dated snapshot
  /// per security (mirrors Account#current_holdings on the web), excluding
  /// zeroed-out positions, sorted by value desc within each account.
  Map<String, List<Holding>> get holdingsByAccount {
    final latestBySecurity = <String, Holding>{};
    for (final holding in _holdings) {
      if (holding.qtyAsDouble == 0) continue;
      final key = '${holding.account.id}:${holding.security.id}';
      final current = latestBySecurity[key];
      if (current == null || holding.date.compareTo(current.date) > 0) {
        latestBySecurity[key] = holding;
      }
    }

    final grouped = <String, List<Holding>>{};
    for (final holding in latestBySecurity.values) {
      grouped.putIfAbsent(holding.account.id, () => []).add(holding);
    }
    for (final list in grouped.values) {
      list.sort((a, b) => b.amountAsDouble.compareTo(a.amountAsDouble));
    }
    return grouped;
  }

  /// The holdings endpoint returns every dated snapshot, not just current
  /// positions, so a family with a long history can span several pages.
  /// Caps at 20 pages (2000 rows) as a sane ceiling against a runaway loop.
  static const int _maxPages = 20;

  Future<void> fetchHoldings({required String accessToken}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final allHoldings = <Holding>[];
      var page = 1;
      var totalPages = 1;

      do {
        final result = await _holdingsService.getHoldings(
          accessToken: accessToken,
          page: page,
        );

        if (result['success'] != true) {
          _errorMessage = result['error'] as String? ?? 'Failed to fetch holdings';
          _log.error('HoldingsProvider', 'Failed to fetch holdings: $_errorMessage');
          break;
        }

        allHoldings.addAll(result['holdings'] as List<Holding>);
        final pagination = result['pagination'] as Map<String, dynamic>?;
        totalPages = (pagination?['total_pages'] as num?)?.toInt() ?? 1;
        page++;
      } while (_errorMessage == null && page <= totalPages && page <= _maxPages);

      // Keep whatever pages loaded successfully even if a later page failed,
      // but leave the error message in place so the UI can still surface it.
      if (allHoldings.isNotEmpty) {
        _holdings = allHoldings;
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
