import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'tutorial_controller.dart';
import 'tutorial_step.dart';
import 'urdu_text.dart';

/// Wraps a screen so the guided tour can dim it and cut a hole around whatever
/// it is explaining.
///
/// Every screen that takes part wraps its body in one of these and names itself
/// via [screen]. The overlay paints nothing until the tour reaches a step that
/// belongs to this screen.
class TutorialOverlay extends StatefulWidget {
  final TutorialScreen screen;
  final Widget child;

  const TutorialOverlay({super.key, required this.screen, required this.child});

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay> {
  final TutorialController _c = TutorialController.instance;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _claimIfOnTop());
  }

  /// A pushed screen leaves the one below it mounted, and that one keeps
  /// rebuilding. Without this check Home would go on insisting it was the
  /// visible screen after the user had moved past it, and every later step
  /// would stay hidden -- the tour looked like it had simply stopped.
  void _claimIfOnTop() {
    if (!mounted) return;
    final ModalRoute<Object?>? route = ModalRoute.of(context);
    if (route == null || route.isCurrent) {
      _c.setVisibleScreen(widget.screen);
    }
  }

  @override
  void dispose() {
    _c.removeListener(_onChange);
    _c.clearVisibleScreen(widget.screen);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  /// Where the highlighted widget sits in global coordinates, or null when it
  /// is not on screen (not laid out yet, or scrolled out of view).
  Rect? _targetRect(TutorialStep step) {
    final GlobalKey? key = _c.targetKey(step.targetId);
    final RenderObject? box = key?.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final Offset topLeft = box.localToGlobal(Offset.zero);
    return Rect.fromLTWH(
      topLeft.dx,
      topLeft.dy,
      box.size.width,
      box.size.height,
    ).inflate(step.padding);
  }

  @override
  Widget build(BuildContext context) {
    // Re-claim after a pop brings this screen back to the top.
    WidgetsBinding.instance.addPostFrameCallback((_) => _claimIfOnTop());

    final TutorialStep? step = _c.visibleStep;
    if (step == null) return widget.child;

    final Rect? rect = step.targetId == null ? null : _targetRect(step);

    return Stack(
      children: <Widget>[
        widget.child,
        Positioned.fill(
          child: _SpotlightLayer(
            step: step,
            targetRect: rect,
            index: _c.index,
            total: _c.stepCount,
            onNext: _c.next,
            onBack: _c.index > 0 ? _c.back : null,
            onSkip: _c.skip,
          ),
        ),
      ],
    );
  }
}

class _SpotlightLayer extends StatelessWidget {
  final TutorialStep step;
  final Rect? targetRect;
  final int index;
  final int total;
  final VoidCallback onNext;
  final VoidCallback? onBack;
  final VoidCallback onSkip;

  const _SpotlightLayer({
    required this.step,
    required this.targetRect,
    required this.index,
    required this.total,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
  });

  /// A step can ask the user to tap the thing it is pointing at -- but only if
  /// that thing is actually on screen. When the target is missing (not laid
  /// out, scrolled away, or simply never wired up) the step falls back to a
  /// Next button, otherwise there would be nothing to tap and no way forward.
  bool get _awaitingTap => step.requiresTap && targetRect != null;

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.sizeOf(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);

    return Stack(
      children: <Widget>[
        // The dimmer. While waiting for a tap the hole is left live so the
        // real widget underneath still receives it.
        Positioned.fill(
          child: IgnorePointer(
            ignoring: _awaitingTap,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _awaitingTap ? null : onNext,
              child: CustomPaint(
                painter: _SpotlightPainter(rect: targetRect, shape: step.shape),
                size: screen,
              ),
            ),
          ),
        ),

        // A ring around the cutout so the target reads as "this one".
        if (targetRect != null)
          Positioned(
            left: targetRect!.left,
            top: targetRect!.top,
            width: targetRect!.width,
            height: targetRect!.height,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: step.shape == SpotlightShape.circle
                      ? null
                      : BorderRadius.circular(12),
                  shape: step.shape == SpotlightShape.circle
                      ? BoxShape.circle
                      : BoxShape.rectangle,
                  border: Border.all(color: AppTheme.tealAccent, width: 2.4),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppTheme.tealAccent.withValues(alpha: 0.55),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),

        _bubble(context, screen, safe),

        // Skip stays reachable at every step.
        Positioned(
          top: safe.top + 8,
          right: 12,
          child: TextButton(
            onPressed: onSkip,
            style: TextButton.styleFrom(
              backgroundColor: Colors.black.withValues(alpha: 0.45),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text('چھوڑ دیں', style: UrduText.body(color: Colors.white, fontSize: 14)),
          ),
        ),
      ],
    );
  }

  /// The caption. Sits on whichever side of the target has more room, so it
  /// never covers the thing it is pointing at.
  Widget _bubble(BuildContext context, Size screen, EdgeInsets safe) {
    const double margin = 16;
    final double maxW = screen.width - margin * 2;

    double? top;
    double? bottom;
    if (targetRect == null) {
      top = screen.height * 0.32;
    } else {
      final double spaceBelow = screen.height - targetRect!.bottom;
      final double spaceAbove = targetRect!.top;
      if (spaceBelow >= spaceAbove) {
        top = targetRect!.bottom + 18;
      } else {
        bottom = screen.height - targetRect!.top + 18;
      }
    }

    return Positioned(
      left: margin,
      right: margin,
      top: top,
      bottom: bottom,
      child: UrduDirection(
        child: Container(
          constraints: BoxConstraints(maxWidth: maxW),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 26,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(step.title, style: UrduText.heading()),
              const SizedBox(height: 6),
              Text(step.body, style: UrduText.body()),
              if (step.tapHint != null && _awaitingTap) ...<Widget>[
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.touch_app_rounded,
                      size: 18,
                      color: AppTheme.tealAccent,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        step.tapHint!,
                        style: UrduText.caption(color: AppTheme.tealAccent),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Text('${index + 1} / $total', style: UrduText.caption()),
                  const Spacer(),
                  if (onBack != null)
                    TextButton(
                      onPressed: onBack,
                      child: Text('پیچھے', style: UrduText.body(fontSize: 14)),
                    ),
                  if (!_awaitingTap) ...<Widget>[
                    const SizedBox(width: 4),
                    FilledButton(
                      onPressed: onNext,
                      child: Text(
                        index + 1 == total ? 'ختم' : 'آگے',
                        style: UrduText.body(color: Colors.white, fontSize: 15),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fills the screen with a scrim and punches a hole over the target.
class _SpotlightPainter extends CustomPainter {
  final Rect? rect;
  final SpotlightShape shape;

  const _SpotlightPainter({required this.rect, required this.shape});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint scrim = Paint()..color = const Color(0xCC061021);
    final Path full = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    if (rect == null) {
      canvas.drawPath(full, scrim);
      return;
    }

    final Path hole = Path();
    if (shape == SpotlightShape.circle) {
      hole.addOval(Rect.fromCircle(center: rect!.center, radius: rect!.longestSide / 2));
    } else {
      hole.addRRect(RRect.fromRectAndRadius(rect!, const Radius.circular(12)));
    }

    canvas.drawPath(
      Path.combine(PathOperation.difference, full, hole),
      scrim,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.rect != rect || old.shape != shape;
}
