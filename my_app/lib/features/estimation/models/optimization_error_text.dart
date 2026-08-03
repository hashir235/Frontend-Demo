/// Turns the engine's wording into something a fabricator can act on.
///
/// The engine speaks in its own terms -- "No feasible stock plan for section
/// D29 under the hard wastage cap (2ft)" -- which says nothing to someone
/// standing in a workshop. Worse, the usual cause is a mistyped stock length,
/// and the message never points there. A user once entered 238 (reading the
/// field as inches), every section failed, and it read as though the app was
/// broken.
class OptimizationErrorText {
  const OptimizationErrorText._();

  /// A short, plain-language line for [raw], or [raw] itself when it is not a
  /// message we recognise -- never swallow something we do not understand.
  static String friendly(String raw) {
    final String text = raw.trim();
    final String lower = text.toLowerCase();

    if (lower.contains('no feasible stock plan')) {
      final String which = _sectionIn(text) ?? 'a section';
      return 'The lengths you allowed for $which cannot cut these pieces '
          'without wasting more than the limit. Open Recalculation and check '
          'those lengths — they are in feet.';
    }

    if (lower.contains('single sutter digit')) {
      return 'A size looks wrong. In inches mode the part after the dot is '
          'the sutter and must be a single digit 0-7, like 45.4';
    }

    if (lower.contains('must be positive')) {
      return 'A height or width is missing or zero. Check the window sizes.';
    }

    if (lower.contains('dimension format is invalid')) {
      return 'A size could not be read. Enter it like 45.4 (inch.sutter) or '
          '4.6 (feet.inches).';
    }

    return text;
  }

  static List<String> friendlyAll(List<String> raw) =>
      raw.map(friendly).toList(growable: false);

  /// Pulls "D29" out of "... for section D29 under ...".
  static String? _sectionIn(String text) {
    final RegExpMatch? m = RegExp(
      r'section\s+([A-Za-z0-9_]+)',
      caseSensitive: false,
    ).firstMatch(text);
    return m?.group(1);
  }
}
