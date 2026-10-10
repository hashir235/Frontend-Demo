import 'package:flutter/material.dart';

import '../models/home_plan_look.dart';
import '../state/plan_shade.dart';
import 'plan_validity_card.dart';

/// The colour laid over a background for [tone], or null for none.
Color? planShadeTint(PlanTone? tone) =>
    tone == null ? null : planToneTint(tone);

/// [theme] with the plan's shade on its page colour, so every plain Scaffold
/// -- and the app bar standing on it -- carries the shade without each
/// screen being told. Unchanged when there is no plan.
ThemeData withPlanShade(ThemeData theme, PlanTone? tone) {
  final Color? tint = planShadeTint(tone);
  if (tint == null) return theme;
  return theme.copyWith(
    scaffoldBackgroundColor: Color.alphaBlend(
      tint,
      theme.scaffoldBackgroundColor,
    ),
  );
}

/// Paints the plan's shade behind [child], for a screen that draws its own
/// background (a gradient of its own) instead of the Scaffold's. Goes inside
/// that background, around what stands on it.
class PlanTint extends StatelessWidget {
  final Widget child;

  const PlanTint({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PlanTone?>(
      valueListenable: PlanShade.instance,
      builder: (BuildContext context, PlanTone? tone, Widget? child) {
        return AnimatedContainer(
          key: const Key('plan_tint'),
          duration: const Duration(milliseconds: 400),
          color: planShadeTint(tone) ?? Colors.transparent,
          child: child,
        );
      },
      child: child,
    );
  }
}
