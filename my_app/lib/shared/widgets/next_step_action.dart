import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// The single "Next" control for every step of the Estimation and Fabrication
/// flows.
///
/// Steps used to disagree with each other — some put a text "Next" button at
/// the bottom, others a plain arrow in the AppBar — so the flow felt different
/// on every screen. Every step now places this in `AppBar.actions`, so Next is
/// always the top-right brand-coloured arrow.
///
/// Pass a null [onPressed] to show it disabled rather than hiding it: a missing
/// button reads as "this screen has no next step", which is exactly the
/// confusion this widget exists to remove.
class NextStepAction extends StatelessWidget {
  final VoidCallback? onPressed;
  final String tooltip;

  const NextStepAction({
    super.key,
    required this.onPressed,
    this.tooltip = 'Next',
  });

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    return Padding(
      padding: const EdgeInsets.only(right: AppTheme.space4),
      child: IconButton.filled(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: enabled ? AppTheme.royalBlue : AppTheme.line,
          foregroundColor: enabled ? Colors.white : AppTheme.textSecondary,
          minimumSize: const Size(40, 40),
        ),
        icon: const Icon(Icons.arrow_forward_rounded, size: 20),
      ),
    );
  }
}
