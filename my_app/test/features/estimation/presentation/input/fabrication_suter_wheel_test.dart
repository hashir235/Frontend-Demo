import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/features/estimation/models/window_type.dart';
import 'package:my_app/features/estimation/state/estimate_session_store.dart';
import 'package:my_app/features/estimation/presentation/input/window_input_base.dart';
import 'package:my_app/shared/widgets/suter_wheel.dart';

const WindowType _slidingNode = WindowType(
  label: 'Sliding Window',
  graphicKey: 'sliding_basic',
  children: <WindowType>[],
  displayIndex: 1,
  codeName: 'S_win',
);

EstimateSessionStore _fabricationSession() => EstimateSessionStore(
  projectName: 'Test Project',
  projectLocation: 'Test Location',
  flow: EstimateFlow.fabrication,
);

Finder _fieldByLabel(String label) => find.byWidgetPredicate(
  (Widget widget) =>
      widget is TextField && widget.decoration?.labelText == label,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'fabrication inch mode shows the suter wheel, not a suter text box',
    (WidgetTester tester) async {
      final EstimateSessionStore session = _fabricationSession();
      await tester.pumpWidget(
        MaterialApp(
          home: WindowInputScreen(node: _slidingNode, session: session),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // Switch this fabrication flow to inch.suter mode.
      await tester.tap(find.byKey(const Key('open_settings_drawer_button')));
      await tester.pumpAndSettle();
      // The sidebar scrolls now that it carries more options, so the unit
      // buttons can sit below the fold on a small screen.
      await tester.ensureVisible(find.byKey(const Key('unit_inches_radio')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('unit_inches_radio')));
      await tester.pumpAndSettle();

      // Inch is still typed…
      expect(_fieldByLabel('Height (Inch)'), findsOneWidget);
      expect(_fieldByLabel('Width (Inch)'), findsOneWidget);
      // …but suter is a tape wheel now, and there is no suter text box.
      expect(find.byType(SuterWheel), findsNWidgets(2));
      expect(_fieldByLabel('Suter'), findsNothing);
    },
  );

  testWidgets(
    'saving captures the typed inch and the wheel-picked suter',
    (WidgetTester tester) async {
      final EstimateSessionStore session = _fabricationSession();
      await tester.pumpWidget(
        MaterialApp(
          home: WindowInputScreen(node: _slidingNode, session: session),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      await tester.tap(find.byKey(const Key('open_settings_drawer_button')));
      await tester.pumpAndSettle();
      // The sidebar scrolls now that it carries more options, so the unit
      // buttons can sit below the fold on a small screen.
      await tester.ensureVisible(find.byKey(const Key('unit_inches_radio')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('unit_inches_radio')));
      await tester.pumpAndSettle();
      // Close the settings end-drawer, otherwise its modal barrier keeps
      // covering the form and the save-button tap can never land.
      await tester.tapAt(const Offset(10, 400));
      await tester.pumpAndSettle();

      await tester.enterText(_fieldByLabel('Height (Inch)'), '45');
      await tester.enterText(_fieldByLabel('Width (Inch)'), '30');

      // Drive the height wheel to half a suter through its own callback — this
      // is what a drag/tap ultimately does, without fighting the overlay tab in
      // the test. The width wheel is left untouched (suter 0).
      final Finder wheels = find.byType(SuterWheel);
      tester.widget<SuterWheel>(wheels.first).onChanged(0.5);
      await tester.pump();

      await tester.tap(find.byKey(const Key('input_save_button')));
      await tester.pumpAndSettle();

      expect(session.items, hasLength(1));
      final heightValue = session.items.single.heightValue;
      // Height is 45 inch and carries a non-zero suter from the wheel…
      expect(heightValue.startsWith('45'), isTrue);
      expect(heightValue, isNot('45.0'));
      // …while the untouched width wheel stays at suter 0.
      expect(session.items.single.widthValue, '30.0');
    },
  );
}
