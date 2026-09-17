import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/formulas/data/formula_catalogue.dart';
import 'package:my_app/features/formulas/data/formula_catalogue_asset.dart';
import 'package:my_app/features/estimation/models/window_review_item.dart';
import 'package:my_app/features/estimation/models/window_type.dart';
import 'package:my_app/features/estimation/presentation/input/window_input_base.dart';
import 'package:my_app/features/estimation/state/estimate_session_store.dart';
import 'package:my_app/features/formulas/model/window_sides.dart';
import 'package:my_app/features/settings/state/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Measuring a window one side at a time, on the screen it is measured on.
void main() {
  const WindowType sliding = WindowType(
    label: 'Sliding Window',
    graphicKey: 'sliding_basic',
    children: <WindowType>[],
    displayIndex: 1,
    codeName: 'S_win',
  );

  const WindowType door = WindowType(
    label: 'Single Door',
    graphicKey: 'door_single',
    children: <WindowType>[],
    displayIndex: 21,
    codeName: 'Single_Door',
  );

  late EstimateSessionStore session;

  setUpAll(() {
    // The screen reads the catalogue for the sides a window's frame has.
    // Reading an asset inside a widget test never finishes, so it is read from
    // disk once and handed in.
    FormulaCatalogueAsset.preload(
      FormulaCatalogue.fromJson(
        jsonDecode(File('assets/formulas/catalogue.json').readAsStringSync())
            as Map<String, dynamic>,
      ),
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppSettings.instance.resetForTest();
    session = EstimateSessionStore(
      projectName: 'Test Project',
      projectLocation: 'Test Location',
      flow: EstimateFlow.fabrication,
    );
  });

  tearDown(AppSettings.instance.resetForTest);

  Future<void> open(
    WidgetTester tester, {
    WindowType node = sliding,
    WindowReviewItem? editing,
  }) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: WindowInputScreen(
          node: node,
          session: session,
          editingItem: editing,
        ),
      ),
    );
    // The catalogue is read once, for the sides this window's frame has.
    await tester.pumpAndSettle();
  }

  Finder sideField(String side) => find.byKey(Key('side_field_$side'));

  Future<void> turnOnSides(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('per_side_toggle')));
    await tester.tap(find.byKey(const Key('per_side_toggle')));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    final Finder button = find.byKey(const Key('input_save_button'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('is off until it is turned on, and then the window has sides',
      (WidgetTester tester) async {
    await open(tester);

    // The plain pair, as every window has always had.
    expect(find.byKey(const Key('per_side_toggle')), findsOneWidget);
    expect(sideField(WindowSide.top), findsNothing);

    await turnOnSides(tester);

    // A sliding window has four sides, laid out as they sit on the window.
    expect(sideField(WindowSide.top), findsOneWidget);
    expect(sideField(WindowSide.bottom), findsOneWidget);
    expect(sideField(WindowSide.left), findsOneWidget);
    expect(sideField(WindowSide.right), findsOneWidget);

    final Rect top = tester.getRect(sideField(WindowSide.top));
    final Rect left = tester.getRect(sideField(WindowSide.left));
    final Rect right = tester.getRect(sideField(WindowSide.right));
    final Rect bottom = tester.getRect(sideField(WindowSide.bottom));
    expect(top.bottom, lessThanOrEqualTo(left.top));
    expect(left.right, lessThanOrEqualTo(right.left));
    expect(left.bottom, lessThanOrEqualTo(bottom.top));
  });

  testWidgets('a door has three sides, and says why', (WidgetTester tester) async {
    await open(tester, node: door);
    await turnOnSides(tester);

    expect(sideField(WindowSide.top), findsOneWidget);
    expect(sideField(WindowSide.left), findsOneWidget);
    expect(sideField(WindowSide.right), findsOneWidget);
    expect(sideField(WindowSide.bottom), findsNothing);
    expect(find.text('A door has no bottom frame.'), findsOneWidget);
  });

  testWidgets('an empty side says which side it will be taken from',
      (WidgetTester tester) async {
    await open(tester);
    await turnOnSides(tester);

    await tester.enterText(sideField(WindowSide.top), '44.5');
    await tester.pumpAndSettle();

    // Under the box, where it can be read: an empty box shows its own name
    // where a hint would go.
    final TextField bottom = tester.widget<TextField>(sideField(WindowSide.bottom));
    expect(bottom.decoration?.helperText, 'same as top');
    expect(find.text('same as top'), findsOneWidget);

    final TextField right = tester.widget<TextField>(sideField(WindowSide.right));
    expect(right.decoration?.helperText, isNull,
        reason: 'the left is still empty, so the right has nothing to take');
  });

  testWidgets('the sides are saved, and the window is the smaller of each pair',
      (WidgetTester tester) async {
    await open(tester);
    await turnOnSides(tester);

    await tester.enterText(sideField(WindowSide.top), '44.5');
    await tester.enterText(sideField(WindowSide.bottom), '46');
    await tester.enterText(sideField(WindowSide.left), '54.5');
    await tester.pumpAndSettle();
    await save(tester);

    expect(session.items, hasLength(1));
    final WindowReviewItem saved = session.items.single;
    expect(saved.sideSizes.raw(WindowSide.top), '44.5');
    // Stored the way every other size on this window is: a whole number keeps
    // its point, so "46" and "46.0" cannot read as two different sizes.
    expect(saved.sideSizes.raw(WindowSide.bottom), '46.0');
    expect(saved.sideSizes.raw(WindowSide.left), '54.5');
    expect(saved.sideSizes.raw(WindowSide.right), '',
        reason: 'what was left empty is left empty');
    expect(saved.sideSizes.effective(WindowSide.right), '54.5');

    // What the glass and everything inside the frame is cut to, and what every
    // screen after this reads as the window's size.
    expect(saved.widthValue, '44.5');
    expect(saved.heightValue, '54.5');
  });

  testWidgets('a pair left empty altogether will not save',
      (WidgetTester tester) async {
    await open(tester);
    await turnOnSides(tester);

    await tester.enterText(sideField(WindowSide.top), '44.5');
    await tester.pumpAndSettle();
    await save(tester);

    expect(session.items, isEmpty, reason: 'no height was measured at all');
    expect(find.text('Required'), findsWidgets);
  });

  testWidgets('turning it off keeps the smaller of what was measured',
      (WidgetTester tester) async {
    await open(tester);
    await turnOnSides(tester);

    await tester.enterText(sideField(WindowSide.top), '44.5');
    await tester.enterText(sideField(WindowSide.bottom), '46');
    await tester.enterText(sideField(WindowSide.left), '54.5');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('per_side_toggle')));
    await tester.pumpAndSettle();

    expect(sideField(WindowSide.top), findsNothing);
    await save(tester);

    final WindowReviewItem saved = session.items.single;
    expect(saved.sideSizes.isEmpty, isTrue);
    expect(saved.widthValue, '44.5');
    expect(saved.heightValue, '54.5');
  });

  testWidgets('a window already measured side by side opens that way',
      (WidgetTester tester) async {
    final WindowReviewItem measured = WindowReviewItem(
      winNo: 1,
      windowLabel: 'Sliding Window',
      windowCode: 'S_win',
      windowIndex: 1,
      collarIndex: 1,
      unitMode: UnitMode.feet,
      heightValue: '54.5',
      widthValue: '44.5',
      sideSizes: const SideSizes(<String, String>{
        'WT': '44.5',
        'WB': '46',
        'HL': '54.5',
      }),
    );
    session.replaceItems(<WindowReviewItem>[measured]);

    await open(tester, editing: measured);

    expect(sideField(WindowSide.top), findsOneWidget);
    expect(
      tester.widget<TextField>(sideField(WindowSide.bottom)).controller?.text,
      '46',
    );
  });

  testWidgets('Settings decides what a new window opens on',
      (WidgetTester tester) async {
    await AppSettings.instance.setPerSideSizes(true);
    await open(tester);

    expect(sideField(WindowSide.top), findsOneWidget,
        reason: 'the shop asked for every side in Settings');
  });
}
