/// A window measured one side at a time.
library;

import 'window_measurements.dart';

/// The sides of a window, named as its frame names them.
///
/// A wall is never quite square. The top of an opening can be half an inch
/// wider than its bottom, and a fabricator who has measured both wants the
/// frame cut to what they measured -- the head to the top, the sill to the
/// bottom -- while everything inside the frame is cut to the smaller of the
/// two, because a sash cut to the wider one will not go in.
///
/// The names are the frame's own piece labels, so nothing has to be translated
/// between what is typed and what is cut: WT is the head, WB the sill, HL and
/// HR the two jambs, and a corner window's two walls carry WT_l/WB_l and
/// WT_r/WB_r.
class WindowSide {
  const WindowSide._();

  static const String top = 'WT';
  static const String bottom = 'WB';
  static const String left = 'HL';
  static const String right = 'HR';
  static const String topLeft = 'WT_l';
  static const String topRight = 'WT_r';
  static const String bottomLeft = 'WB_l';
  static const String bottomRight = 'WB_r';

  /// Every side this feature knows, in the order they are read out.
  static const List<String> all = <String>[
    top,
    topLeft,
    topRight,
    left,
    right,
    bottom,
    bottomLeft,
    bottomRight,
  ];

  /// The side facing this one. A side left empty is taken as its opposite --
  /// which is what a fabricator means by measuring one of them.
  static const Map<String, String> facing = <String, String>{
    top: bottom,
    bottom: top,
    left: right,
    right: left,
    topLeft: bottomLeft,
    bottomLeft: topLeft,
    topRight: bottomRight,
    bottomRight: topRight,
  };

  /// The measurement each side stands for, in the names formulas use.
  static const Map<String, String> dimension = <String, String>{
    top: 'w',
    bottom: 'w',
    left: 'h',
    right: 'h',
    topLeft: 'wl',
    bottomLeft: 'wl',
    topRight: 'wr',
    bottomRight: 'wr',
  };

  /// What a fabricator calls it.
  static String labelOf(String side) {
    switch (side) {
      case top:
        return 'Top';
      case bottom:
        return 'Bottom';
      case left:
        return 'Left';
      case right:
        return 'Right';
      case topLeft:
        return 'Top left';
      case topRight:
        return 'Top right';
      case bottomLeft:
        return 'Bottom left';
      case bottomRight:
        return 'Bottom right';
    }
    return side;
  }

  /// Whether this side is a width. The rest are heights.
  static bool isWidth(String side) => dimension[side] != 'h';

  /// The sides of [labels] that this feature can take, in reading order.
  static List<String> orderedFrom(Iterable<String> labels) {
    final Set<String> given = labels.toSet();
    return <String>[
      for (final String side in all)
        if (given.contains(side)) side,
    ];
  }
}

/// What a fabricator typed for each side of one window.
///
/// The strings are kept exactly as typed, in the same notation as every other
/// size in the app, so what is shown back is what was written. A side left
/// blank is not a missing measurement: it is the one facing it.
class SideSizes {
  const SideSizes(this._bySide);

  const SideSizes.empty() : _bySide = const <String, String>{};

  final Map<String, String> _bySide;

  bool get isEmpty => _bySide.values.every((String value) => value.trim().isEmpty);
  bool get isNotEmpty => !isEmpty;

  /// The sides that carry something, in reading order.
  List<String> get sides => WindowSide.orderedFrom(
        _bySide.entries
            .where((MapEntry<String, String> e) => e.value.trim().isNotEmpty)
            .map((MapEntry<String, String> e) => e.key),
      );

  /// What was typed for this side, exactly as typed.
  String raw(String side) => (_bySide[side] ?? '').trim();

  /// What this side measures: its own, or -- left blank -- the side facing it.
  String effective(String side) {
    final String own = raw(side);
    if (own.isNotEmpty) return own;
    final String? facing = WindowSide.facing[side];
    return facing == null ? '' : raw(facing);
  }

  SideSizes withSide(String side, String value) {
    return SideSizes(<String, String>{..._bySide, side: value});
  }

  /// Only the sides this window has, so a size typed for a side that has since
  /// gone -- a door's bottom, a collar change -- cannot be cut to.
  SideSizes keepingOnly(Iterable<String> sides) {
    final Set<String> keep = sides.toSet();
    return SideSizes(<String, String>{
      for (final MapEntry<String, String> entry in _bySide.entries)
        if (keep.contains(entry.key) && entry.value.trim().isNotEmpty)
          entry.key: entry.value.trim(),
    });
  }

  /// The smaller of these sides, exactly as it was typed.
  ///
  /// This is the size everything inside the frame is cut to, and the size the
  /// rest of Quick AL is told the window is -- the glass, the piece labels,
  /// the history. The wider edge belongs to the frame alone.
  String? smallestRaw(Iterable<String> sides, {required String unitMode}) {
    String? smallest;
    double? held;
    for (final String side in sides) {
      final String raw = effective(side);
      if (raw.isEmpty) continue;
      final double? value = WindowMeasurements.readOne(
        isFabrication: true,
        unitMode: unitMode,
        value: raw,
      );
      if (value == null) continue;
      if (held == null || value < held) {
        held = value;
        smallest = raw;
      }
    }
    return smallest;
  }

  /// The sides as a fabricator would read them out: the widths, then the
  /// heights, with a pair that differs written "44.5/46".
  String describe(List<String> sides) {
    String group(Iterable<String> group) {
      final List<String> written = <String>[];
      for (final String side in group) {
        final String raw = effective(side);
        if (raw.isNotEmpty && !written.contains(raw)) written.add(raw);
      }
      return written.join('/');
    }

    final List<String> widths = <String>[
      for (final String dimension in <String>['w', 'wl', 'wr'])
        group(sides.where((String side) => WindowSide.dimension[side] == dimension)),
    ].where((String part) => part.isNotEmpty).toList();
    final String heights =
        group(sides.where((String side) => WindowSide.dimension[side] == 'h'));

    if (widths.isEmpty && heights.isEmpty) return '';
    if (widths.isEmpty) return heights;
    if (heights.isEmpty) return widths.join(' | ');
    return '${widths.join(' | ')} x $heights';
  }

  Map<String, Object?> toJson() => <String, Object?>{
        for (final MapEntry<String, String> entry in _bySide.entries)
          if (entry.value.trim().isNotEmpty) entry.key: entry.value.trim(),
      };

  static SideSizes fromJson(Object? json) {
    if (json is! Map) return const SideSizes.empty();
    final Map<String, String> read = <String, String>{};
    json.forEach((Object? side, Object? value) {
      if (side is! String || value is! String) return;
      if (!WindowSide.all.contains(side)) return;
      final String trimmed = value.trim();
      if (trimmed.isEmpty) return;
      read[side] = trimmed;
    });
    return SideSizes(read);
  }

  @override
  bool operator ==(Object other) {
    if (other is! SideSizes) return false;
    final Map<String, Object?> mine = toJson();
    final Map<String, Object?> theirs = other.toJson();
    if (mine.length != theirs.length) return false;
    for (final MapEntry<String, Object?> entry in mine.entries) {
      if (theirs[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAllUnordered(
        toJson().entries.map((MapEntry<String, Object?> e) => Object.hash(e.key, e.value)),
      );

  @override
  String toString() => toJson().toString();
}

/// One window's sides, read into numbers a formula can use.
class SideMeasurements {
  const SideMeasurements._(this.bySide, this.inner);

  /// Each side's own measurement, blanks already taken from the side facing.
  final Map<String, double> bySide;

  /// What everything inside the frame is cut to: the smaller of each pair.
  final Map<String, double> inner;

  /// Why the sides could not be read, if they could not.
  static String? lastProblem;

  /// Reads the sides of one window.
  ///
  /// [sizes] is what was typed, [sides] the sides this window actually has.
  /// Returns null when a side cannot be read or a pair was left empty
  /// altogether -- a window with no width is not a window that can be cut, and
  /// guessing at one is the worst possible answer.
  static SideMeasurements? read({
    required String unitMode,
    required SideSizes sizes,
    required List<String> sides,
  }) {
    lastProblem = null;
    if (sides.isEmpty) {
      lastProblem = 'this window has no sides to measure';
      return null;
    }

    final Map<String, double> bySide = <String, double>{};
    for (final String side in sides) {
      final String typed = sizes.effective(side);
      if (typed.isEmpty) {
        lastProblem =
            '${WindowSide.labelOf(side)} is empty, and so is the side facing it';
        return null;
      }
      final double? value = WindowMeasurements.readOne(
        isFabrication: true,
        unitMode: unitMode,
        value: typed,
      );
      if (value == null) {
        lastProblem =
            '${WindowSide.labelOf(side)}: ${WindowMeasurements.lastProblem ?? 'cannot be read'}';
        return null;
      }
      bySide[side] = value;
    }

    // What the pieces inside the frame are cut to. Taken per measurement --
    // a corner window's two walls are two different widths, and the smaller of
    // one wall says nothing about the other.
    final Map<String, double> smallest = <String, double>{};
    bySide.forEach((String side, double value) {
      final String? dimension = WindowSide.dimension[side];
      if (dimension == null) return;
      final double? held = smallest[dimension];
      if (held == null || value < held) smallest[dimension] = value;
    });

    final double? h = smallest['h'];
    final double? w = smallest['w'];
    final double? wl = smallest['wl'];
    final double? wr = smallest['wr'];
    if (h == null) {
      lastProblem = 'this window has no height';
      return null;
    }
    // A corner window is measured as two walls and has no single width; a
    // straight one has no left and right. Each fills in for the other so every
    // formula has the name it reads, whichever kind of window it is.
    final double width = w ?? (wl != null && wr != null ? (wl < wr ? wl : wr) : (wl ?? wr ?? 0));
    if (width <= 0) {
      lastProblem = 'this window has no width';
      return null;
    }

    return SideMeasurements._(
      Map<String, double>.unmodifiable(bySide),
      Map<String, double>.unmodifiable(<String, double>{
        'h': h,
        'w': width,
        'wl': wl ?? width,
        'wr': wr ?? width,
        'ar': 0,
      }),
    );
  }
}
