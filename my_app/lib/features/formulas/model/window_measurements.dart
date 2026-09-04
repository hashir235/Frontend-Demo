/// Turning what a fabricator typed into the numbers a formula works in.
library;

/// How a window's measurements reach a formula.
///
/// A fabricator types "72.4" and means seventy-two inches and four suter, or
/// seven feet four inches, or seventy-two point four centimetres, depending on
/// which unit the screen is in. The engine has always decoded that on the
/// server; the app has to decode it the same way, to the last digit, or a
/// formula worked out here and the same formula worked out there would give
/// two different lengths for one window.
///
/// This is that decoding, written against the engine's own
/// parseEncodedMeasure and parseFabricationMeasure, and held against them by
/// the parity harness on real projects.
class WindowMeasurements {
  const WindowMeasurements._(this.values);

  /// The measurements in the names formulas use: h, w, wl, wr, ar.
  ///
  /// In centimetres for fabrication and feet for estimation, because that is
  /// what each side's formulas are written in.
  final Map<String, double> values;

  /// Why the measurements could not be read, if they could not.
  static String? _problem;

  /// Reads one window's measurements.
  ///
  /// Returns null when a dimension cannot be read at all -- an empty height, a
  /// suter of 9, a value with two decimal points. The engine refuses those and
  /// so must this: a window that cannot be measured has no cut list, and
  /// guessing at one is the worst possible answer.
  static WindowMeasurements? read({
    required bool isFabrication,
    required String unitMode,
    required String heightValue,
    required String widthValue,
    String? leftWidthValue,
    String? rightWidthValue,
    String? archValue,
  }) {
    _problem = null;
    final double? h = _one(isFabrication, unitMode, heightValue);
    final double? w = _one(isFabrication, unitMode, widthValue);
    if (h == null || w == null) return null;

    // The corner windows carry a left and a right; everything else reads both
    // from the single width, exactly as the engine does when they are blank.
    final double? wl = _oneOr(isFabrication, unitMode, leftWidthValue, w);
    final double? wr = _oneOr(isFabrication, unitMode, rightWidthValue, w);
    if (wl == null || wr == null) return null;

    // Only the round arch has one, and a blank from the rectangle is expected
    // rather than a mistake.
    final double ar = _oneOr(isFabrication, unitMode, archValue, 0) ?? 0;

    return WindowMeasurements._(<String, double>{
      'h': h,
      'w': w,
      'wl': wl,
      'wr': wr,
      'ar': ar,
    });
  }

  /// What went wrong with the last read that returned null.
  static String? get lastProblem => _problem;

  static double? _oneOr(bool isFabrication, String unitMode, String? raw, double fallback) {
    if (raw == null || raw.trim().isEmpty) return fallback;
    return _one(isFabrication, unitMode, raw);
  }

  static double? _one(bool isFabrication, String unitMode, String raw) {
    return isFabrication
        ? _fabricationCm(unitMode, raw)
        : _estimationFeet(unitMode, raw);
  }

  /// Fabrication works in centimetres.
  ///
  /// "cm" and "feet" both arrive already in centimetres -- the app converts
  /// before sending, and the engine treats them the same. Inches arrive as
  /// inch.suter and are converted here.
  static double? _fabricationCm(String unitMode, String raw) {
    final String mode = unitMode.trim().toLowerCase();
    final String value = raw.trim();
    if (value.isEmpty) {
      _problem = 'a dimension is missing';
      return null;
    }

    if (mode == 'cm' || mode == 'feet') {
      final double? cm = double.tryParse(value);
      if (cm == null || cm <= 0) {
        _problem = '"$value" is not a measurement';
        return null;
      }
      return cm;
    }

    if (mode != 'inches') {
      _problem = 'unit must be cm or inches';
      return null;
    }

    final _InchSuter? parsed = _InchSuter.read(value);
    if (parsed == null) return null;
    if (parsed.whole <= 0) {
      _problem = 'inches must be more than zero';
      return null;
    }
    return (parsed.whole + parsed.suter / 8.0) * 2.54;
  }

  /// Estimation works in feet.
  ///
  /// Inches arrive as inch.suter and are divided by twelve; feet arrive as
  /// feet.inches. Centimetres never reach here -- the app encodes them as
  /// inch.suter before sending, because the estimation engine has no
  /// centimetre mode at all.
  static double? _estimationFeet(String unitMode, String raw) {
    final String mode = unitMode.trim().toLowerCase();
    final String value = raw.trim();
    if (value.isEmpty) {
      _problem = 'a dimension is missing';
      return null;
    }

    final _InchSuter? parsed = _InchSuter.read(value);
    if (parsed == null) return null;

    if (mode == 'inches') {
      if (parsed.suter < 0 || parsed.suter >= 8) {
        _problem = 'suter must be 0 to 7';
        return null;
      }
      return (parsed.whole + parsed.suter / 8.0) / 12.0;
    }

    if (mode == 'feet') {
      // Here the part after the point is whole inches, not suter.
      final int inches = parsed.rightAsInt;
      if (inches < 0 || inches >= 12) {
        _problem = 'inches must be 0 to 11';
        return null;
      }
      return parsed.whole + inches / 12.0;
    }

    _problem = 'unit must be inches or feet';
    return null;
  }
}

/// A measurement written as a whole number and a fraction after the point.
///
/// The fraction is read two ways depending on the unit -- as suter eighths, or
/// as whole inches -- so this keeps both and lets the caller decide. "45.4" is
/// four suter; "45.45" is four and a half. One digit or two, never more.
class _InchSuter {
  const _InchSuter(this.whole, this.suter, this.rightAsInt);

  final int whole;
  final double suter;
  final int rightAsInt;

  static _InchSuter? read(String value) {
    final int dot = value.indexOf('.');
    if (dot != value.lastIndexOf('.')) {
      WindowMeasurements._problem = '"$value" has two decimal points';
      return null;
    }

    final String wholeText = dot < 0 ? value : value.substring(0, dot);
    final String fraction = dot < 0 ? '' : value.substring(dot + 1);

    final int? whole = int.tryParse(wholeText);
    if (whole == null) {
      WindowMeasurements._problem = '"$value" is not a measurement';
      return null;
    }

    if (fraction.isEmpty) return _InchSuter(whole, 0, 0);
    if (fraction.length > 2 || int.tryParse(fraction) == null) {
      WindowMeasurements._problem = '"$value" has too much after the point';
      return null;
    }

    final double suter = fraction.length == 1
        ? double.parse(fraction)
        : double.parse(fraction[0]) + double.parse(fraction[1]) / 10.0;

    return _InchSuter(whole, suter, int.parse(fraction));
  }
}
