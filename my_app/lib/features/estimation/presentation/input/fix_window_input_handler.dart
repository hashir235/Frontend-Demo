part of 'window_input_handler.dart';

class FixWindowInputHandler extends WindowInputHandler {
  const FixWindowInputHandler();

  @override
  Map<int, List<String>> get sectionsByCollar => const <int, List<String>>{
    1: <String>['D41', 'D54F'],
    2: <String>['D41', 'D54A'],
    3: <String>['D41', 'D54F', 'D54A'],
    4: <String>['D41', 'D54F', 'D54A'],
    5: <String>['D41', 'D54F', 'D54A'],
    6: <String>['D41', 'D54F', 'D54A'],
    7: <String>['D41', 'D54F', 'D54A'],
    8: <String>['D41', 'D54F', 'D54A'],
    9: <String>['D41', 'D54F', 'D54A'],
    10: <String>['D41', 'D54F', 'D54A'],
    11: <String>['D41', 'D54F', 'D54A'],
    12: <String>['D41', 'D54F', 'D54A'],
    13: <String>['D41', 'D54F', 'D54A'],
    14: <String>['D41', 'D54F', 'D54A'],
  };

  @override
  Widget? overlayForCollar(int collarIndex, String? selectedSection) {
    if (collarIndex < 1 || collarIndex > collarCount) {
      return null;
    }
    return FixWindowOverlay(
      collarId: collarIndex,
      selectedSection: selectedSection,
    );
  }
}
