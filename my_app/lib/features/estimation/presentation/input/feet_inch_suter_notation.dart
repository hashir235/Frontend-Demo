/// A length in feet, inches and suter, typed the way the size boxes type.
///
/// The size boxes take two parts -- inch and suter, or feet and inch. A stock
/// length said in feet needs all three, the way a tape reads it: `10' 7'' 4½'''`
/// is ten feet, seven inches, four and a half suter.
///
/// It is typed like a size: the point and the space are one key meaning "on to
/// the next part" -- feet to inch, inch to suter -- and after the suter that
/// key gives the ½. `10 . 7 . 4 .` and `10 7 4 ` are both `10' 7'' 4½'''`. An
/// inch runs 0 to 11 and a suter 0 to 7, and a digit that would take either
/// past that is simply not typed. See [SizeNotation.readEntry] for the two-part
/// version this follows.
library;

import 'package:flutter/services.dart';
import 'package:my_app/shared/format/suter_half.dart';

/// A feet-inch-suter length in the parts it is typed in.
class FeetInchSuterEntry {
  const FeetInchSuterEntry({
    required this.feet,
    required this.inch,
    required this.suter,
    required this.stage,
  });

  static const FeetInchSuterEntry empty =
      FeetInchSuterEntry(feet: '', inch: '', suter: '', stage: 0);

  final String feet;
  final String inch;

  /// The suter's digit, without its half.
  final String suter;

  /// How far the length has got: 0 the feet, 1 on to the inch, 2 on to the
  /// suter, 3 the suter has its ½.
  final int stage;

  bool get half => stage == 3;

  static bool isDigit(String ch) =>
      ch.compareTo('0') >= 0 && ch.compareTo('9') <= 0;

  /// The point, the space, or the comma some keyboards put there.
  static bool isNextKey(String ch) => ch == '.' || ch == ' ' || ch == ',';

  /// An inch of a foot: one digit, or 10 or 11.
  static bool _inchAccepts(String inch, String ch) {
    final String next = '$inch$ch';
    return next.length == 1 || next == '10' || next == '11';
  }

  /// The length read the way it is typed, one key at a time. Tape marks and
  /// anything else that is not part of a length are skipped; a next-key with
  /// nothing in front of it is ignored rather than guessed at.
  static FeetInchSuterEntry read(String text) {
    final StringBuffer feet = StringBuffer();
    final StringBuffer inch = StringBuffer();
    final StringBuffer suter = StringBuffer();
    int stage = 0;
    for (final int unit in text.codeUnits) {
      final String ch = String.fromCharCode(unit);
      switch (stage) {
        case 0:
          if (isDigit(ch)) {
            feet.write(ch);
          } else if (isNextKey(ch) && feet.isNotEmpty) {
            stage = 1;
          }
        case 1:
          if (isDigit(ch)) {
            if (_inchAccepts(inch.toString(), ch)) inch.write(ch);
          } else if (isNextKey(ch) && inch.isNotEmpty) {
            stage = 2;
          }
        case 2:
          if (isDigit(ch)) {
            if (suter.isEmpty && ch.compareTo('7') <= 0) suter.write(ch);
          } else if (ch == SuterHalf.mark) {
            stage = 3;
          } else if (isNextKey(ch) && suter.isNotEmpty) {
            stage = 3;
          }
        default:
          // Nothing comes after the ½.
          break;
      }
    }
    final String suterText = suter.toString();
    return FeetInchSuterEntry(
      feet: feet.toString(),
      inch: inch.toString(),
      // "0½" is shown, and kept, as the ½ it is.
      suter: stage == 3 && suterText == '0' ? '' : suterText,
      stage: stage,
    );
  }

  /// The keys that make it, marks left out: `10 7 4½`. One character per
  /// thing typed, which is what the cursor is counted in.
  String get bare {
    final StringBuffer out = StringBuffer(feet);
    if (stage >= 1) out.write(' $inch');
    if (stage >= 2) out.write(' $suter');
    if (half) out.write(SuterHalf.mark);
    return out.toString();
  }

  /// As the box shows it: `10'`, `10' `, `10' 7''`, `10' 7'' `, `10' 7'' 4'''`,
  /// `10' 7'' 4½'''`.
  String get shown {
    if (feet.isEmpty) return '';
    final StringBuffer out = StringBuffer("$feet'");
    if (stage >= 1) {
      out.write(' ');
      if (inch.isNotEmpty) out.write("$inch''");
    }
    if (stage >= 2) {
      out.write(' ');
      final String s = '$suter${half ? SuterHalf.mark : ''}';
      if (s.isNotEmpty) out.write("$s'''");
    }
    return out.toString();
  }

  /// Where each part ends, counted in [bare] characters.
  int get feetEnd => feet.length;
  int get inchEnd => feet.length + 1 + inch.length;
  int get suterEnd => inchEnd + 1 + suter.length;

  /// The length in feet, or null when no feet have been typed.
  double? get inFeet {
    final int? f = int.tryParse(feet);
    if (f == null) return null;
    final int i = int.tryParse(inch) ?? 0;
    final double s = (int.tryParse(suter) ?? 0) + (half ? 0.5 : 0);
    return f + i / 12 + s / 96;
  }
}

/// Puts the tape marks into a feet-inch-suter box as the length is typed.
///
/// Each key is read where it landed, as in the size boxes: a next-key at the
/// end of a part moves on, at the end of the suter it gives the ½, and
/// anywhere else it does nothing -- a point pressed in the middle can never
/// quietly make it a different length. A digit that does not fit is not
/// typed. Backspace over the space between two parts steps over it instead of
/// running them together (10' 7'' into 107').
class FeetInchSuterFormatter extends TextInputFormatter {
  const FeetInchSuterFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String before = oldValue.text;
    final String after = newValue.text;
    final FeetInchSuterEntry was = FeetInchSuterEntry.read(before);
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
      return _keyPressed(
        was,
        _bareLength(before.substring(0, caret)),
        after[caret],
      );
    }

    // Backspace over a space with more of the length after it: step over.
    if (after.length == before.length - 1) {
      int at = 0;
      while (at < after.length && before[at] == after[at]) {
        at++;
      }
      if (at < before.length - 1 &&
          before[at] == ' ' &&
          before.substring(0, at) + before.substring(at + 1) == after) {
        return _shown(was, _bareLength(before.substring(0, at)));
      }
    }

    // Anything else -- a deletion, a paste -- is read afresh, key by key.
    final FeetInchSuterEntry now = FeetInchSuterEntry.read(after);
    final int newCaret = newValue.selection.isValid
        ? newValue.selection.end.clamp(0, after.length)
        : after.length;
    return _shown(now, _bareLength(after.substring(0, newCaret)));
  }

  TextEditingValue _keyPressed(FeetInchSuterEntry was, int at, String key) {
    final String bare = was.bare;
    final int k = at.clamp(0, bare.length);

    if (FeetInchSuterEntry.isDigit(key)) {
      final FeetInchSuterEntry now =
          FeetInchSuterEntry.read(bare.substring(0, k) + key + bare.substring(k));
      // A digit that does not fit is not typed, and the length stays exactly
      // as it was -- never kept at the cost of a digit further on.
      if (now.bare.length <= bare.length) return _shown(was, k);
      return _shown(now, k + 1);
    }

    if (FeetInchSuterEntry.isNextKey(key)) {
      if (was.stage == 0) {
        if (was.feet.isNotEmpty && k == was.feetEnd) {
          final FeetInchSuterEntry now = FeetInchSuterEntry.read('$bare ');
          return _shown(now, now.bare.length);
        }
        return _shown(was, k);
      }
      // At the end of a part whose next part is already begun: on to it.
      if (k == was.feetEnd) return _shown(was, was.inchEnd);
      if (was.stage == 1) {
        if (k == bare.length && was.inch.isNotEmpty) {
          final FeetInchSuterEntry now = FeetInchSuterEntry.read('$bare ');
          return _shown(now, now.bare.length);
        }
        return _shown(was, k);
      }
      if (k == was.inchEnd) return _shown(was, was.suterEnd);
      if (was.stage == 2 && k == bare.length && was.suter.isNotEmpty) {
        final FeetInchSuterEntry now =
            FeetInchSuterEntry.read('$bare${SuterHalf.mark}');
        return _shown(now, now.bare.length);
      }
      return _shown(was, k);
    }

    // Letters and anything else never reach the box.
    return _shown(was, k);
  }

  int _bareLength(String text) => FeetInchSuterEntry.read(text).bare.length;

  /// [entry] with its marks on, and the cursor after [bareCaret] of its keys.
  TextEditingValue _shown(FeetInchSuterEntry entry, int bareCaret) {
    final String shown = entry.shown;
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
}
