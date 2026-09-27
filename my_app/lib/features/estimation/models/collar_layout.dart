/// Which sides of a window carry a collar, for every collar type it has.
///
/// A collar type is a number the engine cuts by -- collar 7 of a sliding
/// window is "collar on the bottom and the right, none on the top or the
/// left". The window input screen lets a fabricator tap a side of the drawing
/// to put a collar on or take it off, and this is what turns that tap back
/// into the collar number.
///
/// The tables are the engine's own, read off the formula catalogue (each side
/// is cut from its collar profile -- DC30F, D54F, M30F... -- or from the plain
/// one), and a test holds them against the catalogue so they cannot drift.
/// They also match the collar drawings side for side.
library;

import 'window_variant.dart';

/// A side of a window's frame that can carry a collar.
enum CollarSide { top, bottom, left, right }

/// The collar types of one kind of window.
class CollarLayout {
  const CollarLayout._(this.sides, this._collars);

  /// The sides a fabricator can tap one at a time. Empty when the window
  /// only comes with a collar all round or none at all (corner windows, the
  /// corner fix, the round arch): then a tap anywhere switches the lot.
  final List<CollarSide> sides;

  final Map<int, Set<CollarSide>> _collars;

  /// Collar all round or none at all -- there is nothing in between.
  bool get isWholeFrame => sides.isEmpty;

  /// How many collar types there are.
  int get collarCount => _collars.length;

  /// The collar types, by number.
  Iterable<int> get collars => _collars.keys;

  /// Whether collar [collar] is one this window comes in.
  bool offers(int collar) => _collars.containsKey(collar);

  /// Whether the window comes in one collar type only -- then there is
  /// nothing to tap between.
  bool get isFixed => _collars.length == 1;

  /// [collar] if the window comes in it, otherwise the nearest one it does:
  /// a collar remembered from another window, or saved before the window's
  /// collars were narrowed, never reaches the screen as one it cannot cut.
  int nearestOffered(int collar) {
    if (offers(collar)) return collar;
    int best = _collars.keys.first;
    for (final int candidate in _collars.keys) {
      if ((candidate - collar).abs() < (best - collar).abs()) best = candidate;
    }
    return best;
  }

  /// The same window, offering only [only] of its collars.
  CollarLayout offering(Iterable<int> only) => CollarLayout._(
    sides,
    <int, Set<CollarSide>>{
      for (final int collar in only)
        if (_collars.containsKey(collar)) collar: _collars[collar]!,
    },
  );

  /// The sides collar [collar] puts a collar on. Empty for an unknown number.
  Set<CollarSide> sidesWithCollar(int collar) =>
      _collars[collar] ?? const <CollarSide>{};

  /// The collar type with exactly these sides collared, or null when the
  /// engine has no such collar.
  int? collarWith(Set<CollarSide> collared) {
    for (final MapEntry<int, Set<CollarSide>> entry in _collars.entries) {
      if (entry.value.length == collared.length &&
          entry.value.containsAll(collared)) {
        return entry.key;
      }
    }
    return null;
  }

  /// The collar type after [side] is tapped on [collar]: that side's collar
  /// taken off if it had one, put on if it did not.
  ///
  /// Null when no collar type has that result -- a sliding window has no
  /// collar with only the top and right collared, for one -- or when [side]
  /// is not a side this window can collar on its own.
  int? toggle(int collar, CollarSide side) {
    if (isWholeFrame || !sides.contains(side)) return null;
    final Set<CollarSide> next = <CollarSide>{...sidesWithCollar(collar)};
    if (!next.remove(side)) next.add(side);
    return collarWith(next);
  }

  /// The collar type after a tap on a whole-frame window: collar all round
  /// becomes none, and none becomes all round. Null when the window does not
  /// come in the other one.
  int? toggleWholeFrame(int collar) {
    final int next = collar == 1 ? 2 : 1;
    return offers(next) ? next : null;
  }

  /// The layout for one of the app's window types, or null for one it does
  /// not know.
  ///
  /// A variant window (see [WindowVariants]) has its base window's layout,
  /// offering only the collars it comes in.
  static CollarLayout? forWindow(String windowCode) {
    final WindowVariant? variant = WindowVariants.of(windowCode);
    if (variant != null) {
      final CollarLayout? base = forWindow(variant.baseCode);
      final List<int>? only = variant.collars;
      return only == null ? base : base?.offering(only);
    }
    switch (windowCode) {
      // Four sides, fourteen collars: sliding, panel (plain and M-section),
      // fix and openable windows all share one table.
      case 'S_win':
      case 'MS_win':
      case 'PF3_win':
      case 'PS4_win':
      case 'EF3_win':
      case 'ES3_win':
      case 'MPF3_win':
      case 'MPS4_win':
      case 'MEF3_win':
      case 'MES3_win':
      case 'F_win':
      case 'O_win':
        return _fourSides;
      // A door has no bottom frame: three sides, every combination.
      case 'Single_Door':
      case 'Double_Door':
        return _door;
      // The rectangle arch never has a bottom collar either -- but its eight
      // collars are numbered differently from the door's.
      case 'AR_win':
        return _rectangleArch;
      // Collar all round or none.
      case 'A_win':
      case 'FC_win':
      case 'SCF_win':
      case 'SCS_win':
      case 'SCL_win':
      case 'SCR_win':
      case 'MSCF_win':
      case 'MSCS_win':
      case 'MSCL_win':
      case 'MSCR_win':
        return _wholeFrame;
    }
    return null;
  }

  static const CollarSide _t = CollarSide.top;
  static const CollarSide _b = CollarSide.bottom;
  static const CollarSide _l = CollarSide.left;
  static const CollarSide _r = CollarSide.right;

  /// Sixteen ways to collar four sides, fourteen collar types: there is none
  /// with only the top and right collared, and none with only the bottom and
  /// left.
  static const CollarLayout _fourSides = CollarLayout._(
    <CollarSide>[_t, _b, _l, _r],
    <int, Set<CollarSide>>{
      1: <CollarSide>{_t, _b, _l, _r},
      2: <CollarSide>{},
      3: <CollarSide>{_b, _l, _r},
      4: <CollarSide>{_t, _b, _l},
      5: <CollarSide>{_t, _l, _r},
      6: <CollarSide>{_t, _b, _r},
      7: <CollarSide>{_b, _r},
      8: <CollarSide>{_t, _l},
      9: <CollarSide>{_l, _r},
      10: <CollarSide>{_t, _b},
      11: <CollarSide>{_t},
      12: <CollarSide>{_r},
      13: <CollarSide>{_b},
      14: <CollarSide>{_l},
    },
  );

  static const CollarLayout _door = CollarLayout._(
    <CollarSide>[_t, _l, _r],
    <int, Set<CollarSide>>{
      1: <CollarSide>{_t, _l, _r},
      2: <CollarSide>{},
      3: <CollarSide>{_t, _r},
      4: <CollarSide>{_l, _r},
      5: <CollarSide>{_t, _l},
      6: <CollarSide>{_r},
      7: <CollarSide>{_l},
      8: <CollarSide>{_t},
    },
  );

  static const CollarLayout _rectangleArch = CollarLayout._(
    <CollarSide>[_t, _l, _r],
    <int, Set<CollarSide>>{
      1: <CollarSide>{_t, _l, _r},
      2: <CollarSide>{},
      3: <CollarSide>{_t, _r},
      4: <CollarSide>{_l, _r},
      5: <CollarSide>{_t, _l},
      6: <CollarSide>{_t},
      7: <CollarSide>{_l},
      8: <CollarSide>{_r},
    },
  );

  static const CollarLayout _wholeFrame = CollarLayout._(
    <CollarSide>[],
    <int, Set<CollarSide>>{
      1: <CollarSide>{_t, _b, _l, _r},
      2: <CollarSide>{},
    },
  );
}
