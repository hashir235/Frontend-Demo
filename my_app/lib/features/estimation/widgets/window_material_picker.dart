import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/option_switch.dart';
import '../models/window_material.dart';
import 'swatch_choice_grid.dart';

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
        // The finishes as boxes to tap, the chosen one named above them. A
        // shop picks a finish by eye; the list of names it used to open made
        // them read "SAHARA/ BROWN" and "BLACK/ MULTI" every time.
        SwatchChoiceGrid(
          title: 'ALUMINIUM COLOR',
          options: AluminiumColors.all,
          selected: value.color,
          nameFor: AluminiumColors.labelFor,
          swatchBuilder: (String color, double size) =>
              AluminiumSwatch(color: color, size: size),
          keyPrefix: 'aluminium_color',
          onSelected: (String color) {
            onChanged(value.copyWith(color: color));
          },
        ),
      ],
    );
  }
}

/// A rounded chip of the finish itself.
///
/// Wood coat is drawn with a grain. Its brown sits close to Sahara's, and with
/// the names gone from the boxes the grain is what tells the two apart.
class AluminiumSwatch extends StatelessWidget {
  final String color;
  final double size;

  const AluminiumSwatch({super.key, required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(size / 3.2);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AluminiumColors.swatchFor(color),
        borderRadius: radius,
        border: Border.all(color: Colors.black.withValues(alpha: 0.15)),
      ),
      child: color == AluminiumColors.wood
          ? ClipRRect(
              borderRadius: radius,
              child: CustomPaint(painter: _WoodGrainPainter()),
            )
          : null,
    );
  }
}

/// A few wavy lines of a lighter brown across the swatch.
class _WoodGrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint grain = Paint()
      ..color = const Color(0xFFA9774A).withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, size.height / 22);
    const int lines = 4;
    for (int i = 1; i <= lines; i += 1) {
      final double y = size.height * i / (lines + 1);
      final double wave = size.height / 14;
      final Path path = Path()..moveTo(0, y);
      path.cubicTo(
        size.width * 0.3,
        y - wave,
        size.width * 0.6,
        y + wave,
        size.width,
        y - wave / 2,
      );
      canvas.drawPath(path, grain);
    }
  }

  @override
  bool shouldRepaint(covariant _WoodGrainPainter oldDelegate) => false;
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
