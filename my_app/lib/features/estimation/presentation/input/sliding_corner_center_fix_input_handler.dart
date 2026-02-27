part of 'window_input_handler.dart';

class SlidingCornerCenterFixInputHandler extends WindowInputHandler {
  static const double _cornerInteriorAngleDeg = 120;
  final String windowCode;

  const SlidingCornerCenterFixInputHandler({required this.windowCode});

  @override
  Map<int, List<String>> get sectionsByCollar {
    if (windowCode != 'SCF_win') return const {};
    return const <int, List<String>>{
      1: <String>['DC30F', 'DC26F', 'M23', 'M28', 'M24'],
    };
  }

  @override
  int get collarCount => 2;

  @override
  Widget? overlayForCollar(int collarIndex, String? selectedSection) {
    if (collarIndex < 1 || collarIndex > collarCount) return null;
    return SlidingCornerCenterFixOverlay(
      interiorAngleDeg: _cornerInteriorAngleDeg,
      collarId: collarIndex,
      windowCode: windowCode,
      selectedSection: selectedSection,
    );
  }
}
