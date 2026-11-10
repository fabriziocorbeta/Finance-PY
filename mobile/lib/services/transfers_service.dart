import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/transfer.dart';
import 'api_config.dart';

class TransfersService {
  Future<Map<String, dynamic>> createTransfer({
    required String accessToken,
    required String fromAccountId,
    required String toAccountId,
    required String amount,
    String? date,
    String? exchangeRate,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/transfers');

    final body = {
      'transfer': {
        'from_account_id': fromAccountId,
        'to_account_id': toAccountId,
        'amount': amount,
        if (date != null) 'date': date,
        if (exchangeRate != null) 'exchange_rate': exchangeRate,
      }
    };

    try {
      final response = await http.post(
        url,
        headers: {
          ...ApiConfig.getAuthHeaders(accessToken),
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        return {
          'success': true,
          'transfer': Transfer.fromJson(responseData),
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'unauthorized',
        };
      } else {
        try {
          final responseData = jsonDecode(response.body);
          return {
            'success': false,
            'error': responseData['message'] ?? responseData['error'] ?? 'Failed to create transfer',
            if (responseData['errors'] != null) 'errors': responseData['errors'],
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'Failed to create transfer: ${response.body}',
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
