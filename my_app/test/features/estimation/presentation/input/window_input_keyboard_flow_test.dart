import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/features/estimation/models/window_type.dart';
import 'package:my_app/features/estimation/presentation/input/window_input_base.dart';
import 'package:my_app/shared/widgets/option_switch.dart';
import 'package:my_app/features/estimation/state/estimate_session_store.dart';

Finder _textFieldByLabel(String label) {
  return find.byWidgetPredicate(
    (Widget widget) =>
        widget is TextField && widget.decoration?.labelText == label,
  );
}

/// Estimation opens in inches, where a size is a typed inch box plus a suter
/// box -- hence the unit in the label. Sizes are typed rather than picked on
/// the wheel by default, so the suter is part of the keyboard chain: next goes
/// inch, suter, inch, suter, quantity, description. Leaving the suter boxes
/// empty means the saved value comes back as whole inches, `45` -> `45.0`.
const String _heightLabel = 'Height (Inch)';
const String _widthLabel = 'Width (Inch)';

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

  // Description is the last stop in the keyboard chain -- that is what makes it
  // reachable without leaving the keyboard -- so it is the field that carries
  // "done", and the save happens there rather than on the last size field.
  testWidgets('keyboard action walks the fields and the last one saves', (
    WidgetTester tester,
  ) async {
    final EstimateSessionStore session = _testSession();

    await tester.pumpWidget(
      MaterialApp(
        home: WindowInputScreen(node: _slidingNode, session: session),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final Finder heightField = _textFieldByLabel(_heightLabel);
    final Finder widthField = _textFieldByLabel(_widthLabel);
    final Finder suterField = _textFieldByLabel('Suter');
    final Finder quantityField = _textFieldByLabel('Quantity (Optional)');
    final Finder descriptionField = _textFieldByLabel('Description (Optional)');

    // The size fields sit under the pinned Save bar on a short screen, so a
    // raw tap lands on the bar instead of the field.
    await tester.ensureVisible(heightField);
    await tester.pumpAndSettle();
    await tester.tap(heightField);
    await tester.pump();
    await tester.enterText(heightField, '45');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();

    // A size is two boxes, so next goes to the suter beside the inch it was
    // typed in -- not past it to the next measurement.
    expect(
      tester.widget<TextField>(suterField.at(0)).focusNode?.hasFocus,
      isTrue,
    );

    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(tester.widget<TextField>(widthField).focusNode?.hasFocus, isTrue);

    await tester.enterText(widthField, '22');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(
      tester.widget<TextField>(suterField.at(1)).focusNode?.hasFocus,
      isTrue,
    );

    // Quantity comes before the description: it belongs with the measurement.
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(
      tester.widget<TextField>(quantityField).focusNode?.hasFocus,
      isTrue,
    );

    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();

    // Nothing is saved on the way through.
    expect(
      tester.widget<TextField>(descriptionField).focusNode?.hasFocus,
      isTrue,
    );
    expect(session.items, isEmpty);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(session.items, hasLength(1));
    expect(session.items.single.heightValue, '45.0');
    expect(session.items.single.widthValue, '22.0');
    // Saving hands the keyboard back to the first field for the next window.
    expect(
      tester.widget<TextField>(descriptionField).focusNode?.hasFocus,
      isFalse,
    );
    expect(tester.widget<TextField>(heightField).focusNode?.hasFocus, isTrue);
    expect(find.text('winNo: 2'), findsOneWidget);
  });

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

      final Finder heightField = _textFieldByLabel(_heightLabel);
      final Finder widthField = _textFieldByLabel(_widthLabel);
      final Finder descriptionField = _textFieldByLabel(
        'Description (Optional)',
      );

      await tester.enterText(heightField, '48');
      await tester.enterText(widthField, '30');
      await tester.enterText(descriptionField, 'north room');
      await tester.tap(find.byKey(const Key('input_save_button')));
      await tester.pump();

      expect(session.items, hasLength(1));
      expect(session.items.single.heightValue, '48.0');
      expect(session.items.single.widthValue, '30.0');
      expect(session.items.single.description, 'north room');

      expect(tester.widget<TextField>(heightField).controller?.text, isEmpty);
      expect(tester.widget<TextField>(widthField).controller?.text, isEmpty);
      expect(
        tester.widget<TextField>(descriptionField).controller?.text,
        isEmpty,
      );

      await tester.pump(const Duration(milliseconds: 120));

      expect(tester.widget<TextField>(heightField).focusNode?.hasFocus, isTrue);
      expect(find.text('winNo: 2'), findsOneWidget);
    },
  );

  testWidgets('restores saved unit mode when reopening the same flow', (
    WidgetTester tester,
  ) async {
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

    // Unit sits on the input page now, not behind the Sections panel, so
    // there is no drawer to open first.
    await tester.ensureVisible(find.byKey(const Key('unit_inches_radio')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('unit_inches_radio')));
    await tester.pumpAndSettle();

    // The one tapped is the one selected. Selection is drawn as colour and
    // weight now rather than as a tick, so the flag is what to assert on.
    expect(
      tester
          .widget<OptionSwitch>(find.byKey(const Key('unit_inches_radio')))
          .selected,
      isTrue,
    );

    await pumpInput(
      EstimateSessionStore(
        projectName: 'Test Project',
        projectLocation: 'Test Location',
        flow: EstimateFlow.fabrication,
      ),
    );

    // The unit chips are on the page, so the saved mode has to be showing as
    // selected without opening anything.
    await tester.ensureVisible(find.byKey(const Key('unit_inches_radio')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<OptionSwitch>(find.byKey(const Key('unit_inches_radio')))
          .selected,
      isTrue,
    );
  });
}
