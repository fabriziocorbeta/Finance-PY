import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/merchant.dart';
import 'api_config.dart';

class MerchantsService {
  Future<Map<String, dynamic>> getMerchants({required String accessToken}) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/merchants');

    try {
      final response = await http.get(
        url,
        headers: ApiConfig.getAuthHeaders(accessToken),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final rawList = responseData is List ? responseData : <dynamic>[];
        final merchants = rawList.map((json) => Merchant.fromJson(json as Map<String, dynamic>)).toList();
        return {'success': true, 'merchants': merchants};
      } else if (response.statusCode == 401) {
        return {'success': false, 'error': 'unauthorized'};
      } else {
        final responseData = jsonDecode(response.body);
        return {'success': false, 'error': responseData['error'] ?? 'Failed to fetch merchants'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }
}
