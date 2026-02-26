part of 'window_input_handler.dart';

class SlidingCornerCenterFixInputHandler extends WindowInputHandler {
  static const double _cornerInteriorAngleDeg = 120;

  const SlidingCornerCenterFixInputHandler();

  @override
  int get collarCount => 2;

  @override
  Widget? overlayForCollar(int collarIndex, String? selectedSection) {
    if (collarIndex < 1 || collarIndex > collarCount) return null;
    return SlidingCornerCenterFixOverlay(
      interiorAngleDeg: _cornerInteriorAngleDeg,
      collarId: collarIndex,
    );
  }
}
