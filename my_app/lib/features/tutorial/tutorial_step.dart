import 'package:flutter/widgets.dart';

/// Where a tutorial step lives. The tutorial walks the user through several
/// screens, so each step says which screen it belongs to; the overlay only
/// shows a step once the matching screen is on top.
/// Which walkthrough is running. They are separate journeys with separate
/// buttons, and each remembers on its own whether it has been shown.
enum TutorialTour { estimation, fabrication }

enum TutorialScreen {
  home,

  /// The Fabrication landing screen -- Create Project and Glass Report.
  fabricationMenu,

  /// The Estimation landing screen -- recent projects and "Create Project".
  projectMenu,
  windowLibrary,
  windowInput,

  /// The saved-windows list reached by the Next arrow -- recheck, edit, delete.
  reviewList,
  lengthOptimization,
  sectionRecalculation,
  materialSelection,

  /// The "Rate Setting" screen -- section, total feet and the rate per foot.
  rateSetting,
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
