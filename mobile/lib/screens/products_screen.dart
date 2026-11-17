import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../providers/products_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/business_mode_gate.dart';
import 'product_form_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  Future<void> _load() async {
    final authProvider = context.read<AuthProvider>();
    final provider = context.read<ProductsProvider>();

    final accessToken = await authProvider.getValidAccessToken();
    if (accessToken != null) {
      await provider.fetchProducts(accessToken: accessToken);
    }
  }

  Future<void> _openForm({Product? product}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => ProductFormScreen(product: product)),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(product == null ? 'Product created.' : 'Product updated.')),
      );
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Delete "${product.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final authProvider = context.read<AuthProvider>();
    final provider = context.read<ProductsProvider>();
    final accessToken = await authProvider.getValidAccessToken();
    if (accessToken == null || !mounted) return;

    final result = await provider.deleteProduct(accessToken: accessToken, productId: product.id);
    if (!mounted) return;
    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error']?.toString() ?? 'Failed to delete product')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final provider = context.watch<ProductsProvider>();
    final products = provider.products;

    return Scaffold(
      appBar: AppBar(title: const Text('Products')),
      floatingActionButton: provider.errorMessage == BusinessModeGate.errorCode
          ? null
          : FloatingActionButton(onPressed: () => _openForm(), child: const Icon(Icons.add)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: provider.isLoading && products.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : provider.errorMessage == BusinessModeGate.errorCode
                ? const BusinessModeGate(featureName: 'Products')
                : provider.errorMessage != null && products.isEmpty
                    ? _buildErrorState(colorScheme, provider.errorMessage!)
                    : products.isEmpty
                        ? _buildEmptyState(colorScheme)
                        : ListView.separated(
                            padding: const EdgeInsets.only(bottom: 80),
                            itemCount: products.length,
                            separatorBuilder: (context, index) => Divider(height: 1, color: colorScheme.outlineVariant),
                            itemBuilder: (context, index) => _buildItem(colorScheme, products[index]),
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
            Icon(Icons.inventory_2_outlined, size: 64, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('No Products Yet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Products from your catalog will show up here.',
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
            Text('Unable to load products', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: TextStyle(color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(ColorScheme colorScheme, Product product) {
    final format = NumberFormat.currency(symbol: '${product.currency} ', decimalDigits: 2);

    return Dismissible(
      key: Key('product_${product.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await _deleteProduct(product);
        return false;
      },
      background: Container(
        color: colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
      ),
      child: ListTile(
        onTap: () => _openForm(product: product),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: product.isLowStock ? colorScheme.errorContainer : colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.inventory_2_outlined,
            color: product.isLowStock ? colorScheme.onErrorContainer : colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [
            if (product.sku != null && product.sku!.isNotEmpty) 'SKU: ${product.sku}',
            'Stock: ${product.stock}',
          ].join(' • '),
          style: TextStyle(fontSize: 12, color: product.isLowStock ? colorScheme.error : colorScheme.onSurfaceVariant),
        ),
        trailing: Text(
          format.format(product.sellPrice),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
