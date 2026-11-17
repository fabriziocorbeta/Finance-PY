class ReportSummaryMetrics {
  final double income;
  final double? incomeChangePct;
  final double expense;
  final double? expenseChangePct;
  final double netSavings;
  final double? budgetUsedPct;

  ReportSummaryMetrics({
    required this.income,
    this.incomeChangePct,
    required this.expense,
    this.expenseChangePct,
    required this.netSavings,
    this.budgetUsedPct,
  });

  factory ReportSummaryMetrics.fromJson(Map<String, dynamic> json) {
    return ReportSummaryMetrics(
      income: (json['income'] as num?)?.toDouble() ?? 0.0,
      incomeChangePct: (json['income_change_pct'] as num?)?.toDouble(),
      expense: (json['expense'] as num?)?.toDouble() ?? 0.0,
      expenseChangePct: (json['expense_change_pct'] as num?)?.toDouble(),
      netSavings: (json['net_savings'] as num?)?.toDouble() ?? 0.0,
      budgetUsedPct: (json['budget_used_pct'] as num?)?.toDouble(),
    );
  }
}

class ReportNetWorth {
  final double current;
  final double totalAssets;
  final double totalLiabilities;
  final double change;
  final double? changePct;

  ReportNetWorth({
    required this.current,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.change,
    this.changePct,
  });

  factory ReportNetWorth.fromJson(Map<String, dynamic> json) {
    return ReportNetWorth(
      current: (json['current'] as num?)?.toDouble() ?? 0.0,
      totalAssets: (json['total_assets'] as num?)?.toDouble() ?? 0.0,
      totalLiabilities: (json['total_liabilities'] as num?)?.toDouble() ?? 0.0,
      change: (json['change'] as num?)?.toDouble() ?? 0.0,
      changePct: (json['change_pct'] as num?)?.toDouble(),
    );
  }
}

class ReportCategoryGroup {
  final String categoryName;
  final String? categoryColor;
  final double total;
  final int count;

  ReportCategoryGroup({
    required this.categoryName,
    this.categoryColor,
    required this.total,
    required this.count,
  });

  factory ReportCategoryGroup.fromJson(Map<String, dynamic> json) {
    return ReportCategoryGroup(
      categoryName: json['category_name'] as String? ?? 'Uncategorized',
      categoryColor: json['category_color'] as String?,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class ReportSummary {
  final String currency;
  final ReportSummaryMetrics summary;
  final ReportNetWorth netWorth;
  final List<ReportCategoryGroup> incomeBreakdown;
  final List<ReportCategoryGroup> expenseBreakdown;

  ReportSummary({
    required this.currency,
    required this.summary,
    required this.netWorth,
    required this.incomeBreakdown,
    required this.expenseBreakdown,
  });

  factory ReportSummary.fromJson(Map<String, dynamic> json) {
    final breakdown = json['transactions_breakdown'] as Map<String, dynamic>? ?? {};
    final incomeJson = breakdown['income'] as List<dynamic>? ?? [];
    final expenseJson = breakdown['expense'] as List<dynamic>? ?? [];

    return ReportSummary(
      currency: json['currency'] as String? ?? 'USD',
      summary: ReportSummaryMetrics.fromJson(json['summary'] as Map<String, dynamic>? ?? {}),
      netWorth: ReportNetWorth.fromJson(json['net_worth'] as Map<String, dynamic>? ?? {}),
      incomeBreakdown: incomeJson.map((g) => ReportCategoryGroup.fromJson(g as Map<String, dynamic>)).toList(),
      expenseBreakdown: expenseJson.map((g) => ReportCategoryGroup.fromJson(g as Map<String, dynamic>)).toList(),
    );
  }
}
