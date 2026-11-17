import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/report_summary.dart';
import '../providers/reports_provider.dart';
import '../providers/auth_provider.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  static const _periods = {
    'monthly': 'This month',
    'quarterly': 'This quarter',
    'last_6_months': 'Last 6 months',
    'ytd': 'Year to date',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  Future<void> _load({String? periodType}) async {
    final authProvider = context.read<AuthProvider>();
    final provider = context.read<ReportsProvider>();

    final accessToken = await authProvider.getValidAccessToken();
    if (accessToken != null) {
      await provider.fetchSummary(accessToken: accessToken, periodType: periodType);
    }
  }

  Color _parseColor(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    final cleaned = hex.replaceAll('#', '');
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return fallback;
    return Color(cleaned.length == 6 ? 0xFF000000 | value : value);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final provider = context.watch<ReportsProvider>();
    final summary = provider.summary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          PopupMenuButton<String>(
            initialValue: provider.periodType,
            onSelected: (value) => _load(periodType: value),
            itemBuilder: (context) => _periods.entries
                .map((e) => PopupMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            icon: const Icon(Icons.calendar_today_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(),
        child: provider.isLoading && summary == null
            ? const Center(child: CircularProgressIndicator())
            : provider.errorMessage != null && summary == null
                ? _buildErrorState(colorScheme, provider.errorMessage!)
                : summary == null
                    ? const SizedBox.shrink()
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text(
                            _periods[provider.periodType] ?? provider.periodType,
                            style: TextStyle(color: colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 12),
                          _buildSummaryCard(colorScheme, summary),
                          const SizedBox(height: 16),
                          _buildNetWorthCard(colorScheme, summary),
                          const SizedBox(height: 16),
                          if (summary.expenseBreakdown.isNotEmpty)
                            _buildBreakdownCard(colorScheme, summary, 'Spending by Category', summary.expenseBreakdown),
                          if (summary.incomeBreakdown.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _buildBreakdownCard(colorScheme, summary, 'Income by Category', summary.incomeBreakdown),
                          ],
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
            Text('Unable to load report', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: TextStyle(color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => _load(), child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(ColorScheme colorScheme, ReportSummary summary) {
    final format = NumberFormat.currency(symbol: '${summary.currency} ', decimalDigits: 2);
    final metrics = summary.summary;
    final isPositive = metrics.netSavings >= 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetric(colorScheme, 'Income', format.format(metrics.income), metrics.incomeChangePct, Colors.green.shade700),
              _buildMetric(colorScheme, 'Expenses', format.format(metrics.expense), metrics.expenseChangePct, colorScheme.error),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Net savings', style: TextStyle(color: colorScheme.onSurfaceVariant)),
              Text(
                format.format(metrics.netSavings),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isPositive ? Colors.green.shade700 : colorScheme.error,
                ),
              ),
            ],
          ),
          if (metrics.budgetUsedPct != null) ...[
            const SizedBox(height: 8),
            Text(
              'Budget used: ${metrics.budgetUsedPct!.toStringAsFixed(0)}%',
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetric(ColorScheme colorScheme, String label, String value, double? changePct, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
        if (changePct != null)
          Text(
            '${changePct >= 0 ? '+' : ''}${changePct.toStringAsFixed(1)}% vs last period',
            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
          ),
      ],
    );
  }

  Widget _buildNetWorthCard(ColorScheme colorScheme, ReportSummary summary) {
    final format = NumberFormat.currency(symbol: '${summary.currency} ', decimalDigits: 2);
    final nw = summary.netWorth;
    final isPositiveChange = nw.change >= 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Net Worth', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(format.format(nw.current), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          const SizedBox(height: 4),
          Text(
            '${isPositiveChange ? '+' : ''}${format.format(nw.change)}${nw.changePct != null ? ' (${nw.changePct!.toStringAsFixed(1)}%)' : ''}',
            style: TextStyle(color: isPositiveChange ? Colors.green.shade700 : colorScheme.error, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Assets: ${format.format(nw.totalAssets)}', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
              Text('Liabilities: ${format.format(nw.totalLiabilities)}', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownCard(
    ColorScheme colorScheme,
    ReportSummary summary,
    String title,
    List<ReportCategoryGroup> groups,
  ) {
    final format = NumberFormat.currency(symbol: '${summary.currency} ', decimalDigits: 2);
    final maxTotal = groups.map((g) => g.total).fold(0.0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ...groups.take(10).map((group) {
            final color = _parseColor(group.categoryColor, colorScheme.primary);
            final barWidth = maxTotal > 0 ? (group.total / maxTotal).clamp(0, 1).toDouble() : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(group.categoryName, maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ),
                      Text(format.format(group.total), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: barWidth,
                      minHeight: 6,
                      backgroundColor: colorScheme.surfaceDim,
                      color: color,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
