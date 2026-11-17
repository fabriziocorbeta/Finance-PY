class InstallmentScheduleItem {
  final int number;
  final String dueDate;
  final double amount;
  final double paidAmount;
  final String status;

  InstallmentScheduleItem({
    required this.number,
    required this.dueDate,
    required this.amount,
    required this.paidAmount,
    required this.status,
  });

  factory InstallmentScheduleItem.fromJson(Map<String, dynamic> json) {
    return InstallmentScheduleItem(
      number: (json['number'] as num?)?.toInt() ?? 0,
      dueDate: json['due_date'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'pending',
    );
  }
}

class Receivable {
  final String id;
  final double totalAmount;
  final int? installmentCount;
  final int? dueDay;
  final String? firstDueDate;
  final String accountId;
  final double balance;
  final double originalBalance;
  final double paidAmount;
  final double percentPaid;
  final String name;
  final String currency;
  final String? notes;
  final List<InstallmentScheduleItem> installmentSchedule;

  Receivable({
    required this.id,
    required this.totalAmount,
    this.installmentCount,
    this.dueDay,
    this.firstDueDate,
    required this.accountId,
    required this.balance,
    required this.originalBalance,
    required this.paidAmount,
    required this.percentPaid,
    required this.name,
    required this.currency,
    this.notes,
    required this.installmentSchedule,
  });

  factory Receivable.fromJson(Map<String, dynamic> json) {
    final scheduleJson = json['installment_schedule'] as List<dynamic>? ?? [];
    return Receivable(
      id: json['id'].toString(),
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      installmentCount: (json['installment_count'] as num?)?.toInt(),
      dueDay: (json['due_day'] as num?)?.toInt(),
      firstDueDate: json['first_due_date'] as String?,
      accountId: json['account_id'].toString(),
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      originalBalance: (json['original_balance'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0.0,
      percentPaid: (json['percent_paid'] as num?)?.toDouble() ?? 0.0,
      name: json['name'] as String? ?? '',
      currency: json['currency'] as String? ?? 'USD',
      notes: json['notes'] as String?,
      installmentSchedule:
          scheduleJson.map((s) => InstallmentScheduleItem.fromJson(s as Map<String, dynamic>)).toList(),
    );
  }

  bool get isPaidOff => balance <= 0;
}
