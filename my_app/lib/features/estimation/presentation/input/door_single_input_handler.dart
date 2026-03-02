part of 'window_input_handler.dart';

class DoorSingleInputHandler extends WindowInputHandler {
  bool d46Enabled;
  bool d52Enabled;

  DoorSingleInputHandler({this.d46Enabled = false, this.d52Enabled = false});

  @override
  int get collarCount => 8;

  @override
  Map<int, List<String>> get sectionsByCollar {
    final Map<int, List<String>> base = <int, List<String>>{
      1: <String>['D50', 'D54F'],
      2: <String>['D50', 'D54A'],
      3: <String>['D50', 'D54F', 'D54A'],
      4: <String>['D50', 'D54F', 'D54A'],
      5: <String>['D50', 'D54F', 'D54A'],
      6: <String>['D50', 'D54F', 'D54A'],
      7: <String>['D50', 'D54F', 'D54A'],
      8: <String>['D50', 'D54F', 'D54A'],
    };
    if (!d46Enabled && !d52Enabled) {
      return base;
    }

    return base.map(
      (int key, List<String> value) {
        final List<String> sections = List<String>.from(value);
        int insertAt = sections.indexOf('D50');
        if (insertAt >= 0 && d46Enabled && !sections.contains('D46')) {
          sections.insert(insertAt + 1, 'D46');
          insertAt = sections.indexOf('D46');
        }
        if (insertAt >= 0 && d52Enabled && !sections.contains('D52')) {
          sections.insert(insertAt + 1, 'D52');
        }
        return MapEntry<int, List<String>>(key, sections);
      },
    );
  }

  @override
  Widget? overlayForCollar(int collarIndex, String? selectedSection) {
    if (collarIndex < 1 || collarIndex > collarCount) {
      return null;
    }
    return DoorSingleOverlay(
      collarId: collarIndex,
      selectedSection: selectedSection,
      d46Enabled: d46Enabled,
      d52Enabled: d52Enabled,
    );
  }
}
