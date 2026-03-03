class CuttingReport {
  final bool ok;
  final String context;
  final String displayUnit;
  final List<String> errors;
  final List<CuttingReportSection> sections;

  const CuttingReport({
    required this.ok,
    required this.context,
    required this.displayUnit,
    required this.errors,
    required this.sections,
  });

  factory CuttingReport.fromJson(Map<String, dynamic> json) {
    return CuttingReport(
      ok: json['ok'] == true,
      context: (json['context'] as String?) ?? '',
      displayUnit: (json['displayUnit'] as String?) ?? '',
      errors: ((json['errors'] as List<dynamic>?) ?? const <dynamic>[])
          .map((dynamic item) => item.toString())
          .toList(growable: false),
      sections: ((json['sections'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(CuttingReportSection.fromJson)
          .toList(growable: false),
    );
  }
}

class CuttingReportSection {
  final String name;
  final CuttingReportSummary? summary;
  final List<CuttingReportGroup> groups;

  const CuttingReportSection({
    required this.name,
    required this.summary,
    required this.groups,
  });

  factory CuttingReportSection.fromJson(Map<String, dynamic> json) {
    return CuttingReportSection(
      name: (json['name'] as String?) ?? '',
      summary: json['summary'] is Map<String, dynamic>
          ? CuttingReportSummary.fromJson(json['summary'] as Map<String, dynamic>)
          : null,
      groups: ((json['groups'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(CuttingReportGroup.fromJson)
          .toList(growable: false),
    );
  }
}

class CuttingReportSummary {
  final List<double> usedLengths;
  final List<String> usedLengthsDisplay;
  final double totalLength;
  final String totalLengthDisplay;

  const CuttingReportSummary({
    required this.usedLengths,
    required this.usedLengthsDisplay,
    required this.totalLength,
    required this.totalLengthDisplay,
  });

  factory CuttingReportSummary.fromJson(Map<String, dynamic> json) {
    return CuttingReportSummary(
      usedLengths: ((json['usedLengths'] as List<dynamic>?) ?? const <dynamic>[])
          .map(_toDouble)
          .toList(growable: false),
      usedLengthsDisplay:
          ((json['usedLengthsDisplay'] as List<dynamic>?) ?? const <dynamic>[])
              .map((dynamic item) => item.toString())
              .toList(growable: false),
      totalLength: _toDouble(json['totalLength']),
      totalLengthDisplay: (json['totalLengthDisplay'] as String?) ?? '',
    );
  }
}

class CuttingReportGroup {
  final double stockLenFt;
  final String stockLenDisplay;
  final double wastageFt;
  final String wastageDisplay;
  final bool offcut;
  final List<CuttingReportCut> cuts;

  const CuttingReportGroup({
    required this.stockLenFt,
    required this.stockLenDisplay,
    required this.wastageFt,
    required this.wastageDisplay,
    required this.offcut,
    required this.cuts,
  });

  factory CuttingReportGroup.fromJson(Map<String, dynamic> json) {
    return CuttingReportGroup(
      stockLenFt: _toDouble(json['stockLenFt']),
      stockLenDisplay: (json['stockLenDisplay'] as String?) ?? '',
      wastageFt: _toDouble(json['wastageFt']),
      wastageDisplay: (json['wastageDisplay'] as String?) ?? '',
      offcut: json['offcut'] == true,
      cuts: ((json['cuts'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(CuttingReportCut.fromJson)
          .toList(growable: false),
    );
  }
}

class CuttingReportCut {
  final String label;
  final String windowName;
  final int windowNo;
  final String dimension;
  final double lengthFt;
  final String lengthDisplay;

  const CuttingReportCut({
    required this.label,
    required this.windowName,
    required this.windowNo,
    required this.dimension,
    required this.lengthFt,
    required this.lengthDisplay,
  });

  factory CuttingReportCut.fromJson(Map<String, dynamic> json) {
    return CuttingReportCut(
      label: (json['label'] as String?) ?? '',
      windowName: (json['windowName'] as String?) ?? '',
      windowNo: _toInt(json['windowNo']),
      dimension: (json['dimension'] as String?) ?? '',
      lengthFt: _toDouble(json['lengthFt']),
      lengthDisplay: (json['lengthDisplay'] as String?) ?? '',
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
