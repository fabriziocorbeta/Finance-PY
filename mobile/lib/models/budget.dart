class BudgetCategoryEntry {
  final String id;
  final String categoryId;
  final String categoryName;
  final String? categoryColor;
  final String? categoryIcon;
  final double budgetedSpending;
  final double actualSpending;
  final double percentOfBudgetSpent;
  final double barWidthPercent;
  final bool overBudget;
  final bool nearLimit;
  final bool budgeted;

  BudgetCategoryEntry({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    this.categoryColor,
    this.categoryIcon,
    required this.budgetedSpending,
    required this.actualSpending,
    required this.percentOfBudgetSpent,
    required this.barWidthPercent,
    required this.overBudget,
    required this.nearLimit,
    required this.budgeted,
  });

  factory BudgetCategoryEntry.fromJson(Map<String, dynamic> json) {
    return BudgetCategoryEntry(
      id: json['id'].toString(),
      categoryId: json['category_id'].toString(),
      categoryName: json['category_name'] as String? ?? '',
      categoryColor: json['category_color'] as String?,
      categoryIcon: json['category_icon'] as String?,
      budgetedSpending: (json['budgeted_spending'] as num?)?.toDouble() ?? 0.0,
      actualSpending: (json['actual_spending'] as num?)?.toDouble() ?? 0.0,
      percentOfBudgetSpent: (json['percent_of_budget_spent'] as num?)?.toDouble() ?? 0.0,
      barWidthPercent: (json['bar_width_percent'] as num?)?.toDouble() ?? 0.0,
      overBudget: json['over_budget'] as bool? ?? false,
      nearLimit: json['near_limit'] as bool? ?? false,
      budgeted: json['budgeted'] as bool? ?? false,
    );
  }
}

class Budget {
  final String id;
  final String startDate;
  final String endDate;
  final String currency;
  final String name;
  final bool initialized;
  final bool current;
  final double budgetedSpending;
  final double expectedIncome;
  final double actualSpending;
  final double availableToSpend;
  final double allocatedSpending;
  final double allocatedPercent;
  final double percentOfBudgetSpent;
  final double actualIncome;
  final List<BudgetCategoryEntry> categories;

  Budget({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.currency,
    required this.name,
    required this.initialized,
    required this.current,
    required this.budgetedSpending,
    required this.expectedIncome,
    required this.actualSpending,
    required this.availableToSpend,
    required this.allocatedSpending,
    required this.allocatedPercent,
    required this.percentOfBudgetSpent,
    required this.actualIncome,
    required this.categories,
  });

  factory Budget.fromJson(Map<String, dynamic> json) {
    final categoriesJson = json['categories'] as List<dynamic>? ?? [];
    return Budget(
      id: json['id'].toString(),
      startDate: json['start_date'] as String,
      endDate: json['end_date'] as String,
      currency: json['currency'] as String? ?? 'USD',
      name: json['name'] as String? ?? '',
      initialized: json['initialized'] as bool? ?? false,
      current: json['current'] as bool? ?? false,
      budgetedSpending: (json['budgeted_spending'] as num?)?.toDouble() ?? 0.0,
      expectedIncome: (json['expected_income'] as num?)?.toDouble() ?? 0.0,
      actualSpending: (json['actual_spending'] as num?)?.toDouble() ?? 0.0,
      availableToSpend: (json['available_to_spend'] as num?)?.toDouble() ?? 0.0,
      allocatedSpending: (json['allocated_spending'] as num?)?.toDouble() ?? 0.0,
      allocatedPercent: (json['allocated_percent'] as num?)?.toDouble() ?? 0.0,
      percentOfBudgetSpent: (json['percent_of_budget_spent'] as num?)?.toDouble() ?? 0.0,
      actualIncome: (json['actual_income'] as num?)?.toDouble() ?? 0.0,
      categories: categoriesJson
          .map((c) => BudgetCategoryEntry.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}
