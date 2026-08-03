import 'package:flutter/widgets.dart';

import 'tutorial_controller.dart';

/// Marks a widget the tour can point at.
///
/// Wrap the real widget -- the Estimation button, a collar card, the Next arrow
/// -- and give it the same [id] the matching [TutorialStep] uses. Outside the
/// tour this adds nothing but a key, so it is safe to leave in place.
class TutorialTarget extends StatefulWidget {
  final String id;
  final Widget child;

  const TutorialTarget({super.key, required this.id, required this.child});

  @override
  State<TutorialTarget> createState() => _TutorialTargetState();
}

class _TutorialTargetState extends State<TutorialTarget> {
  final GlobalKey _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    TutorialController.instance.registerTarget(widget.id, _key);
  }

  @override
  void didUpdateWidget(TutorialTarget old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) {
      TutorialController.instance.unregisterTarget(old.id, _key);
      TutorialController.instance.registerTarget(widget.id, _key);
    }
  }

  @override
  void dispose() {
    TutorialController.instance.unregisterTarget(widget.id, _key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _key, child: widget.child);
  }
}
