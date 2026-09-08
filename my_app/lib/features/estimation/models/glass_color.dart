import 'package:flutter/material.dart';

import '../../settings/models/bill_defaults.dart';

/// The glass a window is glazed in.
///
/// Like the aluminium finish, this belongs to the window rather than the job:
/// a bathroom goes in obscured glass while the room next to it is clear, and a
/// shop that had to pick one glass for a whole project would price at least one
/// of those wrong.
///
/// The names come straight from [GlassTypes.all] -- the same list the rates
/// screen prices -- so a colour picked here always has somewhere for its rate
/// to live. A separate list would drift, and the day it did a job would be
/// glazed in something the bill had no price for.
class GlassColors {
  const GlassColors._();

  static List<String> get all => GlassTypes.all;

  /// What the first window of a new job starts on. Clear is the commonest
  /// glass and the cheapest to be wrong about.
  static const String initial = 'Clear Glass';

  /// Falls back to clear for anything unrecognised -- a type dropped from the
  /// rate list, or a window saved before glass was a per-window choice.
  static String normalize(String? value) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return initial;
    return GlassTypes.match(v) ?? initial;
  }

  /// Roughly what the glass looks like held up to the light.
  ///
  /// For the eye only, and that is the point: a fitter who cannot read English
  /// picks "Green Mercury" by seeing green with a mirrored sheen, not by
  /// spelling it out. Mercury is the mirrored back, so it reads brighter and
  /// harder than the plain tint of the same colour.
  static Color swatchFor(String value) {
    switch (GlassTypes.match(value) ?? value) {
      case 'Clear Glass':
        return const Color(0xFFDDE9F0);
      case 'Green Mercury':
        return const Color(0xFF3E8E6E);
      case 'Green Simple':
        return const Color(0xFF7FB09A);
      case 'Brown Mercury':
        return const Color(0xFF7A5230);
      case 'Brown Simple':
        return const Color(0xFFB08A62);
      case 'Blue Mercury':
        return const Color(0xFF2E5F9E);
      case 'Blue Simple':
        return const Color(0xFF8FAFD4);
      case 'Gray Mercury':
        return const Color(0xFF55606B);
      case 'Gray Simple':
        return const Color(0xFFA3ADB6);
      case 'Ocean Blue':
        return const Color(0xFF1F7A8C);
      default:
        return const Color(0xFFDDE9F0);
    }
  }

  /// Whether the swatch is mirrored, so the chip can show that without a word.
  static bool isMercury(String value) =>
      (GlassTypes.match(value) ?? value).toLowerCase().contains('mercury');

  /// Text that stays readable on top of [swatchFor].
  static Color onSwatchFor(String value) {
    switch (GlassTypes.match(value) ?? value) {
      case 'Clear Glass':
      case 'Green Simple':
      case 'Blue Simple':
      case 'Gray Simple':
      case 'Brown Simple':
        return const Color(0xFF1B2430);
      default:
        return Colors.white;
    }
  }

  /// The short name, for a chip or a line under a window where the full name
  /// would crowd out the size.
  static String shortLabelFor(String value) {
    final String name = GlassTypes.match(value) ?? value;
    if (name == 'Clear Glass') return 'Clear';
    if (name == 'Ocean Blue') return 'Ocean';
    // "Green Mercury" -> "Green Mer.", which still tells the two greens apart
    // in the width a chip has.
    if (name.endsWith(' Mercury')) {
      return '${name.substring(0, name.length - 8)} Mer.';
    }
    if (name.endsWith(' Simple')) {
      return name.substring(0, name.length - 7);
    }
    return name;
  }
}
