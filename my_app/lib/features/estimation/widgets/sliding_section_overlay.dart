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
      } else if (collarId == 8) {
        // Draw outer top and left only (no right, no bottom)
        canvas.drawLine(outerRect.topLeft, outerRect.topRight, basePaint);
        canvas.drawLine(outerRect.topLeft, outerRect.bottomLeft, basePaint);
      } else if (collarId == 9) {
        // Draw outer left and right only (no top, no bottom)
        canvas.drawLine(outerRect.topLeft, outerRect.bottomLeft, basePaint);
        canvas.drawLine(outerRect.topRight, outerRect.bottomRight, basePaint);
      } else if (collarId == 10) {
        // Draw outer top and bottom only (no left, no right)
        canvas.drawLine(outerRect.topLeft, outerRect.topRight, basePaint);
        canvas.drawLine(outerRect.bottomLeft, outerRect.bottomRight, basePaint);
      } else if (collarId == 11) {
        // Draw outer top only (no left, no right, no bottom)
        canvas.drawLine(outerRect.topLeft, outerRect.topRight, basePaint);
      } else if (collarId == 12) {
        // Draw outer right only (no top, no left, no bottom)
        canvas.drawLine(outerRect.topRight, outerRect.bottomRight, basePaint);
      } else if (collarId == 13) {
        // Draw outer bottom only (no top, no right, no left)
        canvas.drawLine(outerRect.bottomLeft, outerRect.bottomRight, basePaint);
      } else if (collarId == 14) {
        // Draw outer left only (no top, no right, no bottom)
        canvas.drawLine(outerRect.topLeft, outerRect.bottomLeft, basePaint);
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
      if (collarId != 7 && collarId != 12 && collarId != 13) {
        canvas.drawLine(outerRect.topLeft, innerRect.topLeft, basePaint);
      }
      if (collarId == 14) {
        canvas.drawLine(outerRect.topLeft, innerRect.topLeft, basePaint);
      }
      if (collarId != 13 && collarId != 14) {
        canvas.drawLine(outerRect.topRight, innerRect.topRight, basePaint);
      }
      // Restore bottom-left link for collar 7, 13, 14
      if (collarId == 13 || collarId == 14) {
        canvas.drawLine(outerRect.bottomLeft, innerRect.bottomLeft, basePaint);
      } else if (collarId != 11 && collarId != 12) {
        canvas.drawLine(outerRect.bottomLeft, innerRect.bottomLeft, basePaint);
      }
      if (collarId != 8 && collarId != 11 && collarId != 14) {
        canvas.drawLine(
          outerRect.bottomRight,
          innerRect.bottomRight,
          basePaint,
        );
      }
    }

    // Labels (light tone like lines)
    const double fontSize = 12;
    final double labelGap = size.height * 0.012;
    final double sideGap = labelGap + size.width * 0.01;
    final bool highlightDc30F = effectiveSection == 'DC30F';
    final bool highlightDc30C = effectiveSection == 'DC30C';
    final bool highlightDc26 = effectiveSection == 'DC26C' || effectiveSection == 'DC26F';
    final bool highlightM23 = effectiveSection == 'M23';
    final bool highlightM24 = effectiveSection == 'M24';
    final bool highlightM28 = effectiveSection == 'M28';
    final bool highlightD29 = effectiveSection == 'D29';
    final bool onlyHighlights = effectiveSection != null;
    final Set<String> highlightLabels = {
      if (highlightDc30F &&
          collarId != 6 &&
          collarId != 7 &&
          collarId != 10 &&
          collarId != 11 &&
          collarId != 12) ...{
        'HL',
      },
      if (highlightDc30F &&
          (collarId == 6 || collarId == 7 || collarId == 12)) ...{
        'HR',
      },
      if (highlightDc30F && collarId == 1) ...{'HR'},
      if (highlightDc30F && collarId == 3) ...{'HR'},
      if (highlightDc30F && collarId == 5) ...{'HR'},
      if (highlightDc30F && collarId == 9) ...{'HR'},
      if (highlightDc30F && collarId == 8) ...{'WT', 'HL'},
      if (highlightDc30F && collarId == 10) ...{'WT'},
      if (highlightDc30F && collarId == 11) ...{'WT'},
      if (highlightDc30F && collarId == 1) ...{'WT'},
      if (highlightDc30F && collarId == 5) ...{'WT'},
      if (highlightDc30F && collarId == 6) ...{'WT'},
      if (highlightDc30F &&
          collarId != 1 &&
          collarId != 3 &&
          collarId != 5 &&
          collarId != 6 &&
          collarId != 7 &&
          collarId != 9 &&
          collarId != 10 &&
          collarId != 11 &&
          collarId != 12 &&
          collarId != 14) ...{
        'WT',
      },
      if (highlightDc30C && collarId == 2) ...{'HR'},
      if (highlightDc30C && collarId == 7) ...{'WT', 'HL'},
      if (highlightDc30C && collarId == 8) ...{'HR'},
      if (highlightDc30C && collarId == 9) ...{'WT'},
      if (highlightDc30C && collarId == 12) ...{'WT', 'HL'},
      if (highlightDc30C &&
          collarId != 4 &&
          collarId != 6 &&
          collarId != 7 &&
          collarId != 8 &&
          collarId != 9 &&
          collarId != 11 &&
          collarId != 12) ...{
        'WT',
      },
      if (highlightDc30C && collarId == 4) ...{'HR'},
      if (highlightDc30C && collarId == 6) ...{'HL'},
      if (highlightDc30C && collarId == 11) ...{'HL', 'HR'},
      if (highlightDc30C && collarId == 10) ...{'HL', 'HR'},
      if (highlightDc30C && collarId == 13) ...{'HL', 'HR'},
      if (highlightDc30C && collarId == 14) ...{'WT', 'HR'},
      if (highlightDc26 &&
          collarId != 8 &&
          collarId != 9 &&
          collarId != 11 &&
          collarId != 12 &&
          collarId != 13) ...{
        'WB',
      },
      if (highlightDc26 && (collarId == 8 || collarId == 9)) ...{'WB'},
      if (highlightDc26 && collarId == 11) ...{'WB'},
      if (highlightDc26 && collarId == 12) ...{'WB'},
      if (highlightDc26 && collarId == 13) ...{'WB'},
      if (highlightM24) ...{'W'},
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
    if (!onlyHighlights || highlightLabels.contains('WT')) {
      final TextPainter tpTop = tpBuilder('WT');
      double topY = labelRect.top - labelGap - tpTop.height;
      if (topY < 0) topY = 0;
      tpTop.paint(canvas, Offset(labelRect.center.dx - tpTop.width / 2, topY));
    }

    // DC30F highlight set for collar 1:
    // top + left + right rails with WT/HL/HR labels
    if (highlightDc30F && collarId == 1) {
      if (!hideOuter) {
        canvas.drawLine(outerRect.topLeft, outerRect.topRight, highlightPaint);
        canvas.drawLine(outerRect.topLeft, outerRect.bottomLeft, highlightPaint);
        canvas.drawLine(
          outerRect.topRight,
          outerRect.bottomRight,
          highlightPaint,
        );
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
      canvas.drawLine(
        Offset(innerRect.right, innerRect.top),
        Offset(innerRect.right, innerRect.bottom),
        highlightPaint,
      );
      if (!hideOuter) {
        canvas.drawLine(outerRect.topLeft, innerRect.topLeft, highlightPaint);
        canvas.drawLine(outerRect.topRight, innerRect.topRight, highlightPaint);
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

    // DC30F highlight set for collar 3:
    // left/right rails + corner links with HL/HR labels
    if (highlightDc30F && collarId == 3) {
      if (!hideOuter) {
        canvas.drawLine(outerRect.topLeft, outerRect.bottomLeft, highlightPaint);
        canvas.drawLine(
          outerRect.topRight,
          outerRect.bottomRight,
          highlightPaint,
        );
        canvas.drawLine(outerRect.topLeft, innerRect.topLeft, highlightPaint);
        canvas.drawLine(outerRect.topRight, innerRect.topRight, highlightPaint);
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

    // DC30F highlight set for collar 4:
    // top/left rails + related corner links with HL/WT labels
    if (highlightDc30F && collarId == 4) {
      if (!hideOuter) {
        canvas.drawLine(outerRect.topLeft, outerRect.topRight, highlightPaint);
        canvas.drawLine(outerRect.topLeft, outerRect.bottomLeft, highlightPaint);
        canvas.drawLine(outerRect.topLeft, innerRect.topLeft, highlightPaint);
        canvas.drawLine(outerRect.topRight, innerRect.topRight, highlightPaint);
        canvas.drawLine(
          outerRect.bottomLeft,
          innerRect.bottomLeft,
          highlightPaint,
        );
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
    }

    // DC30F highlight set for collar 5:
    // top/left/right rails + corner links with HL/HR/WT labels
    if (highlightDc30F && collarId == 5) {
      if (!hideOuter) {
        canvas.drawLine(outerRect.topLeft, outerRect.topRight, highlightPaint);
        canvas.drawLine(outerRect.topLeft, outerRect.bottomLeft, highlightPaint);
        canvas.drawLine(
          outerRect.topRight,
          outerRect.bottomRight,
          highlightPaint,
        );
        canvas.drawLine(outerRect.topLeft, innerRect.topLeft, highlightPaint);
        canvas.drawLine(outerRect.topRight, innerRect.topRight, highlightPaint);
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
      canvas.drawLine(
        Offset(innerRect.right, innerRect.top),
        Offset(innerRect.right, innerRect.bottom),
        highlightPaint,
      );
    }

    // DC30F highlight set for collar 6:
    // top + right rails with WT/HR labels
    if (highlightDc30F && collarId == 6) {
      if (!hideOuter) {
        canvas.drawLine(outerRect.topLeft, outerRect.topRight, highlightPaint);
        canvas.drawLine(
          outerRect.topRight,
          outerRect.bottomRight,
          highlightPaint,
        );
        // Required corner links: top-left, top-right, bottom-right
        canvas.drawLine(outerRect.topLeft, innerRect.topLeft, highlightPaint);
        canvas.drawLine(outerRect.topRight, innerRect.topRight, highlightPaint);
        canvas.drawLine(
          outerRect.bottomRight,
          innerRect.bottomRight,
          highlightPaint,
        );
      }
      canvas.drawLine(
        Offset(innerRect.left, innerRect.top),
        Offset(innerRect.right, innerRect.top),
        highlightPaint,
      );
      canvas.drawLine(
        Offset(innerRect.right, innerRect.top),
        Offset(innerRect.right, innerRect.bottom),
        highlightPaint,
      );
    }

    // DC30F highlight set for collar 7:
    // right rails + right corner links with HR
    if (highlightDc30F && collarId == 7) {
      if (!hideOuter) {
        canvas.drawLine(
          outerRect.topRight,
          outerRect.bottomRight,
          highlightPaint,
        );
        canvas.drawLine(outerRect.topRight, innerRect.topRight, highlightPaint);
        canvas.drawLine(
          outerRect.bottomRight,
          innerRect.bottomRight,
          highlightPaint,
        );
      }
      canvas.drawLine(
        Offset(innerRect.right, innerRect.top),
        Offset(innerRect.right, innerRect.bottom),
        highlightPaint,
      );
    }

    // DC30F highlight set for collar 8:
    // top + left rails with related corner links and WT/HL
    if (highlightDc30F && collarId == 8) {
      if (!hideOuter) {
        canvas.drawLine(outerRect.topLeft, outerRect.topRight, highlightPaint);
        canvas.drawLine(outerRect.topLeft, outerRect.bottomLeft, highlightPaint);
        canvas.drawLine(outerRect.topLeft, innerRect.topLeft, highlightPaint);
        canvas.drawLine(outerRect.topRight, innerRect.topRight, highlightPaint);
        canvas.drawLine(
          outerRect.bottomLeft,
          innerRect.bottomLeft,
          highlightPaint,
        );
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
    }

    // DC30F highlight set for collar 9:
    // left/right rails + all corner links with HL/HR
    if (highlightDc30F && collarId == 9) {
      if (!hideOuter) {
        canvas.drawLine(outerRect.topLeft, outerRect.bottomLeft, highlightPaint);
        canvas.drawLine(
          outerRect.topRight,
          outerRect.bottomRight,
          highlightPaint,
        );
        canvas.drawLine(outerRect.topLeft, innerRect.topLeft, highlightPaint);
        canvas.drawLine(outerRect.topRight, innerRect.topRight, highlightPaint);
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

    // DC30F highlight set for collar 10:
    // top rails + top corner links with WT
    if (highlightDc30F && collarId == 10) {
      if (!hideOuter) {
        canvas.drawLine(outerRect.topLeft, outerRect.topRight, highlightPaint);
        canvas.drawLine(outerRect.topLeft, innerRect.topLeft, highlightPaint);
        canvas.drawLine(outerRect.topRight, innerRect.topRight, highlightPaint);
      }
      canvas.drawLine(
        Offset(innerRect.left, innerRect.top),
        Offset(innerRect.right, innerRect.top),
        highlightPaint,
      );
    }

    // DC30F highlight set for collar 11:
    // top rails + top corner links with WT
    if (highlightDc30F && collarId == 11) {
      if (!hideOuter) {
        canvas.drawLine(outerRect.topLeft, outerRect.topRight, highlightPaint);
        canvas.drawLine(outerRect.topLeft, innerRect.topLeft, highlightPaint);
        canvas.drawLine(outerRect.topRight, innerRect.topRight, highlightPaint);
      }
      canvas.drawLine(
        Offset(innerRect.left, innerRect.top),
        Offset(innerRect.right, innerRect.top),
        highlightPaint,
      );
    }

    // DC30F highlight set for collar 12:
    // right rails + right corner links with HR
    if (highlightDc30F && collarId == 12) {
      if (!hideOuter) {
        canvas.drawLine(
          outerRect.topRight,
          outerRect.bottomRight,
          highlightPaint,
        );
        canvas.drawLine(outerRect.topRight, innerRect.topRight, highlightPaint);
        canvas.drawLine(
          outerRect.bottomRight,
          innerRect.bottomRight,
          highlightPaint,
        );
      }
      canvas.drawLine(
        Offset(innerRect.right, innerRect.top),
        Offset(innerRect.right, innerRect.bottom),
        highlightPaint,
      );
    }

    // DC30F highlight set for collar 14:
    // left rails + left corner links with HL
    if (highlightDc30F && collarId == 14) {
      if (!hideOuter) {
        canvas.drawLine(outerRect.topLeft, outerRect.bottomLeft, highlightPaint);
        canvas.drawLine(outerRect.topLeft, innerRect.topLeft, highlightPaint);
        canvas.drawLine(
          outerRect.bottomLeft,
          innerRect.bottomLeft,
          highlightPaint,
        );
      }
      canvas.drawLine(
        Offset(innerRect.left, innerRect.top),
        Offset(innerRect.left, innerRect.bottom),
        highlightPaint,
      );
    }

    // DC26F/DC26C highlight set for collar 1:
    // bottom rails + bottom corner links with WB label
    if (highlightDc26 && collarId == 1) {
      if (!hideOuter) {
        canvas.drawLine(
          outerRect.bottomLeft,
          outerRect.bottomRight,
          highlightPaint,
        );
      }
      canvas.drawLine(
        Offset(innerRect.left, innerRect.bottom),
        Offset(innerRect.right, innerRect.bottom),
        highlightPaint,
      );
      if (!hideOuter) {
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

    // DC26F highlight set for collar 3:
    // bottom rails + bottom corner links with WB label
    if (highlightDc26 && collarId == 3) {
      if (!hideOuter) {
        canvas.drawLine(
          outerRect.bottomLeft,
          outerRect.bottomRight,
          highlightPaint,
        );
      }
      canvas.drawLine(
        Offset(innerRect.left, innerRect.bottom),
        Offset(innerRect.right, innerRect.bottom),
        highlightPaint,
      );
      if (!hideOuter) {
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

    // DC26F/DC26C highlight set for collar 4:
    // bottom rails + bottom corner links with WB label
    if (highlightDc26 && collarId == 4) {
      if (!hideOuter) {
        canvas.drawLine(
          outerRect.bottomLeft,
          outerRect.bottomRight,
          highlightPaint,
        );
      }
      canvas.drawLine(
        Offset(innerRect.left, innerRect.bottom),
        Offset(innerRect.right, innerRect.bottom),
        highlightPaint,
      );
      if (!hideOuter) {
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

    // DC26C highlight set for collar 5:
    // only bottom inner line + WB label
    if (highlightDc26 && collarId == 5) {
      canvas.drawLine(
        Offset(innerRect.left, innerRect.bottom),
        Offset(innerRect.right, innerRect.bottom),
        highlightPaint,
      );
    }

    // DC26F highlight set for collar 6:
    // bottom rails + WB label
    if (highlightDc26 && collarId == 6) {
      if (!hideOuter) {
        canvas.drawLine(
          outerRect.bottomLeft,
          outerRect.bottomRight,
          highlightPaint,
        );
        // Required corner links: bottom-left and bottom-right
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
      canvas.drawLine(
        Offset(innerRect.left, innerRect.bottom),
        Offset(innerRect.right, innerRect.bottom),
        highlightPaint,
      );
    }

    // DC26F highlight set for collar 7:
    // bottom rails + bottom corner links with WB
    if (highlightDc26 && collarId == 7) {
      if (!hideOuter) {
        canvas.drawLine(
          outerRect.bottomLeft,
          outerRect.bottomRight,
          highlightPaint,
        );
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
      canvas.drawLine(
        Offset(innerRect.left, innerRect.bottom),
        Offset(innerRect.right, innerRect.bottom),
        highlightPaint,
      );
    }

    // DC26C highlight set for collar 8:
    // bottom inner line + WB
    if (highlightDc26 && collarId == 8) {
      canvas.drawLine(
        Offset(innerRect.left, innerRect.bottom),
        Offset(innerRect.right, innerRect.bottom),
        highlightPaint,
      );
    }

    // DC26C highlight set for collar 9:
    // bottom inner line + WB
    if (highlightDc26 && collarId == 9) {
      canvas.drawLine(
        Offset(innerRect.left, innerRect.bottom),
        Offset(innerRect.right, innerRect.bottom),
        highlightPaint,
      );
    }

    // DC26C highlight set for collar 11:
    // bottom inner line + WB
    if (highlightDc26 && collarId == 11) {
      canvas.drawLine(
        Offset(innerRect.left, innerRect.bottom),
        Offset(innerRect.right, innerRect.bottom),
        highlightPaint,
      );
    }

    // DC26C highlight set for collar 12:
    // bottom inner line + WB
    if (highlightDc26 && collarId == 12) {
      canvas.drawLine(
        Offset(innerRect.left, innerRect.bottom),
        Offset(innerRect.right, innerRect.bottom),
        highlightPaint,
      );
    }

    // DC26F highlight set for collar 13:
    // bottom rails + bottom corner links with WB
    if (highlightDc26 && collarId == 13) {
      if (!hideOuter) {
        canvas.drawLine(
          outerRect.bottomLeft,
          outerRect.bottomRight,
          highlightPaint,
        );
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
      canvas.drawLine(
        Offset(innerRect.left, innerRect.bottom),
        Offset(innerRect.right, innerRect.bottom),
        highlightPaint,
      );
    }

    // DC26C highlight set for collar 14:
    // bottom inner line + WB
    if (highlightDc26 && collarId == 14) {
      canvas.drawLine(
        Offset(innerRect.left, innerRect.bottom),
        Offset(innerRect.right, innerRect.bottom),
        highlightPaint,
      );
    }

    // DC26F highlight set for collar 10:
    // bottom rails + bottom corner links with WB
    if (highlightDc26 && collarId == 10) {
      if (!hideOuter) {
        canvas.drawLine(
          outerRect.bottomLeft,
          outerRect.bottomRight,
          highlightPaint,
        );
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
      canvas.drawLine(
        Offset(innerRect.left, innerRect.bottom),
        Offset(innerRect.right, innerRect.bottom),
        highlightPaint,
      );
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

    // DC30C highlight set for collar 3:
    // top inner line + WT
    if (highlightDc30C && collarId == 3) {
      canvas.drawLine(
        Offset(innerRect.left, innerRect.top),
        Offset(innerRect.right, innerRect.top),
        highlightPaint,
      );
    }

    // DC30C highlight set for collar 4:
    // right inner line + HR
    if (highlightDc30C && collarId == 4) {
      canvas.drawLine(
        Offset(innerRect.right, innerRect.top),
        Offset(innerRect.right, innerRect.bottom),
        highlightPaint,
      );
    }

    // DC30C highlight set for collar 6:
    // left inner line + HL
    if (highlightDc30C && collarId == 6) {
      canvas.drawLine(
        Offset(innerRect.left, innerRect.top),
        Offset(innerRect.left, innerRect.bottom),
        highlightPaint,
      );
    }

    // DC30C highlight set for collar 7:
    // top inner + left inner with WT/HL
    if (highlightDc30C && collarId == 7) {
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
    }

    // DC30C highlight set for collar 8:
    // right inner line + HR
    if (highlightDc30C && collarId == 8) {
      canvas.drawLine(
        Offset(innerRect.right, innerRect.top),
        Offset(innerRect.right, innerRect.bottom),
        highlightPaint,
      );
    }

    // DC30C highlight set for collar 9:
    // top inner line + WT
    if (highlightDc30C && collarId == 9) {
      canvas.drawLine(
        Offset(innerRect.left, innerRect.top),
        Offset(innerRect.right, innerRect.top),
        highlightPaint,
      );
    }

    // DC30C highlight set for collar 10:
    // left + right inner lines with HL/HR
    if (highlightDc30C && collarId == 10) {
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

    // DC30C highlight set for collar 11:
    // left + right inner lines with HL/HR
    if (highlightDc30C && collarId == 11) {
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

    // DC30C highlight set for collar 12:
    // top inner + left inner with WT/HL
    if (highlightDc30C && collarId == 12) {
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
    }

    // DC30C highlight set for collar 13:
    // top + left + right inner with WT/HL/HR
    if (highlightDc30C && collarId == 13) {
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
      canvas.drawLine(
        Offset(innerRect.right, innerRect.top),
        Offset(innerRect.right, innerRect.bottom),
        highlightPaint,
      );
    }

    // DC30C highlight set for collar 14:
    // top + right inner with WT/HR
    if (highlightDc30C && collarId == 14) {
      canvas.drawLine(
        Offset(innerRect.left, innerRect.top),
        Offset(innerRect.right, innerRect.top),
        highlightPaint,
      );
      canvas.drawLine(
        Offset(innerRect.right, innerRect.top),
        Offset(innerRect.right, innerRect.bottom),
        highlightPaint,
      );
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
    if (!onlyHighlights || highlightLabels.contains('WB')) {
      final TextPainter tpBottom = tpBuilder('WB');
      double bottomY = labelRect.bottom + labelGap;
      if (bottomY + tpBottom.height > size.height) {
        bottomY = size.height - tpBottom.height;
      }
      tpBottom.paint(
        canvas,
        Offset(labelRect.center.dx - tpBottom.width / 2, bottomY),
      );
    }

    // HL left side
    if (!onlyHighlights || highlightLabels.contains('HL')) {
      final TextPainter tpLeft = tpBuilder('HL');
      double leftX = labelRect.left - (sideGap * 1.05) - tpLeft.width;
      if (leftX < 0) leftX = 0;
      tpLeft.paint(
        canvas,
        Offset(leftX, labelRect.center.dy - tpLeft.height / 2),
      );
    }

    // HR right side
    if (!onlyHighlights || highlightLabels.contains('HR')) {
      final TextPainter tpRight = tpBuilder('HR');
      double rightX = labelRect.right + (sideGap * 1.05);
      if (rightX + tpRight.width > size.width) {
        rightX = size.width - tpRight.width;
      }
      tpRight.paint(
        canvas,
        Offset(rightX, labelRect.center.dy - tpRight.height / 2),
      );
    }

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
      if (!onlyHighlights || highlightW) {
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
      }
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
      final bool highlightHOuter =
          tpHOuter.text!.style?.color == highlightPaint.color;
      final bool highlightHInner =
          tpHInner.text!.style?.color == highlightPaint.color;
      final double hInnerX = isLeftPanel
          ? panel.right - tpHInner.width - innerGap
          : panel.left + innerGap;
      final double hOuterX = isLeftPanel
          ? panel.left + innerGap
          : panel.right - tpHOuter.width - innerGap;
      final double hY = panel.center.dy - tpHOuter.height / 2;
      // Inner H highlights on M23/M28 or D29 (left side)
      if (!onlyHighlights || highlightHOuter) {
        tpHOuter.paint(canvas, Offset(hOuterX, hY));
      }
      if (!onlyHighlights || highlightHInner) {
        tpHInner.paint(canvas, Offset(hInnerX, hY));
      }
      // Bottom W
      if (!onlyHighlights || highlightW) {
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
    }

    paintPanelLabels(leftPanel, isLeftPanel: true);
    paintPanelLabels(rightPanel, isLeftPanel: false);

    // Old band-rectangle highlights removed; per-section highlights will be
    // drawn explicitly in dedicated branches.

    // M23 highlights only inner left/right vertical lines + inner H symbols.
    if (highlightM23) {
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
    // Collar-specific zone definitions
    const dc30F = _ZoneSpec(
      'DC30F',
      Rect.fromLTWH(0.08, 0.08, 0.84, 0.10),
    ); // top rail
    const dc30C = _ZoneSpec(
      'DC30C',
      Rect.fromLTWH(0.08, 0.08, 0.84, 0.10),
    ); // top rail variant
    const dc26C = _ZoneSpec(
      'DC26C',
      Rect.fromLTWH(0.08, 0.82, 0.84, 0.10),
    ); // bottom rail
    const d29 = _ZoneSpec(
      'D29',
      Rect.fromLTWH(0.08, 0.18, 0.10, 0.64),
    ); // left stile
    const m23 = _ZoneSpec(
      'M23',
      Rect.fromLTWH(0.82, 0.18, 0.10, 0.64),
    ); // right stile
    const m24 = _ZoneSpec(
      'M24',
      Rect.fromLTWH(0.20, 0.22, 0.60, 0.06),
    ); // upper mullion band
    const m28 = _ZoneSpec(
      'M28',
      Rect.fromLTWH(0.42, 0.22, 0.16, 0.56),
    ); // center divider band

    // Universal sections (always show)
    const universalSections = [d29, m23, m24, m28];

    // Collar-specific sections
    switch (collarId) {
      case 11:
        // Collar 11: top line only - show DC30F and DC26C (not DC30C)
        return [dc30F, dc26C, ...universalSections];
      case 12:
        // Collar 12: right line only - show DC30F and DC26C (not DC30C)
        return [dc30F, dc26C, ...universalSections];
      case 13:
        // Collar 13: bottom line only - show only DC26C (not DC30F, not DC30C)
        return [dc26C, ...universalSections];
      case 14:
        // Collar 14: left line only - show DC30C and DC26C (not DC30F)
        return [dc30C, dc26C, ...universalSections];
      default:
        // Collar 7, 8, 9, 10 and others: show all 7
        return [dc30F, dc30C, dc26C, ...universalSections];
    }
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
