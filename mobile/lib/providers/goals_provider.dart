import 'package:flutter/foundation.dart';
import '../models/goal.dart';
import '../services/goals_service.dart';
import '../services/log_service.dart';

class GoalsProvider with ChangeNotifier {
  final GoalsService _goalsService = GoalsService();
  final LogService _log = LogService.instance;

  List<Goal> _goals = [];
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Active (non-archived) goals, most recently created first (API order).
  List<Goal> get goals => List.unmodifiable(_goals.where((g) => !g.isArchived));

  Future<void> fetchGoals({required String accessToken}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _goalsService.getGoals(accessToken: accessToken);

      if (result['success'] == true) {
        _goals = result['goals'] as List<Goal>;
        _errorMessage = null;
      } else {
        _errorMessage = result['error'] as String? ?? 'Failed to fetch goals';
        _log.error('GoalsProvider', 'Failed to fetch goals: $_errorMessage');
      }
    } catch (e) {
      _errorMessage = 'Failed to load goals';
      _log.error('GoalsProvider', 'Exception fetching goals: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _goals = [];
    _errorMessage = null;
    notifyListeners();
  }
}
