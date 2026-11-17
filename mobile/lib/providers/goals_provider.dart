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

  Future<Map<String, dynamic>> createGoal({
    required String accessToken,
    required String name,
    required double targetAmount,
    String? currency,
    String? targetDate,
    required List<String> accountIds,
  }) async {
    final result = await _goalsService.createGoal(
      accessToken: accessToken,
      name: name,
      targetAmount: targetAmount,
      currency: currency,
      targetDate: targetDate,
      accountIds: accountIds,
    );
    if (result['success'] == true) {
      _goals = [..._goals, result['goal'] as Goal];
      notifyListeners();
    }
    return result;
  }

  Future<Map<String, dynamic>> updateGoal({
    required String accessToken,
    required String goalId,
    String? name,
    double? targetAmount,
    String? targetDate,
  }) async {
    final result = await _goalsService.updateGoal(
      accessToken: accessToken,
      goalId: goalId,
      name: name,
      targetAmount: targetAmount,
      targetDate: targetDate,
    );
    if (result['success'] == true) {
      final updated = result['goal'] as Goal;
      _goals = _goals.map((g) => g.id == goalId ? updated : g).toList();
      notifyListeners();
    }
    return result;
  }

  /// Archiving (not a hard delete) is the only remove path exposed here:
  /// the API refuses DELETE on a goal that isn't archived? yet, which would
  /// mean two confirmations for one action anyway -- archiving alone already
  /// drops it from `goals` since that getter filters isArchived out.
  Future<Map<String, dynamic>> archiveGoal({
    required String accessToken,
    required String goalId,
  }) async {
    final result = await _goalsService.updateGoal(accessToken: accessToken, goalId: goalId, state: 'archived');
    if (result['success'] == true) {
      final updated = result['goal'] as Goal;
      _goals = _goals.map((g) => g.id == goalId ? updated : g).toList();
      notifyListeners();
    }
    return result;
  }

  void clear() {
    _goals = [];
    _errorMessage = null;
    notifyListeners();
  }
}
