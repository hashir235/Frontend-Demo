import 'package:flutter/material.dart';

import 'fix_window_overlay.dart';

class OpenableWindowOverlay extends StatelessWidget {
  final int collarId;
  final String? selectedSection;

  const OpenableWindowOverlay({
    super.key,
    required this.collarId,
    this.selectedSection,
  });

  String? get _mappedSection {
    if (selectedSection == null) {
      return null;
    }
    switch (selectedSection!.trim().toUpperCase()) {
      case 'D50':
        return 'D41';
      default:
        return selectedSection;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FixWindowOverlay(
      collarId: collarId,
      selectedSection: _mappedSection,
    );
  }
}
