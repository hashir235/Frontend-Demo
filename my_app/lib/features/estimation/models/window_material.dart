import 'package:flutter/material.dart';

/// The stock one window is made from: which gauge of aluminium, in which
/// finish.
///
/// This used to be a single choice for a whole project, made on its own screen
/// before any window was entered. Real jobs are not like that -- the outside
/// frames go in 2mm and the inner partitions in 1.2mm, or a door comes in a
/// different colour from the windows around it. So it belongs to the window,
/// beside its height and width, and is chosen while the window is being
/// entered rather than pledged in advance for everything.
@immutable
class WindowMaterial {
  final String gauge;
  final String color;

  const WindowMaterial({required this.gauge, required this.color});

  /// What the first window of a brand-new job starts on. Every window after it
  /// inherits from the one before, so a shop doing ten windows in one stock
  /// picks it once.
  static const WindowMaterial initial = WindowMaterial(
    gauge: WindowGauges.g12,
    color: AluminiumColors.champagne,
  );

  WindowMaterial copyWith({String? gauge, String? color}) =>
      WindowMaterial(gauge: gauge ?? this.gauge, color: color ?? this.color);

  /// "1.2mm · Champagne" -- for a line of text under a window in the review
  /// list, where the reader wants to know at a glance and not read a table.
  String get label => '$gauge · ${AluminiumColors.shortLabelFor(color)}';

  @override
  bool operator ==(Object other) =>
      other is WindowMaterial && other.gauge == gauge && other.color == color;

  @override
  int get hashCode => Object.hash(gauge, color);

  @override
  String toString() => 'WindowMaterial($gauge, $color)';
}

/// The three gauges the rate list is priced in.
class WindowGauges {
  const WindowGauges._();

  static const String g12 = '1.2mm';
  static const String g16 = '1.6mm';
  static const String g2 = '2mm';

  static const List<String> all = <String>[g12, g16, g2];
}

/// The finishes, and what each one looks like.
///
/// `value` has to match the rate list's column heading exactly -- that string
/// is how a rate is looked up, so a label that reads nicely but does not match
/// would price the job at nothing. The swatch is only for the eye: a shop
/// picks colour by sight, and a row of identical grey chips reading "SAHARA/
/// BROWN" and "BLACK/ MULTI" makes them read every time instead of glancing.
class AluminiumColors {
  const AluminiumColors._();

  static const String champagne = 'H23/PC-RAL';
  static const String dull = 'DULL';
  static const String sahara = 'SAHARA/ BROWN';
  static const String black = 'BLACK/ MULTI';
  static const String wood = 'WOOD COAT';

  static const List<String> all = <String>[
    champagne,
    dull,
    sahara,
    black,
    wood,
  ];

  /// The full name, as the rates screen and the rate list write it.
  static String labelFor(String value) {
    switch (value) {
      case champagne:
        return 'H23/PC-RAL (Champagne)';
      case dull:
        return 'DULL';
      case sahara:
        return 'SAHARA/ BROWN';
      case black:
        return 'BLACK/ MULTI';
      case wood:
        return 'WOOD COAT';
      default:
        return value;
    }
  }

  /// The short name, for a chip or a line under a window where the full
  /// heading would crowd everything else out.
  static String shortLabelFor(String value) {
    switch (value) {
      case champagne:
        return 'Champagne';
      case dull:
        return 'Dull';
      case sahara:
        return 'Sahara';
      case black:
        return 'Black';
      case wood:
        return 'Wood';
      default:
        return value;
    }
  }

  /// Roughly what the finish looks like on the bar.
  static Color swatchFor(String value) {
    switch (value) {
      case champagne:
        return const Color(0xFFC9A227);
      case dull:
        return const Color(0xFF9BA3AB);
      case sahara:
        return const Color(0xFF8C6239);
      case black:
        return const Color(0xFF2E2E2E);
      case wood:
        return const Color(0xFF6E4423);
      default:
        return const Color(0xFF9BA3AB);
    }
  }

  /// Text that stays readable on top of [swatchFor]. Champagne and dull are
  /// light enough to need dark text; the browns and black do not.
  static Color onSwatchFor(String value) {
    switch (value) {
      case champagne:
      case dull:
        return const Color(0xFF1B2430);
      default:
        return Colors.white;
    }
  }

  /// Falls back to champagne for anything unrecognised -- a colour removed
  /// from the rate list, or a job saved before this list existed.
  static String normalize(String? value) {
    final String v = (value ?? '').trim();
    return all.contains(v) ? v : champagne;
  }
}
