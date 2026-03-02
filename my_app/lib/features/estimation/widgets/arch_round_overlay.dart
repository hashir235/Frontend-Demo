import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class ArchRoundOverlay extends StatelessWidget {
  final int collarId;
  final String? selectedSection;

  const ArchRoundOverlay({
    super.key,
    required this.collarId,
    this.selectedSection,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CustomPaint(
        painter: _ArchRoundPainter(
          collarId: collarId,
          selectedSection: selectedSection,
        ),
      ),
    );
  }
}

class _ArchRoundPainter extends CustomPainter {
  final int collarId;
  final String? selectedSection;

  const _ArchRoundPainter({
    required this.collarId,
    required this.selectedSection,
  });

  void _drawCenteredText(
    Canvas canvas, {
    required String text,
    required Offset center,
    required TextStyle style,
  }) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();

    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    const Color highlightColor = Color(0xFF5B45D6);
    final Paint basePaint = Paint()
      ..color = const Color(0xFFB7C0C7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final Paint highlightPaint = Paint()
      ..color = highlightColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;
    final TextStyle baseLabelStyle = TextStyle(
      color: AppTheme.deepTeal.withValues(alpha: 0.78),
      fontSize: size.width * 0.058,
      fontWeight: FontWeight.w700,
    );
    final TextStyle highlightLabelStyle = baseLabelStyle.copyWith(
      color: highlightColor,
    );

    final String normalizedSection = selectedSection?.trim().toUpperCase() ?? '';
    final bool onlyHighlightedSymbols = normalizedSection.isNotEmpty;
    final bool highlightD41 = normalizedSection == 'D41';
    final bool highlightD50A = normalizedSection == 'D50A';
    final bool highlightD50F = normalizedSection == 'D50F';

    final Rect frameRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.78,
      height: size.height * 0.44,
    );
    final double sideTopY = frameRect.top + (frameRect.height * 0.40);
    final Offset leftBase = Offset(frameRect.left, frameRect.bottom);
    final Offset rightBase = Offset(frameRect.right, frameRect.bottom);
    final Offset leftTop = Offset(frameRect.left, sideTopY);
    final Offset rightTop = Offset(frameRect.right, sideTopY);

    final Rect innerRect = Rect.fromLTWH(
      frameRect.left + size.width * 0.055,
      frameRect.top + size.height * 0.05,
      frameRect.width - size.width * 0.11,
      frameRect.height - size.height * 0.07,
    );
    final double innerSideTopY = innerRect.top + (innerRect.height * 0.40);
    final Offset innerLeftBase = Offset(innerRect.left, innerRect.bottom);
    final Offset innerRightBase = Offset(innerRect.right, innerRect.bottom);
    final Offset innerLeftTop = Offset(innerRect.left, innerSideTopY);
    final Offset innerRightTop = Offset(innerRect.right, innerSideTopY);

    final bool showOuterDesign = collarId == 1;

    void drawLine(Offset from, Offset to, Paint paint) {
      canvas.drawLine(from, to, paint);
    }

    void drawArchCurve({
      required Offset left,
      required Offset right,
      required Rect rect,
      required Paint paint,
    }) {
      final Path curve = Path()
        ..moveTo(left.dx, left.dy)
        ..quadraticBezierTo(
          rect.center.dx,
          rect.top - (rect.height * 0.22),
          right.dx,
          right.dy,
        );
      canvas.drawPath(curve, paint);
    }

    void drawLabel(String text, Offset center, {bool highlight = false}) {
      if (onlyHighlightedSymbols && !highlight) {
        return;
      }
      _drawCenteredText(
        canvas,
        text: text,
        center: center,
        style: highlight ? highlightLabelStyle : baseLabelStyle,
      );
    }

    if (showOuterDesign) {
      drawLine(leftBase, leftTop, basePaint);
      drawLine(rightBase, rightTop, basePaint);
      drawArchCurve(
        left: leftTop,
        right: rightTop,
        rect: frameRect,
        paint: basePaint,
      );
    }

    drawLine(innerLeftBase, innerRightBase, basePaint);
    drawLine(innerLeftBase, innerLeftTop, basePaint);
    drawLine(innerRightBase, innerRightTop, basePaint);
    drawArchCurve(
      left: innerLeftTop,
      right: innerRightTop,
      rect: innerRect,
      paint: basePaint,
    );

    if (showOuterDesign) {
      drawLine(leftBase, innerLeftBase, basePaint);
      drawLine(rightBase, innerRightBase, basePaint);
      drawLine(leftTop, innerLeftTop, basePaint);
      drawLine(rightTop, innerRightTop, basePaint);
    }

    if (highlightD41) {
      drawLine(innerLeftBase, innerRightBase, highlightPaint);
      drawLine(innerLeftBase, innerLeftTop, highlightPaint);
      drawLine(innerRightBase, innerRightTop, highlightPaint);
      drawArchCurve(
        left: innerLeftTop,
        right: innerRightTop,
        rect: innerRect,
        paint: highlightPaint,
      );
    }

    if (highlightD50A) {
      if (collarId == 1) {
        drawLine(innerLeftBase, innerRightBase, highlightPaint);
      } else {
        drawLine(innerLeftBase, innerRightBase, highlightPaint);
        drawLine(innerLeftBase, innerLeftTop, highlightPaint);
        drawLine(innerRightBase, innerRightTop, highlightPaint);
        drawArchCurve(
          left: innerLeftTop,
          right: innerRightTop,
          rect: innerRect,
          paint: highlightPaint,
        );
      }
    }

    if (highlightD50F) {
      if (showOuterDesign) {
        drawLine(leftBase, leftTop, highlightPaint);
        drawLine(rightBase, rightTop, highlightPaint);
        drawArchCurve(
          left: leftTop,
          right: rightTop,
          rect: frameRect,
          paint: highlightPaint,
        );
        drawLine(leftBase, innerLeftBase, highlightPaint);
        drawLine(rightBase, innerRightBase, highlightPaint);
        drawLine(leftTop, innerLeftTop, highlightPaint);
        drawLine(rightTop, innerRightTop, highlightPaint);
      }
      drawLine(innerLeftBase, innerLeftTop, highlightPaint);
      drawLine(innerRightBase, innerRightTop, highlightPaint);
      drawArchCurve(
        left: innerLeftTop,
        right: innerRightTop,
        rect: innerRect,
        paint: highlightPaint,
      );
    }

    if (showOuterDesign || highlightD50F || (highlightD50A && collarId == 2)) {
      drawLabel(
        'Arch',
        Offset(
          size.width / 2,
          (showOuterDesign ? frameRect.top : innerRect.top) - size.height * 0.09,
        ),
        highlight: highlightD50F || (highlightD50A && collarId == 2),
      );
    }
    if (showOuterDesign || highlightD50A) {
      drawLabel(
        'W',
        Offset(size.width / 2, innerRect.bottom + size.height * 0.045),
        highlight: highlightD50A,
      );
    }

    drawLabel(
      'Arch',
      Offset(size.width / 2, innerRect.top + innerRect.height * 0.16),
      highlight: highlightD41,
    );
    drawLabel(
      'W',
      Offset(size.width / 2, innerRect.bottom - size.height * 0.035),
      highlight: highlightD41,
    );
  }

  @override
  bool shouldRepaint(covariant _ArchRoundPainter oldDelegate) {
    return oldDelegate.collarId != collarId ||
        oldDelegate.selectedSection != selectedSection;
  }
}
