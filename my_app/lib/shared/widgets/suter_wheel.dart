import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';

/// Immutable configuration that turns the generic [_TapeWheel] into a specific
/// unit picker. [SuterWheel] and [InchWheel] are thin wrappers over the same
/// wheel body + magnified tape, differing only in range, step and the symbol
/// printed after the number.
class _TapeSpec {
  final double min;
  final double max;
  final double step;

  /// Printed right after the value, e.g. `'''` (suter) or `''` (inch).
  final String unitSuffix;

  /// Compact wheel: pixels the mini tape travels per 1.0 unit.
  final double bodyPxPerUnit;

  /// Magnified tab: pixels the tape travels per 1.0 unit.
  final double tapePxPerUnit;

  /// Formats a snapped value for display (e.g. `3` / `3.5` for suter, `9` for
  /// inch).
  final String Function(double) format;

  const _TapeSpec({
    required this.min,
    required this.max,
    required this.step,
    required this.unitSuffix,
    required this.bodyPxPerUnit,
    required this.tapePxPerUnit,
    required this.format,
  });

  double snap(double value) {
    if (!value.isFinite) {
      return min;
    }
    final double snapped = (value / step).roundToDouble() * step;
    return snapped.clamp(min, max);
  }
}

/// A horizontal "inchi tape" wheel for picking the **suter** part of a size.
///
/// The user drags the wheel left or right (like pulling a measuring tape) and
/// the value snaps to the tape's real resolution — half a suter (0, 0.5 … 7.5).
/// While the finger is on the wheel, a glassmorphism tab pops up above it
/// showing a magnified tape with numbered tick lines, exactly like the suter
/// edge of a real inchi tape.
///
/// Quick taps on the left/right half of the wheel nudge the value by ±0.5 for
/// fine adjustment. The wheel can never produce an invalid suter, so the old
/// "Suter must be less than 8" validation can never trigger from here.
class SuterWheel extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final String label;

  const SuterWheel({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Suter',
  });

  static const double min = 0;
  static const double max = 7.5;
  static const double step = 0.5;

  /// Snaps any value onto the tape's half-suter resolution.
  static double snap(double value) {
    if (!value.isFinite) {
      return 0;
    }
    final double snapped = (value * 2).roundToDouble() / 2;
    return snapped.clamp(min, max);
  }

  /// `3` for whole values, `3.5` for halves — the shop's own notation.
  static String format(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return _TapeWheel(
      value: value,
      onChanged: onChanged,
      label: label,
      spec: const _TapeSpec(
        min: min,
        max: max,
        step: step,
        unitSuffix: "'''",
        bodyPxPerUnit: 56,
        tapePxPerUnit: 88,
        format: SuterWheel.format,
      ),
    );
  }
}

/// The same tape wheel tuned for the **inch** part of a feet-mode size: whole
/// inches from 0 to 11 (12 inches makes the next foot, which the user types).
class InchWheel extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final String label;

  const InchWheel({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Inch',
  });

  static const double min = 0;
  static const double max = 11;
  static const double step = 1;

  /// Snaps onto whole inches, 0..11.
  static double snap(double value) {
    if (!value.isFinite) {
      return 0;
    }
    return value.roundToDouble().clamp(min, max);
  }

  static String format(double value) => value.round().toString();

  @override
  Widget build(BuildContext context) {
    return _TapeWheel(
      value: value,
      onChanged: onChanged,
      label: label,
      spec: const _TapeSpec(
        min: min,
        max: max,
        step: step,
        unitSuffix: "''",
        bodyPxPerUnit: 30,
        tapePxPerUnit: 52,
        format: InchWheel.format,
      ),
    );
  }
}

class _TapeWheel extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final String label;
  final _TapeSpec spec;

  const _TapeWheel({
    required this.value,
    required this.onChanged,
    required this.label,
    required this.spec,
  });

  @override
  State<_TapeWheel> createState() => _TapeWheelState();
}

class _TapeWheelState extends State<_TapeWheel>
    with SingleTickerProviderStateMixin {
  _TapeSpec get _spec => widget.spec;

  final LayerLink _link = LayerLink();
  final OverlayPortalController _tapeTab = OverlayPortalController();

  late double _live = _spec.snap(widget.value);
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Animation<double>? _settleAnim;
  Timer? _hideTimer;
  int _lastHapticNotch = 0;

  @override
  void initState() {
    super.initState();
    _lastHapticNotch = (_live / _spec.step).round();
    _settle.addListener(() {
      final Animation<double>? anim = _settleAnim;
      if (anim == null) {
        return;
      }
      setState(() => _live = anim.value);
    });
  }

  @override
  void didUpdateWidget(_TapeWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Follow external changes (e.g. a reset), but never fight the finger.
    if (widget.value != oldWidget.value &&
        !_settle.isAnimating &&
        _spec.snap(widget.value) != _spec.snap(_live)) {
      _live = _spec.snap(widget.value);
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _settle.dispose();
    super.dispose();
  }

  void _showTape() {
    _hideTimer?.cancel();
    if (!_tapeTab.isShowing) {
      _tapeTab.show();
    }
  }

  void _scheduleHideTape() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted && _tapeTab.isShowing) {
        _tapeTab.hide();
      }
    });
  }

  void _setLive(double value) {
    final double clamped = value.clamp(_spec.min, _spec.max);
    // Tick like a real gear wheel every time a notch is crossed.
    final int notch = (clamped / _spec.step).round();
    if (notch != _lastHapticNotch) {
      _lastHapticNotch = notch;
      HapticFeedback.selectionClick();
    }
    setState(() => _live = clamped);
  }

  void _commit(double target) {
    final double snapped = _spec.snap(target);
    _settleAnim = Tween<double>(begin: _live, end: snapped).animate(
      CurvedAnimation(parent: _settle, curve: Curves.easeOutCubic),
    );
    _settle.forward(from: 0);
    if (snapped != _spec.snap(widget.value)) {
      widget.onChanged(snapped);
    }
    _scheduleHideTape();
  }

  void _onDragStart(DragStartDetails details) {
    _settle.stop();
    _showTape();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    // Dragging right pulls the tape right, so the value under the pointer
    // decreases — the same direction a real tape moves.
    _setLive(_live - details.delta.dx / _spec.bodyPxPerUnit);
  }

  void _onDragEnd(DragEndDetails details) {
    final double velocity = details.velocity.pixelsPerSecond.dx;
    // Short glide in the fling direction, then snap to the nearest notch.
    final double projected = _live - (velocity / _spec.bodyPxPerUnit) * 0.14;
    _commit(projected);
  }

  void _nudge(double delta) {
    _settle.stop();
    _showTape();
    HapticFeedback.selectionClick();
    final double target =
        (_spec.snap(_live) + delta).clamp(_spec.min, _spec.max);
    _lastHapticNotch = (target / _spec.step).round();
    _commit(target);
  }

  void _onTapUp(TapUpDetails details, double width) {
    final double dx = details.localPosition.dx;
    if (dx < width / 2 - 12) {
      _nudge(-_spec.step);
    } else if (dx > width / 2 + 12) {
      _nudge(_spec.step);
    } else {
      _showTape();
      _scheduleHideTape();
    }
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _tapeTab,
      overlayChildBuilder: (BuildContext context) {
        final double screenWidth = MediaQuery.sizeOf(context).width;
        final double tabWidth = screenWidth.clamp(0, 372) - 24;
        return Positioned(
          width: tabWidth,
          child: CompositedTransformFollower(
            link: _link,
            targetAnchor: Alignment.topCenter,
            followerAnchor: Alignment.bottomCenter,
            offset: const Offset(0, -10),
            child: IgnorePointer(
              child: _TapeTab(live: _live, label: widget.label, spec: _spec),
            ),
          ),
        );
      },
      child: CompositedTransformTarget(
        link: _link,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double width = constraints.maxWidth;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: _onDragStart,
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: _onDragEnd,
              onTapUp: (TapUpDetails details) => _onTapUp(details, width),
              child: _WheelBody(live: _live, label: widget.label, spec: _spec),
            );
          },
        ),
      ),
    );
  }
}

/// The compact glass wheel that sits where the old suter box used to be.
class _WheelBody extends StatelessWidget {
  final double live;
  final String label;
  final _TapeSpec spec;

  const _WheelBody({
    required this.live,
    required this.label,
    required this.spec,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Colors.white.withValues(alpha: 0.68),
                AppTheme.ice.withValues(alpha: 0.42),
              ],
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.85),
              width: 1.2,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppTheme.royalBlue.withValues(alpha: 0.10),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: <Widget>[
              // Moving mini tape in the lower half of the wheel.
              Positioned.fill(
                child: CustomPaint(
                  painter: _MiniTicksPainter(live: live, spec: spec),
                ),
              ),
              // Label + big live value.
              Positioned(
                top: 5,
                left: 10,
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: AppTheme.slate.withValues(alpha: 0.85),
                  ),
                ),
              ),
              Positioned(
                top: 2,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    "${spec.format(spec.snap(live))}${spec.unitSuffix}",
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.deepTeal,
                    ),
                  ),
                ),
              ),
              // Scroll affordance chevrons.
              Positioned(
                left: 2,
                top: 0,
                bottom: 14,
                child: Icon(
                  Icons.chevron_left_rounded,
                  size: 17,
                  color: AppTheme.slate.withValues(alpha: 0.45),
                ),
              ),
              Positioned(
                right: 2,
                top: 0,
                bottom: 14,
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 17,
                  color: AppTheme.slate.withValues(alpha: 0.45),
                ),
              ),
              // Centre pointer over the mini tape.
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 2.4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppTheme.royalBlue,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppTheme.royalBlue.withValues(alpha: 0.45),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The magnified glass tape that appears above the wheel while scrolling.
/// Kept deliberately compact so it does not cover the field above it.
class _TapeTab extends StatelessWidget {
  final double live;
  final String label;
  final _TapeSpec spec;

  const _TapeTab({
    required this.live,
    required this.label,
    required this.spec,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 74,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Colors.white.withValues(alpha: 0.88),
                  AppTheme.mist.withValues(alpha: 0.74),
                ],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.9),
                width: 1.2,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppTheme.inkBlue.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: <Widget>[
                Positioned.fill(
                  child: CustomPaint(
                    painter: _TapePainter(live: live, spec: spec),
                  ),
                ),
                // Soft fades on both edges, like the tape sliding out of view.
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 30,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          Colors.white.withValues(alpha: 0.9),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: 30,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: <Color>[
                          Colors.white.withValues(alpha: 0.9),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                // Current value pill.
                Positioned(
                  top: 6,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.royalBlue,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: AppTheme.royalBlue.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        "$label ${spec.format(spec.snap(live))}${spec.unitSuffix}",
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                // Centre pointer line + notch.
                Positioned(
                  top: 22,
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 2.4,
                      decoration: BoxDecoration(
                        color: AppTheme.royalBlue.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small moving tick strip inside the compact wheel.
class _MiniTicksPainter extends CustomPainter {
  final double live;
  final _TapeSpec spec;

  const _MiniTicksPainter({required this.live, required this.spec});

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double bottom = size.height - 3;
    final Paint whole = Paint()
      ..color = AppTheme.slate.withValues(alpha: 0.55)
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round;
    final Paint half = Paint()
      ..color = AppTheme.slate.withValues(alpha: 0.34)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    for (double v = spec.min; v <= spec.max + 0.001; v += spec.step) {
      final double x = cx + (v - live) * spec.bodyPxPerUnit;
      if (x < -8 || x > size.width + 8) {
        continue;
      }
      final bool isWhole = v == v.roundToDouble();
      canvas.drawLine(
        Offset(x, bottom),
        Offset(x, bottom - (isWhole ? 14 : 8)),
        isWhole ? whole : half,
      );
    }
  }

  @override
  bool shouldRepaint(_MiniTicksPainter oldDelegate) =>
      oldDelegate.live != live || oldDelegate.spec != spec;
}

/// The magnified tape scale: numbered lines just like a real inchi tape —
/// tall lines on whole units, shorter lines on halves, numbers above.
class _TapePainter extends CustomPainter {
  final double live;
  final _TapeSpec spec;

  const _TapePainter({required this.live, required this.spec});

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double bottom = size.height - 6;

    final Paint base = Paint()
      ..color = AppTheme.inkBlue.withValues(alpha: 0.55)
      ..strokeWidth = 1.4;
    canvas.drawLine(Offset(0, bottom), Offset(size.width, bottom), base);

    final Paint whole = Paint()
      ..color = AppTheme.inkBlue.withValues(alpha: 0.88)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final Paint half = Paint()
      ..color = AppTheme.slate.withValues(alpha: 0.75)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (double v = spec.min; v <= spec.max + 0.001; v += spec.step) {
      final double x = cx + (v - live) * spec.tapePxPerUnit;
      if (x < -30 || x > size.width + 30) {
        continue;
      }
      final bool isWhole = v == v.roundToDouble();
      final double tickHeight = isWhole ? 24 : 15;
      canvas.drawLine(
        Offset(x, bottom),
        Offset(x, bottom - tickHeight),
        isWhole ? whole : half,
      );

      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: spec.format(v),
          style: TextStyle(
            fontSize: isWhole ? 11 : 8.5,
            fontWeight: isWhole ? FontWeight.w800 : FontWeight.w600,
            color: isWhole
                ? AppTheme.inkBlue
                : AppTheme.slate.withValues(alpha: 0.9),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(x - tp.width / 2, bottom - tickHeight - tp.height - 2),
      );
    }
  }

  @override
  bool shouldRepaint(_TapePainter oldDelegate) =>
      oldDelegate.live != live || oldDelegate.spec != spec;
}
