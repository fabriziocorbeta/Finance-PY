class PurchaseOrderItem {
  final String id;
  final String? productName;
  final double quantity;
  final double unitCost;
  final double subtotal;

  PurchaseOrderItem({
    required this.id,
    this.productName,
    required this.quantity,
    required this.unitCost,
    required this.subtotal,
  });

  factory PurchaseOrderItem.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderItem(
      id: json['id'].toString(),
      productName: json['product_name'] as String?,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unitCost: (json['unit_cost'] as num?)?.toDouble() ?? 0.0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class PurchaseOrder {
  final String id;
  final String? orderNumber;
  final String? supplierName;
  final String status;
  final String currency;
  final String? expectedDate;
  final double total;
  final List<PurchaseOrderItem> items;

  PurchaseOrder({
    required this.id,
    this.orderNumber,
    this.supplierName,
    required this.status,
    required this.currency,
    this.expectedDate,
    required this.total,
    required this.items,
  });

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['purchase_order_items'] as List<dynamic>? ?? [];
    return PurchaseOrder(
      id: json['id'].toString(),
      orderNumber: json['order_number'] as String?,
      supplierName: json['supplier_name'] as String?,
      status: json['status'] as String? ?? 'draft',
      currency: json['currency'] as String? ?? 'USD',
      expectedDate: json['expected_date'] as String?,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      items: itemsJson.map((i) => PurchaseOrderItem.fromJson(i as Map<String, dynamic>)).toList(),
    );
  }
}
