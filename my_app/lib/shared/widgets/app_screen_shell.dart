import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class AppScreenShell extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AppScreenShell({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(
      AppTheme.space5,
      AppTheme.space5,
      AppTheme.space5,
      AppTheme.space7,
    ),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.pageDecoration(),
      child: Stack(
        children: <Widget>[
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
