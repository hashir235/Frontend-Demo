import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/models/window_type.dart';
import 'package:my_app/features/estimation/presentation/input/window_input_base.dart';
import 'package:my_app/features/estimation/state/estimate_session_store.dart';
import 'package:my_app/features/tutorial/tutorial_controller.dart';
import 'package:my_app/features/tutorial/tutorial_overlay.dart';
import 'package:my_app/features/tutorial/tutorial_step.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The framework tests use a toy screen. These pump a real one.
///
/// The tour shipped once already as a fully written thing that showed nothing,
/// because no screen had been wired to it. A passing framework test would not
/// have caught that -- only pumping an actual app screen does.
const WindowType _slidingNode = WindowType(
  label: 'Sliding Window',
  graphicKey: 'sliding_basic',
  children: <WindowType>[],
  displayIndex: 1,
  codeName: 'S_win',
);

EstimateSessionStore _session() => EstimateSessionStore(
  projectName: 'Test Project',
  projectLocation: 'Test Location',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TutorialController.instance.finish();
  });

  tearDown(() => TutorialController.instance.finish());

  Future<void> pumpInput(WidgetTester t) async {
    await t.pumpWidget(
      MaterialApp(
        home: WindowInputScreen(node: _slidingNode, session: _session()),
      ),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 250));
  }

  testWidgets('the window input screen takes part in the tour', (
    WidgetTester t,
  ) async {
    await pumpInput(t);

    // Nothing before it starts -- the screen must look untouched.
    expect(find.text('یونٹ'), findsNothing);

    TutorialController.instance.start(
      steps: const <TutorialStep>[
        TutorialStep(
          screen: TutorialScreen.windowInput,
          targetId: 'input.unit',
          title: 'یونٹ',
          body: 'یہاں سے یونٹ چنیں',
        ),
      ],
    );
    await t.pumpAndSettle();

    // The bubble is painted over the real screen, not a stand-in.
    expect(find.text('یونٹ'), findsOneWidget);
    expect(find.text('یہاں سے یونٹ چنیں'), findsOneWidget);
    expect(find.text('چھوڑ دیں'), findsOneWidget);
  });

  testWidgets('a step meant for another screen stays hidden here', (
    WidgetTester t,
  ) async {
    await pumpInput(t);

    TutorialController.instance.start(
      steps: const <TutorialStep>[
        TutorialStep(
          screen: TutorialScreen.actualBill,
          title: 'بل',
          body: 'یہ بل والے صفحے کی بات ہے',
        ),
      ],
    );
    await t.pumpAndSettle();

    // Window input must not paint the bill screen's step.
    expect(find.text('بل'), findsNothing);
  });

  testWidgets('a pushed screen takes over, so the tour does not stall', (
    WidgetTester t,
  ) async {
    // The bug this guards: Home stayed mounted under the screen the user had
    // moved to and kept reporting itself as visible, so every later step was
    // hidden and the tour looked like it had simply ended after Estimation.
    final GlobalKey<NavigatorState> nav = GlobalKey<NavigatorState>();
    await t.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        home: const TutorialOverlay(
          screen: TutorialScreen.home,
          child: Scaffold(body: Center(child: Text('home'))),
        ),
      ),
    );
    await t.pumpAndSettle();

    TutorialController.instance.start(
      steps: const <TutorialStep>[
        TutorialStep(
          screen: TutorialScreen.projectMenu,
          title: 'نیا پروجیکٹ',
          body: 'یہاں سے شروع کریں',
        ),
      ],
    );
    await t.pumpAndSettle();

    // Home must not paint a step belonging to the next screen.
    expect(find.text('نیا پروجیکٹ'), findsNothing);

    nav.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const TutorialOverlay(
          screen: TutorialScreen.projectMenu,
          child: Scaffold(body: Center(child: Text('menu'))),
        ),
      ),
    );
    await t.pumpAndSettle();

    // Now that it is on top, the step shows.
    expect(find.text('نیا پروجیکٹ'), findsOneWidget);
  });

  testWidgets('skip leaves the real screen usable again', (
    WidgetTester t,
  ) async {
    await pumpInput(t);
    TutorialController.instance.start(
      steps: const <TutorialStep>[
        TutorialStep(
          screen: TutorialScreen.windowInput,
          targetId: 'input.unit',
          title: 'یونٹ',
          body: 'یہاں سے یونٹ چنیں',
        ),
      ],
    );
    await t.pumpAndSettle();

    await t.tap(find.text('چھوڑ دیں'));
    await t.pumpAndSettle();

    expect(find.text('یونٹ'), findsNothing);
    expect(TutorialController.instance.isRunning, isFalse);
    // The screen's own controls are back.
    expect(find.byKey(const Key('open_settings_drawer_button')), findsOneWidget);
  });
}
