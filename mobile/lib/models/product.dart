class Product {
  final String id;
  final String name;
  final String? sku;
  final String? category;
  final String? supplier;
  final double buyPrice;
  final double sellPrice;
  final String currency;
  final int stock;
  final int? minStock;
  final String? description;

  Product({
    required this.id,
    required this.name,
    this.sku,
    this.category,
    this.supplier,
    required this.buyPrice,
    required this.sellPrice,
    required this.currency,
    required this.stock,
    this.minStock,
    this.description,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      sku: json['sku'] as String?,
      category: json['category'] as String?,
      supplier: json['supplier'] as String?,
      buyPrice: (json['buy_price'] as num?)?.toDouble() ?? 0.0,
      sellPrice: (json['sell_price'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'USD',
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      minStock: (json['min_stock'] as num?)?.toInt(),
      description: json['description'] as String?,
    );
  }

  bool get isLowStock => minStock != null && stock <= minStock!;
}
