import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/theme/app_theme.dart';
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

  TextStyle? _tableValueTextStyle(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: AppTheme.deepTeal,
      fontWeight: FontWeight.w700,
    );
  }

  String _apiBaseUrl() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://127.0.0.1:8080';
  }

  Future<void> _generateMaterialPdf({
    String successMessage = 'Material PDF generated.',
  }) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    try {
      final http.Response response = await http.post(
        Uri.parse('${_apiBaseUrl()}/api/pdf/material'),
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(const <String, Object?>{}),
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
        // Keep fallback message.
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
        builder: (BuildContext context) => GlassReportScreen(
          projectId: widget.projectId,
        ),
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

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: AppTheme.sky.withValues(alpha: 0.7)),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppTheme.deepTeal.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            if (widget.showPdfActions) ...<Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: _generateMaterialPdf,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Download PDF'),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                tooltip: 'Share',
                onPressed: _showShareOptions,
                icon: const Icon(Icons.share_outlined),
              ),
            ],
            if (showGlassReport) ...<Widget>[
              if (widget.showPdfActions) const SizedBox(width: 12),
              FilledButton.tonalIcon(
                onPressed: _openGlassReport,
                icon: const Icon(Icons.table_view_rounded),
                label: const Text('Glass Report'),
              ),
            ],
            if (widget.showNextToBill) ...<Widget>[
              if (widget.showPdfActions || showGlassReport)
                const SizedBox(width: 12),
              FilledButton(
                onPressed: _handleNextPressed,
                child: const Text('Next'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<_MaterialDisplayRow> _displayRows(CostTable table) {
    final List<_MaterialDisplayRow> rows = <_MaterialDisplayRow>[];
    for (final CostTableRow row in table.rows) {
      if (row.lengths.isEmpty) {
        rows.add(
          _MaterialDisplayRow(
            section: row.section,
            length: '--',
            quantity: 0,
            totalFt: row.totalFt,
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
            length: length.lengthFt,
            quantity: length.quantity,
            totalFt: row.totalFt,
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              AppTheme.ice,
              AppTheme.sky.withValues(alpha: 0.42),
              AppTheme.mist,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildBody(context),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Loading material table...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadTable,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final CostTable? table = _table;
    if (table == null) {
      return const Center(child: Text('No material data.'));
    }

    final List<_MaterialDisplayRow> rows = _displayRows(table);
    if (rows.isEmpty) {
      return _buildShell(
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('No material rows found for the current project.'),
          ),
        ),
      );
    }

    return _buildShell(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        children: <Widget>[
          _buildHeaderCard(context, table),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                AppTheme.deepTeal.withValues(alpha: 0.08),
              ),
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
                        DataCell(
                          Text(
                            row.section,
                            style: _tableValueTextStyle(context),
                          ),
                        ),
                        DataCell(
                          Text(
                            row.length is String
                                ? row.length as String
                                : '${_formatNumber(row.length as double, decimals: 1)} ft',
                            style: _tableValueTextStyle(context),
                          ),
                        ),
                        DataCell(
                          Text(
                            '${row.quantity}',
                            style: _tableValueTextStyle(context),
                          ),
                        ),
                        DataCell(
                          Text(
                            _formatNumber(row.totalFt),
                            style: _tableValueTextStyle(context),
                          ),
                        ),
                        DataCell(
                          Text(
                            _formatNumber(row.rate),
                            style: _tableValueTextStyle(context),
                          ),
                        ),
                        DataCell(
                          Text(
                            _formatNumber(row.totalRate),
                            style: _tableValueTextStyle(context),
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShell({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppTheme.sky.withValues(alpha: 0.8)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppTheme.deepTeal.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildHeaderCard(BuildContext context, CostTable table) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: <Color>[
            AppTheme.violet.withValues(alpha: 0.12),
            AppTheme.sky.withValues(alpha: 0.14),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _MaterialInfoPill(label: 'Gage', value: widget.gaugeLabel),
              _MaterialInfoPill(label: 'Color', value: widget.colorLabel),
              _MaterialInfoPill(
                label: 'Grand Total',
                value: _formatNumber(table.grandTotal),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MaterialDisplayRow {
  final String section;
  final Object length;
  final int quantity;
  final double totalFt;
  final double rate;
  final double totalRate;

  const _MaterialDisplayRow({
    required this.section,
    required this.length,
    required this.quantity,
    required this.totalFt,
    required this.rate,
    required this.totalRate,
  });
}

class _MaterialInfoPill extends StatelessWidget {
  final String label;
  final String value;

  const _MaterialInfoPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.sky.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppTheme.deepTeal.withValues(alpha: 0.66),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.deepTeal,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
