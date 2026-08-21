import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/suter_wheel.dart';
import '../../settings/state/app_settings.dart';
import '../../settings/state/size_input_mode.dart';
import '../models/glass_report.dart';

/// Modal editor used for both adding a new glass row and editing an existing
/// one. Glass size (width + height) is required; every other field is optional.
/// Size uses the shop convention: whole inches + sutter eighths (half-sutter
/// allowed), matching how the rest of the system reads glass dimensions.
/// The sutter part is picked on a tape-style [SuterWheel] instead of a
/// dropdown, so it feels like reading a real inchi tape.
///
/// Returns the built [GlassReportRow], or `null` if the user cancels.
class GlassRowEditorSheet extends StatefulWidget {
  /// The row being edited, or `null` when adding brand-new rows.
  final GlassReportRow? existingRow;

  /// Window number suggested for a new row (continues the existing sequence).
  final int suggestedWindowNo;

  /// Called for each row saved while the sheet stays open.
  ///
  /// Present only when adding. A glass job is a run of pieces typed one after
  /// another, so the sheet keeps itself open and clears down for the next one
  /// rather than closing and making the user press Add Row again -- the same
  /// rhythm the window input already has.
  final ValueChanged<GlassReportRow>? onRowSaved;

  const GlassRowEditorSheet({
    super.key,
    this.existingRow,
    required this.suggestedWindowNo,
    this.onRowSaved,
  });

  static Future<GlassReportRow?> show(
    BuildContext context, {
    GlassReportRow? existingRow,
    required int suggestedWindowNo,
    ValueChanged<GlassReportRow>? onRowSaved,
  }) {
    return showModalBottomSheet<GlassReportRow>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext ctx) => GlassRowEditorSheet(
        existingRow: existingRow,
        suggestedWindowNo: suggestedWindowNo,
        onRowSaved: onRowSaved,
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

  // Sutter comes from the tape wheel, which only produces 0..7.5 in half
  // steps — this keeps the value compatible with the shop convention.
  late double _widthSutter;
  late double _heightSutter;

  /// How many rows this sitting has added, so the sheet can show progress
  /// while it stays open.
  int _savedCount = 0;

  // The tab order a piece of glass is actually typed in: width, height, then
  // how many. Pressing the keyboard's next/tick walks it, and the last field
  // saves the row -- so a run of glass never needs the screen touched.
  final FocusNode _widthFocus = FocusNode();
  final FocusNode _widthSutterFocus = FocusNode();
  final FocusNode _heightFocus = FocusNode();
  final FocusNode _heightSutterFocus = FocusNode();
  final FocusNode _qtyFocus = FocusNode();

  bool get _isEditing => widget.existingRow != null;

  @override
  void initState() {
    super.initState();
    final GlassReportRow? row = widget.existingRow;
    final GlassDimension width =
        row?.widthDimension ?? const GlassDimension(inches: 0, sutter: 0);
    final GlassDimension height =
        row?.heightDimension ?? const GlassDimension(inches: 0, sutter: 0);

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
    _widthSutter = SuterWheel.snap(width.sutter);
    _heightSutter = SuterWheel.snap(height.sutter);
  }

  @override
  void dispose() {
    _winNoController.dispose();
    _labelController.dispose();
    _rubberController.dispose();
    _qtyController.dispose();
    _widthSutterFocus.dispose();
    _heightFocus.dispose();
    _heightSutterFocus.dispose();
    _qtyFocus.dispose();
    _widthInchController.dispose();
    _heightInchController.dispose();
    _widthFocus.dispose();
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
    final GlassDimension width = GlassDimension(
      inches: widthInch,
      sutter: _widthSutter,
    );
    final GlassDimension height = GlassDimension(
      inches: heightInch,
      sutter: _heightSutter,
    );

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

    final ValueChanged<GlassReportRow>? keepOpen = widget.onRowSaved;
    if (keepOpen == null || _isEditing) {
      Navigator.of(context).pop(result);
      return;
    }

    keepOpen(result);
    _resetForNextRow(winNo);
  }

  /// Clears the size fields and steps the window number on, leaving the sheet
  /// ready for the next piece.
  ///
  /// Rubber type and the window name stay: on a real job a run of glass is
  /// usually the same kind, and retyping it every row is the thing that made
  /// people avoid this screen.
  void _resetForNextRow(int savedWinNo) {
    setState(() {
      _savedCount += 1;
      _widthInchController.clear();
      _heightInchController.clear();
      _widthSutter = 0;
      _heightSutter = 0;
      _qtyController.text = '1';
      _winNoController.text = (savedWinNo + 1).toString();
    });
    _formKey.currentState?.reset();
    // Straight back to the first size box, so the next piece can be typed
    // without reaching for the screen.
    FocusScope.of(context).requestFocus(_widthFocus);
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
                      _isEditing ? Icons.edit_rounded : Icons.add_box_rounded,
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
                  inchFocusNode: _widthFocus,
                  sutterFocusNode: _widthSutterFocus,
                  onRowComplete: () =>
                      FocusScope.of(context).requestFocus(_heightFocus),
                  inchController: _widthInchController,
                  sutterValue: _widthSutter,
                  onSutterChanged: (double value) {
                    setState(() => _widthSutter = value);
                  },
                  inchValidator: _sizeInchValidator,
                ),
                const SizedBox(height: 12),
                _DimensionRow(
                  label: 'Height',
                  inchFocusNode: _heightFocus,
                  sutterFocusNode: _heightSutterFocus,
                  onRowComplete: () =>
                      FocusScope.of(context).requestFocus(_qtyFocus),
                  inchController: _heightInchController,
                  sutterValue: _heightSutter,
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
                        focusNode: _qtyFocus,
                        keyboardType: TextInputType.number,
                        // The end of the chain: the tick saves the row, which
                        // clears the boxes and puts the cursor back on Width.
                        // A run of glass can be typed without touching the
                        // screen once.
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
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
                // While rows are being typed in a run, say how many have gone
                // in -- otherwise the sheet clearing itself looks the same as
                // the sheet losing what you typed.
                if (_savedCount > 0) ...<Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: AppTheme.success,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _savedCount == 1
                            ? '1 glass added'
                            : '$_savedCount glass pieces added',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.success,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          _isEditing || _savedCount == 0 ? 'Cancel' : 'Done',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.check_rounded),
                        label: Text(
                          _isEditing
                              ? 'Save Row'
                              : (widget.onRowSaved != null
                                    ? 'Save & Next'
                                    : 'Add Row'),
                        ),
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

/// One labelled width/height input: an inch text field plus the sutter, which
/// is either the tape-style wheel or a plain typing box.
///
/// Which one appears is the same Settings choice the window pages read. It was
/// previously only honoured there, so someone who had switched to typing still
/// met a wheel the moment they entered glass.
class _DimensionRow extends StatefulWidget {
  final String label;
  final TextEditingController inchController;
  final double sutterValue;
  final ValueChanged<double> onSutterChanged;
  final FormFieldValidator<String> inchValidator;

  /// Set on the first size box so a saved row can hand the cursor straight
  /// back to it for the next piece.
  final FocusNode? inchFocusNode;

  /// Only used when the sutter is a typing box; the wheel takes no focus.
  final FocusNode? sutterFocusNode;

  /// Where the cursor goes once this row has been filled in.
  ///
  /// Called from the sutter box when the box is showing, and from the inch box
  /// when the wheel is on instead — so pressing next walks the same path
  /// whichever way sizes are being entered.
  final VoidCallback? onRowComplete;

  const _DimensionRow({
    required this.label,
    required this.inchController,
    required this.sutterValue,
    required this.onSutterChanged,
    required this.inchValidator,
    this.inchFocusNode,
    this.sutterFocusNode,
    this.onRowComplete,
  });

  @override
  State<_DimensionRow> createState() => _DimensionRowState();
}

class _DimensionRowState extends State<_DimensionRow> {
  late final TextEditingController _sutterController;

  @override
  void initState() {
    super.initState();
    _sutterController = TextEditingController(
      text: _formatSutter(widget.sutterValue),
    );
  }

  @override
  void didUpdateWidget(covariant _DimensionRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only when the value really moved elsewhere, so typing is never
    // interrupted by the field rewriting itself under the cursor.
    if (widget.sutterValue != oldWidget.sutterValue &&
        _parseSutter(_sutterController.text) != widget.sutterValue) {
      _sutterController.text = _formatSutter(widget.sutterValue);
    }
  }

  @override
  void dispose() {
    _sutterController.dispose();
    super.dispose();
  }

  /// Whole numbers read better without a trailing ".0" on a cutting slip.
  ///
  /// Zero shows as an empty box rather than "0". A pre-filled zero has to be
  /// cleared before a number can be typed — on a screen where a run of glass
  /// is entered piece after piece, that is one deletion per piece. Blank means
  /// zero anyway, which is what [_parseSutter] does with it.
  static String _formatSutter(double value) {
    if (value == 0) return '';
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  static double _parseSutter(String text) => double.tryParse(text.trim()) ?? 0;

  void _onSutterTyped(String text) {
    final double parsed = _parseSutter(text);
    // The wheel can only produce 0..7.5 in half steps; typing is held to the
    // same range so both paths save identical values.
    final double clamped = parsed.clamp(0, 7.5).toDouble();
    widget.onSutterChanged(SuterWheel.snap(clamped));
  }

  @override
  Widget build(BuildContext context) {
    final bool usesKeypad =
        AppSettings.instance.sizeInputMode == SizeInputMode.keypad;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 56,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              widget.label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ),
        Expanded(
          child: TextFormField(
            controller: widget.inchController,
            focusNode: widget.inchFocusNode,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) {
              // With the wheel showing there is no sutter box to move into,
              // so this box hands straight on to the next row.
              if (usesKeypad && widget.sutterFocusNode != null) {
                FocusScope.of(context).requestFocus(widget.sutterFocusNode);
              } else {
                widget.onRowComplete?.call();
              }
            },
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            validator: widget.inchValidator,
            decoration: const InputDecoration(
              labelText: 'Inches',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: usesKeypad
              ? TextFormField(
                  controller: _sutterController,
                  focusNode: widget.sutterFocusNode,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => widget.onRowComplete?.call(),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d?')),
                  ],
                  onChanged: _onSutterTyped,
                  decoration: const InputDecoration(
                    labelText: 'Sutter',
                    hintText: '0-7.5',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                )
              : SuterWheel(
                  value: widget.sutterValue,
                  onChanged: widget.onSutterChanged,
                  label: 'Sutter',
                ),
        ),
      ],
    );
  }
}
