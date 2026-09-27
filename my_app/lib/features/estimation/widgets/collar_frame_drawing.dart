import 'package:flutter/widgets.dart';

/// A collar drawing that can say where it draws the window's frame.
///
/// The drawings do not fill their card the same way: a sliding window runs
/// nearly edge to edge, a door stands narrow in the middle, a fix window sits
/// well inside. A tap on a side of the drawing has to be matched to the line
/// under the finger, not to the nearest edge of the card -- otherwise a tap
/// high up on a door's left side lands closer to the card's top and takes the
/// top collar off instead.
abstract interface class CollarFrameDrawing {
  /// The outer frame's rectangle when the drawing is painted at [size].
  Rect collarFrameIn(Size size);
}
