import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../data/optimization_repository.dart';
import '../models/cutting_report.dart';
import '../models/section_recalculation.dart';

class SectionRecalculationScreen extends StatefulWidget {
  final CuttingReportSection section;
  final String? projectId;
  final String requestContext;
  final String displayUnit;
  final OptimizationRepository? repository;

  const SectionRecalculationScreen({
    super.key,
    required this.section,
    this.projectId,
    required this.requestContext,
    required this.displayUnit,
    this.repository,
  });

  @override
  State<SectionRecalculationScreen> createState() =>
      _SectionRecalculationScreenState();
}

class _SectionRecalculationScreenState
    extends State<SectionRecalculationScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final OptimizationRepository _repository;
  late final List<double> _baseLengths;
  late final List<TextEditingController> _quantityControllers;
  final TextEditingController _extraLengthController = TextEditingController();
  final TextEditingController _extraQuantityController =
      TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;
  CuttingReport? _result;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? OptimizationRepository();
    _baseLengths = _resolveBaseLengths();
    _quantityControllers = List<TextEditingController>.generate(
      _baseLengths.length,
      (_) => TextEditingController(),
      growable: false,
    );
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _quantityControllers) {
      controller.dispose();
    }
    _extraLengthController.dispose();
    _extraQuantityController.dispose();
    super.dispose();
  }

  List<double> _resolveBaseLengths() {
    if (widget.section.allowedLengthsFt.isNotEmpty) {
      return widget.section.allowedLengthsFt;
    }
    final Set<double> unique = <double>{};
    final CuttingReportSummary? summary = widget.section.summary;
    if (summary != null) {
      unique.addAll(summary.usedLengths);
    }
    final List<double> fallback = unique.toList()..sort();
    return fallback;
  }

  String _stockDisplayInFeet(double stockLenFt) {
    final String fixed = stockLenFt.toStringAsFixed(2);
    final String compact = fixed
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return '$compact ft';
  }

  String _pieceSymbolForCut(CuttingReportCut cut) {
    final int pipeIndex = cut.label.lastIndexOf('|');
    if (pipeIndex == -1 || pipeIndex + 1 >= cut.label.length) {
      return '--';
    }
    final String symbol = cut.label.substring(pipeIndex + 1).trim();
    return symbol.isEmpty ? '--' : symbol;
  }

  CuttingReportSection? get _resultSection {
    final CuttingReport? report = _result;
    if (report == null || report.sections.isEmpty) {
      return null;
    }
    for (final CuttingReportSection section in report.sections) {
      if (section.name == widget.section.name) {
        return section;
      }
    }
    return report.sections.first;
  }

  Future<bool> _handleWillPop() async {
    Navigator.of(context).pop(_result);
    return false;
  }

  List<CuttingReportCut> _flattenSourceCuts() {
    return widget.section.groups
        .expand((CuttingReportGroup group) => group.cuts)
        .toList(growable: false);
  }

  Future<void> _handleOptimizePressed() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final List<SectionStockAvailability> stockOptions =
        <SectionStockAvailability>[];
    for (int index = 0; index < _baseLengths.length; index += 1) {
      final String rawQuantity = _quantityControllers[index].text.trim();
      stockOptions.add(
        SectionStockAvailability(
          lengthFt: _baseLengths[index],
          quantity: rawQuantity.isEmpty ? null : int.parse(rawQuantity),
        ),
      );
    }

    final String extraLengthText = _extraLengthController.text.trim();
    final String extraQuantityText = _extraQuantityController.text.trim();
    if (extraLengthText.isNotEmpty) {
      stockOptions.add(
        SectionStockAvailability(
          lengthFt: double.parse(extraLengthText),
          quantity: extraQuantityText.isEmpty
              ? null
              : int.parse(extraQuantityText),
        ),
      );
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final CuttingReport report = await _repository.recalculateSection(
        SectionRecalculationRequest(
          projectId: widget.projectId,
          context: widget.requestContext,
          displayUnit: widget.displayUnit,
          sectionName: widget.section.name,
          sourceCuts: _flattenSourceCuts(),
          stockOptions: stockOptions,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _result = report;
        _isSubmitting = false;
      });
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _errorMessage = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final CuttingReportSection? resultSection = _resultSection;

    return WillPopScope(
      onWillPop: _handleWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Re Calculation'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(_result),
          ),
        ),
        bottomNavigationBar: SafeArea(
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
            child: FilledButton.icon(
              onPressed: _isSubmitting ? null : _handleOptimizePressed,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : const Icon(Icons.refresh_rounded),
              label: Text(_isSubmitting ? 'Optimizing...' : 'Optimize Section'),
            ),
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[AppTheme.mist, AppTheme.ice],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                children: <Widget>[
                  _buildHeaderCard(context),
                  const SizedBox(height: 12),
                  ..._buildLengthCards(),
                  const SizedBox(height: 12),
                  _buildExtraLengthCard(),
                  if (_errorMessage != null) ...<Widget>[
                    const SizedBox(height: 12),
                    _buildErrorBanner(context, _errorMessage!),
                  ],
                  if (resultSection != null) ...<Widget>[
                    const SizedBox(height: 18),
                    Text(
                      'Updated Result',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.deepTeal,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSummaryCard(context, resultSection),
                    const SizedBox(height: 12),
                    ...resultSection.groups.map(
                      (CuttingReportGroup group) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildGroupCard(context, group),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.sky.withValues(alpha: 0.8)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppTheme.deepTeal.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            widget.section.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppTheme.deepTeal,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Leave Quantity blank for infinite stock. Enter 0 if a length is finished. Use whole numbers only.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.deepTeal.withValues(alpha: 0.86),
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildLengthCards() {
    return List<Widget>.generate(_baseLengths.length, (int index) {
      final double lengthFt = _baseLengths[index];
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.sky.withValues(alpha: 0.82)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: _buildStaticLengthBox(
                  label: 'Allowed Length',
                  value: _stockDisplayInFeet(lengthFt),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 120,
                child: _buildQuantityField(
                  controller: _quantityControllers[index],
                ),
              ),
            ],
          ),
        ),
      );
    }, growable: false);
  }

  Widget _buildStaticLengthBox({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.mist,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.sky.withValues(alpha: 0.88)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.deepTeal,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.deepTeal,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityField({required TextEditingController controller}) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(4),
      ],
      decoration: InputDecoration(
        labelText: 'Quantity',
        hintText: '?',
        hintStyle: TextStyle(
          color: AppTheme.deepTeal.withValues(alpha: 0.28),
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildExtraLengthCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.sky.withValues(alpha: 0.82)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: TextFormField(
              controller: _extraLengthController,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              decoration: const InputDecoration(
                labelText: 'Extra Length',
                hintText: 'Optional',
                suffixText: 'ft',
              ),
              validator: (String? value) {
                final String lengthText = value?.trim() ?? '';
                final String quantityText = _extraQuantityController.text
                    .trim();
                if (lengthText.isEmpty) {
                  if (quantityText.isNotEmpty) {
                    return 'Add a length first';
                  }
                  return null;
                }
                final int? parsed = int.tryParse(lengthText);
                if (parsed == null || parsed <= 0) {
                  return 'Enter a valid ft length';
                }
                return null;
              },
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: _buildQuantityField(controller: _extraQuantityController),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Colors.red.shade800,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, CuttingReportSection section) {
    final CuttingReportSummary? summary = section.summary;
    final String usedLengths = summary == null || summary.usedLengths.isEmpty
        ? '--'
        : summary.usedLengths.map(_stockDisplayInFeet).join(', ');
    final double totalLength = summary?.totalLength ?? 0;

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
            'Total Length: ${_stockDisplayInFeet(totalLength)}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.deepTeal,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(BuildContext context, CuttingReportGroup group) {
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
              columns: const <DataColumn>[
                DataColumn(label: Text('WinSize')),
                DataColumn(label: Text('Window')),
                DataColumn(label: Text('No.')),
                DataColumn(label: Text('Dimention')),
                DataColumn(label: Text('Cuts')),
              ],
              rows: group.cuts
                  .map((CuttingReportCut cut) {
                    return DataRow(
                      cells: <DataCell>[
                        DataCell(Text(cut.dimension)),
                        DataCell(Text(cut.windowName)),
                        DataCell(Text(cut.windowNo.toString())),
                        DataCell(Text(_pieceSymbolForCut(cut))),
                        DataCell(Text(cut.lengthDisplay)),
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
}
