import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/purchase_order.dart';
import '../providers/purchase_orders_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/business_mode_gate.dart';
import 'purchase_order_form_screen.dart';

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

  Future<void> _createOrder() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const PurchaseOrderFormScreen()),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Purchase order created.')));
    }
  }

  Future<void> _receiveOrder(PurchaseOrder order) async {
    final authProvider = context.read<AuthProvider>();
    final provider = context.read<PurchaseOrdersProvider>();
    final accessToken = await authProvider.getValidAccessToken();
    if (accessToken == null || !mounted) return;

    final result = await provider.receivePurchaseOrder(accessToken: accessToken, purchaseOrderId: order.id);
    if (!mounted) return;
    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error']?.toString() ?? 'Failed to mark as received')),
      );
    }
  }

  Future<void> _cancelOrder(PurchaseOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Purchase Order'),
        content: const Text('This will cancel the purchase order. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel Order')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final authProvider = context.read<AuthProvider>();
    final provider = context.read<PurchaseOrdersProvider>();
    final accessToken = await authProvider.getValidAccessToken();
    if (accessToken == null || !mounted) return;

    final result = await provider.cancelPurchaseOrder(accessToken: accessToken, purchaseOrderId: order.id);
    if (!mounted) return;
    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error']?.toString() ?? 'Failed to cancel order')),
      );
    }
  }

  Future<void> _deleteOrder(PurchaseOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Purchase Order'),
        content: const Text('Delete this draft purchase order? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final authProvider = context.read<AuthProvider>();
    final provider = context.read<PurchaseOrdersProvider>();
    final accessToken = await authProvider.getValidAccessToken();
    if (accessToken == null || !mounted) return;

    final result = await provider.deletePurchaseOrder(accessToken: accessToken, purchaseOrderId: order.id);
    if (!mounted) return;
    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error']?.toString() ?? 'Failed to delete order')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final provider = context.watch<PurchaseOrdersProvider>();
    final orders = provider.orders;

    return Scaffold(
      appBar: AppBar(title: const Text('Purchase Orders')),
      floatingActionButton: provider.errorMessage == BusinessModeGate.errorCode
          ? null
          : FloatingActionButton(onPressed: _createOrder, child: const Icon(Icons.add)),
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
                            padding: const EdgeInsets.only(bottom: 80),
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            format.format(order.total),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (order.status == 'draft')
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: colorScheme.onSurfaceVariant, size: 18),
              onSelected: (value) {
                if (value == 'receive') _receiveOrder(order);
                if (value == 'cancel') _cancelOrder(order);
                if (value == 'delete') _deleteOrder(order);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'receive', child: Text('Mark received')),
                PopupMenuItem(value: 'cancel', child: Text('Cancel')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
        ],
      ),
    );
  }
}
