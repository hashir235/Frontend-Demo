import 'package:flutter/widgets.dart';

import '../../models/window_type.dart';
import '../../widgets/sliding_section_overlay.dart';

/// Base class for window-specific input behavior.
abstract class WindowInputHandler {
  const WindowInputHandler();

  /// Sections to show in the drawer for a given collar.
  List<String> sectionsForCollar(int collarIndex) =>
      sectionsByCollar[collarIndex] ?? const [];

  /// Whether the drawer should be shown for this collar.
  bool showDrawerForCollar(int collarIndex) =>
      sectionsByCollar.containsKey(collarIndex);

  /// Optional overlay painter/widget for the given collar.
  Widget? overlayForCollar(int collarIndex, String? selectedSection) => null;

  /// Map of collarIndex -> section list (override per window).
  Map<int, List<String>> get sectionsByCollar => const {};

  /// Map of collarIndex -> alias map (baseKey -> aliasKey).
  Map<int, Map<String, String>> get sectionAliasesByCollar => const {};

  Map<String, String> aliasesForCollar(int collarIndex) =>
      sectionAliasesByCollar[collarIndex] ?? const {};
}

class DefaultInputHandler extends WindowInputHandler {
  const DefaultInputHandler();
}

class SlidingWindowInputHandler extends WindowInputHandler {
  static const List<String> _baseSections = <String>[
    'DC30F',
    'DC26F',
    'D29',
    'M23',
    'M24',
    'M28',
  ];

  static final Map<int, List<String>> _sections = () {
    final Map<int, List<String>> map = <int, List<String>>{
      1: _baseSections,
      2: const <String>[
        'DC30C',
        'DC26C',
        'D29',
        'M23',
        'M24',
        'M28',
      ],
      3: const <String>[
        'DC30F',
        'DC30C',
        'DC26F',
        'D29',
        'M23',
        'M24',
        'M28',
      ],
      4: const <String>[
        'DC30F',
        'DC30C',
        'DC26F',
        'D29',
        'M23',
        'M24',
        'M28',
      ],
      5: const <String>[
        'DC30F',
        'DC26C',
        'D29',
        'M23',
        'M24',
        'M28',
      ],
      6: const <String>[
        'DC30F',
        'DC30C',
        'DC26F',
        'D29',
        'M23',
        'M24',
        'M28',
      ],
      7: const <String>[
        'DC30F',
        'DC30C',
        'DC26F',
        'D29',
        'M23',
        'M24',
        'M28',
      ],
      8: const <String>[
        'DC30F',
        'DC30C',
        'DC26C',
        'D29',
        'M23',
        'M24',
        'M28',
      ],
      9: const <String>[
        'DC30F',
        'DC30C',
        'DC26C',
        'D29',
        'M23',
        'M24',
        'M28',
      ],
      10: const <String>[
        'DC30F',
        'DC30C',
        'DC26F',
        'D29',
        'M23',
        'M24',
        'M28',
      ],
      11: const <String>[
        'DC30F',
        'DC30C',
        'DC26C',
        'D29',
        'M23',
        'M24',
        'M28',
      ],
      12: const <String>[
        'DC30F',
        'DC30C',
        'DC26C',
        'D29',
        'M23',
        'M24',
        'M28',
      ],
      13: const <String>[
        'DC30C',
        'DC26F',
        'D29',
        'M23',
        'M24',
        'M28',
      ],
      14: const <String>[
        'DC30F',
        'DC30C',
        'DC26C',
        'D29',
        'M23',
        'M24',
        'M28',
      ],
    };
    for (int i = 9; i <= 14; i++) {
      if (map.containsKey(i)) continue;
      map[i] = _baseSections;
    }
    return map;
  }();

  static final Map<int, Map<String, String>> _aliases = () {
    final Map<int, Map<String, String>> map = <int, Map<String, String>>{
      1: const {},
      2: const {
        'DC30F': 'DC30C',
        'DC26F': 'DC26C',
      },
      5: const {
        'DC26F': 'DC26C',
      },
      6: const {},
      7: const {},
      8: const {
        'DC26F': 'DC26C',
      },
    };
    for (int i = 3; i <= 14; i++) {
      if (map.containsKey(i)) continue;
      map[i] = const {};
    }
    return map;
  }();

  const SlidingWindowInputHandler();

  @override
  List<String> sectionsForCollar(int collarIndex) {
    if (collarIndex == 9) {
      return const <String>[
        'DC30F',
        'DC30C',
        'DC26C',
        'D29',
        'M23',
        'M24',
        'M28',
      ];
    }
    return super.sectionsForCollar(collarIndex);
  }

  @override
  bool showDrawerForCollar(int collarIndex) =>
      sectionsForCollar(collarIndex).isNotEmpty;

  @override
  Map<int, List<String>> get sectionsByCollar => _sections;

  @override
  Map<int, Map<String, String>> get sectionAliasesByCollar => _aliases;

  @override
  Widget? overlayForCollar(int collarIndex, String? selectedSection) {
    if (!showDrawerForCollar(collarIndex)) return null;
    return SlidingSectionOverlay(
      selectedSection: selectedSection,
      sectionAliases: aliasesForCollar(collarIndex),
      collarId: collarIndex,
    );
  }
}

WindowInputHandler handlerForWindow(WindowType node) {
  if (node.label == 'Sliding Window') {
    return const SlidingWindowInputHandler();
  }
  return const DefaultInputHandler();
}
