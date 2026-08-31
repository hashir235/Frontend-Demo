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
import '../models/window_type.dart';
import '../state/estimate_session_store.dart';
import '../widgets/window_navigation_card.dart';
import 'input/input_registry.dart';
import 'review_list_screen.dart';
import '../../help_videos/tutorial_videos.dart';

class WindowNavigationScreen extends StatefulWidget {
  final List<WindowType> nodes;
  final List<String> path;
  final EstimateSessionStore session;
  final String moduleTitle;

  const WindowNavigationScreen({
    super.key,
    required this.nodes,
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
      nodes: WindowCatalog.rootForFlow(isFabrication: session.isFabrication),
      path: <String>[rootLabel],
      session: session,
      moduleTitle: moduleTitle,
    );
  }

  @override
  State<WindowNavigationScreen> createState() => _WindowNavigationScreenState();
}

class _WindowNavigationScreenState extends State<WindowNavigationScreen> {
  int _selectedIndex = 0;
  late final PageController _mobilePageController;

  @override
  void initState() {
    super.initState();
    _mobilePageController = PageController(viewportFraction: 0.84);
  }

  @override
  void dispose() {
    _mobilePageController.dispose();
    super.dispose();
  }

  void _onNodeTap(WindowType node) {
    if (node.hasChildren) {
      // Still inside the library, just a level deeper, so the chain stays on
      // the same bubble.
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: RouteSettings(name: FlowSteps.library.id),
          builder: (_) => WindowNavigationScreen(
            nodes: node.children,
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

  Widget _buildMobileCardCarousel(BuildContext context, double width) {
    final double cardHeight = width < 380 ? 330 : 360;

    return Column(
      children: <Widget>[
        SizedBox(
          key: const Key('window_page_view'),
          height: cardHeight,
          child: PageView.builder(
            controller: _mobilePageController,
            physics: const BouncingScrollPhysics(),
            itemCount: widget.nodes.length,
            onPageChanged: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            itemBuilder: (BuildContext context, int index) {
              final WindowType node = widget.nodes[index];
              final bool isSelected = index == _selectedIndex;
              return Padding(
                padding: EdgeInsets.only(
                  right: index == widget.nodes.length - 1 ? 0 : AppTheme.space4,
                ),
                // Phones get this carousel, not the grid below, so the tour's
                // targets have to be registered on both paths -- without this
                // the spotlight simply never appeared for real users.
                child: TutorialTarget(
                  id: index == 0 ? 'library.sliding' : 'library.card.$index',
                  child: WindowNavigationCard(
                    node: node,
                    isFocused: isSelected,
                    isSelected: isSelected,
                    parallaxShift: 0,
                    onTap: () {
                      setState(() {
                        _selectedIndex = index;
                      });
                      TutorialController.instance.advanceAfterTap();
                      _onNodeTap(node);
                    },
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppTheme.space4),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppTheme.space2,
          runSpacing: AppTheme.space2,
          children: List<Widget>.generate(widget.nodes.length, (int index) {
            final bool active = index == _selectedIndex;
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final String currentLabel = widget.nodes[_selectedIndex].label;

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
              final bool useMobileCarousel = constraints.maxWidth < 560;
              final int crossAxisCount = _crossAxisCount(constraints.maxWidth);
              final double aspectRatio = crossAxisCount == 2 ? 0.70 : 0.82;

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
                  const SizedBox(height: AppTheme.space6),
                  SectionSurfaceCard(
                    title: 'Window Library',
                    subtitle:
                        'Selected: $currentLabel. Tap any tile to open a family or start detailed input.',
                    child: useMobileCarousel
                        ? _buildMobileCardCarousel(
                            context,
                            constraints.maxWidth,
                          )
                        : GridView.builder(
                            key: const Key('window_page_view'),
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: widget.nodes.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: AppTheme.space5,
                                  mainAxisSpacing: AppTheme.space5,
                                  childAspectRatio: aspectRatio,
                                ),
                            itemBuilder: (BuildContext context, int index) {
                              final WindowType node = widget.nodes[index];
                              final bool isSelected = index == _selectedIndex;
                              // The tour points at the first card -- Sliding
                              // Window at the top of the catalogue -- as its
                              // worked example.
                              return TutorialTarget(
                                id: index == 0
                                    ? 'library.sliding'
                                    : 'library.card.$index',
                                child: WindowNavigationCard(
                                  node: node,
                                  isFocused: isSelected,
                                  isSelected: isSelected,
                                  parallaxShift: 0,
                                  onTap: () {
                                    setState(() {
                                      _selectedIndex = index;
                                    });
                                    TutorialController.instance
                                        .advanceAfterTap();
                                    _onNodeTap(node);
                                  },
                                ),
                              );
                            },
                          ),
                  ),
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
