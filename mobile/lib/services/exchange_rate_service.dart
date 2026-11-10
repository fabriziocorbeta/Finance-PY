import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class ExchangeRateService {
  Future<Map<String, dynamic>> getRate({
    required String accessToken,
    required String from,
    required String to,
    String? date,
  }) async {
    final queryParams = {
      'from': from,
      'to': to,
      if (date != null) 'date': date,
    };

    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/exchange_rate')
        .replace(queryParameters: queryParams);

    try {
      final response = await http.get(
        url,
        headers: {
          ...ApiConfig.getAuthHeaders(accessToken),
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        // The server always sends `rate` as a JSON string (BigDecimal#to_s("F"))
        // -- decode it as a String here and never reparse it as a double,
        // which would reintroduce the binary-float rounding this feature
        // exists to avoid.
        final responseData = jsonDecode(response.body);
        return {
          'success': true,
          'sameCurrency': responseData['same_currency'] == true,
          'rate': responseData['rate']?.toString(),
          if (responseData['rate_date'] != null) 'rateDate': responseData['rate_date'].toString(),
          if (responseData['stale'] != null) 'stale': responseData['stale'] == true,
          if (responseData['rate_hint'] != null) 'rateHint': responseData['rate_hint'].toString(),
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'unauthorized',
        };
      } else if (response.statusCode == 404) {
        try {
          final responseData = jsonDecode(response.body);
          return {
            'success': false,
            'error': 'not_found',
            if (responseData['rate_hint'] != null) 'rateHint': responseData['rate_hint'].toString(),
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'not_found',
          };
        }
      } else {
        try {
          final responseData = jsonDecode(response.body);
          return {
            'success': false,
            'error': responseData['message'] ?? responseData['error'] ?? 'Failed to fetch exchange rate',
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'Failed to fetch exchange rate: ${response.body}',
          };
        }
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }
}
