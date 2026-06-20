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

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'ok': ok,
      'errors': errors,
      'projectName': projectName,
      'projectLocation': projectLocation,
      'rows': rows.map((GlassReportRow row) => row.toJson()).toList(),
    };
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

  /// Builds a row from edited/manual inputs. Width and height are supplied as
  /// [GlassDimension] (inch + sutter) and converted to both display + cm so the
  /// row is ready for the optimizer and the PDF scripts.
  factory GlassReportRow.fromInputs({
    required GlassDimension width,
    required GlassDimension height,
    String windowName = '',
    int windowNo = 0,
    String inputSize = '',
    String rubberType = '',
    int quantity = 1,
  }) {
    return GlassReportRow(
      windowName: windowName,
      windowNo: windowNo,
      inputSize: inputSize,
      rubberType: rubberType,
      quantity: quantity < 1 ? 1 : quantity,
      widthCm: width.cm,
      heightCm: height.cm,
      widthDisplay: width.display,
      heightDisplay: height.display,
    );
  }

  GlassReportRow copyWith({
    String? windowName,
    int? windowNo,
    String? inputSize,
    String? rubberType,
    int? quantity,
    double? heightCm,
    double? widthCm,
    String? heightDisplay,
    String? widthDisplay,
  }) {
    return GlassReportRow(
      windowName: windowName ?? this.windowName,
      windowNo: windowNo ?? this.windowNo,
      inputSize: inputSize ?? this.inputSize,
      rubberType: rubberType ?? this.rubberType,
      quantity: quantity ?? this.quantity,
      heightCm: heightCm ?? this.heightCm,
      widthCm: widthCm ?? this.widthCm,
      heightDisplay: heightDisplay ?? this.heightDisplay,
      widthDisplay: widthDisplay ?? this.widthDisplay,
    );
  }

  /// Width parsed back into editable inch + sutter form.
  GlassDimension get widthDimension =>
      GlassDimension.fromRow(display: widthDisplay, cm: widthCm);

  /// Height parsed back into editable inch + sutter form.
  GlassDimension get heightDimension =>
      GlassDimension.fromRow(display: heightDisplay, cm: heightCm);

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'windowName': windowName,
      'windowNo': windowNo,
      'inputSize': inputSize,
      'rubberType': rubberType,
      'quantity': quantity,
      'heightCm': heightCm,
      'widthCm': widthCm,
      'heightDisplay': heightDisplay,
      'widthDisplay': widthDisplay,
    };
  }
}

/// A single glass edge length expressed in the shop convention:
/// whole [inches] plus [sutter] eighths (1 inch = 8 sutter). Half-sutter is
/// supported, so [sutter] may carry a .5 (e.g. 3.5 sutter = 7/16 inch).
class GlassDimension {
  final int inches;
  final double sutter;

  const GlassDimension({required this.inches, required this.sutter});

  static const double _inchPerCm = 1 / 2.54;

  /// Total length in decimal inches.
  double get decimalInches => inches + sutter / 8.0;

  /// Length in centimetres (what the optimizer/PDF keep as a numeric backup).
  double get cm => decimalInches * 2.54;

  /// Shop display string, e.g. `45'' 3'''` or `45'' 0'''`.
  String get display {
    final String sutterStr = sutter == sutter.roundToDouble()
        ? sutter.toInt().toString()
        : sutter.toStringAsFixed(1);
    return "$inches'' $sutterStr'''";
  }

  bool get isPositive => decimalInches > 0;

  /// Parses an existing row's display string (preferred) or cm value back into
  /// editable inch + sutter. The display's first number is inches, the second
  /// is sutter eighths.
  factory GlassDimension.fromRow({required String display, required double cm}) {
    final String trimmed = display.trim();
    if (trimmed.isNotEmpty) {
      final Iterable<Match> matches =
          RegExp(r'-?\d+(?:\.\d+)?').allMatches(trimmed);
      final List<double> numbers = matches
          .map((Match m) => double.tryParse(m.group(0) ?? '') ?? 0)
          .toList(growable: false);
      if (numbers.isNotEmpty) {
        final int inches = numbers[0].toInt();
        final double sutter = numbers.length > 1 ? numbers[1] : 0;
        return GlassDimension(inches: inches, sutter: _snapSutter(sutter));
      }
    }
    return GlassDimension.fromDecimalInches(cm * _inchPerCm);
  }

  /// Snaps any decimal-inch value to the nearest half-sutter.
  factory GlassDimension.fromDecimalInches(double decimalInches) {
    final double safe =
        decimalInches.isFinite && decimalInches > 0 ? decimalInches : 0;
    int inches = safe.floor();
    double sutter = _snapSutter((safe - inches) * 8.0);
    if (sutter >= 8) {
      inches += 1;
      sutter = 0;
    }
    return GlassDimension(inches: inches, sutter: sutter);
  }

  /// Rounds a sutter value to the nearest 0.5 within the 0..7.5 range.
  static double _snapSutter(double value) {
    if (!value.isFinite || value <= 0) {
      return 0;
    }
    final double snapped = (value * 2).round() / 2;
    if (snapped > 7.5) {
      return 7.5;
    }
    return snapped;
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
