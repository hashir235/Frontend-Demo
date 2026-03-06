import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../models/bill_request.dart';
import 'actual_bill_screen.dart';

class BillInputsScreen extends StatefulWidget {
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
      <TextInputFormatter>[
    LengthLimitingTextInputFormatter(80),
  ];
  static final List<TextInputFormatter> _glassColorInputFormatters =
      <TextInputFormatter>[
    LengthLimitingTextInputFormatter(80),
  ];
  static final List<TextInputFormatter> _addressInputFormatters =
      <TextInputFormatter>[
    LengthLimitingTextInputFormatter(200),
  ];

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
          request: request,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.mist, AppTheme.ice],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: AppTheme.deepTeal,
                    ),
                    Expanded(
                      child: Text(
                        'Bill Inputs',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineLarge
                            ?.copyWith(fontSize: 30, height: 1),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: AppTheme.sky.withValues(alpha: 0.65),
                ),
              ),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            _InfoChip(label: 'Gage', value: widget.gaugeLabel),
                            _InfoChip(label: 'Color', value: widget.colorLabel),
                            _InfoChip(
                              label: 'Aluminium',
                              value: _formatAmount(widget.aluminiumTotal),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _SectionLabel(text: '* Mandatory Fields'),
                        const SizedBox(height: 10),
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
                        const SizedBox(height: 12),
                        _SectionLabel(text: '* Optional Fields'),
                        const SizedBox(height: 10),
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
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _handleNextPressed,
                      child: const Text('Next'),
                    ),
                  ),
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
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: _decimalInputFormatters,
        validator: validator,
        decoration: _inputDecoration(label),
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
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: validator,
        decoration: _inputDecoration(label),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      enabledBorder: BorderSide(
        color: AppTheme.sky.withValues(alpha: 0.75),
        width: 1,
      ).toBorder(),
      focusedBorder: BorderSide(
        color: AppTheme.violet.withValues(alpha: 0.85),
        width: 1.2,
      ).toBorder(),
      errorBorder: BorderSide(
        color: Colors.red.shade400,
        width: 1,
      ).toBorder(),
      focusedErrorBorder: BorderSide(
        color: Colors.red.shade600,
        width: 1.2,
      ).toBorder(),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: AppTheme.deepTeal,
        fontWeight: FontWeight.w700,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.sky.withValues(alpha: 0.55)),
      ),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.deepTeal,
          ),
          children: <InlineSpan>[
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

extension on BorderSide {
  UnderlineInputBorder toBorder() {
    return UnderlineInputBorder(borderSide: this);
  }
}

