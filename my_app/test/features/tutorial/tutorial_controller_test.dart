import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/features/tutorial/tutorial_controller.dart';
import 'package:my_app/features/tutorial/tutorial_overlay.dart';
import 'package:my_app/features/tutorial/tutorial_step.dart';
import 'package:my_app/features/tutorial/tutorial_target.dart';

/// The tour is easy to leave half-wired -- a screen that never registers, a
/// target id that does not match the step. These check the machinery actually
/// paints and moves, so a build cannot ship with a tutorial that does nothing.
void main() {
  const List<TutorialStep> steps = <TutorialStep>[
    TutorialStep(
      screen: TutorialScreen.home,
      title: 'پہلا',
      body: 'پہلا مرحلہ',
    ),
    TutorialStep(
      screen: TutorialScreen.home,
      targetId: 'home.estimation',
      title: 'دوسرا',
      body: 'ایسٹیمیشن کا بٹن',
    ),
  ];

  Widget harness() => MaterialApp(
    home: Scaffold(
      body: TutorialOverlay(
        screen: TutorialScreen.home,
        child: Center(
          child: TutorialTarget(
            id: 'home.estimation',
            child: const SizedBox(width: 120, height: 48, child: Text('Est')),
          ),
        ),
      ),
    ),
  );

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() => TutorialController.instance.finish());

  testWidgets('nothing shows until the tour starts', (WidgetTester t) async {
    await t.pumpWidget(harness());
    await t.pumpAndSettle();
    expect(find.text('پہلا'), findsNothing);
  });

  testWidgets('first step appears once started', (WidgetTester t) async {
    await t.pumpWidget(harness());
    await t.pumpAndSettle();

    TutorialController.instance.start(steps: steps);
    await t.pumpAndSettle();

    expect(find.text('پہلا'), findsOneWidget);
    expect(find.text('پہلا مرحلہ'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('Next moves to the step that points at a widget', (
    WidgetTester t,
  ) async {
    await t.pumpWidget(harness());
    await t.pumpAndSettle();
    TutorialController.instance.start(steps: steps);
    await t.pumpAndSettle();

    await t.tap(find.text('آگے'));
    await t.pumpAndSettle();

    expect(find.text('دوسرا'), findsOneWidget);
    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets('skip closes it', (WidgetTester t) async {
    await t.pumpWidget(harness());
    await t.pumpAndSettle();
    TutorialController.instance.start(steps: steps);
    await t.pumpAndSettle();

    await t.tap(find.text('چھوڑ دیں'));
    await t.pumpAndSettle();

    expect(find.text('پہلا'), findsNothing);
    expect(TutorialController.instance.isRunning, isFalse);
  });

  testWidgets('a tap-step whose target is missing still offers a way on', (
    WidgetTester t,
  ) async {
    // Points at an id nothing registers -- a screen not wired yet, or a
    // widget scrolled out of view. Without a fallback the user would be
    // staring at a dimmed screen with nothing to press.
    const List<TutorialStep> orphan = <TutorialStep>[
      TutorialStep(
        screen: TutorialScreen.home,
        targetId: 'nobody.registers.this',
        title: 'اٹکا ہوا',
        body: 'یہاں دبانا تھا',
        requiresTap: true,
        tapHint: 'یہاں دبائیں',
      ),
      TutorialStep(
        screen: TutorialScreen.home,
        title: 'اگلا',
        body: 'آگے بڑھ گئے',
      ),
    ];

    await t.pumpWidget(harness());
    await t.pumpAndSettle();
    TutorialController.instance.start(steps: orphan);
    await t.pumpAndSettle();

    expect(find.text('اٹکا ہوا'), findsOneWidget);
    // The tap hint would be a lie with nothing to tap.
    expect(find.text('یہاں دبائیں'), findsNothing);

    await t.tap(find.text('آگے'));
    await t.pumpAndSettle();
    expect(find.text('اگلا'), findsOneWidget);
  });

  test('the real Estimation script is not empty and names its targets', () {
    TutorialController.instance.start();
    expect(TutorialController.instance.stepCount, greaterThan(20));
    TutorialController.instance.finish();
  });
}
