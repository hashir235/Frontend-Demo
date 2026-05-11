/// Represents a length in the Pakistani fabrication convention:
/// whole inches plus "sutar" eighths (1 inch = 8 sutar).
class InchSutar {
  /// Whole inches part (e.g. 48).
  final int inches;

  /// Sutar part, 0..7 (1 sutar = 1/8 inch).
  final int sutar;

  const InchSutar({required this.inches, required this.sutar});

  /// Decimal inches representation, e.g. 48 inch 3 sutar -> 48.375.
  double get decimalInches => inches + sutar / 8.0;

  /// Storage string used by the estimation flow: "inch.sutar" (e.g. "48.3").
  /// Suter > 7 is impossible because we always normalise on construction.
  String get storageFormat {
    if (sutar == 0) {
      return '$inches.0';
    }
    return '$inches.$sutar';
  }

  /// Human-friendly label such as "48 in 3 sutar".
  String get displayLabel {
    if (sutar == 0) return '$inches in';
    return '$inches in $sutar sutar';
  }

  /// Converts a raw decimal-inch measurement into the nearest inch+sutar pair,
  /// snapping to the nearest 1/8 inch.
  factory InchSutar.fromDecimalInches(double decimalInches) {
    if (decimalInches.isNaN || decimalInches.isInfinite || decimalInches < 0) {
      return const InchSutar(inches: 0, sutar: 0);
    }
    final int totalSutar = (decimalInches * 8.0).round();
    final int inches = totalSutar ~/ 8;
    final int sutar = totalSutar % 8;
    return InchSutar(inches: inches, sutar: sutar);
  }

  /// Converts a raw metre measurement (the unit ARCore returns) into inch+sutar.
  factory InchSutar.fromMeters(double meters) {
    const double inchPerMeter = 39.37007874015748;
    return InchSutar.fromDecimalInches(meters * inchPerMeter);
  }
}
