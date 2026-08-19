import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';

/// A size expressed the way the shop says it: whole inches plus suter eighths.
class ShopLength {
  final int inches;
  final double suter;

  const ShopLength({this.inches = 0, this.suter = 0});

  /// Decimal inches, which is what the optimizer works in.
  double get asInches => inches + (suter / 8.0);

  bool get isZero => inches == 0 && suter == 0;

  String get display {
    if (isZero) return '0';
    final String s = suter == suter.roundToDouble()
        ? suter.toInt().toString()
        : suter.toString();
    if (inches == 0) return "$s'''";
    if (suter == 0) return "$inches''";
    return "$inches'' $s'''";
  }
}

/// "Glass Extra Margin": how far past the real sheet a layout may reach.
///
/// This is not a bigger sheet. The glass is the size it is. It is the shop
/// saying: if a layout spills over by a suter or two, lay it out anyway and
/// shave each piece down while cutting, rather than opening a second sheet for
/// almost nothing. That is what a cutter does by hand, and what the optimizer
/// used to refuse to do.
///
/// Height and width are set separately because they are not interchangeable on
/// a real sheet, and a shop will often allow one and not the other.
class ExtraMarginField extends StatelessWidget {
  final ShopLength height;
  final ShopLength width;
  final ValueChanged<ShopLength> onHeightChanged;
  final ValueChanged<ShopLength> onWidthChanged;
  final bool enabled;

  const ExtraMarginField({
    super.key,
    required this.height,
    required this.width,
    required this.onHeightChanged,
    required this.onWidthChanged,
    this.enabled = true,
  });

  bool get _anySet => !height.isZero || !width.isZero;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(
              Icons.open_in_full_rounded,
              size: 18,
              color: AppTheme.royalBlue,
            ),
            const SizedBox(width: AppTheme.space3),
            Text(
              'Glass Extra Margin',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Allow a layout to run this far past the sheet instead of starting a '
          'new one. Each piece is cut slightly smaller to take it up. Anything '
          'beyond this still goes on a new sheet.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: AppTheme.space4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: _MarginInput(
                key: const Key('extra_margin_height'),
                label: 'Height',
                value: height,
                enabled: enabled,
                onChanged: onHeightChanged,
              ),
            ),
            const SizedBox(width: AppTheme.space4),
            Expanded(
              child: _MarginInput(
                key: const Key('extra_margin_width'),
                label: 'Width',
                value: width,
                enabled: enabled,
                onChanged: onWidthChanged,
              ),
            ),
          ],
        ),
        if (_anySet) ...<Widget>[
          const SizedBox(height: AppTheme.space3),
          Text(
            'Any sheet that actually uses this is marked in red on the layout, '
            'with the exact amount to shave.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.warning,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _MarginInput extends StatefulWidget {
  final String label;
  final ShopLength value;
  final ValueChanged<ShopLength> onChanged;
  final bool enabled;

  const _MarginInput({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.enabled,
  });

  @override
  State<_MarginInput> createState() => _MarginInputState();
}

class _MarginInputState extends State<_MarginInput> {
  late final TextEditingController _inch = TextEditingController(
    text: widget.value.inches == 0 ? '' : widget.value.inches.toString(),
  );
  late final TextEditingController _suter = TextEditingController(
    text: widget.value.suter == 0 ? '' : _trim(widget.value.suter),
  );

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    _inch.dispose();
    _suter.dispose();
    super.dispose();
  }

  void _emit() {
    final int inches = int.tryParse(_inch.text.trim()) ?? 0;
    // Held to the same 0..7.5 the rest of the app uses for suter, so a typo
    // cannot quietly authorise a margin of half a sheet.
    final double suter = (double.tryParse(_suter.text.trim()) ?? 0).clamp(
      0,
      7.5,
    );
    widget.onChanged(
      ShopLength(inches: inches < 0 ? 0 : inches, suter: suter),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          widget.label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _inch,
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                onChanged: (_) => _emit(),
                decoration: const InputDecoration(
                  labelText: 'Inch',
                  hintText: '0',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _suter,
                enabled: widget.enabled,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d?')),
                ],
                onChanged: (_) => _emit(),
                decoration: const InputDecoration(
                  labelText: 'Suter',
                  hintText: '0-7.5',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
