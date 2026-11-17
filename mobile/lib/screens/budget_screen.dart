import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/budget.dart';
import '../providers/budgets_provider.dart';
import '../providers/auth_provider.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBudgets();
    });
  }

  Future<void> _loadBudgets() async {
    final authProvider = context.read<AuthProvider>();
    final budgetsProvider = context.read<BudgetsProvider>();

    final accessToken = await authProvider.getValidAccessToken();
    if (accessToken != null) {
      await budgetsProvider.fetchBudgets(accessToken: accessToken);
    }
  }

  Color _parseCategoryColor(String? hex, ColorScheme colorScheme) {
    if (hex == null || hex.isEmpty) return colorScheme.primary;
    final cleaned = hex.replaceAll('#', '');
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return colorScheme.primary;
    final argb = cleaned.length == 6 ? 0xFF000000 | value : value;
    return Color(argb);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final budgetsProvider = context.watch<BudgetsProvider>();
    final budget = budgetsProvider.currentBudget;

    return Scaffold(
      appBar: AppBar(title: const Text('Budget')),
      body: RefreshIndicator(
        onRefresh: _loadBudgets,
        child: budgetsProvider.isLoading && budgetsProvider.budgets.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : budgetsProvider.errorMessage != null && budgetsProvider.budgets.isEmpty
                ? _buildErrorState(colorScheme, budgetsProvider.errorMessage!)
                : budget == null
                    ? _buildEmptyState(colorScheme)
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildSummaryCard(colorScheme, budget),
                          const SizedBox(height: 24),
                          if (!budget.initialized)
                            _buildNotInitializedNotice(colorScheme)
                          else if (budget.categories.isEmpty)
                            _buildNoCategoriesNotice(colorScheme)
                          else
                            ...budget.categories.map(
                              (c) => _buildCategoryRow(colorScheme, budget, c),
                            ),
                        ],
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
            Icon(Icons.pie_chart_outline, size: 64, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('No Budget Yet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Set up a budget on the web to track it here.',
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
            Text('Unable to load budget', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: TextStyle(color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadBudgets, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildNotInitializedNotice(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'This budget period hasn\'t been set up yet. Allocate category budgets on the web to see them here.',
        style: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
    );
  }

  Widget _buildNoCategoriesNotice(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'No category budgets allocated for this period yet.',
        style: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
    );
  }

  Widget _buildSummaryCard(ColorScheme colorScheme, Budget budget) {
    final currencyFormat = NumberFormat.currency(symbol: '${budget.currency} ', decimalDigits: 2);
    final spentPercent = budget.percentOfBudgetSpent.clamp(0, 100) / 100;
    final isOverBudget = budget.actualSpending > budget.budgetedSpending && budget.budgetedSpending > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            budget.name,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${currencyFormat.format(budget.actualSpending)} spent',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isOverBudget ? colorScheme.error : colorScheme.onSurface,
                ),
              ),
              Text(
                'of ${currencyFormat.format(budget.budgetedSpending)}',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: spentPercent.toDouble(),
              minHeight: 8,
              backgroundColor: colorScheme.surfaceContainerHighest,
              color: isOverBudget ? colorScheme.error : colorScheme.primary,
            ),
          ),
          if (budget.expectedIncome > 0) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${currencyFormat.format(budget.actualIncome)} income',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                Text(
                  'of ${currencyFormat.format(budget.expectedIncome)} expected',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryRow(ColorScheme colorScheme, Budget budget, BudgetCategoryEntry category) {
    final currencyFormat = NumberFormat.currency(symbol: '${budget.currency} ', decimalDigits: 2);
    final color = _parseCategoryColor(category.categoryColor, colorScheme);
    final barColor = category.overBudget
        ? colorScheme.error
        : category.nearLimit
            ? Colors.amber.shade700
            : color;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    category.categoryName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              Text(
                category.budgeted
                    ? '${currencyFormat.format(category.actualSpending)} / ${currencyFormat.format(category.budgetedSpending)}'
                    : currencyFormat.format(category.actualSpending),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: category.overBudget ? colorScheme.error : colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (category.barWidthPercent.clamp(0, 100) / 100).toDouble(),
              minHeight: 6,
              backgroundColor: colorScheme.surfaceContainerHighest,
              color: barColor,
            ),
          ),
        ],
      ),
    );
  }
}
