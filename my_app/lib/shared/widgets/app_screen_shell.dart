import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../features/subscription/models/home_plan_look.dart';
import '../../features/subscription/presentation/plan_tint.dart';
import '../../features/subscription/state/plan_shade.dart';

class AppScreenShell extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// A colour laid over the whole background. Left null, it is the shop's
  /// plan shade ([PlanShade]), which every screen wears. Faded in and out
  /// rather than switched, as it usually arrives a moment after the screen
  /// does.
  final Color? tint;

  const AppScreenShell({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(
      AppTheme.space5,
      AppTheme.space5,
      AppTheme.space5,
      AppTheme.space7,
    ),
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.pageDecoration(),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: ValueListenableBuilder<PlanTone?>(
              valueListenable: PlanShade.instance,
              builder: (BuildContext context, PlanTone? tone, _) {
                return AnimatedContainer(
                  key: const Key('screen_shell_tint'),
                  duration: const Duration(milliseconds: 400),
                  color: tint ?? planShadeTint(tone) ?? Colors.transparent,
                );
              },
            ),
          ),
          const _GlowOrb(
            alignment: Alignment(-1.15, -1.05),
            size: 240,
            color: AppTheme.royalBlue,
            opacity: 0.10,
          ),
          const _GlowOrb(
            alignment: Alignment(1.10, -0.55),
            size: 220,
            color: AppTheme.tealAccent,
            opacity: 0.10,
          ),
          const _GlowOrb(
            alignment: Alignment(0.95, 1.05),
            size: 300,
            color: AppTheme.amberAccent,
            opacity: 0.07,
          ),
          SafeArea(
            child: Padding(padding: padding, child: child),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final Alignment alignment;
  final double size;
  final Color color;
  final double opacity;

  const _GlowOrb({
    required this.alignment,
    required this.size,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: opacity),
          ),
        ),
      ),
    );
  }
}
