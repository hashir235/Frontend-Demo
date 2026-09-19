import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/glass_color.dart';
import 'swatch_choice_grid.dart';

/// Picks the glass for the window being entered.
///
/// It sits under the aluminium finish, because it is the same kind of decision
/// made at the same moment: the fitter is looking at this opening and knows
/// whether it wants clear glass or obscured. Asked once for a whole job, it
/// would price the bathroom and the drawing room the same.
///
/// The choice stays where it was put. Most jobs are mostly one glass, so it
/// carries to the next window and only moves when somebody moves it.
///
/// Every glass is a box to tap, as with the aluminium finish, and the chosen
/// one is named in full above them -- there is a whole line for it now, so
/// "Green Mercury" rather than the "Green Mer." a crowded list column needs.
/// Mercury boxes carry a sheen, which is what tells them from the plain glass
/// of the same colour without a word.
class GlassColorPicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const GlassColorPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwatchChoiceGrid(
      title: 'GLASS COLOR',
      options: GlassColors.all,
      selected: GlassColors.normalize(value),
      nameFor: GlassColors.displayName,
      swatchBuilder: (String color, double size) =>
          GlassSwatch(color: color, size: size),
      keyPrefix: 'glass_color',
      onSelected: onChanged,
    );
  }
}

/// A chip of the glass itself.
///
/// The swatch is what a fitter who cannot read English picks by, so mercury
/// gets a sheen across it -- that is the whole difference between the two
/// greens, and it has to be visible without the word.
class GlassSwatch extends StatelessWidget {
  final String color;
  final double size;

  const GlassSwatch({super.key, required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    final Color base = GlassColors.swatchFor(color);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size / 3.2),
        border: Border.all(color: Colors.black.withValues(alpha: 0.15)),
        gradient: GlassColors.isMercury(color)
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color.lerp(base, Colors.white, 0.55) ?? base,
                  base,
                  Color.lerp(base, Colors.black, 0.25) ?? base,
                ],
                stops: const <double>[0, 0.55, 1],
              )
            : null,
        color: GlassColors.isMercury(color) ? null : base,
      ),
    );
  }
}

/// The glass a window is glazed in, as a small badge for lists.
class GlassColorChip extends StatelessWidget {
  final String color;

  const GlassColorChip({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    final String name = GlassColors.normalize(color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          GlassSwatch(color: name, size: 12),
          const SizedBox(width: 6),
          Text(
            GlassColors.shortLabelFor(name),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
