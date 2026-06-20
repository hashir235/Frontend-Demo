import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../models/glass_report.dart';

/// Modal editor used for both adding a new glass row and editing an existing
/// one. Glass size (width + height) is required; every other field is optional.
/// Size uses the shop convention: whole inches + sutter eighths (half-sutter
/// allowed), matching how the rest of the system reads glass dimensions.
///
/// Returns the built [GlassReportRow], or `null` if the user cancels.
class GlassRowEditorSheet extends StatefulWidget {
  /// The row being edited, or `null` when adding a brand-new row.
  final GlassReportRow? existingRow;

  /// Window number suggested for a new row (continues the existing sequence).
  final int suggestedWindowNo;

  const GlassRowEditorSheet({
    super.key,
    this.existingRow,
    required this.suggestedWindowNo,
  });

  static Future<GlassReportRow?> show(
    BuildContext context, {
    GlassReportRow? existingRow,
    required int suggestedWindowNo,
  }) {
    return showModalBottomSheet<GlassReportRow>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext ctx) => GlassRowEditorSheet(
        existingRow: existingRow,
        suggestedWindowNo: suggestedWindowNo,
      ),
    );
  }

  @override
  State<GlassRowEditorSheet> createState() => _GlassRowEditorSheetState();
}

class _GlassRowEditorSheetState extends State<GlassRowEditorSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _winNoController;
  late final TextEditingController _labelController;
  late final TextEditingController _rubberController;
  late final TextEditingController _qtyController;
  late final TextEditingController _widthInchController;
  late final TextEditingController _heightInchController;

  // Sutter is chosen from a fixed 0..7.5 (half-step) list to avoid invalid
  // entries — this keeps the value compatible with the shop convention.
  late double _widthSutter;
  late double _heightSutter;

  static const List<double> _sutterOptions = <double>[
    0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5, 5.5, 6, 6.5, 7, 7.5,
  ];

  bool get _isEditing => widget.existingRow != null;

  @override
  void initState() {
    super.initState();
    final GlassReportRow? row = widget.existingRow;
    final GlassDimension width = row?.widthDimension ??
        const GlassDimension(inches: 0, sutter: 0);
    final GlassDimension height = row?.heightDimension ??
        const GlassDimension(inches: 0, sutter: 0);

    _winNoController = TextEditingController(
      text: row != null
          ? (row.windowNo > 0 ? row.windowNo.toString() : '')
          : widget.suggestedWindowNo.toString(),
    );
    _labelController = TextEditingController(text: row?.windowName ?? '');
    _rubberController = TextEditingController(text: row?.rubberType ?? '');
    _qtyController = TextEditingController(
      text: row != null ? row.quantity.toString() : '1',
    );
    _widthInchController = TextEditingController(
      text: width.inches > 0 ? width.inches.toString() : '',
    );
    _heightInchController = TextEditingController(
      text: height.inches > 0 ? height.inches.toString() : '',
    );
    _widthSutter = _nearestSutterOption(width.sutter);
    _heightSutter = _nearestSutterOption(height.sutter);
  }

  double _nearestSutterOption(double value) {
    return _sutterOptions.contains(value) ? value : 0;
  }

  @override
  void dispose() {
    _winNoController.dispose();
    _labelController.dispose();
    _rubberController.dispose();
    _qtyController.dispose();
    _widthInchController.dispose();
    _heightInchController.dispose();
    super.dispose();
  }

  String? _sizeInchValidator(String? value) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) {
      return 'Required';
    }
    final int? parsed = int.tryParse(text);
    if (parsed == null || parsed < 0) {
      return 'Invalid';
    }
    return null;
  }

  void _submit() {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final int widthInch = int.tryParse(_widthInchController.text.trim()) ?? 0;
    final int heightInch = int.tryParse(_heightInchController.text.trim()) ?? 0;
    final GlassDimension width =
        GlassDimension(inches: widthInch, sutter: _widthSutter);
    final GlassDimension height =
        GlassDimension(inches: heightInch, sutter: _heightSutter);

    if (!width.isPositive || !height.isPositive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Glass width and height must be greater than zero.'),
        ),
      );
      return;
    }

    final int winNo = int.tryParse(_winNoController.text.trim()) ?? 0;
    final int qty = int.tryParse(_qtyController.text.trim()) ?? 1;

    final GlassReportRow result = GlassReportRow.fromInputs(
      width: width,
      height: height,
      windowName: _labelController.text.trim(),
      windowNo: winNo,
      // Preserve the original window input size when editing; manual rows
      // leave it blank (the table shows "--").
      inputSize: widget.existingRow?.inputSize ?? '',
      rubberType: _rubberController.text.trim(),
      quantity: qty < 1 ? 1 : qty,
    );

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Icon(
                      _isEditing
                          ? Icons.edit_rounded
                          : Icons.add_box_rounded,
                      color: AppTheme.royalBlue,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isEditing ? 'Edit Glass Row' : 'Add Glass Row',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Glass size is required. Window number, label, rubber, and '
                  'quantity are optional (quantity defaults to 1).',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),

                // ── Glass size (required) ──
                Text(
                  'Glass Size',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.royalBlue,
                  ),
                ),
                const SizedBox(height: 10),
                _DimensionRow(
                  label: 'Width',
                  inchController: _widthInchController,
                  sutterValue: _widthSutter,
                  sutterOptions: _sutterOptions,
                  onSutterChanged: (double value) {
                    setState(() => _widthSutter = value);
                  },
                  inchValidator: _sizeInchValidator,
                ),
                const SizedBox(height: 12),
                _DimensionRow(
                  label: 'Height',
                  inchController: _heightInchController,
                  sutterValue: _heightSutter,
                  sutterOptions: _sutterOptions,
                  onSutterChanged: (double value) {
                    setState(() => _heightSutter = value);
                  },
                  inchValidator: _sizeInchValidator,
                ),

                const SizedBox(height: 20),
                // ── Optional metadata ──
                Text(
                  'Details (optional)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.royalBlue,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextFormField(
                        controller: _winNoController,
                        keyboardType: TextInputType.number,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(5),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Win No',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _qtyController,
                        keyboardType: TextInputType.number,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Qty',
                          hintText: '1',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _labelController,
                  inputFormatters: <TextInputFormatter>[
                    LengthLimitingTextInputFormatter(40),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Label (window name)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _rubberController,
                  inputFormatters: <TextInputFormatter>[
                    LengthLimitingTextInputFormatter(20),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Rubber type',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),

                const SizedBox(height: 22),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.check_rounded),
                        label: Text(_isEditing ? 'Save Row' : 'Add Row'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One labelled width/height input: an inch text field plus a sutter dropdown.
class _DimensionRow extends StatelessWidget {
  final String label;
  final TextEditingController inchController;
  final double sutterValue;
  final List<double> sutterOptions;
  final ValueChanged<double> onSutterChanged;
  final FormFieldValidator<String> inchValidator;

  const _DimensionRow({
    required this.label,
    required this.inchController,
    required this.sutterValue,
    required this.sutterOptions,
    required this.onSutterChanged,
    required this.inchValidator,
  });

  String _sutterLabel(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 56,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ),
        Expanded(
          child: TextFormField(
            controller: inchController,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            validator: inchValidator,
            decoration: const InputDecoration(
              labelText: 'Inches',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButtonFormField<double>(
            initialValue: sutterValue,
            isDense: true,
            decoration: const InputDecoration(
              labelText: 'Sutter',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: sutterOptions
                .map(
                  (double value) => DropdownMenuItem<double>(
                    value: value,
                    child: Text(_sutterLabel(value)),
                  ),
                )
                .toList(growable: false),
            onChanged: (double? value) {
              if (value != null) {
                onSutterChanged(value);
              }
            },
          ),
        ),
      ],
    );
  }
}
