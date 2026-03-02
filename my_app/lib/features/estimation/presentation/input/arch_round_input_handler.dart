part of 'window_input_handler.dart';

class ArchRoundInputHandler extends WindowInputHandler {
  const ArchRoundInputHandler();

  @override
  int get collarCount => 2;

  @override
  Map<int, List<String>> get sectionsByCollar => const <int, List<String>>{
    1: <String>['D41', 'D50A', 'D50F'],
    2: <String>['D41', 'D50A'],
  };

  @override
  Widget? overlayForCollar(int collarIndex, String? selectedSection) {
    if (collarIndex != 1 && collarIndex != 2) {
      return null;
    }
    return ArchRoundOverlay(
      collarId: collarIndex,
      selectedSection: selectedSection,
    );
  }
}
