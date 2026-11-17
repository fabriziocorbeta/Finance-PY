class Tag {
  final String id;
  final String name;
  final String? color;

  Tag({required this.id, required this.name, this.color});

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      color: json['color'] as String?,
    );
  }
}
