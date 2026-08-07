import 'package:flutter/foundation.dart';

import '../models/flow_step.dart';

/// What tapping a bubble is allowed to do.
enum FlowTapAction {
  /// Already behind us: pop back to it.
  goBack,

  /// The very next step: run the screen's own next action.
  goNext,

  /// Where we already are.
  none,

  /// Further ahead than the next step, or a step whose screen cannot be built
  /// from here. Shown, but inert.
  blocked,
}

/// Where the user is in the current journey.
///
/// Lives outside the widget tree because a journey spans a stack of pushed
/// routes: the bar on the invoice screen has to know the user came through
/// Library and Size Input, which no single screen can tell it.
///
/// Nothing here navigates. It answers "what is allowed from here", and the bar
/// asks the screen to actually move.
class FlowProgress extends ChangeNotifier {
  FlowProgress._internal();

  static final FlowProgress instance = FlowProgress._internal();

  AppFlow? _flow;
  int _currentIndex = 0;

  /// The deepest step reached in this journey. Going back does not lower it --
  /// someone who reached the invoice and stepped back to Library has still
  /// been to the invoice.
  int _furthestIndex = 0;

  AppFlow? get flow => _flow;
  int get currentIndex => _currentIndex;
  int get furthestIndex => _furthestIndex;

  /// True once there is anything to draw. On Home that is a single bubble; the
  /// chain grows once a journey is picked.
  bool get isActive => _flow != null && _flow!.steps.isNotEmpty;

  FlowStep? get currentStep {
    final AppFlow? flow = _flow;
    if (flow == null || _currentIndex >= flow.steps.length) return null;
    return flow.steps[_currentIndex];
  }

  /// Starts a journey. Called when the user picks Estimation, Fabrication, a
  /// glass project or a settings page.
  void enter(AppFlow flow) {
    _flow = flow;
    _currentIndex = 0;
    _furthestIndex = 0;
    notifyListeners();
  }

  /// A screen reporting that it is now on top.
  ///
  /// Screens call this on build, so it has to be cheap and silent when nothing
  /// changed -- otherwise every rebuild would notify and rebuild the bar again.
  void arriveAt(String stepId) {
    final AppFlow? flow = _flow;
    if (flow == null) return;
    final int index = flow.indexOf(stepId);
    if (index < 0 || index == _currentIndex) return;

    _currentIndex = index;
    if (index > _furthestIndex) _furthestIndex = index;
    notifyListeners();
  }

  /// Leaves the journey -- back at Home with nothing in progress.
  void exit() {
    if (_flow == null) return;
    _flow = null;
    _currentIndex = 0;
    _furthestIndex = 0;
    notifyListeners();
  }

  /// What a tap on the bubble at [index] should do.
  ///
  /// Backwards is always open: the user has been there, and the screens are
  /// still on the stack underneath. Forwards is one step at a time -- each
  /// screen builds the next one from live state, so skipping ahead would mean
  /// arriving somewhere with nothing to show.
  FlowTapAction actionFor(int index, {required bool hasNextAction}) {
    final AppFlow? flow = _flow;
    if (flow == null || index < 0 || index >= flow.steps.length) {
      return FlowTapAction.blocked;
    }
    if (index == _currentIndex) return FlowTapAction.none;
    if (index < _currentIndex) return FlowTapAction.goBack;
    if (index == _currentIndex + 1 && hasNextAction) {
      return FlowTapAction.goNext;
    }
    return FlowTapAction.blocked;
  }

  /// True for steps the user has already worked through.
  bool isDone(int index) => index < _currentIndex;

  @visibleForTesting
  void resetForTest() {
    _flow = null;
    _currentIndex = 0;
    _furthestIndex = 0;
  }
}
