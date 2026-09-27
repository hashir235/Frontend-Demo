import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/presentation/window_navigation_screen.dart';
import 'package:my_app/features/estimation/state/estimate_session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The window library in rows: "Sliding Windows", then "Box type Windows".
/// Each window's card reads name, then the sections it is made of, then its
/// drawing.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Future<void> open(
    WidgetTester tester, {
    bool fabrication = false,
    Size phone = const Size(1080, 2340),
  }) async {
    tester.view.physicalSize = phone;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: WindowNavigationScreen.root(
          session: EstimateSessionStore(
            projectName: 'Test Project',
            projectLocation: 'Test Location',
            flow: fabrication ? EstimateFlow.fabrication : EstimateFlow.estimation,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder row(String id) => find.byKey(Key('window_page_view_$id'));

  /// Brings [finder] on screen: the rows are in a scrolling list, and one
  /// that is far below is not built at all until it is near.
  Future<void> reach(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Future<int> windowsIn(WidgetTester tester, String id) async {
    await reach(tester, row(id));
    final PageView view = tester.widget<PageView>(
      find.descendant(of: row(id), matching: find.byType(PageView)),
    );
    return (view.childrenDelegate as SliverChildBuilderDelegate).childCount!;
  }

  testWidgets('two rows under their own headings, no second "library" title', (
    WidgetTester tester,
  ) async {
    await open(tester);

    expect(find.text('Windows Library'), findsOneWidget, reason: 'the top title stays');
    expect(find.text('Window Library'), findsNothing, reason: 'the one over the designs is gone');

    final Finder sliding = find.byKey(const Key('library_group_sliding'));
    final Finder box = find.byKey(const Key('library_group_box'));
    expect(tester.widget<Text>(sliding).data, 'Sliding Windows');
    expect(await windowsIn(tester, 'sliding'), 6);
    final double slidingTop = tester.getTopLeft(sliding).dy;

    expect(await windowsIn(tester, 'box'), 5);
    expect(tester.widget<Text>(box).data, 'Box type Windows');
    expect(slidingTop, lessThan(tester.getTopLeft(box).dy),
        reason: 'sliding windows first, box type below');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a card reads name, then used sections, then the drawing', (
    WidgetTester tester,
  ) async {
    await open(tester);

    final Finder card = find.descendant(
      of: row('sliding'),
      matching: find.byKey(const Key('used_sections_S_win')),
    );
    expect(tester.widget<Text>(card).data,
        'DC30F  ·  DC30C  ·  DC26F  ·  DC26C  ·  D29  ·  M23  ·  M24  ·  M28');

    final double name = tester.getTopLeft(find.text('Sliding Window')).dy;
    final double heading = tester.getTopLeft(find.text('Used Sections').first).dy;
    final double sections = tester.getTopLeft(card).dy;
    final double drawing = tester.getTopLeft(
      find.descendant(of: row('sliding'), matching: find.byType(FittedBox)).first,
    ).dy;
    expect(name, lessThan(heading));
    expect(heading, lessThan(sections));
    expect(sections, lessThan(drawing));
    expect(tester.takeException(), isNull, reason: 'nothing overflows on a phone');
  });

  testWidgets('fabrication has no arches in the box type row', (
    WidgetTester tester,
  ) async {
    await open(tester, fabrication: true);
    expect(await windowsIn(tester, 'sliding'), 6);
    expect(await windowsIn(tester, 'box'), 4);
  });

  testWidgets('a box type window opens its size input', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await reach(tester, row('box'));
    final Finder fix = find.descendant(of: row('box'), matching: find.text('Fix Window'));
    await tester.ensureVisible(fix);
    await tester.pumpAndSettle();
    await tester.tap(fix);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('input_window_label')), findsOneWidget);
    expect(find.text('Fix Window'), findsWidgets);
    expect(find.byKey(const Key('collar_side_picker')), findsOneWidget);
  });

  testWidgets('a family opens under its own name, sections on every card', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await reach(tester, row('box'));
    await tester.ensureVisible(row('box'));
    await tester.pumpAndSettle();
    for (int i = 0; i < 3; i++) {
      await tester.drag(
        find.descendant(of: row('box'), matching: find.byType(PageView)),
        const Offset(-300, 0),
      );
      await tester.pumpAndSettle();
    }
    final Finder door = find.descendant(of: row('box'), matching: find.text('Door'));
    await tester.tap(door);
    await tester.pumpAndSettle();

    final Finder heading = find.byKey(const Key('library_group_family'));
    expect(tester.widget<Text>(heading).data, 'Door');
    expect(await windowsIn(tester, 'family'), 2);
    expect(find.text('Single Door'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('used_sections_Single_Door'))).data,
      'D54F  ·  D54A  ·  D50  ·  D46 (optional)  ·  D52 (optional)',
    );
  });

  testWidgets('on a wide screen the rows are grids, still in order', (
    WidgetTester tester,
  ) async {
    await open(tester, phone: const Size(2400, 1800));
    expect(tester.widget(row('sliding')), isA<GridView>());
    await reach(tester, find.byKey(const Key('used_sections_F_win')));
    expect(tester.widget(row('box')), isA<GridView>());
    expect(tester.takeException(), isNull);
  });
}
