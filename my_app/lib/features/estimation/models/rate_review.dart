class RateReviewRow {
  final String section;

  /// The stock this rate is for. M23 in 1.2mm and M23 in 2mm are two rows at
  /// two prices, so the row has to carry which one it is -- both to show the
  /// user and so an edited rate lands on the right one.
  final String gauge;
  final String color;

  final double totalFt;
  final String totalFtDisplay;
  final double rate;

  const RateReviewRow({
    required this.section,
    this.gauge = '',
    this.color = '',
    required this.totalFt,
    required this.totalFtDisplay,
    required this.rate,
  });

  /// Identifies this row among the others. The section name alone does not:
  /// a job can list the same profile twice.
  String get key => '$section|$gauge|$color';

  /// The stock, for showing beside the name. Empty on a review from before
  /// stock was per-window, so nothing gains a stray separator.
  String get materialLabel {
    final List<String> bits = <String>[
      if (gauge.trim().isNotEmpty) gauge.trim(),
      if (color.trim().isNotEmpty) color.trim(),
    ];
    return bits.join(' · ');
  }

  factory RateReviewRow.fromJson(Map<String, dynamic> json) {
    final double totalFt = (json['totalFt'] as num?)?.toDouble() ?? 0;
    return RateReviewRow(
      section: json['section'] as String? ?? '',
      gauge: json['gauge'] as String? ?? '',
      color: json['color'] as String? ?? '',
      totalFt: totalFt,
      totalFtDisplay: json['totalFtDisplay'] as String? ?? '$totalFt ft',
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
    final List<dynamic> rowItems = rawRows is List<dynamic>
        ? rawRows
        : const <dynamic>[];

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
