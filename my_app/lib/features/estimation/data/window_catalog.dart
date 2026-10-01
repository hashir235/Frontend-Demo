import '../models/window_type.dart';
import '../models/window_variant.dart';

/// One line of windows in the library, swiped sideways.
class WindowRow {
  const WindowRow({required this.id, required this.nodes, this.title});

  /// A stable name for keys and tests: "sliding", "sliding_b", "box".
  final String id;

  final List<WindowType> nodes;

  /// The line's own heading, where a group holds lines from different makers
  /// (the Economy windows: PAK AL TECH's, and Prime's). Null for a line that
  /// needs none beyond its group's.
  final String? title;
}

/// A kind of window in the library: a heading, and the lines of windows
/// under it. The sliding windows have three lines -- the plain frame, the B
/// frame and the BA frame -- under the one heading.
class WindowGroup {
  const WindowGroup({required this.id, required this.title, required this.rows});

  /// A stable name for keys and tests: "sliding", "box".
  final String id;

  /// The heading the rows go under.
  final String title;

  final List<WindowRow> rows;

  /// Every window in the group, line by line.
  List<WindowType> get nodes => <WindowType>[
    for (final WindowRow row in rows) ...row.nodes,
  ];
}

class WindowCatalog {
  /// Windows that slide: the sliding window, the panel windows and the
  /// sliding corner windows, each with its M-section twin.
  static const List<WindowType> slidingWindows = <WindowType>[
    WindowType(
      label: 'Sliding Window',
      subtitle: 'Balanced day-to-day aluminium sliding system',
      graphicKey: 'sliding_basic',
      children: <WindowType>[],
      displayIndex: 1,
      codeName: 'S_win',
    ),
    WindowType(
      label: 'Sliding Window M_Section',
      subtitle: 'Sliding window with M-section profile',
      graphicKey: 'sliding_basic',
      children: <WindowType>[],
      displayIndex: 2,
      codeName: 'MS_win',
    ),
    WindowType(
      label: 'Panel Windows',
      subtitle: 'Center fix, center slide, and equal panel variants',
      graphicKey: 'panel_basic',
      children: <WindowType>[
        WindowType(
          label: 'Center Fix',
          subtitle: 'Three-panel layout with center fixed section',
          graphicKey: 'panel_basic',
          children: <WindowType>[],
          displayIndex: 3,
          codeName: 'PF3_win',
        ),
        WindowType(
          label: 'Center Slide',
          subtitle: 'Three-panel layout with center sliding section',
          graphicKey: 'panel_basic',
          children: <WindowType>[],
          displayIndex: 4,
          codeName: 'PS4_win',
        ),
        WindowType(
          label: 'Equal Panel',
          subtitle: 'Even visual balance across the full panel set',
          graphicKey: 'panel_basic',
          children: <WindowType>[],
          displayIndex: 5,
          codeName: 'EF3_win',
        ),
      ],
      displayIndex: null,
    ),
    WindowType(
      label: 'Panel Windows M_Section',
      subtitle: 'M-section panel family for broader fabrication needs',
      graphicKey: 'panel_basic',
      children: <WindowType>[
        WindowType(
          label: 'Center Fix',
          subtitle: 'M-section center fix panel arrangement',
          graphicKey: 'panel_basic',
          children: <WindowType>[],
          displayIndex: 7,
          codeName: 'MPF3_win',
        ),
        WindowType(
          label: 'Center Slide',
          subtitle: 'M-section center slide panel arrangement',
          graphicKey: 'panel_basic',
          children: <WindowType>[],
          displayIndex: 8,
          codeName: 'MPS4_win',
        ),
        WindowType(
          label: 'Equal Panel',
          subtitle: 'Equal panel arrangement with M-section profiles',
          graphicKey: 'panel_basic',
          children: <WindowType>[],
          displayIndex: 8,
          codeName: 'MEF3_win',
        ),
      ],
      displayIndex: null,
    ),
    WindowType(
      label: 'Sliding Corner Windows',
      subtitle: 'Corner-focused layouts with multiple opening behaviors',
      graphicKey: 'corner_basic',
      children: <WindowType>[
        WindowType(
          label: 'Sliding Corner Center Fix',
          subtitle: 'Corner system with center fixed panel',
          graphicKey: 'corner_basic',
          children: <WindowType>[],
          displayIndex: 9,
          codeName: 'SCF_win',
        ),
        WindowType(
          label: 'Sliding Corner Center Slide',
          subtitle: 'Corner system with center sliding panel',
          graphicKey: 'corner_basic',
          children: <WindowType>[],
          displayIndex: 10,
          codeName: 'SCS_win',
        ),
        WindowType(
          label: 'Sliding Corner Left Fix',
          subtitle: 'Corner system with left fixed panel',
          graphicKey: 'corner_basic',
          children: <WindowType>[],
          displayIndex: 11,
          codeName: 'SCL_win',
        ),
        WindowType(
          label: 'Sliding Corner Right Fix',
          subtitle: 'Corner system with right fixed panel',
          graphicKey: 'corner_basic',
          children: <WindowType>[],
          displayIndex: 12,
          codeName: 'SCR_win',
        ),
      ],
      displayIndex: null,
    ),
    WindowType(
      label: 'Sliding Corner Windows M_Section',
      subtitle: 'M-section corner layouts for heavier fabrication demands',
      graphicKey: 'corner_basic',
      children: <WindowType>[
        WindowType(
          label: 'Sliding Corner Center Fix',
          subtitle: 'M-section corner with center fixed panel',
          graphicKey: 'corner_basic',
          children: <WindowType>[],
          displayIndex: 13,
          codeName: 'MSCF_win',
        ),
        WindowType(
          label: 'Sliding Corner Center Slide',
          subtitle: 'M-section corner with center sliding panel',
          graphicKey: 'corner_basic',
          children: <WindowType>[],
          displayIndex: 14,
          codeName: 'MSCS_win',
        ),
        WindowType(
          label: 'Sliding Corner Left Fix',
          subtitle: 'M-section corner with left fixed panel',
          graphicKey: 'corner_basic',
          children: <WindowType>[],
          displayIndex: 15,
          codeName: 'MSCL_win',
        ),
        WindowType(
          label: 'Sliding Corner Right Fix',
          subtitle: 'M-section corner with right fixed panel',
          graphicKey: 'corner_basic',
          children: <WindowType>[],
          displayIndex: 16,
          codeName: 'MSCR_win',
        ),
      ],
      displayIndex: null,
    ),
  ];

  /// The sliding windows again on the B frame -- DC30B and DC26B in place of
  /// DC30C and DC26C, everything else the same. See [WindowVariants].
  static const List<WindowType> primeWindows = <WindowType>[
    WindowType(
      label: 'Prime Sliding Window',
      subtitle: 'Sliding window on the DC30B / DC26B frame',
      graphicKey: 'sliding_basic',
      children: <WindowType>[],
      displayIndex: 24,
      codeName: 'SB_win',
    ),
    WindowType(
      label: 'Prime Panel Windows',
      subtitle: 'Panel windows on the DC30B / DC26B frame',
      graphicKey: 'panel_basic',
      children: <WindowType>[
        WindowType(
          label: 'Prime Center Fix',
          subtitle: 'Center fix panel on the DC30B / DC26B frame',
          graphicKey: 'panel_basic',
          children: <WindowType>[],
          displayIndex: 25,
          codeName: 'PF3B_win',
        ),
        WindowType(
          label: 'Prime Center Slide',
          subtitle: 'Center slide panel on the DC30B / DC26B frame',
          graphicKey: 'panel_basic',
          children: <WindowType>[],
          displayIndex: 26,
          codeName: 'PS4B_win',
        ),
        WindowType(
          label: 'Prime Equal Panel',
          subtitle: 'Equal panel on the DC30B / DC26B frame',
          graphicKey: 'panel_basic',
          children: <WindowType>[],
          displayIndex: 27,
          codeName: 'EF3B_win',
        ),
      ],
      displayIndex: null,
    ),
    WindowType(
      label: 'Prime Corner Windows',
      subtitle: 'Sliding corner windows on the DC30B / DC26B frame',
      graphicKey: 'corner_basic',
      children: <WindowType>[
        WindowType(
          label: 'Prime Corner Center Fix',
          subtitle: 'Corner with center fixed panel, DC30B / DC26B frame',
          graphicKey: 'corner_basic',
          children: <WindowType>[],
          displayIndex: 28,
          codeName: 'SCFB_win',
        ),
        WindowType(
          label: 'Prime Corner Center Slide',
          subtitle: 'Corner with center sliding panel, DC30B / DC26B frame',
          graphicKey: 'corner_basic',
          children: <WindowType>[],
          displayIndex: 29,
          codeName: 'SCSB_win',
        ),
        WindowType(
          label: 'Prime Corner Left Fix',
          subtitle: 'Corner with left fixed panel, DC30B / DC26B frame',
          graphicKey: 'corner_basic',
          children: <WindowType>[],
          displayIndex: 30,
          codeName: 'SCLB_win',
        ),
        WindowType(
          label: 'Prime Corner Right Fix',
          subtitle: 'Corner with right fixed panel, DC30B / DC26B frame',
          graphicKey: 'corner_basic',
          children: <WindowType>[],
          displayIndex: 31,
          codeName: 'SCRB_win',
        ),
      ],
      displayIndex: null,
    ),
  ];

  /// And on the BA frame: DC30BA and DC26BA.
  static const List<WindowType> royalWindows = <WindowType>[
    WindowType(
      label: 'Royal Sliding Window',
      subtitle: 'Sliding window on the DC30BA / DC26BA frame',
      graphicKey: 'sliding_basic',
      children: <WindowType>[],
      displayIndex: 32,
      codeName: 'SBA_win',
    ),
    WindowType(
      label: 'Royal Panel Windows',
      subtitle: 'Panel windows on the DC30BA / DC26BA frame',
      graphicKey: 'panel_basic',
      children: <WindowType>[
        WindowType(
          label: 'Royal Center Fix',
          subtitle: 'Center fix panel on the DC30BA / DC26BA frame',
          graphicKey: 'panel_basic',
          children: <WindowType>[],
          displayIndex: 33,
          codeName: 'PF3BA_win',
        ),
        WindowType(
          label: 'Royal Center Slide',
          subtitle: 'Center slide panel on the DC30BA / DC26BA frame',
          graphicKey: 'panel_basic',
          children: <WindowType>[],
          displayIndex: 34,
          codeName: 'PS4BA_win',
        ),
        WindowType(
          label: 'Royal Equal Panel',
          subtitle: 'Equal panel on the DC30BA / DC26BA frame',
          graphicKey: 'panel_basic',
          children: <WindowType>[],
          displayIndex: 35,
          codeName: 'EF3BA_win',
        ),
      ],
      displayIndex: null,
    ),
    WindowType(
      label: 'Royal Corner Windows',
      subtitle: 'Sliding corner windows on the DC30BA / DC26BA frame',
      graphicKey: 'corner_basic',
      children: <WindowType>[
        WindowType(
          label: 'Royal Corner Center Fix',
          subtitle: 'Corner with center fixed panel, DC30BA / DC26BA frame',
          graphicKey: 'corner_basic',
          children: <WindowType>[],
          displayIndex: 36,
          codeName: 'SCFBA_win',
        ),
        WindowType(
          label: 'Royal Corner Center Slide',
          subtitle: 'Corner with center sliding panel, DC30BA / DC26BA frame',
          graphicKey: 'corner_basic',
          children: <WindowType>[],
          displayIndex: 37,
          codeName: 'SCSBA_win',
        ),
        WindowType(
          label: 'Royal Corner Left Fix',
          subtitle: 'Corner with left fixed panel, DC30BA / DC26BA frame',
          graphicKey: 'corner_basic',
          children: <WindowType>[],
          displayIndex: 38,
          codeName: 'SCLBA_win',
        ),
        WindowType(
          label: 'Royal Corner Right Fix',
          subtitle: 'Corner with right fixed panel, DC30BA / DC26BA frame',
          graphicKey: 'corner_basic',
          children: <WindowType>[],
          displayIndex: 39,
          codeName: 'SCRBA_win',
        ),
      ],
      displayIndex: null,
    ),
  ];

  /// The Economy line: the first line's windows, M-section ones too, on the
  /// Economy profiles (EC for the plain windows, ET for the M-section ones).
  /// Same drawings, collars and formulas. See [WindowVariants].
  static const List<WindowType> economyWindows = <WindowType>[
    WindowType(
      label: 'Eco Sliding Window',
      subtitle: 'Sliding window on the Economy profiles',
      graphicKey: 'sliding_basic',
      children: <WindowType>[],
      displayIndex: 40,
      codeName: 'SE_win',
    ),
    WindowType(
      label: 'Eco Sliding Window M_Section',
      subtitle: 'M-section sliding window on the Economy ET profiles',
      graphicKey: 'sliding_basic',
      children: <WindowType>[],
      displayIndex: 48,
      codeName: 'MSE_win',
    ),
    WindowType(
      label: 'Eco Panel Windows',
      subtitle: 'Panel windows on the Economy profiles',
      graphicKey: 'panel_basic',
      children: <WindowType>[
        WindowType(
          label: 'Eco Center Fix',
          subtitle: 'Center fix panel, Economy profiles',
          graphicKey: 'panel_basic',
          children: <WindowType>[],
          displayIndex: 41,
          codeName: 'PF3E_win',
        ),
        WindowType(
          label: 'Eco Center Slide',
          subtitle: 'Center slide panel, Economy profiles',
          graphicKey: 'panel_basic',
          children: <WindowType>[],
          displayIndex: 42,
          codeName: 'PS4E_win',
        ),
        WindowType(
          label: 'Eco Equal Panel',
          subtitle: 'Equal panel, Economy profiles',
          graphicKey: 'panel_basic',
          children: <WindowType>[],
          displayIndex: 43,
          codeName: 'EF3E_win',
        ),
      ],
      displayIndex: null,
    ),
    WindowType(
      label: 'Eco Panel Windows M_Section',
      subtitle: 'M-section panel windows on the Economy ET profiles',
      graphicKey: 'panel_basic',
      children: <WindowType>[
        WindowType(
          label: 'Eco M Center Fix',
          subtitle: 'M-section center fix, Economy',
          graphicKey: 'panel_basic',
          children: <WindowType>[],
          displayIndex: 49,
          codeName: 'MPF3E_win',
        ),
        WindowType(
          label: 'Eco M Center Slide',
          subtitle: 'M-section center slide, Economy',
          graphicKey: 'panel_basic',
          children: <WindowType>[],
          displayIndex: 50,
          codeName: 'MPS4E_win',
        ),
        WindowType(
          label: 'Eco M Equal Panel',
          subtitle: 'M-section equal panel, Economy',
          graphicKey: 'panel_basic',
          children: <WindowType>[],
          displayIndex: 51,
          codeName: 'MEF3E_win',
        ),
      ],
      displayIndex: null,
    ),
    WindowType(
      label: 'Eco Corner Windows',
      subtitle: 'Sliding corner windows on the Economy profiles',
      graphicKey: 'corner_basic',
      children: <WindowType>[
        WindowType(
          label: 'Eco Corner Center Fix',
          subtitle: 'Corner with center fixed panel, Economy',
          graphicKey: 'corner_basic',
          children: <WindowType>[],
          displayIndex: 44,
          codeName: 'SCFE_win',
        ),
        WindowType(
          label: 'Eco Corner Center Slide',
          subtitle: 'Corner with center sliding panel, Economy',
          graphicKey: 'corner_basic',
          children: <WindowType>[],
          displayIndex: 45,
          codeName: 'SCSE_win',
        ),
        WindowType(
          label: 'Eco Corner Left Fix',
          subtitle: 'Corner with left fixed panel, Economy',
          graphicKey: 'corner_basic',
          children: <WindowType>[],
          displayIndex: 46,
          codeName: 'SCLE_win',
        ),
        WindowType(
          label: 'Eco Corner Right Fix',
          subtitle: 'Corner with right fixed panel, Economy',
          graphicKey: 'corner_basic',
          children: <WindowType>[],
          displayIndex: 47,
          codeName: 'SCRE_win',
        ),
      ],
      displayIndex: null,
    ),
    WindowType(
      label: 'Eco Corner Windows M_Section',
      subtitle: 'M-section sliding corners on the Economy ET profiles',
      graphicKey: 'corner_basic',
      children: <WindowType>[
        WindowType(
          label: 'Eco M Corner Center Fix',
          subtitle: 'M-section corner, center fixed, Economy',
          graphicKey: 'corner_basic',
          children: <WindowType>[],
          displayIndex: 52,
          codeName: 'MSCFE_win',
        ),
        WindowType(
          label: 'Eco M Corner Center Slide',
          subtitle: 'M-section corner, center sliding, Economy',
          graphicKey: 'corner_basic',
          children: <WindowType>[],
          displayIndex: 53,
          codeName: 'MSCSE_win',
        ),
        WindowType(
          label: 'Eco M Corner Left Fix',
          subtitle: 'M-section corner, left fixed, Economy',
          graphicKey: 'corner_basic',
          children: <WindowType>[],
          displayIndex: 54,
          codeName: 'MSCLE_win',
        ),
        WindowType(
          label: 'Eco M Corner Right Fix',
          subtitle: 'M-section corner, right fixed, Economy',
          graphicKey: 'corner_basic',
          children: <WindowType>[],
          displayIndex: 55,
          codeName: 'MSCRE_win',
        ),
      ],
      displayIndex: null,
    ),
  ];

  /// The Prime Economy line, on Prime's EF profiles, cut to formulas of its
  /// own (see [OwnWindow]). One window so far: the plain two-panel sliding
  /// window, with no collar.
  static const List<WindowType> primeEconomyWindows = <WindowType>[
    WindowType(
      label: 'Prime Eco Sliding Window',
      subtitle: 'Two-panel sliding window on the Prime EF profiles',
      graphicKey: 'sliding_basic',
      children: <WindowType>[],
      displayIndex: 56,
      codeName: 'SPE_win',
    ),
  ];

  /// Windows built as a box: fixed frame all round -- fix, corner fix,
  /// openable, doors and arches.
  static const List<WindowType> boxTypeWindows = <WindowType>[
    WindowType(
      label: 'Fix Window',
      subtitle: 'Simple fixed opening with clean geometry',
      graphicKey: 'fix_basic',
      children: <WindowType>[],
      displayIndex: 17,
      codeName: 'F_win',
    ),
    WindowType(
      label: 'Corner Fix',
      subtitle: 'Fixed corner layout for glass-heavy facades',
      graphicKey: 'fix_basic',
      children: <WindowType>[],
      displayIndex: 18,
      codeName: 'FC_win',
    ),
    WindowType(
      label: 'Openable',
      subtitle: 'Openable unit with optional net behavior',
      graphicKey: 'fix_basic',
      children: <WindowType>[],
      displayIndex: 19,
      codeName: 'O_win',
    ),
    WindowType(
      label: 'Door',
      subtitle: 'Single and double-door production paths',
      graphicKey: 'door_basic',
      children: <WindowType>[
        WindowType(
          label: 'Single Door',
          subtitle: 'Single-leaf door setup',
          graphicKey: 'door_basic',
          children: <WindowType>[],
          displayIndex: 20,
          codeName: 'Single_Door',
        ),
        WindowType(
          label: 'Double Door',
          subtitle: 'Double-leaf door setup',
          graphicKey: 'door_basic',
          children: <WindowType>[],
          displayIndex: 21,
          codeName: 'Double_Door',
        ),
      ],
      displayIndex: null,
    ),
    WindowType(
      label: 'Arch',
      subtitle: 'Round and rectangular arch families',
      graphicKey: 'arch_basic',
      children: <WindowType>[
        WindowType(
          label: 'Round Arch',
          subtitle: 'Curved top arch window',
          graphicKey: 'arch_basic',
          children: <WindowType>[],
          displayIndex: 22,
          codeName: 'A_win',
        ),
        WindowType(
          label: 'Rectangle',
          subtitle: 'Arch family with rectangular top framing',
          graphicKey: 'arch_basic',
          children: <WindowType>[],
          displayIndex: 23,
          codeName: 'AR_win',
        ),
      ],
      displayIndex: null,
    ),
  ];

  /// Every window, in library order.
  static const List<WindowType> root = <WindowType>[
    ...slidingWindows,
    ...primeWindows,
    ...royalWindows,
    ...economyWindows,
    ...primeEconomyWindows,
    ...boxTypeWindows,
  ];

  /// The library's rows for a flow. Fabrication has no arches.
  static List<WindowGroup> groupsForFlow({required bool isFabrication}) {
    List<WindowType> forFlow(List<WindowType> nodes) => isFabrication
        ? nodes.where((WindowType node) => !_isArchFamily(node)).toList(growable: false)
        : nodes;
    return <WindowGroup>[
      WindowGroup(
        id: 'sliding',
        title: 'Sliding Windows',
        rows: <WindowRow>[
          WindowRow(id: 'sliding', nodes: forFlow(slidingWindows)),
          WindowRow(id: 'sliding_b', nodes: forFlow(primeWindows)),
          WindowRow(id: 'sliding_ba', nodes: forFlow(royalWindows)),
        ],
      ),
      // Two makers' Economy windows, a line each under its maker's name: the
      // first line was built from PAK AL TECH's catalogue, the second is
      // Prime's.
      WindowGroup(
        id: 'economy',
        title: 'Economy Sliding Window',
        rows: <WindowRow>[
          WindowRow(
            id: 'economy',
            title: 'PAK AL TECH',
            nodes: forFlow(economyWindows),
          ),
          WindowRow(
            id: 'economy_prime',
            title: 'Prime Economy Sliding Windows',
            nodes: forFlow(primeEconomyWindows),
          ),
        ],
      ),
      WindowGroup(
        id: 'box',
        title: 'Box type Windows',
        rows: <WindowRow>[WindowRow(id: 'box', nodes: forFlow(boxTypeWindows))],
      ),
    ];
  }

  /// Every window kind a job can contain, by the name it is saved under.
  ///
  /// These are the leaf labels -- the thing the user actually picks -- and
  /// they are the same strings the bill groups its rows by, so a hardware rate
  /// entered against one of these lands on the bill line the customer reads.
  ///
  /// De-duplicated: the M_Section variants of the panel and sliding-corner
  /// windows carry the same labels as the plain ones, and one bill row covers
  /// both, so one rate does too.
  ///
  /// Derived from the catalogue rather than written out again, so a window
  /// added above cannot be forgotten here.
  static List<String> get allTypeNames {
    final List<String> names = <String>[];
    void walk(List<WindowType> nodes) {
      for (final WindowType node in nodes) {
        if (node.children.isEmpty) {
          if (!names.contains(node.label)) names.add(node.label);
        } else {
          walk(node.children);
        }
      }
    }

    walk(root);
    return List<String>.unmodifiable(names);
  }

  static WindowType? byDisplayIndex(int index) {
    return _findIn(root, index);
  }

  static WindowType? byCodeName(String codeName) {
    return _findByCode(root, codeName);
  }

  /// The window whose drawing [node] uses: a variant window's base (a Prime
  /// Center Fix is drawn as the Center Fix), and a family of variants the
  /// family its bases belong to. Every other window is its own.
  static WindowType drawnAs(WindowType node) {
    final WindowVariant? variant = WindowVariants.of(node.codeName);
    if (variant != null) return byCodeName(variant.baseCode) ?? node;
    if (!node.hasChildren) return node;
    final WindowVariant? first = WindowVariants.of(node.children.first.codeName);
    if (first == null) return node;
    for (final WindowType family in root) {
      if (family.children.any((WindowType child) => child.codeName == first.baseCode)) {
        return family;
      }
    }
    return node;
  }

  static bool _isArchFamily(WindowType node) {
    if (node.codeName == 'A_win' || node.codeName == 'AR_win') {
      return true;
    }
    if (node.children.isEmpty) {
      return false;
    }
    return node.children.any(
      (WindowType child) =>
          child.codeName == 'A_win' || child.codeName == 'AR_win',
    );
  }

  static WindowType? _findIn(List<WindowType> nodes, int index) {
    for (final WindowType node in nodes) {
      if (node.displayIndex == index) {
        return node;
      }
      if (node.children.isNotEmpty) {
        final WindowType? nested = _findIn(node.children, index);
        if (nested != null) {
          return nested;
        }
      }
    }
    return null;
  }

  static WindowType? _findByCode(List<WindowType> nodes, String codeName) {
    for (final WindowType node in nodes) {
      if (node.codeName == codeName) {
        return node;
      }
      if (node.children.isNotEmpty) {
        final WindowType? nested = _findByCode(node.children, codeName);
        if (nested != null) {
          return nested;
        }
      }
    }
    return null;
  }
}
