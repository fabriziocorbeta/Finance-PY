import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/rule.dart';
import '../providers/rules_provider.dart';
import '../providers/auth_provider.dart';

class RulesScreen extends StatefulWidget {
  const RulesScreen({super.key});

  @override
  State<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends State<RulesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  Future<void> _load() async {
    final authProvider = context.read<AuthProvider>();
    final provider = context.read<RulesProvider>();

    final accessToken = await authProvider.getValidAccessToken();
    if (accessToken != null) {
      await provider.fetchRules(accessToken: accessToken);
    }
  }

  String _describeCondition(RuleCondition c) {
    final type = c.conditionType.replaceAll('_', ' ');
    final op = c.operator.replaceAll('_', ' ');
    return c.value != null && c.value!.isNotEmpty ? '$type $op "${c.value}"' : '$type $op';
  }

  String _describeAction(RuleAction a) {
    final type = a.actionType.replaceAll('_', ' ');
    return a.value != null && a.value!.isNotEmpty ? '$type → "${a.value}"' : type;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final provider = context.watch<RulesProvider>();
    final rules = provider.rules;

    return Scaffold(
      appBar: AppBar(title: const Text('Rules')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: provider.isLoading && rules.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : provider.errorMessage != null && rules.isEmpty
                ? _buildErrorState(colorScheme, provider.errorMessage!)
                : rules.isEmpty
                    ? _buildEmptyState(colorScheme)
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: rules.length,
                        itemBuilder: (context, index) => _buildRuleCard(colorScheme, rules[index]),
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
            Icon(Icons.rule_outlined, size: 64, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('No Rules Yet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Automation rules for categorizing transactions will show up here.',
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
            Text('Unable to load rules', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: TextStyle(color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleCard(ColorScheme colorScheme, Rule rule) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  rule.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (rule.active ? Colors.green.shade700 : colorScheme.onSurfaceVariant).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  rule.active ? 'Active' : 'Inactive',
                  style: TextStyle(
                    color: rule.active ? Colors.green.shade700 : colorScheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (rule.conditions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('When', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            ...rule.conditions.map(
              (c) => Text('• ${_describeCondition(c)}', style: const TextStyle(fontSize: 13)),
            ),
          ],
          if (rule.actions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Then', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            ...rule.actions.map(
              (a) => Text('• ${_describeAction(a)}', style: const TextStyle(fontSize: 13)),
            ),
          ],
        ],
      ),
    );
  }
}
