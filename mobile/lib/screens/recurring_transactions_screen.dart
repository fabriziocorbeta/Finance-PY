import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recurring_transaction.dart';
import '../providers/recurring_transactions_provider.dart';
import '../providers/auth_provider.dart';

class RecurringTransactionsScreen extends StatefulWidget {
  const RecurringTransactionsScreen({super.key});

  @override
  State<RecurringTransactionsScreen> createState() => _RecurringTransactionsScreenState();
}

class _RecurringTransactionsScreenState extends State<RecurringTransactionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  Future<void> _load() async {
    final authProvider = context.read<AuthProvider>();
    final provider = context.read<RecurringTransactionsProvider>();

    final accessToken = await authProvider.getValidAccessToken();
    if (accessToken != null) {
      await provider.fetchRecurringTransactions(accessToken: accessToken);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final provider = context.watch<RecurringTransactionsProvider>();
    final items = provider.items;

    return Scaffold(
      appBar: AppBar(title: const Text('Recurring Transactions')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: provider.isLoading && items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : provider.errorMessage != null && items.isEmpty
                ? _buildErrorState(colorScheme, provider.errorMessage!)
                : items.isEmpty
                    ? _buildEmptyState(colorScheme)
                    : ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (context, index) => Divider(height: 1, color: colorScheme.outlineVariant),
                        itemBuilder: (context, index) => _buildItem(colorScheme, items[index]),
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
            Icon(Icons.repeat, size: 64, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('No Recurring Transactions', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Detected subscriptions and recurring bills will show up here.',
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
            Text('Unable to load recurring transactions', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: TextStyle(color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(ColorScheme colorScheme, RecurringTransaction item) {
    final subtitleParts = <String>[];
    if (item.account != null) subtitleParts.add(item.account!.name);
    if (item.nextExpectedDate != null) subtitleParts.add('Next: ${item.nextExpectedDate}');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: item.isActive
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.repeat,
          color: item.isActive ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(
        item.merchant?.name ?? item.name,
        style: const TextStyle(fontWeight: FontWeight.w500),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        subtitleParts.join(' • '),
        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${item.currency} ${item.amount}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (!item.isActive)
            Text(
              'Inactive',
              style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}
