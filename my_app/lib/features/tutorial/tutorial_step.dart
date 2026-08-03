import 'package:flutter/widgets.dart';

/// Where a tutorial step lives. The tutorial walks the user through several
/// screens, so each step says which screen it belongs to; the overlay only
/// shows a step once the matching screen is on top.
enum TutorialScreen {
  home,
  windowLibrary,
  windowInput,
  lengthOptimization,
  sectionRecalculation,
  materialSelection,
  materialTable,
  billInputs,
  actualBill,
}

/// How the spotlight hole is shaped around the target.
enum SpotlightShape { rect, circle }

/// One stop on the guided tour.
///
/// A step either points at a real widget on screen (via [targetId], registered
/// by a [TutorialTarget]) or, when [targetId] is null, shows its text centred
/// with no cutout -- used for the opening and closing messages.
@immutable
class TutorialStep {
  /// Which screen this step waits for.
  final TutorialScreen screen;

  /// Matches the id given to a [TutorialTarget]. Null means "no spotlight".
  final String? targetId;

  /// Urdu heading, in Nastaliq.
  final String title;

  /// Urdu explanation, in Naskh.
  final String body;

  final SpotlightShape shape;

  /// Extra breathing room around the highlighted widget.
  final double padding;

  /// When true the user must actually tap the highlighted widget to go on --
  /// the Next button is hidden. Used where the tap is the thing being taught,
  /// like opening the sidebar or moving to the next screen.
  final bool requiresTap;

  /// Shown under the body as a nudge, e.g. "یہاں دبائیں".
  final String? tapHint;

  const TutorialStep({
    required this.screen,
    required this.title,
    required this.body,
    this.targetId,
    this.shape = SpotlightShape.rect,
    this.padding = 8,
    this.requiresTap = false,
    this.tapHint,
  });
}
