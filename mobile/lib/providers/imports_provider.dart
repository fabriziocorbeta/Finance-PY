import 'package:flutter/foundation.dart';
import '../models/csv_import.dart';
import '../services/imports_service.dart';
import '../services/log_service.dart';

class ImportsProvider with ChangeNotifier {
  final ImportsService _service = ImportsService();
  final LogService _log = LogService.instance;

  List<CsvImport> _imports = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  List<CsvImport> get imports => List.unmodifiable(_imports);

  Future<void> fetchImports({required String accessToken}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _service.getImports(accessToken: accessToken);

      if (result['success'] == true) {
        _imports = result['imports'] as List<CsvImport>;
        _errorMessage = null;
      } else {
        _errorMessage = result['error'] as String? ?? 'Failed to fetch imports';
        _log.error('ImportsProvider', 'Failed to fetch: $_errorMessage');
      }
    } catch (e) {
      _errorMessage = 'Failed to load imports';
      _log.error('ImportsProvider', 'Exception: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Creates the import, then refreshes the list so the new row (with
  /// whatever its real server-computed status turned out to be) replaces
  /// this method's own best-effort return value.
  Future<Map<String, dynamic>> createImport({
    required String accessToken,
    required String accountId,
    required String csvContent,
  }) async {
    _isSubmitting = true;
    notifyListeners();

    try {
      final result = await _service.createImport(
        accessToken: accessToken,
        accountId: accountId,
        csvContent: csvContent,
      );

      if (result['success'] == true) {
        await fetchImports(accessToken: accessToken);
      }

      return result;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> publishImport({
    required String accessToken,
    required String importId,
  }) async {
    final result = await _service.publishImport(accessToken: accessToken, importId: importId);
    if (result['success'] == true) {
      await fetchImports(accessToken: accessToken);
    }
    return result;
  }

  void clear() {
    _imports = [];
    _errorMessage = null;
    notifyListeners();
  }
}
