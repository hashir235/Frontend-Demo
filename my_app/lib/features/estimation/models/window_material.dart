import 'package:flutter/material.dart';

import 'window_variant.dart';

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

  /// What the first window starts on until the shop picks a stock of its own
  /// (see `LastWindowMaterial`). Every window after it inherits from the one
  /// before, so a shop doing ten windows in one stock picks it once.
  static const WindowMaterial initial = WindowMaterial(
    gauge: WindowGauges.g12,
    color: AluminiumColors.champagne,
  );

  WindowMaterial copyWith({String? gauge, String? color}) =>
      WindowMaterial(gauge: gauge ?? this.gauge, color: color ?? this.color);

  /// False for a window saved before stock was per-window: it has no material
  /// of its own, and the job it belongs to has to supply one.
  bool get isSet => gauge.trim().isNotEmpty && color.trim().isNotEmpty;

  /// This material, or [fallback] where it says nothing.
  ///
  /// Half-set is possible in principle (a gauge with no colour), so each part
  /// falls back on its own rather than the pair being all-or-nothing.
  WindowMaterial orElse(WindowMaterial fallback) {
    if (isSet) return this;
    return WindowMaterial(
      gauge: gauge.trim().isEmpty ? fallback.gauge : gauge,
      color: color.trim().isEmpty ? fallback.color : color,
    );
  }

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

/// The gauges a window can be made in, thinnest first.
///
/// The rate list prices three of them -- 1.2, 1.6 and 2mm. 0.9mm and 1mm are
/// bought at the 1.2mm rate (Hashir, Oct 2026) and are offered so the bill
/// can say what the window was really made in; the engine prices them from
/// the 1.2mm row unless the list carries one of their own, as it does for
/// Prime Economy's profiles in 0.9mm.
class WindowGauges {
  const WindowGauges._();

  static const String g09 = '0.9mm';
  static const String g10 = '1mm';
  static const String g12 = '1.2mm';
  static const String g16 = '1.6mm';
  static const String g2 = '2mm';

  static const List<String> all = <String>[g09, g10, g12, g16, g2];

  /// The gauges window [windowCode] comes in: all of these, unless it is made
  /// in others (Prime Economy, in 0.9mm only).
  static List<String> forWindow(String windowCode) =>
      WindowVariants.ownOf(windowCode)?.gauges ?? all;
}

/// The finishes, and what each one looks like.
///
/// `value` has to match the rate list's column heading exactly -- that string
/// is how a rate is looked up, so a label that reads nicely but does not match
/// would price the job at nothing. The swatch is only for the eye: a shop
/// picks colour by sight, and a row of identical grey chips reading "SAHARA/
/// BROWN" and "BLACK/ MULTI" makes them read every time instead of glancing.
///
/// Milky White and Black Matte have no column of their own: they are bought
/// at the champagne rate (Hashir, Oct 2026), and are offered so the bill
/// prints the finish the window was made in. The engine prices them from the
/// champagne column unless the list carries one of their own.
class AluminiumColors {
  const AluminiumColors._();

  static const String champagne = 'H23/PC-RAL';
  static const String dull = 'DULL';
  static const String sahara = 'SAHARA/ BROWN';
  static const String black = 'BLACK/ MULTI';
  static const String wood = 'WOOD COAT';
  static const String milkyWhite = 'MILKY WHITE';
  static const String blackMatte = 'BLACK MATTE';

  static const List<String> all = <String>[
    champagne,
    dull,
    sahara,
    black,
    wood,
    milkyWhite,
    blackMatte,
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
      case milkyWhite:
        return 'Milky White';
      case blackMatte:
        return 'Black Matte';
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
      case milkyWhite:
        return 'Milky White';
      case blackMatte:
        return 'Black Matte';
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
      // An off-white with a little warmth, so it does not read as an empty box
      // on a white card.
      case milkyWhite:
        return const Color(0xFFF2EFE6);
      // A flat, deeper black than Black/Multi's, which is drawn a shade lifted.
      case blackMatte:
        return const Color(0xFF1C1C1E);
      default:
        return const Color(0xFF9BA3AB);
    }
  }

  /// Text that stays readable on top of [swatchFor]. Champagne, dull and
  /// milky white are light enough to need dark text; the browns and blacks do
  /// not.
  static Color onSwatchFor(String value) {
    switch (value) {
      case champagne:
      case dull:
      case milkyWhite:
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
