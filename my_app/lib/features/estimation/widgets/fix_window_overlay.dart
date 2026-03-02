import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class FixWindowOverlay extends StatelessWidget {
  final int collarId;
  final String? selectedSection;

  const FixWindowOverlay({
    super.key,
    required this.collarId,
    this.selectedSection,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CustomPaint(
        painter: _FixWindowPainter(
          collarId: collarId,
          selectedSection: selectedSection,
        ),
      ),
    );
  }
}

class _FixWindowPainter extends CustomPainter {
  final int collarId;
  final String? selectedSection;

  const _FixWindowPainter({
    required this.collarId,
    required this.selectedSection,
  });

  bool get _showOuterTop =>
      collarId != 2 &&
      collarId != 3 &&
      collarId != 7 &&
      collarId != 9 &&
      collarId != 12 &&
      collarId != 13 &&
      collarId != 14;

  bool get _showOuterRight =>
      collarId != 2 &&
      collarId != 4 &&
      collarId != 8 &&
      collarId != 10 &&
      collarId != 11 &&
      collarId != 13 &&
      collarId != 14;

  bool get _showOuterBottom =>
      collarId != 2 &&
      collarId != 5 &&
      collarId != 8 &&
      collarId != 9 &&
      collarId != 11 &&
      collarId != 12 &&
      collarId != 14;

  bool get _showOuterLeft =>
      collarId != 2 &&
      collarId != 6 &&
      collarId != 7 &&
      collarId != 10 &&
      collarId != 11 &&
      collarId != 12 &&
      collarId != 13;

  bool get _showTopLeftCornerLink =>
      collarId != 2 && (_showOuterTop || _showOuterLeft);

  bool get _showTopRightCornerLink =>
      collarId != 2 && (_showOuterTop || _showOuterRight);

  bool get _showBottomLeftCornerLink =>
      collarId != 2 && (_showOuterBottom || _showOuterLeft);

  bool get _showBottomRightCornerLink =>
      collarId != 2 && (_showOuterBottom || _showOuterRight);

  bool get _hasSelection =>
      selectedSection != null && selectedSection!.trim().isNotEmpty;

  bool get _highlightD41 => selectedSection == 'D41';
  bool get _highlightD54F => selectedSection == 'D54F';
  bool get _highlightD54A => selectedSection == 'D54A';

  @override
  void paint(Canvas canvas, Size size) {
    final Paint basePaint = Paint()
      ..color = AppTheme.deepTeal.withValues(alpha: 0.68)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final Paint accentPaint = Paint()
      ..color = AppTheme.violet
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final TextStyle baseLabelStyle = TextStyle(
      color: AppTheme.deepTeal.withValues(alpha: 0.72),
      fontSize: size.width * 0.055,
      fontWeight: FontWeight.w700,
    );
    final TextStyle accentLabelStyle = baseLabelStyle.copyWith(
      color: AppTheme.violet,
    );

    final Rect outerRect = Rect.fromLTWH(
      size.width * 0.17,
      size.height * 0.16,
      size.width * 0.66,
      size.height * 0.68,
    );
    final Rect innerRect = Rect.fromLTWH(
      size.width * 0.245,
      size.height * 0.245,
      size.width * 0.51,
      size.height * 0.51,
    );

    final Offset wtCenter = Offset(
      outerRect.center.dx,
      outerRect.top - size.height * 0.07,
    );
    final Offset hlCenter = Offset(
      outerRect.left - size.width * 0.08,
      outerRect.center.dy,
    );
    final Offset hrCenter = Offset(
      outerRect.right + size.width * 0.08,
      outerRect.center.dy,
    );
    final Offset wbCenter = Offset(
      outerRect.center.dx,
      outerRect.bottom + size.height * 0.07,
    );
    final Offset innerTopWCenter = Offset(
      innerRect.center.dx,
      innerRect.top + size.height * 0.055,
    );
    final Offset innerBottomWCenter = Offset(
      innerRect.center.dx,
      innerRect.bottom - size.height * 0.055,
    );
    final Offset innerLeftHCenter = Offset(
      innerRect.left + size.width * 0.045,
      innerRect.center.dy,
    );
    final Offset innerRightHCenter = Offset(
      innerRect.right - size.width * 0.045,
      innerRect.center.dy,
    );
    final bool highlightOuterTopLine = _highlightD54F && _showOuterTop;
    final bool highlightOuterRightLine = _highlightD54F && _showOuterRight;
    final bool highlightOuterBottomLine = _highlightD54F && _showOuterBottom;
    final bool highlightOuterLeftLine = _highlightD54F && _showOuterLeft;
    final bool highlightOuterTopSymbol =
        (_highlightD54F && _showOuterTop) || (_highlightD54A && !_showOuterTop);
    final bool highlightOuterRightSymbol =
        (_highlightD54F && _showOuterRight) ||
        (_highlightD54A && !_showOuterRight);
    final bool highlightOuterBottomSymbol =
        (_highlightD54F && _showOuterBottom) ||
        (_highlightD54A && !_showOuterBottom);
    final bool highlightOuterLeftSymbol =
        (_highlightD54F && _showOuterLeft) || (_highlightD54A && !_showOuterLeft);
    final bool highlightCornerTopLeft =
        _highlightD54F && _showTopLeftCornerLink;
    final bool highlightCornerTopRight = _highlightD54F && _showTopRightCornerLink;
    final bool highlightCornerBottomLeft =
        _highlightD54F && _showBottomLeftCornerLink;
    final bool highlightCornerBottomRight =
        _highlightD54F && _showBottomRightCornerLink;
    final bool highlightInnerTop =
        _highlightD41 ||
        (_highlightD54F && _showOuterTop) ||
        (_highlightD54A && !_showOuterTop);
    final bool highlightInnerRight =
        _highlightD41 ||
        (_highlightD54F && _showOuterRight) ||
        (_highlightD54A && !_showOuterRight);
    final bool highlightInnerBottom =
        _highlightD41 ||
        (_highlightD54F && _showOuterBottom) ||
        (_highlightD54A && !_showOuterBottom);
    final bool highlightInnerLeft =
        _highlightD41 ||
        (_highlightD54F && _showOuterLeft) ||
        (_highlightD54A && !_showOuterLeft);
    final bool highlightInnerTopLabel = _highlightD41;
    final bool highlightInnerRightLabel = _highlightD41;
    final bool highlightInnerBottomLabel = _highlightD41;
    final bool highlightInnerLeftLabel = _highlightD41;

    void drawLine(Offset from, Offset to, Paint paint) {
      canvas.drawLine(from, to, paint);
    }

    void drawRect(Rect rect, Paint paint) {
      canvas.drawRect(rect, paint);
    }

    void drawLabel(
      String text,
      Offset center, {
      required bool highlight,
    }) {
      if (_hasSelection && !highlight) {
        return;
      }
      final TextPainter painter = TextPainter(
        text: TextSpan(
          text: text,
          style: highlight ? accentLabelStyle : baseLabelStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
      );
    }

    if (_showOuterTop) {
      drawLine(outerRect.topLeft, outerRect.topRight, basePaint);
    }
    if (_showOuterRight) {
      drawLine(outerRect.topRight, outerRect.bottomRight, basePaint);
    }
    if (_showOuterBottom) {
      drawLine(outerRect.bottomLeft, outerRect.bottomRight, basePaint);
    }
    if (_showOuterLeft) {
      drawLine(outerRect.topLeft, outerRect.bottomLeft, basePaint);
    }

    drawRect(innerRect, basePaint);

    if (_showTopLeftCornerLink) {
      drawLine(outerRect.topLeft, innerRect.topLeft, basePaint);
    }
    if (_showTopRightCornerLink) {
      drawLine(outerRect.topRight, innerRect.topRight, basePaint);
    }
    if (_showBottomLeftCornerLink) {
      drawLine(outerRect.bottomLeft, innerRect.bottomLeft, basePaint);
    }
    if (_showBottomRightCornerLink) {
      drawLine(outerRect.bottomRight, innerRect.bottomRight, basePaint);
    }

    if (highlightOuterTopLine) {
        drawLine(outerRect.topLeft, outerRect.topRight, accentPaint);
    }
    if (highlightOuterRightLine) {
        drawLine(outerRect.topRight, outerRect.bottomRight, accentPaint);
    }
    if (highlightOuterBottomLine) {
        drawLine(outerRect.bottomLeft, outerRect.bottomRight, accentPaint);
    }
    if (highlightOuterLeftLine) {
        drawLine(outerRect.topLeft, outerRect.bottomLeft, accentPaint);
    }
    if (highlightCornerTopLeft) {
        drawLine(outerRect.topLeft, innerRect.topLeft, accentPaint);
    }
    if (highlightCornerTopRight) {
        drawLine(outerRect.topRight, innerRect.topRight, accentPaint);
    }
    if (highlightCornerBottomLeft) {
        drawLine(outerRect.bottomLeft, innerRect.bottomLeft, accentPaint);
    }
    if (highlightCornerBottomRight) {
        drawLine(outerRect.bottomRight, innerRect.bottomRight, accentPaint);
    }

    if (highlightInnerTop) {
      drawLine(innerRect.topLeft, innerRect.topRight, accentPaint);
    }
    if (highlightInnerRight) {
      drawLine(innerRect.topRight, innerRect.bottomRight, accentPaint);
    }
    if (highlightInnerBottom) {
      drawLine(innerRect.bottomLeft, innerRect.bottomRight, accentPaint);
    }
    if (highlightInnerLeft) {
      drawLine(innerRect.topLeft, innerRect.bottomLeft, accentPaint);
    }

    drawLabel(
      'WT',
      wtCenter,
      highlight: highlightOuterTopSymbol,
    );
    drawLabel(
      'HL',
      hlCenter,
      highlight: highlightOuterLeftSymbol,
    );
    drawLabel(
      'HR',
      hrCenter,
      highlight: highlightOuterRightSymbol,
    );
    drawLabel(
      'WB',
      wbCenter,
      highlight: highlightOuterBottomSymbol,
    );
    drawLabel(
      'W',
      innerTopWCenter,
      highlight: highlightInnerTopLabel,
    );
    drawLabel(
      'W',
      innerBottomWCenter,
      highlight: highlightInnerBottomLabel,
    );
    drawLabel(
      'H',
      innerLeftHCenter,
      highlight: highlightInnerLeftLabel,
    );
    drawLabel(
      'H',
      innerRightHCenter,
      highlight: highlightInnerRightLabel,
    );
  }

  @override
  bool shouldRepaint(covariant _FixWindowPainter oldDelegate) {
    return oldDelegate.collarId != collarId ||
        oldDelegate.selectedSection != selectedSection;
  }
}
