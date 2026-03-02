import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class DoorSingleOverlay extends StatelessWidget {
  final int collarId;
  final String? selectedSection;
  final bool d46Enabled;
  final bool d52Enabled;

  const DoorSingleOverlay({
    super.key,
    required this.collarId,
    this.selectedSection,
    this.d46Enabled = false,
    this.d52Enabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CustomPaint(
        painter: _DoorSinglePainter(
          collarId: collarId,
          selectedSection: selectedSection,
          d46Enabled: d46Enabled,
          d52Enabled: d52Enabled,
        ),
      ),
    );
  }
}

class _DoorSinglePainter extends CustomPainter {
  final int collarId;
  final String? selectedSection;
  final bool d46Enabled;
  final bool d52Enabled;

  const _DoorSinglePainter({
    required this.collarId,
    required this.selectedSection,
    required this.d46Enabled,
    required this.d52Enabled,
  });

  bool get _showOuterTop =>
      collarId != 2 && collarId != 4 && collarId != 6 && collarId != 7;

  bool get _showOuterLeft =>
      collarId != 2 && collarId != 3 && collarId != 6 && collarId != 8;

  bool get _showOuterRight =>
      collarId != 2 && collarId != 5 && collarId != 7 && collarId != 8;

  bool get _showTopLeftCornerLink => _showOuterTop || _showOuterLeft;

  bool get _showTopRightCornerLink => _showOuterTop || _showOuterRight;

  bool get _showBottomLeftCornerLink => _showOuterLeft;

  bool get _showBottomRightCornerLink => _showOuterRight;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint basePaint = Paint()
      ..color = AppTheme.deepTeal.withValues(alpha: 0.68)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final Paint highlightPaint = Paint()
      ..color = AppTheme.violet
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final TextStyle baseLabelStyle = TextStyle(
      color: AppTheme.deepTeal.withValues(alpha: 0.72),
      fontSize: size.width * 0.055,
      fontWeight: FontWeight.w700,
    );
    final TextStyle highlightLabelStyle = baseLabelStyle.copyWith(
      color: AppTheme.violet,
    );

    final String normalizedSection = selectedSection?.trim().toUpperCase() ?? '';
    final bool onlyHighlightedSymbols = normalizedSection.isNotEmpty;
    final bool highlightD50 = normalizedSection == 'D50';
    final bool highlightD46 = d46Enabled && normalizedSection == 'D46';
    final bool highlightD52 = d52Enabled && normalizedSection == 'D52';
    final bool highlightD54F = normalizedSection == 'D54F';
    final bool highlightD54A = normalizedSection == 'D54A';

    final Rect outerRect = Rect.fromLTWH(
      size.width * 0.34,
      size.height * 0.14,
      size.width * 0.32,
      size.height * 0.70,
    );
    final Rect innerRect = Rect.fromLTWH(
      outerRect.left + size.width * 0.035,
      outerRect.top + size.height * 0.045,
      outerRect.width - size.width * 0.07,
      outerRect.height - size.height * 0.09,
    );

    final bool singleInnerTop = !_showOuterTop;
    final bool singleInnerLeft = !_showOuterLeft;
    final bool singleInnerRight = !_showOuterRight;
    final double centerY = innerRect.center.dy;

    void drawLabel(String text, Offset center, {bool highlight = false}) {
      if (onlyHighlightedSymbols && !highlight) {
        return;
      }
      final TextPainter painter = TextPainter(
        text: TextSpan(
          text: text,
          style: highlight ? highlightLabelStyle : baseLabelStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
      );
    }

    void drawLine(Offset from, Offset to, Paint paint) {
      canvas.drawLine(from, to, paint);
    }

    if (_showOuterTop) {
      drawLine(outerRect.topLeft, outerRect.topRight, basePaint);
    }
    if (_showOuterLeft) {
      drawLine(outerRect.topLeft, outerRect.bottomLeft, basePaint);
    }
    if (_showOuterRight) {
      drawLine(outerRect.topRight, outerRect.bottomRight, basePaint);
    }

    canvas.drawRect(innerRect, basePaint);
    if (d52Enabled) {
      drawLine(
        Offset(innerRect.left, centerY),
        Offset(innerRect.right, centerY),
        basePaint,
      );
    }

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

    if (highlightD54F) {
      if (_showOuterTop) {
        drawLine(outerRect.topLeft, outerRect.topRight, highlightPaint);
      }
      if (_showOuterLeft) {
        drawLine(outerRect.topLeft, outerRect.bottomLeft, highlightPaint);
      }
      if (_showOuterRight) {
        drawLine(outerRect.topRight, outerRect.bottomRight, highlightPaint);
      }
      if (_showTopLeftCornerLink) {
        drawLine(outerRect.topLeft, innerRect.topLeft, highlightPaint);
      }
      if (_showTopRightCornerLink) {
        drawLine(outerRect.topRight, innerRect.topRight, highlightPaint);
      }
      if (_showBottomLeftCornerLink) {
        drawLine(outerRect.bottomLeft, innerRect.bottomLeft, highlightPaint);
      }
      if (_showBottomRightCornerLink) {
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

    if (highlightD54A) {
      if (singleInnerTop) {
        drawLine(innerRect.topLeft, innerRect.topRight, highlightPaint);
      }
      if (singleInnerLeft) {
        drawLine(innerRect.topLeft, innerRect.bottomLeft, highlightPaint);
      }
      if (singleInnerRight) {
        drawLine(innerRect.topRight, innerRect.bottomRight, highlightPaint);
      }
    }

    if (highlightD50) {
      drawLine(innerRect.topLeft, innerRect.topRight, highlightPaint);
      drawLine(innerRect.topLeft, innerRect.bottomLeft, highlightPaint);
      drawLine(innerRect.topRight, innerRect.bottomRight, highlightPaint);
      if (!d46Enabled) {
        drawLine(innerRect.bottomLeft, innerRect.bottomRight, highlightPaint);
      }
    }

    if (highlightD46) {
      drawLine(innerRect.bottomLeft, innerRect.bottomRight, highlightPaint);
    }

    if (highlightD52) {
      drawLine(
        Offset(innerRect.left, centerY),
        Offset(innerRect.right, centerY),
        highlightPaint,
      );
    }

    drawLabel(
      'WT',
      Offset(outerRect.center.dx, outerRect.top - size.height * 0.07),
      highlight: (highlightD54F && _showOuterTop) ||
          (highlightD54A && singleInnerTop),
    );
    drawLabel(
      'HL',
      Offset(outerRect.left - size.width * 0.08, outerRect.center.dy),
      highlight: (highlightD54F && _showOuterLeft) ||
          (highlightD54A && singleInnerLeft),
    );
    drawLabel(
      'HR',
      Offset(outerRect.right + size.width * 0.08, outerRect.center.dy),
      highlight: (highlightD54F && _showOuterRight) ||
          (highlightD54A && singleInnerRight),
    );

    drawLabel(
      'W',
      Offset(innerRect.center.dx, innerRect.top + size.height * 0.05),
      highlight: highlightD50,
    );
    if (d52Enabled) {
      drawLabel(
        'T',
        Offset(innerRect.center.dx, centerY - size.height * 0.06),
        highlight: highlightD52,
      );
    }
    drawLabel(
      'W',
      Offset(innerRect.center.dx, innerRect.bottom - size.height * 0.05),
      highlight: highlightD46 || (highlightD50 && !d46Enabled),
    );
    drawLabel(
      'H',
      Offset(
        innerRect.left + size.width * 0.04,
        innerRect.center.dy - (d52Enabled ? size.height * 0.045 : 0),
      ),
      highlight: highlightD50,
    );
    drawLabel(
      'H',
      Offset(
        innerRect.right - size.width * 0.04,
        innerRect.center.dy - (d52Enabled ? size.height * 0.045 : 0),
      ),
      highlight: highlightD50,
    );
  }

  @override
  bool shouldRepaint(covariant _DoorSinglePainter oldDelegate) {
    return oldDelegate.collarId != collarId ||
        oldDelegate.selectedSection != selectedSection ||
        oldDelegate.d46Enabled != d46Enabled ||
        oldDelegate.d52Enabled != d52Enabled;
  }
}
