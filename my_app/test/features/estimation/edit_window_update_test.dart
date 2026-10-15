import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/data/window_catalog.dart';
import 'package:my_app/features/estimation/models/window_review_item.dart';
import 'package:my_app/features/estimation/presentation/input/input_registry.dart';
import 'package:my_app/features/estimation/state/estimate_session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A window opened from Review, changed and saved, is the changed window.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Finder field(String label) => find.byWidgetPredicate(
    (Widget w) => w is TextField && w.decoration?.labelText == label,
  );

  Future<void> show(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    final Finder button = find.byKey(const Key('input_save_button'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  for (final EstimateFlow flow in <EstimateFlow>[EstimateFlow.estimation, EstimateFlow.fabrication]) {
    testWidgets('${flow.name}: a changed width and height are saved', (WidgetTester tester) async {
      final EstimateSessionStore session =
          EstimateSessionStore(projectName: 'P', projectLocation: 'L', flow: flow);
      await show(tester, buildInputScreen(node: WindowCatalog.byCodeName('S_win')!, session: session));
      await tester.enterText(field('Width'), '40');
      await tester.enterText(field('Height'), '30');
      await save(tester);
      expect(session.items, hasLength(1));
      final WindowReviewItem before = session.items.single;

      await show(
        tester,
        buildInputScreen(
          node: WindowCatalog.byCodeName('S_win')!,
          session: session,
          editingItem: before,
        ),
      );
      await tester.enterText(field('Width'), '52');
      await tester.enterText(field('Height'), '36');
      await save(tester);

      final WindowReviewItem after = session.items.single;
      expect(after.widthValue, isNot(before.widthValue));
      expect(after.heightValue, isNot(before.heightValue));
    });
  }

  testWidgets('a profile switched while editing is saved', (WidgetTester tester) async {
    final EstimateSessionStore session = EstimateSessionStore(projectName: 'P', projectLocation: 'L');
    await show(tester, buildInputScreen(node: WindowCatalog.byCodeName('MSE_win')!, session: session));
    await tester.enterText(field('Width'), '40');
    await tester.enterText(field('Height'), '30');
    await save(tester);
    expect(session.items.single.windowCode, 'MSE_win');

    await show(
      tester,
      buildInputScreen(
        node: WindowCatalog.byCodeName('MSE_win')!,
        session: session,
        editingItem: session.items.single,
      ),
    );
    await tester.tap(find.byKey(const Key('open_settings_drawer_button')));
    await tester.pumpAndSettle();
    final Finder et24a = find.descendant(
      of: find.byKey(const Key('settings_drawer')),
      matching: find.text('ET24A'),
    );
    await tester.ensureVisible(et24a);
    await tester.tap(et24a);
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byKey(const Key('settings_drawer')))).pop();
    await tester.pumpAndSettle();
    await save(tester);

    expect(session.items.single.windowCode, 'MSEA_win');
  });
}
