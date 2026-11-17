import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/products_provider.dart';
import '../providers/auth_provider.dart';

class ProductFormScreen extends StatefulWidget {
  final Product? product;

  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _skuController;
  late final TextEditingController _categoryController;
  late final TextEditingController _supplierController;
  late final TextEditingController _buyPriceController;
  late final TextEditingController _sellPriceController;
  late final TextEditingController _currencyController;
  late final TextEditingController _minStockController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _initialStockController;
  bool _isSaving = false;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _nameController = TextEditingController(text: product?.name ?? '');
    _skuController = TextEditingController(text: product?.sku ?? '');
    _categoryController = TextEditingController(text: product?.category ?? '');
    _supplierController = TextEditingController(text: product?.supplier ?? '');
    _buyPriceController = TextEditingController(text: product != null ? product.buyPrice.toString() : '');
    _sellPriceController = TextEditingController(text: product != null ? product.sellPrice.toString() : '');
    _currencyController = TextEditingController(text: product?.currency ?? 'USD');
    _minStockController = TextEditingController(text: product?.minStock?.toString() ?? '');
    _descriptionController = TextEditingController(text: product?.description ?? '');
    _initialStockController = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _categoryController.dispose();
    _supplierController.dispose();
    _buyPriceController.dispose();
    _sellPriceController.dispose();
    _currencyController.dispose();
    _minStockController.dispose();
    _descriptionController.dispose();
    _initialStockController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final authProvider = context.read<AuthProvider>();
    final provider = context.read<ProductsProvider>();
    final accessToken = await authProvider.getValidAccessToken();

    if (accessToken == null || !mounted) {
      setState(() => _isSaving = false);
      return;
    }

    final buyPrice = double.tryParse(_buyPriceController.text) ?? 0.0;
    final sellPrice = double.tryParse(_sellPriceController.text) ?? 0.0;
    final minStock = int.tryParse(_minStockController.text);

    final result = _isEditing
        ? await provider.updateProduct(
            accessToken: accessToken,
            productId: widget.product!.id,
            name: _nameController.text.trim(),
            sku: _skuController.text.trim().isEmpty ? null : _skuController.text.trim(),
            category: _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim(),
            supplier: _supplierController.text.trim().isEmpty ? null : _supplierController.text.trim(),
            buyPrice: buyPrice,
            sellPrice: sellPrice,
            currency: _currencyController.text.trim().isEmpty ? 'USD' : _currencyController.text.trim(),
            minStock: minStock,
            description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          )
        : await provider.createProduct(
            accessToken: accessToken,
            name: _nameController.text.trim(),
            sku: _skuController.text.trim().isEmpty ? null : _skuController.text.trim(),
            category: _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim(),
            supplier: _supplierController.text.trim().isEmpty ? null : _supplierController.text.trim(),
            buyPrice: buyPrice,
            sellPrice: sellPrice,
            currency: _currencyController.text.trim().isEmpty ? 'USD' : _currencyController.text.trim(),
            minStock: minStock,
            description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
            initialStock: int.tryParse(_initialStockController.text) ?? 0,
          );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result['success'] == true) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error']?.toString() ?? 'Failed to save product')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Product' : 'New Product')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name *'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _skuController, decoration: const InputDecoration(labelText: 'SKU')),
            const SizedBox(height: 12),
            TextFormField(controller: _categoryController, decoration: const InputDecoration(labelText: 'Category')),
            const SizedBox(height: 12),
            TextFormField(controller: _supplierController, decoration: const InputDecoration(labelText: 'Supplier')),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _buyPriceController,
                    decoration: const InputDecoration(labelText: 'Buy price *'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => double.tryParse(v ?? '') == null ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _sellPriceController,
                    decoration: const InputDecoration(labelText: 'Sell price *'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => double.tryParse(v ?? '') == null ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _currencyController,
                    decoration: const InputDecoration(labelText: 'Currency'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _minStockController,
                    decoration: const InputDecoration(labelText: 'Min stock'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            if (!_isEditing) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _initialStockController,
                decoration: const InputDecoration(labelText: 'Initial stock'),
                keyboardType: TextInputType.number,
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_isEditing ? 'Save Changes' : 'Create Product'),
            ),
          ],
        ),
      ),
    );
  }
}
