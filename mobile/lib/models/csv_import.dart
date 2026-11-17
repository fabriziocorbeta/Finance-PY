class ImportStatusDetail {
  final bool uploaded;
  final bool configured;
  final bool terminal;
  final bool? publishable;

  ImportStatusDetail({
    required this.uploaded,
    required this.configured,
    required this.terminal,
    this.publishable,
  });

  factory ImportStatusDetail.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return ImportStatusDetail(uploaded: false, configured: false, terminal: false);
    }
    return ImportStatusDetail(
      uploaded: json['uploaded'] as bool? ?? false,
      configured: json['configured'] as bool? ?? false,
      terminal: json['terminal'] as bool? ?? false,
      publishable: json['publishable'] as bool?,
    );
  }
}

class CsvImport {
  final String id;
  final String type;
  final String status;
  final String createdAt;
  final String? accountId;
  final String? error;
  final int? rowsCount;
  final ImportStatusDetail statusDetail;

  CsvImport({
    required this.id,
    required this.type,
    required this.status,
    required this.createdAt,
    this.accountId,
    this.error,
    this.rowsCount,
    required this.statusDetail,
  });

  factory CsvImport.fromJson(Map<String, dynamic> json) {
    return CsvImport(
      id: json['id'].toString(),
      type: json['type'] as String? ?? 'TransactionImport',
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] as String? ?? '',
      accountId: json['account_id']?.toString(),
      error: json['error'] as String?,
      rowsCount: (json['rows_count'] as num?)?.toInt(),
      statusDetail: ImportStatusDetail.fromJson(json['status_detail'] as Map<String, dynamic>?),
    );
  }
}
