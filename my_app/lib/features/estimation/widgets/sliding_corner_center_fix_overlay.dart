import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class SlidingCornerCenterFixOverlay extends StatelessWidget {
  final double interiorAngleDeg;
  final int? collarId;

  const SlidingCornerCenterFixOverlay({
    super.key,
    this.interiorAngleDeg = 26,
    this.collarId,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SlidingCornerCenterFixPainter(
        interiorAngleDeg: interiorAngleDeg,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _SlidingCornerCenterFixPainter extends CustomPainter {
  final double interiorAngleDeg;

  const _SlidingCornerCenterFixPainter({
    required this.interiorAngleDeg,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = AppTheme.deepTeal.withValues(alpha: 0.30);

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
    final Offset topApex = Offset(frame.center.dx, frame.top + frame.height * 0.30);
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
    final Offset rightSideBottom = bottomRightOuter + (rightSideDir * sideExtend);

    Offset nLeftSide = outwardNormal(topLeftOuter, bottomLeftOuter);
    if (nLeftSide.dx > 0) nLeftSide = nLeftSide * -1;
    Offset nRightSide = outwardNormal(topRightOuter, bottomRightOuter);
    if (nRightSide.dx < 0) nRightSide = nRightSide * -1;

    final Offset leftSideParallelTop = leftSideTop + (nLeftSide * sideParallelOffset);
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

    final Offset bottomLeftLower = bottomLeftOuter + (nBottomLeft * bottomOffset);
    final Offset bottomRightLower =
        bottomRightOuter + (nBottomRight * bottomOffset);
    final Offset leftShiftBottomApex = bottomApex + (nBottomLeft * bottomOffset);
    final Offset rightShiftBottomApex = bottomApex + (nBottomRight * bottomOffset);
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

    // Outer V-frame + side edges + center seam.
    canvas.drawLine(topLeftOuter, topApex, basePaint);
    canvas.drawLine(topApex, topRightOuter, basePaint);
    canvas.drawLine(bottomLeftOuter, bottomApex, basePaint);
    canvas.drawLine(bottomApex, bottomRightOuter, basePaint);
    canvas.drawLine(leftSideTop, leftSideBottom, basePaint);
    canvas.drawLine(rightSideTop, rightSideBottom, basePaint);
    canvas.drawLine(topApex, bottomApex, basePaint);

    // Draw second top/side/bottom boundaries as a continuous joined frame.
    canvas.drawLine(topLeftUpperJoin, topApexUpper, basePaint);
    canvas.drawLine(topApexUpper, topRightUpperJoin, basePaint);

    canvas.drawLine(topLeftUpperJoin, bottomLeftLowerJoin, basePaint);
    canvas.drawLine(topRightUpperJoin, bottomRightLowerJoin, basePaint);

    canvas.drawLine(bottomLeftLowerJoin, bottomApexLower, basePaint);
    canvas.drawLine(bottomApexLower, bottomRightLowerJoin, basePaint);

    // Small links between outer and inner corner boundaries.
    canvas.drawLine(topLeftOuter, topLeftUpperJoin, basePaint);
    canvas.drawLine(topRightOuter, topRightUpperJoin, basePaint);
    canvas.drawLine(bottomLeftOuter, bottomLeftLowerJoin, basePaint);
    canvas.drawLine(bottomRightOuter, bottomRightLowerJoin, basePaint);

    // Center small links (top and bottom).
    canvas.drawLine(topApex, topApexUpper, basePaint);
    canvas.drawLine(bottomApex, bottomApexLower, basePaint);

    // 4-panel split: one inner line per wing + center seam.
    const double panelSplitT = 0.52;
    Offset lerp(Offset a, Offset b, double t) =>
        Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t);

    final Offset leftInnerTop = lerp(topApex, topLeftBase, panelSplitT);
    final Offset leftInnerBottom = lerp(bottomApex, bottomLeftBase, panelSplitT);
    final Offset rightInnerTop = lerp(topApex, topRightBase, panelSplitT);
    final Offset rightInnerBottom = lerp(bottomApex, bottomRightBase, panelSplitT);

    canvas.drawLine(leftInnerTop, leftInnerBottom, basePaint);
    canvas.drawLine(rightInnerTop, rightInnerBottom, basePaint);
  }

  @override
  bool shouldRepaint(covariant _SlidingCornerCenterFixPainter oldDelegate) {
    return oldDelegate.interiorAngleDeg != interiorAngleDeg;
  }
}
