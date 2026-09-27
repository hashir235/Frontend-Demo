import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/window_line_graphic.dart';
import '../data/window_catalog.dart';
import '../models/window_type.dart';
import '../models/window_variant.dart';

/// One window in the library, read top to bottom: its name, the sections it
/// is made of, then its drawing.
class WindowNavigationCard extends StatelessWidget {
  final WindowType node;
  final bool isFocused;
  final bool isSelected;
  final double parallaxShift;
  final VoidCallback onTap;

  /// The sections the window is cut from, as the library writes them
  /// ("DC30F", "D29 (net)"). Nothing is shown when empty.
  final List<String> usedSections;

  const WindowNavigationCard({
    super.key,
    required this.node,
    required this.isFocused,
    required this.isSelected,
    required this.parallaxShift,
    required this.onTap,
    this.usedSections = const <String>[],
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
    // The frame a variant is on, told apart at a glance by the drawing's
    // backdrop: the B frame warm, the BA frame lavender.
    final String? frame = WindowVariants.of(
      node.hasChildren ? node.children.first.codeName : node.codeName,
    )?.frame;
    final List<Color> diagramColors = switch (frame) {
      'B' => <Color>[const Color(0xFFFFF8EE), const Color(0xFFFBE8CC)],
      'BA' => <Color>[const Color(0xFFF6F2FF), const Color(0xFFE5DCFB)],
      _ when isMSectionCard => <Color>[const Color(0xFFEAF8EB), const Color(0xFFD4F0D7)],
      _ => <Color>[const Color(0xFFEFF6FF), const Color(0xFFDCEBFF)],
    };
    // A variant is drawn as the window it is made like.
    final WindowType drawn = WindowCatalog.drawnAs(node);
    final TextTheme text = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact =
            constraints.maxWidth < 240 || constraints.maxHeight < 320;
        final double cardPadding = compact ? AppTheme.space5 : AppTheme.space6;
        final double iconSize = compact ? 36 : 40;

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
                              // A family card has no code of its own -- it
                              // opens onto the variants inside it. "Gateway"
                              // named that idea in a way nobody recognised.
                              node.codeName ?? 'More Types',
                              key: highlight
                                  ? const Key('focused_code_name')
                                  : null,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.labelMedium?.copyWith(
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
                    const SizedBox(height: AppTheme.space3),
                    // The window's name.
                    Text(
                      node.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.08,
                      ),
                    ),
                    // What it is made of, quieter than the name.
                    if (usedSections.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppTheme.space2),
                      Text(
                        'Used Sections',
                        style: text.labelMedium?.copyWith(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        usedSections.join('  ·  '),
                        key: Key('used_sections_${node.codeName ?? node.label}'),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(
                          color: AppTheme.textSecondary.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppTheme.space4),
                    // Then the drawing, in whatever height is left.
                    Expanded(
                      child: Container(
                        width: double.infinity,
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
                              graphicKey: drawn.graphicKey,
                              windowLabel: drawn.label,
                              displayIndex: drawn.displayIndex,
                              windowCode: drawn.codeName,
                              strokeColor: highlight
                                  ? AppTheme.royalBlue
                                  : AppTheme.deepTeal,
                              horizontalShift: parallaxShift,
                            ),
                          ),
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
