import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// The Prime Economy sliding window, drawn plain.
///
/// It has no collar system, so it is drawn the simple way: one line all round
/// for the frame, the two panels inside it, and the two stiles that meet at
/// the centre a little apart, where the panels overlap. Picking a profile in
/// the sidebar lights the lines it is cut for -- and only those labels, as on
/// the other drawings:
///
///  * EF30 -- the frame's two sides (HL, HR)
///  * EF27 -- the frame's head (WT); EF26A its sill (WB)
///  * EF25 -- each panel's top rail; EF24 each one's bottom rail
///  * EF22 -- each panel's outer stile; EF28 the two meeting at the centre
///  * D29  -- the net over one panel: half the window, boxed
class PrimeEconomySlidingOverlay extends StatelessWidget {
  const PrimeEconomySlidingOverlay({super.key, required this.selectedSection});

  /// The profile picked in the sidebar, or null for none.
  final String? selectedSection;

  /// Where the frame is drawn: in from every edge by 8% of the width, as on
  /// the sliding window's own drawing.
  static Rect frameIn(Size size) {
    final double padding = size.width * 0.08;
    return Rect.fromLTWH(
      padding,
      padding,
      size.width - padding * 2,
      size.height - padding * 2,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      key: const Key('prime_economy_drawing'),
      painter: _PrimeEconomyPainter(selectedSection),
      child: const SizedBox.expand(),
    );
  }
}

/// One line of the drawing, and the profiles it is cut from.
class _Line {
  const _Line(this.from, this.to, this.sections);

  final Offset from;
  final Offset to;
  final Set<String> sections;
}

class _PrimeEconomyPainter extends CustomPainter {
  const _PrimeEconomyPainter(this.selectedSection);

  final String? selectedSection;

  static const double _fontSize = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final String? picked = selectedSection;

    final Rect frame = PrimeEconomySlidingOverlay.frameIn(size);
    final Rect inner = frame.deflate(size.width * 0.05);
    final double overlap = size.width * 0.012;
    final double midX = inner.center.dx;
    final Rect left = Rect.fromLTRB(inner.left, inner.top, midX + overlap, inner.bottom);
    final Rect right = Rect.fromLTRB(midX - overlap, inner.top, inner.right, inner.bottom);

    final List<_Line> lines = <_Line>[
      // The frame.
      _Line(frame.topLeft, frame.bottomLeft, const <String>{'EF30'}),
      _Line(frame.topRight, frame.bottomRight, const <String>{'EF30'}),
      _Line(frame.topLeft, frame.topRight, const <String>{'EF27'}),
      _Line(frame.bottomLeft, frame.bottomRight, const <String>{'EF26A'}),
      // The left panel: it carries the net, so every side is D29 too.
      _Line(left.topLeft, left.topRight, const <String>{'EF25', 'D29'}),
      _Line(left.bottomLeft, left.bottomRight, const <String>{'EF24', 'D29'}),
      _Line(left.topLeft, left.bottomLeft, const <String>{'EF22', 'D29'}),
      _Line(left.topRight, left.bottomRight, const <String>{'EF28', 'D29'}),
      // The right panel.
      _Line(right.topLeft, right.topRight, const <String>{'EF25'}),
      _Line(right.bottomLeft, right.bottomRight, const <String>{'EF24'}),
      _Line(right.topRight, right.bottomRight, const <String>{'EF22'}),
      _Line(right.topLeft, right.bottomLeft, const <String>{'EF28'}),
    ];

    final Paint framePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = AppTheme.deepTeal.withValues(alpha: 0.6);
    final Paint panelPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = AppTheme.deepTeal.withValues(alpha: 0.42);
    final Paint highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = AppTheme.violet;

    // Everything first, then what is picked over it, so a lit line is never
    // drawn under a plain one.
    for (int i = 0; i < lines.length; i++) {
      canvas.drawLine(lines[i].from, lines[i].to, i < 4 ? framePaint : panelPaint);
    }
    for (final _Line line in lines) {
      if (picked != null && line.sections.contains(picked)) {
        canvas.drawLine(line.from, line.to, highlightPaint);
      }
    }

    // The labels: every one while nothing is picked, then only the lit ones.
    final Color baseText = AppTheme.deepTeal.withValues(alpha: 0.55);
    void label(String text, Set<String> sections, Offset Function(Size) at) {
      final bool lit = picked != null && sections.contains(picked);
      if (picked != null && !lit) return;
      final TextPainter painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: lit ? AppTheme.violet : baseText,
            fontSize: _fontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final Offset origin = at(painter.size);
      painter.paint(
        canvas,
        Offset(
          origin.dx.clamp(0, size.width - painter.width),
          origin.dy.clamp(0, size.height - painter.height),
        ),
      );
    }

    final double gap = size.height * 0.012;
    final double sideGap = gap + size.width * 0.01;

    label('WT', const <String>{'EF27'},
        (Size s) => Offset(frame.center.dx - s.width / 2, frame.top - gap - s.height));
    label('WB', const <String>{'EF26A'},
        (Size s) => Offset(frame.center.dx - s.width / 2, frame.bottom + gap));
    label('HL', const <String>{'EF30'},
        (Size s) => Offset(frame.left - sideGap - s.width, frame.center.dy - s.height / 2));
    label('HR', const <String>{'EF30'},
        (Size s) => Offset(frame.right + sideGap, frame.center.dy - s.height / 2));

    final double inset = size.height * 0.015;
    void panel(Rect p, {required bool isLeft}) {
      final Set<String> net = isLeft ? const <String>{'D29'} : const <String>{};
      label('W', <String>{'EF25', ...net},
          (Size s) => Offset(p.center.dx - s.width / 2, p.top + inset));
      label('W', <String>{'EF24', ...net},
          (Size s) => Offset(p.center.dx - s.width / 2, p.bottom - inset - s.height));
      label('H', <String>{'EF22', ...net}, (Size s) => Offset(
            isLeft ? p.left + inset : p.right - inset - s.width,
            p.center.dy - s.height / 2,
          ));
      // Clear of both centre stiles: the panels overlap there, so the other
      // panel's stile is the nearer line.
      label('H', <String>{'EF28', ...net}, (Size s) => Offset(
            isLeft ? midX - overlap - inset - s.width : midX + overlap + inset,
            p.center.dy - s.height / 2,
          ));
    }

    panel(left, isLeft: true);
    panel(right, isLeft: false);
  }

  @override
  bool shouldRepaint(covariant _PrimeEconomyPainter oldDelegate) =>
      oldDelegate.selectedSection != selectedSection;
}
