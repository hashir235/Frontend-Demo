import '../models/window_type.dart';

class WindowCatalog {
  static const List<WindowType> root = [
    WindowType(
      label: 'Sliding Window',
      graphicKey: 'sliding_basic',
      children: [],
      displayIndex: 1,
    ),
    WindowType(
      label: 'Sliding Window M_Section',
      graphicKey: 'sliding_basic',
      children: [],
      displayIndex: 2,
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
        ),
        WindowType(
          label: 'Center Slide',
          graphicKey: 'panel_basic',
          children: [],
          displayIndex: 4,
        ),
        WindowType(
          label: 'Equal Panel',
          graphicKey: 'panel_basic',
          children: [],
          displayIndex: 5,
        ),
        WindowType(
          label: 'Sliding Equal Panel',
          graphicKey: 'panel_basic',
          children: [],
          displayIndex: 6,
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
        ),
        WindowType(
          label: 'Center Slide',
          graphicKey: 'panel_basic',
          children: [],
          displayIndex: 8,
        ),
        WindowType(
          label: 'Equal Panel',
          graphicKey: 'panel_basic',
          children: [],
          displayIndex: 9,
        ),
        WindowType(
          label: 'Sliding Equal Panel',
          graphicKey: 'panel_basic',
          children: [],
          displayIndex: 10,
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
        ),
        WindowType(
          label: 'Sliding Corner Center Slide',
          graphicKey: 'corner_basic',
          children: [],
          displayIndex: 12,
        ),
        WindowType(
          label: 'Sliding Corner Left Fix',
          graphicKey: 'corner_basic',
          children: [],
          displayIndex: 13,
        ),
        WindowType(
          label: 'Sliding Corner Right Fix',
          graphicKey: 'corner_basic',
          children: [],
          displayIndex: 14,
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
        ),
        WindowType(
          label: 'Sliding Corner Center Slide',
          graphicKey: 'corner_basic',
          children: [],
          displayIndex: 16,
        ),
        WindowType(
          label: 'Sliding Corner Left Fix',
          graphicKey: 'corner_basic',
          children: [],
          displayIndex: 17,
        ),
        WindowType(
          label: 'Sliding Corner Right Fix',
          graphicKey: 'corner_basic',
          children: [],
          displayIndex: 18,
        ),
      ],
      displayIndex: null,
    ),
    WindowType(
      label: 'Fix Window',
      graphicKey: 'fix_basic',
      children: [],
      displayIndex: 19,
    ),
    WindowType(
      label: 'Corner Fix',
      graphicKey: 'fix_basic',
      children: [],
      displayIndex: 20,
    ),
    WindowType(
      label: 'Openable',
      graphicKey: 'fix_basic',
      children: [],
      displayIndex: 21,
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
        ),
        WindowType(
          label: 'Double Door',
          graphicKey: 'door_basic',
          children: [],
          displayIndex: 23,
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
        ),
        WindowType(
          label: 'Rectangle',
          graphicKey: 'arch_basic',
          children: [],
          displayIndex: 25,
        ),
      ],
      displayIndex: null,
    ),
  ];
}
