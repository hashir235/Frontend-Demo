import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_hero_header.dart';
import '../../../shared/widgets/app_screen_shell.dart';
import '../../../shared/widgets/section_surface_card.dart';
import '../../../shared/widgets/state_message_card.dart';
import '../../fabrication/presentation/glass_report_screen.dart';
import '../../flow_nav/models/flow_step.dart';
import '../../settings/state/app_settings.dart';
import '../data/project_repository.dart';
import '../models/saved_project.dart';
import '../state/estimate_session_store.dart';
import 'window_navigation_screen.dart';

class RecentProjectsScreen extends StatefulWidget {
  final EstimateFlow flow;
  final String moduleTitle;

  /// When set, tapping a project hands its id back instead of opening it in the
  /// window flow. The glass cutting report uses this: it needs the user to pick
  /// which project's glass to look at, not to reopen the windows themselves.
  final void Function(BuildContext context, SavedProjectSummary project)?
  onProjectSelected;

  const RecentProjectsScreen({
    super.key,
    required this.flow,
    required this.moduleTitle,
    this.onProjectSelected,
  });

  @override
  State<RecentProjectsScreen> createState() => _RecentProjectsScreenState();
}

class _RecentProjectsScreenState extends State<RecentProjectsScreen> {
  /// Set by [_openProject] when the caller supplied its own handler.
  bool get _hasCustomHandler => widget.onProjectSelected != null;

  final ProjectRepository _projectRepository = ProjectRepository();
  late Future<List<SavedProjectSummary>> _projectsFuture;
  String? _openingProjectId;

  @override
  void initState() {
    super.initState();
    _projectsFuture = _loadProjects();
  }

  Future<List<SavedProjectSummary>> _loadProjects() {
    return _projectRepository.fetchRecentProjects(flow: widget.flow);
  }

  void _reload() {
    setState(() {
      _projectsFuture = _loadProjects();
    });
  }

  Future<void> _openProject(SavedProjectSummary project) async {
    // The glass cutting report passes its own handler: it needs the user to
    // pick which project's glass to open, not to reopen the windows.
    if (_hasCustomHandler) {
      widget.onProjectSelected!(context, project);
      return;
    }

    setState(() {
      _openingProjectId = project.id;
    });

    try {
      final SavedProjectDetail detail = await _projectRepository.fetchProject(
        project.id,
      );
      if (!mounted) {
        return;
      }

      final EstimateSessionStore session = EstimateSessionStore(
        projectId: detail.id,
        projectName: detail.projectName,
        projectLocation: detail.projectLocation,
        flow: widget.flow,
        numberingMode: AppSettings.instance.numberingMode,
      );
      session.replaceItems(detail.windows);
      session.restoreOutputs(detail.outputs);

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => WindowNavigationScreen.root(
            session: session,
            rootLabel: 'Recent Project',
            moduleTitle: widget.moduleTitle,
          ),
        ),
      );
      if (mounted) {
        _reload();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _openingProjectId = null;
        });
      }
    }
  }

  String _formatUpdatedAt(DateTime? value) {
    if (value == null) {
      return '--';
    }
    final DateTime local = value.toLocal();
    String two(int part) => part.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  Widget _buildProjectCard(BuildContext context, SavedProjectSummary project) {
    final bool isOpening = _openingProjectId == project.id;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        onTap: isOpening ? null : () => _openProject(project),
        child: Ink(
          decoration: AppTheme.elevatedCardDecoration(),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.space6),
            child: Row(
              children: <Widget>[
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppTheme.royalBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.workspaces_rounded,
                    color: AppTheme.royalBlue,
                  ),
                ),
                const SizedBox(width: AppTheme.space5),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        project.projectName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: AppTheme.space2),
                      Text(
                        project.projectLocation,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppTheme.space4),
                      Wrap(
                        spacing: AppTheme.space3,
                        runSpacing: AppTheme.space3,
                        children: <Widget>[
                          _pill(context, 'Windows', '${project.windowCount}'),
                          _pill(context, 'Status', project.status),
                          _pill(
                            context,
                            'Updated',
                            _formatUpdatedAt(project.updatedAt),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTheme.space4),
                isOpening
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : const Icon(Icons.arrow_forward_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space3,
        vertical: AppTheme.space2,
      ),
      decoration: AppTheme.infoChipDecoration(),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recent Projects')),
      body: AppScreenShell(
        child: FutureBuilder<List<SavedProjectSummary>>(
          future: _projectsFuture,
          builder:
              (
                BuildContext context,
                AsyncSnapshot<List<SavedProjectSummary>> snapshot,
              ) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: StateMessageCard(
                      icon: Icons.cloud_off_rounded,
                      title: 'Unable to load recent projects',
                      message: snapshot.error.toString(),
                      action: FilledButton.icon(
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                      ),
                    ),
                  );
                }

                final List<SavedProjectSummary> projects =
                    snapshot.data ?? <SavedProjectSummary>[];
                if (projects.isEmpty) {
                  return const Center(
                    child: StateMessageCard(
                      icon: Icons.history_toggle_off_rounded,
                      title: 'No recent projects yet',
                      message:
                          'Create a project first and it will appear here for quick reopening.',
                    ),
                  );
                }

                return ListView(
                  children: <Widget>[
                    AppHeroHeader(
                      eyebrow: widget.moduleTitle.toUpperCase(),
                      title: 'Recent Projects',
                      subtitle:
                          'Open a saved project, continue the workflow, and keep the latest calculations close at hand.',
                    ),
                    const SizedBox(height: AppTheme.space6),
                    SectionSurfaceCard(
                      title: 'Saved Work',
                      subtitle:
                          'Tap any card to reopen its flow with the saved windows and outputs.',
                      child: Column(
                        children: projects
                            .map(
                              (SavedProjectSummary project) => Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppTheme.space4,
                                ),
                                child: _buildProjectCard(context, project),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                  ],
                );
              },
        ),
      ),
    );
  }
}

class RecentProjectsListSection extends StatefulWidget {
  final EstimateFlow flow;
  final String moduleTitle;

  /// Extra kinds to list alongside [flow].
  ///
  /// Fabrication holds two kinds of job -- aluminium and glass -- and a user
  /// looking for "that job from Tuesday" should not have to remember which
  /// button made it. They are listed together, each row saying which it is.
  final List<EstimateFlow> alsoInclude;

  const RecentProjectsListSection({
    super.key,
    required this.flow,
    required this.moduleTitle,
    this.alsoInclude = const <EstimateFlow>[],
  });

  @override
  State<RecentProjectsListSection> createState() =>
      _RecentProjectsListSectionState();
}

class _RecentProjectsListSectionState extends State<RecentProjectsListSection> {
  final ProjectRepository _projectRepository = ProjectRepository();
  late Future<List<SavedProjectSummary>> _projectsFuture;
  String? _openingProjectId;

  @override
  void initState() {
    super.initState();
    _projectsFuture = _fetchProjects();
  }

  /// Fetches every kind this section shows and merges them newest-first.
  Future<List<SavedProjectSummary>> _fetchProjects() async {
    final List<EstimateFlow> flows = <EstimateFlow>[
      widget.flow,
      ...widget.alsoInclude,
    ];
    final List<List<SavedProjectSummary>> results = await Future.wait(
      flows.map(
        (EstimateFlow flow) =>
            _projectRepository.fetchRecentProjects(flow: flow),
      ),
    );

    final List<SavedProjectSummary> merged = results
        .expand((List<SavedProjectSummary> list) => list)
        .toList();
    merged.sort((SavedProjectSummary a, SavedProjectSummary b) {
      final DateTime? left = a.updatedAt;
      final DateTime? right = b.updatedAt;
      // Anything without a date sinks to the bottom rather than jumping to the
      // top of the list.
      if (left == null && right == null) return 0;
      if (left == null) return 1;
      if (right == null) return -1;
      return right.compareTo(left);
    });
    return merged;
  }

  Future<void> _openProject(SavedProjectSummary project) async {
    setState(() {
      _openingProjectId = project.id;
    });

    try {
      // A glass job has no windows and no catalogue -- it reopens on the row
      // sheet it was typed into. Sending it through the window flow would show
      // an empty library and lose the rows.
      if (project.isGlass) {
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            settings: RouteSettings(name: FlowSteps.glassSize.id),
            builder: (_) => GlassReportScreen(
              projectId: project.id,
              projectName: project.projectName,
              projectLocation: project.projectLocation,
            ),
          ),
        );
        if (mounted) {
          setState(() => _projectsFuture = _fetchProjects());
        }
        return;
      }

      final SavedProjectDetail detail = await _projectRepository.fetchProject(
        project.id,
      );
      if (!mounted) {
        return;
      }

      final EstimateSessionStore session = EstimateSessionStore(
        projectId: detail.id,
        projectName: detail.projectName,
        projectLocation: detail.projectLocation,
        flow: widget.flow,
        numberingMode: AppSettings.instance.numberingMode,
      );
      session.replaceItems(detail.windows);
      session.restoreOutputs(detail.outputs);

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: RouteSettings(name: FlowSteps.library.id),
          builder: (_) => WindowNavigationScreen.root(
            session: session,
            rootLabel: 'Recent Project',
            moduleTitle: widget.moduleTitle,
          ),
        ),
      );
      if (mounted) {
        setState(() => _projectsFuture = _fetchProjects());
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _openingProjectId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SavedProjectSummary>>(
      future: _projectsFuture,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<SavedProjectSummary>> snapshot,
          ) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: AppTheme.space6),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.hasError) {
              return SectionSurfaceCard(
                title: 'Recent Projects',
                child: Text(
                  snapshot.error.toString(),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              );
            }

            final List<SavedProjectSummary> projects =
                snapshot.data ?? <SavedProjectSummary>[];
            if (projects.isEmpty) {
              return SectionSurfaceCard(
                title: 'Recent Projects',
                child: Text(
                  'No recent projects yet.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              );
            }

            return SectionSurfaceCard(
              title: 'Recent Projects',
              subtitle: 'Reopen the latest saved projects directly from here.',
              trailing: TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => RecentProjectsScreen(
                        flow: widget.flow,
                        moduleTitle: widget.moduleTitle,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.history_rounded),
                label: const Text('View all'),
              ),
              child: Column(
                children: projects
                    .take(4)
                    .map((SavedProjectSummary project) {
                      final bool isOpening = _openingProjectId == project.id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppTheme.space4),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMd,
                            ),
                            onTap: isOpening
                                ? null
                                : () => _openProject(project),
                            child: Ink(
                              padding: const EdgeInsets.all(AppTheme.space5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMd,
                                ),
                                border: Border.all(color: AppTheme.line),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Row(
                                          children: <Widget>[
                                            Flexible(
                                              child: Text(
                                                project.projectName,
                                                overflow: TextOverflow.ellipsis,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w900,
                                                    ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            _ProjectKindBadge(project: project),
                                          ],
                                        ),
                                        const SizedBox(height: AppTheme.space2),
                                        Text(
                                          project.projectLocation,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: AppTheme.textSecondary,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isOpening)
                                    const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                      ),
                                    )
                                  else
                                    const Icon(Icons.arrow_forward_rounded),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
            );
          },
    );
  }
}

/// Says whether a saved project is a glass job or an aluminium one.
///
/// Both kinds share one history, so without this a user has to open a project
/// to find out which it is -- and a glass job opened expecting windows looks
/// broken.
class _ProjectKindBadge extends StatelessWidget {
  final SavedProjectSummary project;

  const _ProjectKindBadge({required this.project});

  @override
  Widget build(BuildContext context) {
    final Color accent = project.isGlass
        ? AppTheme.amberAccent
        : AppTheme.tealAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.42)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            project.isGlass ? Icons.grid_view_rounded : Icons.window_rounded,
            size: 12,
            color: accent,
          ),
          const SizedBox(width: 4),
          Text(
            project.kindLabel,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
