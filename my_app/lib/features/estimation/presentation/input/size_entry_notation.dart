/// The shop's size notation, in one place.
///
/// A size is two numbers said as one -- "twenty-three four" is 23 inches and
/// 4 suter -- and the app carries it as a single string, `23.4`, with the half
/// suter as a second digit: `44.55` is 44 inches and five and a half suter.
///
/// The half is shown and typed as ½ -- `44'' 5½'''` -- the way a tape marks
/// it; see [SuterHalf]. Stored sizes keep the decimal.
///
/// In inches the point and the space are the same key: after the inch they
/// move on to the suter, after the suter they give the ½. `44 . 5 .` and
/// `44 5 ` are both typed as 44'' 5½'''.
///
/// These conversions used to live inside the input screen's state, which meant
/// the one part of the app where a misread digit becomes a mis-cut bar could
/// not be tested without building a screen. They are pure string work and
/// belong somewhere they can be checked directly.
library;

import 'package:flutter/services.dart';
import 'package:my_app/shared/format/suter_half.dart';
import 'package:my_app/shared/widgets/suter_wheel.dart';

class SizeNotation {
  const SizeNotation._();

  /// `('23', '4')` becomes `23.4`; `('44', '5.5')` and `('44', '5½')` both
  /// become `44.55`.
  ///
  /// The suter's half goes in as a second digit rather than a second dot,
  /// because the whole size has to survive as one number.
  static String combineInchSuter(String rawInch, String rawSuter) {
    final String inchValue = rawInch.trim();
    final String suterValue = SuterHalf.toDecimal(rawSuter);
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

  /// The two halves of what a merged box shows.
  ///
  /// A space separates them, because that is how the size is said out loud;
  /// the box always shows it that way, whichever key moved it on. More than
  /// two parts is a typo rather than a size, and says so by coming back null.
  static ({String whole, String sub})? splitMergedEntry(String rawValue) {
    // The box shows the tape marks -- 34'' 4½''' -- and they are decoration.
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
  ///
  /// A ½ goes back to the decimal every reader of a size expects: `5½` is
  /// `5.5`, and a ½ on its own is `0.5`.
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
      if (ch == SuterHalf.mark) {
        final String so = out.toString();
        final bool afterDigit =
            so.isNotEmpty && RegExp(r'\d$').hasMatch(so);
        out.write(afterDigit ? '.5' : '0.5');
        continue;
      }
      final bool isDigit = ch.compareTo('0') >= 0 && ch.compareTo('9') <= 0;
      if (isDigit || ch == '.') out.write(ch);
    }
    return out.toString();
  }

  /// A bare size as the box should show it, marks and all.
  ///
  /// Inches:            Feet:
  ///     34''               13'
  ///     34'' 4'''          13' 7''
  ///     34'' 4½'''
  ///
  /// In inches the point and the space are one key with one meaning: "on to
  /// the next part". After the inch they move on to the suter; after the suter
  /// they give the half, which shows as ½ straight after it with no point in
  /// between -- `34.4.` and `34 4 ` are both `34'' 4½'''`. A suter has no other
  /// fraction, so anything typed after the ½ is not kept. See [readInches].
  ///
  /// The mark goes on from the first digit, not once the next part is started.
  /// Waiting until space was pressed left a number sitting bare on screen with
  /// nothing to say what it was -- and the whole reason for the marks is that
  /// a fitter should never be in doubt about which number he is typing.
  ///
  /// One quote is feet, two inches, three suter. That is what he already reads
  /// off a tape, so which mark belongs to which part depends only on the unit
  /// the screen is in.
  static String displayMerged(String bare, {bool isFeet = false}) {
    if (!isFeet) return _showInches(readInches(bare));
    final String raw = stripMarks(bare);
    if (raw.isEmpty) return '';
    const List<String> marks = <String>["'", "''"];

    final int space = raw.indexOf(' ');
    if (space < 0) {
      return _marked(raw, marks[0]);
    }
    final String first = raw.substring(0, space);
    final String second = raw.substring(space + 1);
    if (first.isEmpty) return raw;
    return '${_marked(first, marks[0])} ${_marked(second, marks[1])}';
  }

  /// Whether [ch] is the key that moves a size on: the point, the space, or
  /// the comma some keyboards put where the point should be.
  static bool _isNextKey(String ch) => ch == '.' || ch == ' ' || ch == ',';

  static bool _isDigit(String ch) =>
      ch.compareTo('0') >= 0 && ch.compareTo('9') <= 0;

  /// An inch size read the way it is typed, one key at a time.
  ///
  /// - digits go into the inch;
  /// - the point or the space after the inch moves on to the suter;
  /// - digits then go into the suter;
  /// - the point or the space after the suter is the half;
  /// - nothing after the half is kept.
  ///
  /// A point or space with nothing in front of it is ignored rather than
  /// guessed at: a second press of the key straight after the inch would
  /// otherwise make a half nobody asked for. Half a suter on its own is typed
  /// as `0` and then the point, and shows as `½`. A ½ already in the text (a
  /// size the box is showing) is read as the half it is. Tape marks and
  /// anything else that is not part of a size are skipped.
  static InchEntry readInches(String text) {
    final StringBuffer inch = StringBuffer();
    final StringBuffer suter = StringBuffer();
    bool moved = false;
    bool half = false;
    for (final int unit in text.codeUnits) {
      final String ch = String.fromCharCode(unit);
      if (!moved) {
        if (_isDigit(ch)) {
          inch.write(ch);
        } else if (_isNextKey(ch) && inch.isNotEmpty) {
          moved = true;
        }
        continue;
      }
      if (half) continue;
      if (_isDigit(ch)) {
        suter.write(ch);
      } else if (ch == SuterHalf.mark) {
        half = true;
      } else if (_isNextKey(ch) && suter.isNotEmpty) {
        half = true;
      }
    }
    final String suterText = suter.toString();
    return InchEntry(
      inch: inch.toString(),
      moved: moved,
      // "0½" is shown, and kept, as the ½ it is.
      suter: half && suterText == '0' ? '' : suterText,
      half: half,
    );
  }

  /// [entry] as the box shows it: `34''`, `34'' `, `34'' 4'''`, `34'' 4½'''`.
  static String _showInches(InchEntry entry) {
    if (entry.inch.isEmpty) return '';
    if (!entry.moved) return "${entry.inch}''";
    final String suter = '${entry.suter}${entry.half ? SuterHalf.mark : ''}';
    if (suter.isEmpty) return "${entry.inch}'' ";
    return "${entry.inch}'' $suter'''";
  }

  /// One part of a size with its mark on it.
  ///
  /// A part still ending in its decimal point is mid-typing; marking there
  /// would wedge the quotes between the dot and the digit still to come.
  static String _marked(String part, String mark) {
    if (part.isEmpty) return '';
    if (part.endsWith('.')) return part;
    return '$part$mark';
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
      return displayMerged(parts.inch, isFeet: isFeet);
    }
    return displayMerged('${parts.inch} ${parts.suter}', isFeet: isFeet);
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

  /// The suter half: 0 to 7½, in halves. Eight suter is the next inch.
  static String? validateSuterPart(String rawValue) {
    final String value = SuterHalf.toDecimal(rawValue);
    if (value.isEmpty) {
      return null;
    }
    final RegExp pattern = RegExp(r'^\d(?:\.\d)?$');
    if (!pattern.hasMatch(value)) {
      return 'Suter runs 0 to 7½';
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

/// An inch size in the parts it is typed in. See [SizeNotation.readInches].
class InchEntry {
  const InchEntry({
    required this.inch,
    required this.moved,
    required this.suter,
    required this.half,
  });

  /// The whole inches.
  final String inch;

  /// Whether the size has moved on from the inch to the suter.
  final bool moved;

  /// The suter's digits, without its half.
  final String suter;

  /// Whether the suter carries a half.
  final bool half;

  /// The size as the keys that make it, marks left out: `34 4½`. One
  /// character per thing typed, which is what the cursor is counted in.
  String get bare => moved
      ? '$inch $suter${half ? SuterHalf.mark : ''}'
      : inch;
}

/// Puts the tape marks into a merged size box as the size is typed.
///
/// Filtering and marking in one pass: what a key means is decided here, and
/// [SizeNotation.displayMerged] decides how the result reads.
///
/// In inches the point and the space both move the size on -- from the inch
/// to the suter, then from the suter to its ½ -- and each key is read where it
/// landed: pressed at the end of the inch it moves on, at the end of the suter
/// it gives the half, and anywhere else it does nothing. A point pressed in
/// the middle of a size can never quietly turn it into a different one.
///
/// The caret is carried by counting real characters rather than pinned to the
/// end, so backspacing into the middle of a size still works -- a masked field
/// that throws the caret to the end on every keystroke is worse than no mask.
class MergedSizeFormatter extends TextInputFormatter {
  const MergedSizeFormatter({this.isFeet = false});

  /// Which marks the parts wear: feet and inch, or inch and suter.
  final bool isFeet;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return isFeet
        ? _formatFeet(oldValue, newValue)
        : _formatInches(oldValue, newValue);
  }

  TextEditingValue _formatInches(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String before = oldValue.text;
    final String after = newValue.text;
    final InchEntry was = SizeNotation.readInches(before);
    final TextSelection selection = oldValue.selection;
    final int caret = selection.isValid
        ? selection.end.clamp(0, before.length)
        : before.length;

    // One key pressed at the cursor: what it means depends on where it landed.
    if ((!selection.isValid || selection.isCollapsed) &&
        after.length == before.length + 1 &&
        after ==
            before.substring(0, caret) +
                after[caret] +
                before.substring(caret)) {
      return _keyPressed(was, _bareLength(before.substring(0, caret)), after[caret]);
    }

    // Backspace over the space between a size's two parts would run the suter
    // into the inch -- 34 4 into 344, a size that looks right and is not. The
    // cursor steps back over the space instead, and nothing is deleted.
    if (after.length == before.length - 1 && was.moved &&
        (was.suter.isNotEmpty || was.half)) {
      int at = 0;
      while (at < after.length && before[at] == after[at]) {
        at++;
      }
      if (before[at] == ' ' &&
          before.substring(0, at) + before.substring(at + 1) == after) {
        return _shown(was, was.inch.length);
      }
    }

    // Anything else -- a deletion, a paste, a whole size entered at once -- is
    // read afresh, key by key.
    final InchEntry now = SizeNotation.readInches(after);
    final int newCaret = newValue.selection.isValid
        ? newValue.selection.end.clamp(0, after.length)
        : after.length;
    return _shown(now, _bareLength(after.substring(0, newCaret)));
  }

  static TextEditingValue _keyPressed(InchEntry was, int at, String key) {
    final String bare = was.bare;
    final int k = at.clamp(0, bare.length);

    if (SizeNotation._isDigit(key)) {
      final InchEntry now = SizeNotation.readInches(
        bare.substring(0, k) + key + bare.substring(k),
      );
      // A digit after the ½ is not kept, and the cursor stays where it was.
      return _shown(now, now.bare.length > bare.length ? k + 1 : k);
    }

    if (SizeNotation._isNextKey(key)) {
      if (!was.moved) {
        // At the end of the inch: on to the suter.
        if (was.inch.isNotEmpty && k == was.inch.length) {
          final InchEntry now = SizeNotation.readInches('$bare ');
          return _shown(now, now.bare.length);
        }
        return _shown(was, k);
      }
      if (k == was.inch.length) {
        // Back at the end of the inch with the suter already begun: the key
        // just moves on to it again.
        return _shown(was, bare.length);
      }
      // At the end of the suter: the half.
      if (k == bare.length && !was.half && was.suter.isNotEmpty) {
        // Read back through the same rules, so 0 and its half show as ½.
        final InchEntry now = SizeNotation.readInches('$bare${SuterHalf.mark}');
        return _shown(now, now.bare.length);
      }
      return _shown(was, k);
    }

    // Letters and anything else never reach the box.
    return _shown(was, k);
  }

  /// How many keys' worth of size [text] holds -- where the cursor is, in
  /// the terms the size is edited in.
  static int _bareLength(String text) =>
      SizeNotation.readInches(text).bare.length;

  /// [entry] with its marks on, and the cursor after [bareCaret] of its keys.
  static TextEditingValue _shown(InchEntry entry, int bareCaret) {
    final String shown = SizeNotation._showInches(entry);
    final int count = bareCaret.clamp(0, entry.bare.length);
    int offset = 0;
    if (count > 0) {
      int seen = 0;
      offset = shown.length;
      for (int i = 0; i < shown.length; i++) {
        if (shown[i] != "'") seen++;
        if (seen == count) {
          offset = i + 1;
          break;
        }
      }
    }
    return TextEditingValue(
      text: shown,
      selection: TextSelection.collapsed(offset: offset),
    );
  }

  TextEditingValue _formatFeet(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final int caret = newValue.selection.end.clamp(0, newValue.text.length);
    final int bareCaret = SizeNotation.stripMarks(
      newValue.text.substring(0, caret),
    ).length;

    final String shown = SizeNotation.displayMerged(
      newValue.text,
      isFeet: true,
    );
    // Anything dropped leaves the caret counted past the end of what is left;
    // it stays at the end rather than jumping over the marks.
    final int shownBare = SizeNotation.stripMarks(shown).length;
    return TextEditingValue(
      text: shown,
      selection: TextSelection.collapsed(
        offset: _offsetAfterBareChars(
          shown,
          bareCaret < shownBare ? bareCaret : shownBare,
        ),
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
