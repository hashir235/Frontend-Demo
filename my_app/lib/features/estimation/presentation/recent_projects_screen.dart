import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
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

/// Every project of one kind, as a record: the site, the customer, what the
/// bill came to and what is still owed, and the shop's own notes -- the
/// "View all" list behind Recent Projects (Hashir, Oct 2026).
///
/// Tapping a card reopens the job, as before; the bin deletes it, and the
/// note under it is written and saved right there.
class RecentProjectsScreen extends StatefulWidget {
  final EstimateFlow flow;
  final String moduleTitle;

  /// When set, tapping a project hands its id back instead of opening it in the
  /// window flow. The glass cutting report uses this: it needs the user to pick
  /// which project's glass to look at, not to reopen the windows themselves.
  final void Function(BuildContext context, SavedProjectSummary project)?
  onProjectSelected;

  /// Injected in tests.
  final ProjectRepository? repository;

  const RecentProjectsScreen({
    super.key,
    required this.flow,
    required this.moduleTitle,
    this.onProjectSelected,
    this.repository,
  });

  /// Every record, not the latest few: the server's ceiling for this list.
  static const int recordLimit = 500;

  @override
  State<RecentProjectsScreen> createState() => _RecentProjectsScreenState();
}

class _RecentProjectsScreenState extends State<RecentProjectsScreen> {
  /// Set by [_openProject] when the caller supplied its own handler.
  bool get _hasCustomHandler => widget.onProjectSelected != null;

  late final ProjectRepository _projectRepository =
      widget.repository ?? ProjectRepository();
  late Future<List<SavedProjectSummary>> _projectsFuture;
  String? _openingProjectId;

  /// Deleted here: dropped from the list at once, without reloading it.
  final Set<String> _deletedIds = <String>{};
  String? _deletingProjectId;

  /// Notes saved here since the list loaded, by project.
  final Map<String, String> _savedNotes = <String, String>{};
  String? _savingNotesId;

  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _projectsFuture = _loadProjects();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<SavedProjectSummary>> _loadProjects() {
    return _projectRepository.fetchRecentProjects(
      flow: widget.flow,
      limit: RecentProjectsScreen.recordLimit,
      details: true,
    );
  }

  Future<void> _deleteProject(SavedProjectSummary project) async {
    final bool deleted = await deleteProjectWithConfirm(
      context,
      _projectRepository,
      project,
      onStarted: () => setState(() => _deletingProjectId = project.id),
    );
    if (!mounted) return;
    setState(() {
      _deletingProjectId = null;
      if (deleted) _deletedIds.add(project.id);
    });
  }

  void _reload() {
    setState(() {
      _savedNotes.clear();
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

  String _notesOf(SavedProjectSummary project) =>
      _savedNotes[project.id] ?? project.notes;

  Future<void> _editNotes(SavedProjectSummary project) async {
    final String before = _notesOf(project);
    final String? written = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _NotesSheet(project: project, initial: before),
    );
    if (written == null || written.trim() == before.trim() || !mounted) return;

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _savingNotesId = project.id);
    try {
      final String saved = await _projectRepository.saveProjectNotes(
        project.id,
        written,
      );
      if (!mounted) return;
      setState(() => _savedNotes[project.id] = saved);
      messenger.showSnackBar(
        SnackBar(
          content: Text(saved.isEmpty ? 'Note removed.' : 'Note saved.'),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not save the note. $error')),
      );
    } finally {
      if (mounted) setState(() => _savingNotesId = null);
    }
  }

  bool _matches(SavedProjectSummary project, String query) {
    if (query.isEmpty) return true;
    final ProjectBillSummary? bill = project.bill;
    final String haystack = <String>[
      project.projectName,
      project.projectLocation,
      bill?.customerName ?? '',
      bill?.customerPhone ?? '',
      _notesOf(project),
    ].join(' ').toLowerCase();
    return query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((String word) => word.isNotEmpty)
        .every(haystack.contains);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All Records')),
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
                      title: 'Unable to load your records',
                      message: snapshot.error.toString(),
                      action: FilledButton.icon(
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                      ),
                    ),
                  );
                }

                final List<SavedProjectSummary> all =
                    (snapshot.data ?? <SavedProjectSummary>[])
                        .where(
                          (SavedProjectSummary project) =>
                              !_deletedIds.contains(project.id),
                        )
                        .toList(growable: false);
                if (all.isEmpty) {
                  return const Center(
                    child: StateMessageCard(
                      icon: Icons.history_toggle_off_rounded,
                      title: 'No projects yet',
                      message:
                          'Create a project first and it will appear here for quick reopening.',
                    ),
                  );
                }

                final String query = _search.text.trim();
                final List<SavedProjectSummary> shown = all
                    .where((SavedProjectSummary p) => _matches(p, query))
                    .toList(growable: false);

                return ListView(
                  children: <Widget>[
                    _RecordsSummary(
                      projects: shown,
                      showsBills: widget.flow == EstimateFlow.estimation,
                    ),
                    const SizedBox(height: AppTheme.space5),
                    TextField(
                      key: const Key('records_search'),
                      controller: _search,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded),
                        hintText: 'Search site, customer, phone or location',
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear',
                                onPressed: _search.clear,
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.space5),
                    if (shown.isEmpty)
                      StateMessageCard(
                        icon: Icons.search_off_rounded,
                        title: 'Nothing matches "$query"',
                      )
                    else
                      for (final SavedProjectSummary project in shown)
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppTheme.space4,
                          ),
                          child: _RecordCard(
                            project: project,
                            notes: _notesOf(project),
                            showsBill:
                                !project.isGlass &&
                                project.context == 'estimation',
                            opening: _openingProjectId == project.id,
                            savingNotes: _savingNotesId == project.id,
                            onOpen: () => _openProject(project),
                            onEditNotes: () => _editNotes(project),
                            deleteButton: _hasCustomHandler
                                ? null
                                : _DeleteProjectButton(
                                    project: project,
                                    deleting: _deletingProjectId == project.id,
                                    onPressed:
                                        _openingProjectId != null ||
                                            _deletingProjectId != null
                                        ? null
                                        : () => _deleteProject(project),
                                  ),
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

/// "Rs 167,708", "Rs 1,250.5": rupees as the bill writes them.
String _rupees(double value) {
  final bool whole = value == value.roundToDouble();
  final String fixed = whole
      ? value.round().abs().toString()
      : value.abs().toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');
  final List<String> parts = fixed.split('.');
  final String digits = parts.first;
  final StringBuffer grouped = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
    grouped.write(digits[i]);
  }
  final String sign = value < 0 ? '-' : '';
  return 'Rs $sign$grouped${parts.length > 1 ? '.${parts[1]}' : ''}';
}

/// "10 Oct 2026, 14:20".
String _when(DateTime? value) {
  if (value == null) return '--';
  const List<String> months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final DateTime local = value.toLocal();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${local.day} ${months[local.month - 1]} ${local.year}, '
      '${two(local.hour)}:${two(local.minute)}';
}

/// The counts across the list as it is filtered: how many jobs, and -- on
/// estimates -- what their bills come to and what is still owed.
class _RecordsSummary extends StatelessWidget {
  final List<SavedProjectSummary> projects;
  final bool showsBills;

  const _RecordsSummary({required this.projects, required this.showsBills});

  @override
  Widget build(BuildContext context) {
    double billed = 0;
    double remaining = 0;
    int windows = 0;
    for (final SavedProjectSummary project in projects) {
      windows += project.windowCount;
      final ProjectBillSummary? bill = project.bill;
      if (bill == null) continue;
      billed += bill.grandTotal;
      remaining += bill.remainingDue > 0 ? bill.remainingDue : 0;
    }
    return Row(
      children: <Widget>[
        Expanded(
          child: _SummaryTile(
            key: const Key('records_total_projects'),
            label: 'Projects',
            value: '${projects.length}',
            icon: Icons.folder_open_rounded,
            accent: AppTheme.royalBlue,
          ),
        ),
        const SizedBox(width: AppTheme.space3),
        if (showsBills) ...<Widget>[
          Expanded(
            child: _SummaryTile(
              key: const Key('records_total_billed'),
              label: 'Billed',
              value: _rupees(billed),
              icon: Icons.receipt_long_rounded,
              accent: AppTheme.success,
            ),
          ),
          const SizedBox(width: AppTheme.space3),
          Expanded(
            child: _SummaryTile(
              key: const Key('records_total_remaining'),
              label: 'Remaining',
              value: _rupees(remaining),
              icon: Icons.account_balance_wallet_rounded,
              accent: remaining > 0 ? AppTheme.warning : AppTheme.success,
            ),
          ),
        ] else
          Expanded(
            child: _SummaryTile(
              label: 'Windows',
              value: '$windows',
              icon: Icons.window_rounded,
              accent: AppTheme.tealAccent,
            ),
          ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  const _SummaryTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppTheme.space4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: accent.withValues(alpha: 0.30)),
        boxShadow: AppTheme.softShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: accent),
          const SizedBox(height: AppTheme.space3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: text.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// One job, as a record.
class _RecordCard extends StatelessWidget {
  final SavedProjectSummary project;
  final String notes;

  /// Estimates carry a bill: customer, Grand Total, Remaining. Cutting and
  /// glass jobs have none, so their cards do not leave empty boxes for one.
  final bool showsBill;
  final bool opening;
  final bool savingNotes;
  final VoidCallback onOpen;
  final VoidCallback onEditNotes;
  final Widget? deleteButton;

  const _RecordCard({
    required this.project,
    required this.notes,
    required this.showsBill,
    required this.opening,
    required this.savingNotes,
    required this.onOpen,
    required this.onEditNotes,
    required this.deleteButton,
  });

  static (String, Color) _status(String status) => switch (status) {
    'billed' => ('Billed', AppTheme.success),
    'in_progress' => ('In progress', AppTheme.royalBlue),
    'draft' => ('Draft', AppTheme.slate),
    '' => ('Draft', AppTheme.slate),
    _ => (
      status[0].toUpperCase() + status.substring(1).replaceAll('_', ' '),
      AppTheme.slate,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ProjectBillSummary? bill = project.bill;
    final (String statusLabel, Color statusColor) = _status(project.status);
    final Color kindColor = project.isGlass
        ? AppTheme.amberAccent
        : AppTheme.tealAccent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('record_card_${project.id}'),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        onTap: opening ? null : onOpen,
        child: Ink(
          decoration: AppTheme.elevatedCardDecoration(),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.space5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Site, place and where the job stands.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: kindColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        project.isGlass
                            ? Icons.grid_view_rounded
                            : Icons.window_rounded,
                        color: kindColor,
                      ),
                    ),
                    const SizedBox(width: AppTheme.space4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            project.projectName,
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: <Widget>[
                              Icon(
                                Icons.place_outlined,
                                size: 15,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  project.projectLocation.isEmpty
                                      ? '--'
                                      : project.projectLocation,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppTheme.space3),
                    _Pill(label: statusLabel, color: statusColor),
                  ],
                ),
                if (showsBill) ...<Widget>[
                  const SizedBox(height: AppTheme.space4),
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.person_outline_rounded,
                        size: 18,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          bill == null
                              ? 'Bill not made yet'
                              : <String>[
                                  bill.customerName.isEmpty
                                      ? 'No customer name'
                                      : bill.customerName,
                                  if (bill.customerPhone.isNotEmpty)
                                    bill.customerPhone,
                                ].join('  ·  '),
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: bill == null || bill.customerName.isEmpty
                                ? AppTheme.textSecondary
                                : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppTheme.space4),
                // The figures, side by side.
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _Figure(
                        label: project.isGlass ? 'Kind' : 'Windows',
                        value: project.isGlass
                            ? 'Glass'
                            : '${project.windowCount}',
                      ),
                    ),
                    if (showsBill) ...<Widget>[
                      const SizedBox(width: AppTheme.space3),
                      Expanded(
                        flex: 2,
                        child: _Figure(
                          label: 'Grand Total',
                          value: bill == null ? '--' : _rupees(bill.grandTotal),
                        ),
                      ),
                      const SizedBox(width: AppTheme.space3),
                      Expanded(
                        flex: 2,
                        child: _Figure(
                          label: bill != null && bill.isPaid
                              ? 'Remaining · Paid'
                              : 'Remaining',
                          value: bill == null
                              ? '--'
                              : _rupees(
                                  bill.remainingDue > 0 ? bill.remainingDue : 0,
                                ),
                          accent: bill == null
                              ? null
                              : bill.remainingDue > 0
                              ? AppTheme.warning
                              : AppTheme.success,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppTheme.space4),
                _NotesLine(
                  key: Key('record_notes_${project.id}'),
                  notes: notes,
                  saving: savingNotes,
                  onTap: onEditNotes,
                ),
                const SizedBox(height: AppTheme.space3),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.schedule_rounded,
                      size: 15,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Updated ${_when(project.updatedAt)}',
                        style: text.bodySmall,
                      ),
                    ),
                    ?deleteButton,
                    if (opening)
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        ),
                      )
                    else
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: AppTheme.royalBlue,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;

  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 11.5,
        ),
      ),
    );
  }
}

/// One figure in a card's row: its value large, what it is small.
class _Figure extends StatelessWidget {
  final String label;
  final String value;
  final Color? accent;

  const _Figure({required this.label, required this.value, this.accent});

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final Color tone = accent ?? AppTheme.royalBlue;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space3,
        vertical: AppTheme.space3,
      ),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.labelSmall?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: text.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: accent ?? AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The shop's note on the job, or the way to add one.
class _NotesLine extends StatelessWidget {
  final String notes;
  final bool saving;
  final VoidCallback onTap;

  const _NotesLine({
    super.key,
    required this.notes,
    required this.saving,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool empty = notes.trim().isEmpty;
    return Material(
      color: AppTheme.amberAccent.withValues(alpha: empty ? 0.05 : 0.10),
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        onTap: saving ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.sticky_note_2_outlined,
                size: 18,
                color: AppTheme.amberAccent,
              ),
              const SizedBox(width: AppTheme.space3),
              Expanded(
                child: Text(
                  empty ? 'Add a note' : notes,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(
                    fontWeight: empty ? FontWeight.w700 : FontWeight.w600,
                    color: empty
                        ? AppTheme.textSecondary
                        : AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.space3),
              saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      empty ? Icons.add_rounded : Icons.edit_outlined,
                      size: 18,
                      color: AppTheme.textSecondary,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Writing the note: the box, and Save. Gives back what was written, or null
/// when the sheet is closed without saving.
class _NotesSheet extends StatefulWidget {
  final SavedProjectSummary project;
  final String initial;

  const _NotesSheet({required this.project, required this.initial});

  @override
  State<_NotesSheet> createState() => _NotesSheetState();
}

class _NotesSheetState extends State<_NotesSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Notes',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              Text(widget.project.projectName, style: text.bodySmall),
              const SizedBox(height: AppTheme.space4),
              TextField(
                key: const Key('project_notes_field'),
                controller: _controller,
                autofocus: true,
                minLines: 3,
                maxLines: 8,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Advance taken in cash, glass comes on Friday…',
                ),
              ),
              const SizedBox(height: AppTheme.space3),
              Row(
                children: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    key: const Key('project_notes_save'),
                    onPressed: () =>
                        Navigator.of(context).pop(_controller.text),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
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

  /// Injected in tests.
  final ProjectRepository? repository;

  const RecentProjectsListSection({
    super.key,
    required this.flow,
    required this.moduleTitle,
    this.alsoInclude = const <EstimateFlow>[],
    this.repository,
  });

  @override
  State<RecentProjectsListSection> createState() =>
      _RecentProjectsListSectionState();
}

class _RecentProjectsListSectionState extends State<RecentProjectsListSection> {
  late final ProjectRepository _projectRepository =
      widget.repository ?? ProjectRepository();
  late Future<List<SavedProjectSummary>> _projectsFuture;
  String? _openingProjectId;

  /// Deleted here: dropped from the list at once, and the next project moves
  /// up into the four shown, without reloading.
  final Set<String> _deletedIds = <String>{};
  String? _deletingProjectId;

  @override
  void initState() {
    super.initState();
    _projectsFuture = _fetchProjects();
  }

  Future<void> _deleteProject(SavedProjectSummary project) async {
    final bool deleted = await deleteProjectWithConfirm(
      context,
      _projectRepository,
      project,
      onStarted: () => setState(() => _deletingProjectId = project.id),
    );
    if (!mounted) return;
    setState(() {
      _deletingProjectId = null;
      if (deleted) _deletedIds.add(project.id);
    });
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
          setState(() {
            _projectsFuture = _fetchProjects();
          });
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
        setState(() {
          _projectsFuture = _fetchProjects();
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
                (snapshot.data ?? <SavedProjectSummary>[])
                    .where(
                      (SavedProjectSummary project) =>
                          !_deletedIds.contains(project.id),
                    )
                    .toList(growable: false);
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
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => RecentProjectsScreen(
                        flow: widget.flow,
                        moduleTitle: widget.moduleTitle,
                        repository: widget.repository,
                      ),
                    ),
                  );
                  // Projects deleted in the full list must not linger here.
                  if (mounted) {
                    setState(() {
                      _projectsFuture = _fetchProjects();
                    });
                  }
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
                                  _DeleteProjectButton(
                                    project: project,
                                    deleting: _deletingProjectId == project.id,
                                    onPressed:
                                        isOpening || _deletingProjectId != null
                                        ? null
                                        : () => _deleteProject(project),
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

/// Asks before a project is deleted. Deleting is one tap from the list, next
/// to the tap that opens the project, so it is never done on a single touch.
Future<bool> confirmProjectDelete(
  BuildContext context,
  SavedProjectSummary project,
) async {
  final bool? sure = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      key: const Key('delete_project_dialog'),
      icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.danger),
      title: const Text('Delete project?'),
      content: Text(
        '"${project.projectName}" (${project.projectLocation}) will be removed '
        'from your projects, with everything in it.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('confirm_delete_project'),
          style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return sure ?? false;
}

/// Deletes [project] once the shop says yes, and tells them how it went.
///
/// True once it is gone, so the list can drop it straight away rather than
/// reloading.
Future<bool> deleteProjectWithConfirm(
  BuildContext context,
  ProjectRepository repository,
  SavedProjectSummary project, {
  required VoidCallback onStarted,
}) async {
  if (!await confirmProjectDelete(context, project)) return false;
  if (!context.mounted) return false;
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  onStarted();
  try {
    await repository.deleteProject(project.id);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text('"${project.projectName}" deleted.')),
    );
    return true;
  } catch (error) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text('Could not delete the project. $error')),
    );
    return false;
  }
}

/// The bin beside each project, or a spinner while it is being deleted.
class _DeleteProjectButton extends StatelessWidget {
  final SavedProjectSummary project;
  final bool deleting;
  final VoidCallback? onPressed;

  const _DeleteProjectButton({
    required this.project,
    required this.deleting,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (deleting) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: AppTheme.danger,
          ),
        ),
      );
    }
    return IconButton(
      key: Key('delete_project_${project.id}'),
      tooltip: 'Delete project',
      onPressed: onPressed,
      icon: const Icon(Icons.delete_outline_rounded),
      color: AppTheme.danger,
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
