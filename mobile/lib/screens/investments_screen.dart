import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/holding.dart';
import '../providers/holdings_provider.dart';
import '../providers/accounts_provider.dart';
import '../providers/auth_provider.dart';

class InvestmentsScreen extends StatefulWidget {
  const InvestmentsScreen({super.key});

  @override
  State<InvestmentsScreen> createState() => _InvestmentsScreenState();
}

class _InvestmentsScreenState extends State<InvestmentsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHoldings();
    });
  }

  Future<void> _loadHoldings() async {
    final authProvider = context.read<AuthProvider>();
    final holdingsProvider = context.read<HoldingsProvider>();

    final accessToken = await authProvider.getValidAccessToken();
    if (accessToken != null) {
      await holdingsProvider.fetchHoldings(accessToken: accessToken);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final holdingsProvider = context.watch<HoldingsProvider>();
    final accountsProvider = context.watch<AccountsProvider>();

    final investmentAccounts = accountsProvider.accounts
        .where((a) => a.accountType == 'investment' || a.accountType == 'crypto')
        .toList();

    final holdingsByAccount = holdingsProvider.holdingsByAccount;

    return Scaffold(
      appBar: AppBar(title: const Text('Investments')),
      body: RefreshIndicator(
        onRefresh: _loadHoldings,
        child: holdingsProvider.isLoading && holdingsProvider.holdings.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : holdingsProvider.errorMessage != null && holdingsProvider.holdings.isEmpty
                ? _buildErrorState(colorScheme, holdingsProvider.errorMessage!)
                : investmentAccounts.isEmpty
                    ? _buildEmptyState(colorScheme)
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: investmentAccounts.length,
                        itemBuilder: (context, index) {
                          final account = investmentAccounts[index];
                          final holdings = holdingsByAccount[account.id] ?? [];
                          return _buildAccountSection(
                            colorScheme,
                            account.name,
                            account.currency,
                            holdings,
                          );
                        },
                      ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.trending_up,
              size: 64,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No Investment Accounts',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Connect or add an investment account to see your holdings here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
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
            Text(
              'Unable to load investments',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadHoldings,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSection(
    ColorScheme colorScheme,
    String accountName,
    String accountCurrency,
    List<Holding> holdings,
  ) {
    final totalValue = holdings.fold<double>(0.0, (sum, h) => sum + h.amountAsDouble);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  accountName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              Text(
                '$accountCurrency ${totalValue.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
        if (holdings.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              'No holdings in this account yet.',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          )
        else
          ...holdings.map((holding) => _buildHoldingItem(colorScheme, holding)),
        Divider(height: 1, color: colorScheme.outlineVariant),
      ],
    );
  }

  Widget _buildHoldingItem(ColorScheme colorScheme, Holding holding) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Text(
          holding.security.ticker.isNotEmpty
              ? holding.security.ticker.substring(0, holding.security.ticker.length.clamp(0, 4))
              : '?',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
      ),
      title: Text(
        holding.security.name.isNotEmpty ? holding.security.name : holding.security.ticker,
        style: const TextStyle(fontWeight: FontWeight.w500),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${holding.qty} ${holding.security.ticker} @ ${holding.price}',
        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            holding.amount,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          if (holding.avgCost != null)
            Text(
              'avg ${holding.avgCost}',
              style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}
