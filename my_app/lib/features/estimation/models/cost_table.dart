class RateOverrideInput {
  final String section;
  final double rate;

  const RateOverrideInput({
    required this.section,
    required this.rate,
  });

  Map<String, Object> toJson() {
    return <String, Object>{
      'section': section,
      'rate': rate,
    };
  }
}

class CostTableLength {
  final double lengthFt;
  final int quantity;

  const CostTableLength({
    required this.lengthFt,
    required this.quantity,
  });

  factory CostTableLength.fromJson(Map<String, dynamic> json) {
    return CostTableLength(
      lengthFt: (json['lengthFt'] as num?)?.toDouble() ?? 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
    );
  }
}

class CostTableRow {
  final String section;
  final double totalFt;
  final double rate;
  final double totalPrice;
  final List<CostTableLength> lengths;

  const CostTableRow({
    required this.section,
    required this.totalFt,
    required this.rate,
    required this.totalPrice,
    required this.lengths,
  });

  factory CostTableRow.fromJson(Map<String, dynamic> json) {
    final Object? rawLengths = json['lengths'];
    final List<dynamic> lengthItems =
        rawLengths is List<dynamic> ? rawLengths : const <dynamic>[];

    return CostTableRow(
      section: json['section'] as String? ?? '',
      totalFt: (json['totalFt'] as num?)?.toDouble() ?? 0,
      rate: (json['rate'] as num?)?.toDouble() ?? 0,
      totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0,
      lengths: lengthItems
          .whereType<Map<String, dynamic>>()
          .map(CostTableLength.fromJson)
          .toList(),
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

  const CostTable({
    required this.ok,
    required this.errors,
    required this.context,
    required this.gauge,
    required this.color,
    required this.grandTotal,
    required this.rows,
  });

  factory CostTable.fromJson(Map<String, dynamic> json) {
    final Object? rawRows = json['rows'];
    final List<dynamic> rowItems = rawRows is List<dynamic> ? rawRows : const <dynamic>[];

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
    );
  }
}
