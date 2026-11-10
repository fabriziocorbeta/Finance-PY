import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/account.dart';
import '../providers/auth_provider.dart';
import '../providers/accounts_provider.dart';
import '../services/connectivity_service.dart';
import '../services/transfers_service.dart';
import '../services/log_service.dart';
import '../widgets/exchange_rate_entry.dart';

class TransferFormScreen extends StatefulWidget {
  final Account? initialFromAccount;

  const TransferFormScreen({
    super.key,
    this.initialFromAccount,
  });

  @override
  State<TransferFormScreen> createState() => _TransferFormScreenState();
}

class _TransferFormScreenState extends State<TransferFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _dateController = TextEditingController();
  final _transfersService = TransfersService();
  final _log = LogService.instance;

  Account? _fromAccount;
  Account? _toAccount;
  String? _exchangeRate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fromAccount = widget.initialFromAccount;
    final now = DateTime.now();
    _dateController.text = DateFormat('yyyy/MM/dd').format(now);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  String? _validateAmount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter an amount';
    }
    final amount = double.tryParse(value.trim());
    if (amount == null) {
      return 'Please enter a valid number';
    }
    if (amount <= 0) {
      return 'Amount must be greater than 0';
    }
    return null;
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        _dateController.text = DateFormat('yyyy/MM/dd').format(picked);
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fromAccount == null || _toAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both accounts'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_fromAccount!.id == _toAccount!.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Source and destination accounts must be different'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final crossCurrency = _fromAccount!.currency != _toAccount!.currency;
    if (crossCurrency && (_exchangeRate == null || _exchangeRate!.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an exchange rate'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final connectivityService = Provider.of<ConnectivityService>(context, listen: false);
    if (!connectivityService.isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transfers require an internet connection'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final accessToken = await authProvider.getValidAccessToken();

      if (accessToken == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session expired. Please login again.'),
              backgroundColor: Colors.red,
            ),
          );
          await authProvider.logout();
        }
        return;
      }

      final parsedDate = DateFormat('yyyy/MM/dd').parse(_dateController.text);
      final apiDate = DateFormat('yyyy-MM-dd').format(parsedDate);

      final result = await _transfersService.createTransfer(
        accessToken: accessToken,
        fromAccountId: _fromAccount!.id,
        toAccountId: _toAccount!.id,
        amount: _amountController.text.trim(),
        date: apiDate,
        exchangeRate: crossCurrency ? _exchangeRate : null,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transfer created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error']?.toString() ?? 'Failed to create transfer'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      _log.error('TransferForm', 'Exception during transfer creation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = Provider.of<AccountsProvider>(context).accounts;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'New Transfer',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 16,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'From account',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<Account>(
                          value: _fromAccount != null
                              ? accounts.firstWhere(
                                  (a) => a.id == _fromAccount!.id,
                                  orElse: () => _fromAccount!,
                                )
                              : null,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.account_balance_wallet),
                          ),
                          isExpanded: true,
                          items: accounts.map((account) {
                            return DropdownMenuItem<Account>(
                              value: account,
                              child: Text('${account.name} (${account.currency})'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _fromAccount = value;
                              _exchangeRate = null;
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        Text(
                          'To account',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<Account>(
                          value: _toAccount,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                          ),
                          isExpanded: true,
                          items: accounts
                              .where((a) => _fromAccount == null || a.id != _fromAccount!.id)
                              .map((account) {
                            return DropdownMenuItem<Account>(
                              value: account,
                              child: Text('${account.name} (${account.currency})'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _toAccount = value;
                              _exchangeRate = null;
                            });
                          },
                        ),
                        const SizedBox(height: 24),

                        TextFormField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Amount *',
                            prefixIcon: const Icon(Icons.attach_money),
                            suffixText: _fromAccount?.currency,
                            helperText: 'Required',
                          ),
                          validator: _validateAmount,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _dateController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Date',
                            prefixIcon: Icon(Icons.calendar_today),
                            helperText: 'Optional (default: today)',
                          ),
                          onTap: _selectDate,
                        ),

                        if (_fromAccount != null &&
                            _toAccount != null &&
                            _fromAccount!.currency != _toAccount!.currency) ...[
                          const SizedBox(height: 16),
                          ExchangeRateEntry(
                            sourceAmount: _amountController.text.trim(),
                            fromCurrency: _fromAccount!.currency,
                            toCurrency: _toAccount!.currency,
                            date: DateFormat('yyyy-MM-dd').format(
                              DateFormat('yyyy/MM/dd').parse(_dateController.text),
                            ),
                            onRateChanged: (rate) {
                              _exchangeRate = rate;
                            },
                          ),
                        ],

                        const SizedBox(height: 32),

                        ElevatedButton(
                          onPressed: _isSubmitting ? null : _handleSubmit,
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Create Transfer'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
