import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class BottomActionBar extends StatelessWidget {
  final List<Widget> children;

  const BottomActionBar({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.space5,
          AppTheme.space4,
          AppTheme.space5,
          AppTheme.space5,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.line)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppTheme.inkBlue.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Row(children: children),
      ),
    );
  }
}
