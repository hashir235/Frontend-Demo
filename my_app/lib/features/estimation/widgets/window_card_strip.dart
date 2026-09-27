import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// One line of window cards, swiped sideways.
///
/// It replaces a page view that moved one card per swipe however hard the
/// swipe was, which made hunting for a window feel like work: a fling here
/// runs on with its own momentum across as many cards as it carries, then
/// settles on the nearest one, and even a gentle flick moves on a card. The
/// next card always shows at the edge, so there is plainly more to see.
///
/// Always a single line, whatever the width -- a wider screen shows more
/// cards side by side, never a second line of them.
class WindowCardStrip extends StatefulWidget {
  const WindowCardStrip({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.height = 330,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double height;

  /// The gap between two cards.
  static const double gap = AppTheme.space4;

  /// How wide a card is in a strip [available] wide: most of a phone's
  /// width, so the next card peeks in, and a steady size on anything wider.
  static double cardWidthFor(double available) {
    if (available >= 560) return 250;
    return (available * 0.8).clamp(200.0, 280.0);
  }

  @override
  State<WindowCardStrip> createState() => _WindowCardStripState();
}

class _WindowCardStripState extends State<WindowCardStrip> {
  final ScrollController _controller = ScrollController();

  static const double _shadowRoom = 8;

  /// The card at the start of the strip -- what the dots show.
  int _leading = 0;
  double _extent = 1;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final ScrollPosition position = _controller.position;
    // At the very end the last card is the one in full view, even though
    // the strip cannot scroll it to the start.
    final int leading = position.pixels >= position.maxScrollExtent - 1
        ? widget.itemCount - 1
        : (position.pixels / _extent).round().clamp(0, widget.itemCount - 1);
    if (leading != _leading) setState(() => _leading = leading);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double cardWidth = WindowCardStrip.cardWidthFor(constraints.maxWidth);
        _extent = cardWidth + WindowCardStrip.gap;
        final bool scrolls =
            widget.itemCount * _extent - WindowCardStrip.gap > constraints.maxWidth;
        return Column(
          children: <Widget>[
            SizedBox(
              // Room above and below for a card's shadow, which the strip
              // would otherwise cut off square.
              height: widget.height + _shadowRoom * 2,
              child: ListView.builder(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(vertical: _shadowRoom),
                physics: CardSnapScrollPhysics(
                  extent: _extent,
                  parent: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                ),
                itemExtent: _extent,
                itemCount: widget.itemCount,
                itemBuilder: (BuildContext context, int index) => Padding(
                  padding: const EdgeInsets.only(right: WindowCardStrip.gap),
                  child: widget.itemBuilder(context, index),
                ),
              ),
            ),
            if (scrolls && widget.itemCount > 1) ...<Widget>[
              const SizedBox(height: AppTheme.space4),
              _Dots(count: widget.itemCount, active: _leading),
            ],
          ],
        );
      },
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppTheme.space2,
      runSpacing: AppTheme.space2,
      children: List<Widget>.generate(count, (int index) {
        final bool on = index == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: on ? 22 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: on
                ? AppTheme.royalBlue
                : AppTheme.royalBlue.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

/// Scrolls freely with a fling's own momentum, then comes to rest with a card
/// at the start of the strip.
///
/// Where the fling would have stopped is worked out first, and the nearest
/// card to that is where it settles -- so a hard fling crosses several cards
/// and a light one crosses one. A flick too light to reach the next card on
/// its own still moves to it: that is what the flick was for.
class CardSnapScrollPhysics extends ScrollPhysics {
  const CardSnapScrollPhysics({required this.extent, super.parent});

  /// One card and its gap.
  final double extent;

  /// How quickly a fling slows. Lower runs further.
  static const double _drag = 0.1;

  @override
  CardSnapScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      CardSnapScrollPhysics(extent: extent, parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    // Pulled past either end: the parent springs it back.
    if ((velocity <= 0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final Tolerance tolerance = toleranceFor(position);
    final double here = position.pixels / extent;
    final double projected =
        (position.pixels - velocity / math.log(_drag)) / extent;
    double card = projected.roundToDouble();
    if (velocity.abs() > tolerance.velocity) {
      // A flick always moves on at least to the next card its way.
      card = velocity > 0
          ? math.max(card, here.floorToDouble() + 1)
          : math.min(card, here.ceilToDouble() - 1);
    }
    final double target = (card * extent).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() < tolerance.distance) return null;
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: tolerance,
    );
  }

  @override
  bool get allowImplicitScrolling => false;
}
