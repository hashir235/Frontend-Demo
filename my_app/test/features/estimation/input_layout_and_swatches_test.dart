import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/models/window_type.dart';
import 'package:my_app/features/estimation/presentation/input/window_input_base.dart';
import 'package:my_app/features/estimation/state/estimate_session_store.dart';
import 'package:my_app/features/estimation/state/last_glass_color.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where things sit on the window input screen, and choosing the aluminium and
/// the glass by their colour.
void main() {
  const WindowType sliding = WindowType(
    label: 'Sliding Window',
    graphicKey: 'sliding_basic',
    children: <WindowType>[],
    displayIndex: 1,
    codeName: 'S_win',
  );

  late EstimateSessionStore session;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    LastGlassColor.instance.resetForTest();
    session = EstimateSessionStore(
      projectName: 'Test Project',
      projectLocation: 'Test Location',
    );
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: WindowInputScreen(node: sliding, session: session)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  }

  Finder fieldLabelled(String label) => find.byWidgetPredicate(
    (Widget widget) =>
        widget is TextField && widget.decoration?.labelText == label,
  );

  Rect rectOf(WidgetTester tester, Finder finder) => tester.getRect(finder);

  testWidgets('number and quantity sit on one line between collar and sizes', (
    WidgetTester tester,
  ) async {
    await open(tester);

    final Rect collar = rectOf(tester, find.byKey(const Key('collar_page_view')));
    final Rect winNo = rectOf(tester, find.byKey(const Key('current_win_no_label')));
    final Rect quantity = rectOf(tester, fieldLabelled('Quantity'));
    final Rect width = rectOf(tester, fieldLabelled('Width').first);

    expect(winNo.top, greaterThan(collar.bottom),
        reason: 'the number no longer floats above the collar');
    expect((winNo.center.dy - quantity.center.dy).abs(), lessThan(4),
        reason: 'number and quantity share a line');
    expect(winNo.left, lessThan(quantity.left), reason: 'number first');
    expect(quantity.bottom, lessThan(width.top), reason: 'both above the sizes');
    expect(
      find.descendant(
        of: find.byKey(const Key('current_win_no_label')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('aluminium, glass and description come after the sizes', (
    WidgetTester tester,
  ) async {
    await open(tester);

    final double sizesBottom =
        rectOf(tester, fieldLabelled('Height').first).bottom;
    final Rect aluminium =
        rectOf(tester, find.byKey(const Key('aluminium_color_selected')));
    final Rect glass = rectOf(tester, find.byKey(const Key('glass_color_selected')));
    final Rect description =
        rectOf(tester, fieldLabelled('Description (Optional)'));

    expect(aluminium.top, greaterThan(sizesBottom));
    expect(glass.top, greaterThan(aluminium.bottom));
    expect(description.top, greaterThan(glass.bottom));
  });

  testWidgets('the aluminium colour is picked from its box, ticked and named', (
    WidgetTester tester,
  ) async {
    await open(tester);

    Finder tickOn(String color) => find.descendant(
      of: find.byKey(Key('aluminium_color_option_$color')),
      matching: find.byIcon(Icons.check_rounded),
    );

    // Five boxes, no list to open.
    for (final String color in <String>[
      'H23/PC-RAL',
      'DULL',
      'SAHARA/ BROWN',
      'BLACK/ MULTI',
      'WOOD COAT',
    ]) {
      expect(find.byKey(Key('aluminium_color_option_$color')), findsOneWidget);
    }
    expect(tickOn('H23/PC-RAL'), findsOneWidget, reason: 'the default');

    await tester.ensureVisible(
      find.byKey(const Key('aluminium_color_option_WOOD COAT')),
    );
    await tester.tap(find.byKey(const Key('aluminium_color_option_WOOD COAT')));
    await tester.pumpAndSettle();

    expect(tickOn('WOOD COAT'), findsOneWidget);
    expect(tickOn('H23/PC-RAL'), findsNothing, reason: 'only one is ticked');
    expect(
      find.descendant(
        of: find.byKey(const Key('aluminium_color_selected')),
        matching: find.text('WOOD COAT'),
      ),
      findsOneWidget,
    );
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('the glass is picked from its box, ticked, named and saved', (
    WidgetTester tester,
  ) async {
    await open(tester);

    Finder tickOn(String glass) => find.descendant(
      of: find.byKey(Key('glass_color_option_$glass')),
      matching: find.byIcon(Icons.check_rounded),
    );

    expect(tickOn('Clear Glass'), findsOneWidget, reason: 'the default');

    await tester.ensureVisible(
      find.byKey(const Key('glass_color_option_Blue Mercury')),
    );
    await tester.tap(find.byKey(const Key('glass_color_option_Blue Mercury')));
    await tester.pumpAndSettle();

    expect(tickOn('Blue Mercury'), findsOneWidget);
    expect(tickOn('Clear Glass'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('glass_color_selected')),
        matching: find.text('Blue Mercury'),
      ),
      findsOneWidget,
    );
    // Still remembered for the next window, as before.
    expect(LastGlassColor.instance.value, 'Blue Mercury');

    await tester.enterText(fieldLabelled('Width').first, '30');
    await tester.enterText(fieldLabelled('Height').first, '40');
    final Finder save = find.byKey(const Key('input_save_button'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(session.items.single.glassColor, 'Blue Mercury');
  });
}
