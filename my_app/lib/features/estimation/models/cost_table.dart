class RateOverrideInput {
  final String section;

  /// The stock this override is for. Without it, correcting what M23 costs in
  /// 2mm would also reprice the 1.2mm M23 in the same job -- the engine keys
  /// its rates on all three.
  final String gauge;
  final String color;

  final double rate;

  const RateOverrideInput({
    required this.section,
    this.gauge = '',
    this.color = '',
    required this.rate,
  });

  String get key => '$section|$gauge|$color';

  Map<String, Object> toJson() {
    return <String, Object>{
      'section': section,
      'gauge': gauge,
      'color': color,
      'rate': rate,
    };
  }
}

class CostTableLength {
  final double lengthFt;
  final String lengthDisplay;
  final int quantity;

  const CostTableLength({
    required this.lengthFt,
    required this.lengthDisplay,
    required this.quantity,
  });

  factory CostTableLength.fromJson(Map<String, dynamic> json) {
    final double lengthFt = (json['lengthFt'] as num?)?.toDouble() ?? 0;
    return CostTableLength(
      lengthFt: lengthFt,
      lengthDisplay: json['lengthDisplay'] as String? ?? '$lengthFt ft',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
    );
  }
}

class CostTableRow {
  final String section;

  /// Which aluminium this row is priced for. The same profile can appear twice
  /// in one job -- once per gauge or colour -- at two different rates, so the
  /// row has to say which one it is or the two are indistinguishable.
  ///
  /// Empty on a job costed before this was per-window; those rows carry the
  /// pair the whole job was priced at, held on [CostTable] itself.
  final String gauge;
  final String color;

  final double totalFt;
  final String totalFtDisplay;
  final double rate;
  final double totalPrice;
  final List<CostTableLength> lengths;

  const CostTableRow({
    required this.section,
    this.gauge = '',
    this.color = '',
    required this.totalFt,
    required this.totalFtDisplay,
    required this.rate,
    required this.totalPrice,
    required this.lengths,
  });

  factory CostTableRow.fromJson(Map<String, dynamic> json) {
    final Object? rawLengths = json['lengths'];
    final List<dynamic> lengthItems = rawLengths is List<dynamic>
        ? rawLengths
        : const <dynamic>[];
    final double totalFt = (json['totalFt'] as num?)?.toDouble() ?? 0;

    return CostTableRow(
      section: json['section'] as String? ?? '',
      gauge: json['gauge'] as String? ?? '',
      color: json['color'] as String? ?? '',
      totalFt: totalFt,
      totalFtDisplay: json['totalFtDisplay'] as String? ?? '$totalFt ft',
      rate: (json['rate'] as num?)?.toDouble() ?? 0,
      totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0,
      lengths: lengthItems
          .whereType<Map<String, dynamic>>()
          .map(CostTableLength.fromJson)
          .toList(),
    );
  }
}

/// How much glazing of one glass this job comes to.
///
/// Worked out by the engine, not here: the bill charges these feet, and a
/// second opinion about what a window measures would eventually differ from
/// the one being charged.
class GlassAreaSummary {
  final String color;
  final double areaSqFt;
  final int windows;

  const GlassAreaSummary({
    required this.color,
    required this.areaSqFt,
    required this.windows,
  });

  /// Windows entered before glass was a per-window choice carry no name.
  bool get isUnnamed => color.trim().isEmpty;

  factory GlassAreaSummary.fromJson(Map<String, dynamic> json) {
    return GlassAreaSummary(
      color: (json['color'] as String? ?? '').trim(),
      areaSqFt: (json['areaSqFt'] as num?)?.toDouble() ?? 0,
      windows: (json['windows'] as num?)?.toInt() ?? 0,
    );
  }
}

class CostTable {
  final bool ok;
  final List<String> errors;
  final String context;
  final String gauge;
  final String color;
  final double grandTotal;
  final List<CostTableRow> rows;

  /// The glazing this job needs, per glass. Empty for a fabrication run, and
  /// for anything answered by a server that predates it.
  final List<GlassAreaSummary> glassAreas;

  const CostTable({
    required this.ok,
    required this.errors,
    required this.context,
    required this.gauge,
    required this.color,
    required this.grandTotal,
    required this.rows,
    this.glassAreas = const <GlassAreaSummary>[],
  });

  factory CostTable.fromJson(Map<String, dynamic> json) {
    final Object? rawRows = json['rows'];
    final List<dynamic> rowItems = rawRows is List<dynamic>
        ? rawRows
        : const <dynamic>[];

    return CostTable(
      ok: json['ok'] as bool? ?? false,
      errors: (json['errors'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic item) => item.toString())
          .toList(),
      context: json['context'] as String? ?? '',
      gauge: json['gauge'] as String? ?? '',
      color: json['color'] as String? ?? '',
      grandTotal: (json['grandTotal'] as num?)?.toDouble() ?? 0,
      rows: rowItems
          .whereType<Map<String, dynamic>>()
          .map(CostTableRow.fromJson)
          .toList(),
      glassAreas: (json['glassAreas'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(GlassAreaSummary.fromJson)
          .toList(),
    );
  }
}
