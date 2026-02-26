part of 'window_input_handler.dart';

class SlidingCornerCenterFixInputHandler extends WindowInputHandler {
  static const double _cornerInteriorAngleDeg = 120;

  const SlidingCornerCenterFixInputHandler();

  @override
  Widget? overlayForCollar(int collarIndex, String? selectedSection) {
    if (collarIndex < 1 || collarIndex > 14) return null;
    return SlidingCornerCenterFixOverlay(
      interiorAngleDeg: _cornerInteriorAngleDeg,
      collarId: collarIndex,
    );
  }
}
