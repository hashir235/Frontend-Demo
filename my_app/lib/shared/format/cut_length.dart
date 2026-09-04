/// One length, said the three ways a workshop reads it.
library;

/// Centimetres in a foot.
const double _cmPerFoot = 30.48;

/// A cut length, in whichever unit the person looking at it thinks in.
///
/// A workshop measuring in inches and one measuring in centimetres are looking
/// at the same bar, and neither should have to do the conversion in their
/// head -- least of all while deciding whether a formula is right. Taking 2mm
/// off a formula is obvious in centimetres and not obvious at all in suter,
/// and it is the same 2mm either way.
class CutLength {
  const CutLength.fromFeet(this.feet);

  CutLength.fromCm(double cm) : feet = cm / _cmPerFoot;

  final double feet;

  double get cm => feet * _cmPerFoot;

  /// `7.116 ft`, trimmed of trailing zeros.
  String get inFeet => '${_trim(feet, 3)} ft';

  /// `216.9 cm`.
  String get inCm => '${_trim(cm, 1)} cm';

  /// `7' 1'' 3'''` -- the form read straight off a tape.
  ///
  /// Suter snaps to the nearest half, which is the finest mark on the tape;
  /// carrying more precision than the tape can show would be inventing it.
  String get inInchSutter {
    final double safe = feet < 0 ? 0 : feet;
    int wholeFeet = safe.floor();
    final double remainingInches = (safe - wholeFeet) * 12.0;
    int inches = remainingInches.floor();
    double suter = ((remainingInches - inches) * 8.0 * 2).round() / 2.0;

    if (suter >= 8.0) {
      suter = 0;
      inches += 1;
    }
    if (inches >= 12) {
      inches = 0;
      wholeFeet += 1;
    }

    final String su = suter == suter.roundToDouble()
        ? suter.toInt().toString()
        : suter.toStringAsFixed(1);
    return "$wholeFeet' $inches'' $su'''";
  }

  /// All three at once, for the places that cannot know which one the reader
  /// thinks in. Centimetres first when that is what the formula is written in.
  String threeWays({required bool centimetresFirst}) {
    return centimetresFirst
        ? '$inCm  ·  $inFeet  ·  $inInchSutter'
        : '$inFeet  ·  $inCm  ·  $inInchSutter';
  }

  /// Drops the zeros a tape would not show: 7.100 reads as 7.1, 7.000 as 7.
  static String _trim(double value, int places) {
    final String fixed = value.toStringAsFixed(places);
    if (!fixed.contains('.')) return fixed;
    return fixed
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}
