import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_hero_header.dart';
import '../../../shared/widgets/app_screen_shell.dart';
import '../../../shared/widgets/bottom_action_bar.dart';
import '../../../shared/widgets/project_meta_strip.dart';
import '../../../shared/widgets/section_surface_card.dart';
import '../models/bill_request.dart';
import '../models/estimate_flow_state.dart';
import '../state/estimate_session_store.dart';
import 'actual_bill_screen.dart';

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
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _extraChargesController = TextEditingController();
  final TextEditingController _advancePaidController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
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
    _customerNameController.text = draft.customerName;
    _phoneController.text = draft.customerPhone;
    _addressController.text = draft.customerAddress;
  }

  @override
  void dispose() {
    _glassRateController.dispose();
    _laborRateController.dispose();
    _hardwareRateController.dispose();
    _glassColorController.dispose();
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
      projectName: widget.projectName,
      projectLocation: widget.projectLocation,
      customerName: _customerNameController.text.trim(),
      customerPhone: _phoneController.text.trim(),
      customerAddress: _addressController.text.trim(),
    );

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ActualBillScreen(
          session: widget.session,
          request: request,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bill Inputs')),
      bottomNavigationBar: BottomActionBar(
        children: <Widget>[
          Expanded(
            child: FilledButton(
              onPressed: _handleNextPressed,
              child: const Text('Next'),
            ),
          ),
        ],
      ),
      body: AppScreenShell(
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              const AppHeroHeader(
                eyebrow: 'BILLING',
                title: 'Enter billing inputs with a clean structured form',
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
                    ),
                    _buildNumberField(
                      controller: _laborRateController,
                      label: 'Labor Rate *',
                      validator: _requiredNumberValidator,
                    ),
                    _buildNumberField(
                      controller: _hardwareRateController,
                      label: 'Hardware Rate *',
                      validator: _requiredNumberValidator,
                    ),
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
                    _buildNumberField(
                      controller: _extraChargesController,
                      label: 'Extra Charges',
                      validator: _optionalNumberValidator,
                    ),
                    _buildNumberField(
                      controller: _advancePaidController,
                      label: 'Advance Paid',
                      validator: _optionalNumberValidator,
                    ),
                    _buildTextField(
                      controller: _glassColorController,
                      label: 'Glass Color',
                      inputFormatters: _glassColorInputFormatters,
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
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space4),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: validator,
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
