import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class SectionSurfaceCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget child;
  final Widget? leading;
  final Widget? trailing;
  final bool accented;
  final EdgeInsetsGeometry padding;

  const SectionSurfaceCard({
    super.key,
    this.title,
    this.subtitle,
    required this.child,
    this.leading,
    this.trailing,
    this.accented = false,
    this.padding = const EdgeInsets.all(AppTheme.space6),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: accented
          ? AppTheme.accentPanelDecoration()
          : AppTheme.elevatedCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (title != null ||
              subtitle != null ||
              leading != null ||
              trailing != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (leading != null) ...<Widget>[
                  leading!,
                  const SizedBox(width: AppTheme.space4),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (title != null)
                        Text(
                          title!,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) ...<Widget>[
                  const SizedBox(width: AppTheme.space4),
                  trailing!,
                ],
              ],
            ),
          if (title != null || leading != null || trailing != null)
            const SizedBox(height: AppTheme.space5),
          child,
        ],
      ),
    );
  }
}
