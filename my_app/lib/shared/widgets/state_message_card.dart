import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'section_surface_card.dart';

class StateMessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final Color? iconColor;

  const StateMessageCard({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final Color resolvedIconColor = iconColor ?? AppTheme.royalBlue;
    return SectionSurfaceCard(
      accented: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: resolvedIconColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: resolvedIconColor, size: 30),
          ),
          const SizedBox(height: AppTheme.space5),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          if (message != null) ...<Widget>[
            const SizedBox(height: AppTheme.space3),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
            ),
          ],
          if (action != null) ...<Widget>[
            const SizedBox(height: AppTheme.space5),
            action!,
          ],
        ],
      ),
    );
  }
}
