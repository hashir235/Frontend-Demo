import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/models/collar_layout.dart';
import 'package:my_app/features/estimation/widgets/collar_side_picker.dart';

/// Tests reach a collar the way a fabricator does: by tapping sides of the
/// collar drawing on the window input screen.

final Finder collarPicker = find.byKey(const Key('collar_side_picker'));

/// The collar the screen shows now, read off the "Collar N" badge.
int shownCollar(WidgetTester tester) {
  final Iterable<Text> badges = tester
      .widgetList<Text>(find.textContaining(RegExp(r'^Collar \d+$')));
  final String text = badges.single.data!;
  return int.parse(text.substring('Collar '.length));
}

/// Taps [side] of the drawing, on its frame line: [along] is how far along
/// the line, 0 at the top or left end and 1 at the bottom or right end. A
/// whole-frame window takes any side.
Future<void> tapCollarSide(
  WidgetTester tester,
  CollarSide side, {
  double along = 0.5,
}) async {
  await tester.ensureVisible(collarPicker);
  await tester.pumpAndSettle();
  final Rect box = tester.getRect(collarPicker);
  final Rect frame = tester
      .widget<CollarSidePicker>(find.byType(CollarSidePicker))
      .frameIn(box.size);
  final (Offset from, Offset to) = switch (side) {
    CollarSide.top => (frame.topLeft, frame.topRight),
    CollarSide.bottom => (frame.bottomLeft, frame.bottomRight),
    CollarSide.left => (frame.topLeft, frame.bottomLeft),
    CollarSide.right => (frame.topRight, frame.bottomRight),
  };
  await tester.tapAt(box.topLeft + Offset.lerp(from, to, along)!);
  await tester.pumpAndSettle();
}

/// Taps sides until the screen is on [target], by the shortest way the
/// window's own collar table allows.
Future<void> goToCollar(WidgetTester tester, String windowCode, int target) async {
  final CollarLayout layout = CollarLayout.forWindow(windowCode)!;
  final int start = shownCollar(tester);
  if (start == target) return;

  if (layout.isWholeFrame) {
    await tapCollarSide(tester, CollarSide.top);
    expect(shownCollar(tester), target);
    return;
  }

  // Shortest path over single taps.
  final Map<int, (int, CollarSide)> cameFrom = <int, (int, CollarSide)>{};
  final List<int> queue = <int>[start];
  final Set<int> seen = <int>{start};
  while (queue.isNotEmpty && !seen.contains(target)) {
    final int at = queue.removeAt(0);
    for (final CollarSide side in layout.sides) {
      final int? next = layout.toggle(at, side);
      if (next != null && seen.add(next)) {
        cameFrom[next] = (at, side);
        queue.add(next);
      }
    }
  }
  final List<CollarSide> taps = <CollarSide>[];
  for (int at = target; at != start;) {
    final (int from, CollarSide side) = cameFrom[at]!;
    taps.insert(0, side);
    at = from;
  }
  for (final CollarSide side in taps) {
    await tapCollarSide(tester, side);
  }
  expect(shownCollar(tester), target, reason: 'reached collar $target by taps');
}
