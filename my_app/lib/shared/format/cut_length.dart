/// One length, said the three ways a workshop reads it.
library;

/// Centimetres in a foot.
const double _cmPerFoot = 30.48;

/// One reading of a length: what to call it, and what it says.
class CutReading {
  const CutReading(this.unit, this.value);

  /// `cm`, `ft`, `in`.
  final String unit;

  /// The length written the way that unit is read.
  final String value;
}

/// A cut length, in whichever unit the person looking at it thinks in.
///
/// A workshop measuring in inches and one measuring in centimetres are looking
/// at the same bar, and neither should have to do the conversion in their
/// head -- least of all while deciding whether a formula is right. Taking 2mm
/// off a formula is obvious in centimetres and not obvious at all in suter,
/// and it is the same 2mm either way.
///
/// Feet and inches are two different readings, not one. A bar is read off the
/// tape as `7' 1'' 1.5'''` when a shop works in feet, and as `85'' 1.5'''`
/// when it works in inches -- the same bar, and neither is the other written
/// differently.
class CutLength {
  const CutLength.fromFeet(this.feet);

  CutLength.fromCm(double cm) : feet = cm / _cmPerFoot;

  final double feet;

  double get cm => feet * _cmPerFoot;

  double get inches => feet * 12.0;

  /// `216.4` -- centimetres, to the millimetre a tape can show.
  String get inCm => _trim(cm, 1);

  /// `7' 1'' 1.5'''` -- feet, inches and suter, as a shop working in feet
  /// reads it off the tape.
  String get inFeetInchSuter {
    final _Tape tape = _Tape.of(inches);
    return "${tape.feet}' ${tape.inches}'' ${tape.suter}'''";
  }

  /// `85'' 1.5'''` -- whole inches and suter, as a shop working in inches
  /// reads it. The same bar as [inFeetInchSuter], counted without ever
  /// reaching for feet.
  String get inInchSuter {
    final _Tape tape = _Tape.of(inches);
    return "${tape.totalInches}'' ${tape.suter}'''";
  }

  /// All three readings, in the order a workshop scans them.
  ///
  /// Centimetres first when that is what the formulas are written in, so the
  /// number under a formula lines up with the numbers in it.
  List<CutReading> readings({required bool centimetresFirst}) {
    final List<CutReading> feetAndInches = <CutReading>[
      CutReading('ft', inFeetInchSuter),
      CutReading('in', inInchSuter),
    ];
    return centimetresFirst
        ? <CutReading>[CutReading('cm', inCm), ...feetAndInches]
        : <CutReading>[...feetAndInches, CutReading('cm', inCm)];
  }

  /// Drops the zeros a tape would not show: 216.40 reads as 216.4, 216.00 as
  /// 216.
  static String _trim(double value, int places) {
    final String fixed = value.toStringAsFixed(places);
    if (!fixed.contains('.')) return fixed;
    return fixed
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}

/// A length as the marks on a tape, worked out once and read off either way.
///
/// Suter snaps to the nearest half, which is the finest mark there is;
/// carrying more precision than the tape can show would be inventing it. The
/// carries matter: a piece a hair under a whole inch must read as the next
/// inch and no suter, never as eight suter of the one below, because nobody
/// has an eight-suter mark to cut to.
class _Tape {
  const _Tape(this.totalInches, this.suter);

  /// Whole inches in the whole length -- 85 for a bar that is seven feet and
  /// one inch.
  final int totalInches;

  /// Suter past the last whole inch, to the half.
  final String suter;

  int get feet => totalInches ~/ 12;

  /// Inches past the last whole foot.
  int get inches => totalInches % 12;

  static _Tape of(double totalInches) {
    final double safe = totalInches < 0 ? 0 : totalInches;
    int whole = safe.floor();
    double suter = ((safe - whole) * 8.0 * 2).round() / 2.0;

    if (suter >= 8.0) {
      suter = 0;
      whole += 1;
    }

    final String text = suter == suter.roundToDouble()
        ? suter.toInt().toString()
        : suter.toStringAsFixed(1);
    return _Tape(whole, text);
  }
}
