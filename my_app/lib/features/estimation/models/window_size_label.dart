import '../../../shared/format/suter_half.dart';
import '../presentation/input/size_entry_notation.dart';

/// A window's size as the cutting list and the glass list name it: width
/// first, then height -- the way a shop measures and writes a window -- each
/// in the unit the window was measured in: `60'' x 48'' 3.5'''`, `5' x 4' 9''`,
/// `150 x 120 cm`.
///
/// The engine used to write the raw stored numbers height first
/// (`48.35x60`), which no one could read at a glance and which put the
/// height where everyone looks for the width (Hashir, Oct 2026). The app now
/// sends this text with each window and the engine labels its cuts with it.
///
/// Composed with the half in decimal (`3.5'''`), as every size on the wire
/// is; [shown] turns it into ½ -- and half a suter alone into 0½ -- where it
/// reaches the eye, as the PDFs do.
class WindowSizeLabel {
  const WindowSizeLabel._();

  /// The label for one window. [unit] is `inches` (inch.suter), `feet`
  /// (feet.inch) or `cm`; the sizes are in the stored notation of that unit.
  /// [right] and [left] are a corner window's two widths, [arch] an arched
  /// window's rise.
  static String compose({
    required String unit,
    required String height,
    required String width,
    String? right,
    String? left,
    String? arch,
  }) {
    final bool cm = unit == 'cm';
    final bool split = (right ?? '').trim().isNotEmpty || (left ?? '').trim().isNotEmpty;
    final String widthText = split
        ? '${_part(_or(right, width), unit)} / ${_part(_or(left, width), unit)}'
        : _part(width, unit);
    final StringBuffer out = StringBuffer('$widthText x ${_part(height, unit)}');
    if (cm) out.write(' cm');
    if ((arch ?? '').trim().isNotEmpty) {
      out.write(', arch ${_part(arch!, unit)}');
      if (cm) out.write(' cm');
    }
    // The engine's label is "name #no -> size | piece": nothing in a size may
    // look like one of those separators.
    return out.toString().replaceAll(RegExp(r'[|#>]'), '');
  }

  static String _or(String? value, String fallback) =>
      (value ?? '').trim().isEmpty ? fallback : value!;

  /// One stored size in its own unit: `34.35` -> `34'' 3.5'''`,
  /// `34.05` -> `34'' 0.5'''`, `34` -> `34''`, `4.9` (feet) -> `4' 9''`,
  /// `120.5` (cm) -> `120.5`.
  static String _part(String raw, String unit) {
    final String value = raw.trim();
    if (value.isEmpty || unit == 'cm') return value;
    if (unit == 'feet') {
      final ({String inch, String suter}) parts = SizeNotation.splitStoredFeet(value);
      final String inches = parts.suter;
      return inches.isEmpty || inches == '0'
          ? "${parts.inch}'"
          : "${parts.inch}' $inches''";
    }
    final ({String inch, String suter}) parts = SizeNotation.splitStoredInches(value);
    final double? suter = double.tryParse(parts.suter);
    if (parts.suter.isEmpty || suter == null || suter == 0) return "${parts.inch}''";
    final double halved = (suter * 2).roundToDouble() / 2;
    final String suterText = halved == halved.truncateToDouble()
        ? '${halved.toInt()}'
        : halved.toStringAsFixed(1);
    return "${parts.inch}'' $suterText'''";
  }

  // The engine's own label before this: raw numbers, height first --
  // `48.35x60`, `54.5x30/40` for a corner, `54.5x44.5 a:10` with an arch.
  static final RegExp _engineRaw = RegExp(
    r'^\s*(?<height>[\d.]+)\s*x\s*(?<width>[\d.]+(?:/[\d.]+)?)(?<arch>\s+a:\S+)?\s*$',
    caseSensitive: false,
  );

  /// A size from a cutting or glass report, as it is shown: the half as ½
  /// (and half alone as 0½). A report made before the app sent its own label
  /// carries the engine's raw height-first numbers; those are at least turned
  /// round, width first, as the PDFs have long done.
  static String shown(String dimension) {
    final String text = dimension.trim();
    final RegExpMatch? raw = _engineRaw.firstMatch(text);
    if (raw != null) {
      return '${raw.namedGroup('width')}x${raw.namedGroup('height')}'
          '${raw.namedGroup('arch') ?? ''}';
    }
    return SuterHalf.inText(text);
  }
}
