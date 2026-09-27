import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../models/collar_layout.dart';
import 'collar_frame_drawing.dart';

/// The window's collar, chosen by tapping its sides.
///
/// One drawing of the window instead of a row of cards to swipe through. A
/// side drawn as a double line has a collar; tap it and the collar comes off
/// -- a single light red line -- and tap it again to put it back. The drawing
/// is the same collar drawing the cards always showed, so what is on screen is
/// exactly the collar that will be cut.
///
/// A window that only comes with a collar all round or none (the corner
/// windows, the corner fix, the round arch) switches the whole frame on any
/// tap. A combination the engine has no collar for is refused with a word of
/// explanation rather than silently turned into something else.
class CollarSidePicker extends StatelessWidget {
  const CollarSidePicker({
    super.key,
    required this.layout,
    required this.collar,
    required this.drawing,
    required this.onChanged,
    required this.onRefused,
    required this.width,
    required this.height,
  });

  final CollarLayout layout;

  /// The collar type now chosen.
  final int collar;

  /// The collar drawing for [collar]. When it is a [CollarFrameDrawing] a tap
  /// goes to the frame line nearest the finger; otherwise the drawing is taken
  /// to fill the card.
  final Widget? drawing;

  final ValueChanged<int> onChanged;

  /// Called with the reason when a tap asks for a collar that does not exist.
  final ValueChanged<String> onRefused;

  final double width;
  final double height;

  /// The space between the card's border and the drawing.
  static const double _padding = 12;

  static const double _border = 2.2;

  /// How far in from the card's edge the drawing starts: a [Container] puts
  /// its border's width inside the padding as well.
  static const double _inset = _padding + _border;

  /// Which side of [frame] a tap at [position] means: the side whose line
  /// passes closest to the finger.
  static CollarSide sideAt(Offset position, Rect frame) {
    final Map<CollarSide, double> distance = <CollarSide, double>{
      CollarSide.top: _toSegment(position, frame.topLeft, frame.topRight),
      CollarSide.bottom: _toSegment(position, frame.bottomLeft, frame.bottomRight),
      CollarSide.left: _toSegment(position, frame.topLeft, frame.bottomLeft),
      CollarSide.right: _toSegment(position, frame.topRight, frame.bottomRight),
    };
    CollarSide nearest = CollarSide.top;
    for (final MapEntry<CollarSide, double> entry in distance.entries) {
      if (entry.value < distance[nearest]!) nearest = entry.key;
    }
    return nearest;
  }

  static double _toSegment(Offset p, Offset a, Offset b) {
    final Offset ab = b - a;
    final double lengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lengthSquared == 0) return (p - a).distance;
    final Offset ap = p - a;
    final double t = ((ap.dx * ab.dx + ap.dy * ab.dy) / lengthSquared).clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  /// The frame's rectangle in the card's own coordinates, for a card of [size].
  Rect frameIn(Size size) {
    final Size drawingSize = Size(
      size.width - (_inset * 2),
      size.height - (_inset * 2),
    );
    final Rect frame = switch (drawing) {
      final CollarFrameDrawing framed => framed.collarFrameIn(drawingSize),
      _ => Offset.zero & drawingSize,
    };
    return frame.shift(const Offset(_inset, _inset));
  }

  static String _name(CollarSide side) => switch (side) {
    CollarSide.top => 'top',
    CollarSide.bottom => 'bottom',
    CollarSide.left => 'left',
    CollarSide.right => 'right',
  };

  /// What a tap is told on a window with one collar type: there is nothing
  /// else to switch to.
  static String onlyCollarMessage(CollarLayout layout) =>
      layout.sidesWithCollar(layout.collars.first).isEmpty
          ? 'This window has no collar on any side.'
          : 'This window comes in one collar type only.';

  void _tap(Offset position, Size size) {
    if (layout.isFixed) {
      onRefused(onlyCollarMessage(layout));
      return;
    }
    if (layout.isWholeFrame) {
      final int? next = layout.toggleWholeFrame(collar);
      if (next == null) {
        onRefused(onlyCollarMessage(layout));
        return;
      }
      HapticFeedback.selectionClick();
      onChanged(next);
      return;
    }
    final CollarSide side = sideAt(position, frameIn(size));
    if (!layout.sides.contains(side)) {
      // The bottom of a door or an arch: nothing there takes a collar.
      onRefused('The ${_name(side)} of this window never has a collar.');
      return;
    }
    final int? next = layout.toggle(collar, side);
    if (next == null) {
      final Set<CollarSide> wanted = <CollarSide>{...layout.sidesWithCollar(collar)};
      if (!wanted.remove(side)) wanted.add(side);
      final List<String> names = <String>[
        for (final CollarSide s in CollarSide.values)
          if (wanted.contains(s)) _name(s),
      ];
      onRefused(
        'No collar type has a collar on the ${names.join(' and ')} only. '
        'Change another side first.',
      );
      return;
    }
    HapticFeedback.selectionClick();
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Size size = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            key: const Key('collar_side_picker'),
            behavior: HitTestBehavior.opaque,
            onTapUp: (TapUpDetails details) => _tap(details.localPosition, size),
            child: Container(
              padding: const EdgeInsets.all(_padding),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xFFF8FBFD), Color(0xFFEAF1F5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.violet, width: _border),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppTheme.deepTeal.withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: drawing ?? const SizedBox.expand(),
            ),
          );
        },
      ),
    );
  }
}
