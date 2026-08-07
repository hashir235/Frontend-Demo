import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/flow_step.dart';
import '../state/flow_progress.dart';

/// A chain of frosted bubbles across the bottom of the screen, showing how far
/// through a job the user is.
///
/// The one they are on is large and lit; the ones behind are small and dim but
/// still tappable; the ones ahead are barely there. Tapping backwards pops to
/// that screen, tapping the next bubble runs whatever the current screen does
/// when you press on.
///
/// [onNext] is supplied by the screen rather than worked out here on purpose:
/// each screen already knows how to build the one after it, from live state
/// the bar has no business reaching into. Null means the screen is not ready
/// to move on, and the next bubble stays inert.
class FlowProgressBar extends StatefulWidget {
  /// Which step this screen is. Reported on build so the bar can follow the
  /// user across a stack of pushed routes.
  final String stepId;

  /// Runs the current screen's own "carry on" action.
  final VoidCallback? onNext;

  /// Pops back to [stepId]'s route. Defaults to popping until the route with
  /// that name, which is what every screen in the flow wants.
  final void Function(BuildContext context, FlowStep step)? onJumpBack;

  const FlowProgressBar({
    super.key,
    required this.stepId,
    this.onNext,
    this.onJumpBack,
  });

  @override
  State<FlowProgressBar> createState() => _FlowProgressBarState();
}

class _FlowProgressBarState extends State<FlowProgressBar> {
  final FlowProgress _progress = FlowProgress.instance;
  final ScrollController _scroll = ScrollController();
  final GlobalKey _currentKey = GlobalKey();

  static const double _currentSize = 46;
  static const double _doneSize = 30;
  static const double _slot = 78;

  @override
  void initState() {
    super.initState();
    _progress.addListener(_onChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }

  @override
  void didUpdateWidget(FlowProgressBar old) {
    super.didUpdateWidget(old);
    if (old.stepId != widget.stepId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _report());
    }
  }

  @override
  void dispose() {
    _progress.removeListener(_onChange);
    _scroll.dispose();
    super.dispose();
  }

  /// Only the screen actually on top may claim the current step; a screen left
  /// mounted underneath a pushed route must not drag the bar back to itself.
  ///
  /// Called on every build, not just on first mount. Popping back reveals a
  /// screen that is already mounted, so initState never runs again -- without
  /// this the chain stayed pointing at the step the user had just left, and a
  /// jump back looked like it had done nothing.
  ///
  /// Cheap to repeat: arriveAt returns immediately when the step has not
  /// changed.
  void _report() {
    if (!mounted) return;
    final ModalRoute<Object?>? route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    _progress.arriveAt(widget.stepId);
  }

  void _onChange() {
    if (mounted) setState(() => _centreOnCurrent());
  }

  void _centreOnCurrent() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? ctx = _currentKey.currentContext;
      if (ctx == null || !_scroll.hasClients) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _handleTap(int index, FlowStep step) {
    final FlowTapAction action = _progress.actionFor(
      index,
      hasNextAction: widget.onNext != null,
    );
    switch (action) {
      case FlowTapAction.goNext:
        widget.onNext?.call();
      case FlowTapAction.goBack:
        if (widget.onJumpBack != null) {
          widget.onJumpBack!(context, step);
        } else {
          _popTo(step);
        }
      case FlowTapAction.none:
      case FlowTapAction.blocked:
        break;
    }
  }

  /// Routes in a flow are named after their step, so going back is a pop to
  /// that name. Home is the first route, which has no name of its own.
  void _popTo(FlowStep step) {
    final NavigatorState navigator = Navigator.of(context);
    if (step.id == FlowSteps.home.id) {
      navigator.popUntil((Route<dynamic> route) => route.isFirst);
      _progress.exit();
      return;
    }
    navigator.popUntil(
      (Route<dynamic> route) => route.settings.name == step.id || route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Re-claim after a pop brings this screen back to the top.
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());

    final AppFlow? flow = _progress.flow;
    if (flow == null || !_progress.isActive) {
      return const SizedBox.shrink();
    }

    final EdgeInsets safe = MediaQuery.paddingOf(context);

    // No panel, no bar, no border: the bubbles sit straight on the page and
    // the screen shows through between them. A frosted strip behind them read
    // as a footer bolted to the bottom, which is exactly what this is not.
    return Padding(
      padding: EdgeInsets.fromLTRB(6, 6, 6, 8 + safe.bottom),
      child: SizedBox(
        height: 74,
        child: SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              for (int i = 0; i < flow.steps.length; i++)
                _buildNode(context, flow, i),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNode(BuildContext context, AppFlow flow, int index) {
    final FlowStep step = flow.steps[index];
    final bool isCurrent = index == _progress.currentIndex;
    final bool isDone = _progress.isDone(index);
    final FlowTapAction action = _progress.actionFor(
      index,
      hasNextAction: widget.onNext != null,
    );
    final bool tappable =
        action == FlowTapAction.goBack || action == FlowTapAction.goNext;

    // The whole node takes the tap -- label included. Someone aiming at a step
    // aims at the word as often as at the circle, and a name that looks like a
    // button but ignores you is worse than no name at all.
    return SizedBox(
      width: _slot,
      child: Semantics(
        button: tappable,
        selected: isCurrent,
        label: step.spoken,
        child: Tooltip(
          message: step.meaning ?? step.label,
          waitDuration: const Duration(milliseconds: 600),
          child: InkWell(
            onTap: tappable ? () => _handleTap(index, step) : null,
            borderRadius: BorderRadius.circular(18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _buildLabel(step, isCurrent: isCurrent, isDone: isDone),
                const SizedBox(height: 5),
                Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    // The connectors sit behind the circle and run the full
                    // slot, so the chain reads as one line rather than as
                    // separate dashes.
                    Positioned.fill(
                      child: _Connectors(
                        showLeft: index > 0,
                        showRight: index < flow.steps.length - 1,
                        leftDone: index <= _progress.currentIndex,
                        rightDone: index < _progress.currentIndex,
                      ),
                    ),
                    _Bubble(
                      key: isCurrent ? _currentKey : null,
                      step: step,
                      size: isCurrent ? _currentSize : _doneSize,
                      isCurrent: isCurrent,
                      isDone: isDone,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(
    FlowStep step, {
    required bool isCurrent,
    required bool isDone,
  }) {
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      style: TextStyle(
        fontSize: isCurrent ? 11 : 9.5,
        // Light, as asked: the label names the stop, the bubble carries the
        // weight.
        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
        color: isCurrent
            ? AppTheme.royalBlue
            : AppTheme.slate.withValues(alpha: isDone ? 0.72 : 0.38),
        height: 1.1,
      ),
      child: Text(
        step.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// What a screen hands to `Scaffold.bottomNavigationBar`.
///
/// Several screens already keep action buttons down there -- PDF, Recalc,
/// Share. Those stay put; the chain sits under them, so one line at each call
/// site covers both instead of every screen assembling its own Column.
class FlowBottomBar extends StatelessWidget {
  final String stepId;
  final VoidCallback? onNext;

  /// The screen's existing bottom actions, if it has any.
  final Widget? actions;

  const FlowBottomBar({
    super.key,
    required this.stepId,
    this.onNext,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ?actions,
        FlowProgressBar(stepId: stepId, onNext: onNext),
      ],
    );
  }
}

/// The line running left and right out of a bubble.
class _Connectors extends StatelessWidget {
  final bool showLeft;
  final bool showRight;
  final bool leftDone;
  final bool rightDone;

  const _Connectors({
    required this.showLeft,
    required this.showRight,
    required this.leftDone,
    required this.rightDone,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: _segment(showLeft, leftDone)),
        Expanded(child: _segment(showRight, rightDone)),
      ],
    );
  }

  Widget _segment(bool show, bool done) {
    if (!show) return const SizedBox.shrink();
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        height: done ? 2.4 : 1.6,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          color: done
              ? AppTheme.royalBlue.withValues(alpha: 0.45)
              : AppTheme.slate.withValues(alpha: 0.20),
        ),
      ),
    );
  }
}

/// A single frosted circle.
///
/// The blur lives here rather than behind the whole row: with no panel, each
/// bubble has to be its own piece of glass, taking its colour from whatever it
/// happens to be floating over.
///
/// Taps are handled by the node around it, so the whole thing -- label and
/// circle -- is one target.
class _Bubble extends StatelessWidget {
  final FlowStep step;
  final double size;
  final bool isCurrent;
  final bool isDone;

  const _Bubble({
    super.key,
    required this.step,
    required this.size,
    required this.isCurrent,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    final Color ink = isCurrent
        ? Colors.white
        : isDone
        ? AppTheme.royalBlue.withValues(alpha: 0.78)
        : AppTheme.slate.withValues(alpha: 0.42);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isCurrent
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[AppTheme.royalBlue, AppTheme.deepTeal],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Colors.white.withValues(alpha: isDone ? 0.95 : 0.65),
                  Colors.white.withValues(alpha: isDone ? 0.70 : 0.40),
                ],
              ),
        border: Border.all(
          color: isCurrent
              ? Colors.white.withValues(alpha: 0.90)
              : isDone
              ? AppTheme.royalBlue.withValues(alpha: 0.34)
              : AppTheme.slate.withValues(alpha: 0.18),
          width: isCurrent ? 1.8 : 1.1,
        ),
        // Always exactly one shadow, transparent when there should be none.
        // A list that changes length between states cannot be tweened, and
        // AnimatedContainer asserts rather than animating.
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: isCurrent
                ? AppTheme.royalBlue.withValues(alpha: 0.42)
                : isDone
                ? AppTheme.royalBlue.withValues(alpha: 0.12)
                : Colors.transparent,
            blurRadius: isCurrent ? 16 : 7,
            spreadRadius: isCurrent ? 1 : 0,
            offset: Offset(0, isCurrent ? 4 : 2),
          ),
        ],
      ),
      child: Center(
        child: Icon(step.icon, size: isCurrent ? 22 : 15, color: ink),
      ),
    );
  }
}
