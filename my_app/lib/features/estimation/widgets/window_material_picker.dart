import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/option_switch.dart';
import '../models/window_material.dart';

/// Picks the gauge and colour for the window being entered.
///
/// It sits on the input screen, beside height and width, because that is when
/// the fabricator knows the answer -- he is looking at the drawing for this
/// opening. Asking once on a screen of its own, before any window existed,
/// forced one answer onto a whole job.
///
/// Compact on purpose: this is a small decision next to the sizes, not a step
/// of its own, and the screen it lives on is already busy.
class WindowMaterialPicker extends StatelessWidget {
  final WindowMaterial value;
  final ValueChanged<WindowMaterial> onChanged;

  const WindowMaterialPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  Future<void> _pickColor(BuildContext context) async {
    final String? picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
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
                      'Colour',
                      style: Theme.of(sheetContext).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              for (final String option in AluminiumColors.all)
                ListTile(
                  leading: _Swatch(color: option, size: 30),
                  title: Text(
                    AluminiumColors.labelFor(option),
                    style: TextStyle(
                      fontWeight: option == value.color
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                  ),
                  trailing: option == value.color
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () => Navigator.of(sheetContext).pop(option),
                ),
              const SizedBox(height: AppTheme.space3),
            ],
          ),
        );
      },
    );
    if (picked != null && picked != value.color) {
      onChanged(value.copyWith(color: picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        OptionSwitchRow(
          label: 'Gauge',
          options: <Widget>[
            for (final String gauge in WindowGauges.all)
              OptionSwitch(
                label: gauge,
                selected: gauge == value.gauge,
                expand: true,
                onTap: () {
                  if (gauge != value.gauge) {
                    onChanged(value.copyWith(gauge: gauge));
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: AppTheme.space5),
        Text(
          'COLOUR',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: AppTheme.space3),
        _ColorButton(
          color: value.color,
          onTap: () => _pickColor(context),
        ),
      ],
    );
  }
}

/// The colour row: a swatch of the finish, its name, and a hint that it opens.
///
/// The swatch carries the meaning. A shop picks colour by eye, and five grey
/// rows reading "SAHARA/ BROWN" and "BLACK/ MULTI" make them read every time.
class _ColorButton extends StatelessWidget {
  final String color;
  final VoidCallback onTap;

  const _ColorButton({required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
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
              _Swatch(color: color, size: 26),
              const SizedBox(width: AppTheme.space4),
              Expanded(
                child: Text(
                  AluminiumColors.labelFor(color),
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
    );
  }
}

/// A rounded chip of the finish itself.
class _Swatch extends StatelessWidget {
  final String color;
  final double size;

  const _Swatch({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AluminiumColors.swatchFor(color),
        borderRadius: BorderRadius.circular(size / 3.2),
        border: Border.all(color: Colors.black.withValues(alpha: 0.15)),
      ),
    );
  }
}

/// The gauge and colour a window is made in, as a small badge.
///
/// Used wherever a window or a cutting pile is listed -- the review list, the
/// section chips, the rate rows -- so the same fact always looks the same.
class WindowMaterialChip extends StatelessWidget {
  final WindowMaterial material;

  const WindowMaterialChip({super.key, required this.material});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.line.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: AluminiumColors.swatchFor(material.color),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black.withValues(alpha: 0.15)),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            material.label,
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
