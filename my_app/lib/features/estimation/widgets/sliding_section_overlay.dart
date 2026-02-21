import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class _ZoneSpec {
  final String section;
  final Rect rect;

  const _ZoneSpec(this.section, this.rect);
}

class _SlidingPainter extends CustomPainter {
  final String? selectedSection;
  final Map<String, String> sectionAliases;
  final int? collarId;
  final List<_ZoneSpec> zones;

  const _SlidingPainter({
    required this.selectedSection,
    required this.sectionAliases,
    required this.collarId,
    required this.zones,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Normalize selected section using alias map (base -> alias).
    String? effectiveSection = selectedSection;
    if (selectedSection != null) {
      // If selected matches an alias value, map back to its base key.
      final String? base = sectionAliases.entries
          .firstWhere(
            (e) => e.value == selectedSection,
            orElse: () => const MapEntry<String, String>('', ''),
          )
          .key;
      if (base != null && base.isNotEmpty) {
        effectiveSection = base;
      }
    }

    final double outerPadding = size.width * 0.08;
    final double outerWidth = size.width - (outerPadding * 2);
    final double outerHeight = size.height - (outerPadding * 2);
    final Rect outerRect = Rect.fromLTWH(
      outerPadding,
      outerPadding,
      outerWidth,
      outerHeight,
    );

    final double gap = size.width * 0.06;
    final Rect innerRect = outerRect.deflate(gap);
    final bool hideOuter = collarId == 2;
    final Rect labelRect = hideOuter ? innerRect : outerRect;

    final Paint basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = AppTheme.deepTeal.withValues(alpha: 0.28);

    final Paint highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = AppTheme.violet;

    // Outer + inner boxes
    if (!hideOuter) {
      if (collarId == 3) {
        // Draw outer left, right, bottom only (no top line)
        canvas.drawLine(outerRect.bottomLeft, outerRect.bottomRight, basePaint);
        canvas.drawLine(outerRect.topLeft, outerRect.bottomLeft, basePaint);
        canvas.drawLine(outerRect.topRight, outerRect.bottomRight, basePaint);
      } else if (collarId == 4) {
        // Draw outer top, left, bottom only (no right line)
        canvas.drawLine(outerRect.topLeft, outerRect.topRight, basePaint);
        canvas.drawLine(outerRect.bottomLeft, outerRect.bottomRight, basePaint);
        canvas.drawLine(outerRect.topLeft, outerRect.bottomLeft, basePaint);
      } else if (collarId == 5) {
        // Draw outer top, left, right only (no bottom line)
        canvas.drawLine(outerRect.topLeft, outerRect.topRight, basePaint);
        canvas.drawLine(outerRect.topLeft, outerRect.bottomLeft, basePaint);
        canvas.drawLine(outerRect.topRight, outerRect.bottomRight, basePaint);
      } else if (collarId == 6) {
        // Draw outer top, right, bottom only (no left line)
        canvas.drawLine(outerRect.topLeft, outerRect.topRight, basePaint);
        canvas.drawLine(outerRect.bottomLeft, outerRect.bottomRight, basePaint);
        canvas.drawLine(outerRect.topRight, outerRect.bottomRight, basePaint);
      } else if (collarId == 7) {
        // Draw outer right and bottom only (no top, no left)
        canvas.drawLine(outerRect.bottomLeft, outerRect.bottomRight, basePaint);
        canvas.drawLine(outerRect.topRight, outerRect.bottomRight, basePaint);
      } else {
        canvas.drawRect(outerRect, basePaint);
      }
    }
    canvas.drawRect(innerRect, basePaint);

    // Center vertical line inside inner box
    final Offset innerTopCenter = Offset(
      innerRect.left + innerRect.width / 2,
      innerRect.top,
    );
    final Offset innerBottomCenter = Offset(
      innerRect.left + innerRect.width / 2,
      innerRect.bottom,
    );
    canvas.drawLine(innerTopCenter, innerBottomCenter, basePaint);

    // Corner links (outer corners to inner corners)
    if (!hideOuter) {
      if (collarId != 7) {
        canvas.drawLine(outerRect.topLeft, innerRect.topLeft, basePaint);
      }
      canvas.drawLine(outerRect.topRight, innerRect.topRight, basePaint);
      // Restore bottom-left link for collar 7
      canvas.drawLine(outerRect.bottomLeft, innerRect.bottomLeft, basePaint);
      canvas.drawLine(outerRect.bottomRight, innerRect.bottomRight, basePaint);
    }

    // Labels (light tone like lines)
    const double fontSize = 12;
    final double labelGap = size.height * 0.012;
    final double sideGap = labelGap + size.width * 0.01;
    final bool highlightDc30F = effectiveSection == 'DC30F';
    final bool highlightDc30C = effectiveSection == 'DC30C';
    final bool highlightDc26F = effectiveSection == 'DC26F';
    final bool highlightM23 = effectiveSection == 'M23';
    final bool highlightM24 = effectiveSection == 'M24';
    final bool highlightM28 = effectiveSection == 'M28';
    final bool highlightD29 = effectiveSection == 'D29';
    final Set<String> highlightLabels = {
      if (highlightDc30F && collarId != 6 && collarId != 7) ...{'WL'},
      if (highlightDc30F && (collarId == 6 || collarId == 7)) ...{'WR'},
      if (highlightDc30F && collarId != 3 && collarId != 7) ...{'WT'},
      if (highlightDc30C && collarId == 7) ...{'WT', 'WL'},
      if (highlightDc30C && collarId != 4 && collarId != 6 && collarId != 7)
        ...{'WT'},
      if (highlightDc30C && collarId == 4) ...{'WR'},
      if (highlightDc30C && collarId == 6) ...{'WL'},
      if (highlightDc26F) ...{'WB'},
      if (highlightM24) ...{'W'},
      if (highlightM23) ...{'HL', 'HR'},
      // D29 should NOT highlight outer labels; handled in panel paint
    };

    TextPainter tpBuilder(String text) => TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: highlightLabels.contains(text)
              ? highlightPaint.color
              : basePaint.color,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // WT top center
    final TextPainter tpTop = tpBuilder('WT');
    double topY = labelRect.top - labelGap - tpTop.height;
    if (topY < 0) topY = 0;
    tpTop.paint(canvas, Offset(labelRect.center.dx - tpTop.width / 2, topY));

    // Special-case: collar 6 + DC30C -> only inner left + WL, nothing else
    if (collarId == 6 && effectiveSection == 'DC30C') {
      // Left inner line
      canvas.drawLine(
        Offset(innerRect.left, innerRect.top),
        Offset(innerRect.left, innerRect.bottom),
        highlightPaint,
      );
      // WL label force highlight
      final TextPainter tpLeftWL = TextPainter(
        text: TextSpan(
          text: 'WL',
          style: TextStyle(
            color: highlightPaint.color,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final double sideGapWL = labelGap + size.width * 0.01;
      double leftXWL = labelRect.left - (sideGapWL * 1.05) - tpLeftWL.width;
      if (leftXWL < 0) leftXWL = 0;
      tpLeftWL.paint(
        canvas,
        Offset(leftXWL, labelRect.center.dy - tpLeftWL.height / 2),
      );
      return;
    }

    // DC30F highlight set (top + verticals)
    if (highlightDc30F) {
      // Outer top (skip for collar 3)
      if (!hideOuter && collarId != 3 && collarId != 7) {
        canvas.drawLine(outerRect.topLeft, outerRect.topRight, highlightPaint);
      }
      // Inner top (skip for collar 3 per requirement)
      if (collarId != 3 && collarId != 7) {
        canvas.drawLine(
          Offset(innerRect.left, innerRect.top),
          Offset(innerRect.right, innerRect.top),
          highlightPaint,
        );
      }
      // Outer verticals
      if (!hideOuter) {
        if (collarId != 6 && collarId != 7) {
          canvas.drawLine(
            outerRect.topLeft,
            outerRect.bottomLeft,
            highlightPaint,
          );
        }
        if (collarId != 4) {
          canvas.drawLine(
            outerRect.topRight,
            outerRect.bottomRight,
            highlightPaint,
          );
        }
      }
      // Inner verticals (left/right)
      if (collarId != 6 && collarId != 7) {
        canvas.drawLine(
          Offset(innerRect.left, innerRect.top),
          Offset(innerRect.left, innerRect.bottom),
          highlightPaint,
        );
      }
      if (collarId != 4) {
        canvas.drawLine(
          Offset(innerRect.right, innerRect.top),
          Offset(innerRect.right, innerRect.bottom),
          highlightPaint,
        );
      }
      // Corner links (top + bottom)
      if (!hideOuter) {
        if (collarId != 7) {
          canvas.drawLine(outerRect.topLeft, innerRect.topLeft, highlightPaint);
        }
        if (collarId != 6 && collarId != 7) {
          canvas.drawLine(
            outerRect.bottomLeft,
            innerRect.bottomLeft,
            highlightPaint,
          );
        }
        canvas.drawLine(
          outerRect.topRight,
          innerRect.topRight,
          highlightPaint,
        );
        if (collarId != 4) {
          canvas.drawLine(
            outerRect.bottomRight,
            innerRect.bottomRight,
            highlightPaint,
          );
        }
      }
    }

    // DC26F highlight set (bottom + corner links)
    if (highlightDc26F) {
      // Outer bottom (skip for collar 5)
      if (!hideOuter && collarId != 5) {
        canvas.drawLine(
          outerRect.bottomLeft,
          outerRect.bottomRight,
          highlightPaint,
        );
      }
      // Inner bottom
      canvas.drawLine(
        Offset(innerRect.left, innerRect.bottom),
        Offset(innerRect.right, innerRect.bottom),
        highlightPaint,
      );
      // Corner links bottom (skip for collar 5)
      if (!hideOuter && collarId != 5) {
        canvas.drawLine(
          outerRect.bottomLeft,
          innerRect.bottomLeft,
          highlightPaint,
        );
        canvas.drawLine(
          outerRect.bottomRight,
          innerRect.bottomRight,
          highlightPaint,
        );
      }
    }

    // M24 highlight set (inner top + bottom + W labels)
    if (highlightM24) {
      canvas.drawLine(
        Offset(innerRect.left, innerRect.top),
        Offset(innerRect.right, innerRect.top),
        highlightPaint,
      );
      canvas.drawLine(
        Offset(innerRect.left, innerRect.bottom),
        Offset(innerRect.right, innerRect.bottom),
        highlightPaint,
      );
    }

    // DC30C highlight set (collar 3 top rail + WT)
    if (highlightDc30C) {
      if (collarId == 3) {
        // Inner top line only
        canvas.drawLine(
          Offset(innerRect.left, innerRect.top),
          Offset(innerRect.right, innerRect.top),
          highlightPaint,
        );
      } else if (collarId == 4) {
        // Only right inner vertical + WR label (outer edges stay off)
        canvas.drawLine(
          Offset(innerRect.right, innerRect.top),
          Offset(innerRect.right, innerRect.bottom),
          highlightPaint,
        );
      } else if (collarId == 6) {
        // Left side only (inner) with WL label
        canvas.drawLine(
          Offset(innerRect.left, innerRect.top),
          Offset(innerRect.left, innerRect.bottom),
          highlightPaint,
        );
        // No other highlights for this selection
        return;
      } else if (collarId == 7) {
        // Top (outer+inner) and left (outer+inner) only
        if (!hideOuter) {
          canvas.drawLine(outerRect.topLeft, outerRect.topRight, highlightPaint);
          canvas.drawLine(outerRect.topLeft, outerRect.bottomLeft, highlightPaint);
        }
        canvas.drawLine(
          Offset(innerRect.left, innerRect.top),
          Offset(innerRect.right, innerRect.top),
          highlightPaint,
        );
        canvas.drawLine(
          Offset(innerRect.left, innerRect.top),
          Offset(innerRect.left, innerRect.bottom),
          highlightPaint,
        );
        // Corner links on left side
        if (!hideOuter) {
          canvas.drawLine(outerRect.topLeft, innerRect.topLeft, highlightPaint);
          canvas.drawLine(
            outerRect.bottomLeft,
            innerRect.bottomLeft,
            highlightPaint,
          );
        }
      } else {
        // Default: inner top
        canvas.drawLine(
          Offset(innerRect.left, innerRect.top),
          Offset(innerRect.right, innerRect.top),
          highlightPaint,
        );
      }
    }

    // D29 highlight: inner left vertical, center vertical, and left halves of inner top/bottom
    if (highlightD29) {
      final double midX = innerRect.center.dx;
      // Inner left vertical
      canvas.drawLine(
        Offset(innerRect.left, innerRect.top),
        Offset(innerRect.left, innerRect.bottom),
        highlightPaint,
      );
      // Center vertical
      canvas.drawLine(
        Offset(midX, innerRect.top),
        Offset(midX, innerRect.bottom),
        highlightPaint,
      );
      // Inner top left half
      canvas.drawLine(
        Offset(innerRect.left, innerRect.top),
        Offset(midX, innerRect.top),
        highlightPaint,
      );
      // Inner bottom left half
      canvas.drawLine(
        Offset(innerRect.left, innerRect.bottom),
        Offset(midX, innerRect.bottom),
        highlightPaint,
      );
    }

    // WB bottom center
    final TextPainter tpBottom = tpBuilder('WB');
    double bottomY = labelRect.bottom + labelGap;
    if (bottomY + tpBottom.height > size.height) {
      bottomY = size.height - tpBottom.height;
    }
    tpBottom.paint(
      canvas,
      Offset(labelRect.center.dx - tpBottom.width / 2, bottomY),
    );

    // WL left side
    final TextPainter tpLeft = tpBuilder('WL');
    double leftX = labelRect.left - (sideGap * 1.05) - tpLeft.width;
    if (leftX < 0) leftX = 0;
    tpLeft.paint(
      canvas,
      Offset(leftX, labelRect.center.dy - tpLeft.height / 2),
    );

    // WR right side
    final TextPainter tpRight = tpBuilder('WR');
    double rightX = labelRect.right + (sideGap * 1.05);
    if (rightX + tpRight.width > size.width) {
      rightX = size.width - tpRight.width;
    }
    tpRight.paint(
      canvas,
      Offset(rightX, labelRect.center.dy - tpRight.height / 2),
    );

    // Inner panel labels (both panels share same styling)
    final TextPainter tpWBase = tpBuilder('W');
    TextPainter tpHBuilder(Color color) => TextPainter(
      text: TextSpan(
        text: 'H',
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final double innerGap = size.height * 0.01;
    final double midX = innerRect.center.dx;

    Rect leftPanel = Rect.fromLTRB(
      innerRect.left,
      innerRect.top,
      midX,
      innerRect.bottom,
    );
    Rect rightPanel = Rect.fromLTRB(
      midX,
      innerRect.top,
      innerRect.right,
      innerRect.bottom,
    );

    void paintPanelLabels(Rect panel, {required bool isLeftPanel}) {
      // Top W
      final bool highlightW = highlightM24 || (highlightD29 && isLeftPanel);
      final TextPainter tpWTop = highlightW
          ? (TextPainter(
              text: const TextSpan(
                text: 'W',
                style: TextStyle(
                  color: AppTheme.violet,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
            )..layout())
          : tpWBase;
      tpWTop.paint(
        canvas,
        Offset(panel.center.dx - tpWTop.width / 2, panel.top + innerGap),
      );
      // H near center seam and outer vertical
      final TextPainter tpHOuter = tpHBuilder(
        (highlightM23 || (highlightD29 && isLeftPanel))
            ? highlightPaint.color
            : basePaint.color,
      );
      final Color innerHColor = () {
        if (highlightM28) return highlightPaint.color;
        if (highlightD29) {
          // Only left panel inner H should glow for D29; right stays base
          return isLeftPanel ? highlightPaint.color : basePaint.color;
        }
        return basePaint.color;
      }();
      final TextPainter tpHInner = tpHBuilder(innerHColor);
      final double hInnerX = isLeftPanel
          ? panel.right - tpHInner.width - innerGap
          : panel.left + innerGap;
      final double hOuterX = isLeftPanel
          ? panel.left + innerGap
          : panel.right - tpHOuter.width - innerGap;
      final double hY = panel.center.dy - tpHOuter.height / 2;
      // Outer H highlights on M23; Inner H highlights on M28 or D29 (left side)
      tpHOuter.paint(canvas, Offset(hOuterX, hY));
      tpHInner.paint(canvas, Offset(hInnerX, hY));
      // Bottom W
      final TextPainter tpWBottom = highlightW
          ? (TextPainter(
              text: const TextSpan(
                text: 'W',
                style: TextStyle(
                  color: AppTheme.violet,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
            )..layout())
          : tpWBase;
      tpWBottom.paint(
        canvas,
        Offset(
          panel.center.dx - tpWBottom.width / 2,
          panel.bottom - innerGap - tpWBottom.height,
        ),
      );
    }

    paintPanelLabels(leftPanel, isLeftPanel: true);
    paintPanelLabels(rightPanel, isLeftPanel: false);

    // Old band-rectangle highlights removed; per-section highlights will be
    // drawn explicitly in dedicated branches.

    // M23 highlight: inner verticals + H labels
    if (highlightM23) {
      // Inner verticals (left/right)
      canvas.drawLine(
        Offset(innerRect.left, innerRect.top),
        Offset(innerRect.left, innerRect.bottom),
        highlightPaint,
      );
      canvas.drawLine(
        Offset(innerRect.right, innerRect.top),
        Offset(innerRect.right, innerRect.bottom),
        highlightPaint,
      );
    }

    // M28 highlight: center vertical only
    if (highlightM28) {
      canvas.drawLine(
        Offset(innerRect.center.dx, innerRect.top),
        Offset(innerRect.center.dx, innerRect.bottom),
        highlightPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SlidingPainter oldDelegate) {
    return oldDelegate.selectedSection != selectedSection;
  }
}

class SlidingSectionOverlay extends StatelessWidget {
  final String? selectedSection;
  final Map<String, String> sectionAliases;
  final int? collarId;

  const SlidingSectionOverlay({
    super.key,
    required this.selectedSection,
    this.sectionAliases = const {},
    this.collarId,
  });

  List<_ZoneSpec> _zones() {
    // Normalized zones aligned with outer/inner boxes
    return const <_ZoneSpec>[
      // Outer frame bands
      _ZoneSpec('DC30F', Rect.fromLTWH(0.08, 0.08, 0.84, 0.10)), // top rail
      _ZoneSpec('DC26F', Rect.fromLTWH(0.08, 0.82, 0.84, 0.10)), // bottom rail
      _ZoneSpec('D29', Rect.fromLTWH(0.08, 0.18, 0.10, 0.64)), // left stile
      _ZoneSpec('M23', Rect.fromLTWH(0.82, 0.18, 0.10, 0.64)), // right stile
      // Inner vertical + glass guides
      _ZoneSpec(
        'M24',
        Rect.fromLTWH(0.20, 0.22, 0.60, 0.06),
      ), // upper mullion band
      _ZoneSpec(
        'M28',
        Rect.fromLTWH(0.42, 0.22, 0.16, 0.56),
      ), // center divider band
    ];
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SlidingPainter(
        selectedSection: selectedSection,
        sectionAliases: sectionAliases,
        collarId: collarId,
        zones: _zones(),
      ),
      child: const SizedBox.expand(),
    );
  }
}
