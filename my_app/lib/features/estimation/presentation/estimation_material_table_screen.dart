import 'dart:convert';

import 'package:my_app/core/config/api_config.dart';
import 'package:my_app/core/network/auth_http_client.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_hero_header.dart';
import '../../../shared/widgets/app_screen_shell.dart';
import '../../../shared/widgets/bottom_action_bar.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/project_meta_strip.dart';
import '../../../shared/widgets/section_surface_card.dart';
import '../../../shared/widgets/state_message_card.dart';
import '../../fabrication/presentation/glass_report_screen.dart';
import '../data/cost_table_api_client.dart';
import '../models/cost_table.dart';
import 'bill_inputs_screen.dart';

class EstimationMaterialTableScreen extends StatefulWidget {
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

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? CostTableApiClient();
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


  Future<void> _generateMaterialPdf({
    String successMessage = 'Material PDF generated.',
  }) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    try {
      final http.Response response = await AuthHttpClient().post(
        ApiConfig.buildUri('/api/pdf/material'),
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(<String, Object?>{'projectId': widget.projectId}),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Unable to generate material PDF.')),
        );
        return;
      }

      String resolvedMessage = successMessage;
      try {
        final Object? decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final String? fileName = decoded['fileName'] as String?;
          if (fileName != null && fileName.isNotEmpty) {
            resolvedMessage = 'PDF ready: $fileName';
          }
        }
      } on FormatException {
        // keep fallback
      }

      messenger.showSnackBar(SnackBar(content: Text(resolvedMessage)));
    } on Exception {
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to reach local PDF service.')),
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
                  await _generateMaterialPdf(
                    successMessage:
                        'Material PDF generated in local downloads.',
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Share PDF'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _generateMaterialPdf(
                    successMessage:
                        'Material PDF generated. Native share can be wired next.',
                  );
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
        builder: (BuildContext context) => BillInputsScreen(
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

  void _openGlassReport() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            GlassReportScreen(projectId: widget.projectId),
      ),
    );
  }

  Widget? _buildBottomActions() {
    if (_isLoading || _errorMessage != null || _table == null) {
      return null;
    }
    final bool showGlassReport =
        widget.requestContext.toLowerCase() == 'fabrication';
    if (!widget.showPdfActions && !widget.showNextToBill && !showGlassReport) {
      return null;
    }

    return BottomActionBar(
      children: <Widget>[
        if (widget.showPdfActions)
          Expanded(
            child: FilledButton.icon(
              onPressed: _generateMaterialPdf,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Download PDF'),
            ),
          ),
        if (widget.showPdfActions && showGlassReport)
          const SizedBox(width: AppTheme.space4),
        if (showGlassReport)
          FilledButton.tonalIcon(
            onPressed: _openGlassReport,
            icon: const Icon(Icons.table_view_rounded),
            label: const Text('Glass Report'),
          ),
        if ((widget.showPdfActions || showGlassReport) && widget.showNextToBill)
          const SizedBox(width: AppTheme.space4),
        if (widget.showNextToBill)
          FilledButton(
            onPressed: _handleNextPressed,
            child: const Text('Next'),
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

  List<_MaterialDisplayRow> _displayRows(CostTable table) {
    final List<_MaterialDisplayRow> rows = <_MaterialDisplayRow>[];
    for (final CostTableRow row in table.rows) {
      if (row.lengths.isEmpty) {
        rows.add(
          _MaterialDisplayRow(
            section: row.section,
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
    return Scaffold(
      appBar: AppBar(title: Text(widget.screenTitle)),
      bottomNavigationBar: _buildBottomActions(),
      body: AppScreenShell(child: _buildBody(context)),
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
          title: widget.screenTitle,
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
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const <DataColumn>[
                DataColumn(label: Text('Section')),
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
        ),
      ],
    );
  }
}

class _MaterialDisplayRow {
  final String section;
  final String lengthDisplay;
  final int quantity;
  final double totalFt;
  final String totalFtDisplay;
  final double rate;
  final double totalRate;

  const _MaterialDisplayRow({
    required this.section,
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
