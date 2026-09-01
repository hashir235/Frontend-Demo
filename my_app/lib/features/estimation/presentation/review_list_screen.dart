import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/next_step_action.dart';
import '../../flow_nav/models/flow_step.dart';
import '../../flow_nav/presentation/flow_progress_bar.dart';
import '../../tutorial/tutorial_controller.dart';
import '../../tutorial/tutorial_overlay.dart';
import '../../tutorial/tutorial_step.dart';
import '../../tutorial/tutorial_target.dart';
import '../data/project_repository.dart';
import '../data/window_catalog.dart';
import '../models/window_material.dart';
import '../models/window_review_item.dart';
import '../models/window_type.dart';
import '../state/estimate_session_store.dart';
import '../widgets/window_material_picker.dart';
import 'input/input_registry.dart';
import 'length_optimization_screen.dart';
import 'rate_review_screen.dart';

class ReviewListScreen extends StatelessWidget {
  final EstimateSessionStore session;
  final ProjectRepository _projectRepository = ProjectRepository();

  static const List<Color> _cardAccentPalette = <Color>[
    AppTheme.royalBlue,
    AppTheme.tealAccent,
    AppTheme.amberAccent,
  ];

  ReviewListScreen({super.key, required this.session});

  Color _accentForIndex(int index) {
    return _cardAccentPalette[index % _cardAccentPalette.length];
  }

  String _unitLabel(WindowReviewItem item) {
    if (!session.isFabrication) {
      return item.unitMode.label;
    }
    return item.unitMode == UnitMode.feet ? 'cm' : 'inches';
  }

  Future<void> _editItem(BuildContext context, WindowReviewItem item) async {
    final WindowType? node =
        WindowCatalog.byDisplayIndex(item.windowIndex) ??
        WindowCatalog.byCodeName(item.windowCode);
    if (node == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open editor for this item.')),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: FlowSteps.sizeInput.id),
        builder: (_) =>
            buildInputScreen(node: node, session: session, editingItem: item),
      ),
    );
  }

  Future<void> _deleteItem(BuildContext context, WindowReviewItem item) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete item'),
          content: Text('Delete winNo ${item.winNo}?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      session.deleteByWinNo(item.winNo);
      try {
        await _projectRepository.syncSession(session);
      } on Exception catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.toString())));
        }
      }
    }
  }

  Future<void> _openLengthOptimization(BuildContext context) async {
    final List<WindowReviewItem> items = session.items;
    if (items.isEmpty) {
      return;
    }

    if (session.isFabrication) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: RouteSettings(name: FlowSteps.lengthOptimization.id),
          builder: (_) => LengthOptimizationScreen(
            session: session,
            items: items,
            projectId: session.projectId,
            projectName: session.projectName,
            projectLocation: session.projectLocation,
            requestContext: 'fabrication',
            showPdfActions: true,
            materialSelectionBuilder:
                (
                  BuildContext context,
                  String? projectId,
                  String projectName,
                  String projectLocation,
                ) {
                  final WindowMaterial material =
                      session.representativeMaterial;
                  return RateReviewScreen(
                    session: session,
                    gaugeLabel: material.gauge,
                    gaugeValue: material.gauge,
                    colorLabel: AluminiumColors.labelFor(material.color),
                    colorValue: material.color,
                    projectId: projectId,
                    projectName: projectName,
                    projectLocation: projectLocation,
                    requestContext: 'fabrication',
                    materialTableTitle: 'Fabrication Material Table',
                    materialTableShowNextToBill: false,
                    materialTableShowPdfActions: true,
                  );
                },
          ),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: FlowSteps.lengthOptimization.id),
        builder: (_) => LengthOptimizationScreen(
          session: session,
          items: items,
          projectId: session.projectId,
          projectName: session.projectName,
          projectLocation: session.projectLocation,
          requestContext: 'estimation',
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, int totalWindows) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            Colors.white.withValues(alpha: 0.82),
            AppTheme.ice.withValues(alpha: 0.56),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.68)),
        boxShadow: AppTheme.softShadow(),
      ),
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(
              text: 'Total saved windows : ',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.deepTeal,
                fontWeight: FontWeight.w800,
              ),
            ),
            TextSpan(
              text: '$totalWindows',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.royalBlue,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: accentColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.deepTeal,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  static const Map<int, String> _lockTypeLabels = <int, String>{
    1: 'Latch',
    2: 'Self',
    3: 'Handal',
  };

  /// Everything the user picked for this window besides its size.
  ///
  /// The card used to show only the collar and the unit, so a fabricator
  /// checking their list before cutting could not see which lock or rubber
  /// they had chosen for a given window -- the two things most likely to
  /// differ between otherwise identical rows.
  List<Widget> _buildSelectionChips(
    BuildContext context,
    WindowReviewItem item,
    Color accentColor,
    Color codeColor,
  ) {
    final List<Widget> chips = <Widget>[
      _buildMetaChip(
        context,
        icon: Icons.grid_view_rounded,
        label: 'Collar ${item.collarIndex}',
        accentColor: accentColor,
      ),
      _buildMetaChip(
        context,
        icon: Icons.straighten_rounded,
        label: _unitLabel(item),
        accentColor: codeColor,
      ),
      // The gauge and colour picked for this window, alongside the other
      // choices made on the same screen. A job can mix them now, so this is
      // the page where a wrong one gets caught -- reading down the list is how
      // anyone checks their own work before it goes to the saw.
      WindowMaterialChip(material: item.material),
    ];

    if (item.lockType != null) {
      chips.add(
        _buildMetaChip(
          context,
          icon: Icons.lock_outline_rounded,
          label: 'Lock: ${_lockTypeLabels[item.lockType] ?? item.lockType}',
          accentColor: AppTheme.royalBlue,
        ),
      );
    }

    final String? rubber = item.rubberType?.trim();
    if (rubber != null && rubber.isNotEmpty) {
      chips.add(
        _buildMetaChip(
          context,
          icon: Icons.filter_frames_rounded,
          label: 'Rubber: ${rubber.toUpperCase() == 'U' ? 'U' : 'Fix'}',
          accentColor: AppTheme.tealAccent,
        ),
      );
    }

    if (item.addBottom) {
      chips.add(
        _buildMetaChip(
          context,
          icon: Icons.vertical_align_bottom_rounded,
          label: 'D46 On',
          accentColor: AppTheme.royalBlue,
        ),
      );
    }
    if (item.addTee) {
      chips.add(
        _buildMetaChip(
          context,
          icon: Icons.horizontal_split_rounded,
          label: 'D52 On',
          accentColor: AppTheme.royalBlue,
        ),
      );
    }
    if (item.addNet) {
      chips.add(
        _buildMetaChip(
          context,
          icon: Icons.grid_on_rounded,
          label: 'Net On',
          accentColor: AppTheme.tealAccent,
        ),
      );
    }

    // Only worth a chip when it is not the usual 1.7cm, so the row stays short
    // on the windows where nothing unusual was chosen.
    if (item.backCollarCm == kBackCollarTwoCm) {
      chips.add(
        _buildMetaChip(
          context,
          icon: Icons.square_foot_rounded,
          label: 'Back collar 2 cm',
          accentColor: AppTheme.warning,
        ),
      );
    }

    return chips;
  }

  Widget _buildDimensionText(
    BuildContext context,
    WindowReviewItem item,
    Color accentColor,
  ) {
    const Color widthMaroon = Color(0xFF6A2233);
    final TextStyle labelStyle = Theme.of(context).textTheme.bodyMedium!
        .copyWith(
          color: AppTheme.slate,
          fontWeight: FontWeight.w700,
          height: 1.5,
        );
    final TextStyle heightLabelStyle = labelStyle.copyWith(
      color: Colors.black,
      fontWeight: FontWeight.w800,
      fontSize: 15,
    );
    final TextStyle heightValueStyle = labelStyle.copyWith(
      color: Colors.black,
      fontWeight: FontWeight.w900,
      fontSize: 18,
    );
    final TextStyle widthLabelStyle = labelStyle.copyWith(
      color: widthMaroon,
      fontWeight: FontWeight.w800,
      fontSize: 15,
    );
    final TextStyle widthValueStyle = labelStyle.copyWith(
      color: widthMaroon,
      fontWeight: FontWeight.w900,
      fontSize: 18,
    );
    final TextStyle archLabelStyle = labelStyle.copyWith(
      color: accentColor == AppTheme.amberAccent
          ? AppTheme.warning
          : AppTheme.royalBlue,
      fontWeight: FontWeight.w800,
      fontSize: 15,
    );
    final TextStyle archValueStyle = archLabelStyle.copyWith(
      fontWeight: FontWeight.w900,
      fontSize: 18,
    );

    final List<InlineSpan> spans = <InlineSpan>[
      TextSpan(text: 'Height = ', style: heightLabelStyle),
      TextSpan(text: item.heightValue, style: heightValueStyle),
      const TextSpan(text: '   '),
    ];

    if (item.leftWidthValue != null || item.rightWidthValue != null) {
      spans.addAll(<InlineSpan>[
        TextSpan(text: 'Right Width = ', style: widthLabelStyle),
        TextSpan(
          text: item.rightWidthValue ?? item.widthValue,
          style: widthValueStyle,
        ),
        const TextSpan(text: '   '),
        TextSpan(text: 'Left Width = ', style: widthLabelStyle),
        TextSpan(
          text: item.leftWidthValue ?? item.widthValue,
          style: widthValueStyle,
        ),
      ]);
    } else {
      spans.addAll(<InlineSpan>[
        TextSpan(text: 'Width = ', style: widthLabelStyle),
        TextSpan(text: item.widthValue, style: widthValueStyle),
      ]);
    }

    if (item.archValue != null && item.archValue!.isNotEmpty) {
      spans.addAll(<InlineSpan>[
        const TextSpan(text: '   '),
        TextSpan(text: 'Arch = ', style: archLabelStyle),
        TextSpan(text: item.archValue!, style: archValueStyle),
      ]);
    }

    return Text.rich(TextSpan(children: spans));
  }

  Widget _buildReviewCard(
    BuildContext context,
    WindowReviewItem item,
    int index,
  ) {
    final Color accentColor = _accentForIndex(index);
    final Color codeColor = accentColor == AppTheme.amberAccent
        ? AppTheme.warning
        : accentColor;

    return Container(
      key: Key('review_item_${item.winNo}'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            Colors.white,
            accentColor.withValues(alpha: 0.05),
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withValues(alpha: 0.22)),
        boxShadow: AppTheme.softShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'winNo ${item.winNo}',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: codeColor,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item.windowLabel,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.deepTeal,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.windowCode,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: codeColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                key: Key('review_edit_${item.winNo}'),
                onPressed: () => _editItem(context, item),
                icon: const Icon(Icons.edit_outlined),
                color: AppTheme.deepTeal,
                tooltip: 'Edit',
              ),
              IconButton(
                key: Key('review_delete_${item.winNo}'),
                onPressed: () => _deleteItem(context, item),
                icon: const Icon(Icons.delete_outline_rounded),
                color: AppTheme.danger,
                tooltip: 'Delete',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _buildSelectionChips(context, item, accentColor, codeColor),
          ),
          const SizedBox(height: 12),
          _buildDimensionText(context, item, accentColor),
          if (item.description != null &&
              item.description!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              'Description',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.slate,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.description!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.deepTeal,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Wraps the Scaffold rather than the body so the tour can spotlight the
    // Next arrow, which lives in the AppBar.
    return TutorialOverlay(
      screen: TutorialScreen.reviewList,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Review'),
          centerTitle: true,
          actions: <Widget>[
            // Stays disabled (not hidden) until a window is saved, so the step is
            // still discoverable on an empty list.
            AnimatedBuilder(
              animation: session,
              builder: (BuildContext context, Widget? child) {
                return TutorialTarget(
                  id: 'review.next',
                  child: NextStepAction(
                    key: const Key('review_next_button'),
                    onPressed: session.items.isEmpty
                        ? null
                        : () {
                            TutorialController.instance.advanceAfterTap();
                            _openLengthOptimization(context);
                          },
                  ),
                );
              },
            ),
          ],
        ),
        bottomNavigationBar: FlowProgressBar(stepId: FlowSteps.review.id),
        body: AnimatedBuilder(
          animation: session,
          builder: (BuildContext context, Widget? child) {
            final List<WindowReviewItem> items = session.items;
            if (items.isEmpty) {
              return Center(
                child: Text(
                  'No saved windows yet.',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.deepTeal,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }

            return Container(
              decoration: AppTheme.pageDecoration(),
              child: ListView(
                key: const Key('review_list_view'),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                children: <Widget>[
                  _buildSummaryCard(context, items.length),
                  const SizedBox(height: 12),
                  ...List<Widget>.generate(items.length, (int index) {
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == items.length - 1 ? 0 : 10,
                      ),
                      // The tour explains recheck / edit / delete on the first
                      // card, so only that one carries a target.
                      child: index == 0
                          ? TutorialTarget(
                              id: 'review.card',
                              child: _buildReviewCard(
                                context,
                                items[index],
                                index,
                              ),
                            )
                          : _buildReviewCard(context, items[index], index),
                    );
                  }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
