import 'package:flutter/foundation.dart';
import '../models/tag.dart';
import '../models/merchant.dart';
import '../services/tags_service.dart';
import '../services/merchants_service.dart';
import '../services/log_service.dart';

class TagsMerchantsProvider with ChangeNotifier {
  final TagsService _tagsService = TagsService();
  final MerchantsService _merchantsService = MerchantsService();
  final LogService _log = LogService.instance;

  List<Tag> _tags = [];
  List<Merchant> _merchants = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Tag> get tags => List.unmodifiable(_tags);
  List<Merchant> get merchants => List.unmodifiable(_merchants);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchAll({required String accessToken}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _tagsService.getTags(accessToken: accessToken),
        _merchantsService.getMerchants(accessToken: accessToken),
      ]);

      final tagsResult = results[0];
      final merchantsResult = results[1];

      if (tagsResult['success'] == true) {
        _tags = tagsResult['tags'] as List<Tag>;
      } else {
        _errorMessage = tagsResult['error'] as String?;
        _log.error('TagsMerchantsProvider', 'Failed to fetch tags: $_errorMessage');
      }

      if (merchantsResult['success'] == true) {
        _merchants = merchantsResult['merchants'] as List<Merchant>;
      } else {
        _errorMessage ??= merchantsResult['error'] as String?;
        _log.error('TagsMerchantsProvider', 'Failed to fetch merchants: ${merchantsResult['error']}');
      }
    } catch (e) {
      _errorMessage = 'Failed to load tags and merchants';
      _log.error('TagsMerchantsProvider', 'Exception: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _tags = [];
    _merchants = [];
    _errorMessage = null;
    notifyListeners();
  }
}
