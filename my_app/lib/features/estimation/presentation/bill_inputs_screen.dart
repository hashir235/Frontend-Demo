import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../flow_nav/models/flow_step.dart';
import '../../flow_nav/presentation/flow_progress_bar.dart';
import '../../tutorial/tutorial_controller.dart';
import '../../tutorial/tutorial_overlay.dart';
import '../../tutorial/tutorial_step.dart';
import '../../tutorial/tutorial_target.dart';
import '../../../shared/widgets/app_hero_header.dart';
import '../../../shared/widgets/app_screen_shell.dart';
import '../../../shared/widgets/next_step_action.dart';
import '../../../shared/widgets/project_meta_strip.dart';
import '../../../shared/widgets/section_surface_card.dart';
import '../models/bill_request.dart';
import '../../settings/data/bill_defaults_api_client.dart';
import '../../settings/models/bill_defaults.dart';
import '../models/estimate_flow_state.dart';
import '../state/estimate_session_store.dart';
import 'actual_bill_screen.dart';
import '../../help_videos/tutorial_videos.dart';

class BillInputsScreen extends StatefulWidget {
  final EstimateSessionStore session;
  final double aluminiumTotal;
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
  final TextEditingController _glassColorController = TextEditingController();
  final TextEditingController _aluminiumCompanyController =
      TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _extraChargesController = TextEditingController();
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
    _loadSavedRates();
    final EstimateBillDraft? draft = widget.session.billDraft;
    if (draft == null) {
      return;
    }
    _glassRateController.text = draft.glassRatePerSqFt;
    _laborRateController.text = draft.laborRatePerSqFt;
    _hardwareRateController.text = draft.hardwareRatePerWindow;
    _discountController.text = draft.aluminiumDiscountPercent;
    _extraChargesController.text = draft.extraCharges;
    _advancePaidController.text = draft.advancePaid;
    _glassColorController.text = draft.glassColor;
    _aluminiumCompanyController.text = draft.aluminiumCompany;
    _customerNameController.text = draft.customerName;
    _phoneController.text = draft.customerPhone;
    _addressController.text = draft.customerAddress;
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
      fill(_discountController, defaults.aluminiumDiscount);
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
    _glassColorController.dispose();
    _aluminiumCompanyController.dispose();
    _discountController.dispose();
    _extraChargesController.dispose();
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

    final EstimateBillDraft draft = EstimateBillDraft(
      glassRatePerSqFt: _glassRateController.text.trim(),
      laborRatePerSqFt: _laborRateController.text.trim(),
      hardwareRatePerWindow: _hardwareRateController.text.trim(),
      aluminiumDiscountPercent: _discountController.text.trim(),
      extraCharges: _extraChargesController.text.trim(),
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
      glassRatePerSqFt: _parseRequiredNumber(_glassRateController),
      laborRatePerSqFt: _parseRequiredNumber(_laborRateController),
      hardwareRatePerWindow: _parseRequiredNumber(_hardwareRateController),
      aluminiumDiscountPercent: _parseRequiredNumber(_discountController),
      aluminiumTotal: widget.aluminiumTotal,
      extraCharges: _parseOptionalNumber(_extraChargesController),
      advancePaid: _parseOptionalNumber(_advancePaidController),
      gauge: widget.gaugeValue,
      aluminiumColor: widget.colorValue,
      glassColor: _glassColorController.text.trim(),
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
    return TutorialOverlay(
      screen: TutorialScreen.billInputs,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bill Inputs'),
          actions: <Widget>[
            TutorialTarget(
              id: 'bill.next',
              child: NextStepAction(
                onPressed: () {
                  TutorialController.instance.advanceAfterTap();
                  _handleNextPressed();
                },
              ),
            ),
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
                    _InfoChip(label: 'Gage', value: widget.gaugeLabel),
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
                      _buildNumberField(
                        controller: _glassRateController,
                        label: 'Glass Rate *',
                        validator: _requiredNumberValidator,
                        tourId: 'bill.glassRate',
                      ),
                      _buildNumberField(
                        controller: _laborRateController,
                        label: 'Labor Rate *',
                        validator: _requiredNumberValidator,
                        tourId: 'bill.laborRate',
                      ),
                      _buildNumberField(
                        controller: _hardwareRateController,
                        label: 'Hardware Rate *',
                        validator: _requiredNumberValidator,
                        tourId: 'bill.hardwareRate',
                      ),
                      _buildNumberField(
                        controller: _discountController,
                        label: 'Aluminium Discount % *',
                        validator: _discountValidator,
                        tourId: 'bill.discount',
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
                      _buildNumberField(
                        controller: _extraChargesController,
                        label: 'Extra Charges',
                        validator: _optionalNumberValidator,
                        tourId: 'bill.extraCharges',
                      ),
                      _buildNumberField(
                        controller: _advancePaidController,
                        label: 'Advance Paid',
                        validator: _optionalNumberValidator,
                        tourId: 'bill.advance',
                      ),
                      _buildTextField(
                        onChanged: _onGlassColorChanged,
                        controller: _glassColorController,
                        label: 'Glass Color',
                        inputFormatters: _glassColorInputFormatters,
                        tourId: 'bill.glassColor',
                      ),
                      _buildTextField(
                        controller: _aluminiumCompanyController,
                        label: 'Aluminium Company',
                        inputFormatters: _nameInputFormatters,
                        tourId: 'bill.company',
                      ),
                      _buildTextField(
                        controller: _customerNameController,
                        label: 'Customer Name',
                        inputFormatters: _nameInputFormatters,
                        tourId: 'bill.customer',
                      ),
                      _buildTextField(
                        controller: _addressController,
                        label: 'Address',
                        maxLines: 2,
                        inputFormatters: _addressInputFormatters,
                        tourId: 'bill.address',
                      ),
                      _buildTextField(
                        controller: _phoneController,
                        label: 'Phone Number',
                        keyboardType: TextInputType.phone,
                        inputFormatters: _phoneInputFormatters,
                        validator: _phoneValidator,
                        tourId: 'bill.phone',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    // The tour explains every field here one by one, so each carries its own id.
    String? tourId,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space4),
      child: _withTourTarget(
        tourId,
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: _decimalInputFormatters,
          validator: validator,
          decoration: InputDecoration(labelText: label),
        ),
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
    String? tourId,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space4),
      child: _withTourTarget(
        tourId,
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          onChanged: onChanged,
          decoration: InputDecoration(labelText: label),
        ),
      ),
    );
  }

  Widget _withTourTarget(String? id, Widget child) =>
      id == null ? child : TutorialTarget(id: id, child: child);
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
