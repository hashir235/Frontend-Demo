class RateReviewRow {
  final String section;
  final double totalFt;
  final double rate;

  const RateReviewRow({
    required this.section,
    required this.totalFt,
    required this.rate,
  });

  factory RateReviewRow.fromJson(Map<String, dynamic> json) {
    return RateReviewRow(
      section: json['section'] as String? ?? '',
      totalFt: (json['totalFt'] as num?)?.toDouble() ?? 0,
      rate: (json['rate'] as num?)?.toDouble() ?? 0,
    );
  }
}

class RateReview {
  final bool ok;
  final List<String> errors;
  final String gauge;
  final String color;
  final List<RateReviewRow> rows;

  const RateReview({
    required this.ok,
    required this.errors,
    required this.gauge,
    required this.color,
    required this.rows,
  });

  factory RateReview.fromJson(Map<String, dynamic> json) {
    final Object? rawRows = json['rows'];
    final List<dynamic> rowItems = rawRows is List<dynamic> ? rawRows : const <dynamic>[];

    return RateReview(
      ok: json['ok'] as bool? ?? false,
      errors: (json['errors'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic item) => item.toString())
          .toList(),
      gauge: json['gauge'] as String? ?? '',
      color: json['color'] as String? ?? '',
      rows: rowItems
          .whereType<Map<String, dynamic>>()
          .map(RateReviewRow.fromJson)
          .toList(),
    );
  }
}
