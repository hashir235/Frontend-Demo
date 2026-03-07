import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/window_line_graphic.dart';
import '../models/window_type.dart';

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
    final bool highlight = isSelected || isFocused;
    final Color accent = node.hasChildren
        ? AppTheme.tealAccent
        : AppTheme.royalBlue;
    final String resolvedCode = (node.codeName ?? '').trim();
    final bool isMSectionCard =
        node.label.contains('M_Section') ||
        node.label.contains('M Section') ||
        resolvedCode.startsWith('M');
    final List<Color> diagramColors = isMSectionCard
        ? <Color>[const Color(0xFFEAF8EB), const Color(0xFFD4F0D7)]
        : <Color>[const Color(0xFFEFF6FF), const Color(0xFFDCEBFF)];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact =
            constraints.maxWidth < 240 || constraints.maxHeight < 320;
        final double cardPadding = compact ? AppTheme.space5 : AppTheme.space6;
        final double iconSize = compact ? 36 : 40;
        final double graphicHeight = compact ? 92 : 122;
        final int titleLines = compact ? 3 : 2;
        final int subtitleLines = compact ? 2 : 3;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            onTap: onTap,
            child: Ink(
              decoration: AppTheme.elevatedCardDecoration(
                selected: highlight,
                accent: accent,
              ),
              child: Padding(
                padding: EdgeInsets.all(cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.space3,
                              vertical: AppTheme.space2,
                            ),
                            decoration: AppTheme.infoChipDecoration(
                              emphasized: highlight,
                            ),
                            child: Text(
                              node.codeName ?? 'Gateway',
                              key: highlight
                                  ? const Key('focused_code_name')
                                  : null,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: highlight
                                        ? accent
                                        : AppTheme.textPrimary,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.space3),
                        Container(
                          width: iconSize,
                          height: iconSize,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            node.hasChildren
                                ? Icons.dashboard_customize_rounded
                                : Icons.arrow_forward_rounded,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.space4),
                    SizedBox(
                      height: graphicHeight,
                      width: double.infinity,
                      child: Container(
                        padding: EdgeInsets.all(
                          compact ? AppTheme.space4 : AppTheme.space5,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: diagramColors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: AppTheme.line.withValues(alpha: 0.85),
                          ),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMd,
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(
                            width: compact ? 118 : 150,
                            height: compact ? 72 : 88,
                            child: WindowLineGraphic(
                              graphicKey: node.graphicKey,
                              windowLabel: node.label,
                              displayIndex: node.displayIndex,
                              windowCode: node.codeName,
                              strokeColor: highlight
                                  ? AppTheme.royalBlue
                                  : AppTheme.deepTeal,
                              horizontalShift: parallaxShift,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.space4),
                    Text(
                      node.label,
                      maxLines: titleLines,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: AppTheme.space2),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          node.subtitle ??
                              (node.hasChildren
                                  ? 'Open this family to continue'
                                  : 'Open the detailed input page'),
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(height: 1.32),
                          maxLines: subtitleLines,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
