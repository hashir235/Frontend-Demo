import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_hero_header.dart';
import '../../../shared/widgets/app_screen_shell.dart';
import '../../../shared/widgets/bottom_action_bar.dart';
import '../../../shared/widgets/project_meta_strip.dart';
import '../../../shared/widgets/section_surface_card.dart';
import '../../../shared/widgets/state_message_card.dart';
import '../data/cost_table_api_client.dart';
import '../data/rate_review_api_client.dart';
import '../models/cost_table.dart';
import '../models/rate_review.dart';
import 'estimation_material_table_screen.dart';

class RateReviewScreen extends StatefulWidget {
  final String gaugeLabel;
  final String gaugeValue;
  final String colorLabel;
  final String colorValue;
  final String? projectId;
  final String requestContext;
  final String projectName;
  final String projectLocation;
  final RateReviewApiClient? apiClient;
  final CostTableApiClient? costTableApiClient;
  final String materialTableTitle;
  final bool materialTableShowNextToBill;
  final bool materialTableShowPdfActions;

  const RateReviewScreen({
    super.key,
    required this.gaugeLabel,
    required this.gaugeValue,
    required this.colorLabel,
    required this.colorValue,
    this.projectId,
    this.requestContext = 'estimation',
    required this.projectName,
    required this.projectLocation,
    this.apiClient,
    this.costTableApiClient,
    this.materialTableTitle = 'Estimation Material Table',
    this.materialTableShowNextToBill = true,
    this.materialTableShowPdfActions = true,
  });

  @override
  State<RateReviewScreen> createState() => _RateReviewScreenState();
}

class _RateReviewScreenState extends State<RateReviewScreen> {
  late final RateReviewApiClient _apiClient;
  String? _errorMessage;
  bool _isLoading = true;
  List<_EditableRateRow> _editableRows = const <_EditableRateRow>[];

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? RateReviewApiClient();
    _loadRates();
  }

  Future<void> _loadRates() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final RateReview review = await _apiClient.fetchRateReview(
        gauge: widget.gaugeValue,
        color: widget.colorValue,
        projectId: widget.projectId,
        context: widget.requestContext,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _editableRows = review.rows
            .map(
              (RateReviewRow row) => _EditableRateRow(
                section: row.section,
                totalFt: row.totalFt,
                totalFtDisplay: row.totalFtDisplay,
                rateText: _formatDecimal(row.rate),
              ),
            )
            .toList();
        _isLoading = false;
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

  static String _formatDecimal(double value) {
    final String fixed = value.toStringAsFixed(
      value == value.truncateToDouble() ? 0 : 2,
    );
    if (!fixed.contains('.')) {
      return fixed;
    }
    return fixed
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  void _updateRate(int index, String value) {
    setState(() {
      _editableRows = List<_EditableRateRow>.from(_editableRows);
      _editableRows[index] = _editableRows[index].copyWith(rateText: value);
    });
  }

  void _handleNextPressed() {
    final List<RateOverrideInput> overrides = <RateOverrideInput>[];
    for (final _EditableRateRow row in _editableRows) {
      final double? parsed = double.tryParse(row.rateText.trim());
      if (parsed == null || parsed <= 0) {
        continue;
      }
      overrides.add(RateOverrideInput(section: row.section, rate: parsed));
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => EstimationMaterialTableScreen(
          gaugeLabel: widget.gaugeLabel,
          gaugeValue: widget.gaugeValue,
          colorLabel: widget.colorLabel,
          colorValue: widget.colorValue,
          projectId: widget.projectId,
          requestContext: widget.requestContext,
          projectName: widget.projectName,
          projectLocation: widget.projectLocation,
          overrides: overrides,
          apiClient: widget.costTableApiClient,
          screenTitle: widget.materialTableTitle,
          showNextToBill: widget.materialTableShowNextToBill,
          showPdfActions: widget.materialTableShowPdfActions,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rate Setting')),
      bottomNavigationBar: BottomActionBar(
        children: <Widget>[
          Expanded(
            child: FilledButton(
              onPressed: _isLoading ? null : _handleNextPressed,
              child: const Text('Next'),
            ),
          ),
        ],
      ),
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
          icon: Icons.price_change_outlined,
          title: 'Rate review failed',
          message: _errorMessage,
          iconColor: AppTheme.danger,
          action: FilledButton.icon(
            onPressed: _loadRates,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ),
      );
    }

    if (_editableRows.isEmpty) {
      return const Center(
        child: StateMessageCard(
          icon: Icons.inventory_2_outlined,
          title: 'No sections found',
          message: 'No sections are available for the current project.',
        ),
      );
    }

    return ListView(
      children: <Widget>[
        const AppHeroHeader(
          eyebrow: 'RATE SETTING',
          title: 'Adjust section rates before material costing',
          subtitle:
              'Review the live backend rates and make controlled edits before generating the material table.',
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
        SectionSurfaceCard(
          title: 'Section Rates',
          subtitle:
              'Each section shows the total quantity in feet and the editable rate used for costing.',
          child: Column(
            children: _editableRows
                .asMap()
                .entries
                .map((MapEntry<int, _EditableRateRow> entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.space4),
                    child: _buildRateRowCard(context, entry.key, entry.value),
                  );
                })
                .toList(growable: false),
          ),
        ),
      ],
    );
  }

  Widget _buildRateRowCard(
    BuildContext context,
    int index,
    _EditableRateRow row,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            row.section,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: AppTheme.space4),
          Row(
            children: <Widget>[
              Expanded(
                child: _ReadOnlyMetric(
                  label: 'Total Length',
                  value: row.totalFtDisplay,
                ),
              ),
              const SizedBox(width: AppTheme.space4),
              Expanded(
                child: TextFormField(
                  initialValue: row.rateText,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  onChanged: (String value) => _updateRate(index, value),
                  decoration: const InputDecoration(labelText: 'Rate'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditableRateRow {
  final String section;
  final double totalFt;
  final String totalFtDisplay;
  final String rateText;

  const _EditableRateRow({
    required this.section,
    required this.totalFt,
    required this.totalFtDisplay,
    required this.rateText,
  });

  _EditableRateRow copyWith({String? rateText}) {
    return _EditableRateRow(
      section: section,
      totalFt: totalFt,
      totalFtDisplay: totalFtDisplay,
      rateText: rateText ?? this.rateText,
    );
  }
}

class _ReadOnlyMetric extends StatelessWidget {
  final String label;
  final String value;

  const _ReadOnlyMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppTheme.space2),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
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
