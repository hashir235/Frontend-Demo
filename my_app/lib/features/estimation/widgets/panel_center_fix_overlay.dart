import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class _LineSpec {
  final String id;
  final Offset from;
  final Offset to;

  const _LineSpec({
    required this.id,
    required this.from,
    required this.to,
  });
}

class _PanelCenterFixPainter extends CustomPainter {
  static const Map<int, Set<String>> _dc30FByCollar = <int, Set<String>>{
    1: <String>{
      'outer_top',
      'outer_left',
      'outer_right',
      'inner_top',
      'inner_left',
      'inner_right',
      'corner_tl',
      'corner_tr',
      'corner_bl',
      'corner_br',
    },
    3: <String>{
      'outer_left',
      'outer_right',
      'inner_left',
      'inner_right',
      'corner_tl',
      'corner_tr',
      'corner_bl',
      'corner_br',
    },
    4: <String>{
      'outer_top',
      'outer_left',
      'inner_top',
      'inner_left',
      'corner_tl',
      'corner_tr',
      'corner_bl',
    },
    5: <String>{
      'outer_top',
      'outer_left',
      'outer_right',
      'inner_top',
      'inner_left',
      'inner_right',
      'corner_tl',
      'corner_tr',
      'corner_bl',
      'corner_br',
    },
    6: <String>{
      'outer_top',
      'outer_right',
      'inner_top',
      'inner_right',
      'corner_tl',
      'corner_tr',
      'corner_br',
    },
    7: <String>{
      'outer_right',
      'inner_right',
      'corner_tr',
      'corner_br',
    },
    8: <String>{
      'outer_top',
      'outer_left',
      'inner_top',
      'inner_left',
      'corner_tl',
      'corner_tr',
      'corner_bl',
    },
    9: <String>{
      'outer_left',
      'outer_right',
      'inner_left',
      'inner_right',
      'corner_tl',
      'corner_tr',
      'corner_bl',
      'corner_br',
    },
    10: <String>{
      'outer_top',
      'inner_top',
      'corner_tl',
      'corner_tr',
    },
    11: <String>{
      'outer_top',
      'inner_top',
      'corner_tl',
      'corner_tr',
    },
    12: <String>{
      'outer_right',
      'inner_right',
      'corner_tr',
      'corner_br',
    },
    14: <String>{
      'outer_left',
      'inner_left',
      'corner_tl',
      'corner_bl',
    },
  };

  static const Map<int, Set<String>> _dc30CByCollar = <int, Set<String>>{
    2: <String>{'inner_top', 'inner_left', 'inner_right'},
    3: <String>{'inner_top'},
    4: <String>{'inner_right'},
    6: <String>{'inner_left'},
    7: <String>{'inner_top', 'inner_left'},
    8: <String>{'inner_right'},
    9: <String>{'inner_top'},
    10: <String>{'inner_left', 'inner_right'},
    11: <String>{'inner_left', 'inner_right'},
    12: <String>{'inner_top', 'inner_left'},
    13: <String>{'inner_top', 'inner_left', 'inner_right'},
    14: <String>{'inner_top', 'inner_right'},
  };

  static const Map<int, Set<String>> _dc26ByCollar = <int, Set<String>>{
    1: <String>{'outer_bottom', 'inner_bottom', 'corner_bl', 'corner_br'},
    2: <String>{'inner_bottom'},
    3: <String>{'outer_bottom', 'inner_bottom', 'corner_bl', 'corner_br'},
    4: <String>{'outer_bottom', 'inner_bottom', 'corner_bl', 'corner_br'},
    5: <String>{'inner_bottom'},
    6: <String>{'outer_bottom', 'inner_bottom', 'corner_bl', 'corner_br'},
    7: <String>{'outer_bottom', 'inner_bottom', 'corner_bl', 'corner_br'},
    8: <String>{'inner_bottom'},
    9: <String>{'inner_bottom'},
    10: <String>{'outer_bottom', 'inner_bottom', 'corner_bl', 'corner_br'},
    11: <String>{'inner_bottom'},
    12: <String>{'inner_bottom'},
    13: <String>{'outer_bottom', 'inner_bottom', 'corner_bl', 'corner_br'},
    14: <String>{'inner_bottom'},
  };

  final String? selectedSection;
  final Map<String, String> sectionAliases;
  final int? collarId;
  final double leftDividerFraction;
  final double rightDividerFraction;
  final bool d29MirrorRightPanel;
  final bool m23HighlightAllVerticals;

  const _PanelCenterFixPainter({
    required this.selectedSection,
    required this.sectionAliases,
    required this.collarId,
    required this.leftDividerFraction,
    required this.rightDividerFraction,
    required this.d29MirrorRightPanel,
    required this.m23HighlightAllVerticals,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final int c = collarId ?? 1;

    String? effectiveSection = selectedSection;
    final bool bypassAlias =
        c == 2 && (selectedSection == 'DC30C' || selectedSection == 'DC26C');
    if (selectedSection != null && !bypassAlias) {
      final String base = sectionAliases.entries
          .firstWhere(
            (MapEntry<String, String> e) => e.value == selectedSection,
            orElse: () => const MapEntry<String, String>('', ''),
          )
          .key;
      if (base.isNotEmpty) {
        effectiveSection = base;
      }
    }
    final bool hideOuter = c == 2;

    final double outerPadding = size.width * 0.08;
    final Rect outerRect = Rect.fromLTWH(
      outerPadding,
      outerPadding,
      size.width - (outerPadding * 2),
      size.height - (outerPadding * 2),
    );

    final double gap = size.width * 0.06;
    final Rect innerRect = outerRect.deflate(gap);
    final Rect labelRect = hideOuter ? innerRect : outerRect;

    final double x25 = innerRect.left + (innerRect.width * leftDividerFraction);
    final double x75 = innerRect.left + (innerRect.width * rightDividerFraction);

    final Paint basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = AppTheme.deepTeal.withValues(alpha: 0.28);

    final Paint highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = AppTheme.violet;

    final List<_LineSpec> lines = <_LineSpec>[
      _LineSpec(id: 'outer_top', from: outerRect.topLeft, to: outerRect.topRight),
      _LineSpec(
        id: 'outer_bottom',
        from: outerRect.bottomLeft,
        to: outerRect.bottomRight,
      ),
      _LineSpec(id: 'outer_left', from: outerRect.topLeft, to: outerRect.bottomLeft),
      _LineSpec(
        id: 'outer_right',
        from: outerRect.topRight,
        to: outerRect.bottomRight,
      ),
      _LineSpec(id: 'inner_top', from: innerRect.topLeft, to: innerRect.topRight),
      _LineSpec(
        id: 'inner_bottom',
        from: innerRect.bottomLeft,
        to: innerRect.bottomRight,
      ),
      _LineSpec(id: 'inner_left', from: innerRect.topLeft, to: innerRect.bottomLeft),
      _LineSpec(id: 'inner_right', from: innerRect.topRight, to: innerRect.bottomRight),
      _LineSpec(
        id: 'divider_25',
        from: Offset(x25, innerRect.top),
        to: Offset(x25, innerRect.bottom),
      ),
      _LineSpec(
        id: 'divider_75',
        from: Offset(x75, innerRect.top),
        to: Offset(x75, innerRect.bottom),
      ),
      _LineSpec(id: 'corner_tl', from: outerRect.topLeft, to: innerRect.topLeft),
      _LineSpec(id: 'corner_tr', from: outerRect.topRight, to: innerRect.topRight),
      _LineSpec(id: 'corner_bl', from: outerRect.bottomLeft, to: innerRect.bottomLeft),
      _LineSpec(
        id: 'corner_br',
        from: outerRect.bottomRight,
        to: innerRect.bottomRight,
      ),
    ];

    bool isBaseVisible(String id) {
      if (id.startsWith('inner_') || id.startsWith('divider_')) {
        return true;
      }
      if (hideOuter) return false;

      switch (id) {
        case 'outer_top':
          return c != 3 &&
              c != 7 &&
              c != 9 &&
              c != 12 &&
              c != 13 &&
              c != 14;
        case 'outer_bottom':
          return c != 5 &&
              c != 8 &&
              c != 9 &&
              c != 10 &&
              c != 11 &&
              c != 12 &&
              c != 14;
        case 'outer_left':
          return c != 6 &&
              c != 7 &&
              c != 10 &&
              c != 11 &&
              c != 12 &&
              c != 13;
        case 'outer_right':
          return c != 4 &&
              c != 8 &&
              c != 10 &&
              c != 11 &&
              c != 13 &&
              c != 14;
        case 'corner_tl':
          return (c != 7 && c != 12 && c != 13) || c == 14;
        case 'corner_tr':
          return c != 13 && c != 14;
        case 'corner_bl':
          return c != 11 && c != 12;
        case 'corner_br':
          return c != 8 && c != 11 && c != 14;
        default:
          return false;
      }
    }

    final Map<String, _LineSpec> lineById = <String, _LineSpec>{
      for (final _LineSpec line in lines) line.id: line,
    };

    for (final _LineSpec line in lines) {
      if (isBaseVisible(line.id)) {
        canvas.drawLine(line.from, line.to, basePaint);
      }
    }

    final bool highlightDc30F = effectiveSection == 'DC30F';
    final bool highlightDc30C = effectiveSection == 'DC30C';
    final bool highlightDc26 = effectiveSection == 'DC26F' || effectiveSection == 'DC26C';
    final bool highlightD29 = effectiveSection == 'D29';
    final bool highlightM23 = effectiveSection == 'M23';
    final bool highlightM24 = effectiveSection == 'M24';
    final bool highlightM28 = effectiveSection == 'M28';
    final bool onlyHighlights = effectiveSection != null;

    final Set<String> highlightLineIds = <String>{
      if (highlightDc30F) ...(_dc30FByCollar[c] ?? const <String>{}),
      if (highlightDc30C) ...(_dc30CByCollar[c] ?? const <String>{}),
      if (highlightDc26) ...(_dc26ByCollar[c] ?? const <String>{}),
      if (highlightM23)
        ...<String>{
          'inner_left',
          'inner_right',
          if (m23HighlightAllVerticals) 'divider_25',
          if (m23HighlightAllVerticals) 'divider_75',
        },
      if (highlightM24) ...<String>{'inner_top', 'inner_bottom'},
      if (highlightM28) ...<String>{'divider_25', 'divider_75'},
      if (highlightD29) ...<String>{
        'inner_left',
        'divider_25',
        if (d29MirrorRightPanel) 'divider_75',
        if (d29MirrorRightPanel) 'inner_right',
      },
    };

    for (final String id in highlightLineIds) {
      final _LineSpec? line = lineById[id];
      if (line != null) {
        canvas.drawLine(line.from, line.to, highlightPaint);
      }
    }

    if (highlightD29) {
      canvas.drawLine(
        innerRect.topLeft,
        Offset(x25, innerRect.top),
        highlightPaint,
      );
      canvas.drawLine(
        innerRect.bottomLeft,
        Offset(x25, innerRect.bottom),
        highlightPaint,
      );
      if (d29MirrorRightPanel) {
        canvas.drawLine(
          Offset(x75, innerRect.top),
          innerRect.topRight,
          highlightPaint,
        );
        canvas.drawLine(
          Offset(x75, innerRect.bottom),
          innerRect.bottomRight,
          highlightPaint,
        );
      }
    }

    const double fontSize = 12;
    final double labelGap = size.height * 0.012;
    final double sideGap = labelGap + size.width * 0.01;
    final double innerGap = size.height * 0.01;

    final Set<String> highlightLabelIds = <String>{
      if (highlightDc30F &&
          c != 6 &&
          c != 7 &&
          c != 10 &&
          c != 11 &&
          c != 12) ...<String>{'HL'},
      if (highlightDc30F && (c == 6 || c == 7 || c == 12)) ...<String>{'HR'},
      if (highlightDc30F && (c == 1 || c == 3 || c == 5 || c == 9)) ...<String>{'HR'},
      if (highlightDc30F && c == 8) ...<String>{'WT', 'HL'},
      if (highlightDc30F && (c == 10 || c == 11 || c == 1 || c == 5 || c == 6))
        ...<String>{'WT'},
      if (highlightDc30F &&
          c != 1 &&
          c != 3 &&
          c != 5 &&
          c != 6 &&
          c != 7 &&
          c != 9 &&
          c != 10 &&
          c != 11 &&
          c != 12 &&
          c != 14) ...<String>{'WT'},
      if (highlightDc30C && c == 2) ...<String>{'HL', 'HR'},
      if (highlightDc30C && c == 7) ...<String>{'WT', 'HL'},
      if (highlightDc30C && c == 8) ...<String>{'HR'},
      if (highlightDc30C && c == 9) ...<String>{'WT'},
      if (highlightDc30C && c == 12) ...<String>{'WT', 'HL'},
      if (highlightDc30C &&
          c != 4 &&
          c != 6 &&
          c != 7 &&
          c != 8 &&
          c != 9 &&
          c != 11 &&
          c != 12) ...<String>{'WT'},
      if (highlightDc30C && c == 4) ...<String>{'HR'},
      if (highlightDc30C && c == 6) ...<String>{'HL'},
      if (highlightDc30C && (c == 10 || c == 11 || c == 13)) ...<String>{'HL', 'HR'},
      if (highlightDc30C && c == 14) ...<String>{'WT', 'HR'},
      if (highlightDc26 &&
          c != 8 &&
          c != 9 &&
          c != 11 &&
          c != 12 &&
          c != 13) ...<String>{'WB'},
      if (highlightDc26 && (c == 8 || c == 9 || c == 11 || c == 12 || c == 13))
        ...<String>{'WB'},
      if (highlightM24)
        ...<String>{'W_T1', 'W_T2', 'W_T3', 'W_B1', 'W_B2', 'W_B3'},
      if (highlightM23)
        ...<String>{
          'H_L',
          'H_R',
          if (m23HighlightAllVerticals) 'H_D25_L',
          if (m23HighlightAllVerticals) 'H_D25_R',
          if (m23HighlightAllVerticals) 'H_D75_L',
          if (m23HighlightAllVerticals) 'H_D75_R',
        },
      if (highlightM28) ...<String>{'H_D25_L', 'H_D25_R', 'H_D75_L', 'H_D75_R'},
      if (highlightD29)
        ...<String>{
          'W_T1',
          'W_B1',
          'H_L',
          'H_D25_L',
          if (d29MirrorRightPanel) 'W_T3',
          if (d29MirrorRightPanel) 'W_B3',
          if (d29MirrorRightPanel) 'H_D75_R',
          if (d29MirrorRightPanel) 'H_R',
        },
    };

    TextPainter buildPainter(String id, String text) => TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: highlightLabelIds.contains(id)
              ? highlightPaint.color
              : basePaint.color,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    void drawLabel({
      required String id,
      required String text,
      required double x,
      required double y,
    }) {
      if (onlyHighlights && !highlightLabelIds.contains(id)) return;
      final TextPainter tp = buildPainter(id, text);
      tp.paint(canvas, Offset(x, y));
    }

    final TextPainter tpWT = buildPainter('WT', 'WT');
    final double wtY = (labelRect.top - labelGap - tpWT.height).clamp(0, size.height);
    drawLabel(
      id: 'WT',
      text: 'WT',
      x: labelRect.center.dx - (tpWT.width / 2),
      y: wtY,
    );

    final TextPainter tpWB = buildPainter('WB', 'WB');
    drawLabel(
      id: 'WB',
      text: 'WB',
      x: labelRect.center.dx - (tpWB.width / 2),
      y: labelRect.bottom + labelGap,
    );

    final TextPainter tpHL = buildPainter('HL', 'HL');
    drawLabel(
      id: 'HL',
      text: 'HL',
      x: (labelRect.left - sideGap - tpHL.width).clamp(0, size.width),
      y: labelRect.center.dy - (tpHL.height / 2),
    );

    final TextPainter tpHR = buildPainter('HR', 'HR');
    drawLabel(
      id: 'HR',
      text: 'HR',
      x: (labelRect.right + sideGap).clamp(0, size.width - tpHR.width),
      y: labelRect.center.dy - (tpHR.height / 2),
    );

    final List<Rect> panels = <Rect>[
      Rect.fromLTRB(innerRect.left, innerRect.top, x25, innerRect.bottom),
      Rect.fromLTRB(x25, innerRect.top, x75, innerRect.bottom),
      Rect.fromLTRB(x75, innerRect.top, innerRect.right, innerRect.bottom),
    ];

    for (int i = 0; i < panels.length; i++) {
      final Rect panel = panels[i];
      final String topId = 'W_T${i + 1}';
      final String bottomId = 'W_B${i + 1}';
      final TextPainter top = buildPainter(topId, 'W');
      final TextPainter bottom = buildPainter(bottomId, 'W');
      drawLabel(
        id: topId,
        text: 'W',
        x: panel.center.dx - (top.width / 2),
        y: panel.top + innerGap,
      );
      drawLabel(
        id: bottomId,
        text: 'W',
        x: panel.center.dx - (bottom.width / 2),
        y: panel.bottom - innerGap - bottom.height,
      );
    }

    final double hY = innerRect.center.dy;
    final TextPainter hSample = buildPainter('H_L', 'H');
    drawLabel(
      id: 'H_L',
      text: 'H',
      x: innerRect.left + innerGap,
      y: hY - (hSample.height / 2),
    );
    drawLabel(
      id: 'H_D25_L',
      text: 'H',
      x: x25 - innerGap - hSample.width,
      y: hY - (hSample.height / 2),
    );
    drawLabel(
      id: 'H_D25_R',
      text: 'H',
      x: x25 + innerGap,
      y: hY - (hSample.height / 2),
    );
    drawLabel(
      id: 'H_D75_L',
      text: 'H',
      x: x75 - innerGap - hSample.width,
      y: hY - (hSample.height / 2),
    );
    drawLabel(
      id: 'H_D75_R',
      text: 'H',
      x: x75 + innerGap,
      y: hY - (hSample.height / 2),
    );
    drawLabel(
      id: 'H_R',
      text: 'H',
      x: innerRect.right - innerGap - hSample.width,
      y: hY - (hSample.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _PanelCenterFixPainter oldDelegate) {
    return oldDelegate.selectedSection != selectedSection ||
        oldDelegate.sectionAliases != sectionAliases ||
        oldDelegate.collarId != collarId ||
        oldDelegate.leftDividerFraction != leftDividerFraction ||
        oldDelegate.rightDividerFraction != rightDividerFraction ||
        oldDelegate.d29MirrorRightPanel != d29MirrorRightPanel ||
        oldDelegate.m23HighlightAllVerticals != m23HighlightAllVerticals;
  }
}

class PanelCenterFixOverlay extends StatelessWidget {
  final String? selectedSection;
  final Map<String, String> sectionAliases;
  final int? collarId;
  final double leftDividerFraction;
  final double rightDividerFraction;
  final bool d29MirrorRightPanel;
  final bool m23HighlightAllVerticals;

  const PanelCenterFixOverlay({
    super.key,
    required this.selectedSection,
    this.sectionAliases = const <String, String>{},
    this.collarId,
    this.leftDividerFraction = 0.25,
    this.rightDividerFraction = 0.75,
    this.d29MirrorRightPanel = true,
    this.m23HighlightAllVerticals = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PanelCenterFixPainter(
        selectedSection: selectedSection,
        sectionAliases: sectionAliases,
        collarId: collarId,
        leftDividerFraction: leftDividerFraction,
        rightDividerFraction: rightDividerFraction,
        d29MirrorRightPanel: d29MirrorRightPanel,
        m23HighlightAllVerticals: m23HighlightAllVerticals,
      ),
      child: const SizedBox.expand(),
    );
  }
}
