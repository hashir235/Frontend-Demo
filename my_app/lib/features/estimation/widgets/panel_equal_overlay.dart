import 'package:flutter/material.dart';

import 'panel_center_fix_overlay.dart';

class PanelEqualOverlay extends StatelessWidget {
  final String? selectedSection;
  final Map<String, String> sectionAliases;
  final int? collarId;
  final bool m23HighlightAllVerticals;

  const PanelEqualOverlay({
    super.key,
    required this.selectedSection,
    this.sectionAliases = const <String, String>{},
    this.collarId,
    this.m23HighlightAllVerticals = false,
  });

  @override
  Widget build(BuildContext context) {
    return PanelCenterFixOverlay(
      selectedSection: selectedSection,
      sectionAliases: sectionAliases,
      collarId: collarId,
      leftDividerFraction: 1 / 3,
      rightDividerFraction: 2 / 3,
      d29MirrorRightPanel: false,
      m23HighlightAllVerticals: m23HighlightAllVerticals,
    );
  }
}
