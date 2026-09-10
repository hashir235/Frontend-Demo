/// The shop's size notation, in one place.
///
/// A size is two numbers said as one -- "twenty-three four" is 23 inches and
/// 4 suter -- and the app carries it as a single string, `23.4`, with the half
/// suter as a second digit: `44.55` is 44 inches and five and a half suter.
///
/// These conversions used to live inside the input screen's state, which meant
/// the one part of the app where a misread digit becomes a mis-cut bar could
/// not be tested without building a screen. They are pure string work and
/// belong somewhere they can be checked directly.
library;

import 'package:flutter/services.dart';
import 'package:my_app/shared/widgets/suter_wheel.dart';

class SizeNotation {
  const SizeNotation._();

  /// `('23', '4')` becomes `23.4`; `('44', '5.5')` becomes `44.55`.
  ///
  /// The suter's half goes in as a second digit rather than a second dot,
  /// because the whole size has to survive as one number.
  static String combineInchSuter(String rawInch, String rawSuter) {
    final String inchValue = rawInch.trim();
    final String suterValue = rawSuter.trim();
    if (suterValue.isEmpty) {
      return '$inchValue.0';
    }
    if (!suterValue.contains('.')) {
      return '$inchValue.$suterValue';
    }
    final List<String> parts = suterValue.split('.');
    final String left = parts.first;
    final String right = parts.length > 1 ? parts[1] : '';
    if (right.isEmpty) {
      return '$inchValue.$left';
    }
    return '$inchValue.${left[0]}${right[0]}';
  }

  /// `23.4` becomes `('23', '4')`; `44.55` becomes `('44', '5.5')`.
  static ({String inch, String suter}) splitStoredInches(String rawValue) {
    final String value = rawValue.trim();
    if (value.isEmpty) {
      return (inch: '', suter: '');
    }
    final List<String> parts = value.split('.');
    final String inchValue = parts.first;
    if (parts.length < 2) {
      return (inch: inchValue, suter: '');
    }
    final String right = parts[1];
    if (right.isEmpty || right == '0') {
      return (inch: inchValue, suter: '');
    }
    if (right.length == 1) {
      return (inch: inchValue, suter: right);
    }
    return (inch: inchValue, suter: '${right[0]}.${right[1]}');
  }

  /// Storage stays in the shop's `feet.inch` notation.
  static String combineFeetInch(String rawFeet, String rawInch) {
    final String feet = rawFeet.trim();
    if (feet.isEmpty) {
      return '';
    }
    final int inch = int.tryParse(rawInch.trim()) ?? 0;
    return '$feet.$inch';
  }

  static ({String inch, String suter}) splitStoredFeet(String stored) {
    final String value = stored.trim();
    if (value.isEmpty) {
      return (inch: '', suter: '');
    }
    final List<String> parts = value.split('.');
    final String feet = parts.first;
    if (parts.length < 2 || parts[1].trim().isEmpty) {
      return (inch: feet, suter: '');
    }
    final int inch = int.tryParse(parts[1].trim()) ?? 0;
    return (
      inch: feet,
      suter: InchWheel.snap(inch.toDouble()).round().toString(),
    );
  }

  /// The two halves of what was typed into a merged box.
  ///
  /// A space separates them, because that is how the size is said out loud and
  /// it leaves the dot free to mean the half suter it already means. More than
  /// two parts is a typo rather than a size, and says so by coming back null.
  static ({String whole, String sub})? splitMergedEntry(String rawValue) {
    // The box shows the tape marks -- 34'' 4.5''' -- and they are decoration.
    // Stripped here, at the one place every reader of a merged box comes
    // through, so nothing downstream can mistake a quote for a digit.
    final String value = stripMarks(rawValue).trim();
    if (value.isEmpty) {
      return null;
    }
    final List<String> parts = value.split(RegExp(r'\s+'));
    if (parts.length > 2) {
      return null;
    }
    return (whole: parts.first, sub: parts.length > 1 ? parts[1] : '');
  }

  /// A size without its marks: digits, dots, and a single separating space.
  ///
  /// Also what filters a merged box -- anything that is not part of a size is
  /// dropped here rather than by a second formatter, so there is no ordering
  /// between the two to get wrong.
  static String stripMarks(String text) {
    final StringBuffer out = StringBuffer();
    bool spaced = false;
    for (final int unit in text.codeUnits) {
      final String ch = String.fromCharCode(unit);
      if (ch == ' ') {
        // One separator only; a second space would read as a third part.
        if (out.isNotEmpty && !spaced) {
          out.write(' ');
          spaced = true;
        }
        continue;
      }
      final bool isDigit = ch.compareTo('0') >= 0 && ch.compareTo('9') <= 0;
      if (isDigit || ch == '.') out.write(ch);
    }
    return out.toString();
  }

  /// A bare size as the box should show it, marks and all.
  ///
  ///     34            while the inch is still being typed
  ///     34''          the moment space is pressed -- the inch is settled
  ///     34'' 4.5'''   with the suter in
  ///
  /// A bare `34 4` on screen gives no hint which number is which, and a fitter
  /// who has never met algebra has no reason to guess. These marks are what he
  /// already reads off a tape.
  static String displayMerged(String bare) {
    final String raw = stripMarks(bare);
    final int space = raw.indexOf(' ');
    if (space < 0) {
      // Nothing settled yet, so nothing is marked.
      return raw;
    }
    final String inch = raw.substring(0, space);
    final String suter = raw.substring(space + 1);
    if (inch.isEmpty) return raw;
    if (suter.isEmpty) return "$inch'' ";
    // A suter still ending in its decimal point is mid-typing; marking there
    // would wedge the quotes between the dot and the digit still to come.
    if (suter.endsWith('.')) return "$inch'' $suter";
    return "$inch'' $suter'''";
  }

  /// What was typed into the merged box, as the notation everything else
  /// reads. Empty when there is nothing usable to store.
  static String mergedToStored(String typed, {required bool isFeet}) {
    final ({String whole, String sub})? parts = splitMergedEntry(typed);
    if (parts == null || parts.whole.trim().isEmpty) {
      return '';
    }
    return isFeet
        ? combineFeetInch(parts.whole, parts.sub)
        : combineInchSuter(parts.whole, parts.sub);
  }

  /// Stored notation as the merged box shows it. A size that lands on a whole
  /// inch shows just the inch -- `23`, not `23 0`.
  static String storedToMerged(String stored, {required bool isFeet}) {
    final String value = stored.trim();
    if (value.isEmpty) {
      return '';
    }
    final ({String inch, String suter}) parts = isFeet
        ? splitStoredFeet(value)
        : splitStoredInches(value);
    if (parts.inch.isEmpty) {
      return '';
    }
    if (parts.suter.isEmpty || parts.suter == '0') {
      return displayMerged(parts.inch);
    }
    return displayMerged('${parts.inch} ${parts.suter}');
  }

  /// The inch half: a whole number of inches, and there is no such window as
  /// one measuring nothing.
  static String? validateWholePart(String rawValue) {
    final String value = rawValue.trim();
    if (value.isEmpty) {
      return 'Required';
    }
    final int? parsed = int.tryParse(value);
    if (parsed == null) {
      return 'Use whole number';
    }
    if (parsed <= 0) {
      return 'Must be greater than zero';
    }
    return null;
  }

  /// The suter half: 0 to 7.5, in halves. Eight suter is the next inch.
  static String? validateSuterPart(String rawValue) {
    final String value = rawValue.trim();
    if (value.isEmpty) {
      return null;
    }
    final RegExp pattern = RegExp(r'^\d(?:\.\d)?$');
    if (!pattern.hasMatch(value)) {
      return 'Use 0..7.9 (one decimal)';
    }
    final double? parsed = double.tryParse(value);
    if (parsed == null || parsed < 0 || parsed >= 8) {
      return 'Suter must be less than 8';
    }
    return null;
  }

  /// A whole merged entry in inches mode.
  static String? validateMergedInches(String rawValue) {
    if (rawValue.trim().isEmpty) {
      return 'Required';
    }
    final ({String whole, String sub})? parts = splitMergedEntry(rawValue);
    if (parts == null) {
      return 'Use: inch suter';
    }
    return validateWholePart(parts.whole) ?? validateSuterPart(parts.sub);
  }
}

/// Puts the tape marks into a merged size box as the size is typed.
///
/// Filtering and marking in one pass: [SizeNotation.stripMarks] decides what
/// counts as a size, [SizeNotation.displayMerged] decides how it reads.
///
/// The caret is carried by counting real characters rather than pinned to the
/// end, so backspacing into the middle of a size still works -- a masked field
/// that throws the caret to the end on every keystroke is worse than no mask.
class MergedSizeFormatter extends TextInputFormatter {
  const MergedSizeFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final int caret = newValue.selection.end.clamp(0, newValue.text.length);
    final int bareCaret = SizeNotation.stripMarks(
      newValue.text.substring(0, caret),
    ).length;

    final String shown = SizeNotation.displayMerged(newValue.text);
    return TextEditingValue(
      text: shown,
      selection: TextSelection.collapsed(
        offset: _offsetAfterBareChars(shown, bareCaret),
      ),
    );
  }

  static int _offsetAfterBareChars(String shown, int count) {
    if (count <= 0) return 0;
    for (int i = 1; i <= shown.length; i++) {
      if (SizeNotation.stripMarks(shown.substring(0, i)).length >= count) {
        return i;
      }
    }
    return shown.length;
  }
}
