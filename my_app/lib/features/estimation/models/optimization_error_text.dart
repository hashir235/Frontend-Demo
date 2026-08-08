import 'dart:io';

/// One thing that went wrong, said in a way a fabricator can act on.
///
/// [title] names the problem in a few words; [message] says what happened and
/// what to do about it. [section] is filled when the engine named one, so the
/// screen can point straight at it.
class EstimationIssue {
  final String title;
  final String message;
  final String? section;

  const EstimationIssue({
    required this.title,
    required this.message,
    this.section,
  });

  /// Both parts as one block, for places that show a single string.
  String get combined => '$title\n$message';

  @override
  String toString() => combined;
}

/// Turns the engine's wording into something a fabricator can act on.
///
/// The engine speaks in its own terms -- "No feasible stock plan for section
/// D29 under the hard wastage cap (2ft)" -- which says nothing to someone
/// standing in a workshop. Worse, the usual cause is a mistyped stock length,
/// and the message never points there. A user once entered 238 (reading the
/// field as inches), every section failed, and it read as though the app was
/// broken.
///
/// Every message the engine and the API can produce is matched here. Anything
/// unrecognised is passed through untouched rather than swallowed -- a
/// mysterious message the user can quote to us beats a friendly one that hides
/// what actually happened.
class OptimizationErrorText {
  const OptimizationErrorText._();

  /// The full explanation for one raw engine message.
  static EstimationIssue explain(String raw) {
    final String text = raw.trim();
    final String lower = text.toLowerCase();
    final String? section = _sectionIn(text);
    final String which = section ?? 'a section';

    // ---------------------------------------------------------- lengths
    // The single most common failure, and the one whose real cause the engine
    // cannot see: either a piece is longer than every length allowed for that
    // section, or the allowed lengths simply cannot be combined without going
    // over the waste limit. Both are fixed in the same place, so the message
    // names both rather than guessing.
    if (lower.contains('no feasible stock plan')) {
      return EstimationIssue(
        section: section,
        title: 'Cutting could not be worked out for $which',
        message:
            'Either one piece is longer than every length you allow for $which, '
            'or those lengths cannot be combined without wasting more than the '
            'limit.\n\n'
            'Check two things: the window size you entered (a size typed in the '
            'wrong unit is the usual culprit), and the allowed lengths — open '
            'Recalculation, or Settings > Assigned Lengths. Lengths are in feet.',
      );
    }

    if (lower.contains('no allowed stock lengths configured') ||
        lower.contains('no section lengths found') ||
        lower.contains('section length list cannot be empty')) {
      return EstimationIssue(
        section: section,
        title: 'No lengths set for $which',
        message:
            'This section has no allowed lengths, so there is nothing to cut '
            'from. Open Settings > Assigned Lengths and give $which its lengths '
            'in feet — usually 14, 16 and 18, or 15, 17 and 19 for F sections.',
      );
    }

    if (lower.contains('invalid section length entry') ||
        lower.contains('invalid numeric entry') ||
        lower.contains('no values found in')) {
      return EstimationIssue(
        section: section,
        title: 'A length setting cannot be read',
        message:
            'One of the allowed lengths is not a usable number. Open Settings > '
            'Assigned Lengths and check the entries — they must be plain whole '
            'numbers in feet, between 4 and 30. A number like 238 means inches '
            'were typed into a feet field.',
      );
    }

    // ------------------------------------------------------------ rates
    if (lower.contains('missing rate for section')) {
      return EstimationIssue(
        section: section,
        title: 'No rate for $which',
        message:
            'There is no rate for $which at the gauge and colour you picked, so '
            'the cost cannot be worked out.\n\n'
            'Open Settings > Rates and set a rate for it, or go back and pick a '
            'different gauge or colour.',
      );
    }

    // ------------------------------------------------------------ units
    if (lower.contains('unitmode must be')) {
      return EstimationIssue(
        title: 'Unit is not set properly',
        message:
            'The app could not tell whether your sizes are in feet, inches or '
            'centimetres. Go back to the window and set the unit next to the '
            'size fields, then save again.',
      );
    }

    if (lower.contains('single sutter digit') ||
        lower.contains('suter must be in range') ||
        lower.contains('suter precision') ||
        lower.contains('suter value is invalid')) {
      return EstimationIssue(
        title: 'A size is written wrongly',
        message:
            'In inches mode the part after the dot is the sutter, and it must be '
            'a single digit from 0 to 7 — like 45.4, not 45.85.\n\n'
            'If you meant feet, change the unit next to the size fields first.',
      );
    }

    if (lower.contains('dimension format is invalid') ||
        lower.contains('inch value is invalid')) {
      return EstimationIssue(
        title: 'A size could not be read',
        message:
            'Enter the size as 45.4 (inch.sutter) or 4.6 (feet.inches). Check '
            'that the unit next to the size fields matches how you typed it.',
      );
    }

    if (lower.contains('must be positive') ||
        lower.contains('dimension must be greater than zero') ||
        lower.contains('inch must be greater than zero')) {
      return const EstimationIssue(
        title: 'A size is missing or zero',
        message:
            'One window has no height or width. Go back to the review list, open '
            'that window and fill in both sizes.',
      );
    }

    if (lower.contains('invalid archvalue')) {
      return const EstimationIssue(
        title: 'The arch measurement is wrong',
        message:
            'The arch value is missing or not a usable number. Open that window '
            'and enter the arch in the same unit as the rest of the sizes.',
      );
    }

    // --------------------------------------------------------- sections
    if (lower.contains('unsupported window code')) {
      return EstimationIssue(
        title: 'This window is not supported here',
        message:
            'One of the saved windows cannot be used in this flow${section != null ? ' ($section)' : ''}. '
            'Open the review list, delete that window and add it again from the '
            'window library.',
      );
    }

    if (lower.contains('sections array missing') ||
        lower.contains('no summaries found')) {
      return const EstimationIssue(
        title: 'No sections came back',
        message:
            'The cutting result has no sections in it. This usually means the '
            'windows were saved without sizes. Open the review list and check '
            'each window, then try again.',
      );
    }

    // --------------------------------------------------------- no input
    if (lower.contains('no windows found in estimation snapshot') ||
        lower.contains('no valid pieces found') ||
        lower.contains('pieces array missing')) {
      return const EstimationIssue(
        title: 'No windows to work with',
        message:
            'Nothing was saved for this project yet. Go back and add at least '
            'one window with its sizes, then come here again.',
      );
    }

    if (lower.contains('no valid glass pieces found') ||
        lower.contains('glasspieces array missing')) {
      return const EstimationIssue(
        title: 'No glass to report',
        message:
            'None of the saved windows have glass in them, so there is nothing '
            'for the glass report. Check the windows in the review list.',
      );
    }

    // ------------------------------------------------------- our fault
    if (lower.contains('failed to read estimation snapshot') ||
        lower.contains('failed to read optimization result') ||
        lower.contains('failed to write file') ||
        lower.contains('failed to read request json') ||
        lower.contains('object missing')) {
      return const EstimationIssue(
        title: 'The saved work could not be read',
        message:
            'Something went wrong on our side reading this project. Pull down to '
            'refresh and try again. If it keeps happening, message us on '
            'WhatsApp and we will look at it.',
      );
    }

    // A bare "<something> failed" from the service layer carries no detail.
    if (RegExp(r'^\w[\w ]* failed$').hasMatch(lower)) {
      return const EstimationIssue(
        title: 'That step did not finish',
        message:
            'The calculation stopped before it finished. Pull down to refresh '
            'and try again. If it keeps happening, check the window sizes and '
            'the unit first — that is where it usually goes wrong.',
      );
    }

    // Not something we recognise: show it as-is rather than hide it.
    return EstimationIssue(title: 'Something went wrong', message: text);
  }

  static List<EstimationIssue> explainAll(List<String> raw) =>
      raw.map(explain).toList(growable: false);

  /// Splits a already-explained "title\nmessage" back into its two halves.
  ///
  /// The API clients hand the screens one combined string (it travels through
  /// an exception message, which is a single field). A card that shows a title
  /// and a body needs them apart again.
  static (String, String) split(String combined) {
    final int newline = combined.indexOf('\n');
    if (newline <= 0) return ('Something went wrong', combined.trim());
    return (
      combined.substring(0, newline).trim(),
      combined.substring(newline + 1).trim(),
    );
  }

  /// A short, plain-language line for [raw]. Kept for callers that show a
  /// single string.
  static String friendly(String raw) => explain(raw).combined;

  static List<String> friendlyAll(List<String> raw) =>
      raw.map(friendly).toList(growable: false);

  /// Explains a failure that never reached the engine at all -- no network, the
  /// server down, a session that expired.
  ///
  /// These read as "the app is broken" to a user, when usually the phone simply
  /// lost signal, so they are named plainly.
  static EstimationIssue forTransport(Object error, {int? statusCode}) {
    if (error is SocketException) {
      return const EstimationIssue(
        title: 'No connection',
        message:
            'Your phone could not reach Quick AL. Check your internet or mobile '
            'data and try again — nothing you entered has been lost.',
      );
    }
    if (error is HttpException || error is HandshakeException) {
      return const EstimationIssue(
        title: 'Connection dropped',
        message:
            'The connection broke while the calculation was running. Pull down '
            'to refresh and try again.',
      );
    }

    switch (statusCode) {
      case 401:
      case 403:
        return const EstimationIssue(
          title: 'You have been signed out',
          message:
              'Your session ended. Close the app, open it again and sign in — '
              'your projects are safe.',
        );
      case 402:
        return const EstimationIssue(
          title: 'Your plan has ended',
          message:
              'This feature needs an active plan. Open Settings > Billing & '
              'Plans to continue.',
        );
      case 408:
      case 504:
        return const EstimationIssue(
          title: 'It took too long',
          message:
              'The server did not answer in time. This can happen with a very '
              'large project on a slow connection. Try again in a moment.',
        );
      case 429:
        return const EstimationIssue(
          title: 'Too many tries',
          message: 'Please wait a minute, then try again.',
        );
    }

    if (statusCode != null && statusCode >= 500) {
      return const EstimationIssue(
        title: 'The server had a problem',
        message:
            'This one is on us, not on your data. Try again in a moment. If it '
            'keeps happening, message us on WhatsApp.',
      );
    }

    // Anything genuinely unexpected -- keep the original wording visible.
    return EstimationIssue(
      title: 'Could not reach the service',
      message: error.toString(),
    );
  }

  /// Pulls "D29" out of "... for section D29 under ...".
  static String? _sectionIn(String text) {
    final RegExpMatch? m = RegExp(
      r'section\s+([A-Za-z0-9_]+)',
      caseSensitive: false,
    ).firstMatch(text);
    return m?.group(1);
  }
}
