import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/data/window_catalog.dart';
import 'package:my_app/features/estimation/models/collar_layout.dart';
import 'package:my_app/features/estimation/models/window_type.dart';
import 'package:my_app/features/estimation/presentation/input/window_input_base.dart';
import 'package:my_app/features/estimation/state/estimate_session_store.dart';
import 'package:my_app/features/estimation/widgets/collar_side_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/collar_taps.dart';

/// The collar is chosen on one drawing of the window: tap a side and its
/// collar comes off (a single light red line), tap it again and it is back
/// (the double line). No more swiping through fourteen cards.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  List<WindowType> leaves(List<WindowType> nodes) => <WindowType>[
    for (final WindowType node in nodes)
      if (node.children.isEmpty) node else ...leaves(node.children),
  ];
  final List<WindowType> windows = leaves(WindowCatalog.root);
  WindowType window(String code) =>
      windows.firstWhere((WindowType node) => node.codeName == code);

  late EstimateSessionStore session;

  Future<void> open(WidgetTester tester, String code) async {
    session = EstimateSessionStore(
      projectName: 'Test Project',
      projectLocation: 'Test Location',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: WindowInputScreen(node: window(code), session: session),
      ),
    );
    await tester.pumpAndSettle();
  }

  CollarSidePicker picker(WidgetTester tester) =>
      tester.widget<CollarSidePicker>(find.byType(CollarSidePicker));

  /// The collar the drawing itself is painted for -- every collar drawing
  /// carries it as `collarId`.
  int drawnCollar(WidgetTester tester) =>
      (picker(tester).drawing! as dynamic).collarId as int;

  void expectCollar(WidgetTester tester, int collar, {String? reason}) {
    expect(shownCollar(tester), collar, reason: reason);
    expect(picker(tester).collar, collar, reason: reason);
    expect(drawnCollar(tester), collar, reason: 'the drawing follows: $reason');
  }

  final Finder refusal = find.byType(SnackBar);

  testWidgets('opens on collar 1 with one drawing and a hint', (
    WidgetTester tester,
  ) async {
    await open(tester, 'S_win');
    expectCollar(tester, 1);
    expect(find.byType(CollarSidePicker), findsOneWidget);
    expect(find.byKey(const Key('collar_hint')), findsOneWidget);
    expect(find.byType(PageView), findsNothing, reason: 'no more cards to swipe');
  });

  testWidgets('tapping a side takes its collar off, tapping again puts it back', (
    WidgetTester tester,
  ) async {
    await open(tester, 'S_win');

    await tapCollarSide(tester, CollarSide.top);
    expectCollar(tester, 3, reason: 'bottom, left and right');

    await tapCollarSide(tester, CollarSide.top);
    expectCollar(tester, 1, reason: 'all four again');
  });

  testWidgets('sides come off one after another', (WidgetTester tester) async {
    await open(tester, 'S_win');

    await tapCollarSide(tester, CollarSide.bottom);
    expectCollar(tester, 5, reason: 'top, left and right');
    await tapCollarSide(tester, CollarSide.right);
    expectCollar(tester, 8, reason: 'top and left');
    await tapCollarSide(tester, CollarSide.left);
    expectCollar(tester, 11, reason: 'top only');
    await tapCollarSide(tester, CollarSide.top);
    expectCollar(tester, 2, reason: 'none');
    await tapCollarSide(tester, CollarSide.left);
    expectCollar(tester, 14, reason: 'left only');
  });

  testWidgets('a collar the engine does not have is refused, not guessed', (
    WidgetTester tester,
  ) async {
    await open(tester, 'S_win');
    await tapCollarSide(tester, CollarSide.bottom);
    expectCollar(tester, 5);

    // Top and right only: there is no such collar.
    await tapCollarSide(tester, CollarSide.left);
    expectCollar(tester, 5, reason: 'unchanged');
    expect(refusal, findsOneWidget);
    expect(find.textContaining('top and right'), findsOneWidget);
  });

  testWidgets('high up on a door side is still that side, not the top', (
    WidgetTester tester,
  ) async {
    // A door stands narrow in the middle of its card. Near the top of its
    // left side, the card's top edge is closer than the card's left edge --
    // but the finger is on the left line, and the left is what comes off.
    await open(tester, 'Single_Door');
    await tapCollarSide(tester, CollarSide.left, along: 0.1);
    expectCollar(tester, 3, reason: 'door 3 is top and right');

    await tapCollarSide(tester, CollarSide.left, along: 0.9);
    expectCollar(tester, 1, reason: 'low down on the same line puts it back');

    await tapCollarSide(tester, CollarSide.right, along: 0.1);
    expectCollar(tester, 5, reason: 'door 5 is top and left');
  });

  testWidgets('the bottom of a door has no collar to take off', (
    WidgetTester tester,
  ) async {
    await open(tester, 'Single_Door');
    await tapCollarSide(tester, CollarSide.bottom);
    expectCollar(tester, 1, reason: 'unchanged');
    expect(find.textContaining('bottom of this window never has a collar'),
        findsOneWidget);
  });

  testWidgets('the rectangle arch collars top, left and right', (
    WidgetTester tester,
  ) async {
    await open(tester, 'AR_win');
    await tapCollarSide(tester, CollarSide.top);
    expectCollar(tester, 4, reason: 'arch 4 is left and right');
    await tapCollarSide(tester, CollarSide.left);
    expectCollar(tester, 8, reason: 'arch 8 is right only');
  });

  testWidgets('a corner window switches the whole frame', (
    WidgetTester tester,
  ) async {
    await open(tester, 'SCF_win');
    await tapCollarSide(tester, CollarSide.left);
    expectCollar(tester, 2);
    await tapCollarSide(tester, CollarSide.bottom);
    expectCollar(tester, 1);
    expect(refusal, findsNothing);
  });

  testWidgets('a tap on the number badge is a tap on the top', (
    WidgetTester tester,
  ) async {
    // The badge rides over the card's top edge; where it covers the card, a
    // tap has to go through it to the top side rather than stop on it.
    await open(tester, 'S_win');
    final Rect badge = tester.getRect(find.text('Collar 1'));
    final Rect box = tester.getRect(collarPicker);
    expect(badge.bottom, greaterThan(box.top), reason: 'the badge overlaps the card');
    await tester.tapAt(Offset(badge.center.dx, (box.top + badge.bottom) / 2));
    await tester.pumpAndSettle();
    expectCollar(tester, 3);
  });

  testWidgets('a tap outside the drawing changes nothing', (
    WidgetTester tester,
  ) async {
    await open(tester, 'S_win');
    final Rect box = tester.getRect(collarPicker);
    await tester.tapAt(Offset(box.right + 4, box.center.dy));
    await tester.tapAt(Offset(box.center.dx, box.bottom + 40));
    await tester.pumpAndSettle();
    expectCollar(tester, 1);
  });

  testWidgets('the chosen collar is the one saved with the window', (
    WidgetTester tester,
  ) async {
    await open(tester, 'S_win');
    await tapCollarSide(tester, CollarSide.bottom);
    await tapCollarSide(tester, CollarSide.right);
    expectCollar(tester, 8);

    Finder field(String label) => find.byWidgetPredicate(
      (Widget widget) =>
          widget is TextField && widget.decoration?.labelText == label,
    );
    await tester.enterText(field('Width'), '40');
    await tester.enterText(field('Height'), '30');
    final Finder save = find.byKey(const Key('input_save_button'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(session.items, hasLength(1));
    expect(session.items.single.collarIndex, 8);
  });

  // Every window in the library, every side it has: a tap on the side's line
  // near one end takes that side's collar off -- exactly the collar the table
  // says -- and a tap near the other end puts it back.
  for (final WindowType node in windows) {
    final String code = node.codeName!;
    testWidgets('$code: each side toggles on its own line', (
      WidgetTester tester,
    ) async {
      final CollarLayout layout = CollarLayout.forWindow(code)!;
      await open(tester, code);

      // One collar type only (the Prime and Royal windows): the window opens
      // on it, and no tap anywhere changes it -- each says why instead.
      if (layout.isFixed) {
        final int only = layout.collars.single;
        expectCollar(tester, only, reason: code);
        for (final CollarSide side in CollarSide.values) {
          await tapCollarSide(tester, side);
          expectCollar(tester, only, reason: '$code ${side.name}');
        }
        expect(find.text(CollarSidePicker.onlyCollarMessage(layout)), findsWidgets);
        return;
      }

      expectCollar(tester, 1, reason: code);

      if (layout.isWholeFrame) {
        for (final CollarSide side in CollarSide.values) {
          await tapCollarSide(tester, side, along: 0.2);
          expectCollar(tester, 2, reason: '$code ${side.name}');
          await tapCollarSide(tester, side, along: 0.8);
          expectCollar(tester, 1, reason: '$code ${side.name}');
        }
        return;
      }

      for (final CollarSide side in layout.sides) {
        final int off = layout.toggle(1, side)!;
        expect(layout.sidesWithCollar(off), isNot(contains(side)));
        await tapCollarSide(tester, side, along: 0.2);
        expectCollar(tester, off, reason: '$code ${side.name} off');
        await tapCollarSide(tester, side, along: 0.8);
        expectCollar(tester, 1, reason: '$code ${side.name} back');
      }
      expect(refusal, findsNothing, reason: code);
    });
  }
}
