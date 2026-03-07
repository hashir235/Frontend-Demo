import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class SlidingCornerCenterFixOverlay extends StatelessWidget {
  final double interiorAngleDeg;
  final int? collarId;
  final String? windowCode;
  final String? selectedSection;

  const SlidingCornerCenterFixOverlay({
    super.key,
    this.interiorAngleDeg = 26,
    this.collarId,
    this.windowCode,
    this.selectedSection,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SlidingCornerCenterFixPainter(
        interiorAngleDeg: interiorAngleDeg,
        collarId: collarId,
        windowCode: windowCode,
        selectedSection: selectedSection,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _SlidingCornerCenterFixPainter extends CustomPainter {
  final double interiorAngleDeg;
  final int? collarId;
  final String? windowCode;
  final String? selectedSection;

  const _SlidingCornerCenterFixPainter({
    required this.interiorAngleDeg,
    required this.collarId,
    required this.windowCode,
    required this.selectedSection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = AppTheme.deepTeal.withValues(alpha: 0.30);
    final Paint highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..color = AppTheme.violet.withValues(alpha: 0.95);
    final TextStyle labelStyle = TextStyle(
      color: basePaint.color,
      fontSize: 11,
      fontWeight: FontWeight.w700,
    );
    final String normalizedSection =
        selectedSection?.trim().toUpperCase() ?? '';
    final bool onlyHighlightedSymbols = normalizedSection.isNotEmpty;

    // Tune these 4 numbers for quick visual adjustments.
    final Rect frame = Rect.fromLTWH(
      size.width * 0.06,
      size.height * 0.08,
      size.width * 0.88,
      size.height * 0.82,
    );

    final double clampedAngle = interiorAngleDeg.clamp(8, 120);
    final double halfRad = (clampedAngle * math.pi / 180) / 2;
    final double sinHalf = math.sin(halfRad);
    final double cosHalf = math.cos(halfRad);

    // Keep geometry bounded while preserving the angle relation.
    final double maxLenByWidth =
        (frame.width * 0.46) / (sinHalf == 0 ? 1 : sinHalf);
    final double maxLenByHeight =
        (frame.height * 0.27) / (cosHalf == 0 ? 1 : cosHalf);
    final double wingLen = math.min(maxLenByWidth, maxLenByHeight);

    // These factors make shape close to your sketch and easy to tweak.
    final Offset topApex = Offset(
      frame.center.dx,
      frame.top + frame.height * 0.30,
    );
    final Offset bottomApex = Offset(
      frame.center.dx,
      frame.bottom - frame.height * 0.14,
    );

    final Offset topLeftBase = Offset(
      topApex.dx - (wingLen * sinHalf),
      topApex.dy - (wingLen * cosHalf),
    );
    final Offset topRightBase = Offset(
      topApex.dx + (wingLen * sinHalf),
      topApex.dy - (wingLen * cosHalf),
    );

    // Bottom outers must stay ABOVE bottom apex so center is the deepest point.
    final Offset bottomLeftBase = Offset(
      bottomApex.dx - (wingLen * sinHalf),
      bottomApex.dy - (wingLen * cosHalf),
    );
    final Offset bottomRightBase = Offset(
      bottomApex.dx + (wingLen * sinHalf),
      bottomApex.dy - (wingLen * cosHalf),
    );

    // Keep inner diagram stable, and push only outer side frame slightly away.
    final double outerSideShift = size.width * 0.018;
    final Offset topLeftOuter = topLeftBase + Offset(-outerSideShift, 0);
    final Offset topRightOuter = topRightBase + Offset(outerSideShift, 0);
    final Offset bottomLeftOuter = bottomLeftBase + Offset(-outerSideShift, 0);
    final Offset bottomRightOuter = bottomRightBase + Offset(outerSideShift, 0);

    // Upper parallel top boundary (easy to tune).
    final double upperOffset = size.height * 0.045;
    Offset outwardNormal(Offset a, Offset b) {
      final Offset raw = Offset(b.dy - a.dy, -(b.dx - a.dx));
      final double len = raw.distance;
      if (len == 0) return Offset.zero;
      return Offset(raw.dx / len, raw.dy / len);
    }

    Offset lineIntersection(Offset p1, Offset p2, Offset p3, Offset p4) {
      final double d1x = p2.dx - p1.dx;
      final double d1y = p2.dy - p1.dy;
      final double d2x = p4.dx - p3.dx;
      final double d2y = p4.dy - p3.dy;
      final double cross = (d1x * d2y) - (d1y * d2x);
      if (cross.abs() < 0.0001) {
        return Offset((p2.dx + p3.dx) / 2, (p2.dy + p3.dy) / 2);
      }
      final double t =
          (((p3.dx - p1.dx) * d2y) - ((p3.dy - p1.dy) * d2x)) / cross;
      return Offset(p1.dx + (d1x * t), p1.dy + (d1y * t));
    }

    Offset mid(Offset a, Offset b) =>
        Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);

    void drawLabel(String text, Offset center, {Color? color}) {
      if (onlyHighlightedSymbols && color == null) {
        return;
      }
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: text,
          style: labelStyle.copyWith(color: color ?? labelStyle.color),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    }

    final Offset nLeft = outwardNormal(topLeftOuter, topApex);
    final Offset nRight = outwardNormal(topApex, topRightOuter);
    final Offset topLeftUpper = topLeftOuter + (nLeft * upperOffset);
    final Offset topRightUpper = topRightOuter + (nRight * upperOffset);
    final Offset leftShiftApex = topApex + (nLeft * upperOffset);
    final Offset rightShiftApex = topApex + (nRight * upperOffset);
    final Offset topApexUpper = lineIntersection(
      topLeftUpper,
      leftShiftApex,
      rightShiftApex,
      topRightUpper,
    );

    // Keep outer boundaries joined on exact corners (no extra protrusion).
    const double sideExtend = 0.0;
    final double sideParallelOffset = size.width * 0.024;
    Offset normalize(Offset v) {
      final double len = v.distance;
      if (len == 0) return Offset.zero;
      return Offset(v.dx / len, v.dy / len);
    }

    final Offset leftSideDir = normalize(bottomLeftOuter - topLeftOuter);
    final Offset rightSideDir = normalize(bottomRightOuter - topRightOuter);

    final Offset leftSideTop = topLeftOuter - (leftSideDir * sideExtend);
    final Offset leftSideBottom = bottomLeftOuter + (leftSideDir * sideExtend);
    final Offset rightSideTop = topRightOuter - (rightSideDir * sideExtend);
    final Offset rightSideBottom =
        bottomRightOuter + (rightSideDir * sideExtend);

    Offset nLeftSide = outwardNormal(topLeftOuter, bottomLeftOuter);
    if (nLeftSide.dx > 0) nLeftSide = nLeftSide * -1;
    Offset nRightSide = outwardNormal(topRightOuter, bottomRightOuter);
    if (nRightSide.dx < 0) nRightSide = nRightSide * -1;

    final Offset leftSideParallelTop =
        leftSideTop + (nLeftSide * sideParallelOffset);
    final Offset leftSideParallelBottom =
        leftSideBottom + (nLeftSide * sideParallelOffset);
    final Offset rightSideParallelTop =
        rightSideTop + (nRightSide * sideParallelOffset);
    final Offset rightSideParallelBottom =
        rightSideBottom + (nRightSide * sideParallelOffset);

    // Bottom parallel boundary + connectors.
    final double bottomOffset = size.height * 0.040;
    Offset nBottomLeft = outwardNormal(bottomLeftOuter, bottomApex);
    if (nBottomLeft.dy < 0) nBottomLeft = nBottomLeft * -1;
    Offset nBottomRight = outwardNormal(bottomApex, bottomRightOuter);
    if (nBottomRight.dy < 0) nBottomRight = nBottomRight * -1;

    final Offset bottomLeftLower =
        bottomLeftOuter + (nBottomLeft * bottomOffset);
    final Offset bottomRightLower =
        bottomRightOuter + (nBottomRight * bottomOffset);
    final Offset leftShiftBottomApex =
        bottomApex + (nBottomLeft * bottomOffset);
    final Offset rightShiftBottomApex =
        bottomApex + (nBottomRight * bottomOffset);
    final Offset bottomApexLower = lineIntersection(
      bottomLeftLower,
      leftShiftBottomApex,
      rightShiftBottomApex,
      bottomRightLower,
    );

    // Join outer parallel boundaries directly (remove tiny corner connector lines).
    final Offset topLeftUpperJoin = lineIntersection(
      topLeftUpper,
      topApexUpper,
      leftSideParallelTop,
      leftSideParallelBottom,
    );
    final Offset topRightUpperJoin = lineIntersection(
      topApexUpper,
      topRightUpper,
      rightSideParallelTop,
      rightSideParallelBottom,
    );
    final Offset bottomLeftLowerJoin = lineIntersection(
      bottomLeftLower,
      bottomApexLower,
      leftSideParallelTop,
      leftSideParallelBottom,
    );
    final Offset bottomRightLowerJoin = lineIntersection(
      bottomApexLower,
      bottomRightLower,
      rightSideParallelTop,
      rightSideParallelBottom,
    );

    // Collar 2: hide primary outer frame + corner links, keep inner frame.
    final bool showPrimaryOuterGeometry = collarId != 2;
    const bool showSecondaryInnerFrame = true;
    final bool showCornerSmallLinks = collarId != 2;
    final bool showOuterLabels = true;

    final bool hideCenterSeamForCollar =
        (windowCode == 'SCF_win' ||
            windowCode == 'FC_win' ||
            windowCode == 'SCL_win' ||
            windowCode == 'SCR_win') &&
        (collarId == 1 || collarId == 2);
    final bool showCenterSeam = !hideCenterSeamForCollar;

    // Center seam for applicable variants.
    if (showCenterSeam) {
      canvas.drawLine(topApex, bottomApex, basePaint);
    }

    if (showPrimaryOuterGeometry) {
      // Outer V-frame + side edges.
      canvas.drawLine(topLeftOuter, topApex, basePaint);
      canvas.drawLine(topApex, topRightOuter, basePaint);
      canvas.drawLine(bottomLeftOuter, bottomApex, basePaint);
      canvas.drawLine(bottomApex, bottomRightOuter, basePaint);
      canvas.drawLine(leftSideTop, leftSideBottom, basePaint);
      canvas.drawLine(rightSideTop, rightSideBottom, basePaint);
    }

    if (showSecondaryInnerFrame) {
      // Draw second top/side/bottom boundaries as a continuous joined frame.
      canvas.drawLine(topLeftUpperJoin, topApexUpper, basePaint);
      canvas.drawLine(topApexUpper, topRightUpperJoin, basePaint);

      canvas.drawLine(topLeftUpperJoin, bottomLeftLowerJoin, basePaint);
      canvas.drawLine(topRightUpperJoin, bottomRightLowerJoin, basePaint);

      canvas.drawLine(bottomLeftLowerJoin, bottomApexLower, basePaint);
      canvas.drawLine(bottomApexLower, bottomRightLowerJoin, basePaint);
    }

    if (showCornerSmallLinks) {
      // Small links between outer and inner corner boundaries.
      canvas.drawLine(topLeftOuter, topLeftUpperJoin, basePaint);
      canvas.drawLine(topRightOuter, topRightUpperJoin, basePaint);
      canvas.drawLine(bottomLeftOuter, bottomLeftLowerJoin, basePaint);
      canvas.drawLine(bottomRightOuter, bottomRightLowerJoin, basePaint);
    }

    // Center small links (top and bottom).
    if (showCenterSeam) {
      canvas.drawLine(topApex, topApexUpper, basePaint);
      canvas.drawLine(bottomApex, bottomApexLower, basePaint);
    }

    // 4-panel split: one inner line per wing + center seam.
    const double panelSplitT = 0.52;
    Offset lerp(Offset a, Offset b, double t) =>
        Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t);

    // For collar 2, make inner center lines fully meet the top/bottom inner lines.
    final Offset leftInnerTop = collarId == 2
        ? lerp(topApexUpper, topLeftUpperJoin, panelSplitT)
        : lerp(topApex, topLeftBase, panelSplitT);
    final Offset leftInnerBottom = collarId == 2
        ? lerp(bottomApexLower, bottomLeftLowerJoin, panelSplitT)
        : lerp(bottomApex, bottomLeftBase, panelSplitT);
    final Offset rightInnerTop = collarId == 2
        ? lerp(topApexUpper, topRightUpperJoin, panelSplitT)
        : lerp(topApex, topRightBase, panelSplitT);
    final Offset rightInnerBottom = collarId == 2
        ? lerp(bottomApexLower, bottomRightLowerJoin, panelSplitT)
        : lerp(bottomApex, bottomRightBase, panelSplitT);

    final bool isSclCollar =
        windowCode == 'SCL_win' && (collarId == 1 || collarId == 2);
    final bool isScrCollar =
        windowCode == 'SCR_win' && (collarId == 1 || collarId == 2);
    final bool isFcCollar =
        windowCode == 'FC_win' && (collarId == 1 || collarId == 2);
    final bool isFcSectionCollar = isFcCollar;
    final bool isScCornerSectionCollar =
        (windowCode == 'SCF_win' ||
            windowCode == 'SCS_win' ||
            windowCode == 'SCL_win' ||
            windowCode == 'SCR_win') &&
        (collarId == 1 || collarId == 2);
    final bool highlightDc30F =
        isScCornerSectionCollar &&
        collarId == 1 &&
        normalizedSection == 'DC30F';
    final bool highlightDc26F =
        isScCornerSectionCollar &&
        collarId == 1 &&
        normalizedSection == 'DC26F';
    final bool highlightDc30C =
        isScCornerSectionCollar &&
        collarId == 2 &&
        normalizedSection == 'DC30C';
    final bool highlightDc26C =
        isScCornerSectionCollar &&
        collarId == 2 &&
        normalizedSection == 'DC26C';
    final bool highlightD29 =
        isScCornerSectionCollar && normalizedSection == 'D29';
    final bool highlightM23 =
        isScCornerSectionCollar && normalizedSection == 'M23';
    final bool highlightM28 =
        isScCornerSectionCollar && normalizedSection == 'M28';
    final bool highlightM24 =
        isScCornerSectionCollar && normalizedSection == 'M24';
    if (!isSclCollar && !isFcCollar) {
      canvas.drawLine(leftInnerTop, leftInnerBottom, basePaint);
    }
    if (!isScrCollar && !isFcCollar) {
      canvas.drawLine(rightInnerTop, rightInnerBottom, basePaint);
    }

    if (showOuterLabels) {
      // Outer symbols.
      final double topLabelGap = size.height * 0.074;
      final double sideLabelGap = size.width * 0.050;
      final double bottomLabelGap = size.height * 0.074;
      final double sideXPush = size.width * 0.015;
      final double topYPush = size.height * 0.026;
      final double bottomYPush = size.height * 0.030;

      drawLabel(
        'WT_L',
        mid(topLeftOuter, topApex) +
            (nLeft * topLabelGap) +
            Offset(0, -topYPush),
      );
      drawLabel(
        'WT_R',
        mid(topApex, topRightOuter) +
            (nRight * topLabelGap) +
            Offset(0, -topYPush),
      );

      drawLabel(
        'HL',
        mid(leftSideTop, leftSideBottom) +
            (nLeftSide * sideLabelGap) +
            Offset(-sideXPush, 0),
      );
      if (collarId == 1 || collarId == 2) {
        // Extra H on inner side-lines near HL/HR.
        drawLabel(
          'H',
          mid(leftSideParallelTop, leftSideParallelBottom) +
              Offset(size.width * 0.052, 0),
        );
        drawLabel(
          'H',
          mid(rightSideParallelTop, rightSideParallelBottom) +
              Offset(-size.width * 0.052, 0),
        );
      }
      drawLabel(
        'HR',
        mid(rightSideTop, rightSideBottom) +
            (nRightSide * sideLabelGap) +
            Offset(sideXPush, 0),
      );

      drawLabel(
        'WB_L',
        mid(bottomLeftOuter, bottomApex) +
            (nBottomLeft * bottomLabelGap) +
            Offset(0, bottomYPush),
      );
      drawLabel(
        'WB_R',
        mid(bottomApex, bottomRightOuter) +
            (nBottomRight * bottomLabelGap) +
            Offset(0, bottomYPush),
      );
    }

    // Collar 1: inner symbols.
    if (collarId == 1 || collarId == 2) {
      final double hEdgeGap = size.width * 0.020;
      final double hCenterGap = size.width * 0.028;
      final double topInnerY = size.height * 0.048;
      final double bottomInnerY = size.height * 0.036;
      final double leftPanelX = size.width * 0.006;
      final double rightPanelX = size.width * 0.006;

      final Offset leftMid = mid(leftInnerTop, leftInnerBottom);
      final Offset centerMid = mid(topApex, bottomApex);
      final Offset rightMid = mid(rightInnerTop, rightInnerBottom);
      final bool hideLeftMidH = isSclCollar || isFcCollar;
      final bool hideRightMidH = isScrCollar || isFcCollar;
      final bool hideCenterMidH = hideCenterSeamForCollar;

      // H rules: edge lines and center line labels.
      if (!hideLeftMidH) {
        drawLabel('H', leftMid + Offset(-hEdgeGap, 0));
        drawLabel('H', leftMid + Offset(hEdgeGap, 0));
      }
      if (!hideCenterMidH) {
        drawLabel('H', centerMid + Offset(-hCenterGap, 0));
        drawLabel('H', centerMid + Offset(hCenterGap, 0));
      }
      if (!hideRightMidH) {
        drawLabel('H', rightMid + Offset(-hEdgeGap, 0));
        drawLabel('H', rightMid + Offset(hEdgeGap, 0));
      }

      // 4-panel WL-WL-WR-WR mapping (top row).
      if (isFcCollar) {
        drawLabel(
          'WL',
          (collarId == 2
                  ? mid(topLeftUpperJoin, topApexUpper)
                  : mid(topLeftBase, topApex)) +
              Offset(-leftPanelX, topInnerY),
        );
      } else if (isSclCollar) {
        drawLabel(
          'WL',
          (collarId == 2
                  ? mid(topLeftUpperJoin, topApexUpper)
                  : mid(topLeftBase, topApex)) +
              Offset(-leftPanelX, topInnerY),
        );
      } else {
        drawLabel(
          'WL',
          mid(topLeftBase, leftInnerTop) + Offset(-leftPanelX, topInnerY),
        );
        drawLabel(
          'WL',
          mid(leftInnerTop, topApex) + Offset(-leftPanelX, topInnerY),
        );
      }
      if (isFcCollar) {
        drawLabel(
          'WR',
          (collarId == 2
                  ? mid(topApexUpper, topRightUpperJoin)
                  : mid(topApex, topRightBase)) +
              Offset(rightPanelX, topInnerY),
        );
      } else if (isScrCollar) {
        drawLabel(
          'WR',
          (collarId == 2
                  ? mid(topApexUpper, topRightUpperJoin)
                  : mid(topApex, topRightBase)) +
              Offset(rightPanelX, topInnerY),
        );
      } else {
        drawLabel(
          'WR',
          mid(topApex, rightInnerTop) + Offset(rightPanelX, topInnerY),
        );
        drawLabel(
          'WR',
          mid(rightInnerTop, topRightBase) + Offset(rightPanelX, topInnerY),
        );
      }

      // 4-panel WL-WL-WR-WR mapping (bottom row).
      if (isFcCollar) {
        drawLabel(
          'WL',
          (collarId == 2
                  ? mid(bottomLeftLowerJoin, bottomApexLower)
                  : mid(bottomLeftBase, bottomApex)) +
              Offset(-leftPanelX, -bottomInnerY),
        );
      } else if (isSclCollar) {
        drawLabel(
          'WL',
          (collarId == 2
                  ? mid(bottomLeftLowerJoin, bottomApexLower)
                  : mid(bottomLeftBase, bottomApex)) +
              Offset(-leftPanelX, -bottomInnerY),
        );
      } else {
        drawLabel(
          'WL',
          mid(bottomLeftBase, leftInnerBottom) +
              Offset(-leftPanelX, -bottomInnerY),
        );
        drawLabel(
          'WL',
          mid(leftInnerBottom, bottomApex) + Offset(-leftPanelX, -bottomInnerY),
        );
      }
      if (isFcCollar) {
        drawLabel(
          'WR',
          (collarId == 2
                  ? mid(bottomApexLower, bottomRightLowerJoin)
                  : mid(bottomApex, bottomRightBase)) +
              Offset(rightPanelX, -bottomInnerY),
        );
      } else if (isScrCollar) {
        drawLabel(
          'WR',
          (collarId == 2
                  ? mid(bottomApexLower, bottomRightLowerJoin)
                  : mid(bottomApex, bottomRightBase)) +
              Offset(rightPanelX, -bottomInnerY),
        );
      } else {
        drawLabel(
          'WR',
          mid(bottomApex, rightInnerBottom) +
              Offset(rightPanelX, -bottomInnerY),
        );
        drawLabel(
          'WR',
          mid(rightInnerBottom, bottomRightBase) +
              Offset(rightPanelX, -bottomInnerY),
        );
      }
    }

    if (isFcSectionCollar) {
      final Color accent = highlightPaint.color;
      final double leftPanelX = size.width * 0.006;
      final double rightPanelX = size.width * 0.006;
      final double topInnerY = size.height * 0.048;
      final double bottomInnerY = size.height * 0.036;
      final bool highlightFcD54F = collarId == 1 && normalizedSection == 'D54F';
      final bool highlightFcD54A = collarId == 2 && normalizedSection == 'D54A';
      final bool highlightFcD41 = normalizedSection == 'D41';
      final bool highlightAllVisibleLines =
          highlightFcD54F || highlightFcD54A || highlightFcD41;
      final bool highlightOuterFcSymbols = highlightFcD54F || highlightFcD54A;
      final bool highlightInnerFcSymbols = highlightFcD41;

      if (highlightAllVisibleLines) {
        if (showPrimaryOuterGeometry) {
          canvas.drawLine(topLeftOuter, topApex, highlightPaint);
          canvas.drawLine(topApex, topRightOuter, highlightPaint);
          canvas.drawLine(bottomLeftOuter, bottomApex, highlightPaint);
          canvas.drawLine(bottomApex, bottomRightOuter, highlightPaint);
          canvas.drawLine(leftSideTop, leftSideBottom, highlightPaint);
          canvas.drawLine(rightSideTop, rightSideBottom, highlightPaint);
        }

        canvas.drawLine(topLeftUpperJoin, topApexUpper, highlightPaint);
        canvas.drawLine(topApexUpper, topRightUpperJoin, highlightPaint);
        canvas.drawLine(topLeftUpperJoin, bottomLeftLowerJoin, highlightPaint);
        canvas.drawLine(
          topRightUpperJoin,
          bottomRightLowerJoin,
          highlightPaint,
        );
        canvas.drawLine(bottomLeftLowerJoin, bottomApexLower, highlightPaint);
        canvas.drawLine(bottomApexLower, bottomRightLowerJoin, highlightPaint);

        if (showCornerSmallLinks) {
          canvas.drawLine(topLeftOuter, topLeftUpperJoin, highlightPaint);
          canvas.drawLine(topRightOuter, topRightUpperJoin, highlightPaint);
          canvas.drawLine(bottomLeftOuter, bottomLeftLowerJoin, highlightPaint);
          canvas.drawLine(
            bottomRightOuter,
            bottomRightLowerJoin,
            highlightPaint,
          );
        }
      }

      if (highlightOuterFcSymbols) {
        drawLabel(
          'WT_L',
          mid(topLeftOuter, topApex) +
              (nLeft * (size.height * 0.074)) +
              Offset(0, -(size.height * 0.026)),
          color: accent,
        );
        drawLabel(
          'WT_R',
          mid(topApex, topRightOuter) +
              (nRight * (size.height * 0.074)) +
              Offset(0, -(size.height * 0.026)),
          color: accent,
        );
        drawLabel(
          'HL',
          mid(leftSideTop, leftSideBottom) +
              (nLeftSide * (size.width * 0.050)) +
              Offset(-(size.width * 0.015), 0),
          color: accent,
        );
        drawLabel(
          'HR',
          mid(rightSideTop, rightSideBottom) +
              (nRightSide * (size.width * 0.050)) +
              Offset(size.width * 0.015, 0),
          color: accent,
        );
        drawLabel(
          'WB_L',
          mid(bottomLeftOuter, bottomApex) +
              (nBottomLeft * (size.height * 0.074)) +
              Offset(0, size.height * 0.030),
          color: accent,
        );
        drawLabel(
          'WB_R',
          mid(bottomApex, bottomRightOuter) +
              (nBottomRight * (size.height * 0.074)) +
              Offset(0, size.height * 0.030),
          color: accent,
        );
      }

      if (highlightInnerFcSymbols) {
        drawLabel(
          'WL',
          (collarId == 2
                  ? mid(topLeftUpperJoin, topApexUpper)
                  : mid(topLeftBase, topApex)) +
              Offset(-leftPanelX, topInnerY),
          color: accent,
        );
        drawLabel(
          'WR',
          (collarId == 2
                  ? mid(topApexUpper, topRightUpperJoin)
                  : mid(topApex, topRightBase)) +
              Offset(rightPanelX, topInnerY),
          color: accent,
        );
        drawLabel(
          'WL',
          (collarId == 2
                  ? mid(bottomLeftLowerJoin, bottomApexLower)
                  : mid(bottomLeftBase, bottomApex)) +
              Offset(-leftPanelX, -bottomInnerY),
          color: accent,
        );
        drawLabel(
          'WR',
          (collarId == 2
                  ? mid(bottomApexLower, bottomRightLowerJoin)
                  : mid(bottomApex, bottomRightBase)) +
              Offset(rightPanelX, -bottomInnerY),
          color: accent,
        );
      }
    }

    // SCF collar section highlight behavior.
    if (isScCornerSectionCollar) {
      final Color accent = highlightPaint.color;
      final double hEdgeGap = size.width * 0.020;
      final double hCenterGap = size.width * 0.028;
      final double leftPanelX = size.width * 0.006;
      final double rightPanelX = size.width * 0.006;
      final double topInnerY = size.height * 0.048;
      final double bottomInnerY = size.height * 0.036;

      final Offset leftMid = mid(leftInnerTop, leftInnerBottom);
      final Offset centerMid = mid(topApex, bottomApex);
      final Offset rightMid = mid(rightInnerTop, rightInnerBottom);
      final bool usesCollar2InnerFrame = collarId == 2;
      final bool isScsHighlight = windowCode == 'SCS_win';
      final bool allowLeftD29 = !isSclCollar;
      final bool allowRightD29 = !isScrCollar;
      final bool allowLeftM28 = !isSclCollar;
      final bool allowRightM28 = !isScrCollar;
      final bool allowLeftM24 = !isSclCollar;
      final bool allowRightM24 = !isScrCollar;

      if (highlightDc30F) {
        // Top outer + inner rails.
        canvas.drawLine(topLeftOuter, topApex, highlightPaint);
        canvas.drawLine(topApex, topRightOuter, highlightPaint);
        canvas.drawLine(topLeftUpperJoin, topApexUpper, highlightPaint);
        canvas.drawLine(topApexUpper, topRightUpperJoin, highlightPaint);

        // Left/right outer + inner verticals.
        canvas.drawLine(leftSideTop, leftSideBottom, highlightPaint);
        canvas.drawLine(rightSideTop, rightSideBottom, highlightPaint);
        canvas.drawLine(
          leftSideParallelTop,
          leftSideParallelBottom,
          highlightPaint,
        );
        canvas.drawLine(
          rightSideParallelTop,
          rightSideParallelBottom,
          highlightPaint,
        );

        // Corner small links.
        canvas.drawLine(topLeftOuter, topLeftUpperJoin, highlightPaint);
        canvas.drawLine(topRightOuter, topRightUpperJoin, highlightPaint);
        canvas.drawLine(bottomLeftOuter, bottomLeftLowerJoin, highlightPaint);
        canvas.drawLine(bottomRightOuter, bottomRightLowerJoin, highlightPaint);

        drawLabel(
          'WT_L',
          mid(topLeftOuter, topApex) +
              (nLeft * (size.height * 0.074)) +
              Offset(0, -(size.height * 0.026)),
          color: accent,
        );
        drawLabel(
          'WT_R',
          mid(topApex, topRightOuter) +
              (nRight * (size.height * 0.074)) +
              Offset(0, -(size.height * 0.026)),
          color: accent,
        );
        drawLabel(
          'HL',
          mid(leftSideTop, leftSideBottom) +
              (nLeftSide * (size.width * 0.050)) +
              Offset(-(size.width * 0.015), 0),
          color: accent,
        );
        drawLabel(
          'HR',
          mid(rightSideTop, rightSideBottom) +
              (nRightSide * (size.width * 0.050)) +
              Offset(size.width * 0.015, 0),
          color: accent,
        );
      }

      if (highlightDc30C) {
        // Collar 2 keeps the outer frame hidden, so only highlight visible inner frame.
        canvas.drawLine(topLeftUpperJoin, topApexUpper, highlightPaint);
        canvas.drawLine(topApexUpper, topRightUpperJoin, highlightPaint);
        canvas.drawLine(topLeftUpperJoin, bottomLeftLowerJoin, highlightPaint);
        canvas.drawLine(
          topRightUpperJoin,
          bottomRightLowerJoin,
          highlightPaint,
        );

        drawLabel(
          'WT_L',
          mid(topLeftOuter, topApex) +
              (nLeft * (size.height * 0.074)) +
              Offset(0, -(size.height * 0.026)),
          color: accent,
        );
        drawLabel(
          'WT_R',
          mid(topApex, topRightOuter) +
              (nRight * (size.height * 0.074)) +
              Offset(0, -(size.height * 0.026)),
          color: accent,
        );
        drawLabel(
          'HL',
          mid(leftSideTop, leftSideBottom) +
              (nLeftSide * (size.width * 0.050)) +
              Offset(-(size.width * 0.015), 0),
          color: accent,
        );
        drawLabel(
          'HR',
          mid(rightSideTop, rightSideBottom) +
              (nRightSide * (size.width * 0.050)) +
              Offset(size.width * 0.015, 0),
          color: accent,
        );
      }

      if (highlightDc26F) {
        // Bottom outer rails.
        canvas.drawLine(bottomLeftOuter, bottomApex, highlightPaint);
        canvas.drawLine(bottomApex, bottomRightOuter, highlightPaint);
        // Bottom inner rails.
        canvas.drawLine(bottomLeftLowerJoin, bottomApexLower, highlightPaint);
        canvas.drawLine(bottomApexLower, bottomRightLowerJoin, highlightPaint);
        // Bottom corner links.
        canvas.drawLine(bottomLeftOuter, bottomLeftLowerJoin, highlightPaint);
        canvas.drawLine(bottomRightOuter, bottomRightLowerJoin, highlightPaint);
        drawLabel(
          'WB_L',
          mid(bottomLeftOuter, bottomApex) +
              (nBottomLeft * (size.height * 0.074)) +
              Offset(0, size.height * 0.030),
          color: accent,
        );
        drawLabel(
          'WB_R',
          mid(bottomApex, bottomRightOuter) +
              (nBottomRight * (size.height * 0.074)) +
              Offset(0, size.height * 0.030),
          color: accent,
        );
      }

      if (highlightDc26C) {
        // Collar 2 keeps the outer frame hidden, so only highlight visible inner bottom.
        canvas.drawLine(bottomLeftLowerJoin, bottomApexLower, highlightPaint);
        canvas.drawLine(bottomApexLower, bottomRightLowerJoin, highlightPaint);
        drawLabel(
          'WB_L',
          mid(bottomLeftOuter, bottomApex) +
              (nBottomLeft * (size.height * 0.074)) +
              Offset(0, size.height * 0.030),
          color: accent,
        );
        drawLabel(
          'WB_R',
          mid(bottomApex, bottomRightOuter) +
              (nBottomRight * (size.height * 0.074)) +
              Offset(0, size.height * 0.030),
          color: accent,
        );
      }

      if (highlightD29) {
        // First and last panels.
        if (allowLeftD29) {
          if (usesCollar2InnerFrame) {
            canvas.drawLine(
              topLeftUpperJoin,
              bottomLeftLowerJoin,
              highlightPaint,
            );
          } else {
            canvas.drawLine(leftSideTop, leftSideBottom, highlightPaint);
          }
        }
        if (allowRightD29) {
          if (usesCollar2InnerFrame) {
            canvas.drawLine(
              topRightUpperJoin,
              bottomRightLowerJoin,
              highlightPaint,
            );
          } else {
            canvas.drawLine(rightSideTop, rightSideBottom, highlightPaint);
          }
        }

        if (allowLeftD29) {
          canvas.drawLine(leftInnerTop, leftInnerBottom, highlightPaint);
          canvas.drawLine(
            usesCollar2InnerFrame ? topLeftUpperJoin : topLeftBase,
            leftInnerTop,
            highlightPaint,
          );
          canvas.drawLine(
            usesCollar2InnerFrame ? bottomLeftLowerJoin : bottomLeftBase,
            leftInnerBottom,
            highlightPaint,
          );

          drawLabel(
            'WL',
            mid(
                  usesCollar2InnerFrame ? topLeftUpperJoin : topLeftBase,
                  leftInnerTop,
                ) +
                Offset(-leftPanelX, topInnerY),
            color: accent,
          );
          drawLabel(
            'WL',
            mid(
                  usesCollar2InnerFrame ? bottomLeftLowerJoin : bottomLeftBase,
                  leftInnerBottom,
                ) +
                Offset(-leftPanelX, -bottomInnerY),
            color: accent,
          );
          drawLabel(
            'H',
            mid(
                  usesCollar2InnerFrame ? topLeftUpperJoin : leftSideTop,
                  usesCollar2InnerFrame ? bottomLeftLowerJoin : leftSideBottom,
                ) +
                Offset(size.width * 0.022, 0),
            color: accent,
          );
          drawLabel('H', leftMid + Offset(-hEdgeGap, 0), color: accent);
        }
        if (allowRightD29) {
          canvas.drawLine(rightInnerTop, rightInnerBottom, highlightPaint);
          canvas.drawLine(
            rightInnerTop,
            usesCollar2InnerFrame ? topRightUpperJoin : topRightBase,
            highlightPaint,
          );
          canvas.drawLine(
            rightInnerBottom,
            usesCollar2InnerFrame ? bottomRightLowerJoin : bottomRightBase,
            highlightPaint,
          );

          drawLabel(
            'WR',
            mid(
                  rightInnerTop,
                  usesCollar2InnerFrame ? topRightUpperJoin : topRightBase,
                ) +
                Offset(rightPanelX, topInnerY),
            color: accent,
          );
          drawLabel(
            'WR',
            mid(
                  rightInnerBottom,
                  usesCollar2InnerFrame
                      ? bottomRightLowerJoin
                      : bottomRightBase,
                ) +
                Offset(rightPanelX, -bottomInnerY),
            color: accent,
          );
          drawLabel(
            'H',
            mid(
                  usesCollar2InnerFrame ? topRightUpperJoin : rightSideTop,
                  usesCollar2InnerFrame
                      ? bottomRightLowerJoin
                      : rightSideBottom,
                ) +
                Offset(-size.width * 0.022, 0),
            color: accent,
          );
          drawLabel('H', rightMid + Offset(hEdgeGap, 0), color: accent);
        }
      }

      if (highlightM23) {
        // Only inner side lines.
        canvas.drawLine(
          usesCollar2InnerFrame ? topLeftUpperJoin : leftSideTop,
          usesCollar2InnerFrame ? bottomLeftLowerJoin : leftSideBottom,
          highlightPaint,
        );
        canvas.drawLine(
          usesCollar2InnerFrame ? topRightUpperJoin : rightSideTop,
          usesCollar2InnerFrame ? bottomRightLowerJoin : rightSideBottom,
          highlightPaint,
        );
        if (isScsHighlight) {
          canvas.drawLine(topApex, bottomApex, highlightPaint);
        }
        // |H on left line and H| on right line.
        drawLabel(
          'H',
          mid(
                usesCollar2InnerFrame ? topLeftUpperJoin : leftSideTop,
                usesCollar2InnerFrame ? bottomLeftLowerJoin : leftSideBottom,
              ) +
              Offset(size.width * 0.022, 0),
          color: accent,
        );
        drawLabel(
          'H',
          mid(
                usesCollar2InnerFrame ? topRightUpperJoin : rightSideTop,
                usesCollar2InnerFrame ? bottomRightLowerJoin : rightSideBottom,
              ) +
              Offset(-size.width * 0.022, 0),
          color: accent,
        );
        if (isScsHighlight) {
          drawLabel('H', centerMid + Offset(-hCenterGap, 0), color: accent);
          drawLabel('H', centerMid + Offset(hCenterGap, 0), color: accent);
        }
      }

      if (highlightM28) {
        if (allowLeftM28) {
          canvas.drawLine(leftInnerTop, leftInnerBottom, highlightPaint);
          drawLabel('H', leftMid + Offset(-hEdgeGap, 0), color: accent);
          drawLabel('H', leftMid + Offset(hEdgeGap, 0), color: accent);
        }
        if (allowRightM28) {
          canvas.drawLine(rightInnerTop, rightInnerBottom, highlightPaint);
          drawLabel('H', rightMid + Offset(-hEdgeGap, 0), color: accent);
          drawLabel('H', rightMid + Offset(hEdgeGap, 0), color: accent);
        }
      }

      if (highlightM24) {
        if (usesCollar2InnerFrame) {
          // Only inner top/bottom rails for collar 2.
          if (isSclCollar) {
            canvas.drawLine(topLeftUpperJoin, topApexUpper, highlightPaint);
            canvas.drawLine(
              bottomLeftLowerJoin,
              bottomApexLower,
              highlightPaint,
            );
            drawLabel(
              'WL',
              mid(topLeftUpperJoin, topApexUpper) +
                  Offset(-leftPanelX, topInnerY),
              color: accent,
            );
            drawLabel(
              'WL',
              mid(bottomLeftLowerJoin, bottomApexLower) +
                  Offset(-leftPanelX, -bottomInnerY),
              color: accent,
            );
          } else if (allowLeftM24) {
            canvas.drawLine(topLeftUpperJoin, topApexUpper, highlightPaint);
            canvas.drawLine(
              bottomLeftLowerJoin,
              bottomApexLower,
              highlightPaint,
            );
            drawLabel(
              'WL',
              mid(topLeftUpperJoin, leftInnerTop) +
                  Offset(-leftPanelX, topInnerY),
              color: accent,
            );
            drawLabel(
              'WL',
              mid(leftInnerTop, topApexUpper) + Offset(-leftPanelX, topInnerY),
              color: accent,
            );
            drawLabel(
              'WL',
              mid(bottomLeftLowerJoin, leftInnerBottom) +
                  Offset(-leftPanelX, -bottomInnerY),
              color: accent,
            );
            drawLabel(
              'WL',
              mid(leftInnerBottom, bottomApexLower) +
                  Offset(-leftPanelX, -bottomInnerY),
              color: accent,
            );
          }
          if (isScrCollar) {
            canvas.drawLine(topApexUpper, topRightUpperJoin, highlightPaint);
            canvas.drawLine(
              bottomApexLower,
              bottomRightLowerJoin,
              highlightPaint,
            );
            drawLabel(
              'WR',
              mid(topApexUpper, topRightUpperJoin) +
                  Offset(rightPanelX, topInnerY),
              color: accent,
            );
            drawLabel(
              'WR',
              mid(bottomApexLower, bottomRightLowerJoin) +
                  Offset(rightPanelX, -bottomInnerY),
              color: accent,
            );
          } else if (allowRightM24) {
            canvas.drawLine(topApexUpper, topRightUpperJoin, highlightPaint);
            canvas.drawLine(
              bottomApexLower,
              bottomRightLowerJoin,
              highlightPaint,
            );
            drawLabel(
              'WR',
              mid(topApexUpper, rightInnerTop) + Offset(rightPanelX, topInnerY),
              color: accent,
            );
            drawLabel(
              'WR',
              mid(rightInnerTop, topRightUpperJoin) +
                  Offset(rightPanelX, topInnerY),
              color: accent,
            );
            drawLabel(
              'WR',
              mid(bottomApexLower, rightInnerBottom) +
                  Offset(rightPanelX, -bottomInnerY),
              color: accent,
            );
            drawLabel(
              'WR',
              mid(rightInnerBottom, bottomRightLowerJoin) +
                  Offset(rightPanelX, -bottomInnerY),
              color: accent,
            );
          }
        } else {
          // Only inner top/bottom rails.
          if (isSclCollar) {
            canvas.drawLine(topLeftOuter, topApex, highlightPaint);
            canvas.drawLine(bottomLeftOuter, bottomApex, highlightPaint);
            drawLabel(
              'WL',
              mid(topLeftBase, topApex) + Offset(-leftPanelX, topInnerY),
              color: accent,
            );
            drawLabel(
              'WL',
              mid(bottomLeftBase, bottomApex) +
                  Offset(-leftPanelX, -bottomInnerY),
              color: accent,
            );
          } else if (allowLeftM24) {
            canvas.drawLine(topLeftOuter, topApex, highlightPaint);
            canvas.drawLine(bottomLeftOuter, bottomApex, highlightPaint);
            drawLabel(
              'WL',
              mid(topLeftBase, leftInnerTop) + Offset(-leftPanelX, topInnerY),
              color: accent,
            );
            drawLabel(
              'WL',
              mid(leftInnerTop, topApex) + Offset(-leftPanelX, topInnerY),
              color: accent,
            );
            drawLabel(
              'WL',
              mid(bottomLeftBase, leftInnerBottom) +
                  Offset(-leftPanelX, -bottomInnerY),
              color: accent,
            );
            drawLabel(
              'WL',
              mid(leftInnerBottom, bottomApex) +
                  Offset(-leftPanelX, -bottomInnerY),
              color: accent,
            );
          }
          if (isScrCollar) {
            canvas.drawLine(topApex, topRightOuter, highlightPaint);
            canvas.drawLine(bottomApex, bottomRightOuter, highlightPaint);
            drawLabel(
              'WR',
              mid(topApex, topRightBase) + Offset(rightPanelX, topInnerY),
              color: accent,
            );
            drawLabel(
              'WR',
              mid(bottomApex, bottomRightBase) +
                  Offset(rightPanelX, -bottomInnerY),
              color: accent,
            );
          } else if (allowRightM24) {
            canvas.drawLine(topApex, topRightOuter, highlightPaint);
            canvas.drawLine(bottomApex, bottomRightOuter, highlightPaint);
            drawLabel(
              'WR',
              mid(topApex, rightInnerTop) + Offset(rightPanelX, topInnerY),
              color: accent,
            );
            drawLabel(
              'WR',
              mid(rightInnerTop, topRightBase) + Offset(rightPanelX, topInnerY),
              color: accent,
            );
            drawLabel(
              'WR',
              mid(bottomApex, rightInnerBottom) +
                  Offset(rightPanelX, -bottomInnerY),
              color: accent,
            );
            drawLabel(
              'WR',
              mid(rightInnerBottom, bottomRightBase) +
                  Offset(rightPanelX, -bottomInnerY),
              color: accent,
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SlidingCornerCenterFixPainter oldDelegate) {
    return oldDelegate.interiorAngleDeg != interiorAngleDeg ||
        oldDelegate.collarId != collarId ||
        oldDelegate.windowCode != windowCode ||
        oldDelegate.selectedSection != selectedSection;
  }
}
