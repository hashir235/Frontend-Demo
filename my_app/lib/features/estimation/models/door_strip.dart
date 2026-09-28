/// Strips: aluminium laid inside a door where glass would go.
///
/// A door can be closed in with strips instead of glass: short pieces, each as
/// long as the glass is wide, laid one above another until they cover the
/// glass's height. A fabricator picks one strip profile for a door, or none.
library;

/// One strip profile and how much height one piece of it covers.
class DoorStrip {
  const DoorStrip(this.section, this.widthMm);

  /// The profile, as it is cut and priced: "D61A".
  final String section;

  /// The face width of one strip, in millimetres.
  final double widthMm;

  /// How many strips cover a pane [heightCm] high: the fewest whose widths
  /// add up to the height or more -- P1 + P2 + ... >= the glass's height.
  int piecesFor(double heightCm) {
    if (heightCm <= 0) return 0;
    // A hair of tolerance, so a height that is an exact number of strips is
    // not given one more for a rounding error in the last decimal.
    return (heightCm * 10 / widthMm - 1e-9).ceil();
  }
}

/// The strips the app knows.
class DoorStrips {
  const DoorStrips._();

  static const List<DoorStrip> all = <DoorStrip>[
    DoorStrip('D61A', 100.80),
    DoorStrip('D61H', 107.42),
    DoorStrip('PATTI4', 113.61),
    DoorStrip('PATTI6', 151.19),
  ];

  /// The strip cut from [section], or null for none or one the app does not
  /// know.
  static DoorStrip? of(String? section) {
    if (section == null) return null;
    for (final DoorStrip strip in all) {
      if (strip.section == section.trim()) return strip;
    }
    return null;
  }

  /// Whether a window with this code can take strips: the doors.
  static bool offeredOn(String? windowCode) =>
      windowCode == 'Single_Door' || windowCode == 'Double_Door';
}
