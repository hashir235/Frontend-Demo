import 'package:flutter/material.dart';

import 'collar_frame_drawing.dart';
import 'fix_window_overlay.dart';

class OpenableWindowOverlay extends StatelessWidget
    implements CollarFrameDrawing {
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
      case 'D50A':
      case 'D50':
      case 'D29':
        return 'D41';
      default:
        return selectedSection;
    }
  }

  @override
  Rect collarFrameIn(Size size) => FixWindowOverlay.frameIn(size);

  @override
  Widget build(BuildContext context) {
    return FixWindowOverlay(
      collarId: collarId,
      selectedSection: _mappedSection,
    );
  }
}
