import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../data/optimization_repository.dart';
import '../models/cutting_report.dart';
import '../models/window_review_item.dart';
import '../../../core/theme/app_theme.dart';
import 'material_selection_screen.dart';

typedef MaterialSelectionBuilder =
    Widget Function(
      BuildContext context,
      String projectName,
      String projectLocation,
    );

class LengthOptimizationScreen extends StatefulWidget {
  final List<WindowReviewItem> items;
  final String projectName;
  final String projectLocation;
  final String requestContext;
  final OptimizationRepository? repository;
  final MaterialSelectionBuilder? materialSelectionBuilder;
  final bool showPdfActions;

  const LengthOptimizationScreen({
    super.key,
    required this.items,
    required this.projectName,
    required this.projectLocation,
    this.requestContext = 'estimation',
    this.repository,
    this.materialSelectionBuilder,
    this.showPdfActions = true,
  });

  @override
  State<LengthOptimizationScreen> createState() =>
      _LengthOptimizationScreenState();
}

class _LengthOptimizationScreenState extends State<LengthOptimizationScreen> {
  late final OptimizationRepository _repository;
  CuttingReport? _report;
  String? _errorMessage;
  bool _isLoading = true;
  String? _selectedSectionName;
  final Set<String> _markedCutRowKeys = <String>{};

  bool get _canProceedToMaterialSelection {
    final CuttingReport? report = _report;
    return !_isLoading &&
        _errorMessage == null &&
        report != null &&
        report.ok &&
        report.sections.isNotEmpty;
  }

  CuttingReportSection? get _selectedSection {
    final CuttingReport? report = _report;
    if (report == null || report.sections.isEmpty) {
      return null;
    }
    final String? selectedSectionName = _selectedSectionName;
    if (selectedSectionName == null) {
      return report.sections.first;
    }
    for (final CuttingReportSection section in report.sections) {
      if (section.name == selectedSectionName) {
        return section;
      }
    }
    return report.sections.first;
  }

  String _winSizeForCut(CuttingReportCut cut) => cut.dimension;

  String _pieceSymbolForCut(CuttingReportCut cut) {
    final int pipeIndex = cut.label.lastIndexOf('|');
    if (pipeIndex == -1 || pipeIndex + 1 >= cut.label.length) {
      return '--';
    }
    final String symbol = cut.label.substring(pipeIndex + 1).trim();
    return symbol.isEmpty ? '--' : symbol;
  }

  String _stockDisplayInFeet(double stockLenFt) {
    final String fixed = stockLenFt.toStringAsFixed(2);
    final String compact = fixed
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return '$compact ft';
  }

  String _cutRowKey(
    String sectionName,
    int groupIndex,
    int cutIndex,
    CuttingReportCut cut,
  ) {
    return '$sectionName|$groupIndex|$cutIndex|${cut.label}|${cut.lengthFt}';
  }

  void _toggleMarkedCutRow(String rowKey) {
    setState(() {
      if (_markedCutRowKeys.contains(rowKey)) {
        _markedCutRowKeys.remove(rowKey);
      } else {
        _markedCutRowKeys.add(rowKey);
      }
    });
  }

  Widget _buildCutCell(
    String text, {
    required bool isMarked,
    double? width,
  }) {
    final Widget content = Text(
      text,
      style: TextStyle(
        color: isMarked
            ? AppTheme.deepTeal.withValues(alpha: 0.82)
            : AppTheme.deepTeal,
        fontWeight: isMarked ? FontWeight.w800 : FontWeight.w700,
        fontSize: 13,
      ),
    );

    final Widget stacked = Stack(
      alignment: Alignment.centerLeft,
      children: <Widget>[
        content,
        if (isMarked)
          Positioned.fill(
            child: Align(
              alignment: Alignment.center,
              child: Container(
                height: 2,
                color: AppTheme.violet.withValues(alpha: 0.9),
              ),
            ),
          ),
      ],
    );

    if (width != null) {
      return SizedBox(width: width, child: stacked);
    }
    return stacked;
  }

  String _apiBaseUrl() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://127.0.0.1:8080';
  }

  Future<void> _generateCuttingPdf({
    String successMessage = 'PDF generated.',
  }) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    try {
      final http.Response response = await http.post(
        Uri.parse('${_apiBaseUrl()}/api/pdf/cutting'),
        headers: const <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode(const <String, Object?>{}),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Unable to generate cutting PDF.')),
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
        // Keep fallback success message.
      }

      messenger.showSnackBar(
        SnackBar(content: Text(resolvedMessage)),
      );
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
                  await _generateCuttingPdf(
                    successMessage: 'PDF generated in local downloads.',
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Share PDF'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _generateCuttingPdf(
                    successMessage:
                        'PDF generated. Native share can be wired next.',
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.chat_rounded),
                title: const Text('WhatsApp Share'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _generateCuttingPdf(
                    successMessage:
                        'PDF generated. WhatsApp share can be wired next.',
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
    if (!_canProceedToMaterialSelection) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Wait for optimization to finish before opening Material Selection.',
          ),
        ),
      );
      return;
    }

    final Widget nextScreen =
        widget.materialSelectionBuilder?.call(
          context,
          widget.projectName,
          widget.projectLocation,
        ) ??
        MaterialSelectionScreen(
          projectName: widget.projectName,
          projectLocation: widget.projectLocation,
          requestContext: widget.requestContext,
        );
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (BuildContext context) => nextScreen));
  }

  Widget? _buildBottomActions(BuildContext context) {
    if (_isLoading || _errorMessage != null || _report == null) {
      return null;
    }
    if (!widget.showPdfActions) {
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
                onPressed: _generateCuttingPdf,
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
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? OptimizationRepository();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final CuttingReport report = await _repository.fetchLengthOptimization(
        widget.items,
        context: widget.requestContext,
        projectName: widget.projectName,
        projectLocation: widget.projectLocation,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _report = report;
        _isLoading = false;
        _selectedSectionName = report.sections.isEmpty
            ? null
            : report.sections.first.name;
        _markedCutRowKeys.clear();
      });
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Length Optimization'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Next',
            onPressed: _canProceedToMaterialSelection ? _handleNextPressed : null,
            icon: const Icon(Icons.arrow_forward_rounded),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomActions(context),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[AppTheme.mist, AppTheme.ice],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: _buildBody(context),
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
            Text('Loading optimization report...'),
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

    final CuttingReport? report = _report;
    if (report == null) {
      return const Center(child: Text('No optimization data.'));
    }

    if (report.sections.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            report.errors.isNotEmpty
                ? report.errors.join('\n')
                : 'No optimization data.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.deepTeal,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    final CuttingReportSection? section = _selectedSection;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
                children: report.sections.map((CuttingReportSection item) {
                  final bool isSelected = item.name == section?.name;
                  return ChoiceChip(
                    label: Text(item.name),
                    selected: isSelected,
                    selectedColor: AppTheme.violet.withValues(alpha: 0.88),
                    backgroundColor: Colors.white,
                    checkmarkColor: Colors.white,
                    side: BorderSide(
                      color: isSelected
                          ? AppTheme.violet
                          : AppTheme.sky.withValues(alpha: 0.8),
                      width: isSelected ? 1.3 : 1,
                    ),
                    labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isSelected ? Colors.white : AppTheme.deepTeal,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    ),
                    onSelected: (_) {
                      setState(() {
                        _selectedSectionName = item.name;
                      });
                    },
                );
              }).toList(growable: false),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (report.errors.isNotEmpty) _buildErrorBanner(context, report),
                if (section != null) ...<Widget>[
                  _buildSectionHeader(context, section),
                  const SizedBox(height: 12),
                  if (section.summary != null)
                    _buildSummaryCard(context, section.summary!),
                  const SizedBox(height: 12),
                  ...section.groups.asMap().entries.map(
                    (MapEntry<int, CuttingReportGroup> entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildGroupCard(
                        context,
                        section.name,
                        entry.key,
                        entry.value,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(BuildContext context, CuttingReport report) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Text(
        report.errors.join('\n'),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Colors.red.shade800,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    CuttingReportSection section,
  ) {
    return Text(
      section.name,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        color: AppTheme.deepTeal,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    CuttingReportSummary summary,
  ) {
    final String usedLengths = summary.usedLengths.isEmpty
        ? '--'
        : summary.usedLengths
              .map(_stockDisplayInFeet)
              .join(', ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.sky.withValues(alpha: 0.85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Used Lengths: $usedLengths',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.deepTeal,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Total Length: ${_stockDisplayInFeet(summary.totalLength)}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.deepTeal,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(
    BuildContext context,
    String sectionName,
    int groupIndex,
    CuttingReportGroup group,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.sky.withValues(alpha: 0.85)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppTheme.deepTeal.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Lengths: ${_stockDisplayInFeet(group.stockLenFt)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.deepTeal,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Wastage: ${group.wastageDisplay}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.deepTeal,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (group.offcut) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              'Offcut',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.violet,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
              columns: const <DataColumn>[
                DataColumn(label: Text('WinSize')),
                DataColumn(label: Text('Window')),
                DataColumn(label: Text('No.')),
                DataColumn(label: Text('Dimention')),
                DataColumn(label: Text('Cuts')),
              ],
              rows: group.cuts.asMap().entries.map((
                MapEntry<int, CuttingReportCut> entry,
              ) {
                final int cutIndex = entry.key;
                final CuttingReportCut cut = entry.value;
                final String rowKey = _cutRowKey(
                  sectionName,
                  groupIndex,
                  cutIndex,
                  cut,
                );
                final bool isMarked = _markedCutRowKeys.contains(rowKey);
                return DataRow(
                  selected: isMarked,
                  onSelectChanged: (_) => _toggleMarkedCutRow(rowKey),
                  cells: <DataCell>[
                    DataCell(
                      _buildCutCell(
                        _winSizeForCut(cut),
                        isMarked: isMarked,
                        width: 110,
                      ),
                    ),
                    DataCell(
                      _buildCutCell(cut.windowName, isMarked: isMarked),
                    ),
                    DataCell(
                      _buildCutCell(
                        cut.windowNo.toString(),
                        isMarked: isMarked,
                      ),
                    ),
                    DataCell(
                      _buildCutCell(
                        _pieceSymbolForCut(cut),
                        isMarked: isMarked,
                      ),
                    ),
                    DataCell(
                      _buildCutCell(cut.lengthDisplay, isMarked: isMarked),
                    ),
                  ],
                );
              }).toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }
}


