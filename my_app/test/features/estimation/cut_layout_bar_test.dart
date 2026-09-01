import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/widgets/cut_layout_bar.dart';

/// The bar is a picture of a real cut plan, so the thing worth testing is that
/// the picture cannot disagree with the plan: every piece present, each one as
/// wide as its true share of the length, and the finished ones visibly out of
/// the way.
void main() {
  const double barWidth = 400;

  Future<void> pumpBar(
    WidgetTester tester, {
    required List<CutLayoutSegment> segments,
    double wastageFt = 0,
    bool isOffcut = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: barWidth,
            child: CutLayoutBar(
              segments: segments,
              wastageFt: wastageFt,
              isOffcut: isOffcut,
              totalLabel: '18 ft',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Rendered widths of the blocks, left to right.
  List<double> blockWidths(WidgetTester tester) {
    return tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .map((AnimatedContainer c) => (c.constraints?.maxWidth) ?? 0)
        .toList();
  }

  testWidgets('every cut gets a block, plus one for the waste', (
    WidgetTester tester,
  ) async {
    await pumpBar(
      tester,
      segments: const <CutLayoutSegment>[
        CutLayoutSegment(label: '1/WT', lengthFt: 6),
        CutLayoutSegment(label: '1/WB', lengthFt: 6),
        CutLayoutSegment(label: '2/H', lengthFt: 4),
      ],
      wastageFt: 2,
    );

    expect(find.byType(AnimatedContainer), findsNWidgets(4));
    expect(find.text('1/WT'), findsOneWidget);
    expect(find.text('1/WB'), findsOneWidget);
    expect(find.text('2/H'), findsOneWidget);
    expect(find.text('Waste'), findsOneWidget);
    expect(find.text('3 pieces'), findsOneWidget);
    expect(find.text('= 18 ft'), findsOneWidget);
  });

  testWidgets('block widths follow the real lengths', (
    WidgetTester tester,
  ) async {
    await pumpBar(
      tester,
      segments: const <CutLayoutSegment>[
        CutLayoutSegment(label: 'a', lengthFt: 9),
        CutLayoutSegment(label: 'b', lengthFt: 3),
      ],
    );

    final List<double> widths = blockWidths(tester);
    expect(widths, hasLength(2));
    // 9ft against 3ft: the first block must be three times the second, or the
    // drawing is telling the operator something the plan does not say.
    expect(widths[0] / widths[1], closeTo(3.0, 0.02));
  });

  testWidgets('blocks fill the bar without overflowing it', (
    WidgetTester tester,
  ) async {
    await pumpBar(
      tester,
      segments: const <CutLayoutSegment>[
        CutLayoutSegment(label: 'a', lengthFt: 5),
        CutLayoutSegment(label: 'b', lengthFt: 5),
        CutLayoutSegment(label: 'c', lengthFt: 5),
      ],
      wastageFt: 3,
    );

    final double total = blockWidths(tester).fold<double>(0, (double a, double b) => a + b);
    // Four blocks, three 2px gaps.
    expect(total, closeTo(barWidth - 6, 1.0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a cut piece is dimmed once it is ticked off', (
    WidgetTester tester,
  ) async {
    await pumpBar(
      tester,
      segments: const <CutLayoutSegment>[
        CutLayoutSegment(label: '1/WT', lengthFt: 6, isCut: true),
        CutLayoutSegment(label: '1/WB', lengthFt: 6),
      ],
    );

    final List<AnimatedContainer> blocks = tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .toList();
    final Color cutColor = (blocks[0].decoration! as BoxDecoration).color!;
    final Color pendingColor = (blocks[1].decoration! as BoxDecoration).color!;

    // The finished one recedes; the one still to do keeps full strength.
    expect(cutColor.a, lessThan(pendingColor.a));
    expect(pendingColor.a, 1.0);
  });

  testWidgets('a leftover bar calls its tail an offcut, not waste', (
    WidgetTester tester,
  ) async {
    await pumpBar(
      tester,
      segments: const <CutLayoutSegment>[
        CutLayoutSegment(label: '1/WT', lengthFt: 10),
      ],
      wastageFt: 4,
      isOffcut: true,
    );

    expect(find.text('Offcut'), findsOneWidget);
    expect(find.text('Waste'), findsNothing);
  });

  testWidgets('a sliver of a piece keeps its block but drops its label', (
    WidgetTester tester,
  ) async {
    await pumpBar(
      tester,
      segments: const <CutLayoutSegment>[
        CutLayoutSegment(label: 'big', lengthFt: 40),
        CutLayoutSegment(label: 'tiny', lengthFt: 0.5),
      ],
    );

    // Both pieces are drawn -- dropping one would misrepresent the bar.
    expect(find.byType(AnimatedContainer), findsNWidgets(2));
    // But an unreadable label is worse than none.
    expect(find.text('tiny'), findsNothing);
    expect(find.text('big'), findsOneWidget);
  });

  testWidgets('a bar with no waste draws only its pieces', (
    WidgetTester tester,
  ) async {
    await pumpBar(
      tester,
      segments: const <CutLayoutSegment>[
        CutLayoutSegment(label: '1/WT', lengthFt: 9),
        CutLayoutSegment(label: '1/WB', lengthFt: 9),
      ],
    );

    expect(find.byType(AnimatedContainer), findsNWidgets(2));
    expect(find.text('Waste'), findsNothing);
    expect(find.text('2 pieces'), findsOneWidget);
  });
}
