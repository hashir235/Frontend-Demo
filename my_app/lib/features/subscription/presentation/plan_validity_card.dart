import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/home_plan_look.dart';

/// The colour a plan's state is drawn in: green while it runs, amber in its
/// last days, red once it has ended.
Color planToneColor(PlanTone tone) {
  switch (tone) {
    case PlanTone.active:
      return AppTheme.success;
    case PlanTone.endingSoon:
      return const Color(0xFFB7791F);
    case PlanTone.ended:
      return AppTheme.danger;
  }
}

/// The shade laid over Home's background, so the state of the plan can be
/// seen from across the shop without reading anything: light green, light
/// yellow, light red.
Color planToneTint(PlanTone tone) {
  switch (tone) {
    case PlanTone.active:
      return const Color(0xFF2E9E5B).withValues(alpha: 0.13);
    case PlanTone.endingSoon:
      return const Color(0xFFF2C230).withValues(alpha: 0.22);
    case PlanTone.ended:
      return const Color(0xFFE0525C).withValues(alpha: 0.15);
  }
}

/// Which plan the shop is on and the date it runs to, at the foot of Home.
class PlanValidityCard extends StatelessWidget {
  final HomePlanLook look;

  const PlanValidityCard({super.key, required this.look});

  @override
  Widget build(BuildContext context) {
    final Color accent = planToneColor(look.tone);
    final TextTheme text = Theme.of(context).textTheme;
    final IconData icon = switch (look.tone) {
      PlanTone.active => Icons.verified_user_rounded,
      PlanTone.endingSoon => Icons.hourglass_bottom_rounded,
      PlanTone.ended => Icons.event_busy_rounded,
    };

    return Container(
      key: const Key('home_plan_card'),
      padding: const EdgeInsets.all(AppTheme.space5),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: accent.withValues(alpha: 0.45), width: 1.4),
        boxShadow: AppTheme.softShadow(),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent, size: 26),
          ),
          const SizedBox(width: AppTheme.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  look.planLabel,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  look.dateLine,
                  style: text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.space3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              look.daysLabel,
              style: text.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
