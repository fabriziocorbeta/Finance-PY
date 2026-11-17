import 'package:flutter/foundation.dart';
import '../models/rule.dart';
import '../services/rules_service.dart';
import '../services/log_service.dart';

class RulesProvider with ChangeNotifier {
  final RulesService _service = RulesService();
  final LogService _log = LogService.instance;

  List<Rule> _rules = [];
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Rule> get rules => List.unmodifiable(_rules);

  Future<void> fetchRules({required String accessToken}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _service.getRules(accessToken: accessToken);

      if (result['success'] == true) {
        _rules = result['rules'] as List<Rule>;
        _errorMessage = null;
      } else {
        _errorMessage = result['error'] as String? ?? 'Failed to fetch rules';
        _log.error('RulesProvider', 'Failed to fetch rules: $_errorMessage');
      }
    } catch (e) {
      _errorMessage = 'Failed to load rules';
      _log.error('RulesProvider', 'Exception: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _rules = [];
    _errorMessage = null;
    notifyListeners();
  }
}
