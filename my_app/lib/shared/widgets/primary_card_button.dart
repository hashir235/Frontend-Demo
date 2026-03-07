import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class PrimaryCardButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? accent;

  const PrimaryCardButton({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final Color accentColor = accent ?? AppTheme.royalBlue;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFFFEFFFF), Color(0xFFF4F8FB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppTheme.line),
            boxShadow: AppTheme.softShadow(),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.space6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Icon(icon, color: accentColor, size: 32),
                ),
                const SizedBox(width: AppTheme.space5),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.space3,
                          vertical: AppTheme.space2,
                        ),
                        decoration: AppTheme.infoChipDecoration(
                          emphasized: true,
                        ),
                        child: Text(
                          'Quick Aluminium',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: accentColor,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.space4),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppTheme.textPrimary,
                            ),
                      ),
                      const SizedBox(height: AppTheme.space2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTheme.space4),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.line),
                  ),
                  child: const Icon(Icons.arrow_forward_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
