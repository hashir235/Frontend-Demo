/// One piece of one window, cut as if the window measured something else.
library;

import 'formula_overrides.dart';

/// A size a fabricator set for a single piece of a single window.
///
/// The formula screen shows every piece worked out on the window's own
/// measurement, boxed inside the formula. Typing a different number into that
/// box used to be a question only -- "what would this piece come to?" -- and
/// was forgotten when the screen closed, so the cutting list went on cutting
/// the piece to the window's size. Now it is kept: this piece, in this window,
/// is cut as though the window measured [size].
///
/// It belongs to the window and nothing wider. A formula a workshop changes is
/// how every window like this one is cut from then on; a size is about this
/// opening on this site, and reaching any other window with it would cut that
/// window wrong.
///
/// It also belongs to the measurement it was set against, [base]. A size set
/// for a 152.4cm window says nothing about the same window re-measured at
/// 160cm, so once the window's own measurement moves the size no longer
/// stands -- see [standsFor].
class PieceSize {
  const PieceSize({
    required this.ref,
    required this.label,
    required this.dimension,
    required this.base,
    required this.size,
  });

  /// Which piece: the window configuration, the profile and the position in
  /// it -- the same identity a changed formula is kept under.
  final FormulaPieceRef ref;

  /// What the piece is called on the cutting list, for saying which one has a
  /// size of its own.
  final String label;

  /// The measurement the size stands in for -- `h`, `w`, `wl`, `wr` or `ar`.
  final String dimension;

  /// The window's own measurement when the size was set, in the formula's
  /// units: centimetres on the fabrication side, feet on the estimation side.
  final double base;

  /// The measurement this piece is cut to instead, in the same units.
  final double size;

  /// How close two readings of one measurement have to be to be the same
  /// measurement. Far finer than anything a tape reads, and far coarser than
  /// the rounding a number picks up on its way through a conversion.
  static const double _sameMeasurement = 0.0005;

  /// Whether this size still applies to a window measuring [current].
  bool standsFor(double current) => (current - base).abs() <= _sameMeasurement;

  /// This window's own size for [ref], if it has one.
  static PieceSize? find(Iterable<PieceSize> sizes, FormulaPieceRef ref) {
    for (final PieceSize size in sizes) {
      if (size.ref == ref) return size;
    }
    return null;
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'windowKey': ref.windowKey,
      'configKey': ref.configKey,
      'section': ref.section,
      'index': ref.index,
      'label': label,
      'dimension': dimension,
      'base': base,
      'size': size,
    };
  }

  /// Reads one back, or null if it is not a size that can be cut to.
  ///
  /// Anything malformed is dropped rather than guessed at: a piece cut to a
  /// half-read size is worse than one cut to the window's own.
  static PieceSize? fromJson(Object? json) {
    if (json is! Map) return null;
    final Object? windowKey = json['windowKey'];
    final Object? configKey = json['configKey'];
    final Object? section = json['section'];
    final Object? index = json['index'];
    final Object? label = json['label'];
    final Object? dimension = json['dimension'];
    final Object? base = json['base'];
    final Object? size = json['size'];
    if (windowKey is! String ||
        configKey is! String ||
        section is! String ||
        index is! num ||
        dimension is! String ||
        base is! num ||
        size is! num) {
      return null;
    }
    if (!base.isFinite || !size.isFinite || base <= 0 || size <= 0) {
      return null;
    }
    return PieceSize(
      ref: FormulaPieceRef(
        windowKey: windowKey,
        configKey: configKey,
        section: section,
        index: index.toInt(),
      ),
      label: label is String ? label : '',
      dimension: dimension,
      base: base.toDouble(),
      size: size.toDouble(),
    );
  }

  static List<PieceSize> listFromJson(Object? json) {
    if (json is! List) return const <PieceSize>[];
    return <PieceSize>[
      for (final Object? entry in json) ?PieceSize.fromJson(entry),
    ];
  }

  @override
  bool operator ==(Object other) =>
      other is PieceSize &&
      other.ref == ref &&
      other.label == label &&
      other.dimension == dimension &&
      other.base == base &&
      other.size == size;

  @override
  int get hashCode => Object.hash(ref, label, dimension, base, size);

  @override
  String toString() => '$ref $label: $dimension $base -> $size';
}
