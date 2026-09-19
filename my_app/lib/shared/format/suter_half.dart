/// The half suter, written the way an inchi tape marks it: 4½, not 4.5.
///
/// Suter goes in halves, and a shop writes the half as a fraction. "4.5" made
/// people stop and work out what point five of a suter was; "4½" is what they
/// already write on the wall and read off the tape.
///
/// Only what is shown and typed changes. Every size is still stored and sent
/// in the decimal notation it always had -- `44.55` is 44 inches 5½ suter,
/// `27'' 6.5'''` on the wire -- because the server, the engine, saved jobs and
/// older copies of the app all read that, and the server works glass sizes out
/// from those very strings. So a half is turned into ½ on its way to the eye,
/// and back into .5 on its way in.
library;

import 'dart:async';

import 'package:flutter/services.dart';

class SuterHalf {
  const SuterHalf._();

  /// The mark itself: one small figure over another, the tape's own half.
  static const String mark = '½';

  /// A suter as it is shown: `3` -> "3", `3.5` -> "3½", `0.5` -> "½".
  static String format(double suter) {
    if (!suter.isFinite) return '0';
    final double halved = (suter * 2).roundToDouble() / 2;
    final int whole = halved.truncate();
    final bool half = halved - whole > 0.25;
    if (!half) return '$whole';
    return whole == 0 ? mark : '$whole$mark';
  }

  /// A suter written either way, in the decimal notation stored sizes use:
  /// "3½" -> "3.5", "½" -> "0.5", "3.5" -> "3.5", "3" -> "3".
  static String toDecimal(String text) {
    final String value = text.trim();
    if (!value.contains(mark)) return value;
    final String before = value.substring(0, value.indexOf(mark)).trim();
    return '${before.isEmpty ? '0' : before}.5';
  }

  /// A suter written either way, as a number. Null when it is not one.
  static double? parse(String text) => double.tryParse(toDecimal(text));

  /// A decimal suter as it is shown: "3.5" -> "3½". Anything that is not a
  /// suter number is returned as it was.
  static String fromDecimal(String text) {
    final double? value = double.tryParse(text.trim());
    return value == null ? text : format(value);
  }

  // A single suter digit and its .5, right before the suter mark ''' -- and
  // not the tail of a longer number, which would be something else.
  static final RegExp _halfBeforeMark = RegExp(r"(?<![\d.])(\d)\.5(?=''')");

  /// Every half suter in a finished size, shown as ½: `34'' 4.5'''` ->
  /// `34'' 4½'''`, `2' 3'' 0.5'''` -> `2' 3'' ½'''`.
  ///
  /// For sizes that arrive as text -- from the server, or saved before this --
  /// and are only to be shown. Numbers without the suter mark are left alone:
  /// a centimetre or a foot figure is not a suter.
  static String inText(String text) => text.replaceAllMapped(
    _halfBeforeMark,
    (Match m) => m.group(1) == '0' ? mark : '${m.group(1)}$mark',
  );
}

/// The keys that move a size on: the point, the space, and the comma some
/// keyboards put where the point should be.
bool _isNextKey(String ch) => ch == '.' || ch == ' ' || ch == ',';

/// A box that takes a suter: digits, and the half as ½.
///
/// The point or the space after the suter is how a half is asked for, and it
/// turns into ½ on the spot, straight after the suter with no point between
/// -- there is no other fraction of a suter, so nothing after it is kept.
/// Pressed with no suter in front of it, the key is ignored: half a suter on
/// its own is `0` and then the point. Backspace takes the ½ off in one go.
class SuterBoxFormatter extends TextInputFormatter {
  const SuterBoxFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final StringBuffer digits = StringBuffer();
    bool half = false;
    for (final int unit in newValue.text.codeUnits) {
      final String ch = String.fromCharCode(unit);
      // A ½ already in the box is the half it says; a key only makes one
      // when there is a suter for it to follow.
      if (ch == SuterHalf.mark || (_isNextKey(ch) && digits.isNotEmpty)) {
        half = true;
        break;
      }
      if (ch.compareTo('0') >= 0 && ch.compareTo('9') <= 0) digits.write(ch);
    }
    String whole = digits.toString();
    if (half && whole == '0') whole = '';
    final String shown = half ? '$whole${SuterHalf.mark}' : whole;
    return TextEditingValue(
      text: shown,
      selection: TextSelection.collapsed(offset: shown.length),
    );
  }
}

/// The inch box of a size typed in two boxes.
///
/// The point or the space moves on to the suter box -- the same keys that
/// move a one-box size on from its inch to its suter -- and is not kept. With
/// nothing typed yet the key does nothing. Put it ahead of the digits-only
/// filter, which would otherwise swallow the key before it is seen.
class InchBoxFormatter extends TextInputFormatter {
  const InchBoxFormatter({required this.onNext});

  /// Moves the cursor on to the suter box.
  final void Function() onNext;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length <= oldValue.text.length ||
        !newValue.text.split('').any(_isNextKey)) {
      return newValue;
    }
    if (oldValue.text.trim().isNotEmpty) {
      // After this edit has settled, not in the middle of it.
      scheduleMicrotask(onNext);
    }
    return oldValue;
  }
}
