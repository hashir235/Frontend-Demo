part of 'window_input_handler.dart';

class DoorDoubleInputHandler extends DoorSingleInputHandler {
  DoorDoubleInputHandler({super.d46Enabled, super.d52Enabled});

  @override
  Widget? overlayForCollar(int collarIndex, String? selectedSection) {
    if (collarIndex < 1 || collarIndex > collarCount) {
      return null;
    }
    return DoorDoubleOverlay(
      collarId: collarIndex,
      selectedSection: selectedSection,
      d46Enabled: d46Enabled,
      d52Enabled: d52Enabled,
    );
  }
}
