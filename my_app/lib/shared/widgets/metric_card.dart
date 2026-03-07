import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? accent;
  final IconData? icon;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.accent,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final Color resolvedAccent = accent ?? AppTheme.royalBlue;
    return Container(
      padding: const EdgeInsets.all(AppTheme.space5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: resolvedAccent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: resolvedAccent),
            ),
            const SizedBox(height: AppTheme.space4),
          ],
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.space2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
