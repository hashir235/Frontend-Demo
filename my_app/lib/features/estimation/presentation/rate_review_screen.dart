import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
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
  RateReview? _review;
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
        _review = review;
        _editableRows = review.rows
            .map(
              (RateReviewRow row) => _EditableRateRow(
                section: row.section,
                totalFt: row.totalFt,
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
    final String fixed = value.toStringAsFixed(value == value.truncateToDouble() ? 0 : 2);
    if (!fixed.contains('.')) {
      return fixed;
    }
    return fixed.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
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
      overrides.add(
        RateOverrideInput(
          section: row.section,
          rate: parsed,
        ),
      );
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
      appBar: AppBar(
        title: const Text('Rate Setting'),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton(
            onPressed: _isLoading ? null : _handleNextPressed,
            child: const Text('Next'),
          ),
        ),
      ),
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
            Text('Loading section rates...'),
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
                onPressed: _loadRates,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_editableRows.isEmpty) {
      return _buildShell(
        context,
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('No sections found for the current project.'),
          ),
        ),
      );
    }

    return _buildShell(
      context,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        children: <Widget>[
          _buildHeaderCard(context),
          const SizedBox(height: 16),
          ..._editableRows.asMap().entries.map(
            (MapEntry<int, _EditableRateRow> entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildRateRowCard(context, entry.key, entry.value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShell(BuildContext context, {required Widget child}) {
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

  Widget _buildHeaderCard(BuildContext context) {
    final RateReview? review = _review;
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
              _InfoPill(label: 'Gage', value: widget.gaugeLabel),
              _InfoPill(label: 'Color', value: widget.colorLabel),
              _InfoPill(
                label: 'Sections',
                value: '${review?.rows.length ?? _editableRows.length}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRateRowCard(
    BuildContext context,
    int index,
    _EditableRateRow row,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.mist.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.sky.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            row.section,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppTheme.deepTeal,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _MetricBox(
                  label: 'Total Length',
                  value: '${_formatDecimal(row.totalFt)} ft',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  key: ValueKey<String>('${row.section}-$index'),
                  initialValue: row.rateText,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Rate',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (String value) => _updateRate(index, value),
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
  final String rateText;

  const _EditableRateRow({
    required this.section,
    required this.totalFt,
    required this.rateText,
  });

  _EditableRateRow copyWith({
    String? section,
    double? totalFt,
    String? rateText,
  }) {
    return _EditableRateRow(
      section: section ?? this.section,
      totalFt: totalFt ?? this.totalFt,
      rateText: rateText ?? this.rateText,
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;
  final String value;

  const _InfoPill({
    required this.label,
    required this.value,
  });

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

class _MetricBox extends StatelessWidget {
  final String label;
  final String value;

  const _MetricBox({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.sky.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppTheme.deepTeal.withValues(alpha: 0.66),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.deepTeal,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

