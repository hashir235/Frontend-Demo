import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/theme/app_theme.dart';
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

  String _projectValue(String value) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? '--' : trimmed;
  }

  String _winSizeForRow(GlassReportRow row) {
    final String inputSize = row.inputSize.trim();
    return inputSize.isEmpty ? '--' : inputSize;
  }

  String _glassSizeForRow(GlassReportRow row) {
    return '${row.heightDisplay} x ${row.widthDisplay}';
  }

  String _apiBaseUrl() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://127.0.0.1:8080';
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
      final http.Response response = await http.post(
        Uri.parse('${_apiBaseUrl()}/api/pdf/glass'),
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(const <String, Object?>{}),
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
            Expanded(
              child: FilledButton.icon(
                onPressed: _generateGlassPdf,
                icon: const Icon(Icons.download_rounded),
                label: const Text('Download PDF'),
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filledTonal(
              tooltip: 'Home',
              onPressed: _goHome,
              icon: const Icon(Icons.home_rounded),
            ),
            const SizedBox(width: 12),
            IconButton.filledTonal(
              tooltip: 'Share',
              onPressed: _showShareOptions,
              icon: const Icon(Icons.share_outlined),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Glass Report')),
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
            Text('Loading glass report...'),
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
                onPressed: _loadReport,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final GlassReport? report = _report;
    if (report == null || report.rows.isEmpty) {
      return _buildShell(
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No glass rows found. Run Fabrication Length Optimization first.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return _buildShell(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.violet.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.sky.withValues(alpha: 0.55)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Rows: ${report.rows.length}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.deepTeal,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Project: ${_projectValue(report.projectName)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.deepTeal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Location: ${_projectValue(report.projectLocation)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.deepTeal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                AppTheme.deepTeal.withValues(alpha: 0.08),
              ),
              columns: const <DataColumn>[
                DataColumn(label: Text('WinSize')),
                DataColumn(label: Text('Label')),
                DataColumn(label: Text('WinNo')),
                DataColumn(label: Text('Rub')),
                DataColumn(label: Text('Qty')),
                DataColumn(label: Text('Glass Size')),
              ],
              rows: report.rows
                  .asMap()
                  .entries
                  .map((entry) {
                    final GlassReportRow row = entry.value;
                    return DataRow(
                      cells: <DataCell>[
                        DataCell(_valueText(_winSizeForRow(row))),
                        DataCell(_valueText(row.windowName)),
                        DataCell(_valueText('${row.windowNo}')),
                        DataCell(_valueText(row.rubberType)),
                        DataCell(_valueText('${row.quantity}')),
                        DataCell(_valueText(_glassSizeForRow(row))),
                      ],
                    );
                  })
                  .toList(growable: false),
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

  Widget _valueText(String value) {
    return Text(
      value,
      style: const TextStyle(
        color: AppTheme.deepTeal,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
