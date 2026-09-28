import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/data/window_catalog.dart';
import 'package:my_app/features/estimation/presentation/input/input_registry.dart';
import 'package:my_app/features/estimation/state/estimate_session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The M-section Economy windows take their M24 place as ET24 or as ET24A,
/// switched in the sidebar. The choice is saved with the window -- as its
/// code -- and a window saved switched opens switched.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  late EstimateSessionStore session;

  Future<void> open(WidgetTester tester, String code) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    session = EstimateSessionStore(projectName: 'P', projectLocation: 'L');
    await tester.pumpWidget(
      MaterialApp(
        home: buildInputScreen(node: WindowCatalog.byCodeName(code)!, session: session),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSidebar(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('open_settings_drawer_button')));
    await tester.pumpAndSettle();
  }

  Finder inSidebar(String text) => find.descendant(
    of: find.byKey(const Key('settings_drawer')),
    matching: find.text(text),
  );

  Future<void> saveWindow(WidgetTester tester) async {
    Finder field(String label) => find.byWidgetPredicate(
      (Widget w) => w is TextField && w.decoration?.labelText == label,
    );
    // A corner window has a width for each wall.
    if (field('Right Width').evaluate().isNotEmpty) {
      await tester.enterText(field('Right Width'), '40');
      await tester.enterText(field('Left Width'), '30');
    } else {
      await tester.enterText(field('Width'), '40');
    }
    await tester.enterText(field('Height'), '30');
    final Finder save = find.byKey(const Key('input_save_button'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
  }

  testWidgets('ET24 to start with; the sidebar switches it to ET24A', (
    WidgetTester tester,
  ) async {
    await open(tester, 'MSE_win');
    await openSidebar(tester);
    expect(inSidebar('ET24 or ET24A'), findsOneWidget);
    expect(inSidebar('ET24'), findsNWidgets(2), reason: 'the option and the section');
    expect(inSidebar('ET24A'), findsOneWidget, reason: 'only the option');

    await tester.ensureVisible(inSidebar('ET24A'));
    await tester.tap(inSidebar('ET24A'));
    await tester.pumpAndSettle();
    expect(inSidebar('ET24A'), findsNWidgets(2), reason: 'the section list follows');
    expect(inSidebar('ET24'), findsOneWidget, reason: 'now only the option');
    // Nothing of the plain M names anywhere in the list.
    expect(inSidebar('M24'), findsNothing);
    expect(inSidebar('M30F'), findsNothing);
  });

  testWidgets('the choice is saved with the window, and reopens as saved', (
    WidgetTester tester,
  ) async {
    await open(tester, 'MSE_win');
    await openSidebar(tester);
    await tester.ensureVisible(inSidebar('ET24A'));
    await tester.tap(inSidebar('ET24A'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byKey(const Key('settings_drawer')))).pop();
    await tester.pumpAndSettle();
    await saveWindow(tester);

    expect(session.items.single.windowCode, 'MSEA_win');

    // Reopened for editing: on its own card, still switched.
    await tester.pumpWidget(
      MaterialApp(
        home: buildInputScreen(
          node: WindowCatalog.byCodeName('MSE_win')!,
          session: session,
          editingItem: session.items.single,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await openSidebar(tester);
    expect(inSidebar('ET24A'), findsNWidgets(2));
  });

  testWidgets('left on ET24, it saves as the window on the card', (
    WidgetTester tester,
  ) async {
    await open(tester, 'MSCLE_win');
    await saveWindow(tester);
    expect(session.items.single.windowCode, 'MSCLE_win');
  });

  testWidgets('a plain Economy window has no switch', (WidgetTester tester) async {
    await open(tester, 'SE_win');
    await openSidebar(tester);
    expect(find.textContaining(' or ET24'), findsNothing);
    expect(inSidebar('EC24'), findsOneWidget);
    expect(inSidebar('EC30F'), findsOneWidget, reason: 'the collar frame at collar 1');
    expect(inSidebar('DC30F'), findsNothing);
  });
}
