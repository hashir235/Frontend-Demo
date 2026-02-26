part of 'window_input_handler.dart';

class PanelCenterFixInputHandler extends WindowInputHandler {
  static final Map<int, List<String>> _sections = <int, List<String>>{
    1: const <String>['DC30F', 'DC26F', 'D29', 'M23', 'M24', 'M28'],
    2: const <String>['DC30C', 'DC26C', 'D29', 'M23', 'M24', 'M28'],
    3: const <String>['DC30F', 'DC30C', 'DC26F', 'D29', 'M23', 'M24', 'M28'],
    4: const <String>['DC30F', 'DC30C', 'DC26F', 'D29', 'M23', 'M24', 'M28'],
    5: const <String>['DC30F', 'DC26C', 'D29', 'M23', 'M24', 'M28'],
    6: const <String>['DC30F', 'DC30C', 'DC26F', 'D29', 'M23', 'M24', 'M28'],
    7: const <String>['DC30F', 'DC30C', 'DC26F', 'D29', 'M23', 'M24', 'M28'],
    8: const <String>['DC30F', 'DC30C', 'DC26C', 'D29', 'M23', 'M24', 'M28'],
    9: const <String>['DC30F', 'DC30C', 'DC26C', 'D29', 'M23', 'M24', 'M28'],
    10: const <String>['DC30F', 'DC30C', 'DC26F', 'D29', 'M23', 'M24', 'M28'],
    11: const <String>['DC30F', 'DC30C', 'DC26C', 'D29', 'M23', 'M24', 'M28'],
    12: const <String>['DC30F', 'DC30C', 'DC26C', 'D29', 'M23', 'M24', 'M28'],
    13: const <String>['DC30C', 'DC26F', 'D29', 'M23', 'M24', 'M28'],
    14: const <String>['DC30F', 'DC30C', 'DC26C', 'D29', 'M23', 'M24', 'M28'],
  };

  static final Map<int, Map<String, String>> _aliases =
      <int, Map<String, String>>{
        1: const <String, String>{},
        2: const <String, String>{'DC30F': 'DC30C', 'DC26F': 'DC26C'},
        3: const <String, String>{},
        4: const <String, String>{},
        5: const <String, String>{'DC26F': 'DC26C'},
        6: const <String, String>{},
        7: const <String, String>{},
        8: const <String, String>{'DC26F': 'DC26C'},
        9: const <String, String>{},
        10: const <String, String>{},
        11: const <String, String>{},
        12: const <String, String>{},
        13: const <String, String>{},
        14: const <String, String>{},
      };

  const PanelCenterFixInputHandler();

  @override
  Map<int, List<String>> get sectionsByCollar => _sections;

  @override
  Map<int, Map<String, String>> get sectionAliasesByCollar => _aliases;

  @override
  bool showDrawerForCollar(int collarIndex) =>
      _sections.containsKey(collarIndex);

  @override
  Widget? overlayForCollar(int collarIndex, String? selectedSection) {
    if (!showDrawerForCollar(collarIndex)) return null;
    return PanelCenterFixOverlay(
      selectedSection: selectedSection,
      sectionAliases: aliasesForCollar(collarIndex),
      collarId: collarIndex,
    );
  }
}
