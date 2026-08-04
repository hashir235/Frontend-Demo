import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/features/estimation/models/window_type.dart';
import 'package:my_app/features/estimation/presentation/input/window_input_base.dart';
import 'package:my_app/features/estimation/presentation/window_navigation_screen.dart';
import 'package:my_app/features/estimation/state/estimate_session_store.dart';

const Key _pageViewKey = Key('window_page_view');
const Key _focusedCodeNameKey = Key('focused_code_name');

EstimateSessionStore _testSession() => EstimateSessionStore(
  projectName: 'Test Project',
  projectLocation: 'Test Location',
);

/// The window flow starts here. Reaching this screen through the app would mean
/// getting past auth, the subscription gate and a `POST /projects` round trip --
/// none of which these tests are about, and none of which a widget test can
/// answer. A session without a `projectId` also keeps the backend sync a no-op,
/// so save/edit/delete stay entirely local.
Future<void> _openAddWindows(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(home: WindowNavigationScreen.root(session: _testSession())),
  );
  await tester.pumpAndSettle();
}

/// The library lays out as a carousel on a phone and a grid on anything wider,
/// so the middle of the library box is not reliably a card. The focused card's
/// code chip is, on both.
Future<void> _tapFocusedCard(WidgetTester tester) async {
  final Finder focusedCard = find.byKey(_focusedCodeNameKey);
  await tester.ensureVisible(focusedCard);
  await tester.pumpAndSettle();
  await tester.tap(focusedCard);
  await tester.pumpAndSettle();
}

/// The size fields carry a `GlobalKey` the screen needs for scroll-into-view, so
/// there is no stable test key to hang on to -- the label is the handle.
Finder _fieldByLabel(String label) => find.byWidgetPredicate(
  (Widget widget) =>
      widget is TextField && widget.decoration?.labelText == label,
);

/// Estimation opens in inches, where a size is a typed inch box plus a suter
/// wheel. These pass whole inches and leave the wheel at 0.
Future<void> _enterInputValues(
  WidgetTester tester, {
  required String height,
  required String width,
  String? description,
}) async {
  await tester.enterText(_fieldByLabel('Height (Inch)'), height);
  await tester.enterText(_fieldByLabel('Width (Inch)'), width);
  if (description != null) {
    await tester.enterText(
      _fieldByLabel('Description (Optional)'),
      description,
    );
  }
}

Future<void> _tapSaveButton(WidgetTester tester) async {
  final Finder saveButton = find.byKey(const Key('input_save_button'));
  await tester.ensureVisible(saveButton);
  await tester.tap(saveButton);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The input screen restores the unit and sidebar choices from preferences on
  // open; without a mock store every test would start from whatever the last
  // one left behind.
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Add Windows opens navigation screen with code name labels', (
    WidgetTester tester,
  ) async {
    await _openAddWindows(tester);

    expect(
      find.byKey(const Key('navigation_estimation_heading')),
      findsOneWidget,
    );
    expect(find.byKey(_pageViewKey), findsOneWidget);
    expect(find.byKey(_focusedCodeNameKey), findsOneWidget);
  });

  testWidgets('Leaf card opens input page', (WidgetTester tester) async {
    await _openAddWindows(tester);

    await _tapFocusedCard(tester);

    expect(find.byKey(const Key('input_estimation_heading')), findsOneWidget);
    expect(find.byKey(const Key('input_window_label')), findsOneWidget);
    expect(find.text('Sliding Window'), findsOneWidget);
    expect(find.byKey(const Key('current_win_no_label')), findsOneWidget);
  });

  testWidgets('Sliding Window M_Section shows renamed section codes', (
    WidgetTester tester,
  ) async {
    const WindowType mSectionNode = WindowType(
      label: 'Sliding Window M_Section',
      graphicKey: 'sliding_basic',
      children: <WindowType>[],
      displayIndex: 2,
      codeName: 'MS_win',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: WindowInputScreen(node: mSectionNode, session: _testSession()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open_settings_drawer_button')));
    await tester.pumpAndSettle();

    expect(find.text('M30F'), findsOneWidget);
    expect(find.text('M26F'), findsOneWidget);
    expect(find.text('D29'), findsNothing);

    Navigator.of(
      tester.element(find.byKey(const Key('settings_drawer'))),
    ).pop();
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const Key('collar_page_view')),
      const Offset(-700, 0),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open_settings_drawer_button')));
    await tester.pumpAndSettle();

    expect(find.text('M30'), findsOneWidget);
    expect(find.text('M26'), findsOneWidget);
    expect(find.text('D29'), findsNothing);
  });

  testWidgets('SCF input limits collar cards to 2', (
    WidgetTester tester,
  ) async {
    const WindowType scfNode = WindowType(
      label: 'Sliding Corner Center Fix',
      graphicKey: 'corner_basic',
      children: <WindowType>[],
      displayIndex: 11,
      codeName: 'SCF_win',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: WindowInputScreen(node: scfNode, session: _testSession()),
      ),
    );
    await tester.pumpAndSettle();

    final PageView pageView = tester.widget<PageView>(
      find.byKey(const Key('collar_page_view')),
    );
    final SliverChildBuilderDelegate delegate =
        pageView.childrenDelegate as SliverChildBuilderDelegate;
    expect(delegate.childCount, 2);
  });

  testWidgets('MSCF input limits collar cards to 2', (
    WidgetTester tester,
  ) async {
    const WindowType mscfNode = WindowType(
      label: 'Sliding Corner Center Fix (M_Section)',
      graphicKey: 'corner_basic',
      children: <WindowType>[],
      displayIndex: 15,
      codeName: 'MSCF_win',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: WindowInputScreen(node: mscfNode, session: _testSession()),
      ),
    );
    await tester.pumpAndSettle();

    final PageView pageView = tester.widget<PageView>(
      find.byKey(const Key('collar_page_view')),
    );
    final SliverChildBuilderDelegate delegate =
        pageView.childrenDelegate as SliverChildBuilderDelegate;
    expect(delegate.childCount, 2);
  });

  testWidgets('SCF input shows right and left width fields', (
    WidgetTester tester,
  ) async {
    const WindowType scfNode = WindowType(
      label: 'Sliding Corner Center Fix',
      graphicKey: 'corner_basic',
      children: <WindowType>[],
      displayIndex: 11,
      codeName: 'SCF_win',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: WindowInputScreen(node: scfNode, session: _testSession()),
      ),
    );
    await tester.pumpAndSettle();

    // A corner window splits the width in two, and in inches each of those is
    // an inch box plus a suter wheel -- so the labels carry the unit.
    expect(_fieldByLabel('Right Width (Inch)'), findsOneWidget);
    expect(_fieldByLabel('Left Width (Inch)'), findsOneWidget);
    expect(find.text('Right Width (Inch)'), findsOneWidget);
    expect(find.text('Left Width (Inch)'), findsOneWidget);
  });

  testWidgets('MSCF input also shows right and left width fields', (
    WidgetTester tester,
  ) async {
    const WindowType mscfNode = WindowType(
      label: 'Sliding Corner Center Fix (M_Section)',
      graphicKey: 'corner_basic',
      children: <WindowType>[],
      displayIndex: 15,
      codeName: 'MSCF_win',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: WindowInputScreen(node: mscfNode, session: _testSession()),
      ),
    );
    await tester.pumpAndSettle();

    expect(_fieldByLabel('Right Width (Inch)'), findsOneWidget);
    expect(_fieldByLabel('Left Width (Inch)'), findsOneWidget);
    expect(find.text('Right Width (Inch)'), findsOneWidget);
    expect(find.text('Left Width (Inch)'), findsOneWidget);
  });

  testWidgets('Non-corner windows keep 14 collar cards', (
    WidgetTester tester,
  ) async {
    const WindowType slidingNode = WindowType(
      label: 'Sliding Window',
      graphicKey: 'sliding_basic',
      children: <WindowType>[],
      displayIndex: 1,
      codeName: 'S_win',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: WindowInputScreen(node: slidingNode, session: _testSession()),
      ),
    );
    await tester.pumpAndSettle();

    final PageView pageView = tester.widget<PageView>(
      find.byKey(const Key('collar_page_view')),
    );
    final SliverChildBuilderDelegate delegate =
        pageView.childrenDelegate as SliverChildBuilderDelegate;
    expect(delegate.childCount, 14);
  });

  testWidgets('PF3 drawer follows collar-wise S_win section parity', (
    WidgetTester tester,
  ) async {
    const WindowType pf3Node = WindowType(
      label: 'Center Fix',
      graphicKey: 'panel_basic',
      children: <WindowType>[],
      displayIndex: 3,
      codeName: 'PF3_win',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: WindowInputScreen(node: pf3Node, session: _testSession()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open_settings_drawer_button')));
    await tester.pumpAndSettle();

    // Collar 1
    expect(find.text('DC30F'), findsOneWidget);
    expect(find.text('DC26F'), findsOneWidget);
    expect(find.text('D29'), findsOneWidget);
    expect(find.text('M23'), findsOneWidget);
    expect(find.text('M24'), findsOneWidget);
    expect(find.text('M28'), findsOneWidget);
    expect(find.text('DC30C'), findsNothing);
    expect(find.text('DC26C'), findsNothing);

    Navigator.of(
      tester.element(find.byKey(const Key('settings_drawer'))),
    ).pop();
    await tester.pumpAndSettle();

    // Collar 2
    await tester.drag(
      find.byKey(const Key('collar_page_view')),
      const Offset(-700, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open_settings_drawer_button')));
    await tester.pumpAndSettle();

    expect(find.text('DC30C'), findsOneWidget);
    expect(find.text('DC26C'), findsOneWidget);
    expect(find.text('D29'), findsOneWidget);
    expect(find.text('DC30F'), findsNothing);
    expect(find.text('DC26F'), findsNothing);

    Navigator.of(
      tester.element(find.byKey(const Key('settings_drawer'))),
    ).pop();
    await tester.pumpAndSettle();

    // Collar 3
    await tester.drag(
      find.byKey(const Key('collar_page_view')),
      const Offset(-700, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open_settings_drawer_button')));
    await tester.pumpAndSettle();

    expect(find.text('DC30F'), findsOneWidget);
    expect(find.text('DC30C'), findsOneWidget);
    expect(find.text('DC26F'), findsOneWidget);
    expect(find.text('D29'), findsOneWidget);
    expect(find.text('M23'), findsOneWidget);
    expect(find.text('M24'), findsOneWidget);
    expect(find.text('M28'), findsOneWidget);

    // tap-smoke
    for (final String code in const <String>[
      'DC30F',
      'DC30C',
      'DC26F',
      'D29',
    ]) {
      await tester.tap(find.text(code));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('PS4 drawer collar 2 shows C variants', (
    WidgetTester tester,
  ) async {
    const WindowType ps4Node = WindowType(
      label: 'Center Slide',
      graphicKey: 'panel_basic',
      children: <WindowType>[],
      displayIndex: 4,
      codeName: 'PS4_win',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: WindowInputScreen(node: ps4Node, session: _testSession()),
      ),
    );
    await tester.pumpAndSettle();

    // Collar 1
    await tester.tap(find.byKey(const Key('open_settings_drawer_button')));
    await tester.pumpAndSettle();
    expect(find.text('DC30F'), findsOneWidget);
    expect(find.text('DC26F'), findsOneWidget);
    Navigator.of(
      tester.element(find.byKey(const Key('settings_drawer'))),
    ).pop();
    await tester.pumpAndSettle();

    // Collar 2
    await tester.drag(
      find.byKey(const Key('collar_page_view')),
      const Offset(-700, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open_settings_drawer_button')));
    await tester.pumpAndSettle();

    expect(find.text('DC30C'), findsOneWidget);
    expect(find.text('DC26C'), findsOneWidget);
  });

  testWidgets('EF3 drawer collar 2 shows C variants', (
    WidgetTester tester,
  ) async {
    const WindowType ef3Node = WindowType(
      label: 'Equal Panel',
      graphicKey: 'panel_basic',
      children: <WindowType>[],
      displayIndex: 5,
      codeName: 'EF3_win',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: WindowInputScreen(node: ef3Node, session: _testSession()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open_settings_drawer_button')));
    await tester.pumpAndSettle();
    expect(find.text('DC30F'), findsOneWidget);
    expect(find.text('DC26F'), findsOneWidget);
    Navigator.of(
      tester.element(find.byKey(const Key('settings_drawer'))),
    ).pop();
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const Key('collar_page_view')),
      const Offset(-700, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open_settings_drawer_button')));
    await tester.pumpAndSettle();

    expect(find.text('DC30C'), findsOneWidget);
    expect(find.text('DC26C'), findsOneWidget);
  });

  testWidgets('ES3 drawer excludes M28 and keeps collar matrix', (
    WidgetTester tester,
  ) async {
    const WindowType es3Node = WindowType(
      label: 'Sliding Equal Panel',
      graphicKey: 'panel_basic',
      children: <WindowType>[],
      displayIndex: 6,
      codeName: 'ES3_win',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: WindowInputScreen(node: es3Node, session: _testSession()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open_settings_drawer_button')));
    await tester.pumpAndSettle();

    expect(find.text('DC30F'), findsOneWidget);
    expect(find.text('DC26F'), findsOneWidget);
    expect(find.text('M23'), findsOneWidget);
    expect(find.text('M24'), findsOneWidget);
    expect(find.text('M28'), findsNothing);

    Navigator.of(
      tester.element(find.byKey(const Key('settings_drawer'))),
    ).pop();
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const Key('collar_page_view')),
      const Offset(-700, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open_settings_drawer_button')));
    await tester.pumpAndSettle();

    expect(find.text('DC30C'), findsOneWidget);
    expect(find.text('DC26C'), findsOneWidget);
    expect(find.text('M28'), findsNothing);
  });

  testWidgets('MPF3 drawer uses M codes and removes D29', (
    WidgetTester tester,
  ) async {
    const WindowType mpf3Node = WindowType(
      label: 'Center Fix',
      graphicKey: 'panel_basic',
      children: <WindowType>[],
      displayIndex: 7,
      codeName: 'MPF3_win',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: WindowInputScreen(node: mpf3Node, session: _testSession()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open_settings_drawer_button')));
    await tester.pumpAndSettle();
    expect(find.text('M30F'), findsOneWidget);
    expect(find.text('M26F'), findsOneWidget);
    expect(find.text('D29'), findsNothing);

    Navigator.of(
      tester.element(find.byKey(const Key('settings_drawer'))),
    ).pop();
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const Key('collar_page_view')),
      const Offset(-700, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open_settings_drawer_button')));
    await tester.pumpAndSettle();

    expect(find.text('M30'), findsOneWidget);
    expect(find.text('M26'), findsOneWidget);
    expect(find.text('D29'), findsNothing);
  });

  testWidgets('Save with optional description shows it in review list', (
    WidgetTester tester,
  ) async {
    await _openAddWindows(tester);
    await _tapFocusedCard(tester);

    await _enterInputValues(
      tester,
      height: '45.7',
      width: '22.4',
      description: 'bath room window',
    );
    await _tapSaveButton(tester);

    await tester.tap(find.byKey(const Key('open_review_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('review_item_1')), findsOneWidget);
    // The row labels the description and prints it underneath.
    expect(find.text('Description'), findsOneWidget);
    expect(find.text('bath room window'), findsOneWidget);
  });

  testWidgets('Save without description keeps review row clean', (
    WidgetTester tester,
  ) async {
    await _openAddWindows(tester);
    await _tapFocusedCard(tester);

    await _enterInputValues(tester, height: '21.3', width: '11.2');
    await _tapSaveButton(tester);

    await tester.tap(find.byKey(const Key('open_review_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('review_item_1')), findsOneWidget);
    expect(find.text('Description'), findsNothing);
  });

  testWidgets(
    'Edit description updates same winNo and delete keeps numbering monotonic',
    (WidgetTester tester) async {
      await _openAddWindows(tester);
      await _tapFocusedCard(tester);

      await _enterInputValues(
        tester,
        height: '31.6',
        width: '12.3',
        description: 'bath room window',
      );
      await _tapSaveButton(tester);

      await _enterInputValues(tester, height: '32.6', width: '13.3');
      await _tapSaveButton(tester);

      await tester.tap(find.byKey(const Key('open_review_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('review_item_1')), findsOneWidget);
      expect(find.byKey(const Key('review_item_2')), findsOneWidget);

      await tester.tap(find.byKey(const Key('review_edit_1')));
      await tester.pumpAndSettle();
      await tester.enterText(
        _fieldByLabel('Description (Optional)'),
        'updated bathroom window',
      );
      await _tapSaveButton(tester);

      expect(find.byKey(const Key('review_item_1')), findsOneWidget);
      expect(find.textContaining('updated bathroom window'), findsOneWidget);

      await tester.tap(find.byKey(const Key('review_delete_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('review_item_1')), findsNothing);
      expect(find.byKey(const Key('review_item_2')), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('winNo: 3'), findsOneWidget);
    },
  );
}
