part of 'window_input_handler.dart';

class ArchRectInputHandler extends WindowInputHandler {
  const ArchRectInputHandler();

  @override
  int get collarCount => 8;

  @override
  Map<int, List<String>> get sectionsByCollar => const <int, List<String>>{
    1: <String>['D41', 'D50F', 'D50A'],
    2: <String>['D41', 'D50A'],
    3: <String>['D41', 'D50F', 'D50A'],
    4: <String>['D41', 'D50F', 'D50A'],
    5: <String>['D41', 'D50F', 'D50A'],
    6: <String>['D41', 'D50F', 'D50A'],
    7: <String>['D41', 'D50F', 'D50A'],
    8: <String>['D41', 'D50F', 'D50A'],
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
