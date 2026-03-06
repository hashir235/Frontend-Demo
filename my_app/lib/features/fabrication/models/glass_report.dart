class GlassReport {
  final bool ok;
  final List<String> errors;
  final String projectName;
  final String projectLocation;
  final List<GlassReportRow> rows;

  const GlassReport({
    required this.ok,
    required this.errors,
    required this.projectName,
    required this.projectLocation,
    required this.rows,
  });

  factory GlassReport.fromJson(Map<String, dynamic> json) {
    return GlassReport(
      ok: json['ok'] == true,
      errors: ((json['errors'] as List<dynamic>?) ?? const <dynamic>[])
          .map((dynamic item) => item.toString())
          .toList(growable: false),
      projectName: (json['projectName'] as String?) ?? '',
      projectLocation: (json['projectLocation'] as String?) ?? '',
      rows: ((json['rows'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(GlassReportRow.fromJson)
          .toList(growable: false),
    );
  }
}

class GlassReportRow {
  final String windowName;
  final int windowNo;
  final String inputSize;
  final String rubberType;
  final int quantity;
  final double heightCm;
  final double widthCm;
  final String heightDisplay;
  final String widthDisplay;

  const GlassReportRow({
    required this.windowName,
    required this.windowNo,
    required this.inputSize,
    required this.rubberType,
    required this.quantity,
    required this.heightCm,
    required this.widthCm,
    required this.heightDisplay,
    required this.widthDisplay,
  });

  factory GlassReportRow.fromJson(Map<String, dynamic> json) {
    return GlassReportRow(
      windowName: (json['windowName'] as String?) ?? '',
      windowNo: _toInt(json['windowNo']),
      inputSize: (json['inputSize'] as String?) ?? '',
      rubberType: (json['rubberType'] as String?) ?? '',
      quantity: _toInt(json['quantity']),
      heightCm: _toDouble(json['heightCm']),
      widthCm: _toDouble(json['widthCm']),
      heightDisplay: (json['heightDisplay'] as String?) ?? '',
      widthDisplay: (json['widthDisplay'] as String?) ?? '',
    );
  }
}

double _toDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return 0.0;
}

int _toInt(dynamic value) {
  if (value is num) {
    return value.toInt();
  }
  return 0;
}
