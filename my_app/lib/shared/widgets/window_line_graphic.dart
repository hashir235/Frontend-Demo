import 'package:flutter/material.dart';
import 'dart:math' as math;

class WindowLineGraphic extends StatelessWidget {
  final String graphicKey;
  final String windowLabel;
  final int? displayIndex;
  final String? windowCode;
  final Color strokeColor;
  final double horizontalShift;

  const WindowLineGraphic({
    super.key,
    required this.graphicKey,
    required this.windowLabel,
    required this.displayIndex,
    this.windowCode,
    required this.strokeColor,
    this.horizontalShift = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(horizontalShift, 0),
      child: CustomPaint(
        size: const Size(220, 198),
        painter: _WindowLinePainter(
          strokeColor: strokeColor,
          graphicKey: graphicKey,
          windowLabel: windowLabel,
          displayIndex: displayIndex,
          windowCode: windowCode,
        ),
      ),
    );
  }
}

class _WindowLinePainter extends CustomPainter {
  final Color strokeColor;
  final String graphicKey;
  final String windowLabel;
  final int? displayIndex;
  final String? windowCode;

  const _WindowLinePainter({
    required this.strokeColor,
    required this.graphicKey,
    required this.windowLabel,
    required this.displayIndex,
    required this.windowCode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final String resolvedCode = (windowCode ?? '').trim();
    final bool hasCode = resolvedCode.isNotEmpty;
    final bool isFixWindow = resolvedCode == 'F_win';
    final bool isOpenableWindow = resolvedCode == 'O_win';
    final bool isSingleDoor = resolvedCode == 'Single_Door';
    final bool isDoubleDoor = resolvedCode == 'Double_Door';
    final bool isCornerFixWindow = resolvedCode == 'FC_win';
    final bool isRoundArchWindow = resolvedCode == 'A_win';
    final bool isRectangleArchWindow = resolvedCode == 'AR_win';
    final bool isDoorGateway = !hasCode && windowLabel == 'Door';
    final bool isArchGateway = !hasCode && windowLabel == 'Arch';

    final Rect frameRect = isFixWindow
        ? Rect.fromCenter(
            center: Offset(size.width / 2, size.height / 2),
            width: size.width * 0.50,
            height: size.width * 0.50,
          )
        : isOpenableWindow
        ? Rect.fromCenter(
            center: Offset(size.width / 2, size.height / 2),
            width: size.width * 0.44,
            height: size.height * 0.66,
          )
        : (isDoorGateway || isSingleDoor)
        ? Rect.fromCenter(
            center: Offset(size.width / 2, size.height / 2),
            width: size.width * 0.42,
            height: size.height * 0.70,
          )
        : isDoubleDoor
        ? Rect.fromCenter(
            center: Offset(size.width / 2, size.height / 2),
            width: size.width * 0.58,
            height: size.height * 0.74,
          )
        : (isArchGateway || isRoundArchWindow)
        ? Rect.fromCenter(
            center: Offset(size.width / 2, size.height / 2),
            width: size.width * 0.86,
            height: size.height * 0.50,
          )
        : isRectangleArchWindow
        ? Rect.fromCenter(
            center: Offset(size.width / 2, size.height / 2),
            width: size.width * 0.80,
            height: size.height * 0.38,
          )
        : Rect.fromLTWH(
            size.width * 0.08,
            size.height * 0.16,
            size.width * 0.84,
            size.height * 0.68,
          );

    if (isCornerFixWindow) {
      _drawCornerFix(canvas, frameRect, strokePaint);
      return;
    }

    if (graphicKey == 'corner_basic') {
      _drawCornerBasic(canvas, frameRect, strokePaint);
      return;
    }

    if (isArchGateway || isRoundArchWindow) {
      _drawRoundArch(canvas, frameRect, strokePaint);
      return;
    }

    canvas.drawRect(frameRect, strokePaint);

    if (graphicKey != 'panel_basic') {
      if (isRectangleArchWindow) {
        _drawCenteredText(
          canvas,
          text: 'F',
          center: frameRect.center,
          style: TextStyle(
            color: strokeColor.withValues(alpha: 0.95),
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        );
        return;
      }

      if (isDoubleDoor) {
        _drawDoubleDoorHandles(canvas, frameRect, strokePaint);
        return;
      }

      if (isDoorGateway || isSingleDoor) {
        _drawSingleDoorHandle(canvas, frameRect, strokePaint);
        return;
      }

      if (isOpenableWindow) {
        canvas.drawLine(frameRect.topLeft, frameRect.bottomRight, strokePaint);
        canvas.drawLine(frameRect.topRight, frameRect.bottomLeft, strokePaint);
        return;
      }

      if (isFixWindow) {
        _drawCenteredText(
          canvas,
          text: 'F',
          center: frameRect.center,
          style: TextStyle(
            color: strokeColor.withValues(alpha: 0.95),
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        );
        return;
      }

      canvas.drawLine(
        Offset(frameRect.center.dx, frameRect.top),
        Offset(frameRect.center.dx, frameRect.bottom),
        strokePaint,
      );
      return;
    }

    final _PanelPattern? pattern = _panelPatternFor(windowLabel);

    if (pattern == null) {
      final double leftDividerX = frameRect.left + (frameRect.width * 0.25);
      final double rightDividerX = frameRect.left + (frameRect.width * 0.75);
      canvas.drawLine(
        Offset(leftDividerX, frameRect.top),
        Offset(leftDividerX, frameRect.bottom),
        strokePaint,
      );
      canvas.drawLine(
        Offset(rightDividerX, frameRect.top),
        Offset(rightDividerX, frameRect.bottom),
        strokePaint,
      );
      return;
    }

    final List<double> dividerFractions = pattern.equalThreeSections
        ? const [1 / 3, 2 / 3]
        : const [0.25, 0.75];

    final List<double> dividerX = dividerFractions
        .map((double f) => frameRect.left + (frameRect.width * f))
        .toList();

    for (final double x in dividerX) {
      canvas.drawLine(
        Offset(x, frameRect.top),
        Offset(x, frameRect.bottom),
        strokePaint,
      );
    }

    if (pattern.hasCenterDivider) {
      canvas.drawLine(
        Offset(frameRect.center.dx, frameRect.top),
        Offset(frameRect.center.dx, frameRect.bottom),
        strokePaint,
      );
    }

    final TextStyle symbolStyle = TextStyle(
      color: strokeColor.withValues(alpha: 0.95),
      fontSize: 16,
      fontWeight: FontWeight.w700,
    );

    final List<double> bounds = <double>[
      frameRect.left,
      ...dividerX,
      if (pattern.hasCenterDivider) frameRect.center.dx,
      frameRect.right,
    ]..sort();

    final double centerY = frameRect.center.dy;

    for (int i = 0; i < pattern.symbols.length; i++) {
      final double left = bounds[i];
      final double right = bounds[i + 1];
      _drawCenteredText(
        canvas,
        text: pattern.symbols[i],
        center: Offset((left + right) / 2, centerY),
        style: symbolStyle,
      );
    }
  }

  void _drawRoundArch(Canvas canvas, Rect frameRect, Paint strokePaint) {
    final double sideTopY = frameRect.top + (frameRect.height * 0.40);
    final Offset leftBase = Offset(frameRect.left, frameRect.bottom);
    final Offset rightBase = Offset(frameRect.right, frameRect.bottom);
    final Offset leftTop = Offset(frameRect.left, sideTopY);
    final Offset rightTop = Offset(frameRect.right, sideTopY);

    canvas.drawLine(leftBase, rightBase, strokePaint);
    canvas.drawLine(leftBase, leftTop, strokePaint);
    canvas.drawLine(rightBase, rightTop, strokePaint);

    final Path topCurve = Path()
      ..moveTo(leftTop.dx, leftTop.dy)
      ..quadraticBezierTo(
        frameRect.center.dx,
        frameRect.top - (frameRect.height * 0.22),
        rightTop.dx,
        rightTop.dy,
      );
    canvas.drawPath(topCurve, strokePaint);

    _drawCenteredText(
      canvas,
      text: 'F',
      center: Offset(frameRect.center.dx, frameRect.center.dy + 3),
      style: TextStyle(
        color: strokeColor.withValues(alpha: 0.95),
        fontSize: 19,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  void _drawSingleDoorHandle(Canvas canvas, Rect frameRect, Paint strokePaint) {
    final Paint fillPaint = Paint()
      ..color = strokeColor.withValues(alpha: 0.95)
      ..style = PaintingStyle.fill;

    final Offset handleCenter = Offset(
      frameRect.left + (frameRect.width * 0.16),
      frameRect.center.dy,
    );
    final double radius = frameRect.width * 0.045;
    canvas.drawCircle(handleCenter, radius, fillPaint);

    final Paint innerStrokePaint = Paint()
      ..color = strokeColor.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokePaint.strokeWidth;

    canvas.drawCircle(handleCenter, radius, innerStrokePaint);
  }

  void _drawDoubleDoorHandles(
    Canvas canvas,
    Rect frameRect,
    Paint strokePaint,
  ) {
    canvas.drawLine(
      Offset(frameRect.center.dx, frameRect.top),
      Offset(frameRect.center.dx, frameRect.bottom),
      strokePaint,
    );

    final Paint fillPaint = Paint()
      ..color = strokeColor.withValues(alpha: 0.95)
      ..style = PaintingStyle.fill;

    final double radius = frameRect.width * 0.045;
    final Offset leftHandle = Offset(
      frameRect.center.dx - (frameRect.width * 0.08),
      frameRect.center.dy,
    );
    final Offset rightHandle = Offset(
      frameRect.center.dx + (frameRect.width * 0.08),
      frameRect.center.dy,
    );

    canvas.drawCircle(leftHandle, radius, fillPaint);
    canvas.drawCircle(rightHandle, radius, fillPaint);
  }

  void _drawCornerFix(Canvas canvas, Rect frameRect, Paint strokePaint) {
    final Rect cornerRect = Rect.fromLTWH(
      frameRect.left + (frameRect.width * 0.06),
      frameRect.top + (frameRect.height * 0.10),
      frameRect.width * 0.88,
      frameRect.height * 0.78,
    );

    final double wingTopRise = cornerRect.height * 0.30;
    final double wingBottomDrop = cornerRect.height * 0.34;
    final double wingReach = cornerRect.width * 0.34;

    final Offset topApex = Offset(
      cornerRect.center.dx,
      cornerRect.top + cornerRect.height * 0.34,
    );
    final Offset bottomApex = Offset(
      cornerRect.center.dx,
      cornerRect.bottom - cornerRect.height * 0.02,
    );

    final Offset topLeftOuter = Offset(
      topApex.dx - wingReach,
      topApex.dy - wingTopRise,
    );
    final Offset topRightOuter = Offset(
      topApex.dx + wingReach,
      topApex.dy - wingTopRise,
    );
    final Offset bottomLeftOuter = Offset(
      bottomApex.dx - wingReach,
      bottomApex.dy - wingBottomDrop,
    );
    final Offset bottomRightOuter = Offset(
      bottomApex.dx + wingReach,
      bottomApex.dy - wingBottomDrop,
    );

    canvas.drawLine(topLeftOuter, topApex, strokePaint);
    canvas.drawLine(topApex, topRightOuter, strokePaint);
    canvas.drawLine(bottomLeftOuter, bottomApex, strokePaint);
    canvas.drawLine(bottomApex, bottomRightOuter, strokePaint);
    canvas.drawLine(topLeftOuter, bottomLeftOuter, strokePaint);
    canvas.drawLine(topRightOuter, bottomRightOuter, strokePaint);
    canvas.drawLine(topApex, bottomApex, strokePaint);

    final TextStyle symbolStyle = TextStyle(
      color: strokeColor.withValues(alpha: 0.95),
      fontSize: 18,
      fontWeight: FontWeight.w700,
    );

    final double centerY = ((topApex.dy + bottomApex.dy) / 2) - 10;
    final double leftCenterX = (topLeftOuter.dx + topApex.dx) / 2;
    final double rightCenterX = (topApex.dx + topRightOuter.dx) / 2;

    _drawCenteredText(
      canvas,
      text: 'F',
      center: Offset(leftCenterX, centerY),
      style: symbolStyle,
    );
    _drawCenteredText(
      canvas,
      text: 'F',
      center: Offset(rightCenterX, centerY),
      style: symbolStyle,
    );
  }

  void _drawCornerBasic(Canvas canvas, Rect frameRect, Paint strokePaint) {
    final double cornerInteriorDeg = 30;
    final double edgeAngleRad = cornerInteriorDeg * (math.pi / 180);
    final int? cornerIndex = _effectiveCornerIndex(displayIndex);
    final String resolvedCode = (windowCode ?? '').trim();
    final bool isLeftFix13 =
        resolvedCode == 'SCL_win' || resolvedCode == 'MSCL_win';
    final bool isRightFix14 =
        resolvedCode == 'SCR_win' || resolvedCode == 'MSCR_win';

    final Rect cornerRect = Rect.fromLTWH(
      frameRect.left + (frameRect.width * 0.02),
      frameRect.top + (frameRect.height * 0.02),
      frameRect.width * 0.96,
      frameRect.height * 0.96,
    );

    final double wingTopRise = cornerRect.height * 0.30;
    final double wingBottomDrop = cornerRect.height * 0.32;

    final double rawWingReach = wingTopRise / math.tan(edgeAngleRad);
    final double wingReach =
        (rawWingReach
            .clamp(cornerRect.width * 0.31, cornerRect.width * 0.40)
            .toDouble()) *
        0.94;
    final double leftWingScale = isLeftFix13 ? 0.5 : 1.0;
    final double rightWingScale = isRightFix14 ? 0.5 : 1.0;
    final double centerCompensation = isLeftFix13
        ? wingReach * 0.25
        : (isRightFix14 ? -wingReach * 0.25 : 0);

    final Offset topApex = Offset(
      cornerRect.center.dx - centerCompensation,
      cornerRect.top + cornerRect.height * 0.34,
    );
    final Offset bottomApex = Offset(
      cornerRect.center.dx - centerCompensation,
      cornerRect.bottom - cornerRect.height * 0.02,
    );

    final Offset topLeftOuter = Offset(
      topApex.dx - (wingReach * leftWingScale),
      topApex.dy - wingTopRise,
    );
    final Offset topRightOuter = Offset(
      topApex.dx + (wingReach * rightWingScale),
      topApex.dy - wingTopRise,
    );

    final Offset bottomLeftOuter = Offset(
      bottomApex.dx - (wingReach * leftWingScale),
      bottomApex.dy - wingBottomDrop,
    );
    final Offset bottomRightOuter = Offset(
      bottomApex.dx + (wingReach * rightWingScale),
      bottomApex.dy - wingBottomDrop,
    );

    canvas.drawLine(topLeftOuter, topApex, strokePaint);
    canvas.drawLine(topApex, topRightOuter, strokePaint);
    canvas.drawLine(bottomLeftOuter, bottomApex, strokePaint);
    canvas.drawLine(bottomApex, bottomRightOuter, strokePaint);

    canvas.drawLine(topLeftOuter, bottomLeftOuter, strokePaint);
    canvas.drawLine(topRightOuter, bottomRightOuter, strokePaint);
    canvas.drawLine(topApex, bottomApex, strokePaint);

    const double innerShiftT = 0.62;
    final double leftInnerShiftT = isRightFix14 ? 0.52 : innerShiftT;
    final double rightInnerShiftT = isLeftFix13 ? 0.52 : innerShiftT;
    final Offset leftTopInner = Offset.lerp(
      topApex,
      topLeftOuter,
      leftInnerShiftT,
    )!;
    final Offset leftBottomInner = Offset.lerp(
      bottomApex,
      bottomLeftOuter,
      leftInnerShiftT,
    )!;
    final Offset rightTopInner = Offset.lerp(
      topApex,
      topRightOuter,
      rightInnerShiftT,
    )!;
    final Offset rightBottomInner = Offset.lerp(
      bottomApex,
      bottomRightOuter,
      rightInnerShiftT,
    )!;

    if (!isLeftFix13) {
      canvas.drawLine(leftTopInner, leftBottomInner, strokePaint);
    }
    if (!isRightFix14) {
      canvas.drawLine(rightTopInner, rightBottomInner, strokePaint);
    }

    final _CornerPattern? pattern = _cornerPatternFor(
      windowLabel,
      cornerIndex,
      resolvedCode,
    );
    if (pattern == null) {
      return;
    }

    final TextStyle symbolStyle = TextStyle(
      color: strokeColor.withValues(alpha: 0.95),
      fontSize: 17,
      fontWeight: FontWeight.w700,
    );

    final List<double> panelBounds;
    if (isLeftFix13) {
      panelBounds = <double>[
        topLeftOuter.dx,
        topApex.dx,
        rightTopInner.dx,
        topRightOuter.dx,
      ];
    } else if (isRightFix14) {
      panelBounds = <double>[
        topLeftOuter.dx,
        leftTopInner.dx,
        topApex.dx,
        topRightOuter.dx,
      ];
    } else {
      panelBounds = <double>[
        topLeftOuter.dx,
        leftTopInner.dx,
        topApex.dx,
        rightTopInner.dx,
        topRightOuter.dx,
      ];
    }

    final double centerY = ((topApex.dy + bottomApex.dy) / 2) + 3;

    for (int i = 0; i < pattern.symbols.length; i++) {
      final String symbol = pattern.symbols[i];
      final double centerX = (panelBounds[i] + panelBounds[i + 1]) / 2;
      final bool isLeftWing = centerX < topApex.dx;
      final bool isRightWing = centerX > topApex.dx;
      final double wingRotationDeg = isLeftWing ? 30 : (isRightWing ? -30 : 0);
      final double yOffset = _cornerSymbolYOffset(
        windowLabel,
        cornerIndex,
        resolvedCode,
        i,
        symbol,
      );
      final bool placeArrowBelowLetter =
          (windowLabel == 'Sliding Corner Center Fix' &&
              (i == 0 || i == pattern.symbols.length - 1)) ||
          (resolvedCode == 'MSCS_win' && symbol.contains('S')) ||
          (cornerIndex == 13 && symbol.contains('<-')) ||
          (cornerIndex == 14 && symbol.contains('->'));
      final double belowArrowYOffset =
          resolvedCode == 'MSCS_win' && symbol.contains('S') ? 10 : 11;
      final bool placeArrowAboveLetter =
          windowLabel == 'Sliding Corner Center Slide' &&
          symbol.contains('S') &&
          resolvedCode != 'MSCS_win';

      final TextPainter letterPainter = _drawCenteredText(
        canvas,
        text: _extractLetter(symbol),
        center: Offset(centerX, centerY + yOffset),
        style: symbolStyle,
      );

      final bool hasRightArrow = symbol.contains('->');
      final bool hasLeftArrow = symbol.contains('<-');

      if (hasRightArrow || hasLeftArrow) {
        _drawCornerArrow(
          canvas,
          center: Offset(centerX, centerY + yOffset),
          letterWidth: letterPainter.width,
          color: strokeColor,
          rotateDeg: (placeArrowBelowLetter || placeArrowAboveLetter)
              ? 0
              : wingRotationDeg,
          drawLeft: hasLeftArrow,
          drawRight: hasRightArrow,
          placeBelowLetter: placeArrowBelowLetter,
          belowYOffset: belowArrowYOffset,
          placeAboveLetter: placeArrowAboveLetter,
        );
      }
    }
  }

  int? _effectiveCornerIndex(int? index) {
    if (index == null) {
      return null;
    }
    if (index >= 15 && index <= 18) {
      return index - 4;
    }
    return index;
  }

  String _extractLetter(String symbol) {
    if (symbol.contains('F')) {
      return 'F';
    }
    if (symbol.contains('S')) {
      return 'S';
    }
    return symbol;
  }

  double _cornerSymbolYOffset(
    String label,
    int? index,
    String resolvedCode,
    int panelIndex,
    String symbol,
  ) {
    switch (label) {
      case 'Sliding Corner Center Fix':
        if (index == 11) {
          if (symbol.contains('F')) {
            return -20;
          }
          if (symbol.contains('S')) {
            return -22;
          }
          return 0;
        }
        if (panelIndex == 0 || panelIndex == 3) {
          return -16;
        }
        return 0;
      case 'Sliding Corner Center Slide':
        if (resolvedCode == 'SCS_win') {
          if (symbol.contains('F')) {
            return -20;
          }
          if (symbol.contains('S')) {
            return -6;
          }
          return 0;
        }
        if (resolvedCode == 'MSCS_win') {
          if (symbol.contains('F')) {
            return -20;
          }
          if (symbol.contains('S')) {
            return -10;
          }
          return 0;
        }
        if (symbol.contains('F')) {
          return -8;
        }
        return 0;
      case 'Sliding Corner Left Fix':
        if ((resolvedCode == 'SCL_win' || resolvedCode == 'MSCL_win') &&
            panelIndex == 0) {
          return -10;
        }
        if ((resolvedCode == 'SCL_win' || resolvedCode == 'MSCL_win') &&
            symbol.contains('S')) {
          return -16;
        }
        return 0;
      case 'Sliding Corner Right Fix':
        if ((resolvedCode == 'SCR_win' || resolvedCode == 'MSCR_win') &&
            panelIndex == 0) {
          return -24;
        }
        if ((resolvedCode == 'SCR_win' || resolvedCode == 'MSCR_win') &&
            panelIndex == 2) {
          return -12;
        }
        return 0;
      default:
        return 0;
    }
  }

  _PanelPattern? _panelPatternFor(String label) {
    switch (label) {
      case 'Center Fix':
        return const _PanelPattern(
          symbols: ['S->', 'F', '<-S'],
          equalThreeSections: false,
          hasCenterDivider: false,
        );
      case 'Center Slide':
        return const _PanelPattern(
          symbols: ['F', '<-S', 'S->', 'F'],
          equalThreeSections: false,
          hasCenterDivider: true,
        );
      case 'Equal Panel':
        return const _PanelPattern(
          symbols: ['S->', 'F', '<-S'],
          equalThreeSections: true,
          hasCenterDivider: false,
        );
      case 'Sliding Equal Panel':
        return const _PanelPattern(
          symbols: ['S->', '<-S->', '<-S'],
          equalThreeSections: true,
          hasCenterDivider: false,
        );
      default:
        return null;
    }
  }

  _CornerPattern? _cornerPatternFor(
    String label,
    int? index,
    String resolvedCode,
  ) {
    switch (label) {
      case 'Sliding Corner Center Fix':
        return const _CornerPattern(symbols: ['S->', 'F', 'F', '<-S']);
      case 'Sliding Corner Center Slide':
        return const _CornerPattern(symbols: ['F', '<-S', 'S->', 'F']);
      case 'Sliding Corner Left Fix':
        if (resolvedCode == 'SCL_win' || resolvedCode == 'MSCL_win') {
          return const _CornerPattern(symbols: ['F', 'F', '<-S']);
        }
        return null;
      case 'Sliding Corner Right Fix':
        if (resolvedCode == 'SCR_win' || resolvedCode == 'MSCR_win') {
          return const _CornerPattern(symbols: ['S->', 'F', 'F']);
        }
        return null;
      default:
        return null;
    }
  }

  TextPainter _drawCenteredText(
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
      Offset(center.dx - (painter.width / 2), center.dy - (painter.height / 2)),
    );
    return painter;
  }

  void _drawCornerArrow(
    Canvas canvas, {
    required Offset center,
    required double letterWidth,
    required Color color,
    required double rotateDeg,
    required bool drawLeft,
    required bool drawRight,
    required bool placeBelowLetter,
    required double belowYOffset,
    required bool placeAboveLetter,
  }) {
    final Paint arrowPaint = Paint()
      ..color = color.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final double offsetFromLetter = (letterWidth / 2) + 3;
    const double shaft = 10;
    const double head = 4;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotateDeg * (math.pi / 180));

    if (drawRight) {
      if (placeBelowLetter) {
        final double y = belowYOffset;
        final double x1 = -shaft / 2;
        final double x2 = shaft / 2;
        canvas.drawLine(Offset(x1, y), Offset(x2, y), arrowPaint);
        canvas.drawLine(Offset(x2, y), Offset(x2 - head, y - head), arrowPaint);
        canvas.drawLine(Offset(x2, y), Offset(x2 - head, y + head), arrowPaint);
      } else if (placeAboveLetter) {
        const double y = -11;
        final double x1 = -shaft / 2;
        final double x2 = shaft / 2;
        canvas.drawLine(Offset(x1, y), Offset(x2, y), arrowPaint);
        canvas.drawLine(Offset(x2, y), Offset(x2 - head, y - head), arrowPaint);
        canvas.drawLine(Offset(x2, y), Offset(x2 - head, y + head), arrowPaint);
      } else {
        final double x1 = offsetFromLetter;
        final double x2 = offsetFromLetter + shaft;
        canvas.drawLine(Offset(x1, 0), Offset(x2, 0), arrowPaint);
        canvas.drawLine(Offset(x2, 0), Offset(x2 - head, -head), arrowPaint);
        canvas.drawLine(Offset(x2, 0), Offset(x2 - head, head), arrowPaint);
      }
    }

    if (drawLeft) {
      if (placeBelowLetter) {
        final double y = belowYOffset;
        final double x1 = shaft / 2;
        final double x2 = -shaft / 2;
        canvas.drawLine(Offset(x1, y), Offset(x2, y), arrowPaint);
        canvas.drawLine(Offset(x2, y), Offset(x2 + head, y - head), arrowPaint);
        canvas.drawLine(Offset(x2, y), Offset(x2 + head, y + head), arrowPaint);
      } else if (placeAboveLetter) {
        const double y = -11;
        final double x1 = shaft / 2;
        final double x2 = -shaft / 2;
        canvas.drawLine(Offset(x1, y), Offset(x2, y), arrowPaint);
        canvas.drawLine(Offset(x2, y), Offset(x2 + head, y - head), arrowPaint);
        canvas.drawLine(Offset(x2, y), Offset(x2 + head, y + head), arrowPaint);
      } else {
        final double x1 = -offsetFromLetter;
        final double x2 = -offsetFromLetter - shaft;
        canvas.drawLine(Offset(x1, 0), Offset(x2, 0), arrowPaint);
        canvas.drawLine(Offset(x2, 0), Offset(x2 + head, -head), arrowPaint);
        canvas.drawLine(Offset(x2, 0), Offset(x2 + head, head), arrowPaint);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WindowLinePainter oldDelegate) {
    return oldDelegate.strokeColor != strokeColor ||
        oldDelegate.graphicKey != graphicKey ||
        oldDelegate.windowLabel != windowLabel ||
        oldDelegate.displayIndex != displayIndex ||
        oldDelegate.windowCode != windowCode;
  }
}

class _PanelPattern {
  final List<String> symbols;
  final bool equalThreeSections;
  final bool hasCenterDivider;

  const _PanelPattern({
    required this.symbols,
    required this.equalThreeSections,
    required this.hasCenterDivider,
  });
}

class _CornerPattern {
  final List<String> symbols;

  const _CornerPattern({required this.symbols});
}
