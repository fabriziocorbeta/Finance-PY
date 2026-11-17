import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/sale.dart';
import '../providers/sales_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/business_mode_gate.dart';
import 'sale_form_screen.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  Future<void> _load() async {
    final authProvider = context.read<AuthProvider>();
    final provider = context.read<SalesProvider>();

    final accessToken = await authProvider.getValidAccessToken();
    if (accessToken != null) {
      await provider.fetchSales(accessToken: accessToken);
    }
  }

  Color _statusColor(String status, ColorScheme colorScheme) {
    switch (status) {
      case 'completed':
        return Colors.green.shade700;
      case 'cancelled':
        return colorScheme.error;
      default:
        return colorScheme.onSurfaceVariant;
    }
  }

  Future<void> _createSale() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const SaleFormScreen()),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sale created.')));
    }
  }

  Future<void> _completeSale(Sale sale) async {
    final authProvider = context.read<AuthProvider>();
    final provider = context.read<SalesProvider>();
    final accessToken = await authProvider.getValidAccessToken();
    if (accessToken == null || !mounted) return;

    final result = await provider.completeSale(accessToken: accessToken, saleId: sale.id);
    if (!mounted) return;
    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error']?.toString() ?? 'Failed to complete sale')),
      );
    }
  }

  Future<void> _cancelSale(Sale sale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Sale'),
        content: const Text('This will cancel the sale. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel Sale')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final authProvider = context.read<AuthProvider>();
    final provider = context.read<SalesProvider>();
    final accessToken = await authProvider.getValidAccessToken();
    if (accessToken == null || !mounted) return;

    final result = await provider.cancelSale(accessToken: accessToken, saleId: sale.id);
    if (!mounted) return;
    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error']?.toString() ?? 'Failed to cancel sale')),
      );
    }
  }

  Future<void> _deleteSale(Sale sale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Sale'),
        content: const Text('Delete this draft sale? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final authProvider = context.read<AuthProvider>();
    final provider = context.read<SalesProvider>();
    final accessToken = await authProvider.getValidAccessToken();
    if (accessToken == null || !mounted) return;

    final result = await provider.deleteSale(accessToken: accessToken, saleId: sale.id);
    if (!mounted) return;
    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error']?.toString() ?? 'Failed to delete sale')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final provider = context.watch<SalesProvider>();
    final sales = provider.sales;

    return Scaffold(
      appBar: AppBar(title: const Text('Sales')),
      floatingActionButton: provider.errorMessage == BusinessModeGate.errorCode
          ? null
          : FloatingActionButton(onPressed: _createSale, child: const Icon(Icons.add)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: provider.isLoading && sales.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : provider.errorMessage == BusinessModeGate.errorCode
                ? const BusinessModeGate(featureName: 'Sales')
                : provider.errorMessage != null && sales.isEmpty
                    ? _buildErrorState(colorScheme, provider.errorMessage!)
                    : sales.isEmpty
                        ? _buildEmptyState(colorScheme)
                        : ListView.separated(
                            padding: const EdgeInsets.only(bottom: 80),
                            itemCount: sales.length,
                            separatorBuilder: (context, index) => Divider(height: 1, color: colorScheme.outlineVariant),
                            itemBuilder: (context, index) => _buildItem(colorScheme, sales[index]),
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
            Icon(Icons.point_of_sale_outlined, size: 64, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('No Sales Yet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Sales you record will show up here.',
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
            Text('Unable to load sales', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: TextStyle(color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(ColorScheme colorScheme, Sale sale) {
    final format = NumberFormat.currency(symbol: '${sale.currency} ', decimalDigits: 2);
    final statusColor = _statusColor(sale.status, colorScheme);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.point_of_sale_outlined, color: statusColor),
      ),
      title: Text(
        sale.clientName ?? sale.saleNumber ?? 'Sale',
        style: const TextStyle(fontWeight: FontWeight.w500),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${sale.saleItems.length} item${sale.saleItems.length == 1 ? '' : 's'} • ${sale.status}',
        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            format.format(sale.total),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (sale.status == 'draft')
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: colorScheme.onSurfaceVariant, size: 18),
              onSelected: (value) {
                if (value == 'complete') _completeSale(sale);
                if (value == 'cancel') _cancelSale(sale);
                if (value == 'delete') _deleteSale(sale);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'complete', child: Text('Mark completed')),
                PopupMenuItem(value: 'cancel', child: Text('Cancel')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
        ],
      ),
    );
  }
}
