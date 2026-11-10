class Transfer {
  final String id;
  final String status;
  final String date;
  final double amount;
  final String currency;
  final String fromAccountId;
  final String fromAccountName;
  final String toAccountId;
  final String toAccountName;

  Transfer({
    required this.id,
    required this.status,
    required this.date,
    required this.amount,
    required this.currency,
    required this.fromAccountId,
    required this.fromAccountName,
    required this.toAccountId,
    required this.toAccountName,
  });

  factory Transfer.fromJson(Map<String, dynamic> json) {
    final fromAccount = json['from_account'] as Map<String, dynamic>? ?? const {};
    final toAccount = json['to_account'] as Map<String, dynamic>? ?? const {};

    return Transfer(
      id: json['id'].toString(),
      status: json['status']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency']?.toString() ?? '',
      fromAccountId: fromAccount['id']?.toString() ?? '',
      fromAccountName: fromAccount['name']?.toString() ?? '',
      toAccountId: toAccount['id']?.toString() ?? '',
      toAccountName: toAccount['name']?.toString() ?? '',
    );
  }
}
