class RecurringTransactionAccount {
  final String id;
  final String name;
  final String accountType;

  RecurringTransactionAccount({required this.id, required this.name, required this.accountType});

  factory RecurringTransactionAccount.fromJson(Map<String, dynamic> json) {
    return RecurringTransactionAccount(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      accountType: json['account_type'] as String? ?? '',
    );
  }
}

class RecurringTransactionMerchant {
  final String id;
  final String name;

  RecurringTransactionMerchant({required this.id, required this.name});

  factory RecurringTransactionMerchant.fromJson(Map<String, dynamic> json) {
    return RecurringTransactionMerchant(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
    );
  }
}

class RecurringTransaction {
  final String id;
  final String amount;
  final String currency;
  final int? expectedDayOfMonth;
  final String? lastOccurrenceDate;
  final String? nextExpectedDate;
  final String status;
  final int occurrenceCount;
  final String name;
  final bool manual;
  final RecurringTransactionAccount? account;
  final RecurringTransactionMerchant? merchant;

  RecurringTransaction({
    required this.id,
    required this.amount,
    required this.currency,
    this.expectedDayOfMonth,
    this.lastOccurrenceDate,
    this.nextExpectedDate,
    required this.status,
    required this.occurrenceCount,
    required this.name,
    required this.manual,
    this.account,
    this.merchant,
  });

  factory RecurringTransaction.fromJson(Map<String, dynamic> json) {
    return RecurringTransaction(
      id: json['id'].toString(),
      amount: json['amount'] as String? ?? '0',
      currency: json['currency'] as String? ?? 'USD',
      expectedDayOfMonth: (json['expected_day_of_month'] as num?)?.toInt(),
      lastOccurrenceDate: json['last_occurrence_date'] as String?,
      nextExpectedDate: json['next_expected_date'] as String?,
      status: json['status'] as String? ?? 'active',
      occurrenceCount: (json['occurrence_count'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      manual: json['manual'] as bool? ?? false,
      account: json['account'] != null
          ? RecurringTransactionAccount.fromJson(json['account'] as Map<String, dynamic>)
          : null,
      merchant: json['merchant'] != null
          ? RecurringTransactionMerchant.fromJson(json['merchant'] as Map<String, dynamic>)
          : null,
    );
  }

  bool get isActive => status == 'active';

  double get amountAsDouble {
    final cleaned = amount.replaceAll(RegExp(r'[^\d.-]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }
}
