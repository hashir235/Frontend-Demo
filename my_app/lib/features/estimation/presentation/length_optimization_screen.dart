import 'dart:convert';

import 'package:flutter/foundation.dart';
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
import '../data/optimization_repository.dart';
import '../models/cutting_report.dart';
import '../models/window_review_item.dart';
import 'material_selection_screen.dart';
import 'section_recalculation_screen.dart';

typedef MaterialSelectionBuilder =
    Widget Function(
      BuildContext context,
      String? projectId,
      String projectName,
      String projectLocation,
    );

class LengthOptimizationScreen extends StatefulWidget {
  final List<WindowReviewItem> items;
  final String? projectId;
  final String projectName;
  final String projectLocation;
  final String requestContext;
  final OptimizationRepository? repository;
  final MaterialSelectionBuilder? materialSelectionBuilder;
  final bool showPdfActions;

  const LengthOptimizationScreen({
    super.key,
    required this.items,
    this.projectId,
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

  bool get _canRecalculateSection => _selectedSection != null;

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

  Widget _buildCutCell(String text, {required bool isMarked}) {
    return Stack(
      alignment: Alignment.centerLeft,
      children: <Widget>[
        Text(
          text,
          style: TextStyle(
            color: isMarked
                ? AppTheme.textPrimary.withValues(alpha: 0.82)
                : AppTheme.textPrimary,
            fontWeight: isMarked ? FontWeight.w900 : FontWeight.w700,
            fontSize: 13,
          ),
        ),
        if (isMarked)
          Positioned.fill(
            child: Align(
              alignment: Alignment.center,
              child: Container(
                height: 2,
                color: AppTheme.royalBlue.withValues(alpha: 0.95),
              ),
            ),
          ),
      ],
    );
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
        headers: const <String, String>{'Content-Type': 'application/json'},
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
            ],
          ),
        );
      },
    );
  }

  Future<void> _openRecalculationScreen() async {
    final CuttingReportSection? section = _selectedSection;
    final CuttingReport? report = _report;
    if (section == null || report == null) {
      return;
    }

    final CuttingReport? updatedReport = await Navigator.of(context)
        .push<CuttingReport>(
          MaterialPageRoute<CuttingReport>(
            builder: (BuildContext context) => SectionRecalculationScreen(
              section: section,
              projectId: widget.projectId,
              requestContext: widget.requestContext,
              displayUnit: report.displayUnit,
              repository: _repository,
            ),
          ),
        );

    if (!mounted || updatedReport == null) {
      return;
    }

    final bool containsSelectedSection = updatedReport.sections.any(
      (CuttingReportSection candidate) => candidate.name == section.name,
    );

    setState(() {
      _report = updatedReport;
      _selectedSectionName = containsSelectedSection
          ? section.name
          : (updatedReport.sections.isEmpty
                ? null
                : updatedReport.sections.first.name);
      _markedCutRowKeys.clear();
    });
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
          widget.projectId,
          widget.projectName,
          widget.projectLocation,
        ) ??
        MaterialSelectionScreen(
          projectId: widget.projectId,
          projectName: widget.projectName,
          projectLocation: widget.projectLocation,
          requestContext: widget.requestContext,
        );
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (BuildContext context) => nextScreen),
    );
  }

  Widget? _buildBottomActions(BuildContext context) {
    if (_isLoading || _errorMessage != null || _report == null) {
      return null;
    }

    final bool canRecalculate = _canRecalculateSection;
    if (!widget.showPdfActions && !canRecalculate) {
      return null;
    }

    return BottomActionBar(
      children: <Widget>[
        if (widget.showPdfActions)
          Expanded(
            child: FilledButton.icon(
              onPressed: _generateCuttingPdf,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Download PDF'),
            ),
          ),
        if (widget.showPdfActions && canRecalculate)
          const SizedBox(width: AppTheme.space4),
        if (canRecalculate)
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: _openRecalculationScreen,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Re Calculation'),
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
        projectId: widget.projectId,
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
            onPressed: _canProceedToMaterialSelection
                ? _handleNextPressed
                : null,
            icon: const Icon(Icons.arrow_forward_rounded),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomActions(context),
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
          icon: Icons.auto_graph_rounded,
          title: 'Optimization failed',
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

    final CuttingReport? report = _report;
    if (report == null) {
      return const Center(
        child: StateMessageCard(
          icon: Icons.grid_off_rounded,
          title: 'No optimization data',
        ),
      );
    }

    if (report.sections.isEmpty) {
      return Center(
        child: StateMessageCard(
          icon: Icons.layers_clear_rounded,
          title: 'No optimization data',
          message: report.errors.isNotEmpty
              ? report.errors.join('\n')
              : 'No optimization data.',
        ),
      );
    }

    final CuttingReportSection? section = _selectedSection;

    return ListView(
      children: <Widget>[
        const AppHeroHeader(
          eyebrow: 'OPTIMIZATION',
          title: 'Cutting layout ready for production review',
          subtitle:
              'Compare sections, inspect grouped lengths, and mark finished cuts while keeping recalculation one tap away.',
        ),
        const SizedBox(height: AppTheme.space5),
        ProjectMetaStrip(
          projectName: widget.projectName,
          projectLocation: widget.projectLocation,
          extras: <Widget>[
            _MetaChip(label: 'Windows', value: '${widget.items.length}'),
          ],
        ),
        const SizedBox(height: AppTheme.space6),
        SectionSurfaceCard(
          title: 'Sections',
          subtitle:
              'Choose the section to inspect. The active section stays visually highlighted.',
          child: Wrap(
            spacing: AppTheme.space3,
            runSpacing: AppTheme.space3,
            children: report.sections
                .map((CuttingReportSection item) {
                  final bool isSelected = item.name == section?.name;
                  return ChoiceChip(
                    label: Text(item.name),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        _selectedSectionName = item.name;
                      });
                    },
                  );
                })
                .toList(growable: false),
          ),
        ),
        if (report.errors.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppTheme.space5),
          StateMessageCard(
            icon: Icons.warning_amber_rounded,
            title: 'Warnings',
            message: report.errors.join('\n'),
            iconColor: AppTheme.warning,
          ),
        ],
        if (section != null) ...<Widget>[
          const SizedBox(height: AppTheme.space6),
          Row(
            children: <Widget>[
              Expanded(
                child: MetricCard(
                  label: 'Selected Section',
                  value: section.name,
                  icon: Icons.straighten_rounded,
                ),
              ),
              if (section.summary != null) ...<Widget>[
                const SizedBox(width: AppTheme.space4),
                Expanded(
                  child: MetricCard(
                    label: 'Groups',
                    value: '${section.groups.length}',
                    icon: Icons.segment_rounded,
                    accent: AppTheme.tealAccent,
                  ),
                ),
              ],
            ],
          ),
          if (section.summary != null) ...<Widget>[
            const SizedBox(height: AppTheme.space5),
            _buildSummaryCard(context, section.summary!),
          ],
          const SizedBox(height: AppTheme.space5),
          ...section.groups.asMap().entries.map(
            (MapEntry<int, CuttingReportGroup> entry) => Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.space5),
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
    );
  }

  Widget _buildSummaryCard(BuildContext context, CuttingReportSummary summary) {
    final String usedLengths = summary.usedLengths.isEmpty
        ? '--'
        : summary.usedLengths.map(_stockDisplayInFeet).join(', ');
    return SectionSurfaceCard(
      title: 'Section Summary',
      child: Row(
        children: <Widget>[
          Expanded(
            child: MetricCard(
              label: 'Lengths',
              value: usedLengths,
              icon: Icons.format_list_bulleted_rounded,
            ),
          ),
          const SizedBox(width: AppTheme.space4),
          Expanded(
            child: MetricCard(
              label: 'Total Length',
              value: _stockDisplayInFeet(summary.totalLength),
              icon: Icons.stacked_line_chart_rounded,
              accent: AppTheme.tealAccent,
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
    final String wastageText =
        'Wastage: ${group.wastageDisplay}${group.offcut ? ' • Offcut' : ''}';
    return SectionSurfaceCard(
      title: 'Lengths: ${_stockDisplayInFeet(group.stockLenFt)}',
      trailing: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space4,
          vertical: AppTheme.space3,
        ),
        decoration: AppTheme.infoChipDecoration(emphasized: true),
        child: Text(
          wastageText,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: group.offcut ? AppTheme.warning : AppTheme.textPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: false,
          columns: const <DataColumn>[
            DataColumn(label: Text('WinSize')),
            DataColumn(label: Text('Window')),
            DataColumn(label: Text('No.')),
            DataColumn(label: Text('Dimension')),
            DataColumn(label: Text('Cuts')),
          ],
          rows: group.cuts
              .asMap()
              .entries
              .map((MapEntry<int, CuttingReportCut> entry) {
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
                      _buildCutCell(_winSizeForCut(cut), isMarked: isMarked),
                    ),
                    DataCell(_buildCutCell(cut.windowName, isMarked: isMarked)),
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
              })
              .toList(growable: false),
        ),
      ),
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
