import 'package:flutter/material.dart';
import 'package:my_app/core/downloads/pdf_download_workflow.dart';

import '../../../core/theme/app_theme.dart';
import '../../flow_nav/models/flow_step.dart';
import '../../flow_nav/presentation/flow_progress_bar.dart';
import '../../tutorial/tutorial_controller.dart';
import '../../tutorial/tutorial_overlay.dart';
import '../../tutorial/tutorial_step.dart';
import '../../tutorial/tutorial_target.dart';
import '../../../shared/widgets/app_hero_header.dart';
import '../../../shared/widgets/app_screen_shell.dart';
import '../../../shared/widgets/bottom_action_bar.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/next_step_action.dart';
import '../../../shared/widgets/project_meta_strip.dart';
import '../../../shared/widgets/section_surface_card.dart';
import '../../../shared/widgets/state_message_card.dart';
import '../../fabrication/presentation/glass_report_screen.dart';
import '../../glass_fabrication/data/glass_project_api_client.dart';
import '../data/cost_table_api_client.dart';
import '../models/cost_table.dart';
import '../models/estimate_flow_state.dart';
import '../models/window_material.dart';
import '../state/estimate_session_store.dart';
import 'bill_inputs_screen.dart';
import '../../help_videos/tutorial_videos.dart';

class EstimationMaterialTableScreen extends StatefulWidget {
  final EstimateSessionStore session;
  final String gaugeLabel;
  final String gaugeValue;
  final String colorLabel;
  final String colorValue;
  final String? projectId;
  final String requestContext;
  final String projectName;
  final String projectLocation;
  final List<RateOverrideInput> overrides;
  final CostTableApiClient? apiClient;
  final String screenTitle;
  final bool showNextToBill;
  final bool showPdfActions;

  const EstimationMaterialTableScreen({
    super.key,
    required this.session,
    required this.gaugeLabel,
    required this.gaugeValue,
    required this.colorLabel,
    required this.colorValue,
    this.projectId,
    this.requestContext = 'estimation',
    required this.projectName,
    required this.projectLocation,
    required this.overrides,
    this.apiClient,
    this.screenTitle = 'Estimation Material Table',
    this.showNextToBill = true,
    this.showPdfActions = true,
  });

  @override
  State<EstimationMaterialTableScreen> createState() =>
      _EstimationMaterialTableScreenState();
}

class _EstimationMaterialTableScreenState
    extends State<EstimationMaterialTableScreen> {
  late final CostTableApiClient _apiClient;
  CostTable? _table;
  String? _errorMessage;
  bool _isLoading = true;

  /// While on, the table shows one line per section instead of one per cut
  /// length, and each line can be changed or removed.
  ///
  /// The two views exist because they answer different questions. Reading the
  /// table, you want to see which lengths make up a section; correcting it,
  /// the lengths are noise -- what you are changing is the section's feet and
  /// its rate.
  bool _editing = false;
  bool _saving = false;

  /// True while the glass job is being opened on the server, so the button
  /// cannot be pressed twice while the first press is still travelling.
  bool _openingGlass = false;

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? CostTableApiClient();
    widget.session.setMaterialSelection(
      EstimateMaterialSelection(
        gaugeValue: widget.gaugeValue,
        colorValue: widget.colorValue,
      ),
    );
    widget.session.setRateOverrides(widget.overrides);
    _loadTable();
  }

  Future<void> _loadTable() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final CostTable table = await _apiClient.fetchCostTable(
        gauge: widget.gaugeValue,
        color: widget.colorValue,
        projectId: widget.projectId,
        context: widget.requestContext,
        overrides: widget.overrides,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _table = table;
        _isLoading = false;
      });
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  static String _formatNumber(double value, {int decimals = 2}) {
    final String fixed = value.toStringAsFixed(decimals);
    if (!fixed.contains('.')) {
      return fixed;
    }
    return fixed
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  Future<void> _downloadMaterialPdf() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    try {
      final String fileName = await PdfDownloadWorkflow.generateAndDownload(
        endpoint: '/api/pdf/material',
        payload: <String, Object?>{'projectId': widget.projectId},
        generationFailureMessage: 'Unable to generate material PDF.',
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

  Future<void> _shareMaterialPdf() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    try {
      final String fileName = await PdfDownloadWorkflow.generateAndShare(
        endpoint: '/api/pdf/material',
        payload: <String, Object?>{'projectId': widget.projectId},
        generationFailureMessage: 'Unable to generate material PDF.',
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
                  await _downloadMaterialPdf();
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Share PDF'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _shareMaterialPdf();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleNextPressed() {
    final CostTable? table = _table;
    if (table == null) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: FlowSteps.billInputs.id),
        builder: (BuildContext context) => BillInputsScreen(
          session: widget.session,
          aluminiumTotal: table.grandTotal,
          gaugeLabel: widget.gaugeLabel,
          gaugeValue: widget.gaugeValue,
          colorLabel: widget.colorLabel,
          colorValue: widget.colorValue,
          projectId: widget.projectId,
          projectName: widget.projectName,
          projectLocation: widget.projectLocation,
        ),
      ),
    );
  }

  /// Hands this aluminium job over to the glass side, with nothing to type.
  ///
  /// The engine already worked out the glass list while cutting the aluminium.
  /// The server opens a glass project under the same name and location and
  /// carries those sizes across, so the fabricator lands on a filled-in glass
  /// job rather than an empty one they have to name and retype.
  ///
  /// Pressing it again reopens the same job instead of making a second copy.
  Future<void> _openGlassReport() async {
    final String? projectId = widget.projectId;
    if (projectId == null || projectId.isEmpty) {
      // Nothing to hand over from; fall back to the plain screen.
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: RouteSettings(name: FlowSteps.glassSize.id),
          builder: (_) => const GlassReportScreen(),
        ),
      );
      return;
    }

    setState(() => _openingGlass = true);
    try {
      final GlassProjectHandover handover = await GlassProjectApiClient()
          .openGlassSideOf(projectId);
      if (!mounted) return;
      setState(() => _openingGlass = false);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: RouteSettings(name: FlowSteps.glassSize.id),
          builder: (_) => GlassReportScreen(
            projectId: handover.projectId,
            projectName: handover.projectName,
            projectLocation: handover.projectLocation,
          ),
        ),
      );
    } on GlassProjectApiException catch (error) {
      if (!mounted) return;
      setState(() => _openingGlass = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Widget? _buildBottomActions() {
    if (_isLoading || _errorMessage != null || _table == null) {
      return null;
    }
    final bool showGlassReport =
        widget.requestContext.toLowerCase() == 'fabrication';
    // "Next" now lives in the AppBar (NextStepAction), so the bottom bar only
    // exists for the PDF/glass actions.
    if (!widget.showPdfActions && !showGlassReport) {
      return null;
    }

    return BottomActionBar(
      children: <Widget>[
        if (widget.showPdfActions)
          Expanded(
            child: FilledButton.icon(
              onPressed: _downloadMaterialPdf,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Download PDF'),
            ),
          ),
        if (widget.showPdfActions && showGlassReport)
          const SizedBox(width: AppTheme.space4),
        if (showGlassReport)
          TutorialTarget(
            id: 'table.glassReport',
            child: FilledButton.tonalIcon(
              onPressed: _openingGlass
                  ? null
                  : () {
                      TutorialController.instance.advanceAfterTap();
                      _openGlassReport();
                    },
              icon: _openingGlass
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.window_rounded),
              // Named for what it hands you rather than what it prints: this
              // opens the glass job with the sizes already in it.
              label: Text(_openingGlass ? 'Opening' : 'Glass Size'),
            ),
          ),
        if (widget.showPdfActions) ...<Widget>[
          const SizedBox(width: AppTheme.space4),
          IconButton.filledTonal(
            tooltip: 'Share',
            onPressed: _showShareOptions,
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ],
    );
  }

  /// Writes the edited table back and reloads from what the server saved.
  ///
  /// Taking the response rather than trusting the local list keeps the screen
  /// showing the same figures the PDF and the bill will use -- the totals are
  /// recomputed on the server, so anything it corrected shows up here too.
  Future<void> _persist(List<CostTableRow> rows) async {
    setState(() => _saving = true);
    try {
      final CostTable saved = await _apiClient.saveCostTable(
        rows: rows,
        projectId: widget.projectId,
        context: widget.requestContext,
      );
      if (!mounted) return;
      setState(() {
        _table = saved;
        _saving = false;
      });
    } on CostTableApiException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _deleteRow(CostTableRow row) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Remove section'),
        content: Text(
          'Remove ${row.section} from the material table? '
          'The bill and the PDF will be worked out without it.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final List<CostTableRow> rows = List<CostTableRow>.from(_table!.rows)
      ..removeWhere((CostTableRow r) => r.section == row.section);
    await _persist(rows);
  }

  Future<void> _editRow({CostTableRow? existing}) async {
    final _RowEdit? result = await showDialog<_RowEdit>(
      context: context,
      builder: (BuildContext ctx) => _MaterialRowDialog(existing: existing),
    );
    if (result == null) return;

    final List<CostTableRow> rows = List<CostTableRow>.from(_table!.rows);
    final CostTableRow updated = CostTableRow(
      section: result.section,
      // An edited row keeps the stock it was priced for. Dropping it here
      // would turn "M23 in 2mm" into a bare "M23" and quietly merge it with
      // the 1.2mm row sitting above it.
      gauge: existing?.gauge ?? '',
      color: existing?.color ?? '',
      totalFt: result.totalFt,
      totalFtDisplay: result.totalFt.toString(),
      rate: result.rate,
      totalPrice: result.totalFt * result.rate,
      lengths: existing?.lengths ?? const <CostTableLength>[],
    );

    if (existing == null) {
      rows.add(updated);
    } else {
      // Matched on stock as well as name: a job can hold two M23 rows, and
      // matching on the name alone would edit whichever came first -- not
      // necessarily the one the user tapped.
      final int at = rows.indexWhere(
        (CostTableRow r) =>
            r.section == existing.section &&
            r.gauge == existing.gauge &&
            r.color == existing.color,
      );
      if (at >= 0) rows[at] = updated;
    }
    await _persist(rows);
  }

  /// "2mm · Black" for a row, or the job-wide pair for a table costed before
  /// stock was per-window.
  ///
  /// Without it two rows both read "M23" at two different rates, and there is
  /// nothing on the page to say which bar each one is for.
  /// The gauge this row is priced for, falling back to the job-wide one on a
  /// table costed before stock was per-window.
  String _gaugeFor(CostTable table, CostTableRow row) {
    final String gauge = row.gauge.trim().isNotEmpty
        ? row.gauge.trim()
        : table.gauge.trim();
    return gauge.isEmpty ? '--' : gauge;
  }

  /// The colour, same fallback. Shown by its short name so the column stays
  /// narrow enough to sit beside the rest of the table.
  String _colorFor(CostTable table, CostTableRow row) {
    final String color = row.color.trim().isNotEmpty
        ? row.color.trim()
        : table.color.trim();
    return color.isEmpty ? '--' : AluminiumColors.shortLabelFor(color);
  }

  List<_MaterialDisplayRow> _displayRows(CostTable table) {
    final List<_MaterialDisplayRow> rows = <_MaterialDisplayRow>[];
    for (final CostTableRow row in table.rows) {
      final String gauge = _gaugeFor(table, row);
      final String color = _colorFor(table, row);
      if (row.lengths.isEmpty) {
        rows.add(
          _MaterialDisplayRow(
            section: row.section,
            gauge: gauge,
            color: color,
            lengthDisplay: '--',
            quantity: 0,
            totalFt: row.totalFt,
            totalFtDisplay: row.totalFtDisplay,
            rate: row.rate,
            totalRate: row.totalPrice,
          ),
        );
        continue;
      }

      for (final CostTableLength length in row.lengths) {
        rows.add(
          _MaterialDisplayRow(
            section: row.section,
            gauge: gauge,
            color: color,
            lengthDisplay: length.lengthDisplay,
            quantity: length.quantity,
            totalFt: row.totalFt,
            totalFtDisplay: row.totalFtDisplay,
            rate: row.rate,
            totalRate: row.totalPrice,
          ),
        );
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return TutorialOverlay(
      screen: TutorialScreen.materialTable,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.screenTitle),
          actions: <Widget>[
            // Fabrication reuses this screen with no bill step after it, so the
            // action only appears when there is somewhere to go next.
            if (widget.showNextToBill)
              TutorialTarget(
                id: 'table.next',
                child: NextStepAction(
                  onPressed:
                      _isLoading || _errorMessage != null || _table == null
                      ? null
                      : () {
                          TutorialController.instance.advanceAfterTap();
                          _handleNextPressed();
                        },
                ),
              ),
          ],
        ),
        bottomNavigationBar: FlowBottomBar(
          stepId: FlowSteps.material.id,
          actions: _buildBottomActions(),
        ),
        body: AppScreenShell(child: _buildBody(context)),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: StateMessageCard(
          icon: Icons.table_rows_outlined,
          title: 'Material table unavailable',
          message: _errorMessage,
          iconColor: AppTheme.danger,
          action: FilledButton.icon(
            onPressed: _loadTable,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ),
      );
    }

    final CostTable? table = _table;
    if (table == null) {
      return const Center(
        child: StateMessageCard(
          icon: Icons.grid_off_rounded,
          title: 'No material data',
        ),
      );
    }

    final List<_MaterialDisplayRow> rows = _displayRows(table);
    if (rows.isEmpty) {
      return const Center(
        child: StateMessageCard(
          icon: Icons.inventory_2_outlined,
          title: 'No material rows found',
          message: 'No material rows are available for the current project.',
        ),
      );
    }

    return ListView(
      children: <Widget>[
        AppHeroHeader(
          eyebrow: widget.requestContext.toUpperCase(),
          title: widget.requestContext == 'fabrication'
              ? 'Final Material Table'
              : widget.screenTitle,
          videoKey: widget.requestContext == 'fabrication'
              ? TutorialVideos.fabricationMaterialTable
              : TutorialVideos.estimationMaterialTable,
          subtitle:
              'A polished summary of section lengths, quantities, rates, and totals for ordering and costing.',
        ),
        const SizedBox(height: AppTheme.space5),
        ProjectMetaStrip(
          projectName: widget.projectName,
          projectLocation: widget.projectLocation,
          extras: <Widget>[
            _MetaChip(label: 'Gage', value: widget.gaugeLabel),
            _MetaChip(label: 'Colour', value: widget.colorLabel),
          ],
        ),
        const SizedBox(height: AppTheme.space6),
        Row(
          children: <Widget>[
            Expanded(
              child: MetricCard(
                label: 'Sections',
                value: '${table.rows.length}',
                icon: Icons.view_module_rounded,
              ),
            ),
            const SizedBox(width: AppTheme.space4),
            Expanded(
              child: MetricCard(
                label: 'Grand Total',
                value: _formatNumber(table.grandTotal),
                icon: Icons.request_quote_rounded,
                accent: AppTheme.tealAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space6),
        SectionSurfaceCard(
          title: 'Material Summary',
          subtitle:
              'Lengths are shown in the user-readable display format returned by the backend.',
          child: TutorialTarget(
            id: 'table.summary',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _editing
                            ? 'Correct anything the cut list could not know'
                            : 'Material table',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (_editing)
                      TextButton.icon(
                        onPressed: _saving ? null : () => _editRow(),
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: const Text('Add section'),
                      ),
                    TextButton.icon(
                      onPressed: _saving
                          ? null
                          : () => setState(() => _editing = !_editing),
                      icon: Icon(
                        _editing
                            ? Icons.check_rounded
                            : Icons.edit_outlined,
                        size: 20,
                      ),
                      label: Text(_editing ? 'Done' : 'Edit'),
                    ),
                  ],
                ),
                if (_editing)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.space3),
                    child: Text(
                      'Changes here carry through to the bill and the PDF.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                if (_saving) const LinearProgressIndicator(minHeight: 2),
                SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _editing
                  ? DataTable(
                      columns: const <DataColumn>[
                        DataColumn(label: Text('Section')),
                        DataColumn(label: Text('Gauge')),
                        DataColumn(label: Text('Color')),
                        DataColumn(label: Text('Total ft')),
                        DataColumn(label: Text('Rates')),
                        DataColumn(label: Text('Total Rates')),
                        DataColumn(label: Text('')),
                      ],
                      rows: table.rows
                          .map(
                            (CostTableRow row) => DataRow(
                              cells: <DataCell>[
                                DataCell(Text(row.section)),
                                DataCell(Text(_gaugeFor(table, row))),
                                DataCell(Text(_colorFor(table, row))),
                                DataCell(Text(row.totalFtDisplay)),
                                DataCell(Text(_formatNumber(row.rate))),
                                DataCell(Text(_formatNumber(row.totalPrice))),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      IconButton(
                                        tooltip: 'Edit',
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 20,
                                        ),
                                        color: AppTheme.royalBlue,
                                        onPressed: _saving
                                            ? null
                                            : () => _editRow(existing: row),
                                      ),
                                      IconButton(
                                        tooltip: 'Remove',
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          size: 20,
                                        ),
                                        color: AppTheme.danger,
                                        onPressed: _saving
                                            ? null
                                            : () => _deleteRow(row),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(growable: false),
                    )
                  : DataTable(
                      columns: const <DataColumn>[
                        DataColumn(label: Text('Section')),
                        DataColumn(label: Text('Gauge')),
                        DataColumn(label: Text('Color')),
                        DataColumn(label: Text('Length')),
                        DataColumn(label: Text('Quantity')),
                        DataColumn(label: Text('Total ft')),
                        DataColumn(label: Text('Rates')),
                        DataColumn(label: Text('Total Rates')),
                      ],
                      rows: rows
                          .map(
                            (_MaterialDisplayRow row) => DataRow(
                              cells: <DataCell>[
                                DataCell(Text(row.section)),
                                DataCell(Text(row.gauge)),
                                DataCell(Text(row.color)),
                                DataCell(Text(row.lengthDisplay)),
                                DataCell(Text('${row.quantity}')),
                                DataCell(Text(row.totalFtDisplay)),
                                DataCell(Text(_formatNumber(row.rate))),
                                DataCell(Text(_formatNumber(row.totalRate))),
                              ],
                            ),
                          )
                          .toList(growable: false),
                    ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// What the row dialog hands back once it is happy with the numbers.
class _RowEdit {
  final String section;
  final double totalFt;
  final double rate;

  const _RowEdit({
    required this.section,
    required this.totalFt,
    required this.rate,
  });
}

/// Adds or corrects one section.
///
/// Refuses empty names, feet at or below zero and negative rates -- each of
/// which would otherwise reach a customer's invoice as a nonsense line. The
/// total is shown as it is typed rather than asked for, because a total that
/// disagrees with feet times rate is exactly the error nobody notices.
class _MaterialRowDialog extends StatefulWidget {
  final CostTableRow? existing;

  const _MaterialRowDialog({this.existing});

  @override
  State<_MaterialRowDialog> createState() => _MaterialRowDialogState();
}

class _MaterialRowDialogState extends State<_MaterialRowDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _section = TextEditingController(
    text: widget.existing?.section ?? '',
  );
  late final TextEditingController _feet = TextEditingController(
    text: widget.existing == null ? '' : '${widget.existing!.totalFt}',
  );
  late final TextEditingController _rate = TextEditingController(
    text: widget.existing == null ? '' : '${widget.existing!.rate}',
  );

  @override
  void dispose() {
    _section.dispose();
    _feet.dispose();
    _rate.dispose();
    super.dispose();
  }

  double get _total {
    final double f = double.tryParse(_feet.text.trim()) ?? 0;
    final double r = double.tryParse(_rate.text.trim()) ?? 0;
    return f * r;
  }

  String? _positive(String? value, String what) {
    final double? parsed = double.tryParse((value ?? '').trim());
    if (parsed == null) return 'Enter $what';
    if (parsed <= 0) return '$what must be more than zero';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add section' : 'Edit section'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(
              controller: _section,
              textCapitalization: TextCapitalization.characters,
              // The section a row belongs to is what ties it to a rate and to
              // the cut list; renaming an existing one would orphan both.
              enabled: widget.existing == null,
              decoration: const InputDecoration(
                labelText: 'Section',
                hintText: 'e.g. D29',
              ),
              validator: (String? v) =>
                  (v ?? '').trim().isEmpty ? 'Enter a section' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _feet,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Total feet'),
              onChanged: (_) => setState(() {}),
              validator: (String? v) => _positive(v, 'total feet'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _rate,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Rate per foot'),
              onChanged: (_) => setState(() {}),
              validator: (String? v) {
                final double? parsed = double.tryParse((v ?? '').trim());
                if (parsed == null) return 'Enter a rate';
                if (parsed < 0) return 'A rate cannot be negative';
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'Total',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  _total.toStringAsFixed(2),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() != true) return;
            Navigator.of(context).pop(
              _RowEdit(
                section: _section.text.trim().toUpperCase(),
                totalFt: double.parse(_feet.text.trim()),
                rate: double.parse(_rate.text.trim()),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _MaterialDisplayRow {
  final String section;
  final String gauge;
  final String color;
  final String lengthDisplay;
  final int quantity;
  final double totalFt;
  final String totalFtDisplay;
  final double rate;
  final double totalRate;

  const _MaterialDisplayRow({
    required this.section,
    required this.gauge,
    required this.color,
    required this.lengthDisplay,
    required this.quantity,
    required this.totalFt,
    required this.totalFtDisplay,
    required this.rate,
    required this.totalRate,
  });
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
