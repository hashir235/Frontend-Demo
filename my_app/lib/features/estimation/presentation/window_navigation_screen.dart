import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../flow_nav/models/flow_step.dart';
import '../../flow_nav/presentation/flow_progress_bar.dart';
import '../../tutorial/tutorial_controller.dart';
import '../../tutorial/tutorial_overlay.dart';
import '../../tutorial/tutorial_step.dart';
import '../../tutorial/tutorial_target.dart';
import '../../../shared/widgets/app_hero_header.dart';
import '../../../shared/widgets/app_screen_shell.dart';
import '../../../shared/widgets/next_step_action.dart';
import '../../../shared/widgets/project_meta_strip.dart';
import '../../../shared/widgets/section_surface_card.dart';
import '../data/window_catalog.dart';
import '../data/window_sections.dart';
import '../models/window_type.dart';
import '../state/estimate_session_store.dart';
import '../widgets/window_card_strip.dart';
import '../widgets/window_navigation_card.dart';
import 'input/input_registry.dart';
import 'review_list_screen.dart';
import '../../help_videos/tutorial_videos.dart';

class WindowNavigationScreen extends StatefulWidget {
  /// The library's rows, top to bottom: each a heading and its windows.
  final List<WindowGroup> groups;
  final List<String> path;
  final EstimateSessionStore session;
  final String moduleTitle;

  const WindowNavigationScreen({
    super.key,
    required this.groups,
    required this.path,
    required this.session,
    required this.moduleTitle,
  });

  factory WindowNavigationScreen.root({
    Key? key,
    required EstimateSessionStore session,
    String rootLabel = 'Create Project',
    String moduleTitle = 'Estimation',
  }) {
    return WindowNavigationScreen(
      key: key,
      groups: WindowCatalog.groupsForFlow(isFabrication: session.isFabrication),
      path: <String>[rootLabel],
      session: session,
      moduleTitle: moduleTitle,
    );
  }

  @override
  State<WindowNavigationScreen> createState() => _WindowNavigationScreenState();
}

class _WindowNavigationScreenState extends State<WindowNavigationScreen> {
  /// The one window the screen has in hand -- the last one tapped, in
  /// whichever row. Only it is drawn selected. Counted within its group, line
  /// after line.
  int _focusGroup = 0;
  int _focusIndex = 0;

  void _focus(int group, int index) {
    setState(() {
      _focusGroup = group;
      _focusIndex = index;
    });
  }

  void _onNodeTap(WindowType node) {
    if (node.hasChildren) {
      // Still inside the library, just a level deeper, so the chain stays on
      // the same bubble. The family's own name heads its one row.
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: RouteSettings(name: FlowSteps.library.id),
          builder: (_) => WindowNavigationScreen(
            groups: <WindowGroup>[
              WindowGroup(
                id: 'family',
                title: node.label,
                rows: <WindowRow>[WindowRow(id: 'family', nodes: node.children)],
              ),
            ],
            path: <String>[...widget.path, node.label],
            session: widget.session,
            moduleTitle: widget.moduleTitle,
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: FlowSteps.sizeInput.id),
        builder: (_) => buildInputScreen(node: node, session: widget.session),
      ),
    );
  }

  void _openReview() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: FlowSteps.review.id),
        builder: (_) => ReviewListScreen(session: widget.session),
      ),
    );
  }

  /// Where group [group] starts when every window on the screen is counted
  /// in order -- the tour names its cards that way.
  int _offsetOf(int group) {
    int offset = 0;
    for (int g = 0; g < group; g++) {
      offset += widget.groups[g].nodes.length;
    }
    return offset;
  }

  /// Where line [row] of group [group] starts within its group.
  int _rowOffset(int group, int row) {
    int offset = 0;
    for (int r = 0; r < row; r++) {
      offset += widget.groups[group].rows[r].nodes.length;
    }
    return offset;
  }

  /// One window's card, wired to the tour and to the screen's focus.
  /// [index] counts within the group.
  Widget _card(int group, int index) {
    final WindowType node = widget.groups[group].nodes[index];
    final bool isSelected = group == _focusGroup && index == _focusIndex;
    final int overall = _offsetOf(group) + index;
    // The tour points at the first card -- Sliding Window at the top of the
    // catalogue -- as its worked example.
    return TutorialTarget(
      id: overall == 0 ? 'library.sliding' : 'library.card.$overall',
      child: WindowNavigationCard(
        node: node,
        isFocused: isSelected,
        isSelected: isSelected,
        parallaxShift: 0,
        usedSections: <String>[
          for (final UsedSection section in WindowSections.forNode(
            node,
            isFabrication: widget.session.isFabrication,
          ))
            section.label,
        ],
        onTap: () {
          _focus(group, index);
          TutorialController.instance.advanceAfterTap();
          _onNodeTap(node);
        },
      ),
    );
  }

  /// One line of windows, swiped sideways -- on every screen, so a line of
  /// windows never folds into two.
  Widget _buildRow(int group, int row) {
    final WindowRow line = widget.groups[group].rows[row];
    final int start = _rowOffset(group, row);
    return WindowCardStrip(
      key: Key('window_page_view_${line.id}'),
      itemCount: line.nodes.length,
      itemBuilder: (BuildContext context, int index) => _card(group, start + index),
    );
  }

  /// A group: its heading, then its lines of windows. Lines after the first
  /// have no heading of their own -- they are the same kind of window -- and
  /// sit under a hairline.
  Widget _buildGroup(BuildContext context, int group) {
    final WindowGroup kind = widget.groups[group];
    return SectionSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 5,
                height: 26,
                decoration: BoxDecoration(
                  gradient: AppTheme.brandGradient,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: AppTheme.space3),
              Expanded(
                child: Text(
                  kind.title,
                  key: Key('library_group_${kind.id}'),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space4),
          for (int row = 0; row < kind.rows.length; row++) ...<Widget>[
            if (row > 0) ...<Widget>[
              const SizedBox(height: AppTheme.space5),
              Divider(
                height: 1,
                thickness: 1,
                color: AppTheme.line.withValues(alpha: 0.7),
              ),
              const SizedBox(height: AppTheme.space4),
            ],
            _buildRow(group, row),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String currentLabel =
        widget.groups[_focusGroup].nodes[_focusIndex].label;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.moduleTitle),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        // Straight to the review list, without picking a window first.
        //
        // Reopening a finished job to look at it is a different errand from
        // building a new one: the windows are already entered, and the only
        // way through to them was to open a size-input screen and back out of
        // it. Disabled while the job is empty, because there is nothing to
        // review yet -- shown disabled rather than hidden so it is still
        // findable the next time there is.
        actions: <Widget>[
          NextStepAction(
            tooltip: 'Review list',
            onPressed: widget.session.items.isEmpty ? null : _openReview,
          ),
        ],
      ),
      bottomNavigationBar: FlowProgressBar(stepId: FlowSteps.library.id),
      body: TutorialOverlay(
        screen: TutorialScreen.windowLibrary,
        child: AppScreenShell(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return ListView(
                children: <Widget>[
                  AppHeroHeader(
                    eyebrow: widget.moduleTitle.toUpperCase(),
                    title: 'Windows Library',
                    videoKey: widget.session.isFabrication
                        ? TutorialVideos.fabricationLibrary
                        : TutorialVideos.estimationLibrary,
                    subtitle:
                        'Browse the catalogue visually, then move directly into the detailed input workflow.',
                    trailing: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        gradient: AppTheme.brandGradient,
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      ),
                      child: const Icon(
                        Icons.window_rounded,
                        size: 38,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.space4),
                  Text(
                    widget.moduleTitle,
                    key: const Key('navigation_estimation_heading'),
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontSize: 0,
                      color: Colors.transparent,
                      height: 0,
                    ),
                  ),
                  Text(
                    '${widget.path.join(' / ')} / $currentLabel',
                    key: const Key('navigation_context_label'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 0,
                      color: Colors.transparent,
                      height: 0,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space5),
                  ProjectMetaStrip(
                    projectName: widget.session.projectName,
                    projectLocation: widget.session.projectLocation,
                    extras: <Widget>[
                      _InfoBadge(label: 'Flow', value: widget.moduleTitle),
                      _InfoBadge(label: 'Path', value: widget.path.join(' / ')),
                    ],
                  ),
                  for (int group = 0; group < widget.groups.length; group++) ...<Widget>[
                    const SizedBox(height: AppTheme.space6),
                    _buildGroup(context, group),
                  ],
                  const SizedBox(height: AppTheme.space6),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final String label;
  final String value;

  const _InfoBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space4,
        vertical: AppTheme.space3,
      ),
      decoration: AppTheme.infoChipDecoration(emphasized: true),
      child: RichText(
        text: TextSpan(
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.textPrimary),
          children: <InlineSpan>[
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
