import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/models/window_type.dart';
import 'package:my_app/features/estimation/presentation/input/input_block_order.dart';
import 'package:my_app/features/estimation/presentation/input/window_input_base.dart';
import 'package:my_app/features/estimation/state/estimate_session_store.dart';
import 'package:my_app/features/estimation/state/last_glass_color.dart';
import 'package:my_app/features/settings/state/app_settings.dart';
import 'package:my_app/shared/widgets/option_switch.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every part of the window input screen can be held and dragged up or down,
/// like an app icon on a phone's home screen, and stays where it is put.
void main() {
  const WindowType sliding = WindowType(
    label: 'Sliding Window',
    graphicKey: 'sliding_basic',
    children: <WindowType>[],
    displayIndex: 1,
    codeName: 'S_win',
  );

  Finder part(String id) => find.byKey(ValueKey<String>('arrangeable_$id'));

  Finder fieldLabelled(String label) => find.byWidgetPredicate(
    (Widget widget) =>
        widget is TextField && widget.decoration?.labelText == label,
  );

  double topOf(WidgetTester tester, String id) => tester.getTopLeft(part(id)).dy;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    LastGlassColor.instance.resetForTest();
    AppSettings.instance.resetForTest();
  });

  Future<void> open(
    WidgetTester tester, {
    double height = 7000,
    double width = 1080,
    EstimateFlow flow = EstimateFlow.estimation,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: WindowInputScreen(
          node: sliding,
          session: EstimateSessionStore(
            projectName: 'Drag Test',
            projectLocation: 'Lahore',
            flow: flow,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  }

  /// Holds [id] where [at] says, waits for it to lift, then drags it to [to].
  Future<TestGesture> holdAndDrag(
    WidgetTester tester,
    Offset at,
    Offset to,
  ) async {
    final TestGesture gesture = await tester.startGesture(at);
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.byKey(const Key('arrangeable_lifted')), findsOneWidget,
        reason: 'held still, the part lifts');
    // In small steps, as a finger moves.
    const int steps = 8;
    for (int i = 1; i <= steps; i++) {
      await gesture.moveTo(Offset.lerp(at, to, i / steps)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    return gesture;
  }

  testWidgets('the screen starts in the order it always had', (
    WidgetTester tester,
  ) async {
    await open(tester);

    final List<String> shown = <String>[
      InputBlockOrder.collar,
      InputBlockOrder.windowNo,
      InputBlockOrder.dimensions,
      InputBlockOrder.unit,
      InputBlockOrder.sizes,
      InputBlockOrder.gauge,
      InputBlockOrder.aluminiumColor,
      InputBlockOrder.glassColor,
      InputBlockOrder.description,
    ];
    for (int i = 1; i < shown.length; i++) {
      expect(topOf(tester, shown[i]), greaterThan(topOf(tester, shown[i - 1])),
          reason: '${shown[i]} comes after ${shown[i - 1]}');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('glass colour held and dragged to the top goes to the top, and '
      'stays there', (WidgetTester tester) async {
    await open(tester);

    final Offset from = tester.getCenter(find.text('GLASS COLOR'));
    final Offset to = tester.getTopLeft(part(InputBlockOrder.collar)) +
        const Offset(40, 10);
    final TestGesture gesture = await holdAndDrag(tester, from, to);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('arrangeable_lifted')), findsNothing);
    expect(topOf(tester, InputBlockOrder.glassColor),
        lessThan(topOf(tester, InputBlockOrder.collar)));
    expect(AppSettings.instance.inputBlockOrder?.first,
        InputBlockOrder.glassColor);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('quick_al.input_block_order')?.first,
        InputBlockOrder.glassColor);

    // A fresh screen -- the next window -- opens in the same order.
    await tester.pumpWidget(const SizedBox());
    await open(tester);
    expect(topOf(tester, InputBlockOrder.glassColor),
        lessThan(topOf(tester, InputBlockOrder.collar)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a part moved down lands below the part it passed', (
    WidgetTester tester,
  ) async {
    await open(tester);

    final Offset from = tester.getCenter(fieldLabelled('Quantity'));
    final Rect glass = tester.getRect(part(InputBlockOrder.glassColor));
    final TestGesture gesture = await holdAndDrag(
      tester,
      from,
      Offset(from.dx, glass.bottom - 4),
    );
    await gesture.up();
    await tester.pumpAndSettle();

    expect(topOf(tester, InputBlockOrder.windowNo),
        greaterThan(topOf(tester, InputBlockOrder.glassColor)));
    expect(topOf(tester, InputBlockOrder.windowNo),
        lessThan(topOf(tester, InputBlockOrder.description)));
  });

  testWidgets('holding a text box moves it rather than selecting its text', (
    WidgetTester tester,
  ) async {
    await open(tester);

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(fieldLabelled('Description (Optional)')),
    );
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.byKey(const Key('arrangeable_lifted')), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('arrangeable_lifted')), findsNothing);
    // Let go where it was: nothing moved, nothing saved.
    expect(AppSettings.instance.inputBlockOrder, isNull);
  });

  testWidgets('a quick tap still taps, and a quick swipe still scrolls', (
    WidgetTester tester,
  ) async {
    await open(tester, height: 2340);

    await tester.ensureVisible(find.byKey(const Key('unit_inches_radio')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('unit_inches_radio')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('arrangeable_lifted')), findsNothing);
    expect(
      tester
          .widget<OptionSwitch>(find.byKey(const Key('unit_inches_radio')))
          .selected,
      isTrue,
      reason: 'the tap chose inches',
    );

    final ScrollableState scrollable = tester.state<ScrollableState>(
      find
          .ancestor(
            of: find.byKey(const Key('input_parts')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(fieldLabelled('Quantity'));
    await tester.pumpAndSettle();
    final double before = scrollable.position.pixels;
    await tester.flingFrom(
      tester.getCenter(fieldLabelled('Quantity')),
      const Offset(0, -300),
      1200,
    );
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, greaterThan(before));
    expect(find.byKey(const Key('arrangeable_lifted')), findsNothing);
    expect(AppSettings.instance.inputBlockOrder, isNull);
  });

  testWidgets('held near the top of the screen, the page scrolls with it', (
    WidgetTester tester,
  ) async {
    await open(tester, height: 2340);

    final ScrollableState scrollable = tester.state<ScrollableState>(
      find
          .ancestor(
            of: find.byKey(const Key('input_parts')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(fieldLabelled('Description (Optional)'));
    await tester.pumpAndSettle();
    final double scrolledTo = scrollable.position.pixels;
    expect(scrolledTo, greaterThan(0));

    final Rect view = tester.getRect(find.byType(Scrollable).first);
    final Offset from = tester.getCenter(
      fieldLabelled('Description (Optional)'),
    );
    final TestGesture gesture = await holdAndDrag(
      tester,
      from,
      Offset(from.dx, view.top + 8),
    );
    for (int i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(scrollable.position.pixels, lessThan(scrolledTo));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('arrangeable_lifted')), findsNothing);
    // It was carried up past the parts it scrolled over.
    expect(topOf(tester, InputBlockOrder.description),
        lessThan(topOf(tester, InputBlockOrder.glassColor)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the sidebar puts the screen back as it came', (
    WidgetTester tester,
  ) async {
    // Wide enough for the sidebar's section list in the test font.
    await open(tester, width: 1800);
    final Offset from = tester.getCenter(find.text('GLASS COLOR'));
    final Offset to = tester.getTopLeft(part(InputBlockOrder.collar)) +
        const Offset(40, 10);
    final TestGesture gesture = await holdAndDrag(tester, from, to);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(topOf(tester, InputBlockOrder.glassColor),
        lessThan(topOf(tester, InputBlockOrder.collar)));

    await tester.tap(find.byKey(const Key('open_settings_drawer_button')));
    await tester.pumpAndSettle();
    expect(find.text('Screen Layout'), findsOneWidget);
    await tester.tap(find.byKey(const Key('reset_input_layout_button')));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byKey(const Key('settings_drawer')))).pop();
    await tester.pumpAndSettle();

    expect(AppSettings.instance.inputBlockOrder, isNull);
    expect(topOf(tester, InputBlockOrder.glassColor),
        greaterThan(topOf(tester, InputBlockOrder.sizes)));
  });

  testWidgets('fabrication: lock and rubber rows move on their own', (
    WidgetTester tester,
  ) async {
    await open(tester, flow: EstimateFlow.fabrication);

    expect(part(InputBlockOrder.lock), findsOneWidget);
    expect(part(InputBlockOrder.rubber), findsOneWidget);

    final Offset from = tester.getCenter(find.byKey(const Key('rubber_fix_option')));
    final Offset to = tester.getTopLeft(part(InputBlockOrder.collar)) +
        const Offset(40, 10);
    final TestGesture gesture = await holdAndDrag(tester, from, to);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(topOf(tester, InputBlockOrder.rubber),
        lessThan(topOf(tester, InputBlockOrder.collar)));
    expect(topOf(tester, InputBlockOrder.lock),
        greaterThan(topOf(tester, InputBlockOrder.unit)),
        reason: 'the lock row stayed where it was');
    expect(tester.takeException(), isNull);
  });
}
