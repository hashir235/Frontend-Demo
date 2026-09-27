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
  /// One carousel per row on a phone, each remembering its own page.
  late final List<PageController> _mobilePageControllers;
  late final List<int> _pageOf;

  /// The one window the screen has in hand -- the last one swiped to or
  /// tapped, in whichever row. Only it is drawn selected.
  int _focusGroup = 0;
  int _focusIndex = 0;

  @override
  void initState() {
    super.initState();
    _mobilePageControllers = <PageController>[
      for (final WindowGroup _ in widget.groups)
        PageController(viewportFraction: 0.84),
    ];
    _pageOf = List<int>.filled(widget.groups.length, 0);
  }

  @override
  void dispose() {
    for (final PageController controller in _mobilePageControllers) {
      controller.dispose();
    }
    super.dispose();
  }

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
              WindowGroup(id: 'family', title: node.label, nodes: node.children),
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

  int _crossAxisCount(double width) {
    if (width >= 1200) {
      return 4;
    }
    if (width >= 760) {
      return 3;
    }
    return 2;
  }

  /// Where row [group] starts when every window on the screen is counted in
  /// order -- the tour names its cards that way.
  int _offsetOf(int group) {
    int offset = 0;
    for (int g = 0; g < group; g++) {
      offset += widget.groups[g].nodes.length;
    }
    return offset;
  }

  /// One window's card, wired to the tour and to the screen's focus.
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

  Widget _buildMobileCardCarousel(BuildContext context, double width, int group) {
    final double cardHeight = width < 380 ? 360 : 390;
    final List<WindowType> nodes = widget.groups[group].nodes;

    return Column(
      children: <Widget>[
        SizedBox(
          key: Key('window_page_view_${widget.groups[group].id}'),
          height: cardHeight,
          child: PageView.builder(
            controller: _mobilePageControllers[group],
            physics: const BouncingScrollPhysics(),
            itemCount: nodes.length,
            onPageChanged: (int index) {
              _pageOf[group] = index;
              _focus(group, index);
            },
            itemBuilder: (BuildContext context, int index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index == nodes.length - 1 ? 0 : AppTheme.space4,
                ),
                // Phones get this carousel, not the grid below, so the tour's
                // targets have to be registered on both paths -- without this
                // the spotlight simply never appeared for real users.
                child: _card(group, index),
              );
            },
          ),
        ),
        if (nodes.length > 1) ...<Widget>[
          const SizedBox(height: AppTheme.space4),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppTheme.space2,
            runSpacing: AppTheme.space2,
            children: List<Widget>.generate(nodes.length, (int index) {
              final bool active = index == _pageOf[group];
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: active ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: active
                      ? AppTheme.royalBlue
                      : AppTheme.royalBlue.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _buildGrid(double width, int group) {
    final int crossAxisCount = _crossAxisCount(width);
    final double aspectRatio = crossAxisCount == 2 ? 0.66 : 0.78;
    return GridView.builder(
      key: Key('window_page_view_${widget.groups[group].id}'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.groups[group].nodes.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: AppTheme.space5,
        mainAxisSpacing: AppTheme.space5,
        childAspectRatio: aspectRatio,
      ),
      itemBuilder: (BuildContext context, int index) => _card(group, index),
    );
  }

  /// A row: its heading, then its windows.
  Widget _buildGroup(BuildContext context, double width, int group) {
    final WindowGroup row = widget.groups[group];
    final bool useMobileCarousel = width < 560;
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
                  row.title,
                  key: Key('library_group_${row.id}'),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space5),
          if (useMobileCarousel)
            _buildMobileCardCarousel(context, width, group)
          else
            _buildGrid(width, group),
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
                    _buildGroup(context, constraints.maxWidth, group),
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
