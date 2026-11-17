import 'package:flutter/foundation.dart';
import '../models/fleet_vehicle.dart';
import '../services/fleet_vehicles_service.dart';
import '../services/log_service.dart';

class FleetVehiclesProvider with ChangeNotifier {
  final FleetVehiclesService _service = FleetVehiclesService();
  final LogService _log = LogService.instance;

  List<FleetVehicle> _vehicles = [];
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<FleetVehicle> get vehicles => List.unmodifiable(_vehicles);

  Future<void> fetchFleetVehicles({required String accessToken}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _service.getFleetVehicles(accessToken: accessToken);

      if (result['success'] == true) {
        _vehicles = result['vehicles'] as List<FleetVehicle>;
        _errorMessage = null;
      } else {
        _errorMessage = result['error'] as String? ?? 'Failed to fetch fleet vehicles';
        _log.error('FleetVehiclesProvider', 'Failed to fetch: $_errorMessage');
      }
    } catch (e) {
      _errorMessage = 'Failed to load fleet vehicles';
      _log.error('FleetVehiclesProvider', 'Exception: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> createFleetVehicle({
    required String accessToken,
    String? plate,
    String? brand,
    String? model,
    int? year,
    String? status,
    String? notes,
  }) async {
    final result = await _service.createFleetVehicle(
      accessToken: accessToken,
      plate: plate,
      brand: brand,
      model: model,
      year: year,
      status: status,
      notes: notes,
    );
    if (result['success'] == true) {
      _vehicles = [..._vehicles, result['vehicle'] as FleetVehicle];
      notifyListeners();
    }
    return result;
  }

  Future<Map<String, dynamic>> updateFleetVehicle({
    required String accessToken,
    required String vehicleId,
    String? plate,
    String? brand,
    String? model,
    int? year,
    String? status,
    String? notes,
  }) async {
    final result = await _service.updateFleetVehicle(
      accessToken: accessToken,
      vehicleId: vehicleId,
      plate: plate,
      brand: brand,
      model: model,
      year: year,
      status: status,
      notes: notes,
    );
    if (result['success'] == true) {
      final updated = result['vehicle'] as FleetVehicle;
      _vehicles = _vehicles.map((v) => v.id == vehicleId ? updated : v).toList();
      notifyListeners();
    }
    return result;
  }

  Future<Map<String, dynamic>> deleteFleetVehicle({
    required String accessToken,
    required String vehicleId,
  }) async {
    final result = await _service.deleteFleetVehicle(accessToken: accessToken, vehicleId: vehicleId);
    if (result['success'] == true) {
      _vehicles = _vehicles.where((v) => v.id != vehicleId).toList();
      notifyListeners();
    }
    return result;
  }

  void clear() {
    _vehicles = [];
    _errorMessage = null;
    notifyListeners();
  }
}
