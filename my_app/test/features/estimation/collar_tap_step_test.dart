import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/models/window_type.dart';
import 'package:my_app/features/estimation/presentation/input/window_input_base.dart';
import 'package:my_app/features/estimation/state/estimate_session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stepping through collars by tapping.
///
/// A sliding window offers fourteen collars, and reaching the one you want
/// meant dragging the strip along one card at a time -- for every window in a
/// project. Tapping the side of the strip you want to go towards is one
/// movement instead of several.
///
/// The half that decides the direction is the strip's half, not the screen's:
/// the rest of the page has its own taps -- size fields, the winNo box, the
/// sidebar button -- and none of them may start moving collars.
void main() {
  const WindowType slidingNode = WindowType(
    label: 'Sliding Window',
    graphicKey: 'sliding_basic',
    children: <WindowType>[],
    displayIndex: 1,
    codeName: 'S_win',
  );

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Future<void> openInput(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WindowInputScreen(
          node: slidingNode,
          session: EstimateSessionStore(
            projectName: 'Test Project',
            projectLocation: 'Test Location',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final Finder strip = find.byKey(const Key('collar_page_view'));

  /// Which collar is showing, read from the controller the strip is driven by
  /// rather than from anything on screen -- every card carries a number badge,
  /// so the numbers alone cannot say which one is centred.
  double currentPage(WidgetTester tester) {
    final PageView view = tester.widget<PageView>(strip);
    return (view.controller as PageController).page ?? 0;
  }

  /// Taps a fraction across the strip: 0.15 is well inside its left half,
  /// 0.85 well inside its right.
  Future<void> tapAcross(WidgetTester tester, double fraction) async {
    final Rect box = tester.getRect(strip);
    await tester.tapAt(Offset(box.left + box.width * fraction, box.center.dy));
    await tester.pumpAndSettle();
  }

  testWidgets('tapping the right of the strip goes to the next collar', (
    WidgetTester tester,
  ) async {
    await openInput(tester);
    expect(currentPage(tester), 0);

    await tapAcross(tester, 0.85);
    expect(currentPage(tester), 1);

    await tapAcross(tester, 0.85);
    expect(currentPage(tester), 2);
  });

  testWidgets('tapping the left of the strip goes back', (
    WidgetTester tester,
  ) async {
    await openInput(tester);
    await tapAcross(tester, 0.85);
    await tapAcross(tester, 0.85);
    expect(currentPage(tester), 2);

    await tapAcross(tester, 0.15);
    expect(currentPage(tester), 1);
  });

  testWidgets('the ends hold: no wrapping round to the other side', (
    WidgetTester tester,
  ) async {
    await openInput(tester);

    // Collar 1 is the first. Going back from here must not land on collar 14.
    await tapAcross(tester, 0.15);
    expect(currentPage(tester), 0);

    for (int i = 0; i < 13; i++) {
      await tapAcross(tester, 0.85);
    }
    expect(currentPage(tester), 13, reason: 'fourteen collars, last is index 13');

    await tapAcross(tester, 0.85);
    expect(currentPage(tester), 13, reason: 'and it stays there');
  });

  testWidgets('the tap area stops at the strip', (WidgetTester tester) async {
    await openInput(tester);
    await tapAcross(tester, 0.85);
    expect(currentPage(tester), 1);

    // Well below the strip, on the right-hand side -- the half that would step
    // forward if the whole screen were listening. It must not be.
    final Rect box = tester.getRect(strip);
    await tester.tapAt(Offset(box.right - 20, box.bottom + 120));
    await tester.pumpAndSettle();

    expect(currentPage(tester), 1);
  });

  testWidgets('dragging the strip still works', (WidgetTester tester) async {
    // The tap handler sits above the PageView, so a drag has to pass through
    // it untouched or the old way of moving would have been taken away.
    await openInput(tester);
    await tester.drag(strip, const Offset(-700, 0));
    await tester.pumpAndSettle();

    expect(currentPage(tester), greaterThan(0));
  });

  // Keyed rather than found by icon: the screen's own app-bar back button
  // carries the same arrow, and a test that cannot tell the two apart would
  // pass just as happily on the wrong one.
  const Key backArrow = Key('collar_step_back');
  const Key forwardArrow = Key('collar_step_forward');

  testWidgets('both arrows are shown under the cards', (
    WidgetTester tester,
  ) async {
    await openInput(tester);

    expect(find.byKey(backArrow), findsOneWidget);
    expect(find.byKey(forwardArrow), findsOneWidget);

    // They sit below the cards, where they describe the halves above them.
    expect(
      tester.getCenter(find.byKey(forwardArrow)).dy,
      greaterThan(tester.getRect(strip).bottom - 1),
    );
  });

  testWidgets('the arrows move the strip too', (WidgetTester tester) async {
    await openInput(tester);

    await tester.tap(find.byKey(forwardArrow));
    await tester.pumpAndSettle();
    expect(currentPage(tester), 1);

    await tester.tap(find.byKey(backArrow));
    await tester.pumpAndSettle();
    expect(currentPage(tester), 0);
  });

  testWidgets('the back arrow fades at the first collar', (
    WidgetTester tester,
  ) async {
    await openInput(tester);

    double opacityOf(Key key) {
      return tester
          .widget<AnimatedOpacity>(
            find.descendant(
              of: find.byKey(key),
              matching: find.byType(AnimatedOpacity),
            ),
          )
          .opacity;
    }

    // Nothing to go back to, and the arrow says so rather than looking live
    // and doing nothing.
    expect(opacityOf(backArrow), lessThan(0.5));
    expect(opacityOf(forwardArrow), 1);

    await tapAcross(tester, 0.85);
    expect(opacityOf(backArrow), 1);
  });
}
