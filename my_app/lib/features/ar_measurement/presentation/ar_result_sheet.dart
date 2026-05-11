import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/ar_measurement_result.dart';
import '../models/inch_sutar.dart';

/// Final confirmation of an AR measurement. Lets the user adjust the snapped
/// inch + sutar values before they flow into the estimation input fields.
class ArResultSheet extends StatefulWidget {
  final ArMeasurementResult result;

  const ArResultSheet({super.key, required this.result});

  /// Shows the sheet and returns the confirmed inch+sutar pair for width and
  /// height, or null if the user cancels.
  static Future<({InchSutar width, InchSutar height})?> show(
    BuildContext context,
    ArMeasurementResult result,
  ) {
    return showModalBottomSheet<({InchSutar width, InchSutar height})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext ctx) => ArResultSheet(result: result),
    );
  }

  @override
  State<ArResultSheet> createState() => _ArResultSheetState();
}

class _ArResultSheetState extends State<ArResultSheet> {
  late InchSutar _width;
  late InchSutar _height;

  @override
  void initState() {
    super.initState();
    _width = widget.result.width;
    _height = widget.result.height;
  }

  void _adjust({required bool isWidth, required int sutarDelta}) {
    final InchSutar current = isWidth ? _width : _height;
    final int totalSutar = (current.inches * 8 + current.sutar + sutarDelta)
        .clamp(0, 16 * 8); // capped at 16 inches just for safety
    final InchSutar next = InchSutar(
      inches: totalSutar ~/ 8,
      sutar: totalSutar % 8,
    );
    setState(() {
      if (isWidth) {
        _width = next;
      } else {
        _height = next;
      }
    });
  }

  Color _confidenceColor(ArConfidence c) {
    switch (c) {
      case ArConfidence.high:
        return AppTheme.success;
      case ArConfidence.medium:
        return AppTheme.warning;
      case ArConfidence.low:
        return AppTheme.danger;
    }
  }

  String _confidenceLabel(ArConfidence c) {
    switch (c) {
      case ArConfidence.high:
        return 'Good tracking';
      case ArConfidence.medium:
        return 'Verify with tape';
      case ArConfidence.low:
        return 'Low confidence — verify with tape';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ArConfidence overall = widget.result.overallConfidence;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                const Icon(
                  Icons.straighten_rounded,
                  color: AppTheme.royalBlue,
                ),
                const SizedBox(width: 8),
                Text(
                  'AR Measurement',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Snapped to nearest sutar. Adjust if needed, then apply.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: _confidenceColor(overall).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _confidenceColor(overall).withValues(alpha: 0.32),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    overall == ArConfidence.high
                        ? Icons.check_circle_rounded
                        : Icons.info_rounded,
                    color: _confidenceColor(overall),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _confidenceLabel(overall),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _MeasurementRow(
              label: 'Width',
              value: _width,
              onDecrement: () => _adjust(isWidth: true, sutarDelta: -1),
              onIncrement: () => _adjust(isWidth: true, sutarDelta: 1),
            ),
            const SizedBox(height: 12),
            _MeasurementRow(
              label: 'Height',
              value: _height,
              onDecrement: () => _adjust(isWidth: false, sutarDelta: -1),
              onIncrement: () => _adjust(isWidth: false, sutarDelta: 1),
            ),
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Use these values'),
                    onPressed: () => Navigator.of(context).pop(
                      (width: _width, height: _height),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MeasurementRow extends StatelessWidget {
  final String label;
  final InchSutar value;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _MeasurementRow({
    required this.label,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                value.displayLabel,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppTheme.royalBlue,
                      letterSpacing: 0.3,
                    ),
              ),
            ),
          ),
          IconButton.filledTonal(
            onPressed: onDecrement,
            icon: const Icon(Icons.remove_rounded),
            tooltip: '-1 sutar',
          ),
          const SizedBox(width: 4),
          IconButton.filledTonal(
            onPressed: onIncrement,
            icon: const Icon(Icons.add_rounded),
            tooltip: '+1 sutar',
          ),
        ],
      ),
    );
  }
}
