import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/account_detail.dart';
import '../providers/account_detail_provider.dart';
import '../providers/auth_provider.dart';

class AccountDetailScreen extends StatefulWidget {
  final String accountId;
  final String accountName;

  const AccountDetailScreen({super.key, required this.accountId, required this.accountName});

  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  Future<void> _load() async {
    final authProvider = context.read<AuthProvider>();
    final provider = context.read<AccountDetailProvider>();

    final accessToken = await authProvider.getValidAccessToken();
    if (accessToken != null) {
      await provider.fetchAccount(accessToken: accessToken, accountId: widget.accountId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final provider = context.watch<AccountDetailProvider>();
    final account = provider.account;

    return Scaffold(
      appBar: AppBar(title: Text(widget.accountName)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: provider.isLoading && account == null
            ? const Center(child: CircularProgressIndicator())
            : provider.errorMessage != null && account == null
                ? _buildErrorState(colorScheme, provider.errorMessage!)
                : account == null
                    ? const SizedBox.shrink()
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildSummaryCard(colorScheme, account),
                          const SizedBox(height: 16),
                          if (account.loanDetails != null) _buildLoanDetails(colorScheme, account.loanDetails!),
                          if (account.creditCardDetails != null)
                            _buildCreditCardDetails(colorScheme, account.creditCardDetails!, account.currency),
                          if (account.vehicleDetails != null) _buildVehicleDetails(colorScheme, account.vehicleDetails!),
                          if (account.cryptoDetails != null) _buildCryptoDetails(colorScheme, account.cryptoDetails!),
                        ],
                      ),
      ),
    );
  }

  Widget _buildErrorState(ColorScheme colorScheme, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 16),
            Text('Unable to load account', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: TextStyle(color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(ColorScheme colorScheme, AccountDetail account) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Balance', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            account.balance,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _detailRow(colorScheme, 'Status', account.status),
          if (account.institutionName != null) _detailRow(colorScheme, 'Institution', account.institutionName!),
          if (account.subtype != null) _detailRow(colorScheme, 'Subtype', account.subtype!),
        ],
      ),
    );
  }

  Widget _buildLoanDetails(ColorScheme colorScheme, LoanDetails details) {
    return _buildDetailsCard(colorScheme, 'Loan Details', [
      if (details.rateType != null) _detailRow(colorScheme, 'Rate type', details.rateType!),
      if (details.interestRate != null) _detailRow(colorScheme, 'Interest rate', '${details.interestRate}%'),
      if (details.termMonths != null) _detailRow(colorScheme, 'Term', '${details.termMonths} months'),
      if (details.initialBalance != null)
        _detailRow(colorScheme, 'Initial balance', NumberFormat.currency(decimalDigits: 2).format(details.initialBalance)),
      if (details.amortizationMethod != null) _detailRow(colorScheme, 'Amortization', details.amortizationMethod!),
    ]);
  }

  Widget _buildCreditCardDetails(ColorScheme colorScheme, CreditCardDetails details, String currency) {
    final format = NumberFormat.currency(symbol: '$currency ', decimalDigits: 2);
    return _buildDetailsCard(colorScheme, 'Credit Card Details', [
      if (details.availableCredit != null) _detailRow(colorScheme, 'Available credit', format.format(details.availableCredit)),
      if (details.minimumPayment != null) _detailRow(colorScheme, 'Minimum payment', format.format(details.minimumPayment)),
      if (details.apr != null) _detailRow(colorScheme, 'APR', '${details.apr}%'),
      if (details.annualFee != null) _detailRow(colorScheme, 'Annual fee', format.format(details.annualFee)),
      if (details.expirationDate != null) _detailRow(colorScheme, 'Expires', details.expirationDate!),
    ]);
  }

  Widget _buildVehicleDetails(ColorScheme colorScheme, VehicleDetails details) {
    return _buildDetailsCard(colorScheme, 'Vehicle Details', [
      if (details.make != null) _detailRow(colorScheme, 'Make', details.make!),
      if (details.model != null) _detailRow(colorScheme, 'Model', details.model!),
      if (details.year != null) _detailRow(colorScheme, 'Year', details.year.toString()),
      if (details.mileageValue != null)
        _detailRow(colorScheme, 'Mileage', '${details.mileageValue} ${details.mileageUnit ?? ''}'.trim()),
    ]);
  }

  Widget _buildCryptoDetails(ColorScheme colorScheme, CryptoDetails details) {
    return _buildDetailsCard(colorScheme, 'Crypto Details', [
      if (details.taxTreatment != null) _detailRow(colorScheme, 'Tax treatment', details.taxTreatment!),
    ]);
  }

  Widget _buildDetailsCard(ColorScheme colorScheme, String title, List<Widget> rows) {
    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }

  Widget _detailRow(ColorScheme colorScheme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: colorScheme.onSurfaceVariant)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
