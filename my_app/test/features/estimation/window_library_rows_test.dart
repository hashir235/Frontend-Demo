import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/presentation/window_navigation_screen.dart';
import 'package:my_app/features/estimation/state/estimate_session_store.dart';
import 'package:my_app/features/estimation/widgets/window_card_strip.dart';
import 'package:my_app/features/estimation/widgets/window_navigation_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/collar_taps.dart';

/// The window library: "Sliding Windows" -- the plain frame, then the Prime
/// (B frame) and Royal (BA frame) lines under the same heading -- and then
/// "Box type Windows". Every line is one line, swiped sideways. Each card
/// reads name, then the sections it is made of, then its drawing.
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

  Finder stripScroll(String id) =>
      find.descendant(of: row(id), matching: find.byType(Scrollable));

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
    return tester.widget<WindowCardStrip>(row(id)).itemCount;
  }

  /// Swipes line [id] along until [card] is built and on screen.
  Future<void> swipeTo(WidgetTester tester, String id, Finder card) async {
    await reach(tester, row(id));
    await tester.scrollUntilVisible(card, 150, scrollable: stripScroll(id));
    await tester.pumpAndSettle();
  }

  testWidgets('sliding lines under one heading, box type below, no second "library" title', (
    WidgetTester tester,
  ) async {
    await open(tester);

    expect(find.text('Windows Library'), findsOneWidget, reason: 'the top title stays');
    expect(find.text('Window Library'), findsNothing, reason: 'the one over the designs is gone');

    // Where a widget sits on the whole page, however far it is scrolled.
    double onPage(Finder finder) =>
        tester.getTopLeft(finder).dy +
        tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;

    final Finder sliding = find.byKey(const Key('library_group_sliding'));
    expect(tester.widget<Text>(sliding).data, 'Sliding Windows');
    expect(await windowsIn(tester, 'sliding'), 6);
    final double slidingAt = onPage(sliding);

    // The B and BA lines are sliding windows too: no heading of their own.
    expect(await windowsIn(tester, 'sliding_b'), 3);
    final double primeAt = onPage(row('sliding_b'));
    expect(await windowsIn(tester, 'sliding_ba'), 3);
    final double royalAt = onPage(row('sliding_ba'));
    expect(find.byKey(const Key('library_group_sliding_b')), findsNothing);
    expect(find.byKey(const Key('library_group_sliding_ba')), findsNothing);

    // The Economy line under its own heading, then box type.
    final Finder economy = find.byKey(const Key('library_group_economy'));
    expect(await windowsIn(tester, 'economy'), 6);
    expect(tester.widget<Text>(economy).data, 'Economy Sliding Window');
    final double economyAt = onPage(economy);

    final Finder box = find.byKey(const Key('library_group_box'));
    expect(await windowsIn(tester, 'box'), 5);
    expect(tester.widget<Text>(box).data, 'Box type Windows');
    final double boxAt = onPage(box);

    expect(<double>[slidingAt, primeAt, royalAt, economyAt, boxAt],
        orderedEquals(<double>[slidingAt, primeAt, royalAt, economyAt, boxAt]..sort()),
        reason: 'sliding, Prime, Royal, Economy, box type -- top to bottom');
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

  testWidgets('the Prime and Royal lines name their frame sections', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await reach(tester, row('sliding_b'));
    expect(find.text('Prime Sliding Window'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('used_sections_SB_win'))).data,
      'DC30B  ·  DC26B  ·  D29  ·  M23  ·  M24  ·  M28',
    );
    await reach(tester, row('sliding_ba'));
    expect(find.text('Royal Sliding Window'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('used_sections_SBA_win'))).data,
      'DC30BA  ·  DC26BA  ·  D29  ·  M23  ·  M24  ·  M28',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('fabrication has no arches in the box type row', (
    WidgetTester tester,
  ) async {
    await open(tester, fabrication: true);
    expect(await windowsIn(tester, 'sliding'), 6);
    expect(await windowsIn(tester, 'sliding_b'), 3);
    expect(await windowsIn(tester, 'sliding_ba'), 3);
    expect(await windowsIn(tester, 'economy'), 6);
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
    final Finder door = find.descendant(of: row('box'), matching: find.text('Door'));
    await swipeTo(tester, 'box', door);
    await tester.tap(door);
    await tester.pumpAndSettle();

    final Finder heading = find.byKey(const Key('library_group_family'));
    expect(tester.widget<Text>(heading).data, 'Door');
    expect(await windowsIn(tester, 'family'), 2);
    expect(find.text('Single Door'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('used_sections_Single_Door'))).data,
      'D54F  ·  D54A  ·  D50  ·  D46 (optional)  ·  D52 (optional)  ·  '
      'D61A / D61H / PATTI4 / PATTI6 (strips)',
    );
  });

  testWidgets('a Prime window opens on its own frame, without a collar', (
    WidgetTester tester,
  ) async {
    await open(tester);
    final Finder panels =
        find.descendant(of: row('sliding_b'), matching: find.text('Prime Panel Windows'));
    await swipeTo(tester, 'sliding_b', panels);
    await tester.tap(panels);
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('library_group_family'))).data,
        'Prime Panel Windows');
    expect(await windowsIn(tester, 'family'), 3);

    final Finder slide = find.text('Prime Center Slide');
    await swipeTo(tester, 'family', slide);
    await tester.tap(slide);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('input_window_label')), findsOneWidget);
    expect(shownCollar(tester), 2, reason: 'the one collar it comes in');
    expect(find.text('This window has no collar on any side.'), findsOneWidget,
        reason: 'the hint under the drawing says so');
  });

  group('swiping', () {
    /// The first line, scrolled fully into view: on a phone it starts under
    /// the bottom bar.
    Future<void> openOnFirstLine(WidgetTester tester) async {
      await open(tester);
      await tester.ensureVisible(row('sliding'));
      await tester.pumpAndSettle();
    }

    double offset(WidgetTester tester, String id) =>
        tester.state<ScrollableState>(stripScroll(id)).position.pixels;

    double extent(WidgetTester tester, String id) {
      final Rect first = tester.getRect(find.descendant(
        of: row(id),
        matching: find.byType(Padding),
      ).first);
      return first.width;
    }

    testWidgets('a hard fling runs on across several cards, then rests on one', (
      WidgetTester tester,
    ) async {
      await openOnFirstLine(tester);
      await tester.fling(stripScroll('sliding'), const Offset(-200, 0), 2500);
      await tester.pumpAndSettle();
      final double at = offset(tester, 'sliding');
      final double step = extent(tester, 'sliding');
      final double max =
          tester.state<ScrollableState>(stripScroll('sliding')).position.maxScrollExtent;
      expect(at, greaterThan(step * 1.5), reason: 'more than one card');
      final double cards = at / step;
      expect(
        (cards - cards.roundToDouble()).abs() < 0.01 || (at - max).abs() < 0.5,
        isTrue,
        reason: 'at rest on a card, not between two ($cards cards)',
      );
    });

    testWidgets('a gentle flick moves on exactly one card', (
      WidgetTester tester,
    ) async {
      await openOnFirstLine(tester);
      // A light flick of the thumb: a short way, not fast. On its own it
      // would not carry to the next card.
      await tester.fling(stripScroll('sliding'), const Offset(-60, 0), 400);
      await tester.pumpAndSettle();
      expect(offset(tester, 'sliding'), closeTo(extent(tester, 'sliding'), 0.5));
    });

    testWidgets('a slow drag halfway settles on the nearest card', (
      WidgetTester tester,
    ) async {
      await openOnFirstLine(tester);
      final double step = extent(tester, 'sliding');
      await tester.timedDrag(
        stripScroll('sliding'),
        Offset(-step * 0.3, 0),
        const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
      expect(offset(tester, 'sliding'), closeTo(0, 0.5), reason: 'back to the first');

      await tester.timedDrag(
        stripScroll('sliding'),
        Offset(-step * 0.7, 0),
        const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
      expect(offset(tester, 'sliding'), closeTo(step, 0.5), reason: 'on to the second');
    });
  });

  testWidgets('on a wide screen every line stays one line', (
    WidgetTester tester,
  ) async {
    await open(tester, phone: const Size(2400, 1800));
    expect(find.byType(GridView), findsNothing);
    // Measured from the line's own top, so the page moving does not count.
    double fromLine(Finder name) =>
        tester.getTopLeft(find.ancestor(of: name, matching: find.byType(WindowNavigationCard))).dy -
        tester.getTopLeft(row('sliding')).dy;
    final double first = fromLine(find.text('Sliding Window'));
    final Finder corner = find.text('Sliding Corner Windows M_Section');
    await tester.scrollUntilVisible(corner, 150, scrollable: stripScroll('sliding'));
    expect(fromLine(corner), closeTo(first, 0.5),
        reason: 'the sixth card on the same line as the first');
    await reach(tester, find.byKey(const Key('used_sections_F_win')));
    expect(tester.takeException(), isNull);
  });
}
