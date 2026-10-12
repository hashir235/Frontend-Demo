import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../flow_nav/models/flow_step.dart';
import '../../flow_nav/presentation/flow_progress_bar.dart';
import '../../../shared/widgets/app_hero_header.dart';
import '../../../shared/widgets/app_screen_shell.dart';
import '../../../shared/widgets/next_step_action.dart';
import '../../../shared/widgets/project_meta_strip.dart';
import '../../../shared/widgets/section_surface_card.dart';
import '../models/bill_request.dart';
import '../models/cost_table.dart';
import '../models/extra_charge.dart';
import '../widgets/glass_color_picker.dart';
import '../models/window_review_item.dart';
import '../../settings/data/bill_defaults_api_client.dart';
import '../../settings/models/bill_defaults.dart';
import '../models/estimate_flow_state.dart';
import '../state/estimate_session_store.dart';
import 'actual_bill_screen.dart';
import '../../help_videos/tutorial_videos.dart';

/// The two boxes of one extra charge line.
class _ExtraChargeRow {
  _ExtraChargeRow({String description = '', String amount = ''})
    : description = TextEditingController(text: description),
      amount = TextEditingController(text: amount);

  final TextEditingController description;
  final TextEditingController amount;

  bool get isEmpty =>
      description.text.trim().isEmpty && amount.text.trim().isEmpty;

  void dispose() {
    description.dispose();
    amount.dispose();
  }
}

class BillInputsScreen extends StatefulWidget {
  final EstimateSessionStore session;
  final double aluminiumTotal;

  /// The glazing this job needs, per glass, as the engine measured it.
  ///
  /// One rate box is asked for per entry, labelled with the glass and the
  /// footage it buys. Empty for a job answered by a server that predates this,
  /// and the screen then asks for the single glass rate it always did.
  final List<GlassAreaSummary> glassAreas;

  /// What [glassAreas] are counted in: "Rn.ft" for a workshop that bills in
  /// running feet, "sq.ft" otherwise.
  final String areaUnit;
  final String gaugeLabel;
  final String gaugeValue;
  final String colorLabel;
  final String colorValue;
  final String? projectId;
  final String projectName;
  final String projectLocation;

  const BillInputsScreen({
    super.key,
    required this.session,
    required this.aluminiumTotal,
    this.glassAreas = const <GlassAreaSummary>[],
    this.areaUnit = 'sq.ft',
    required this.gaugeLabel,
    required this.gaugeValue,
    required this.colorLabel,
    required this.colorValue,
    this.projectId,
    required this.projectName,
    required this.projectLocation,
  });

  @override
  State<BillInputsScreen> createState() => _BillInputsScreenState();
}

class _BillInputsScreenState extends State<BillInputsScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _glassRateController = TextEditingController();
  final TextEditingController _laborRateController = TextEditingController();
  final TextEditingController _hardwareRateController = TextEditingController();

  /// The window kinds this job actually contains, in the order they appear on
  /// the bill, with how many of each. Read once: the windows are fixed by the
  /// time anyone reaches this screen.
  late final List<MapEntry<String, int>> _windowTypeCounts = _countWindowTypes();

  /// One hardware box per kind, but only when there is more than one kind to
  /// tell apart. A job of nothing but sliding windows keeps the single box it
  /// has always had -- splitting it into a list of one would be a worse screen
  /// for the commonest job.
  final Map<String, TextEditingController> _hardwareByType =
      <String, TextEditingController>{};

  bool get _pricesHardwarePerType => _windowTypeCounts.length > 1;

  /// The glasses this job is glazed in, with the footage of each.
  ///
  /// Only the named ones: a job entered before glass was picked per window
  /// arrives as one unnamed group, and that is the single-rate bill this
  /// screen has always asked for.
  late final List<GlassAreaSummary> _glassGroups = widget.glassAreas
      .where((GlassAreaSummary g) => !g.isUnnamed && g.areaSqFt > 0)
      .toList(growable: false);

  /// One glass box per glass, once the job actually has them. A job glazed
  /// throughout in one glass keeps the single box, the same way hardware does
  /// -- a list of one is a worse screen than the box it replaced.
  final Map<String, TextEditingController> _glassByColor =
      <String, TextEditingController>{};

  bool get _pricesGlassPerColor => _glassGroups.isNotEmpty;

  /// Every gauge the job is made in, for the header here and the bill. Read
  /// once, like the window kinds.
  late final List<String> _gauges = widget.session.gaugesUsed;

  /// How the header names them: all of them, or the one passed in for a job
  /// with no windows to read them from.
  String get _gaugeText =>
      _gauges.isEmpty ? widget.gaugeLabel : _gauges.join(', ');

  List<MapEntry<String, int>> _countWindowTypes() {
    final Map<String, int> counts = <String, int>{};
    for (final WindowReviewItem item in widget.session.items) {
      counts[item.windowLabel] = (counts[item.windowLabel] ?? 0) + 1;
    }
    return counts.entries.toList(growable: false);
  }
  final TextEditingController _glassColorController = TextEditingController();
  final TextEditingController _aluminiumCompanyController =
      TextEditingController();
  final TextEditingController _discountController = TextEditingController();

  /// Extra charges, a line each with what it is for (Hashir, Oct 2026): a
  /// customer asks what an extra figure is, and "Transport" answers it where
  /// a lump does not. Always at least one line.
  final List<_ExtraChargeRow> _extraRows = <_ExtraChargeRow>[];

  final TextEditingController _advancePaidController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  /// The rates saved in Settings, once they have arrived. Null until then,
  /// and null forever if the lookup failed -- billing still works either way.
  BillDefaults? _savedRates;
  final TextEditingController _phoneController = TextEditingController();

  static final List<TextInputFormatter> _decimalInputFormatters =
      <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
      ];
  static final List<TextInputFormatter> _phoneInputFormatters =
      <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(15),
      ];
  static final List<TextInputFormatter> _nameInputFormatters =
      <TextInputFormatter>[LengthLimitingTextInputFormatter(80)];
  static final List<TextInputFormatter> _glassColorInputFormatters =
      <TextInputFormatter>[LengthLimitingTextInputFormatter(80)];
  static final List<TextInputFormatter> _addressInputFormatters =
      <TextInputFormatter>[LengthLimitingTextInputFormatter(200)];

  @override
  void initState() {
    super.initState();
    if (_pricesHardwarePerType) {
      for (final MapEntry<String, int> entry in _windowTypeCounts) {
        _hardwareByType[entry.key] = TextEditingController();
      }
    }
    for (final GlassAreaSummary group in _glassGroups) {
      _glassByColor[group.color] = TextEditingController();
    }
    _loadSavedRates();
    final EstimateBillDraft? draft = widget.session.billDraft;
    _extraRows.addAll(_extraRowsFrom(draft));
    if (draft == null) {
      return;
    }
    _glassRateController.text = draft.glassRatePerSqFt;
    _laborRateController.text = draft.laborRatePerSqFt;
    _hardwareRateController.text = draft.hardwareRatePerWindow;
    _discountController.text = draft.aluminiumDiscountPercent;
    _advancePaidController.text = draft.advancePaid;
    _glassColorController.text = draft.glassColor;
    _aluminiumCompanyController.text = draft.aluminiumCompany;
    _customerNameController.text = draft.customerName;
    _phoneController.text = draft.customerPhone;
    _addressController.text = draft.customerAddress;
  }

  /// The extra charge lines this bill had, or one empty line to start. A bill
  /// whose extra charges were one figure, made before the lines, comes back
  /// as one line with that amount and nothing yet to say what it was for.
  static List<_ExtraChargeRow> _extraRowsFrom(EstimateBillDraft? draft) {
    final List<ExtraChargeDraft> lines = (draft?.extraChargeLines ??
            const <ExtraChargeDraft>[])
        .where((ExtraChargeDraft line) => !line.isEmpty)
        .toList(growable: false);
    if (lines.isNotEmpty) {
      return <_ExtraChargeRow>[
        for (final ExtraChargeDraft line in lines)
          _ExtraChargeRow(description: line.description, amount: line.amount),
      ];
    }
    final String total = draft?.extraCharges.trim() ?? '';
    if ((double.tryParse(total) ?? 0) > 0) {
      return <_ExtraChargeRow>[_ExtraChargeRow(amount: total)];
    }
    return <_ExtraChargeRow>[_ExtraChargeRow()];
  }

  void _addExtraRow() {
    if (_extraRows.length >= ExtraCharge.maxLines) return;
    setState(() => _extraRows.add(_ExtraChargeRow()));
  }

  void _removeExtraRow(_ExtraChargeRow row) {
    setState(() => _extraRows.remove(row));
    // Its boxes are still on screen until this frame is drawn without them.
    WidgetsBinding.instance.addPostFrameCallback((_) => row.dispose());
  }

  /// The lines that are charges: those with an amount.
  List<ExtraCharge> get _extraCharges => <ExtraCharge>[
    for (final _ExtraChargeRow row in _extraRows)
      if ((double.tryParse(row.amount.text.trim()) ?? 0) > 0)
        ExtraCharge(
          description: row.description.text.trim(),
          amount: double.parse(row.amount.text.trim()),
        ),
  ];

  /// A line's amount. Optional, but a line that says what it is for needs
  /// one -- otherwise it would quietly never reach the bill.
  String? _extraAmountValidator(_ExtraChargeRow row, String? value) {
    final String? base = _optionalNumberValidator(value);
    if (base != null) return base;
    final double amount = double.tryParse((value ?? '').trim()) ?? 0;
    if (row.description.text.trim().isNotEmpty && amount <= 0) {
      return 'Enter the amount';
    }
    return null;
  }

  /// Fills in the rates the user saved in Settings, so they are not retyped on
  /// every bill.
  ///
  /// Only ever fills an *empty* box. Anything already on this bill — whether
  /// typed a moment ago or restored from the draft — is left exactly as it is:
  /// a saved default must never overwrite a number someone chose for this job.
  Future<void> _loadSavedRates() async {
    late final BillDefaults defaults;
    try {
      defaults = await BillDefaultsApiClient().fetch();
    } catch (_) {
      return; // Billing must still work when the lookup does not.
    }
    if (!mounted || defaults.isEmpty) return;

    void fill(TextEditingController c, String value) {
      if (c.text.trim().isEmpty && value.trim().isNotEmpty) c.text = value;
    }

    setState(() {
      _savedRates = defaults;
      fill(_laborRateController, defaults.labourRate);
      fill(_hardwareRateController, defaults.hardwareRate);
      // Each kind gets the rate saved against it; anything the user never
      // priced by kind falls back to the one hardware rate, so the boxes are
      // never all blank just because the per-type list is new.
      for (final MapEntry<String, TextEditingController> e
          in _hardwareByType.entries) {
        fill(
          e.value,
          defaults.rateForWindowType(e.key) ?? defaults.hardwareRate,
        );
      }
      fill(_discountController, defaults.aluminiumDiscount);
      // Each glass gets the rate saved against it in Settings. That list is
      // keyed by the same names the windows carry, so a shop that priced
      // "Green Mercury" once never types it again.
      for (final GlassAreaSummary group in _glassGroups) {
        final String? saved = defaults.rateForGlass(group.color);
        if (saved != null) fill(_glassByColor[group.color]!, saved);
      }
      final String? glassRate = defaults.rateForGlass(
        _glassColorController.text,
      );
      if (glassRate != null) fill(_glassRateController, glassRate);
    });
  }

  /// Typing a glass colour that has a saved rate fills the rate in.
  ///
  /// Again only into an empty box: someone quoting an odd job at a special
  /// price must not have it overwritten because the colour happens to match.
  void _onGlassColorChanged(String value) {
    final String? rate = _savedRates?.rateForGlass(value);
    if (rate == null) return;
    if (_glassRateController.text.trim().isNotEmpty) return;
    setState(() => _glassRateController.text = rate);
  }

  @override
  void dispose() {
    _glassRateController.dispose();
    _laborRateController.dispose();
    _hardwareRateController.dispose();
    for (final TextEditingController c in _hardwareByType.values) {
      c.dispose();
    }
    for (final TextEditingController c in _glassByColor.values) {
      c.dispose();
    }
    _glassColorController.dispose();
    _aluminiumCompanyController.dispose();
    _discountController.dispose();
    for (final _ExtraChargeRow row in _extraRows) {
      row.dispose();
    }
    _advancePaidController.dispose();
    _customerNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String? _requiredNumberValidator(String? value) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) {
      return 'Required';
    }
    final double? number = double.tryParse(text);
    if (number == null) {
      return 'Enter a valid number';
    }
    if (number < 0) {
      return 'Must be 0 or more';
    }
    return null;
  }

  String? _discountValidator(String? value) {
    final String? base = _requiredNumberValidator(value);
    if (base != null) {
      return base;
    }
    final double discount = double.parse(value!.trim());
    if (discount > 100) {
      return 'Must be 100 or less';
    }
    return null;
  }

  String? _optionalNumberValidator(String? value) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) {
      return null;
    }
    final double? number = double.tryParse(text);
    if (number == null) {
      return 'Enter a valid number';
    }
    if (number < 0) {
      return 'Must be 0 or more';
    }
    return null;
  }

  String? _phoneValidator(String? value) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) {
      return null;
    }
    if (text.length < 7) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  String _formatAmount(double value) {
    final String fixed = value.toStringAsFixed(2);
    if (fixed.endsWith('.00')) {
      return fixed.substring(0, fixed.length - 3);
    }
    if (fixed.endsWith('0')) {
      return fixed.substring(0, fixed.length - 1);
    }
    return fixed;
  }

  double _parseRequiredNumber(TextEditingController controller) {
    return double.parse(controller.text.trim());
  }

  double _parseOptionalNumber(TextEditingController controller) {
    final String text = controller.text.trim();
    if (text.isEmpty) {
      return 0;
    }
    return double.tryParse(text) ?? 0;
  }

  void _handleNextPressed() {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final List<ExtraCharge> extraCharges = _extraCharges;
    final double extraTotal = ExtraCharge.totalOf(extraCharges);
    final EstimateBillDraft draft = EstimateBillDraft(
      glassRatePerSqFt: _glassRateController.text.trim(),
      laborRatePerSqFt: _laborRateController.text.trim(),
      hardwareRatePerWindow: _hardwareRateController.text.trim(),
      aluminiumDiscountPercent: _discountController.text.trim(),
      extraCharges: extraCharges.isEmpty ? '' : _formatAmount(extraTotal),
      extraChargeLines: <ExtraChargeDraft>[
        for (final _ExtraChargeRow row in _extraRows)
          if (!row.isEmpty)
            ExtraChargeDraft(
              description: row.description.text.trim(),
              amount: row.amount.text.trim(),
            ),
      ],
      advancePaid: _advancePaidController.text.trim(),
      glassColor: _glassColorController.text.trim(),
      aluminiumCompany: _aluminiumCompanyController.text.trim(),
      customerName: _customerNameController.text.trim(),
      customerPhone: _phoneController.text.trim(),
      customerAddress: _addressController.text.trim(),
    );
    widget.session.setBillDraft(draft);
    final BillRequest request = BillRequest(
      projectId: widget.projectId,
      // With several glasses on the job the single rate is no longer the whole
      // answer, so it carries the first glass's: it is what the engine falls
      // back to, and a window whose glass somehow reached the bill without a
      // box of its own is then priced at a real rate rather than at nothing.
      glassRatePerSqFt: _pricesGlassPerColor
          ? _parseRequiredNumber(_glassByColor[_glassGroups.first.color]!)
          : _parseRequiredNumber(_glassRateController),
      glassRateByColor: <String, double>{
        for (final MapEntry<String, TextEditingController> e
            in _glassByColor.entries)
          e.key: _parseRequiredNumber(e.value),
      },
      laborRatePerSqFt: _parseRequiredNumber(_laborRateController),
      // With several kinds on the job the single rate is no longer the whole
      // answer, so it carries the first kind's rate: it is what the engine
      // falls back to, and a window kind that somehow reached the bill without
      // a box of its own is then priced at a real rate rather than at nothing.
      hardwareRatePerWindow: _pricesHardwarePerType
          ? _parseRequiredNumber(_hardwareByType[_windowTypeCounts.first.key]!)
          : _parseRequiredNumber(_hardwareRateController),
      hardwareRateByType: <String, double>{
        for (final MapEntry<String, TextEditingController> e
            in _hardwareByType.entries)
          e.key: _parseRequiredNumber(e.value),
      },
      aluminiumDiscountPercent: _parseRequiredNumber(_discountController),
      aluminiumTotal: widget.aluminiumTotal,
      extraCharges: extraTotal,
      extraChargeItems: extraCharges,
      advancePaid: _parseOptionalNumber(_advancePaidController),
      gauge: widget.gaugeValue,
      gauges: _gauges,
      aluminiumColor: widget.colorValue,
      // The bill's heading still names the glass. With several on one job the
      // heading names them all rather than picking one to stand for the rest;
      // the per-glass rows underneath carry the detail.
      glassColor: _pricesGlassPerColor
          ? _glassGroups.map((GlassAreaSummary g) => g.color).join(', ')
          : _glassColorController.text.trim(),
      aluminiumCompany: _aluminiumCompanyController.text.trim(),
      projectName: widget.projectName,
      projectLocation: widget.projectLocation,
      customerName: _customerNameController.text.trim(),
      customerPhone: _phoneController.text.trim(),
      customerAddress: _addressController.text.trim(),
    );

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: FlowSteps.invoice.id),
        builder: (BuildContext context) =>
            ActualBillScreen(session: widget.session, request: request),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill Inputs'),
        actions: <Widget>[
          NextStepAction(onPressed: _handleNextPressed),
        ],
      ),
      bottomNavigationBar: FlowProgressBar(stepId: FlowSteps.billInputs.id),
      body: AppScreenShell(
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              const AppHeroHeader(
                eyebrow: 'BILLING',
                title: 'Enter billing inputs',
                videoKey: TutorialVideos.estimationBillInputs,
                subtitle:
                    'Keep the rate inputs tight, optional details controlled, and move directly into the final bill.',
              ),
              const SizedBox(height: AppTheme.space5),
              ProjectMetaStrip(
                projectName: widget.projectName,
                projectLocation: widget.projectLocation,
                extras: <Widget>[
                  _InfoChip(label: 'Gage', value: _gaugeText),
                  _InfoChip(label: 'Colour', value: widget.colorLabel),
                  _InfoChip(
                    label: 'Aluminium',
                    value: _formatAmount(widget.aluminiumTotal),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space6),
              SectionSurfaceCard(
                title: 'Mandatory Fields',
                subtitle:
                    'These values drive the actual bill calculation and are required.',
                child: Column(
                  children: <Widget>[
                    if (!_pricesGlassPerColor)
                      _buildNumberField(
                        controller: _glassRateController,
                        label: 'Glass Rate *',
                        validator: _requiredNumberValidator,
                      )
                    else
                      // One box per glass, each saying which glass and how
                      // many feet that rate buys. The footage is in the
                      // label because the rate is per foot: seeing "124.5 sq
                      // ft" beside the box is what stops someone entering
                      // the total for the lot.
                      for (final GlassAreaSummary group in _glassGroups)
                        _buildGlassRateField(group),
                    _buildNumberField(
                      controller: _laborRateController,
                      label: 'Labor Rate *',
                      validator: _requiredNumberValidator,
                    ),
                    if (!_pricesHardwarePerType)
                      _buildNumberField(
                        controller: _hardwareRateController,
                        label: 'Hardware Rate *',
                        validator: _requiredNumberValidator,
                      )
                    else ...<Widget>[
                      // The count is in the label because the rate is per
                      // window, not per line: seeing "x 7" next to the box
                      // is what stops someone entering the total for all
                      // seven.
                      for (final MapEntry<String, int> entry
                          in _windowTypeCounts)
                        _buildNumberField(
                          controller: _hardwareByType[entry.key]!,
                          label:
                              'Hardware Rate — ${entry.key}  × ${entry.value} *',
                          validator: _requiredNumberValidator,
                        ),
                    ],
                    _buildNumberField(
                      controller: _discountController,
                      label: 'Aluminium Discount % *',
                      validator: _discountValidator,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.space5),
              SectionSurfaceCard(
                title: 'Optional Details',
                subtitle:
                    'Add customer and adjustment details only where they are needed.',
                child: Column(
                  children: <Widget>[
                    _buildExtraCharges(context),
                    _buildNumberField(
                      controller: _advancePaidController,
                      label: 'Advance Paid',
                      validator: _optionalNumberValidator,
                    ),
                    // Only when the windows did not say. Glass is picked per
                    // window now, so typing it again here could only
                    // contradict what was actually chosen.
                    if (!_pricesGlassPerColor)
                      _buildTextField(
                        onChanged: _onGlassColorChanged,
                        controller: _glassColorController,
                        label: 'Glass Color',
                        inputFormatters: _glassColorInputFormatters,
                      ),
                    _buildTextField(
                      controller: _aluminiumCompanyController,
                      label: 'Aluminium Company',
                      inputFormatters: _nameInputFormatters,
                    ),
                    _buildTextField(
                      controller: _customerNameController,
                      label: 'Customer Name',
                      inputFormatters: _nameInputFormatters,
                    ),
                    _buildTextField(
                      controller: _addressController,
                      label: 'Address',
                      maxLines: 2,
                      inputFormatters: _addressInputFormatters,
                    ),
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      keyboardType: TextInputType.phone,
                      inputFormatters: _phoneInputFormatters,
                      validator: _phoneValidator,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The rate box for one glass, with a swatch of that glass beside it.
  ///
  /// The swatch is the same one the fitter picked on the input screen. A shop
  /// that chose by sight should be able to check by sight that the rate is
  /// going against the right glass, rather than matching two names.
  Widget _buildGlassRateField(GlassAreaSummary group) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space4),
      child: TextFormField(
        controller: _glassByColor[group.color]!,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: _decimalInputFormatters,
        validator: _requiredNumberValidator,
        decoration: InputDecoration(
          labelText:
              'Glass Rate — ${group.color}  ·  '
              '${_formatArea(group.areaSqFt)} ${widget.areaUnit} *',
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space4,
              vertical: 12,
            ),
            child: GlassSwatch(color: group.color, size: 20),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0),
        ),
      ),
    );
  }

  /// Extra charges, a line each: what it is for, and how much. The bill and
  /// its PDF print every line under its own name; the total is what they
  /// come to.
  Widget _buildExtraCharges(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final List<ExtraCharge> charges = _extraCharges;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Extra Charges',
            style: text.titleSmall?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppTheme.space2),
          Text(
            'Say what each one is for: transport, silicon, extra glass or '
            'section. Every line prints on the bill.',
            style: text.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: AppTheme.space4),
          for (final _ExtraChargeRow row in _extraRows)
            _buildExtraChargeRow(row),
          Row(
            children: <Widget>[
              TextButton.icon(
                key: const Key('bill_add_extra_charge'),
                onPressed: _extraRows.length < ExtraCharge.maxLines
                    ? _addExtraRow
                    : null,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add extra charge'),
              ),
              if (charges.length > 1)
                Expanded(
                  child: Text(
                    'Total: ${_formatAmount(ExtraCharge.totalOf(charges))}',
                    key: const Key('bill_extra_charges_total'),
                    textAlign: TextAlign.right,
                    style: text.bodyMedium?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// One line: what it is for across the full width, where a few words fit
  /// on a small phone, and the amount under it.
  Widget _buildExtraChargeRow(_ExtraChargeRow row) {
    return Padding(
      key: ObjectKey(row),
      padding: const EdgeInsets.only(bottom: AppTheme.space5),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              children: <Widget>[
                TextFormField(
                  controller: row.description,
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: <TextInputFormatter>[
                    LengthLimitingTextInputFormatter(
                      ExtraCharge.maxDescriptionLength,
                    ),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'What is it for?',
                    hintText: 'e.g. Transport',
                  ),
                ),
                const SizedBox(height: AppTheme.space3),
                TextFormField(
                  controller: row.amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: _decimalInputFormatters,
                  validator: (String? value) =>
                      _extraAmountValidator(row, value),
                  // The total under the lines follows as amounts are typed.
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Amount'),
                ),
              ],
            ),
          ),
          if (_extraRows.length > 1)
            IconButton(
              tooltip: 'Remove',
              onPressed: () => _removeExtraRow(row),
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
    );
  }

  /// Footage to one decimal: a tenth of a foot is the finest anyone quotes,
  /// and a long tail of decimals beside a rate box reads as a bug.
  static String _formatArea(double value) => value.toStringAsFixed(1);

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space4),
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: _decimalInputFormatters,
        validator: validator,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space4),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: validator,
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({required this.label, required this.value});

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
