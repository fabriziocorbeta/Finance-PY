import 'package:flutter/foundation.dart';
import '../models/account_detail.dart';
import '../services/accounts_service.dart';
import '../services/log_service.dart';

class AccountDetailProvider with ChangeNotifier {
  final AccountsService _accountsService = AccountsService();
  final LogService _log = LogService.instance;

  AccountDetail? _account;
  bool _isLoading = false;
  String? _errorMessage;

  AccountDetail? get account => _account;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchAccount({required String accessToken, required String accountId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _accountsService.getAccount(accessToken: accessToken, accountId: accountId);

      if (result['success'] == true) {
        _account = result['account'] as AccountDetail;
        _errorMessage = null;
      } else {
        _errorMessage = result['error'] as String? ?? 'Failed to fetch account';
        _log.error('AccountDetailProvider', 'Failed to fetch account: $_errorMessage');
      }
    } catch (e) {
      _errorMessage = 'Failed to load account';
      _log.error('AccountDetailProvider', 'Exception: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _account = null;
    _errorMessage = null;
    notifyListeners();
  }
}
