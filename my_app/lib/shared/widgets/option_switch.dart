import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// One choice in a row of choices.
///
/// The app used to draw these three different ways -- pill chips with a tick
/// for lock and rubber, plain text buttons for the unit, and a bordered box for
/// the gauge. Three looks for one idea made the screen feel assembled rather
/// than designed, so they are all this now.
///
/// Selection reads as weight and colour rather than as a tick: the chosen one
/// is filled and outlined in the app's blue, the rest sit quiet. That survives
/// a glance across a busy screen, which a small tick does not.
class OptionSwitch extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Shown above the label in a smaller, lighter face -- a unit, or what the
  /// option costs. Optional; most rows do not need it.
  final String? caption;

  /// Fills the width it is given. Rows of two or three equal options (gauge,
  /// rubber) look deliberate stretched; longer, uneven lists (lock) are better
  /// left to size themselves.
  final bool expand;

  const OptionSwitch({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.caption,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final Widget button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(
            horizontal: expand ? 8 : 16,
            vertical: caption == null ? 11 : 8,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.royalBlue.withValues(alpha: 0.10)
                : AppTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(
              color: selected ? AppTheme.royalBlue : AppTheme.line,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected
                      ? AppTheme.royalBlue
                      : AppTheme.textSecondary,
                ),
              ),
              if (caption != null)
                Text(
                  caption!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? AppTheme.royalBlue.withValues(alpha: 0.78)
                        : AppTheme.textSecondary.withValues(alpha: 0.72),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// A labelled row of [OptionSwitch]es.
///
/// The heading is a small capitalised label above the row rather than a word
/// beside it. Side labels forced every row to reserve the width of the longest
/// one, which left the options crammed into what was left.
class OptionSwitchRow extends StatelessWidget {
  final String label;
  final List<Widget> options;

  /// Divides the width equally between the options. Off for lists whose labels
  /// differ a lot in length, where equal columns leave odd gaps.
  final bool equalWidths;

  const OptionSwitchRow({
    super.key,
    required this.label,
    required this.options,
    this.equalWidths = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: AppTheme.space3),
        if (equalWidths)
          Row(
            children: <Widget>[
              for (int i = 0; i < options.length; i++) ...<Widget>[
                Expanded(child: options[i]),
                if (i != options.length - 1) const SizedBox(width: AppTheme.space3),
              ],
            ],
          )
        else
          Wrap(
            spacing: AppTheme.space3,
            runSpacing: AppTheme.space3,
            children: options,
          ),
      ],
    );
  }
}
