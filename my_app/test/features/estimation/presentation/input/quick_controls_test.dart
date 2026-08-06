import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/theme/app_theme.dart';
import 'package:my_app/features/estimation/models/window_type.dart';
import 'package:my_app/features/estimation/presentation/input/window_input_base.dart';
import 'package:my_app/features/estimation/state/estimate_session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Unit, lock and rubber used to live behind the sidebar, so changing the unit
/// meant opening a panel -- while typing the very sizes that unit governs.
/// They belong on the page; only the once-per-window things (sections, D46/D52,
/// back collar, net) stay behind the Sections button.
const WindowType _sliding = WindowType(
  label: 'Sliding Window',
  graphicKey: 'sliding_basic',
  children: <WindowType>[],
  displayIndex: 1,
  codeName: 'S_win',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Future<void> pump(
    WidgetTester tester, {
    required EstimateFlow flow,
    WindowType node = _sliding,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WindowInputScreen(
          node: node,
          session: EstimateSessionStore(
            projectName: 'Test Project',
            projectLocation: 'Test Location',
            flow: flow,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  }

  testWidgets('the panel is called Sections, not three dots', (
    WidgetTester tester,
  ) async {
    await pump(tester, flow: EstimateFlow.estimation);

    // The old control was an unlabelled "..." icon, which said nothing about
    // what was behind it.
    expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('open_settings_drawer_button')),
        matching: find.text('Sections'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('estimation shows the unit on the page and no lock or rubber', (
    WidgetTester tester,
  ) async {
    await pump(tester, flow: EstimateFlow.estimation);

    await tester.ensureVisible(find.byKey(const Key('unit_feet_radio')));
    expect(find.byKey(const Key('unit_feet_radio')), findsOneWidget);
    expect(find.byKey(const Key('unit_inches_radio')), findsOneWidget);
    expect(find.byKey(const Key('unit_cm_radio')), findsOneWidget);

    // Estimation has neither of these.
    expect(find.byKey(const Key('rubber_fix_option')), findsNothing);
    expect(find.byKey(const Key('lock_latch_option')), findsNothing);
  });

  testWidgets('fabrication shows unit and rubber on the page', (
    WidgetTester tester,
  ) async {
    await pump(tester, flow: EstimateFlow.fabrication);

    await tester.ensureVisible(find.byKey(const Key('unit_inches_radio')));
    expect(find.byKey(const Key('unit_inches_radio')), findsOneWidget);
    expect(find.byKey(const Key('unit_cm_radio')), findsOneWidget);
    // Fabrication measures in inches or cm; there is no feet chip.
    expect(find.byKey(const Key('unit_feet_radio')), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('rubber_fix_option')));
    expect(find.byKey(const Key('rubber_fix_option')), findsOneWidget);
  });

  testWidgets('fabrication shows the lock chips on the page', (
    WidgetTester tester,
  ) async {
    // Locks belong to sliding-type windows, not to doors.
    await pump(tester, flow: EstimateFlow.fabrication);

    await tester.ensureVisible(find.byKey(const Key('lock_latch_option')));
    expect(find.byKey(const Key('lock_latch_option')), findsOneWidget);
    expect(find.byKey(const Key('lock_self_option')), findsOneWidget);
  });

  testWidgets('the selected chip uses the theme blue, not green', (
    WidgetTester tester,
  ) async {
    // Estimation opens on inches, so that is the chip that should be filled.
    await pump(tester, flow: EstimateFlow.estimation);

    await tester.ensureVisible(find.byKey(const Key('unit_inches_radio')));
    final Material selected = tester.widget<Material>(
      find.byKey(const Key('unit_inches_radio')),
    );
    final Material unselected = tester.widget<Material>(
      find.byKey(const Key('unit_feet_radio')),
    );

    // tealAccent read as green next to the rest of the screen.
    expect(selected.color, AppTheme.royalBlue);
    expect(selected.color, isNot(AppTheme.tealAccent));
    expect(unselected.color, isNot(AppTheme.royalBlue));
  });

  testWidgets('fabrication CM sets the mode the engine actually reads', (
    WidgetTester tester,
  ) async {
    // Fabrication stores centimetres in the `feet` slot. A CM chip that set
    // UnitMode.cm left the screen in neither cm nor inch handling, and the size
    // was read wrongly -- so the chip has to land on the cm field layout.
    await pump(tester, flow: EstimateFlow.fabrication);

    await tester.ensureVisible(find.byKey(const Key('unit_cm_radio')));
    await tester.tap(find.byKey(const Key('unit_cm_radio')));
    await tester.pumpAndSettle();

    // In cm mode the height is one plain field, not a typed part plus a wheel.
    expect(find.widgetWithText(TextField, 'Height'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Height (Inch)'), findsNothing);
  });
}
