import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/models/window_type.dart';
import 'package:my_app/features/estimation/presentation/input/window_input_base.dart';
import 'package:my_app/features/estimation/state/estimate_session_store.dart';
import 'package:my_app/features/settings/state/app_settings.dart';
import 'package:my_app/features/settings/state/size_input_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A round arch takes a third size, and it has to save in every unit.
///
/// The arch box is drawn the same way as the width and height boxes, but it
/// used to be checked on save by the old `45.7` rule -- so in the one-box
/// entry every shop uses, an arch like 34'' 4''' was refused and the window
/// could not be saved at all.
void main() {
  const WindowType roundArch = WindowType(
    label: 'Round Arch',
    graphicKey: 'arch_basic',
    children: <WindowType>[],
    displayIndex: 22,
    codeName: 'A_win',
  );

  Finder fieldByLabel(String label) => find.byWidgetPredicate(
    (Widget widget) =>
        widget is TextField && widget.decoration?.labelText == label,
  );

  Future<EstimateSessionStore> open(WidgetTester tester) async {
    final EstimateSessionStore session = EstimateSessionStore(
      projectName: 'Arch Test',
      projectLocation: 'Lahore',
    );
    await tester.pumpWidget(
      MaterialApp(home: WindowInputScreen(node: roundArch, session: session)),
    );
    await tester.pumpAndSettle();
    return session;
  }

  Future<void> chooseUnit(WidgetTester tester, String key) async {
    final Finder radio = find.byKey(Key(key));
    await tester.ensureVisible(radio);
    await tester.tap(radio);
    await tester.pumpAndSettle();
  }

  Future<void> fill(
    WidgetTester tester, {
    required String width,
    required String height,
    required String arch,
  }) async {
    await tester.enterText(fieldByLabel('Width'), width);
    await tester.enterText(fieldByLabel('Height'), height);
    final Finder archBox = fieldByLabel('Arch');
    await tester.ensureVisible(archBox);
    await tester.enterText(archBox, arch);
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    final Finder button = find.byKey(const Key('input_save_button'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppSettings.instance.setSizeInputMode(SizeInputMode.mergedKeypad);
  });

  testWidgets('in inches, an arch typed in the one box saves', (
    WidgetTester tester,
  ) async {
    final EstimateSessionStore session = await open(tester);
    await fill(tester, width: '36 4', height: '48 2', arch: '12 4');
    expect(find.text("12'' 4'''"), findsOneWidget);

    await save(tester);

    expect(session.items, hasLength(1), reason: 'the window is saved');
    expect(session.items.single.archValue, '12.4');
  });

  testWidgets('in inches, an arch on a half suter saves', (
    WidgetTester tester,
  ) async {
    final EstimateSessionStore session = await open(tester);
    await fill(tester, width: '36 4', height: '48 2', arch: '12 4.');

    await save(tester);

    expect(session.items, hasLength(1));
    expect(session.items.single.archValue, '12.45');
  });

  testWidgets('in feet, an arch typed in the one box saves', (
    WidgetTester tester,
  ) async {
    final EstimateSessionStore session = await open(tester);
    await chooseUnit(tester, 'unit_feet_radio');
    await fill(tester, width: '3 4', height: '4 2', arch: '1 6');
    expect(find.text("1' 6''"), findsOneWidget);

    await save(tester);

    expect(session.items, hasLength(1));
    expect(session.items.single.archValue, '1.6');
  });

  testWidgets('in cm, an arch saves', (WidgetTester tester) async {
    final EstimateSessionStore session = await open(tester);
    await chooseUnit(tester, 'unit_cm_radio');
    await fill(tester, width: '92.5', height: '122', arch: '31.5');

    await save(tester);

    expect(session.items, hasLength(1));
    expect(session.items.single.archValue, '31.5');
  });

  testWidgets('an empty arch is still refused', (WidgetTester tester) async {
    final EstimateSessionStore session = await open(tester);
    await fill(tester, width: '36 4', height: '48 2', arch: '');

    await save(tester);

    expect(session.items, isEmpty, reason: 'a round arch needs its arch');
  });
}
