part of 'window_input_handler.dart';

class SlidingWindowMSectionInputHandler extends WindowInputHandler {
  static final Map<int, List<String>> _sections = <int, List<String>>{
    1: const <String>['M30F', 'M26F', 'M23', 'M24', 'M28'],
    2: const <String>['M30', 'M26', 'M23', 'M24', 'M28'],
    3: const <String>['M30F', 'M30', 'M26F', 'M23', 'M24', 'M28'],
    4: const <String>['M30F', 'M30', 'M26F', 'M23', 'M24', 'M28'],
    5: const <String>['M30F', 'M26', 'M23', 'M24', 'M28'],
    6: const <String>['M30F', 'M30', 'M26F', 'M23', 'M24', 'M28'],
    7: const <String>['M30F', 'M30', 'M26F', 'M23', 'M24', 'M28'],
    8: const <String>['M30F', 'M30', 'M26', 'M23', 'M24', 'M28'],
    9: const <String>['M30F', 'M30', 'M26', 'M23', 'M24', 'M28'],
    10: const <String>['M30F', 'M30', 'M26F', 'M23', 'M24', 'M28'],
    11: const <String>['M30F', 'M30', 'M26', 'M23', 'M24', 'M28'],
    12: const <String>['M30F', 'M30', 'M26', 'M23', 'M24', 'M28'],
    13: const <String>['M30', 'M26F', 'M23', 'M24', 'M28'],
    14: const <String>['M30F', 'M30', 'M26', 'M23', 'M24', 'M28'],
  };

  static final Map<int, Map<String, String>> _aliases =
      <int, Map<String, String>>{
        1: const <String, String>{},
        2: const <String, String>{'M30F': 'M30', 'M26F': 'M26'},
        3: const <String, String>{},
        4: const <String, String>{},
        5: const <String, String>{'M26F': 'M26'},
        6: const <String, String>{},
        7: const <String, String>{},
        8: const <String, String>{'M26F': 'M26'},
        9: const <String, String>{},
        10: const <String, String>{},
        11: const <String, String>{},
        12: const <String, String>{},
        13: const <String, String>{},
        14: const <String, String>{},
      };

  const SlidingWindowMSectionInputHandler();

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
    return SlidingMSectionOverlay(
      selectedSection: selectedSection,
      sectionAliases: aliasesForCollar(collarIndex),
      collarId: collarIndex,
    );
  }
}
