import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_hero_header.dart';
import '../../../shared/widgets/app_screen_shell.dart';
import '../../../shared/widgets/section_surface_card.dart';
import '../../../shared/widgets/state_message_card.dart';
import '../../settings/state/app_settings.dart';
import '../data/project_repository.dart';
import '../models/saved_project.dart';
import '../state/estimate_session_store.dart';
import 'window_navigation_screen.dart';

class RecentProjectsScreen extends StatefulWidget {
  final EstimateFlow flow;
  final String moduleTitle;

  const RecentProjectsScreen({
    super.key,
    required this.flow,
    required this.moduleTitle,
  });

  @override
  State<RecentProjectsScreen> createState() => _RecentProjectsScreenState();
}

class _RecentProjectsScreenState extends State<RecentProjectsScreen> {
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

  const RecentProjectsListSection({
    super.key,
    required this.flow,
    required this.moduleTitle,
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
    _projectsFuture = _projectRepository.fetchRecentProjects(flow: widget.flow);
  }

  Future<void> _openProject(SavedProjectSummary project) async {
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
        setState(() {
          _projectsFuture = _projectRepository.fetchRecentProjects(
            flow: widget.flow,
          );
        });
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
                                        Text(
                                          project.projectName,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w900,
                                              ),
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
