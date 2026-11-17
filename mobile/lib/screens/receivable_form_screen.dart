import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/receivables_provider.dart';
import '../providers/auth_provider.dart';

class ReceivableFormScreen extends StatefulWidget {
  const ReceivableFormScreen({super.key});

  @override
  State<ReceivableFormScreen> createState() => _ReceivableFormScreenState();
}

class _ReceivableFormScreenState extends State<ReceivableFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _totalAmountController = TextEditingController();
  final _currencyController = TextEditingController(text: 'USD');
  final _installmentCountController = TextEditingController();
  final _dueDayController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _firstDueDate;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _totalAmountController.dispose();
    _currencyController.dispose();
    _installmentCountController.dispose();
    _dueDayController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _firstDueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) setState(() => _firstDueDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final authProvider = context.read<AuthProvider>();
    final provider = context.read<ReceivablesProvider>();
    final accessToken = await authProvider.getValidAccessToken();

    if (accessToken == null || !mounted) {
      setState(() => _isSaving = false);
      return;
    }

    final result = await provider.createReceivable(
      accessToken: accessToken,
      name: _nameController.text.trim(),
      totalAmount: double.tryParse(_totalAmountController.text) ?? 0.0,
      currency: _currencyController.text.trim().isEmpty ? null : _currencyController.text.trim(),
      installmentCount: int.tryParse(_installmentCountController.text),
      dueDay: int.tryParse(_dueDayController.text),
      firstDueDate: _firstDueDate?.toIso8601String().split('T').first,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result['success'] == true) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error']?.toString() ?? 'Failed to create receivable')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Receivable')),
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
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _totalAmountController,
                    decoration: const InputDecoration(labelText: 'Total amount *'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      final parsed = double.tryParse(v ?? '');
                      return (parsed == null || parsed <= 0) ? 'Enter a positive amount' : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _currencyController,
                    decoration: const InputDecoration(labelText: 'Currency'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _installmentCountController,
                    decoration: const InputDecoration(labelText: 'Installments'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _dueDayController,
                    decoration: const InputDecoration(labelText: 'Due day of month'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_firstDueDate == null
                  ? 'No first due date'
                  : _firstDueDate!.toIso8601String().split('T').first),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickDate,
            ),
            const SizedBox(height: 12),
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
                  : const Text('Create Receivable'),
            ),
          ],
        ),
      ),
    );
  }
}
