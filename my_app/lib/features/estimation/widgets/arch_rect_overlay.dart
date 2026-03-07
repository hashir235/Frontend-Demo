import 'package:flutter/material.dart';

class ArchRectOverlay extends StatelessWidget {
  final int collarId;
  final String? selectedSection;

  const ArchRectOverlay({
    super.key,
    required this.collarId,
    this.selectedSection,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CustomPaint(
        painter: _ArchRectPainter(
          collarId: collarId,
          selectedSection: selectedSection,
        ),
      ),
    );
  }
}

class _ArchRectPainter extends CustomPainter {
  final int collarId;
  final String? selectedSection;

  const _ArchRectPainter({
    required this.collarId,
    required this.selectedSection,
  });

  bool get _showOuterTop =>
      collarId != 2 && collarId != 4 && collarId != 7 && collarId != 8;

  bool get _showOuterLeft =>
      collarId != 2 && collarId != 3 && collarId != 6 && collarId != 8;

  bool get _showOuterRight =>
      collarId != 2 && collarId != 5 && collarId != 6 && collarId != 7;

  bool get _showTopLeftConnector => _showOuterTop || _showOuterLeft;

  bool get _showTopRightConnector => _showOuterTop || _showOuterRight;

  bool get _showBottomLeftConnector => _showOuterLeft;

  bool get _showBottomRightConnector => _showOuterRight;

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
    final Paint strokePaint = Paint()
      ..color = const Color(0xFFB7C0C7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final Paint highlightPaint = Paint()
      ..color = highlightColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;
    final TextStyle labelStyle = TextStyle(
      color: const Color(0xFF7C8A94),
      fontSize: size.width * 0.055,
      fontWeight: FontWeight.w700,
    );
    final TextStyle highlightLabelStyle = labelStyle.copyWith(
      color: highlightColor,
    );

    final String normalizedSection =
        selectedSection?.trim().toUpperCase() ?? '';
    final bool onlyHighlightedSymbols = normalizedSection.isNotEmpty;
    final bool highlightD41 = normalizedSection == 'D41';
    final bool highlightD51F = normalizedSection == 'D51F';
    final bool highlightD51A = normalizedSection == 'D51A';

    final Rect outerRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.78,
      height: size.height * 0.42,
    );
    final Rect innerRect = Rect.fromLTWH(
      outerRect.left + size.width * 0.055,
      outerRect.top + size.height * 0.045,
      outerRect.width - size.width * 0.11,
      outerRect.height - size.height * 0.09,
    );
    final bool singleInnerTop = !_showOuterTop;
    final bool singleInnerLeft = !_showOuterLeft;
    final bool singleInnerRight = !_showOuterRight;
    const bool singleInnerBottom = true;

    void drawLine(Offset from, Offset to, Paint paint) {
      canvas.drawLine(from, to, paint);
    }

    void drawLabel(
      String text,
      Offset center, {
      required bool highlight,
      bool showBase = true,
    }) {
      if (!highlight && (onlyHighlightedSymbols || !showBase)) {
        return;
      }
      _drawCenteredText(
        canvas,
        text: text,
        center: center,
        style: highlight ? highlightLabelStyle : labelStyle,
      );
    }

    if (_showOuterTop) {
      drawLine(outerRect.topLeft, outerRect.topRight, strokePaint);
    }
    if (_showOuterLeft) {
      drawLine(outerRect.topLeft, outerRect.bottomLeft, strokePaint);
    }
    if (_showOuterRight) {
      drawLine(outerRect.topRight, outerRect.bottomRight, strokePaint);
    }
    canvas.drawRect(innerRect, strokePaint);

    if (_showTopLeftConnector) {
      drawLine(outerRect.topLeft, innerRect.topLeft, strokePaint);
    }
    if (_showTopRightConnector) {
      drawLine(outerRect.topRight, innerRect.topRight, strokePaint);
    }
    if (_showBottomLeftConnector) {
      drawLine(outerRect.bottomLeft, innerRect.bottomLeft, strokePaint);
    }
    if (_showBottomRightConnector) {
      drawLine(outerRect.bottomRight, innerRect.bottomRight, strokePaint);
    }

    if (highlightD41) {
      canvas.drawRect(innerRect, highlightPaint);
    }

    if (highlightD51F) {
      if (_showOuterTop) {
        drawLine(outerRect.topLeft, outerRect.topRight, highlightPaint);
      }
      if (_showOuterLeft) {
        drawLine(outerRect.topLeft, outerRect.bottomLeft, highlightPaint);
      }
      if (_showOuterRight) {
        drawLine(outerRect.topRight, outerRect.bottomRight, highlightPaint);
      }
      if (_showTopLeftConnector) {
        drawLine(outerRect.topLeft, innerRect.topLeft, highlightPaint);
      }
      if (_showTopRightConnector) {
        drawLine(outerRect.topRight, innerRect.topRight, highlightPaint);
      }
      if (_showBottomLeftConnector) {
        drawLine(outerRect.bottomLeft, innerRect.bottomLeft, highlightPaint);
      }
      if (_showBottomRightConnector) {
        drawLine(outerRect.bottomRight, innerRect.bottomRight, highlightPaint);
      }
      if (!singleInnerTop) {
        drawLine(innerRect.topLeft, innerRect.topRight, highlightPaint);
      }
      if (!singleInnerLeft) {
        drawLine(innerRect.topLeft, innerRect.bottomLeft, highlightPaint);
      }
      if (!singleInnerRight) {
        drawLine(innerRect.topRight, innerRect.bottomRight, highlightPaint);
      }
    }

    if (highlightD51A) {
      if (singleInnerTop) {
        drawLine(innerRect.topLeft, innerRect.topRight, highlightPaint);
      }
      if (singleInnerLeft) {
        drawLine(innerRect.topLeft, innerRect.bottomLeft, highlightPaint);
      }
      if (singleInnerRight) {
        drawLine(innerRect.topRight, innerRect.bottomRight, highlightPaint);
      }
      if (singleInnerBottom) {
        drawLine(innerRect.bottomLeft, innerRect.bottomRight, highlightPaint);
      }
    }

    drawLabel(
      'WT',
      Offset(outerRect.center.dx, outerRect.top - size.height * 0.08),
      highlight:
          (highlightD51F && _showOuterTop) || (highlightD51A && singleInnerTop),
    );
    drawLabel(
      'WL',
      Offset(outerRect.left - size.width * 0.08, outerRect.center.dy),
      highlight:
          (highlightD51F && _showOuterLeft) ||
          (highlightD51A && singleInnerLeft),
    );
    drawLabel(
      'WR',
      Offset(outerRect.right + size.width * 0.08, outerRect.center.dy),
      highlight:
          (highlightD51F && _showOuterRight) ||
          (highlightD51A && singleInnerRight),
    );
    drawLabel(
      'WB',
      Offset(outerRect.center.dx, outerRect.bottom + size.height * 0.075),
      highlight: highlightD51A && singleInnerBottom,
    );

    drawLabel(
      'W',
      Offset(innerRect.center.dx, innerRect.top + size.height * 0.045),
      highlight: highlightD41,
    );
    drawLabel(
      'W',
      Offset(innerRect.center.dx, innerRect.bottom - size.height * 0.035),
      highlight: highlightD41,
    );
    drawLabel(
      'H',
      Offset(innerRect.left + size.width * 0.045, innerRect.center.dy),
      highlight: highlightD41,
    );
    drawLabel(
      'H',
      Offset(innerRect.right - size.width * 0.045, innerRect.center.dy),
      highlight: highlightD41,
    );
  }

  @override
  bool shouldRepaint(covariant _ArchRectPainter oldDelegate) =>
      oldDelegate.collarId != collarId ||
      oldDelegate.selectedSection != selectedSection;
}
