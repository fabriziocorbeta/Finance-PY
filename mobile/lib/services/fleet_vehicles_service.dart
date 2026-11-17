import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/fleet_vehicle.dart';
import 'api_config.dart';

class FleetVehiclesService {
  Future<Map<String, dynamic>> getFleetVehicles({
    required String accessToken,
    int page = 1,
    int perPage = 50,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/fleet_vehicles').replace(
      queryParameters: {
        'page': page.toString(),
        'per_page': perPage.toString(),
      },
    );

    try {
      final response = await http.get(
        url,
        headers: ApiConfig.getAuthHeaders(accessToken),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final rawData = responseData['data'] as List? ?? [];
        final vehicles = rawData.map((json) => FleetVehicle.fromJson(json as Map<String, dynamic>)).toList();
        return {'success': true, 'vehicles': vehicles};
      } else if (response.statusCode == 401) {
        return {'success': false, 'error': 'unauthorized'};
      } else {
        final responseData = jsonDecode(response.body);
        return {'success': false, 'error': responseData['error'] ?? 'Failed to fetch fleet vehicles'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  Map<String, dynamic> _vehicleBody({
    String? plate,
    String? brand,
    String? model,
    int? year,
    String? status,
    String? notes,
  }) {
    return {
      'fleet_vehicle': {
        if (plate != null) 'plate': plate,
        if (brand != null) 'brand': brand,
        if (model != null) 'model': model,
        if (year != null) 'year': year,
        if (status != null) 'status': status,
        if (notes != null) 'notes': notes,
      },
    };
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
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/fleet_vehicles');

    try {
      final response = await http.post(
        url,
        headers: {
          ...ApiConfig.getAuthHeaders(accessToken),
          'Content-Type': 'application/json',
        },
        body: jsonEncode(_vehicleBody(plate: plate, brand: brand, model: model, year: year, status: status, notes: notes)),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        return {'success': true, 'vehicle': FleetVehicle.fromJson(responseData['data'] as Map<String, dynamic>)};
      } else {
        final responseData = jsonDecode(response.body);
        return {'success': false, 'error': responseData['message'] ?? responseData['error'] ?? 'Failed to create vehicle'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
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
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/fleet_vehicles/$vehicleId');

    try {
      final response = await http.patch(
        url,
        headers: {
          ...ApiConfig.getAuthHeaders(accessToken),
          'Content-Type': 'application/json',
        },
        body: jsonEncode(_vehicleBody(plate: plate, brand: brand, model: model, year: year, status: status, notes: notes)),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {'success': true, 'vehicle': FleetVehicle.fromJson(responseData['data'] as Map<String, dynamic>)};
      } else {
        final responseData = jsonDecode(response.body);
        return {'success': false, 'error': responseData['message'] ?? responseData['error'] ?? 'Failed to update vehicle'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> deleteFleetVehicle({
    required String accessToken,
    required String vehicleId,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/fleet_vehicles/$vehicleId');

    try {
      final response = await http.delete(
        url,
        headers: ApiConfig.getAuthHeaders(accessToken),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return {'success': true};
      } else {
        final responseData = jsonDecode(response.body);
        return {'success': false, 'error': responseData['message'] ?? responseData['error'] ?? 'Failed to delete vehicle'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }
}
