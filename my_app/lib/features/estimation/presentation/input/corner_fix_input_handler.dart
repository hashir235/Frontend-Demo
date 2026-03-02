part of 'window_input_handler.dart';

class CornerFixInputHandler extends WindowInputHandler {
  static const double _cornerInteriorAngleDeg = 120;

  const CornerFixInputHandler();

  @override
  int get collarCount => 2;

  @override
  bool get usesSplitWidthInputs => true;

  @override
  Map<int, List<String>> get sectionsByCollar => const <int, List<String>>{
    1: <String>['D54F', 'D41'],
    2: <String>['D54A', 'D41'],
  };

  @override
  Widget? overlayForCollar(int collarIndex, String? selectedSection) {
    if (collarIndex < 1 || collarIndex > collarCount) {
      return null;
    }
    return SlidingCornerCenterFixOverlay(
      interiorAngleDeg: _cornerInteriorAngleDeg,
      collarId: collarIndex,
      windowCode: 'FC_win',
      selectedSection: selectedSection,
    );
  }
}
