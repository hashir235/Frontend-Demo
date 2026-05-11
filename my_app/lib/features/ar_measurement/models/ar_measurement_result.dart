import 'inch_sutar.dart';

/// Confidence label returned by the native AR activity.
enum ArConfidence { high, medium, low }

ArConfidence _parseConfidence(String? raw) {
  switch (raw) {
    case 'high':
      return ArConfidence.high;
    case 'medium':
      return ArConfidence.medium;
    default:
      return ArConfidence.low;
  }
}

/// Result of a full AR measurement session: width and height of a window in
/// metres (raw ARCore output) and a per-axis confidence label.
class ArMeasurementResult {
  final double widthMeters;
  final double heightMeters;
  final ArConfidence widthConfidence;
  final ArConfidence heightConfidence;

  const ArMeasurementResult({
    required this.widthMeters,
    required this.heightMeters,
    required this.widthConfidence,
    required this.heightConfidence,
  });

  InchSutar get width => InchSutar.fromMeters(widthMeters);
  InchSutar get height => InchSutar.fromMeters(heightMeters);

  /// Overall confidence is the weaker of the two axes.
  ArConfidence get overallConfidence {
    if (widthConfidence == ArConfidence.low ||
        heightConfidence == ArConfidence.low) {
      return ArConfidence.low;
    }
    if (widthConfidence == ArConfidence.medium ||
        heightConfidence == ArConfidence.medium) {
      return ArConfidence.medium;
    }
    return ArConfidence.high;
  }

  factory ArMeasurementResult.fromMap(Map<dynamic, dynamic> map) {
    return ArMeasurementResult(
      widthMeters: (map['width_meters'] as num?)?.toDouble() ?? 0.0,
      heightMeters: (map['height_meters'] as num?)?.toDouble() ?? 0.0,
      widthConfidence: _parseConfidence(map['width_confidence'] as String?),
      heightConfidence: _parseConfidence(map['height_confidence'] as String?),
    );
  }
}
