import 'package:flutter/widgets.dart';

import 'sliding_corner_center_fix_overlay.dart';

class SlidingCornerMSectionOverlay extends StatelessWidget {
  final double interiorAngleDeg;
  final int? collarId;
  final String? windowCode;
  final String? selectedSection;

  const SlidingCornerMSectionOverlay({
    super.key,
    this.interiorAngleDeg = 26,
    this.collarId,
    this.windowCode,
    this.selectedSection,
  });

  String? _mappedWindowCode() {
    switch (windowCode) {
      case 'MSCF_win':
        return 'SCF_win';
      case 'MSCS_win':
        return 'SCS_win';
      case 'MSCL_win':
        return 'SCL_win';
      case 'MSCR_win':
        return 'SCR_win';
      default:
        return windowCode;
    }
  }

  String? _mappedSection() {
    switch (selectedSection?.trim().toUpperCase()) {
      case 'M30F':
        return 'DC30F';
      case 'M26F':
        return 'DC26F';
      case 'M30':
        return 'DC30C';
      case 'M26':
        return 'DC26C';
      case 'M23':
        return 'M23';
      case 'M24':
        return 'M24';
      case 'M28':
        return 'M28';
      default:
        return selectedSection;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SlidingCornerCenterFixOverlay(
      interiorAngleDeg: interiorAngleDeg,
      collarId: collarId,
      windowCode: _mappedWindowCode(),
      selectedSection: _mappedSection(),
    );
  }
}
