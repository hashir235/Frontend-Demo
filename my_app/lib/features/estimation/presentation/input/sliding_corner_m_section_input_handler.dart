part of 'window_input_handler.dart';

class SlidingCornerMSectionInputHandler extends WindowInputHandler {
  static const double _cornerInteriorAngleDeg = 120;
  final String windowCode;

  const SlidingCornerMSectionInputHandler({required this.windowCode});

  @override
  bool get usesSplitWidthInputs => true;

  @override
  Map<int, List<String>> get sectionsByCollar {
    if (windowCode != 'MSCF_win' &&
        windowCode != 'MSCS_win' &&
        windowCode != 'MSCL_win' &&
        windowCode != 'MSCR_win') {
      return const {};
    }
    return const <int, List<String>>{
      1: <String>['M30F', 'M26F', 'M23', 'M28', 'M24'],
      2: <String>['M30', 'M26', 'M23', 'M28', 'M24'],
    };
  }

  @override
  int get collarCount => 2;

  @override
  Widget? overlayForCollar(int collarIndex, String? selectedSection) {
    if (collarIndex < 1 || collarIndex > collarCount) return null;
    return SlidingCornerMSectionOverlay(
      interiorAngleDeg: _cornerInteriorAngleDeg,
      collarId: collarIndex,
      windowCode: windowCode,
      selectedSection: selectedSection,
    );
  }
}
