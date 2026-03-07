import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class AppHeroHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const AppHeroHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space7),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFFFDFEFF), Color(0xFFF2F7FB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppTheme.line),
        boxShadow: AppTheme.softShadow(),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space4,
                    vertical: AppTheme.space2,
                  ),
                  decoration: AppTheme.infoChipDecoration(emphasized: true),
                  child: Text(
                    eyebrow,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppTheme.royalBlue,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.space5),
                Text(title, style: Theme.of(context).textTheme.headlineLarge),
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: AppTheme.space5),
            trailing!,
          ],
        ],
      ),
    );
  }
}
