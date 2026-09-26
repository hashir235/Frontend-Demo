import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';

/// One part of an [ArrangeableColumn].
class ArrangeableBlock {
  /// Stays the same wherever the part is moved; the saved order is made of
  /// these.
  final String id;

  final Widget child;

  /// Parts that sit close together when they meet -- rows of chips -- as they
  /// read as one control.
  final bool compact;

  /// No gap after this part: a heading whose own height is its spacing.
  final bool tight;

  const ArrangeableBlock({
    required this.id,
    required this.child,
    this.compact = false,
    this.tight = false,
  });
}

/// A column whose parts can be held and dragged up or down, the way app icons
/// are moved on a phone's home screen.
///
/// Hold a part still for a moment and it lifts off the screen and follows the
/// finger; the others make room as it passes, and letting go drops it there.
/// Near the top or bottom of the screen the page scrolls along with it.
///
/// Nothing else about the parts changes. They are the same widgets, laid out
/// the same way, and keep everything typed into them while they move --
/// taps, typing and scrolling work as before, and a quick swipe still scrolls.
class ArrangeableColumn extends StatefulWidget {
  /// The parts, in the order they stand.
  final List<ArrangeableBlock> blocks;

  /// The ids in their new order, once a part has been dropped somewhere new.
  final ValueChanged<List<String>> onReorder;

  final double gap;
  final double compactGap;

  /// How long a part is held before it lifts.
  ///
  /// Shorter than a text box's own long press (half a second), so holding a
  /// size box moves the box rather than selecting what is typed in it; long
  /// enough that a tap, or a finger resting while reading, does not.
  final Duration holdDuration;

  const ArrangeableColumn({
    super.key,
    required this.blocks,
    required this.onReorder,
    this.gap = 14,
    this.compactGap = 8,
    this.holdDuration = const Duration(milliseconds: 400),
  });

  @override
  State<ArrangeableColumn> createState() => _ArrangeableColumnState();
}

class _ArrangeableColumnState extends State<ArrangeableColumn> {
  final Map<String, GlobalKey> _keys = <String, GlobalKey>{};

  /// The part being carried, and the order while it is carried.
  String? _dragId;
  List<String>? _order;

  /// Where the finger is, and where on the part it took hold, both global.
  Offset _finger = Offset.zero;
  Offset _grab = Offset.zero;
  Size _liftedSize = Size.zero;
  double _liftedLeft = 0;

  /// A picture of the part as it was lifted, drawn under the finger. A
  /// picture rather than the part itself, so the real one never leaves its
  /// place in the column and loses nothing typed into it.
  ui.Image? _snapshot;
  OverlayEntry? _lifted;

  Timer? _scrollTimer;
  double _scrollSpeed = 0;

  /// Set after the parts are reshuffled, until they have been laid out again:
  /// their positions on screen are stale until then.
  bool _awaitingLayout = false;

  GlobalKey _keyFor(String id) =>
      _keys.putIfAbsent(id, () => GlobalKey(debugLabel: 'arrangeable_$id'));

  List<String> get _blockIds => <String>[
    for (final ArrangeableBlock block in widget.blocks) block.id,
  ];

  @override
  void dispose() {
    _stopScrolling();
    _lifted?.remove();
    _lifted = null;
    _snapshot?.dispose();
    _snapshot = null;
    super.dispose();
  }

  Rect? _rectOf(String id) {
    final RenderObject? object = _keyFor(id).currentContext?.findRenderObject();
    if (object is! RenderBox || !object.attached || !object.hasSize) {
      return null;
    }
    return object.localToGlobal(Offset.zero) & object.size;
  }

  void _lift(String id, Offset global) {
    if (_dragId != null) _drop();
    final RenderObject? object = _keyFor(id).currentContext?.findRenderObject();
    if (object is! RenderRepaintBoundary || !object.attached) return;

    ui.Image? picture;
    try {
      picture = object.toImageSync(
        pixelRatio: MediaQuery.devicePixelRatioOf(context),
      );
    } catch (_) {
      // Without a picture the lifted part is drawn as an outline; it still
      // moves.
      picture = null;
    }

    final Offset topLeft = object.localToGlobal(Offset.zero);
    HapticFeedback.mediumImpact();
    // The keyboard would otherwise sit over the page the part is moving on.
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _dragId = id;
      _order = _blockIds;
      _finger = global;
      _grab = global - topLeft;
      _liftedSize = object.size;
      _liftedLeft = topLeft.dx;
      _snapshot = picture;
    });
    _lifted = OverlayEntry(builder: _buildLifted);
    Overlay.of(context).insert(_lifted!);
  }

  void _drag(Offset global) {
    if (_dragId == null) return;
    _finger = global;
    _lifted?.markNeedsBuild();
    _retarget();
    _followEdges();
  }

  /// Moves the carried part past whichever part the finger is over, once the
  /// finger crosses that part's middle -- not its edge, or a tall part and a
  /// short one would swap back and forth under a still finger.
  void _retarget() {
    final String? id = _dragId;
    final List<String>? order = _order;
    if (id == null || order == null || _awaitingLayout) return;
    final int from = order.indexOf(id);
    for (int to = 0; to < order.length; to++) {
      if (to == from) continue;
      final Rect? rect = _rectOf(order[to]);
      if (rect == null) continue;
      if (_finger.dy < rect.top || _finger.dy > rect.bottom) continue;
      final bool upperHalf = _finger.dy < rect.center.dy;
      if ((to < from && upperHalf) || (to > from && !upperHalf)) {
        HapticFeedback.selectionClick();
        setState(() {
          order.removeAt(from);
          order.insert(to, id);
          _awaitingLayout = true;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _awaitingLayout = false;
        });
      }
      return;
    }
  }

  /// Scrolls the page while the part is held near its top or bottom edge,
  /// faster the closer it gets.
  void _followEdges() {
    final ScrollableState? scrollable = Scrollable.maybeOf(context);
    final RenderObject? view = scrollable?.context.findRenderObject();
    if (view is! RenderBox || !view.hasSize) return;
    final Rect bounds = view.localToGlobal(Offset.zero) & view.size;
    const double edge = 72;
    const double fastest = 16;
    double speed = 0;
    if (_finger.dy < bounds.top + edge) {
      speed = -fastest * ((bounds.top + edge - _finger.dy) / edge).clamp(0, 1);
    } else if (_finger.dy > bounds.bottom - edge) {
      speed =
          fastest * ((_finger.dy - (bounds.bottom - edge)) / edge).clamp(0, 1);
    }
    _scrollSpeed = speed;
    if (speed == 0) {
      _stopScrolling();
      return;
    }
    _scrollTimer ??= Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _scrollStep(),
    );
  }

  void _scrollStep() {
    final ScrollableState? scrollable = mounted
        ? Scrollable.maybeOf(context)
        : null;
    if (scrollable == null || _dragId == null) {
      _stopScrolling();
      return;
    }
    final ScrollPosition position = scrollable.position;
    final double target = (position.pixels + _scrollSpeed).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (target == position.pixels) return;
    position.jumpTo(target);
    _retarget();
  }

  void _stopScrolling() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
    _scrollSpeed = 0;
  }

  void _drop() {
    final String? id = _dragId;
    final List<String>? order = _order;
    if (id == null || order == null) return;
    _stopScrolling();
    _lifted?.remove();
    _lifted = null;
    final ui.Image? picture = _snapshot;
    _snapshot = null;
    // Freed after the next frame, once nothing can still be drawing it.
    WidgetsBinding.instance.addPostFrameCallback((_) => picture?.dispose());

    final List<String> before = _blockIds;
    setState(() {
      _dragId = null;
      _order = null;
      _awaitingLayout = false;
    });
    if (!listEquals(order, before)) widget.onReorder(List<String>.of(order));
  }

  Widget _buildLifted(BuildContext overlayContext) {
    final RenderObject? overlayBox = Overlay.of(
      context,
    ).context.findRenderObject();
    final Offset globalTopLeft = Offset(_liftedLeft, _finger.dy - _grab.dy);
    final Offset topLeft = overlayBox is RenderBox && overlayBox.hasSize
        ? overlayBox.globalToLocal(globalTopLeft)
        : globalTopLeft;
    final ui.Image? picture = _snapshot;
    return Positioned(
      left: topLeft.dx,
      top: topLeft.dy,
      width: _liftedSize.width,
      height: _liftedSize.height,
      child: IgnorePointer(
        child: Transform.scale(
          scale: 1.03,
          child: Container(
            key: const Key('arrangeable_lifted'),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.royalBlue.withValues(alpha: 0.55),
                width: 1.5,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: picture == null
                  ? const SizedBox.expand()
                  : RawImage(image: picture, fit: BoxFit.fill),
            ),
          ),
        ),
      ),
    );
  }

  double _gapAfter(ArrangeableBlock block, ArrangeableBlock? next) {
    if (next == null || block.tight) return 0;
    if (block.compact && next.compact) return widget.compactGap;
    return widget.gap;
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, ArrangeableBlock> byId = <String, ArrangeableBlock>{
      for (final ArrangeableBlock block in widget.blocks) block.id: block,
    };
    final List<String> ids = <String>[
      for (final String id in _order ?? _blockIds)
        if (byId.containsKey(id)) id,
      // A part that appeared while another was being carried.
      if (_order != null)
        for (final String id in _blockIds)
          if (!_order!.contains(id)) id,
    ];

    return Listener(
      // A carried part is let go when the finger lifts, however the gesture
      // ends -- including when the system takes the touch away.
      onPointerUp: (_) => _drop(),
      onPointerCancel: (_) => _drop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (int i = 0; i < ids.length; i++)
            _buildPart(
              byId[ids[i]]!,
              gapAfter: _gapAfter(
                byId[ids[i]]!,
                i + 1 < ids.length ? byId[ids[i + 1]] : null,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPart(ArrangeableBlock block, {required double gapAfter}) {
    final bool carried = block.id == _dragId;
    return KeyedSubtree(
      key: ValueKey<String>('arrangeable_${block.id}'),
      child: Padding(
        padding: EdgeInsets.only(bottom: gapAfter),
        child: RepaintBoundary(
          key: _keyFor(block.id),
          child: RawGestureDetector(
            behavior: HitTestBehavior.opaque,
            gestures: <Type, GestureRecognizerFactory>{
              LongPressGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                    LongPressGestureRecognizer
                  >(
                    () => LongPressGestureRecognizer(
                      duration: widget.holdDuration,
                      debugOwner: this,
                    ),
                    (LongPressGestureRecognizer recognizer) {
                      recognizer.onLongPressStart =
                          (LongPressStartDetails details) {
                            _lift(block.id, details.globalPosition);
                          };
                      recognizer.onLongPressMoveUpdate =
                          (LongPressMoveUpdateDetails details) {
                            _drag(details.globalPosition);
                          };
                      recognizer.onLongPressEnd = (_) => _drop();
                    },
                  ),
            },
            // The carried part's own place stays open, outlined, while its
            // picture moves: that gap is where it lands.
            child: CustomPaint(
              foregroundPainter: carried ? const _OpenSlotPainter() : null,
              child: IgnorePointer(
                ignoring: carried,
                child: Opacity(opacity: carried ? 0 : 1, child: block.child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OpenSlotPainter extends CustomPainter {
  const _OpenSlotPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final RRect slot = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(14),
    );
    canvas.drawRRect(
      slot,
      Paint()..color = AppTheme.royalBlue.withValues(alpha: 0.06),
    );
    canvas.drawRRect(
      slot.deflate(0.75),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = AppTheme.royalBlue.withValues(alpha: 0.45),
    );
  }

  @override
  bool shouldRepaint(_OpenSlotPainter oldDelegate) => false;
}
