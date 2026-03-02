part of 'window_input_handler.dart';

class OpenableInputHandler extends WindowInputHandler {
  const OpenableInputHandler();

  @override
  Map<int, List<String>> get sectionsByCollar => const <int, List<String>>{
    1: <String>['D50', 'D54F', 'D54A'],
    2: <String>['D50', 'D54A'],
    3: <String>['D50', 'D54F', 'D54A'],
    4: <String>['D50', 'D54F', 'D54A'],
    5: <String>['D50', 'D54F', 'D54A'],
    6: <String>['D50', 'D54F', 'D54A'],
    7: <String>['D50', 'D54F', 'D54A'],
    8: <String>['D50', 'D54F', 'D54A'],
    9: <String>['D50', 'D54F', 'D54A'],
    10: <String>['D50', 'D54F', 'D54A'],
    11: <String>['D50', 'D54F', 'D54A'],
    12: <String>['D50', 'D54F', 'D54A'],
    13: <String>['D50', 'D54F', 'D54A'],
    14: <String>['D50', 'D54F', 'D54A'],
  };

  @override
  Widget? overlayForCollar(int collarIndex, String? selectedSection) {
    if (collarIndex < 1 || collarIndex > collarCount) {
      return null;
    }
    return OpenableWindowOverlay(
      collarId: collarIndex,
      selectedSection: selectedSection,
    );
  }
}
