import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/goal.dart';
import '../models/account.dart';
import '../providers/goals_provider.dart';
import '../providers/accounts_provider.dart';
import '../providers/auth_provider.dart';

class GoalFormScreen extends StatefulWidget {
  final Goal? goal;

  const GoalFormScreen({super.key, this.goal});

  @override
  State<GoalFormScreen> createState() => _GoalFormScreenState();
}

class _GoalFormScreenState extends State<GoalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _targetAmountController;
  DateTime? _targetDate;
  Account? _selectedAccount;
  bool _isSaving = false;

  bool get _isEditing => widget.goal != null;

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    _nameController = TextEditingController(text: goal?.name ?? '');
    _targetAmountController = TextEditingController(text: goal != null ? goal.targetAmount.toString() : '');
    if (goal?.targetDate != null) {
      _targetDate = DateTime.tryParse(goal!.targetDate!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetAmountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 20)),
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  Future<void> _pickAccount() async {
    final accountsProvider = context.read<AccountsProvider>();
    final accounts = accountsProvider.accounts;

    final selected = await showModalBottomSheet<Account>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Link which account?', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            ...accounts.map(
              (a) => ListTile(
                title: Text(a.name),
                subtitle: Text(a.displayAccountType),
                onTap: () => Navigator.pop(context, a),
              ),
            ),
          ],
        ),
      ),
    );

    if (selected != null) setState(() => _selectedAccount = selected);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isEditing && _selectedAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick an account to link this goal to.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final authProvider = context.read<AuthProvider>();
    final provider = context.read<GoalsProvider>();
    final accessToken = await authProvider.getValidAccessToken();

    if (accessToken == null || !mounted) {
      setState(() => _isSaving = false);
      return;
    }

    final targetAmount = double.tryParse(_targetAmountController.text) ?? 0.0;
    final targetDateStr = _targetDate?.toIso8601String().split('T').first;

    final result = _isEditing
        ? await provider.updateGoal(
            accessToken: accessToken,
            goalId: widget.goal!.id,
            name: _nameController.text.trim(),
            targetAmount: targetAmount,
            targetDate: targetDateStr,
          )
        : await provider.createGoal(
            accessToken: accessToken,
            name: _nameController.text.trim(),
            targetAmount: targetAmount,
            targetDate: targetDateStr,
            accountIds: [_selectedAccount!.id],
          );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result['success'] == true) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error']?.toString() ?? 'Failed to save goal')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Goal' : 'New Goal')),
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
            TextFormField(
              controller: _targetAmountController,
              decoration: const InputDecoration(labelText: 'Target amount *'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                final parsed = double.tryParse(v ?? '');
                return (parsed == null || parsed <= 0) ? 'Enter a positive amount' : null;
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_targetDate == null ? 'No target date' : _targetDate!.toIso8601String().split('T').first),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickDate,
            ),
            if (!_isEditing) ...[
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_selectedAccount?.name ?? 'Pick an account *'),
                subtitle: _selectedAccount == null
                    ? Text('Required', style: TextStyle(color: colorScheme.error))
                    : Text(_selectedAccount!.displayAccountType),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickAccount,
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_isEditing ? 'Save Changes' : 'Create Goal'),
            ),
          ],
        ),
      ),
    );
  }
}
