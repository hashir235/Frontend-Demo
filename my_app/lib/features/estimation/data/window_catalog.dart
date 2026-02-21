import '../models/window_type.dart';

class WindowCatalog {
  static const List<WindowType> root = [
    WindowType(
      label: 'Sliding Window',
      graphicKey: 'sliding_basic',
      children: [],
      displayIndex: 1,
      codeName: 'S_win',
    ),
    WindowType(
      label: 'Sliding Window M_Section',
      graphicKey: 'sliding_basic',
      children: [],
      displayIndex: 2,
      codeName: 'MS_win',
    ),
    WindowType(
      label: 'Panel Windows',
      graphicKey: 'panel_basic',
      children: [
        WindowType(
          label: 'Center Fix',
          graphicKey: 'panel_basic',
          children: [],
          displayIndex: 3,
          codeName: 'PF3_win',
        ),
        WindowType(
          label: 'Center Slide',
          graphicKey: 'panel_basic',
          children: [],
          displayIndex: 4,
          codeName: 'PS4_win',
        ),
        WindowType(
          label: 'Equal Panel',
          graphicKey: 'panel_basic',
          children: [],
          displayIndex: 5,
          codeName: 'EF3_win',
        ),
        WindowType(
          label: 'Sliding Equal Panel',
          graphicKey: 'panel_basic',
          children: [],
          displayIndex: 6,
          codeName: 'ES3_win',
        ),
      ],
      displayIndex: null,
    ),
    WindowType(
      label: 'Panel Windows M_Section',
      graphicKey: 'panel_basic',
      children: [
        WindowType(
          label: 'Center Fix',
          graphicKey: 'panel_basic',
          children: [],
          displayIndex: 7,
          codeName: 'MPF3_win',
        ),
        WindowType(
          label: 'Center Slide',
          graphicKey: 'panel_basic',
          children: [],
          displayIndex: 8,
          codeName: 'MPS4_win',
        ),
        WindowType(
          label: 'Equal Panel',
          graphicKey: 'panel_basic',
          children: [],
          displayIndex: 9,
          codeName: 'MEF3_win',
        ),
        WindowType(
          label: 'Sliding Equal Panel',
          graphicKey: 'panel_basic',
          children: [],
          displayIndex: 10,
          codeName: 'MES3_win',
        ),
      ],
      displayIndex: null,
    ),
    WindowType(
      label: 'Sliding Corner Windows',
      graphicKey: 'corner_basic',
      children: [
        WindowType(
          label: 'Sliding Corner Center Fix',
          graphicKey: 'corner_basic',
          children: [],
          displayIndex: 11,
          codeName: 'SCF_win',
        ),
        WindowType(
          label: 'Sliding Corner Center Slide',
          graphicKey: 'corner_basic',
          children: [],
          displayIndex: 12,
          codeName: 'SCS_win',
        ),
        WindowType(
          label: 'Sliding Corner Left Fix',
          graphicKey: 'corner_basic',
          children: [],
          displayIndex: 13,
          codeName: 'SCL_win',
        ),
        WindowType(
          label: 'Sliding Corner Right Fix',
          graphicKey: 'corner_basic',
          children: [],
          displayIndex: 14,
          codeName: 'SCR_win',
        ),
      ],
      displayIndex: null,
    ),
    WindowType(
      label: 'Sliding Corner Windows M_Section',
      graphicKey: 'corner_basic',
      children: [
        WindowType(
          label: 'Sliding Corner Center Fix',
          graphicKey: 'corner_basic',
          children: [],
          displayIndex: 15,
          codeName: 'MSCF_win',
        ),
        WindowType(
          label: 'Sliding Corner Center Slide',
          graphicKey: 'corner_basic',
          children: [],
          displayIndex: 16,
          codeName: 'MSCS_win',
        ),
        WindowType(
          label: 'Sliding Corner Left Fix',
          graphicKey: 'corner_basic',
          children: [],
          displayIndex: 17,
          codeName: 'MSCL_win',
        ),
        WindowType(
          label: 'Sliding Corner Right Fix',
          graphicKey: 'corner_basic',
          children: [],
          displayIndex: 18,
          codeName: 'MSCR_win',
        ),
      ],
      displayIndex: null,
    ),
    WindowType(
      label: 'Fix Window',
      graphicKey: 'fix_basic',
      children: [],
      displayIndex: 19,
      codeName: 'F_win',
    ),
    WindowType(
      label: 'Corner Fix',
      graphicKey: 'fix_basic',
      children: [],
      displayIndex: 20,
      codeName: 'FC_win',
    ),
    WindowType(
      label: 'Openable',
      graphicKey: 'fix_basic',
      children: [],
      displayIndex: 21,
      codeName: 'O_win',
    ),
    WindowType(
      label: 'Door',
      graphicKey: 'door_basic',
      children: [
        WindowType(
          label: 'Single Door',
          graphicKey: 'door_basic',
          children: [],
          displayIndex: 22,
          codeName: 'Single_Door',
        ),
        WindowType(
          label: 'Double Door',
          graphicKey: 'door_basic',
          children: [],
          displayIndex: 23,
          codeName: 'Double_Door',
        ),
      ],
      displayIndex: null,
    ),
    WindowType(
      label: 'Arch',
      graphicKey: 'arch_basic',
      children: [
        WindowType(
          label: 'Round Arch',
          graphicKey: 'arch_basic',
          children: [],
          displayIndex: 24,
          codeName: 'A_win',
        ),
        WindowType(
          label: 'Rectangle',
          graphicKey: 'arch_basic',
          children: [],
          displayIndex: 25,
          codeName: 'AR_win',
        ),
      ],
      displayIndex: null,
    ),
  ];

  static WindowType? byDisplayIndex(int index) {
    return _findIn(root, index);
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
}
