import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/features/estimation/models/window_type.dart';
import 'package:my_app/features/estimation/presentation/input/window_input_base.dart';
import 'package:my_app/features/estimation/models/window_review_item.dart';
import 'package:my_app/features/estimation/state/estimate_session_store.dart';

Finder _textFieldByLabel(String label) {
  return find.byWidgetPredicate(
    (Widget widget) =>
        widget is TextField && widget.decoration?.labelText == label,
  );
}

EstimateSessionStore _testSession() => EstimateSessionStore(
  projectName: 'Test Project',
  projectLocation: 'Test Location',
);

const WindowType _slidingNode = WindowType(
  label: 'Sliding Window',
  graphicKey: 'sliding_basic',
  children: <WindowType>[],
  displayIndex: 1,
  codeName: 'S_win',
);

const WindowType _openableNode = WindowType(
  label: 'Openable Window',
  graphicKey: 'openable_basic',
  children: <WindowType>[],
  displayIndex: 2,
  codeName: 'O_win',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'last required size field saves from keyboard action',
    (WidgetTester tester) async {
      final EstimateSessionStore session = _testSession();

      await tester.pumpWidget(
        MaterialApp(
          home: WindowInputScreen(node: _slidingNode, session: session),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final Finder heightField = _textFieldByLabel('Height');
      final Finder widthField = _textFieldByLabel('Width');
      final Finder descriptionField = _textFieldByLabel(
        'Description (Optional)',
      );

      await tester.tap(heightField);
      await tester.pump();
      await tester.enterText(heightField, '45.7');
      tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();

      expect(
        tester.widget<TextField>(widthField).focusNode?.hasFocus,
        isTrue,
      );

      await tester.enterText(widthField, '22.4');
      tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(session.items, hasLength(1));
      expect(session.items.single.heightValue, '45.7');
      expect(session.items.single.widthValue, '22.4');
      expect(
        tester.widget<TextField>(descriptionField).focusNode?.hasFocus,
        isFalse,
      );
      expect(find.text('winNo: 2'), findsOneWidget);
    },
  );

  testWidgets(
    'save button clears fields immediately and refocuses first input',
    (WidgetTester tester) async {
      final EstimateSessionStore session = _testSession();

      await tester.pumpWidget(
        MaterialApp(
          home: WindowInputScreen(node: _slidingNode, session: session),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final Finder heightField = _textFieldByLabel('Height');
      final Finder widthField = _textFieldByLabel('Width');
      final Finder descriptionField = _textFieldByLabel(
        'Description (Optional)',
      );

      await tester.enterText(heightField, '48.7');
      await tester.enterText(widthField, '30.4');
      await tester.enterText(descriptionField, 'north room');
      await tester.tap(find.byKey(const Key('input_save_button')));
      await tester.pump();

      expect(session.items, hasLength(1));
      expect(session.items.single.heightValue, '48.7');
      expect(session.items.single.widthValue, '30.4');
      expect(session.items.single.description, 'north room');

      expect(
        tester.widget<TextField>(heightField).controller?.text,
        isEmpty,
      );
      expect(
        tester.widget<TextField>(widthField).controller?.text,
        isEmpty,
      );
      expect(
        tester.widget<TextField>(descriptionField).controller?.text,
        isEmpty,
      );

      await tester.pump(const Duration(milliseconds: 120));

      expect(
        tester.widget<TextField>(heightField).focusNode?.hasFocus,
        isTrue,
      );
      expect(find.text('winNo: 2'), findsOneWidget);
    },
  );

  testWidgets(
    'restores saved unit mode when reopening the same flow',
    (WidgetTester tester) async {
      Future<void> pumpInput(EstimateSessionStore session) async {
        await tester.pumpWidget(
          MaterialApp(
            home: WindowInputScreen(node: _openableNode, session: session),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
      }

      await pumpInput(
        EstimateSessionStore(
          projectName: 'Test Project',
          projectLocation: 'Test Location',
          flow: EstimateFlow.fabrication,
        ),
      );

      await tester.tap(find.byKey(const Key('open_settings_drawer_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('unit_inches_radio')));
      await tester.pumpAndSettle();

      final SegmentedButton<UnitMode> beforeRestart =
          tester.widget<SegmentedButton<UnitMode>>(
            find.byKey(const Key('unit_segmented_control')),
          );
      expect(beforeRestart.selected, <UnitMode>{UnitMode.inches});

      await pumpInput(
        EstimateSessionStore(
          projectName: 'Test Project',
          projectLocation: 'Test Location',
          flow: EstimateFlow.fabrication,
        ),
      );

      await tester.tap(find.byKey(const Key('open_settings_drawer_button')));
      await tester.pumpAndSettle();

      final SegmentedButton<UnitMode> afterRestart =
          tester.widget<SegmentedButton<UnitMode>>(
            find.byKey(const Key('unit_segmented_control')),
          );
      expect(afterRestart.selected, <UnitMode>{UnitMode.inches});
    },
  );
}
