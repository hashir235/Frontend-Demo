import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// One piece on a bar: what it is, how long, and whether it has been cut yet.
@immutable
class CutLayoutSegment {
  /// Shown inside the block -- "3/WT": window number, then which piece of that
  /// window it is. Short on purpose; a block can be a few millimetres wide.
  final String label;

  final double lengthFt;

  /// Ticked off in the list below. The block goes grey so the remaining work
  /// is what still has colour.
  final bool isCut;

  const CutLayoutSegment({
    required this.label,
    required this.lengthFt,
    this.isCut = false,
  });
}

/// The bar as it will be cut, drawn to scale above its cutting list.
///
/// A table of numbers tells you what to cut but not what the bar looks like --
/// how the pieces sit along it, how much is left at the end, whether the
/// offcut is worth keeping. The saw operator reads that shape at a glance and
/// then works down the table for the exact sizes.
///
/// Every block is a real piece, its width its true share of the length, so the
/// picture cannot disagree with the plan. Waste is the only thing drawn dim,
/// and finished pieces join it there: what stays coloured is what is still to
/// do.
class CutLayoutBar extends StatelessWidget {
  final List<CutLayoutSegment> segments;

  /// Whatever is left over at the end of the bar.
  final double wastageFt;

  /// A leftover bar rather than a fresh stock length. Its tail is drawn as a
  /// keepable remnant, not as waste, because that is what it is.
  final bool isOffcut;

  /// Total, for the caption on the right -- already formatted by the caller,
  /// which knows whether this job reads in feet or in inch/sutter.
  final String totalLabel;

  const CutLayoutBar({
    super.key,
    required this.segments,
    required this.wastageFt,
    required this.isOffcut,
    required this.totalLabel,
  });

  /// Colours for the pieces, walked in order.
  ///
  /// Neighbouring blocks must not share a colour or the join between two
  /// pieces disappears, which is the one thing this drawing exists to show.
  static const List<Color> _pieceColors = <Color>[
    AppTheme.royalBlue,
    AppTheme.tealAccent,
    AppTheme.deepTeal,
    AppTheme.sky,
    AppTheme.amberAccent,
  ];

  static const double _barHeight = 34;
  static const double _gap = 2;

  /// Narrower than this and a label cannot be read, so it is left off rather
  /// than clipped to a meaningless stub.
  static const double _minWidthForLabel = 34;

  @override
  Widget build(BuildContext context) {
    final double cutTotal = segments.fold<double>(
      0,
      (double sum, CutLayoutSegment s) => sum + s.lengthFt,
    );
    final double tail = wastageFt > 0 ? wastageFt : 0;
    final double total = cutTotal + tail;
    if (total <= 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final int blocks = segments.length + (tail > 0 ? 1 : 0);
            // Gaps eat into the drawable width, so they come off the top
            // before anything is measured -- otherwise the blocks add up to
            // more than the bar and the last one is clipped.
            final double usable =
                constraints.maxWidth - (_gap * (blocks - 1).clamp(0, blocks));
            if (usable <= 0) return const SizedBox.shrink();

            final List<Widget> children = <Widget>[];
            for (int i = 0; i < segments.length; i++) {
              final CutLayoutSegment segment = segments[i];
              final double width = usable * (segment.lengthFt / total);
              children.add(
                _Block(
                  width: width,
                  color: segment.isCut
                      ? AppTheme.line
                      : _pieceColors[i % _pieceColors.length],
                  label: segment.label,
                  dim: segment.isCut,
                  showLabel: width >= _minWidthForLabel,
                  isFirst: i == 0,
                  isLast: i == blocks - 1,
                ),
              );
              if (i < blocks - 1) children.add(const SizedBox(width: _gap));
            }

            if (tail > 0) {
              children.add(
                _Block(
                  width: usable * (tail / total),
                  color: AppTheme.line,
                  label: isOffcut ? 'Offcut' : 'Waste',
                  dim: true,
                  showLabel: usable * (tail / total) >= _minWidthForLabel,
                  isFirst: segments.isEmpty,
                  isLast: true,
                ),
              );
            }

            return Row(children: children);
          },
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            Text(
              '${segments.length} piece${segments.length == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              '= $totalLabel',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One block of the bar.
class _Block extends StatelessWidget {
  final double width;
  final Color color;
  final String label;
  final bool dim;
  final bool showLabel;
  final bool isFirst;
  final bool isLast;

  const _Block({
    required this.width,
    required this.color,
    required this.label,
    required this.dim,
    required this.showLabel,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    // Only the ends of the bar are rounded. Rounding every block would make
    // the pieces look like separate objects lying near each other rather than
    // cuts from one length.
    const Radius r = Radius.circular(7);
    final BorderRadius radius = BorderRadius.horizontal(
      left: isFirst ? r : Radius.zero,
      right: isLast ? r : Radius.zero,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: width < 0 ? 0 : width,
      height: CutLayoutBar._barHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: dim ? color.withValues(alpha: 0.34) : color,
        borderRadius: radius,
      ),
      clipBehavior: Clip.hardEdge,
      child: showLabel
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.clip,
                softWrap: false,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.1,
                  color: dim ? AppTheme.textSecondary : Colors.white,
                ),
              ),
            )
          : null,
    );
  }
}
