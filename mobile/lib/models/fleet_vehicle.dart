class FleetVehicle {
  final String id;
  final String? plate;
  final String? brand;
  final String? model;
  final int? year;
  final String status;
  final double? averageFuelEfficiency;
  final double? monthlyFuelConsumed;
  final double? monthlyDistance;
  final int fuelLogCount;

  FleetVehicle({
    required this.id,
    this.plate,
    this.brand,
    this.model,
    this.year,
    required this.status,
    this.averageFuelEfficiency,
    this.monthlyFuelConsumed,
    this.monthlyDistance,
    required this.fuelLogCount,
  });

  factory FleetVehicle.fromJson(Map<String, dynamic> json) {
    final fuelLogs = json['fuel_logs'] as List<dynamic>? ?? [];
    return FleetVehicle(
      id: json['id'].toString(),
      plate: json['plate'] as String?,
      brand: json['brand'] as String?,
      model: json['model'] as String?,
      year: (json['year'] as num?)?.toInt(),
      status: json['status'] as String? ?? 'active',
      averageFuelEfficiency: (json['average_fuel_efficiency'] as num?)?.toDouble(),
      monthlyFuelConsumed: (json['monthly_fuel_consumed'] as num?)?.toDouble(),
      monthlyDistance: (json['monthly_distance'] as num?)?.toDouble(),
      fuelLogCount: fuelLogs.length,
    );
  }

  String get displayName {
    final parts = [brand, model].where((p) => p != null && p.isNotEmpty).join(' ');
    if (parts.isNotEmpty) return parts;
    return plate ?? 'Vehicle';
  }
}
