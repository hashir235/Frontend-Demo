part of 'window_input_handler.dart';

class ArchRectInputHandler extends WindowInputHandler {
  const ArchRectInputHandler();

  @override
  int get collarCount => 8;

  @override
  bool get usesArchInput => true;

  @override
  Map<int, List<String>> get sectionsByCollar => const <int, List<String>>{
    1: <String>['D41', 'D51F', 'D51A'],
    2: <String>['D41', 'D51A'],
    3: <String>['D41', 'D51F', 'D51A'],
    4: <String>['D41', 'D51F', 'D51A'],
    5: <String>['D41', 'D51F', 'D51A'],
    6: <String>['D41', 'D51F', 'D51A'],
    7: <String>['D41', 'D51F', 'D51A'],
    8: <String>['D41', 'D51F', 'D51A'],
  };

  @override
  Widget? overlayForCollar(int collarIndex, String? selectedSection) {
    if (collarIndex < 1 || collarIndex > collarCount) {
      return null;
    }
    return ArchRectOverlay(
      collarId: collarIndex,
      selectedSection: selectedSection,
    );
  }
}
