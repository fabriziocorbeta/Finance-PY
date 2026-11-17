import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/purchase_order.dart';
import '../providers/purchase_orders_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/business_mode_gate.dart';

class PurchaseOrdersScreen extends StatefulWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  State<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends State<PurchaseOrdersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  Future<void> _load() async {
    final authProvider = context.read<AuthProvider>();
    final provider = context.read<PurchaseOrdersProvider>();

    final accessToken = await authProvider.getValidAccessToken();
    if (accessToken != null) {
      await provider.fetchPurchaseOrders(accessToken: accessToken);
    }
  }

  Color _statusColor(String status, ColorScheme colorScheme) {
    switch (status) {
      case 'received':
        return Colors.green.shade700;
      case 'cancelled':
        return colorScheme.error;
      default:
        return colorScheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final provider = context.watch<PurchaseOrdersProvider>();
    final orders = provider.orders;

    return Scaffold(
      appBar: AppBar(title: const Text('Purchase Orders')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: provider.isLoading && orders.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : provider.errorMessage == BusinessModeGate.errorCode
                ? const BusinessModeGate(featureName: 'Purchase Orders')
                : provider.errorMessage != null && orders.isEmpty
                    ? _buildErrorState(colorScheme, provider.errorMessage!)
                    : orders.isEmpty
                        ? _buildEmptyState(colorScheme)
                        : ListView.separated(
                            itemCount: orders.length,
                            separatorBuilder: (context, index) => Divider(height: 1, color: colorScheme.outlineVariant),
                            itemBuilder: (context, index) => _buildItem(colorScheme, orders[index]),
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
            Icon(Icons.local_shipping_outlined, size: 64, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('No Purchase Orders Yet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Orders placed with suppliers will show up here.',
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
            Text('Unable to load purchase orders', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: TextStyle(color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(ColorScheme colorScheme, PurchaseOrder order) {
    final format = NumberFormat.currency(symbol: '${order.currency} ', decimalDigits: 2);
    final statusColor = _statusColor(order.status, colorScheme);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.local_shipping_outlined, color: statusColor),
      ),
      title: Text(
        order.supplierName ?? order.orderNumber ?? 'Purchase Order',
        style: const TextStyle(fontWeight: FontWeight.w500),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${order.items.length} item${order.items.length == 1 ? '' : 's'} • ${order.status}',
        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
      ),
      trailing: Text(
        format.format(order.total),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}
