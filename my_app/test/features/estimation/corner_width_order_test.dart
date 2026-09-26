import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/models/window_type.dart';
import 'package:my_app/features/estimation/presentation/input/window_input_base.dart';
import 'package:my_app/features/estimation/state/estimate_session_store.dart';
import 'package:my_app/features/settings/state/app_settings.dart';
import 'package:my_app/features/settings/state/size_input_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A corner window has two widths, and they sit the way the window stands:
/// the left width on the left, the right width on the right, with the height
/// straight after -- on screen and for "Next" alike.
void main() {
  const WindowType cornerFix = WindowType(
    label: 'Corner Fix',
    graphicKey: 'fix_basic',
    children: <WindowType>[],
    displayIndex: 3,
    codeName: 'FC_win',
  );

  Finder fieldByLabel(String label) => find.byWidgetPredicate(
    (Widget widget) =>
        widget is TextField && widget.decoration?.labelText == label,
  );

  bool focused(WidgetTester tester, String label) =>
      tester.widget<TextField>(fieldByLabel(label)).focusNode?.hasFocus ?? false;

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WindowInputScreen(
          node: cornerFix,
          session: EstimateSessionStore(
            projectName: 'Corner Test',
            projectLocation: 'Lahore',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppSettings.instance.setSizeInputMode(SizeInputMode.mergedKeypad);
  });

  testWidgets('left width on the left, right width on the right, on one line', (
    WidgetTester tester,
  ) async {
    await open(tester);

    final Offset left = tester.getTopLeft(fieldByLabel('Left Width'));
    final Offset right = tester.getTopLeft(fieldByLabel('Right Width'));
    final Offset height = tester.getTopLeft(fieldByLabel('Height'));

    expect(left.dx, lessThan(right.dx), reason: 'left width is the left box');
    expect(left.dy, closeTo(right.dy, 1), reason: 'the two widths share a line');
    expect(height.dy, greaterThan(left.dy), reason: 'the height comes after them');
  });

  testWidgets('"Next" goes left width, right width, then height', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await tester.ensureVisible(fieldByLabel('Left Width'));
    await tester.pumpAndSettle();
    await tester.tap(fieldByLabel('Left Width'));
    await tester.pumpAndSettle();
    expect(focused(tester, 'Left Width'), isTrue);

    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    expect(focused(tester, 'Right Width'), isTrue);

    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    expect(focused(tester, 'Height'), isTrue);
  });
}
