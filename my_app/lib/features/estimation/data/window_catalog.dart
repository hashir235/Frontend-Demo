import '../models/window_type.dart';

class WindowCatalog {
  static const List<WindowType> root = <WindowType>[
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

  static List<WindowType> rootForFlow({required bool isFabrication}) {
    if (!isFabrication) {
      return root;
    }
    return root
        .where((WindowType node) => !_isArchFamily(node))
        .toList(growable: false);
  }

  static WindowType? byDisplayIndex(int index) {
    return _findIn(root, index);
  }

  static WindowType? byCodeName(String codeName) {
    return _findByCode(root, codeName);
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
