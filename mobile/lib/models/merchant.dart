class Merchant {
  final String id;
  final String name;
  final String type;

  Merchant({required this.id, required this.name, required this.type});

  factory Merchant.fromJson(Map<String, dynamic> json) {
    return Merchant(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? '',
    );
  }
}
