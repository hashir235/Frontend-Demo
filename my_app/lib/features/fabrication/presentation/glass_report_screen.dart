import 'package:flutter/material.dart';
import 'package:my_app/core/downloads/pdf_download_workflow.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_hero_header.dart';
import '../../../shared/widgets/app_screen_shell.dart';
import '../../../shared/widgets/bottom_action_bar.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/project_meta_strip.dart';
import '../../../shared/widgets/section_surface_card.dart';
import '../../../shared/widgets/state_message_card.dart';
import '../data/glass_report_api_client.dart';
import '../models/glass_report.dart';
import 'glass_row_editor_sheet.dart';
import 'glass_sheet_optimization_screen.dart';

/// Glass Cutting Report — now fully editable.
///
/// The table can be populated three ways:
///  1. Loaded from a previous fabrication calculation (auto rows).
///  2. Edited in place — any row (including auto rows) can be changed/deleted
///     before generating the PDF or running glass-sheet optimization.
///  3. Built entirely by hand — a user who only has loose glass sizes (no
///     window calculation) can open this screen and add rows manually.
///
/// Edits are kept in [_rows] locally and pushed to the backend via
/// [GlassReportApiClient.saveGlassReport] before any PDF / optimization step so
/// the saved rows always match what the user sees.
class GlassReportScreen extends StatefulWidget {
  final String? projectId;
  final GlassReportApiClient? apiClient;

  const GlassReportScreen({super.key, this.projectId, this.apiClient});

  @override
  State<GlassReportScreen> createState() => _GlassReportScreenState();
}

class _GlassReportScreenState extends State<GlassReportScreen> {
  late final GlassReportApiClient _apiClient;

  final List<GlassReportRow> _rows = <GlassReportRow>[];
  String _projectName = '';
  String _projectLocation = '';

  bool _isLoading = true;
  bool _isSaving = false;
  bool _dirty = false;

  // A non-blocking note shown above the table (e.g. "no saved rows yet").
  String? _note;
  // A hard load error (network/server) that warrants a retry button.
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? GlassReportApiClient();
    _loadReport();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  bool _isNoDataError(String message) {
    final String lower = message.toLowerCase();
    return lower.contains('no glass data') ||
        lower.contains('no glass cutting table') ||
        lower.contains('run fabrication');
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
      _note = null;
    });

    try {
      final GlassReport report = await _apiClient.fetchGlassReport(
        projectId: widget.projectId,
      );
      if (!mounted) return;
      setState(() {
        _rows
          ..clear()
          ..addAll(report.rows);
        _projectName = report.projectName;
        _projectLocation = report.projectLocation;
        _isLoading = false;
        _dirty = false;
        _note = report.rows.isEmpty
            ? 'No glass rows yet. Tap "Add Row" to enter glass pieces manually.'
            : null;
      });
    } on GlassReportApiException catch (error) {
      if (!mounted) return;
      final bool noData = _isNoDataError(error.message);
      setState(() {
        _rows.clear();
        _isLoading = false;
        if (noData) {
          // Manual-only path: start with an empty editable table.
          _note =
              'No saved glass report found. Tap "Add Row" to build a glass '
              'cutting list manually.';
          _loadError = null;
        } else {
          _loadError = error.message;
        }
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = error.toString();
      });
    }
  }

  // ── Row editing ───────────────────────────────────────────────────────────

  int get _nextWindowNo {
    int highest = 0;
    for (final GlassReportRow row in _rows) {
      if (row.windowNo > highest) {
        highest = row.windowNo;
      }
    }
    return highest + 1;
  }

  Future<void> _addRow() async {
    final GlassReportRow? row = await GlassRowEditorSheet.show(
      context,
      suggestedWindowNo: _nextWindowNo,
    );
    if (row == null) return;
    setState(() {
      _rows.add(row);
      _dirty = true;
      _note = null;
    });
  }

  Future<void> _editRow(int index) async {
    final GlassReportRow? updated = await GlassRowEditorSheet.show(
      context,
      existingRow: _rows[index],
      suggestedWindowNo: _rows[index].windowNo > 0
          ? _rows[index].windowNo
          : _nextWindowNo,
    );
    if (updated == null) return;
    setState(() {
      _rows[index] = updated;
      _dirty = true;
    });
  }

  Future<void> _deleteRow(int index) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Delete row?'),
        content: const Text('This glass row will be removed from the table.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _rows.removeAt(index);
      _dirty = true;
    });
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  GlassReport _buildReport() {
    return GlassReport(
      ok: true,
      errors: const <String>[],
      projectName: _projectName,
      projectLocation: _projectLocation,
      rows: List<GlassReportRow>.unmodifiable(_rows),
    );
  }

  /// Saves the current rows to the backend. Returns true on success. When
  /// [silent] is true no success snackbar is shown (used before PDF/sheets).
  Future<bool> _saveReport({bool silent = false}) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _isSaving = true);
    try {
      final GlassReport saved = await _apiClient.saveGlassReport(
        report: _buildReport(),
        projectId: widget.projectId,
      );
      if (!mounted) return false;
      setState(() {
        _rows
          ..clear()
          ..addAll(saved.rows);
        if (saved.projectName.isNotEmpty) _projectName = saved.projectName;
        if (saved.projectLocation.isNotEmpty) {
          _projectLocation = saved.projectLocation;
        }
        _dirty = false;
        _isSaving = false;
      });
      if (!silent) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          const SnackBar(content: Text('Glass report saved.')),
        );
      }
      return true;
    } on Exception catch (error) {
      if (!mounted) return false;
      setState(() => _isSaving = false);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text('Save failed: $error')));
      return false;
    }
  }

  // ── PDF / navigation ──────────────────────────────────────────────────────

  bool _ensureHasRows() {
    if (_rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one glass row first.')),
      );
      return false;
    }
    return true;
  }

  Future<void> _downloadGlassPdf() async {
    if (!_ensureHasRows()) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    // Persist edits first so the PDF reflects the current table.
    if (_dirty && !await _saveReport(silent: true)) return;

    messenger.hideCurrentSnackBar();
    try {
      final String fileName = await PdfDownloadWorkflow.generateAndDownload(
        endpoint: '/api/pdf/glass',
        payload: <String, Object?>{'projectId': widget.projectId},
        generationFailureMessage: 'Unable to generate glass PDF.',
      );
      messenger.showSnackBar(
        SnackBar(content: Text('PDF downloaded to Downloads: $fileName')),
      );
    } on PdfDownloadException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to reach PDF service.')),
      );
    }
  }

  Future<void> _shareGlassPdf() async {
    if (!_ensureHasRows()) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    if (_dirty && !await _saveReport(silent: true)) return;

    messenger.hideCurrentSnackBar();
    try {
      final String fileName = await PdfDownloadWorkflow.generateAndShare(
        endpoint: '/api/pdf/glass',
        payload: <String, Object?>{'projectId': widget.projectId},
        generationFailureMessage: 'Unable to generate glass PDF.',
      );
      messenger.showSnackBar(
        SnackBar(content: Text('Opening share sheet: $fileName')),
      );
    } on PdfDownloadException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to reach PDF service.')),
      );
    }
  }

  Future<void> _showShareOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.download_rounded),
                title: const Text('Download PDF'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _downloadGlassPdf();
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Share PDF'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _shareGlassPdf();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openGlassSheets() async {
    if (!_ensureHasRows()) return;
    // Save so the glass-sheets PDF (which reads server state) stays consistent.
    if (_dirty && !await _saveReport(silent: true)) return;
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GlassSheetOptimizationScreen(
          projectId: widget.projectId,
          glassReport: _buildReport(),
        ),
      ),
    );
  }

  void _goHome() {
    Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
  }

  // ── Display helpers ───────────────────────────────────────────────────────

  String _winSizeForRow(GlassReportRow row) {
    final String inputSize = row.inputSize.trim();
    return inputSize.isEmpty ? '--' : inputSize;
  }

  String _glassSizeForRow(GlassReportRow row) {
    return '${row.widthDisplay} x ${row.heightDisplay}';
  }

  // ── Bottom bar ────────────────────────────────────────────────────────────

  Widget? _buildBottomActions() {
    if (_isLoading || _loadError != null) {
      return null;
    }
    return BottomActionBar(
      children: <Widget>[
        Expanded(
          child: FilledButton.icon(
            onPressed: _downloadGlassPdf,
            icon: const Icon(Icons.picture_as_pdf_rounded),
            label: const Text('PDF'),
          ),
        ),
        const SizedBox(width: AppTheme.space4),
        IconButton.filledTonal(
          tooltip: 'Home',
          onPressed: _goHome,
          icon: const Icon(Icons.home_rounded),
        ),
        const SizedBox(width: AppTheme.space4),
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: _openGlassSheets,
            icon: const Icon(Icons.auto_awesome_mosaic_rounded),
            label: const Text(
              'Glass Sheets',
              maxLines: 1,
              overflow: TextOverflow.visible,
              softWrap: false,
            ),
          ),
        ),
        const SizedBox(width: AppTheme.space4),
        IconButton.filledTonal(
          tooltip: 'Share',
          onPressed: _showShareOptions,
          icon: const Icon(Icons.share_outlined),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Glass Report'),
        actions: <Widget>[
          if (!_isLoading && _loadError == null)
            IconButton(
              tooltip: _dirty ? 'Save changes' : 'Saved',
              onPressed: (_isSaving || !_dirty) ? null : () => _saveReport(),
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_dirty ? Icons.save_rounded : Icons.check_circle_rounded),
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomActions(),
      body: AppScreenShell(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return Center(
        child: StateMessageCard(
          icon: Icons.table_rows_rounded,
          title: 'Glass report unavailable',
          message: _loadError,
          iconColor: AppTheme.danger,
          action: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              FilledButton.icon(
                onPressed: _loadReport,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
              const SizedBox(height: AppTheme.space3),
              OutlinedButton.icon(
                onPressed: () {
                  // Let the user proceed manually even if loading failed.
                  setState(() {
                    _loadError = null;
                    _rows.clear();
                    _note =
                        'Manual entry mode. Tap "Add Row" to build a glass '
                        'cutting list.';
                  });
                },
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('Enter manually'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      children: <Widget>[
        const AppHeroHeader(
          eyebrow: 'GLASS REPORT',
          title: 'Fabrication glass table ready for issue and print',
          subtitle:
              'Review, edit, add, or delete glass rows. You can also build a '
              'glass cutting list manually without any window calculation.',
        ),
        const SizedBox(height: AppTheme.space5),
        ProjectMetaStrip(
          projectName: _projectName,
          projectLocation: _projectLocation,
          extras: <Widget>[
            _MetaChip(label: 'Rows', value: '${_rows.length}'),
          ],
        ),
        const SizedBox(height: AppTheme.space6),
        Row(
          children: <Widget>[
            Expanded(
              child: MetricCard(
                label: 'Report Rows',
                value: '${_rows.length}',
                icon: Icons.table_chart_rounded,
              ),
            ),
            const SizedBox(width: AppTheme.space4),
            Expanded(
              child: MetricCard(
                label: 'Total Pieces',
                value: '${_totalPieces()}',
                icon: Icons.widgets_rounded,
                accent: AppTheme.tealAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space6),
        SectionSurfaceCard(
          title: 'Glass Cutting Table',
          subtitle:
              'Tap a row to edit, or use the buttons to add and remove rows.',
          trailing: FilledButton.tonalIcon(
            onPressed: _addRow,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Row'),
          ),
          child: _rows.isEmpty
              ? _buildEmptyTableHint(context)
              : _buildEditableTable(context),
        ),
        const SizedBox(height: AppTheme.space7),
      ],
    );
  }

  int _totalPieces() {
    int total = 0;
    for (final GlassReportRow row in _rows) {
      total += row.quantity;
    }
    return total;
  }

  Widget _buildEmptyTableHint(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.space6),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.grid_off_rounded,
            size: 48,
            color: AppTheme.textSecondary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: AppTheme.space4),
          Text(
            _note ?? 'No glass rows yet.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.space5),
          FilledButton.icon(
            onPressed: _addRow,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add First Row'),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableTable(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (_note != null) ...<Widget>[
          Text(
            _note!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.space4),
        ],
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 22,
            columns: const <DataColumn>[
              DataColumn(label: Text('WinSize')),
              DataColumn(label: Text('Label')),
              DataColumn(label: Text('WinNo')),
              DataColumn(label: Text('Rub')),
              DataColumn(label: Text('Qty')),
              DataColumn(label: Text('Glass Size')),
              DataColumn(label: Text('Edit')),
            ],
            rows: _rows.asMap().entries.map((MapEntry<int, GlassReportRow> entry) {
              final int index = entry.key;
              final GlassReportRow row = entry.value;
              return DataRow(
                cells: <DataCell>[
                  DataCell(Text(_winSizeForRow(row)), onTap: () => _editRow(index)),
                  DataCell(
                    Text(row.windowName.isEmpty ? '--' : row.windowName),
                    onTap: () => _editRow(index),
                  ),
                  DataCell(
                    Text(row.windowNo > 0 ? '${row.windowNo}' : '--'),
                    onTap: () => _editRow(index),
                  ),
                  DataCell(
                    Text(row.rubberType.isEmpty ? '--' : row.rubberType),
                    onTap: () => _editRow(index),
                  ),
                  DataCell(Text('${row.quantity}'), onTap: () => _editRow(index)),
                  DataCell(
                    Text(_glassSizeForRow(row)),
                    onTap: () => _editRow(index),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconButton(
                          tooltip: 'Edit',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.edit_rounded, size: 20),
                          color: AppTheme.royalBlue,
                          onPressed: () => _editRow(index),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.delete_outline_rounded, size: 20),
                          color: AppTheme.danger,
                          onPressed: () => _deleteRow(index),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(growable: false),
          ),
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetaChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space4,
        vertical: AppTheme.space3,
      ),
      decoration: AppTheme.infoChipDecoration(emphasized: true),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
