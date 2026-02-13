import 'package:flutter/material.dart';

import '../models/window_type.dart';
import '../theme/app_theme.dart';
import 'window_line_graphic.dart';

class WindowNavigationCard extends StatelessWidget {
  final WindowType node;
  final bool isFocused;
  final bool isSelected;
  final double parallaxShift;
  final VoidCallback onTap;

  const WindowNavigationCard({
    super.key,
    required this.node,
    required this.isFocused,
    required this.isSelected,
    required this.parallaxShift,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color borderColor = isSelected
        ? AppTheme.violet
        : (isFocused ? AppTheme.sky : AppTheme.ice.withValues(alpha: 0.85));

    final Color titleColor = isFocused ? AppTheme.deepTeal : AppTheme.slate;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOutCubic,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF8FBFD), Color(0xFFEAF1F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: borderColor,
              width: isSelected ? 2.4 : 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.deepTeal.withValues(alpha: 0.11),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (node.displayIndex != null)
                    _Pill(
                      label: '#${node.displayIndex}',
                      color: AppTheme.deepTeal,
                      textColor: Colors.white,
                    )
                  else
                    const _Pill(
                      label: 'Gateway',
                      color: AppTheme.slate,
                      textColor: Colors.white,
                    ),
                  if (isSelected)
                    const _Pill(
                      label: 'Selected',
                      color: AppTheme.violet,
                      textColor: Colors.white,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: WindowLineGraphic(
                    graphicKey: node.graphicKey,
                    windowLabel: node.label,
                    displayIndex: node.displayIndex,
                    strokeColor: isFocused ? AppTheme.deepTeal : AppTheme.slate,
                    horizontalShift: parallaxShift,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  node.label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: titleColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  node.hasChildren ? 'Tap to open options' : 'Tap to select',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _Pill({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
