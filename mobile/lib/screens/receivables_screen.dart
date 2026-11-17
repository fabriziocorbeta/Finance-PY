import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/receivable.dart';
import '../providers/receivables_provider.dart';
import '../providers/auth_provider.dart';
import 'receivable_form_screen.dart';

class ReceivablesScreen extends StatefulWidget {
  const ReceivablesScreen({super.key});

  @override
  State<ReceivablesScreen> createState() => _ReceivablesScreenState();
}

class _ReceivablesScreenState extends State<ReceivablesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  Future<void> _load() async {
    final authProvider = context.read<AuthProvider>();
    final provider = context.read<ReceivablesProvider>();

    final accessToken = await authProvider.getValidAccessToken();
    if (accessToken != null) {
      await provider.fetchReceivables(accessToken: accessToken);
    }
  }

  Future<void> _createReceivable() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const ReceivableFormScreen()),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Receivable created.')));
    }
  }

  Future<void> _deleteReceivable(Receivable r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Receivable'),
        content: Text('Delete "${r.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final authProvider = context.read<AuthProvider>();
    final provider = context.read<ReceivablesProvider>();
    final accessToken = await authProvider.getValidAccessToken();
    if (accessToken == null || !mounted) return;

    final result = await provider.deleteReceivable(accessToken: accessToken, receivableId: r.id);
    if (!mounted) return;
    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error']?.toString() ?? 'Failed to delete receivable')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final provider = context.watch<ReceivablesProvider>();
    final items = provider.outstanding;

    return Scaffold(
      appBar: AppBar(title: const Text('Receivables')),
      floatingActionButton: FloatingActionButton(onPressed: _createReceivable, child: const Icon(Icons.add)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: provider.isLoading && items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : provider.errorMessage != null && items.isEmpty
                ? _buildErrorState(colorScheme, provider.errorMessage!)
                : items.isEmpty
                    ? _buildEmptyState(colorScheme)
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                        children: [
                          _buildTotalCard(colorScheme, provider),
                          const SizedBox(height: 16),
                          ...items.map((r) => _buildReceivableCard(colorScheme, r)),
                        ],
                      ),
      ),
    );
  }

  Widget _buildTotalCard(ColorScheme colorScheme, ReceivablesProvider provider) {
    final currency = provider.outstanding.isNotEmpty ? provider.outstanding.first.currency : 'USD';
    final format = NumberFormat.currency(symbol: '$currency ', decimalDigits: 2);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total outstanding', style: TextStyle(color: colorScheme.onPrimaryContainer, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            format.format(provider.totalOutstanding),
            style: TextStyle(
              color: colorScheme.onPrimaryContainer,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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
            Icon(Icons.request_quote_outlined, size: 64, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('No Outstanding Receivables', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Amounts owed to you will show up here.',
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
            Text('Unable to load receivables', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: TextStyle(color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildReceivableCard(ColorScheme colorScheme, Receivable r) {
    final format = NumberFormat.currency(symbol: '${r.currency} ', decimalDigits: 2);
    final progress = r.originalBalance > 0 ? (r.percentPaid.clamp(0, 100) / 100).toDouble() : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  r.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, size: 20, color: colorScheme.onSurfaceVariant),
                onPressed: () => _deleteReceivable(r),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${format.format(r.balance)} remaining',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'of ${format.format(r.totalAmount)}',
                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: colorScheme.surfaceDim,
              color: colorScheme.primary,
            ),
          ),
          if (r.installmentCount != null) ...[
            const SizedBox(height: 8),
            Text(
              '${r.installmentCount} installments${r.dueDay != null ? ' · due day ${r.dueDay}' : ''}',
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
