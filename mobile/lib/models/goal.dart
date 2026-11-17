class Goal {
  final String id;
  final String name;
  final double targetAmount;
  final String currency;
  final String? targetDate;
  final String? color;
  final String? icon;
  final String? notes;
  final String state;
  final double currentBalance;
  final double remainingAmount;
  final double progressPercent;
  final List<String> accountIds;
  final double pace;
  final String status;
  final double? monthsRemaining;

  Goal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currency,
    this.targetDate,
    this.color,
    this.icon,
    this.notes,
    required this.state,
    required this.currentBalance,
    required this.remainingAmount,
    required this.progressPercent,
    required this.accountIds,
    required this.pace,
    required this.status,
    this.monthsRemaining,
  });

  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      targetAmount: (json['target_amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'USD',
      targetDate: json['target_date'] as String?,
      color: json['color'] as String?,
      icon: json['icon'] as String?,
      notes: json['notes'] as String?,
      state: json['state'] as String? ?? 'active',
      currentBalance: (json['current_balance'] as num?)?.toDouble() ?? 0.0,
      remainingAmount: (json['remaining_amount'] as num?)?.toDouble() ?? 0.0,
      progressPercent: (json['progress_percent'] as num?)?.toDouble() ?? 0.0,
      accountIds: (json['account_ids'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      pace: (json['pace'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'no_target_date',
      monthsRemaining: (json['months_remaining'] as num?)?.toDouble(),
    );
  }

  bool get isArchived => state == 'archived';
}
