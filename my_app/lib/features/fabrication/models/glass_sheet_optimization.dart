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

  /// Every placed piece at the market standard -- what the shop charges its
  /// customer for, beside the tape's own total in [GlassSheetSummary.usedArea].
  double get marketUsedArea => sheets.fold<double>(
    0,
    (double sum, GlassSheetLayout sheet) => sum + sheet.marketUsedArea,
  );
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

  /// The glass this whole sheet is cut from.
  ///
  /// A sheet only ever holds one: the optimizer packs each colour separately,
  /// because a sheet in the rack is one colour and a layout mixing two cannot
  /// be cut from anything. Empty for a job whose rows carried no colour.
  final String glassColor;

  /// The real sheet, as opposed to [width]/[height] which include whatever
  /// extra margin the layout was allowed to reach into.
  final double nominalWidth;
  final double nominalHeight;

  /// Whether this sheet actually reaches past the real glass.
  ///
  /// True only when a piece genuinely sits beyond the edge — allowing a margin
  /// does not by itself flag anything, because most sheets in a job will not
  /// need it and a warning on those would train people to ignore the warning.
  final bool usesExtraMargin;

  /// Exactly how far past, so the cutter knows what to shave.
  final double marginOverWidth;
  final double marginOverHeight;
  final String marginOverWidthDisplay;
  final String marginOverHeightDisplay;

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
    this.glassColor = '',
    this.nominalWidth = 0,
    this.nominalHeight = 0,
    this.usesExtraMargin = false,
    this.marginOverWidth = 0,
    this.marginOverHeight = 0,
    this.marginOverWidthDisplay = '',
    this.marginOverHeightDisplay = '',
  });

  /// This sheet's pieces at the market standard.
  double get marketUsedArea => placements.fold<double>(
    0,
    (double sum, GlassSheetPlacement piece) => sum + piece.marketArea,
  );

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
      wasteRects: ((json['wasteRects'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(GlassSheetWasteRect.fromJson)
          .toList(growable: false),
      glassColor: ((json['glassColor'] as String?) ?? '').trim(),
      // Falls back to the laid-out size for a reply from a server that predates
      // the margin, so an older backend simply reports no overshoot.
      nominalWidth: json['nominalWidth'] == null
          ? _toDouble(json['width'])
          : _toDouble(json['nominalWidth']),
      nominalHeight: json['nominalHeight'] == null
          ? _toDouble(json['height'])
          : _toDouble(json['nominalHeight']),
      usesExtraMargin: json['usesExtraMargin'] == true,
      marginOverWidth: _toDouble(json['marginOverWidth']),
      marginOverHeight: _toDouble(json['marginOverHeight']),
      marginOverWidthDisplay:
          (json['marginOverWidthDisplay'] as String?) ?? '',
      marginOverHeightDisplay:
          (json['marginOverHeightDisplay'] as String?) ?? '',
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

  /// The piece's own width and height, in the order its size is written,
  /// whichever way round it was laid on the sheet.
  double get pieceWidth => rotated ? height : width;
  double get pieceHeight => rotated ? width : height;

  /// The piece as the tape measures it: its real width times its height.
  double get mathArea => width * height;

  /// The piece as a glass shop charges for it: each side taken up to the
  /// market step (see [marketSideInches]), then multiplied.
  double get marketWidth => marketSideInches(pieceWidth);
  double get marketHeight => marketSideInches(pieceHeight);
  double get marketArea => marketWidth * marketHeight;

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

/// One side of a glass piece as the market charges for it, in inches.
///
/// Glass is bought by the tape's size but sold by the market's: each side is
/// taken up to the next 3 inches -- 3, 6, 9 ... 24 -- and past 24 inches to
/// the next 6 -- 30, 36, 42, 48 ... A side exactly on a step stays where it
/// is (15 is 15); anything over it, even half a suter, takes the next step
/// (15 and a half suter is 18). Kept in step with `market_side` in the
/// server's GlassSheetOptimizationPDF.py, so the page and the screen agree.
double marketSideInches(double inches) {
  if (!inches.isFinite || inches <= 0) return 0;
  // A hair's allowance -- a millionth of an inch, far under half a suter --
  // so a side that is exactly on a step but arrived through a cm conversion
  // (15.000000000000002) stays on it.
  const double hair = 1e-6;
  if (inches <= 24 + hair) {
    final double steps = ((inches - hair) / 3).ceilToDouble();
    return (steps < 1 ? 1 : steps) * 3;
  }
  return 24 + ((inches - 24 - hair) / 6).ceilToDouble() * 6;
}

/// A market side as it is written: 15'' rather than 15.0.
String formatMarketSide(double inches) => "${_trim(inches, 1)}''";

/// An area of glass in both units a shop uses for it.
///
/// Cut by the inch, bought and priced by the foot. Square inches alone left
/// the fabricator dividing by 144 to tell a customer how much glass a job
/// used, or how much of what he paid for went in the bin.
String formatArea(double value) =>
    '${_trim(value, 1)} sq in  ·  ${formatSqFt(value)} sq ft';

/// The same area on two lines, for a tile too narrow to hold it on one.
String formatAreaLines(double value) =>
    '${_trim(value, 1)} sq in\n${formatSqFt(value)} sq ft';

/// Square inches as square feet, the number alone.
String formatSqFt(double squareInches) => _trim(squareInches / 144, 2);

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
