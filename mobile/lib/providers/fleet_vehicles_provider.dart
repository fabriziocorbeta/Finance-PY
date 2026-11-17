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

  void clear() {
    _vehicles = [];
    _errorMessage = null;
    notifyListeners();
  }
}
