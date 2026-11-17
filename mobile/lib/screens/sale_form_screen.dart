import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../models/account.dart';
import '../providers/sales_provider.dart';
import '../providers/products_provider.dart';
import '../providers/accounts_provider.dart';
import '../providers/auth_provider.dart';

class _SaleItemDraft {
  Product product;
  final TextEditingController quantityController;
  final TextEditingController unitPriceController;

  _SaleItemDraft(this.product)
      : quantityController = TextEditingController(text: '1'),
        unitPriceController = TextEditingController(text: product.sellPrice.toString());

  void dispose() {
    quantityController.dispose();
    unitPriceController.dispose();
  }
}

class SaleFormScreen extends StatefulWidget {
  const SaleFormScreen({super.key});

  @override
  State<SaleFormScreen> createState() => _SaleFormScreenState();
}

class _SaleFormScreenState extends State<SaleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clientNameController = TextEditingController();
  final _notesController = TextEditingController();
  final List<_SaleItemDraft> _items = [];
  Account? _selectedAccount;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final productsProvider = context.read<ProductsProvider>();
      if (productsProvider.products.isEmpty) {
        final authProvider = context.read<AuthProvider>();
        final accessToken = await authProvider.getValidAccessToken();
        if (accessToken != null) {
          await productsProvider.fetchProducts(accessToken: accessToken);
        }
      }
    });
  }

  @override
  void dispose() {
    _clientNameController.dispose();
    _notesController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _pickAccount() async {
    final accounts = context.read<AccountsProvider>().accounts;
    final selected = await showModalBottomSheet<Account>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Deposit sale into which account?', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            ...accounts.map(
              (a) => ListTile(title: Text(a.name), onTap: () => Navigator.pop(context, a)),
            ),
          ],
        ),
      ),
    );
    if (selected != null) setState(() => _selectedAccount = selected);
  }

  Future<void> _addItem() async {
    final products = context.read<ProductsProvider>().products;
    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No products to add. Create one first.')),
      );
      return;
    }

    final selected = await showModalBottomSheet<Product>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Add product', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            ...products.map(
              (p) => ListTile(
                title: Text(p.name),
                subtitle: Text('${p.currency} ${p.sellPrice} • stock ${p.stock}'),
                onTap: () => Navigator.pop(context, p),
              ),
            ),
          ],
        ),
      ),
    );

    if (selected != null) {
      setState(() => _items.add(_SaleItemDraft(selected)));
    }
  }

  double get _total {
    return _items.fold(0.0, (sum, item) {
      final qty = double.tryParse(item.quantityController.text) ?? 0;
      final price = double.tryParse(item.unitPriceController.text) ?? 0;
      return sum + (qty * price);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick an account.')));
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one item.')));
      return;
    }

    setState(() => _isSaving = true);

    final authProvider = context.read<AuthProvider>();
    final provider = context.read<SalesProvider>();
    final accessToken = await authProvider.getValidAccessToken();

    if (accessToken == null || !mounted) {
      setState(() => _isSaving = false);
      return;
    }

    final items = _items
        .map((item) => {
              'product_id': item.product.id,
              'quantity': double.tryParse(item.quantityController.text) ?? 1,
              'unit_price': double.tryParse(item.unitPriceController.text) ?? 0,
            })
        .toList();

    final result = await provider.createSale(
      accessToken: accessToken,
      accountId: _selectedAccount!.id,
      clientName: _clientNameController.text.trim().isEmpty ? null : _clientNameController.text.trim(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      items: items,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result['success'] == true) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error']?.toString() ?? 'Failed to create sale')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('New Sale')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(controller: _clientNameController, decoration: const InputDecoration(labelText: 'Client name')),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_selectedAccount?.name ?? 'Pick an account *'),
              subtitle: _selectedAccount == null ? Text('Required', style: TextStyle(color: colorScheme.error)) : null,
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickAccount,
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Items', style: Theme.of(context).textTheme.titleMedium),
                TextButton.icon(onPressed: _addItem, icon: const Icon(Icons.add), label: const Text('Add')),
              ],
            ),
            if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('No items yet.', style: TextStyle(color: colorScheme.onSurfaceVariant)),
              ),
            ..._items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(item.product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: item.quantityController,
                        decoration: const InputDecoration(labelText: 'Qty'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: item.unitPriceController,
                        decoration: const InputDecoration(labelText: 'Price'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => setState(() {
                        item.dispose();
                        _items.removeAt(index);
                      }),
                    ),
                  ],
                ),
              );
            }),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(_total.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Create Sale'),
            ),
          ],
        ),
      ),
    );
  }
}
