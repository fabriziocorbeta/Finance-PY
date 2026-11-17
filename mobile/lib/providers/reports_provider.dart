import 'package:flutter/foundation.dart';
import '../models/report_summary.dart';
import '../services/reports_service.dart';
import '../services/log_service.dart';

class ReportsProvider with ChangeNotifier {
  final ReportsService _service = ReportsService();
  final LogService _log = LogService.instance;

  ReportSummary? _summary;
  String _periodType = 'monthly';
  bool _isLoading = false;
  String? _errorMessage;

  ReportSummary? get summary => _summary;
  String get periodType => _periodType;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchSummary({required String accessToken, String? periodType}) async {
    if (periodType != null) _periodType = periodType;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _service.getSummary(accessToken: accessToken, periodType: _periodType);

      if (result['success'] == true) {
        _summary = result['summary'] as ReportSummary;
        _errorMessage = null;
      } else {
        _errorMessage = result['error'] as String? ?? 'Failed to fetch report';
        _log.error('ReportsProvider', 'Failed to fetch: $_errorMessage');
      }
    } catch (e) {
      _errorMessage = 'Failed to load report';
      _log.error('ReportsProvider', 'Exception: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _summary = null;
    _errorMessage = null;
    notifyListeners();
  }
}
