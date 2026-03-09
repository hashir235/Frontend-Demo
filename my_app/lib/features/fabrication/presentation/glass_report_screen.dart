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
import '../data/glass_report_api_client.dart';
import '../models/glass_report.dart';

class GlassReportScreen extends StatefulWidget {
  final String? projectId;
  final GlassReportApiClient? apiClient;

  const GlassReportScreen({super.key, this.projectId, this.apiClient});

  @override
  State<GlassReportScreen> createState() => _GlassReportScreenState();
}

class _GlassReportScreenState extends State<GlassReportScreen> {
  late final GlassReportApiClient _apiClient;
  GlassReport? _report;
  String? _errorMessage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? GlassReportApiClient();
    _loadReport();
  }

  String _winSizeForRow(GlassReportRow row) {
    final String inputSize = row.inputSize.trim();
    return inputSize.isEmpty ? '--' : inputSize;
  }

  String _glassSizeForRow(GlassReportRow row) {
    return '${row.heightDisplay} x ${row.widthDisplay}';
  }


  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final GlassReport report = await _apiClient.fetchGlassReport(
        projectId: widget.projectId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _report = report;
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

  Future<void> _generateGlassPdf({
    String successMessage = 'Glass PDF generated.',
  }) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    try {
      final http.Response response = await AuthHttpClient().post(
        ApiConfig.buildUri('/api/pdf/glass'),
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(<String, Object?>{'projectId': widget.projectId}),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Unable to generate glass PDF.')),
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
                  await _generateGlassPdf(
                    successMessage: 'Glass PDF generated in local downloads.',
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Share PDF'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _generateGlassPdf(
                    successMessage:
                        'Glass PDF generated. Native share can be wired next.',
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _goHome() {
    Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
  }

  Widget? _buildBottomActions() {
    if (_isLoading || _errorMessage != null) {
      return null;
    }
    return BottomActionBar(
      children: <Widget>[
        Expanded(
          child: FilledButton.icon(
            onPressed: _generateGlassPdf,
            icon: const Icon(Icons.download_rounded),
            label: const Text('Download PDF'),
          ),
        ),
        const SizedBox(width: AppTheme.space4),
        IconButton.filledTonal(
          tooltip: 'Home',
          onPressed: _goHome,
          icon: const Icon(Icons.home_rounded),
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
      appBar: AppBar(title: const Text('Glass Report')),
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
          icon: Icons.table_rows_rounded,
          title: 'Glass report unavailable',
          message: _errorMessage,
          iconColor: AppTheme.danger,
          action: FilledButton.icon(
            onPressed: _loadReport,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ),
      );
    }

    final GlassReport? report = _report;
    if (report == null || report.rows.isEmpty) {
      return const Center(
        child: StateMessageCard(
          icon: Icons.grid_off_rounded,
          title: 'No glass rows found',
          message:
              'Run Fabrication Length Optimization first to generate the latest glass report.',
        ),
      );
    }

    return ListView(
      children: <Widget>[
        const AppHeroHeader(
          eyebrow: 'GLASS REPORT',
          title: 'Fabrication glass table ready for issue and print',
          subtitle:
              'Use the latest fabrication output to review window sizes, glass sizes, rubber types, and quantities.',
        ),
        const SizedBox(height: AppTheme.space5),
        ProjectMetaStrip(
          projectName: report.projectName,
          projectLocation: report.projectLocation,
          extras: <Widget>[
            _MetaChip(label: 'Rows', value: '${report.rows.length}'),
          ],
        ),
        const SizedBox(height: AppTheme.space6),
        Row(
          children: <Widget>[
            Expanded(
              child: MetricCard(
                label: 'Report Rows',
                value: '${report.rows.length}',
                icon: Icons.table_chart_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space6),
        SectionSurfaceCard(
          title: 'Glass Cutting Table',
          subtitle:
              'Window input sizes and final glass sizes are grouped in a clean production-ready table.',
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const <DataColumn>[
                DataColumn(label: Text('WinSize')),
                DataColumn(label: Text('Label')),
                DataColumn(label: Text('WinNo')),
                DataColumn(label: Text('Rub')),
                DataColumn(label: Text('Qty')),
                DataColumn(label: Text('Glass Size')),
              ],
              rows: report.rows
                  .map((GlassReportRow row) {
                    return DataRow(
                      cells: <DataCell>[
                        DataCell(Text(_winSizeForRow(row))),
                        DataCell(Text(row.windowName)),
                        DataCell(Text('${row.windowNo}')),
                        DataCell(Text(row.rubberType)),
                        DataCell(Text('${row.quantity}')),
                        DataCell(Text(_glassSizeForRow(row))),
                      ],
                    );
                  })
                  .toList(growable: false),
            ),
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
