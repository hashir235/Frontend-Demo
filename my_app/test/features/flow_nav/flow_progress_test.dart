import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/flow_nav/models/flow_step.dart';
import 'package:my_app/features/flow_nav/state/flow_progress.dart';

/// The chain is a promise to the user: it says where they are and what they
/// may do next. These pin the rules that promise depends on.
void main() {
  final FlowProgress progress = FlowProgress.instance;

  setUp(progress.resetForTest);

  test('nothing is drawn until a journey has been picked', () {
    expect(progress.flow, isNull);
    expect(progress.isActive, isFalse);
  });

  test('entering a flow starts at Home', () {
    progress.enter(estimationFlow);

    expect(progress.isActive, isTrue);
    expect(progress.currentStep, FlowSteps.home);
    expect(progress.currentIndex, 0);
  });

  test('arriving moves the chain along and records the depth reached', () {
    progress.enter(estimationFlow);
    progress.arriveAt(FlowSteps.library.id);

    expect(progress.currentStep, FlowSteps.library);
    expect(progress.furthestIndex, estimationFlow.indexOf('library'));
  });

  test('stepping back does not undo how far the user has been', () {
    progress.enter(estimationFlow);
    progress.arriveAt(FlowSteps.invoice.id);
    final int deepest = progress.furthestIndex;

    progress.arriveAt(FlowSteps.library.id);

    expect(progress.currentStep, FlowSteps.library);
    expect(progress.furthestIndex, deepest);
  });

  test('a step from another flow is ignored', () {
    // Glass has no Bill Inputs; reporting it must not move the chain.
    progress.enter(glassFlow);
    progress.arriveAt(FlowSteps.billInputs.id);

    expect(progress.currentStep, FlowSteps.home);
  });

  group('what a tap may do', () {
    setUp(() {
      progress.enter(estimationFlow);
      progress.arriveAt(FlowSteps.rates.id);
    });

    int indexOf(FlowStep step) => estimationFlow.indexOf(step.id);

    test('any earlier step can be jumped back to', () {
      for (final FlowStep step in <FlowStep>[
        FlowSteps.home,
        FlowSteps.projects,
        FlowSteps.library,
        FlowSteps.sizeInput,
        FlowSteps.review,
        FlowSteps.lengthOptimization,
      ]) {
        expect(
          progress.actionFor(indexOf(step), hasNextAction: true),
          FlowTapAction.goBack,
          reason: '${step.label} is behind us and should be reachable',
        );
      }
    });

    test('the step we are on does nothing', () {
      expect(
        progress.actionFor(indexOf(FlowSteps.rates), hasNextAction: true),
        FlowTapAction.none,
      );
    });

    test('the very next step runs the screen forward', () {
      expect(
        progress.actionFor(indexOf(FlowSteps.material), hasNextAction: true),
        FlowTapAction.goNext,
      );
    });

    test('a middle step cannot be skipped', () {
      // From Rates, the invoice is four steps away. Letting someone land there
      // would mean arriving at a bill built from nothing.
      for (final FlowStep step in <FlowStep>[
        FlowSteps.billInputs,
        FlowSteps.invoice,
        FlowSteps.finish,
      ]) {
        expect(
          progress.actionFor(indexOf(step), hasNextAction: true),
          FlowTapAction.blocked,
          reason: '${step.label} is more than one step ahead',
        );
      }
    });

    test('the next step is inert while the screen is not ready', () {
      // No next action means the screen cannot move on yet -- nothing selected,
      // nothing saved -- so the bubble must not pretend otherwise.
      expect(
        progress.actionFor(indexOf(FlowSteps.material), hasNextAction: false),
        FlowTapAction.blocked,
      );
    });
  });

  test('from the invoice every earlier step is reachable', () {
    progress.enter(estimationFlow);
    progress.arriveAt(FlowSteps.invoice.id);

    for (int i = 0; i < estimationFlow.indexOf(FlowSteps.invoice.id); i++) {
      expect(
        progress.actionFor(i, hasNextAction: true),
        FlowTapAction.goBack,
        reason: '${estimationFlow.steps[i].label} should be reachable',
      );
    }
  });

  test('leaving clears the chain', () {
    progress.enter(estimationFlow);
    progress.arriveAt(FlowSteps.review.id);
    progress.exit();

    expect(progress.flow, isNull);
    expect(progress.isActive, isFalse);
  });

  group('the flows themselves', () {
    test('estimation ends at the invoice, then home', () {
      expect(estimationFlow.steps.last, FlowSteps.finish);
      expect(
        estimationFlow.steps[estimationFlow.steps.length - 2],
        FlowSteps.invoice,
      );
      expect(estimationFlow.steps, contains(FlowSteps.review));
    });

    test('fabrication ends at the glass layout and never bills', () {
      expect(fabricationFlow.steps.last, FlowSteps.finish);
      expect(
        fabricationFlow.steps[fabricationFlow.steps.length - 2],
        FlowSteps.glassLayout,
      );
      expect(fabricationFlow.steps, isNot(contains(FlowSteps.billInputs)));
      expect(fabricationFlow.steps, isNot(contains(FlowSteps.invoice)));
    });

    test('a glass-only project skips all the aluminium steps', () {
      expect(glassFlow.steps, <FlowStep>[
        FlowSteps.home,
        FlowSteps.projects,
        FlowSteps.glassSize,
        FlowSteps.glassLayout,
        FlowSteps.finish,
      ]);
    });

    test('a settings page is three steps from home', () {
      final AppFlow flow = settingsFlowFor(FlowSteps.rateSettings);

      expect(flow.steps, <FlowStep>[
        FlowSteps.home,
        FlowSteps.settings,
        FlowSteps.rateSettings,
      ]);
    });

    test('the two working flows start the same way', () {
      expect(
        estimationFlow.steps.take(5).toList(),
        fabricationFlow.steps.take(5).toList(),
      );
    });

    test('no flow repeats a step id, or the chain would fold on itself', () {
      for (final AppFlow flow in <AppFlow>[
        estimationFlow,
        fabricationFlow,
        glassFlow,
      ]) {
        final Set<String> ids = flow.steps.map((FlowStep s) => s.id).toSet();
        expect(ids, hasLength(flow.steps.length), reason: '${flow.kind}');
      }
    });

    test('every abbreviation says what it stands for', () {
      for (final FlowStep step in <FlowStep>[
        FlowSteps.projects,
      ]) {
        expect(step.meaning, isNotNull);
        expect(step.spoken, isNot(step.label));
      }
    });
  });
}
