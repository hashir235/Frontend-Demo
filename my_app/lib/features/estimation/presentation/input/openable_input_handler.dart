part of 'window_input_handler.dart';

class OpenableInputHandler extends WindowInputHandler {
  bool netEnabled;

  OpenableInputHandler({this.netEnabled = false});

  @override
  Map<int, List<String>> get sectionsByCollar {
    final Map<int, List<String>> base = <int, List<String>>{
      1: <String>['D50A', 'D54F', 'D54A'],
      2: <String>['D50A', 'D54A'],
      3: <String>['D50A', 'D54F', 'D54A'],
      4: <String>['D50A', 'D54F', 'D54A'],
      5: <String>['D50A', 'D54F', 'D54A'],
      6: <String>['D50A', 'D54F', 'D54A'],
      7: <String>['D50A', 'D54F', 'D54A'],
      8: <String>['D50A', 'D54F', 'D54A'],
      9: <String>['D50A', 'D54F', 'D54A'],
      10: <String>['D50A', 'D54F', 'D54A'],
      11: <String>['D50A', 'D54F', 'D54A'],
      12: <String>['D50A', 'D54F', 'D54A'],
      13: <String>['D50A', 'D54F', 'D54A'],
      14: <String>['D50A', 'D54F', 'D54A'],
    };

    if (!netEnabled) {
      return base;
    }

    return base.map((int key, List<String> value) {
      final List<String> sections = List<String>.from(value);
      final int insertAt = sections.indexOf('D50A');
      if (insertAt >= 0 && !sections.contains('D29')) {
        sections.insert(insertAt + 1, 'D29');
      }
      return MapEntry<int, List<String>>(key, sections);
    });
  }

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
