import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/models/window_type.dart';
import 'package:my_app/features/estimation/presentation/input/window_input_handler.dart';

void main() {
  const WindowType mSectionNode = WindowType(
    label: 'Sliding Window M_Section',
    graphicKey: 'sliding_basic',
    children: <WindowType>[],
    displayIndex: 2,
    codeName: 'MS_win',
  );
  const WindowType pf3Node = WindowType(
    label: 'Center Fix',
    graphicKey: 'panel_basic',
    children: <WindowType>[],
    displayIndex: 3,
    codeName: 'PF3_win',
  );
  const WindowType ps4Node = WindowType(
    label: 'Center Slide',
    graphicKey: 'panel_basic',
    children: <WindowType>[],
    displayIndex: 4,
    codeName: 'PS4_win',
  );
  const WindowType ef3Node = WindowType(
    label: 'Equal Panel',
    graphicKey: 'panel_basic',
    children: <WindowType>[],
    displayIndex: 5,
    codeName: 'EF3_win',
  );
  const WindowType es3Node = WindowType(
    label: 'Sliding Equal Panel',
    graphicKey: 'panel_basic',
    children: <WindowType>[],
    displayIndex: 6,
    codeName: 'ES3_win',
  );
  const WindowType mpf3Node = WindowType(
    label: 'Center Fix',
    graphicKey: 'panel_basic',
    children: <WindowType>[],
    displayIndex: 7,
    codeName: 'MPF3_win',
  );
  const WindowType mps4Node = WindowType(
    label: 'Center Slide',
    graphicKey: 'panel_basic',
    children: <WindowType>[],
    displayIndex: 8,
    codeName: 'MPS4_win',
  );
  const WindowType mef3Node = WindowType(
    label: 'Equal Panel',
    graphicKey: 'panel_basic',
    children: <WindowType>[],
    displayIndex: 9,
    codeName: 'MEF3_win',
  );
  const WindowType mes3Node = WindowType(
    label: 'Sliding Equal Panel',
    graphicKey: 'panel_basic',
    children: <WindowType>[],
    displayIndex: 10,
    codeName: 'MES3_win',
  );
  const WindowType scfNode = WindowType(
    label: 'Sliding Corner Center Fix',
    graphicKey: 'corner_basic',
    children: <WindowType>[],
    displayIndex: 11,
    codeName: 'SCF_win',
  );
  const WindowType scsNode = WindowType(
    label: 'Sliding Corner Center Slide',
    graphicKey: 'corner_basic',
    children: <WindowType>[],
    displayIndex: 12,
    codeName: 'SCS_win',
  );
  const WindowType sclNode = WindowType(
    label: 'Sliding Corner Left Fix',
    graphicKey: 'corner_basic',
    children: <WindowType>[],
    displayIndex: 13,
    codeName: 'SCL_win',
  );
  const WindowType scrNode = WindowType(
    label: 'Sliding Corner Right Fix',
    graphicKey: 'corner_basic',
    children: <WindowType>[],
    displayIndex: 14,
    codeName: 'SCR_win',
  );
  const WindowType mscfNode = WindowType(
    label: 'Sliding Corner Center Fix (M_Section)',
    graphicKey: 'corner_basic',
    children: <WindowType>[],
    displayIndex: 15,
    codeName: 'MSCF_win',
  );
  const WindowType fixNode = WindowType(
    label: 'Fix Window',
    graphicKey: 'fix_basic',
    children: <WindowType>[],
    displayIndex: 19,
    codeName: 'F_win',
  );
  const WindowType cornerFixNode = WindowType(
    label: 'Corner Fix',
    graphicKey: 'fix_basic',
    children: <WindowType>[],
    displayIndex: 20,
    codeName: 'FC_win',
  );
  const WindowType openableNode = WindowType(
    label: 'Openable',
    graphicKey: 'fix_basic',
    children: <WindowType>[],
    displayIndex: 21,
    codeName: 'O_win',
  );
  const WindowType singleDoorNode = WindowType(
    label: 'Single Door',
    graphicKey: 'door_basic',
    children: <WindowType>[],
    displayIndex: 22,
    codeName: 'Single_Door',
  );
  const WindowType doubleDoorNode = WindowType(
    label: 'Double Door',
    graphicKey: 'door_basic',
    children: <WindowType>[],
    displayIndex: 23,
    codeName: 'Double_Door',
  );
  const WindowType roundArchNode = WindowType(
    label: 'Round Arch',
    graphicKey: 'door_basic',
    children: <WindowType>[],
    displayIndex: 24,
    codeName: 'A_win',
  );
  const WindowType rectArchNode = WindowType(
    label: 'Rectangle',
    graphicKey: 'door_basic',
    children: <WindowType>[],
    displayIndex: 25,
    codeName: 'AR_win',
  );

  test('MS_win collar 1 sections include M-codes and exclude D29', () {
    final WindowInputHandler handler = handlerForWindow(mSectionNode);
    final List<String> collar1 = handler.sectionsForCollar(1);

    expect(collar1, contains('M30F'));
    expect(collar1, contains('M26F'));
    expect(collar1, isNot(contains('D29')));
  });

  test('MS_win collar 2 sections include M30 and M26', () {
    final WindowInputHandler handler = handlerForWindow(mSectionNode);
    final List<String> collar2 = handler.sectionsForCollar(2);

    expect(collar2, contains('M30'));
    expect(collar2, contains('M26'));
    expect(collar2, isNot(contains('D29')));
  });

  test('MS_win collar 13 sections include M30 and M26F', () {
    final WindowInputHandler handler = handlerForWindow(mSectionNode);
    final List<String> collar13 = handler.sectionsForCollar(13);

    expect(collar13, contains('M30'));
    expect(collar13, contains('M26F'));
    expect(collar13, isNot(contains('D29')));
  });

  test('PF3_win routes to PanelCenterFixInputHandler', () {
    final WindowInputHandler handler = handlerForWindow(pf3Node);
    expect(handler, isA<PanelCenterFixInputHandler>());
  });

  test('PF3_win section matrix matches S_win collar patterns', () {
    final WindowInputHandler handler = handlerForWindow(pf3Node);
    final List<String> collar1 = handler.sectionsForCollar(1);
    final List<String> collar2 = handler.sectionsForCollar(2);
    final List<String> collar3 = handler.sectionsForCollar(3);
    final List<String> collar5 = handler.sectionsForCollar(5);

    expect(collar1, const <String>[
      'DC30F',
      'DC26F',
      'D29',
      'M23',
      'M24',
      'M28',
    ]);
    expect(collar2, containsAll(<String>['DC30C', 'DC26C', 'D29', 'M23', 'M24', 'M28']));
    expect(collar2, isNot(contains('DC30F')));
    expect(collar2, isNot(contains('DC26F')));
    expect(collar3, containsAll(<String>['DC30F', 'DC30C', 'DC26F', 'D29', 'M23', 'M24', 'M28']));
    expect(collar5, containsAll(<String>['DC30F', 'DC26C', 'D29', 'M23', 'M24', 'M28']));
    expect(collar5, isNot(contains('DC26F')));
  });

  test('PF3_win aliases match S_win parity', () {
    final WindowInputHandler handler = handlerForWindow(pf3Node);

    expect(
      handler.aliasesForCollar(2),
      const <String, String>{'DC30F': 'DC30C', 'DC26F': 'DC26C'},
    );
    expect(
      handler.aliasesForCollar(5),
      const <String, String>{'DC26F': 'DC26C'},
    );
    expect(
      handler.aliasesForCollar(8),
      const <String, String>{'DC26F': 'DC26C'},
    );
    expect(handler.aliasesForCollar(3), isEmpty);
  });

  test('PF3_win drawer enabled for collars 1..14', () {
    final WindowInputHandler handler = handlerForWindow(pf3Node);

    for (int i = 1; i <= 14; i++) {
      expect(handler.showDrawerForCollar(i), isTrue);
    }
    expect(handler.showDrawerForCollar(15), isFalse);
  });

  test('PS4_win routes to PanelCenterSlideInputHandler', () {
    final WindowInputHandler handler = handlerForWindow(ps4Node);
    expect(handler, isA<PanelCenterSlideInputHandler>());
  });

  test('PS4_win collar 2 includes DC30C/DC26C and excludes D29 aliases as base', () {
    final WindowInputHandler handler = handlerForWindow(ps4Node);
    final List<String> collar2 = handler.sectionsForCollar(2);

    expect(collar2, containsAll(<String>['DC30C', 'DC26C', 'D29', 'M23', 'M24', 'M28']));
    expect(collar2, isNot(contains('DC30F')));
    expect(collar2, isNot(contains('DC26F')));
  });

  test('EF3_win routes to PanelEqualInputHandler', () {
    final WindowInputHandler handler = handlerForWindow(ef3Node);
    expect(handler, isA<PanelEqualInputHandler>());
  });

  test('EF3_win reuses PF3 collar section matrix', () {
    final WindowInputHandler handler = handlerForWindow(ef3Node);
    expect(
      handler.sectionsForCollar(1),
      const <String>['DC30F', 'DC26F', 'D29', 'M23', 'M24', 'M28'],
    );
    expect(
      handler.sectionsForCollar(2),
      containsAll(<String>['DC30C', 'DC26C', 'D29', 'M23', 'M24', 'M28']),
    );
    expect(
      handler.aliasesForCollar(2),
      const <String, String>{'DC30F': 'DC30C', 'DC26F': 'DC26C'},
    );
  });

  test('ES3_win routes to PanelSlidingEqualInputHandler', () {
    final WindowInputHandler handler = handlerForWindow(es3Node);
    expect(handler, isA<PanelSlidingEqualInputHandler>());
  });

  test('ES3_win sections match EF3 minus M28', () {
    final WindowInputHandler handler = handlerForWindow(es3Node);
    final List<String> collar1 = handler.sectionsForCollar(1);
    final List<String> collar2 = handler.sectionsForCollar(2);

    expect(collar1, isNot(contains('M28')));
    expect(collar2, isNot(contains('M28')));
    expect(collar1, containsAll(<String>['DC30F', 'DC26F', 'D29', 'M23', 'M24']));
    expect(collar2, containsAll(<String>['DC30C', 'DC26C', 'D29', 'M23', 'M24']));
  });

  test('MPF3/MPS4/MEF3/MES3 route to dedicated M handlers', () {
    expect(handlerForWindow(mpf3Node), isA<PanelMCenterFixInputHandler>());
    expect(handlerForWindow(mps4Node), isA<PanelMCenterSlideInputHandler>());
    expect(handlerForWindow(mef3Node), isA<PanelMEqualInputHandler>());
    expect(handlerForWindow(mes3Node), isA<PanelMSlidingEqualInputHandler>());
  });

  test('M panel handlers rename DC codes, remove D29, and keep collar matrix parity', () {
    final WindowInputHandler mpf3 = handlerForWindow(mpf3Node);
    final WindowInputHandler mes3 = handlerForWindow(mes3Node);

    final List<String> mpf3C1 = mpf3.sectionsForCollar(1);
    final List<String> mpf3C2 = mpf3.sectionsForCollar(2);
    final List<String> mes3C1 = mes3.sectionsForCollar(1);

    expect(mpf3C1, containsAll(<String>['M30F', 'M26F', 'M23', 'M24', 'M28']));
    expect(mpf3C1, isNot(contains('D29')));
    expect(mpf3C2, containsAll(<String>['M30', 'M26', 'M23', 'M24', 'M28']));
    expect(mpf3C2, isNot(contains('D29')));

    expect(
      mpf3.aliasesForCollar(2),
      const <String, String>{'DC30C': 'M30', 'DC26C': 'M26'},
    );

    expect(mes3C1, containsAll(<String>['M30F', 'M26F', 'M23', 'M24']));
    expect(mes3C1, isNot(contains('M28')));
    expect(mes3C1, isNot(contains('D29')));
  });

  test('SCF_win routes to SlidingCornerCenterFixInputHandler', () {
    final WindowInputHandler handler = handlerForWindow(scfNode);
    expect(handler, isA<SlidingCornerCenterFixInputHandler>());
    expect(handler.collarCount, 2);
    expect(handler.overlayForCollar(1, null), isNotNull);
    expect(handler.overlayForCollar(2, null), isNotNull);
    expect(handler.overlayForCollar(3, null), isNull);
  });

  test('MSCF_win routes to SlidingCornerMSectionInputHandler', () {
    final WindowInputHandler handler = handlerForWindow(mscfNode);
    expect(handler, isA<SlidingCornerMSectionInputHandler>());
    expect(handler.collarCount, 2);
    expect(handler.usesSplitWidthInputs, isTrue);
    expect(handler.sectionsForCollar(1), containsAll(<String>['M30F', 'M26F', 'M23', 'M28', 'M24']));
    expect(handler.sectionsForCollar(1), isNot(contains('D29')));
    expect(handler.sectionsForCollar(2), containsAll(<String>['M30', 'M26', 'M23', 'M28', 'M24']));
    expect(handler.sectionsForCollar(2), isNot(contains('D29')));
    expect(handler.overlayForCollar(1, null), isNotNull);
    expect(handler.overlayForCollar(2, null), isNotNull);
    expect(handler.overlayForCollar(3, null), isNull);
  });

  test('SCS_win routes to SlidingCornerCenterFixInputHandler', () {
    final WindowInputHandler handler = handlerForWindow(scsNode);
    expect(handler, isA<SlidingCornerCenterFixInputHandler>());
    expect(handler.collarCount, 2);
    expect(handler.overlayForCollar(1, null), isNotNull);
    expect(handler.overlayForCollar(2, null), isNotNull);
    expect(handler.overlayForCollar(3, null), isNull);
  });

  test('SCL_win routes to SlidingCornerCenterFixInputHandler', () {
    final WindowInputHandler handler = handlerForWindow(sclNode);
    expect(handler, isA<SlidingCornerCenterFixInputHandler>());
    expect(handler.collarCount, 2);
    expect(handler.overlayForCollar(1, null), isNotNull);
    expect(handler.overlayForCollar(2, null), isNotNull);
    expect(handler.overlayForCollar(3, null), isNull);
  });

  test('SCR_win routes to SlidingCornerCenterFixInputHandler', () {
    final WindowInputHandler handler = handlerForWindow(scrNode);
    expect(handler, isA<SlidingCornerCenterFixInputHandler>());
    expect(handler.collarCount, 2);
    expect(handler.overlayForCollar(1, null), isNotNull);
    expect(handler.overlayForCollar(2, null), isNotNull);
    expect(handler.overlayForCollar(3, null), isNull);
  });

  test('F_win routes to FixWindowInputHandler and supports collar overlays', () {
    final WindowInputHandler handler = handlerForWindow(fixNode);
    expect(handler, isA<FixWindowInputHandler>());
    expect(handler.collarCount, 14);
    expect(handler.sectionsForCollar(1), const <String>['D41', 'D54F']);
    expect(handler.sectionsForCollar(2), const <String>['D41', 'D54A']);
    expect(handler.sectionsForCollar(14), const <String>['D41', 'D54F', 'D54A']);
    expect(handler.overlayForCollar(1, null), isNotNull);
    expect(handler.overlayForCollar(2, null), isNotNull);
    expect(handler.overlayForCollar(14, null), isNotNull);
    expect(handler.overlayForCollar(15, null), isNull);
  });

  test('FC_win routes to CornerFixInputHandler and limits collars to 2', () {
    final WindowInputHandler handler = handlerForWindow(cornerFixNode);
    expect(handler, isA<CornerFixInputHandler>());
    expect(handler.collarCount, 2);
    expect(handler.usesSplitWidthInputs, isTrue);
    expect(handler.overlayForCollar(1, null), isNotNull);
    expect(handler.overlayForCollar(2, null), isNotNull);
    expect(handler.overlayForCollar(3, null), isNull);
  });

  test('O_win copies F_win section system with D50A replacing D41', () {
    final WindowInputHandler handler = handlerForWindow(openableNode);
    expect(handler, isA<OpenableInputHandler>());
    expect(handler.collarCount, 14);
    expect(
      handler.sectionsForCollar(1),
      const <String>['D50A', 'D54F', 'D54A'],
    );
    expect(handler.sectionsForCollar(2), const <String>['D50A', 'D54A']);
    expect(
      handler.sectionsForCollar(14),
      const <String>['D50A', 'D54F', 'D54A'],
    );
    expect(handler.overlayForCollar(1, null), isNotNull);
    expect(handler.overlayForCollar(14, null), isNotNull);
    expect(handler.overlayForCollar(15, null), isNull);
  });

  test('O_win adds D29 when net is enabled', () {
    final OpenableInputHandler handler =
        handlerForWindow(openableNode) as OpenableInputHandler;

    handler.netEnabled = true;

    expect(
      handler.sectionsForCollar(1),
      const <String>['D50A', 'D29', 'D54F', 'D54A'],
    );
    expect(
      handler.sectionsForCollar(2),
      const <String>['D50A', 'D29', 'D54A'],
    );
  });

  test('Single_Door routes to DoorSingleInputHandler and supports collar overlays', () {
    final WindowInputHandler handler = handlerForWindow(singleDoorNode);
    expect(handler, isA<DoorSingleInputHandler>());
    expect(handler.collarCount, 8);
    expect(handler.sectionsForCollar(1), const <String>['D50', 'D54F']);
    expect(handler.sectionsForCollar(2), const <String>['D50', 'D54A']);
    expect(handler.sectionsForCollar(8), const <String>['D50', 'D54F', 'D54A']);
    expect(handler.overlayForCollar(1, null), isNotNull);
    expect(handler.overlayForCollar(2, null), isNotNull);
    expect(handler.overlayForCollar(8, null), isNotNull);
    expect(handler.overlayForCollar(9, null), isNull);
    expect(handler.overlayForCollar(15, null), isNull);
  });

  test('Single_Door adds D46 when the toggle is enabled', () {
    final DoorSingleInputHandler handler =
        handlerForWindow(singleDoorNode) as DoorSingleInputHandler;

    handler.d46Enabled = true;

    expect(handler.sectionsForCollar(1), const <String>['D50', 'D46', 'D54F']);
    expect(handler.sectionsForCollar(2), const <String>['D50', 'D46', 'D54A']);
    expect(
      handler.sectionsForCollar(8),
      const <String>['D50', 'D46', 'D54F', 'D54A'],
    );
  });

  test('Single_Door adds D52 when the toggle is enabled', () {
    final DoorSingleInputHandler handler =
        handlerForWindow(singleDoorNode) as DoorSingleInputHandler;

    handler.d52Enabled = true;

    expect(handler.sectionsForCollar(1), const <String>['D50', 'D52', 'D54F']);
    expect(handler.sectionsForCollar(2), const <String>['D50', 'D52', 'D54A']);
    expect(
      handler.sectionsForCollar(8),
      const <String>['D50', 'D52', 'D54F', 'D54A'],
    );
  });

  test('Single_Door inserts D52 after D46 when both toggles are enabled', () {
    final DoorSingleInputHandler handler =
        handlerForWindow(singleDoorNode) as DoorSingleInputHandler;

    handler.d46Enabled = true;
    handler.d52Enabled = true;

    expect(
      handler.sectionsForCollar(1),
      const <String>['D50', 'D46', 'D52', 'D54F'],
    );
    expect(
      handler.sectionsForCollar(2),
      const <String>['D50', 'D46', 'D52', 'D54A'],
    );
  });

  test('Double_Door copies Single_Door section system and collar limit', () {
    final WindowInputHandler handler = handlerForWindow(doubleDoorNode);

    expect(handler, isA<DoorDoubleInputHandler>());
    expect(handler.collarCount, 8);
    expect(handler.sectionsForCollar(1), const <String>['D50', 'D54F']);
    expect(handler.sectionsForCollar(2), const <String>['D50', 'D54A']);
    expect(handler.sectionsForCollar(8), const <String>['D50', 'D54F', 'D54A']);
    expect(handler.overlayForCollar(1, null), isNotNull);
    expect(handler.overlayForCollar(8, null), isNotNull);
    expect(handler.overlayForCollar(9, null), isNull);
  });

  test('Double_Door adds D46 and D52 using the same toggles', () {
    final DoorDoubleInputHandler handler =
        handlerForWindow(doubleDoorNode) as DoorDoubleInputHandler;

    handler.d46Enabled = true;
    handler.d52Enabled = true;

    expect(
      handler.sectionsForCollar(1),
      const <String>['D50', 'D46', 'D52', 'D54F'],
    );
    expect(
      handler.sectionsForCollar(2),
      const <String>['D50', 'D46', 'D52', 'D54A'],
    );
  });

  test('A_win routes to ArchRoundInputHandler and draws on collars 1 and 2', () {
    final WindowInputHandler handler = handlerForWindow(roundArchNode);

    expect(handler, isA<ArchRoundInputHandler>());
    expect(handler.collarCount, 2);
    expect(handler.sectionsForCollar(1), const <String>['D41', 'D51A', 'D51F']);
    expect(handler.sectionsForCollar(2), const <String>['D41', 'D51A']);
    expect(handler.overlayForCollar(1, null), isNotNull);
    expect(handler.overlayForCollar(2, null), isNotNull);
    expect(handler.overlayForCollar(3, null), isNull);
  });

  test('AR_win routes to ArchRectInputHandler and limits collars to 8', () {
    final WindowInputHandler handler = handlerForWindow(rectArchNode);

    expect(handler, isA<ArchRectInputHandler>());
    expect(handler.collarCount, 8);
    expect(handler.sectionsForCollar(1), const <String>['D41', 'D51F', 'D51A']);
    expect(handler.sectionsForCollar(2), const <String>['D41', 'D51A']);
    expect(handler.sectionsForCollar(8), const <String>['D41', 'D51F', 'D51A']);
    expect(handler.overlayForCollar(1, null), isNotNull);
    expect(handler.overlayForCollar(2, null), isNotNull);
    expect(handler.overlayForCollar(8, null), isNotNull);
    expect(handler.overlayForCollar(9, null), isNull);
  });
}
