import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Choosing a finish by its colour: every option laid out as a box, with the
/// one chosen named above them.
///
/// It replaces a button that opened a list of names. A shop picks a colour by
/// eye -- plenty of fitters do not read the English on the list -- and a list
/// hid the choice behind a tap and then showed mostly words. Here every colour
/// is on the screen at once, one tap picks it, the picked box carries a tick,
/// and the name above says in words what was picked for anyone who wants it.
/// Holding a box shows its name before choosing it.
class SwatchChoiceGrid extends StatelessWidget {
  const SwatchChoiceGrid({
    super.key,
    required this.title,
    required this.options,
    required this.selected,
    required this.nameFor,
    required this.swatchBuilder,
    required this.onSelected,
    required this.keyPrefix,
  });

  /// The small heading over the choice, e.g. "GLASS COLOR".
  final String title;
  final List<String> options;
  final String selected;
  final String Function(String option) nameFor;

  /// Draws one option's colour at the given size.
  final Widget Function(String option, double size) swatchBuilder;
  final ValueChanged<String> onSelected;

  /// Keys the parts for tests: `<prefix>_selected` and
  /// `<prefix>_option_<option>`.
  final String keyPrefix;

  static const int _perRow = 5;
  static const double _gap = 10;
  static const double _largestBox = 56;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: AppTheme.space3),
        Row(
          key: Key('${keyPrefix}_selected'),
          children: <Widget>[
            swatchBuilder(selected, 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                nameFor(selected),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space3),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            // Five to a row, as large as the width allows up to a comfortable
            // thumb: five colours are one row, ten are two.
            final double box = math.min(
              _largestBox,
              (constraints.maxWidth - _gap * (_perRow - 1)) / _perRow,
            );
            return Wrap(
              spacing: _gap,
              runSpacing: _gap,
              children: <Widget>[
                for (final String option in options)
                  _SwatchChoice(
                    key: Key('${keyPrefix}_option_$option'),
                    name: nameFor(option),
                    selected: option == selected,
                    size: box,
                    swatch: swatchBuilder(option, box - 8),
                    onTap: () {
                      if (option != selected) onSelected(option);
                    },
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// One colour to tap. The chosen one gets a ring and a tick in the corner:
/// the ring shows it at a glance, and the tick shows it on a pale glass where
/// a ring alone would be faint.
class _SwatchChoice extends StatelessWidget {
  const _SwatchChoice({
    super.key,
    required this.name,
    required this.selected,
    required this.size,
    required this.swatch,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final double size;
  final Widget swatch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(size / 3.2);
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      child: Tooltip(
        message: name,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: size,
                    height: size,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      border: Border.all(
                        color: selected ? AppTheme.royalBlue : AppTheme.line,
                        width: selected ? 2.5 : 1,
                      ),
                    ),
                    child: Center(child: swatch),
                  ),
                  if (selected)
                    Positioned(
                      top: -5,
                      right: -5,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: AppTheme.royalBlue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
