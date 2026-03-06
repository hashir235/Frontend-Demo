import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recent Projects')),
      body: FutureBuilder<List<SavedProjectSummary>>(
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
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          snapshot.error.toString(),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 14),
                        FilledButton(
                          onPressed: _reload,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final List<SavedProjectSummary> projects =
                  snapshot.data ?? <SavedProjectSummary>[];
              if (projects.isEmpty) {
                return Center(
                  child: Text(
                    'No recent projects yet.',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.deepTeal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemBuilder: (BuildContext context, int index) {
                  final SavedProjectSummary project = projects[index];
                  final bool isOpening = _openingProjectId == project.id;
                  return InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: isOpening ? null : () => _openProject(project),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppTheme.sky.withValues(alpha: 0.8),
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: AppTheme.deepTeal.withValues(alpha: 0.08),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  project.projectName,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        color: AppTheme.deepTeal,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  project.projectLocation,
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        color: AppTheme.deepTeal,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Windows: ${project.windowCount}   Status: ${project.status}',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: AppTheme.deepTeal),
                                ),
                                Text(
                                  'Updated: ${_formatUpdatedAt(project.updatedAt)}',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: AppTheme.deepTeal),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          isOpening
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Icon(Icons.arrow_forward_rounded),
                        ],
                      ),
                    ),
                  );
                },
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemCount: projects.length,
              );
            },
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
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: isOpening ? null : () => _openProject(project),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.sky.withValues(alpha: 0.8)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppTheme.deepTeal.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    project.projectName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.deepTeal,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    project.projectLocation,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.deepTeal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Windows: ${project.windowCount}   Status: ${project.status}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppTheme.deepTeal),
                  ),
                  Text(
                    'Updated: ${_formatUpdatedAt(project.updatedAt)}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppTheme.deepTeal),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            isOpening
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : const Icon(Icons.arrow_forward_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageCard(
    BuildContext context,
    String message, {
    VoidCallback? onRetry,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.sky.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.deepTeal,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (onRetry != null) ...<Widget>[
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Recent Projects',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppTheme.deepTeal,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<SavedProjectSummary>>(
          future: _projectsFuture,
          builder:
              (
                BuildContext context,
                AsyncSnapshot<List<SavedProjectSummary>> snapshot,
              ) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return _buildMessageCard(
                    context,
                    snapshot.error.toString(),
                    onRetry: _reload,
                  );
                }

                final List<SavedProjectSummary> projects =
                    snapshot.data ?? <SavedProjectSummary>[];
                if (projects.isEmpty) {
                  return _buildMessageCard(context, 'No recent projects yet.');
                }

                return Column(
                  children: projects
                      .map(
                        (SavedProjectSummary project) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildProjectCard(context, project),
                        ),
                      )
                      .toList(growable: false),
                );
              },
        ),
      ],
    );
  }
}
