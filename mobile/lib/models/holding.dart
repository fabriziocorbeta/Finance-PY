class HoldingAccount {
  final String id;
  final String name;
  final String accountType;

  HoldingAccount({
    required this.id,
    required this.name,
    required this.accountType,
  });

  factory HoldingAccount.fromJson(Map<String, dynamic> json) {
    return HoldingAccount(
      id: json['id'].toString(),
      name: json['name'] as String,
      accountType: json['account_type'] as String? ?? '',
    );
  }
}

class HoldingSecurity {
  final String id;
  final String ticker;
  final String name;

  HoldingSecurity({
    required this.id,
    required this.ticker,
    required this.name,
  });

  factory HoldingSecurity.fromJson(Map<String, dynamic> json) {
    return HoldingSecurity(
      id: json['id'].toString(),
      ticker: json['ticker'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }
}

class Holding {
  final String id;
  final String date;
  final String qty;
  final String price;
  final String amount;
  final String currency;
  final String? avgCost;
  final HoldingAccount account;
  final HoldingSecurity security;

  Holding({
    required this.id,
    required this.date,
    required this.qty,
    required this.price,
    required this.amount,
    required this.currency,
    this.avgCost,
    required this.account,
    required this.security,
  });

  factory Holding.fromJson(Map<String, dynamic> json) {
    return Holding(
      id: json['id'].toString(),
      date: json['date'] as String,
      qty: json['qty'].toString(),
      price: json['price'] as String,
      amount: json['amount'] as String,
      currency: json['currency'] as String,
      avgCost: json['avg_cost'] as String?,
      account: HoldingAccount.fromJson(json['account'] as Map<String, dynamic>),
      security: HoldingSecurity.fromJson(json['security'] as Map<String, dynamic>),
    );
  }

  double get qtyAsDouble => double.tryParse(qty) ?? 0.0;

  double get amountAsDouble {
    final cleaned = amount.replaceAll(RegExp(r'[^\d.-]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }
}
