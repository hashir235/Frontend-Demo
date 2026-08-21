part of 'window_input_handler.dart';

class ArchRectInputHandler extends WindowInputHandler {
  const ArchRectInputHandler();

  @override
  int get collarCount => 8;

  /// No arch box: a rectangle arch is cut from its height and width alone.
  ///
  /// The engine's Rectangle branch never reads the arch value — it was being
  /// asked for, validated, sent, and then thrown away, while a window could
  /// not be saved without it. The round arch is the one that has an arch.
  @override
  bool get usesArchInput => false;

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
