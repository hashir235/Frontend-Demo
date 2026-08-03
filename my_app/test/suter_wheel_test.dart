import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/shared/widgets/suter_wheel.dart';

void main() {
  group('SuterWheel.snap', () {
    test('rounds to the nearest half suter and clamps to the tape', () {
      expect(SuterWheel.snap(3.24), 3.0);
      expect(SuterWheel.snap(3.26), 3.5);
      expect(SuterWheel.snap(-2), 0);
      expect(SuterWheel.snap(7.9), 7.5);
      expect(SuterWheel.snap(double.nan), 0);
    });
  });

  group('SuterWheel.format', () {
    test('whole values drop the decimal, halves keep one digit', () {
      expect(SuterWheel.format(0), '0');
      expect(SuterWheel.format(3), '3');
      expect(SuterWheel.format(3.5), '3.5');
      expect(SuterWheel.format(7.5), '7.5');
    });
  });

  Future<void> pumpWheel(
    WidgetTester tester, {
    required double value,
    required ValueChanged<double> onChanged,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 180,
              child: SuterWheel(value: value, onChanged: onChanged),
            ),
          ),
        ),
      ),
    );
  }

  // Lets the settle animation (220ms) and the tape-tab hide timer (700ms)
  // finish so no timers are pending when the test ends.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 800));
  }

  testWidgets('tapping the right half nudges up by half a suter', (
    WidgetTester tester,
  ) async {
    double? changed;
    await pumpWheel(tester, value: 2, onChanged: (double v) => changed = v);

    final Offset center = tester.getCenter(find.byType(SuterWheel));
    await tester.tapAt(center + const Offset(46, 0));
    await settle(tester);

    expect(changed, 2.5);
  });

  testWidgets('tapping the left half at 0 stays clamped and reports nothing', (
    WidgetTester tester,
  ) async {
    double? changed;
    await pumpWheel(tester, value: 0, onChanged: (double v) => changed = v);

    final Offset center = tester.getCenter(find.byType(SuterWheel));
    await tester.tapAt(center - const Offset(46, 0));
    await settle(tester);

    expect(changed, isNull);
  });
}
