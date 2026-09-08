import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/glass_color.dart';

/// Picks the glass for the window being entered.
///
/// It sits under the aluminium finish, because it is the same kind of decision
/// made at the same moment: the fitter is looking at this opening and knows
/// whether it wants clear glass or obscured. Asked once for a whole job, it
/// would price the bathroom and the drawing room the same.
///
/// The choice stays where it was put. Most jobs are mostly one glass, so it
/// carries to the next window and only moves when somebody moves it.
class GlassColorPicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const GlassColorPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  Future<void> _pick(BuildContext context) async {
    final String current = GlassColors.normalize(value);
    final String? picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.space5,
                  0,
                  AppTheme.space5,
                  AppTheme.space3,
                ),
                child: Row(
                  children: <Widget>[
                    Text(
                      'Glass',
                      style: Theme.of(sheetContext).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              // Ten types is more than fits on a short phone, so the list
              // scrolls rather than the last few being unreachable.
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: <Widget>[
                    for (final String option in GlassColors.all)
                      ListTile(
                        leading: GlassSwatch(color: option, size: 30),
                        title: Text(
                          option,
                          style: TextStyle(
                            fontWeight: option == current
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                        trailing: option == current
                            ? const Icon(Icons.check_rounded)
                            : null,
                        onTap: () => Navigator.of(sheetContext).pop(option),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.space3),
            ],
          ),
        );
      },
    );
    if (picked != null && picked != current) {
      onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String current = GlassColors.normalize(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'GLASS',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: AppTheme.space3),
        Material(
          color: Colors.transparent,
          child: InkWell(
            key: const Key('glass_color_button'),
            onTap: () => _pick(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: Ink(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.space4,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.line),
              ),
              child: Row(
                children: <Widget>[
                  GlassSwatch(color: current, size: 26),
                  const SizedBox(width: AppTheme.space4),
                  Expanded(
                    child: Text(
                      current,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const Icon(Icons.expand_more_rounded, size: 20),
                ],
              ),
            ),
          ),
        ),
      ],
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
