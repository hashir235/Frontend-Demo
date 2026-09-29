import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/format/cut_length.dart';
import '../../../shared/format/suter_half.dart';
import '../../settings/state/app_settings.dart';
import '../../tutorial/tutorial_controller.dart';
import '../../tutorial/tutorial_overlay.dart';
import '../../tutorial/tutorial_step.dart';
import '../../tutorial/tutorial_target.dart';
import '../data/optimization_repository.dart';
import '../models/cutting_report.dart';
import '../models/section_recalculation.dart';
import 'input/feet_inch_suter_notation.dart';
import 'input/size_entry_notation.dart';

/// Aluminium stock comes in bars, not in arbitrary lengths. Anything outside
/// this range is almost certainly a unit mix-up -- someone typing inches or
/// centimetres into a field that counts feet.
const int kMinStockLengthFt = 4;
const int kMaxStockLengthFt = 30;

/// The unit an extra length is typed in. The buttons over the box say which,
/// so nobody has to guess what the number means.
enum ExtraLengthUnit {
  /// Centimetres, one digit after the point: `320.5`.
  cm,

  /// Inch and suter, as the size boxes type them: `127'' 4½'''`.
  inch,

  /// Feet, inch and suter: `10' 7'' 4½'''`.
  feet,
}

/// [text] as typed in [unit], in feet; null when it is not a length.
double? extraLengthInFeet(String text, ExtraLengthUnit unit) {
  switch (unit) {
    case ExtraLengthUnit.cm:
      final double? cm = double.tryParse(text.trim());
      return cm == null ? null : cm / 30.48;
    case ExtraLengthUnit.inch:
      final SizeEntry entry = SizeNotation.readEntry(text);
      final int? inches = int.tryParse(entry.whole);
      if (inches == null) return null;
      final double suter = (int.tryParse(entry.sub) ?? 0) + (entry.half ? 0.5 : 0);
      return (inches + suter / 8) / 12;
    case ExtraLengthUnit.feet:
      return FeetInchSuterEntry.read(text).inFeet;
  }
}

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

  /// The unit last picked, on this phone, for any section; feet the first
  /// time, as the stock lengths above are all in feet.
  ExtraLengthUnit _extraUnit = ExtraLengthUnit.values.firstWhere(
    (ExtraLengthUnit unit) => unit.name == AppSettings.instance.extraLengthUnit,
    orElse: () => ExtraLengthUnit.feet,
  );

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

  /// The bar lengths to ask a quantity for, longest first -- 18, 16, 14 --
  /// the way the stock is counted off the rack. (The server sorts them
  /// itself, so the order here is only for reading.)
  List<double> _resolveBaseLengths() {
    final Set<double> unique = <double>{...widget.section.allowedLengthsFt};
    if (unique.isEmpty) {
      final CuttingReportSummary? summary = widget.section.summary;
      if (summary != null) {
        unique.addAll(summary.usedLengths);
      }
    }
    return unique.toList()..sort((double a, double b) => b.compareTo(a));
  }

  /// A bar's length: whole feet as `16 ft`, anything else -- an extra length
  /// typed as `10' 7'' 4'''` or in cm -- the way the tape reads it, rather
  /// than as a decimal nobody typed.
  String _stockDisplayInFeet(double stockLenFt) {
    if ((stockLenFt - stockLenFt.roundToDouble()).abs() > 1e-6) {
      return CutLength.fromFeet(stockLenFt).inFeetInchSuter;
    }
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
    // The same pile, not just the same profile: a job can hold M23 in two
    // gauges. A server that predates this sends no stock back, and then the
    // name is all there is to go on.
    for (final CuttingReportSection section in report.sections) {
      if (section.key == widget.section.key) {
        return section;
      }
    }
    for (final CuttingReportSection section in report.sections) {
      if (section.name == widget.section.name) {
        return section;
      }
    }
    return report.sections.first;
  }

  void _handlePop() {
    Navigator.of(context).pop(_result);
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
          lengthFt: extraLengthInFeet(extraLengthText, _extraUnit)!,
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
          sectionGauge: widget.section.gauge,
          sectionColor: widget.section.color,
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

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          _handlePop();
        }
      },
      // Wraps the Scaffold: the Optimize button the tour makes the user press
      // lives in the bottom bar, outside the body.
      child: TutorialOverlay(
        screen: TutorialScreen.sectionRecalculation,
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
              child: TutorialTarget(
                id: 'recalc.optimize',
                child: FilledButton.icon(
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          TutorialController.instance.advanceAfterTap();
                          _handleOptimizePressed();
                        },
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(
                    _isSubmitting ? 'Optimizing...' : 'Optimize Section',
                  ),
                ),
              ),
            ),
          ),
          body: Container(
            decoration: BoxDecoration(
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
                    TutorialTarget(
                      id: 'recalc.header',
                      child: _buildHeaderCard(context),
                    ),
                    const SizedBox(height: 12),
                    ..._buildLengthCards(),
                    const SizedBox(height: 12),
                    TutorialTarget(
                      id: 'recalc.extra',
                      child: _buildExtraLengthCard(),
                    ),
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
                      TutorialTarget(
                        id: 'recalc.result',
                        child: _buildSummaryCard(context, resultSection),
                      ),
                      const SizedBox(height: 12),
                      ...resultSection.barBlocksLongestFirst.map(
                        (CuttingReportBarBlock block) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildGroupCard(
                            context,
                            block.bar,
                            twin: block.twin,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
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
      // The tour works through the first row; ids point at one widget, so
      // only that row registers them.
      final bool isTourExample = index == 0;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _maybeTourTarget(
          id: 'recalc.lengthRow',
          enabled: isTourExample,
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
                  child: _maybeTourTarget(
                    id: 'recalc.quantity',
                    enabled: isTourExample,
                    child: _buildQuantityField(
                      controller: _quantityControllers[index],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }, growable: false);
  }

  /// Wraps [child] in a tour target only on the row the tour walks through.
  Widget _maybeTourTarget({
    required String id,
    required bool enabled,
    required Widget child,
  }) {
    if (!enabled) return child;
    return TutorialTarget(id: id, child: child);
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  'Length in',
                  style: TextStyle(
                    color: AppTheme.deepTeal,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              _buildExtraUnitButtons(),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: TextFormField(
                  key: const Key('extra_length_field'),
                  controller: _extraLengthController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: <TextInputFormatter>[
                    switch (_extraUnit) {
                      ExtraLengthUnit.cm => const TypedSizeFormatter(
                        TypedSizeUnit.cm,
                      ),
                      ExtraLengthUnit.inch => const MergedSizeFormatter(),
                      ExtraLengthUnit.feet => const FeetInchSuterFormatter(),
                    },
                  ],
                  decoration: InputDecoration(
                    labelText: 'Extra Length',
                    hintText: switch (_extraUnit) {
                      ExtraLengthUnit.cm => 'e.g. 320.5',
                      ExtraLengthUnit.inch => "e.g. 127'' 4'''",
                      ExtraLengthUnit.feet => "e.g. 10' 7'' 4'''",
                    },
                    suffixText: _extraUnit == ExtraLengthUnit.cm ? 'cm' : null,
                    errorMaxLines: 2,
                  ),
                  validator: _validateExtraLength,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 120,
                child: _buildQuantityField(controller: _extraQuantityController),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// cm, inch, feet: the unit the extra length is typed in. Changing it
  /// empties the box -- a number typed as feet means nothing in cm.
  Widget _buildExtraUnitButtons() {
    return SegmentedButton<ExtraLengthUnit>(
      key: const Key('extra_length_unit'),
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        selectedBackgroundColor: AppTheme.deepTeal,
        selectedForegroundColor: Colors.white,
        foregroundColor: AppTheme.deepTeal,
        // The theme's own label font, only heavier: a bare TextStyle here
        // would drop the app's font for the platform's.
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
      segments: const <ButtonSegment<ExtraLengthUnit>>[
        ButtonSegment<ExtraLengthUnit>(
          value: ExtraLengthUnit.cm,
          label: Text('cm', key: Key('extra_unit_cm')),
        ),
        ButtonSegment<ExtraLengthUnit>(
          value: ExtraLengthUnit.inch,
          label: Text('inch', key: Key('extra_unit_inch')),
        ),
        ButtonSegment<ExtraLengthUnit>(
          value: ExtraLengthUnit.feet,
          label: Text('feet', key: Key('extra_unit_feet')),
        ),
      ],
      selected: <ExtraLengthUnit>{_extraUnit},
      onSelectionChanged: (Set<ExtraLengthUnit> picked) {
        if (picked.first == _extraUnit) return;
        setState(() {
          _extraUnit = picked.first;
          _extraLengthController.clear();
        });
        AppSettings.instance.setExtraLengthUnit(picked.first.name);
      },
    );
  }

  String? _validateExtraLength(String? value) {
    final String lengthText = value?.trim() ?? '';
    final String quantityText = _extraQuantityController.text.trim();
    if (lengthText.isEmpty) {
      if (quantityText.isNotEmpty) {
        return 'Add a length first';
      }
      return null;
    }
    final double? feet = extraLengthInFeet(lengthText, _extraUnit);
    if (feet == null || feet <= 0) {
      return 'Enter a valid length';
    }
    // A user once typed 238 here, reading the box as inches. The unit
    // buttons now say what the box counts, and a length no bar comes in is
    // still stopped here rather than failing in the optimizer.
    const double tolerance = 1e-9;
    if (feet < kMinStockLengthFt - tolerance ||
        feet > kMaxStockLengthFt + tolerance) {
      // Said in the unit being typed: 4 to 30 ft is 122 to 914 cm, and
      // 48 to 360 inches.
      return switch (_extraUnit) {
        ExtraLengthUnit.cm => 'Use 122 to 914 cm',
        ExtraLengthUnit.inch => "Use 48'' to 360''",
        ExtraLengthUnit.feet =>
          "Use $kMinStockLengthFt' to $kMaxStockLengthFt'",
      };
    }
    return null;
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
        : summary.usedLengthsLongestFirst.map(_stockDisplayInFeet).join(', ');
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

  /// One bar, or with pair cutting a bar and its [twin] as one card: two
  /// lengths with the same cuts, cut together.
  Widget _buildGroupCard(
    BuildContext context,
    CuttingReportGroup group, {
    CuttingReportGroup? twin,
  }) {
    String both(String first, String? second) =>
        second == null || second.isEmpty || second == first
        ? first
        : '$first / $second';
    CuttingReportCut? twinCutAt(int position) =>
        twin == null || position >= twin.cuts.length
        ? null
        : twin.cuts[position];
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
            twin == null
                ? 'Lengths: ${_stockDisplayInFeet(group.stockLenFt)}'
                : 'Lengths: ${_stockDisplayInFeet(group.stockLenFt)}  x 2 — cut together',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: twin == null ? AppTheme.deepTeal : AppTheme.violet,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Wastage: ${SuterHalf.inText(group.wastageDisplay)}',
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
                DataColumn(label: Text('Window No')),
                DataColumn(label: Text('Dimention')),
                DataColumn(label: Text('Cuts')),
              ],
              rows: group.cuts
                  .asMap()
                  .entries
                  .map((MapEntry<int, CuttingReportCut> entry) {
                    final CuttingReportCut cut = entry.value;
                    final CuttingReportCut? other = twinCutAt(entry.key);
                    return DataRow(
                      cells: <DataCell>[
                        DataCell(Text(both(cut.dimension, other?.dimension))),
                        DataCell(Text(both(cut.windowName, other?.windowName))),
                        DataCell(
                          Text(
                            both(
                              cut.windowNo.toString(),
                              other?.windowNo.toString(),
                            ),
                          ),
                        ),
                        DataCell(Text(_pieceSymbolForCut(cut))),
                        DataCell(
                          Text(
                            twin == null
                                ? SuterHalf.inText(cut.lengthDisplay)
                                : '${SuterHalf.inText(cut.lengthDisplay)}  x 2',
                          ),
                        ),
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
