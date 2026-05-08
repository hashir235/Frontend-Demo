import 'glass_report.dart';

class GlassSheetOptimizationResult {
  final bool ok;
  final List<String> errors;
  final String projectName;
  final String projectLocation;
  final GlassSheetSpec sheet;
  final GlassSheetSummary summary;
  final List<GlassReportRow> sourceRows;
  final List<GlassSheetPiece> rejectedPieces;
  final List<GlassSheetLayout> sheets;

  const GlassSheetOptimizationResult({
    required this.ok,
    required this.errors,
    required this.projectName,
    required this.projectLocation,
    required this.sheet,
    required this.summary,
    required this.sourceRows,
    required this.rejectedPieces,
    required this.sheets,
  });

  factory GlassSheetOptimizationResult.fromJson(Map<String, dynamic> json) {
    return GlassSheetOptimizationResult(
      ok: json['ok'] == true,
      errors: ((json['errors'] as List<dynamic>?) ?? const <dynamic>[])
          .map((dynamic item) => item.toString())
          .toList(growable: false),
      projectName: (json['projectName'] as String?) ?? '',
      projectLocation: (json['projectLocation'] as String?) ?? '',
      sheet: GlassSheetSpec.fromJson(
        (json['sheet'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
      summary: GlassSheetSummary.fromJson(
        (json['summary'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
      sourceRows: ((json['sourceRows'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(GlassReportRow.fromJson)
          .toList(growable: false),
      rejectedPieces:
          ((json['rejectedPieces'] as List<dynamic>?) ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(GlassSheetPiece.fromJson)
              .toList(growable: false),
      sheets: ((json['sheets'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(GlassSheetLayout.fromJson)
          .toList(growable: false),
    );
  }
}

class GlassSheetSpec {
  final double width;
  final double height;
  final String widthDisplay;
  final String heightDisplay;
  final bool allowRotation;

  const GlassSheetSpec({
    required this.width,
    required this.height,
    required this.widthDisplay,
    required this.heightDisplay,
    required this.allowRotation,
  });

  factory GlassSheetSpec.fromJson(Map<String, dynamic> json) {
    return GlassSheetSpec(
      width: _toDouble(json['width']),
      height: _toDouble(json['height']),
      widthDisplay: (json['widthDisplay'] as String?) ?? '',
      heightDisplay: (json['heightDisplay'] as String?) ?? '',
      allowRotation: json['allowRotation'] != false,
    );
  }
}

class GlassSheetSummary {
  final int totalSheets;
  final int totalPieces;
  final int placedPieces;
  final int rejectedPieces;
  final double usedArea;
  final double wasteArea;
  final double totalArea;
  final double wastagePercentage;

  const GlassSheetSummary({
    required this.totalSheets,
    required this.totalPieces,
    required this.placedPieces,
    required this.rejectedPieces,
    required this.usedArea,
    required this.wasteArea,
    required this.totalArea,
    required this.wastagePercentage,
  });

  factory GlassSheetSummary.fromJson(Map<String, dynamic> json) {
    return GlassSheetSummary(
      totalSheets: _toInt(json['totalSheets']),
      totalPieces: _toInt(json['totalPieces']),
      placedPieces: _toInt(json['placedPieces']),
      rejectedPieces: _toInt(json['rejectedPieces']),
      usedArea: _toDouble(json['usedArea']),
      wasteArea: _toDouble(json['wasteArea']),
      totalArea: _toDouble(json['totalArea']),
      wastagePercentage: _toDouble(json['wastagePercentage']),
    );
  }
}

class GlassSheetLayout {
  final int sheetNo;
  final double width;
  final double height;
  final String widthDisplay;
  final String heightDisplay;
  final double usedArea;
  final double wasteArea;
  final double wastagePercentage;
  final List<GlassSheetPlacement> placements;
  final List<GlassSheetWasteRect> wasteRects;

  const GlassSheetLayout({
    required this.sheetNo,
    required this.width,
    required this.height,
    required this.widthDisplay,
    required this.heightDisplay,
    required this.usedArea,
    required this.wasteArea,
    required this.wastagePercentage,
    required this.placements,
    required this.wasteRects,
  });

  factory GlassSheetLayout.fromJson(Map<String, dynamic> json) {
    return GlassSheetLayout(
      sheetNo: _toInt(json['sheetNo']),
      width: _toDouble(json['width']),
      height: _toDouble(json['height']),
      widthDisplay: (json['widthDisplay'] as String?) ?? '',
      heightDisplay: (json['heightDisplay'] as String?) ?? '',
      usedArea: _toDouble(json['usedArea']),
      wasteArea: _toDouble(json['wasteArea']),
      wastagePercentage: _toDouble(json['wastagePercentage']),
      placements: ((json['placements'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(GlassSheetPlacement.fromJson)
          .toList(growable: false),
      wasteRects:
          ((json['wasteRects'] as List<dynamic>?) ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(GlassSheetWasteRect.fromJson)
              .toList(growable: false),
    );
  }
}

class GlassSheetPiece {
  final String id;
  final String label;
  final String reason;

  const GlassSheetPiece({
    required this.id,
    required this.label,
    required this.reason,
  });

  factory GlassSheetPiece.fromJson(Map<String, dynamic> json) {
    return GlassSheetPiece(
      id: (json['id'] as String?) ?? '',
      label: (json['label'] as String?) ?? '',
      reason: (json['reason'] as String?) ?? '',
    );
  }
}

class GlassSheetPlacement {
  final String id;
  final String label;
  final int pieceNo;
  final double x;
  final double y;
  final double width;
  final double height;
  final String glassSizeDisplay;
  final bool rotated;

  const GlassSheetPlacement({
    required this.id,
    required this.label,
    required this.pieceNo,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.glassSizeDisplay,
    required this.rotated,
  });

  factory GlassSheetPlacement.fromJson(Map<String, dynamic> json) {
    return GlassSheetPlacement(
      id: (json['id'] as String?) ?? '',
      label: (json['label'] as String?) ?? '',
      pieceNo: _toInt(json['pieceNo']),
      x: _toDouble(json['x']),
      y: _toDouble(json['y']),
      width: _toDouble(json['width']),
      height: _toDouble(json['height']),
      glassSizeDisplay: (json['glassSizeDisplay'] as String?) ?? '',
      rotated: json['rotated'] == true,
    );
  }
}

class GlassSheetWasteRect {
  final String id;
  final int wasteNo;
  final double x;
  final double y;
  final double width;
  final double height;
  final double area;
  final String sizeDisplay;

  const GlassSheetWasteRect({
    required this.id,
    required this.wasteNo,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.area,
    required this.sizeDisplay,
  });

  factory GlassSheetWasteRect.fromJson(Map<String, dynamic> json) {
    return GlassSheetWasteRect(
      id: (json['id'] as String?) ?? '',
      wasteNo: _toInt(json['wasteNo']),
      x: _toDouble(json['x']),
      y: _toDouble(json['y']),
      width: _toDouble(json['width']),
      height: _toDouble(json['height']),
      area: _toDouble(json['area']),
      sizeDisplay: (json['sizeDisplay'] as String?) ?? '',
    );
  }
}

String formatArea(double value) => '${_trim(value, 1)} sq in';

String formatPercent(double value) => '${_trim(value, 1)}%';

String _trim(double value, int digits) {
  String text = value.toStringAsFixed(digits);
  while (text.contains('.') && text.endsWith('0')) {
    text = text.substring(0, text.length - 1);
  }
  if (text.endsWith('.')) {
    text = text.substring(0, text.length - 1);
  }
  return text;
}

double _toDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return 0;
}

int _toInt(dynamic value) {
  if (value is num) {
    return value.toInt();
  }
  return 0;
}
