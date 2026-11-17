class SaleItem {
  final String id;
  final String? productName;
  final double quantity;
  final double unitPrice;
  final double subtotal;

  SaleItem({
    required this.id,
    this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  factory SaleItem.fromJson(Map<String, dynamic> json) {
    return SaleItem(
      id: json['id'].toString(),
      productName: json['product_name'] as String?,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class Sale {
  final String id;
  final String? saleNumber;
  final String? clientName;
  final String status;
  final String currency;
  final String? paymentMethod;
  final String? invoiceNumber;
  final double total;
  final String createdAt;
  final List<SaleItem> saleItems;

  Sale({
    required this.id,
    this.saleNumber,
    this.clientName,
    required this.status,
    required this.currency,
    this.paymentMethod,
    this.invoiceNumber,
    required this.total,
    required this.createdAt,
    required this.saleItems,
  });

  factory Sale.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['sale_items'] as List<dynamic>? ?? [];
    return Sale(
      id: json['id'].toString(),
      saleNumber: json['sale_number'] as String?,
      clientName: json['client_name'] as String?,
      status: json['status'] as String? ?? 'draft',
      currency: json['currency'] as String? ?? 'USD',
      paymentMethod: json['payment_method'] as String?,
      invoiceNumber: json['invoice_number'] as String?,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] as String? ?? '',
      saleItems: itemsJson.map((i) => SaleItem.fromJson(i as Map<String, dynamic>)).toList(),
    );
  }
}
