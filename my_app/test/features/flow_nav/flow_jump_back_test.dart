import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/flow_nav/models/flow_step.dart';
import 'package:my_app/features/flow_nav/presentation/flow_progress_bar.dart';
import 'package:my_app/features/flow_nav/state/flow_progress.dart';

/// The point of the chain is that a step already done is a place you can go
/// back to in one tap. Falling back to "one screen at a time" would make it a
/// picture of progress rather than a way to move.
void main() {
  final FlowProgress progress = FlowProgress.instance;

  setUp(progress.resetForTest);

  /// A stand-in screen that reports its step, exactly as the real ones do.
  Widget screen(String stepId, {VoidCallback? onNext}) {
    return Scaffold(
      body: Center(child: Text('screen:$stepId')),
      bottomNavigationBar: FlowProgressBar(stepId: stepId, onNext: onNext),
    );
  }

  /// Walks the estimation flow the way a user does: each step pushed as a
  /// named route on top of the last.
  Future<GlobalKey<NavigatorState>> walkTo(
    WidgetTester tester,
    List<FlowStep> steps,
  ) async {
    final GlobalKey<NavigatorState> nav = GlobalKey<NavigatorState>();
    progress.enter(estimationFlow);

    await tester.pumpWidget(
      MaterialApp(navigatorKey: nav, home: screen(FlowSteps.home.id)),
    );
    await tester.pumpAndSettle();

    for (final FlowStep step in steps) {
      nav.currentState!.push(
        MaterialPageRoute<void>(
          settings: RouteSettings(name: step.id),
          builder: (_) => screen(step.id),
        ),
      );
      await tester.pumpAndSettle();
    }
    return nav;
  }

  testWidgets('tapping a step three back lands there, not one screen back', (
    WidgetTester tester,
  ) async {
    await walkTo(tester, <FlowStep>[
      FlowSteps.projects,
      FlowSteps.library,
      FlowSteps.sizeInput,
      FlowSteps.review,
      FlowSteps.lengthOptimization,
    ]);

    expect(
      find.text('screen:${FlowSteps.lengthOptimization.id}'),
      findsOneWidget,
    );

    // Library is three stops behind. One tap has to get there.
    await tester.tap(find.text(FlowSteps.library.label).first);
    await tester.pumpAndSettle();

    expect(find.text('screen:${FlowSteps.library.id}'), findsOneWidget);
    expect(progress.currentStep?.id, FlowSteps.library.id);
  });

  testWidgets('the chain still knows how far the user got', (
    WidgetTester tester,
  ) async {
    await walkTo(tester, <FlowStep>[
      FlowSteps.projects,
      FlowSteps.library,
      FlowSteps.sizeInput,
      FlowSteps.review,
    ]);
    final int deepest = progress.furthestIndex;

    await tester.tap(find.text(FlowSteps.projects.label).first);
    await tester.pumpAndSettle();

    expect(progress.currentStep?.id, FlowSteps.projects.id);
    expect(
      progress.furthestIndex,
      deepest,
      reason: 'going back must not forget the work already done',
    );
  });

  testWidgets('Home ends the journey rather than leaving a stale chain', (
    WidgetTester tester,
  ) async {
    await walkTo(tester, <FlowStep>[
      FlowSteps.projects,
      FlowSteps.library,
      FlowSteps.sizeInput,
    ]);

    await tester.tap(find.text(FlowSteps.home.label).first);
    await tester.pumpAndSettle();

    expect(find.text('screen:${FlowSteps.home.id}'), findsOneWidget);
  });

  testWidgets('a step further ahead than the next one does nothing', (
    WidgetTester tester,
  ) async {
    await walkTo(tester, <FlowStep>[FlowSteps.projects, FlowSteps.library]);

    // Invoice is far ahead; its screen cannot be built from here.
    await tester.tap(find.text(FlowSteps.invoice.label).first);
    await tester.pumpAndSettle();

    expect(find.text('screen:${FlowSteps.library.id}'), findsOneWidget);
    expect(progress.currentStep, FlowSteps.library);
  });

  testWidgets('the next step runs the screen own next action', (
    WidgetTester tester,
  ) async {
    final GlobalKey<NavigatorState> nav = GlobalKey<NavigatorState>();
    bool nextCalled = false;
    progress.enter(estimationFlow);

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        home: screen(FlowSteps.home.id, onNext: () => nextCalled = true),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(FlowSteps.projects.label).first);
    await tester.pumpAndSettle();

    expect(nextCalled, isTrue);
  });
}
