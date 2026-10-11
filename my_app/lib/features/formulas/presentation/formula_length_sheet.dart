/// Setting one length of a formula, in inches and suter.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/format/suter_half.dart';
import '../model/formula_inches.dart';
import 'formula_field.dart' show formulaInk;

/// What a piece comes to with the number being set: its cut size, or why it
/// has none.
class LengthSheetCut {
  const LengthSheetCut.size({required String this.inches, required String this.centimetres})
      : problem = null;

  const LengthSheetCut.problem(String this.problem)
      : inches = null,
        centimetres = null;

  /// `40'' 3½'''`.
  final String? inches;

  /// `102.6 cm`.
  final String? centimetres;

  final String? problem;
}

/// Opens one length of a formula for setting, and returns the new length --
/// or null when the sheet is closed without taking one.
///
/// The way a formula in inches is mostly adjusted: one deduction a suter or
/// two off, everything around it left alone. The number is typed the way a
/// size is typed on the measuring screen -- the inch, then the point to move
/// on, then the suter, then the point again for the ½ -- or moved half a
/// suter at a time, and the formula and the cut size beneath follow it as it
/// moves.
///
/// [keptAs] is the stored value, said in its own unit, when the length is
/// only the nearest half suter to it; the sheet then says that leaving it
/// alone keeps it exact.
Future<InchLength?> showFormulaLengthSheet({
  required BuildContext context,
  required String label,
  required InchLength current,
  required String Function(InchLength length) formulaWith,
  required LengthSheetCut? Function(InchLength length) cutWith,
  String? keptAs,
}) {
  return showModalBottomSheet<InchLength>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _LengthSheet(
      label: label,
      current: current,
      keptAs: keptAs,
      formulaWith: formulaWith,
      cutWith: cutWith,
    ),
  );
}

class _LengthSheet extends StatefulWidget {
  const _LengthSheet({
    required this.label,
    required this.current,
    required this.keptAs,
    required this.formulaWith,
    required this.cutWith,
  });

  final String label;
  final InchLength current;
  final String? keptAs;
  final String Function(InchLength) formulaWith;
  final LengthSheetCut? Function(InchLength) cutWith;

  @override
  State<_LengthSheet> createState() => _LengthSheetState();
}

class _LengthSheetState extends State<_LengthSheet> {
  late InchLength _value = widget.current;

  late final TextEditingController _inch =
      TextEditingController(text: _inchText(widget.current));
  late final TextEditingController _suter =
      TextEditingController(text: _suterText(widget.current));

  /// Where the point or the space after the inch moves the cursor.
  final FocusNode _suterFocus = FocusNode();

  @override
  void dispose() {
    _inch.dispose();
    _suter.dispose();
    _suterFocus.dispose();
    super.dispose();
  }

  /// A nought is left to the box's hint rather than typed in, so a box is
  /// either a number somebody chose or visibly empty.
  static String _inchText(InchLength length) =>
      length.inches == 0 ? '' : '${length.inches}';

  static String _suterText(InchLength length) {
    final int halves = length.sixteenths % 16;
    return halves == 0 ? '' : SuterHalf.format(halves / 2);
  }

  void _typed() {
    final int inches = int.tryParse(_inch.text.trim()) ?? 0;
    // The suter box only takes 0 to 7½; the clamp is a second lock on it.
    final double suter = (SuterHalf.parse(_suter.text) ?? 0).clamp(0, 7.5);
    setState(() => _value = InchLength.of(inches: inches, suter: suter));
  }

  void _step(int marks) {
    final InchLength moved = _value.step(marks);
    setState(() {
      _value = moved;
      _inch.text = _inchText(moved);
      _suter.text = _suterText(moved);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LengthSheetCut? cut = widget.cutWith(_value);
    final bool usable = cut?.problem == null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: formulaInk.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: formulaInk.withValues(alpha: 0.22)),
                    ),
                    child: Text(
                      widget.label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: formulaInk,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Change this number',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'In inch and suter. It changes the formula for every window '
                'like this one once you save.',
                style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.slate, height: 1.4),
              ),
              const SizedBox(height: 14),
              // The whole formula with the new number standing in it, so the
              // number is never set without seeing what it is part of.
              Container(
                key: const Key('length_sheet_formula'),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.line),
                ),
                child: Text(
                  widget.formulaWith(_value),
                  style: TextStyle(
                    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                    fontSize: 15.5,
                    height: 1.4,
                    letterSpacing: 0.3,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  _Step(
                    key: const Key('length_sheet_less'),
                    icon: Icons.remove_rounded,
                    tooltip: 'Half a suter less',
                    onTap: _value.sixteenths == 0 ? null : () => _step(-1),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MarkBox(
                      key: const Key('length_sheet_inch'),
                      controller: _inch,
                      label: 'Inch',
                      mark: "''",
                      hint: '0',
                      onChanged: (_) => _typed(),
                      formatters: <TextInputFormatter>[
                        // The point or the space moves on to the suter box.
                        InchBoxFormatter(
                          onNext: () {
                            if (mounted) _suterFocus.requestFocus();
                          },
                        ),
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MarkBox(
                      key: const Key('length_sheet_suter'),
                      controller: _suter,
                      focusNode: _suterFocus,
                      label: 'Suter',
                      mark: "'''",
                      hint: '0-7½',
                      onChanged: (_) => _typed(),
                      // The point or the space after the suter is the half,
                      // and shows as ½ as it is pressed.
                      formatters: const <TextInputFormatter>[SuterBoxFormatter()],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _Step(
                    key: const Key('length_sheet_more'),
                    icon: Icons.add_rounded,
                    tooltip: 'Half a suter more',
                    onTap: () => _step(1),
                  ),
                ],
              ),
              if (widget.keptAs != null) ...<Widget>[
                const SizedBox(height: 12),
                _KeptNote(keptAs: widget.keptAs!, shownAs: widget.current.text),
              ],
              if (cut != null) ...<Widget>[
                const SizedBox(height: 12),
                _CutLine(cut: cut),
              ],
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: formulaInk),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('length_sheet_use'),
                      onPressed: usable ? () => Navigator.of(context).pop(_value) : null,
                      icon: const Icon(Icons.check_rounded),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Use ${_value.text}'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Half a suter less, or more.
class _Step extends StatelessWidget {
  const _Step({super.key, required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    final Color ink = enabled ? formulaInk : AppTheme.slate.withValues(alpha: 0.5);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: formulaInk.withValues(alpha: enabled ? 0.08 : 0.03),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: formulaInk.withValues(alpha: enabled ? 0.28 : 0.10),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            width: 56,
            height: 56,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon, size: 22, color: ink),
                Text(
                  "${SuterHalf.mark}'''",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    color: ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One part of the length -- the inch or the suter -- with its tape mark
/// after it.
class _MarkBox extends StatelessWidget {
  const _MarkBox({
    super.key,
    required this.controller,
    required this.label,
    required this.mark,
    required this.hint,
    required this.onChanged,
    required this.formatters,
    this.focusNode,
  });

  final TextEditingController controller;
  final String label;
  final String mark;
  final String hint;
  final ValueChanged<String> onChanged;
  final List<TextInputFormatter> formatters;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      autocorrect: false,
      enableSuggestions: false,
      inputFormatters: formatters,
      style: TextStyle(
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: AppTheme.textPrimary,
      ),
      decoration: InputDecoration(
        // The tape mark in the name rather than after the number: centred
        // digits with a mark pinned to the far edge read as two things.
        labelText: '$label  $mark',
        hintText: hint,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        floatingLabelStyle: TextStyle(color: AppTheme.slate, fontWeight: FontWeight.w700),
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      ),
    );
  }
}

/// Says that the number is only the nearest half suter to what is kept, and
/// that leaving it alone keeps it exact.
class _KeptNote extends StatelessWidget {
  const _KeptNote({required this.keptAs, required this.shownAs});

  final String keptAs;
  final String shownAs;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 8, 11, 8),
      decoration: BoxDecoration(
        color: AppTheme.slate.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '≈',
            style: TextStyle(
              fontSize: 15,
              height: 1.25,
              fontWeight: FontWeight.w800,
              color: AppTheme.slate,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              // The size held together, so a line never ends between its
              // inch and its suter.
              'Quick AL keeps this as ${keptAs.replaceAll(' ', '\u00A0')}. '
              'Left at ${shownAs.replaceAll(' ', '\u00A0')}, it stays exactly that.',
              style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.slate, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// What the piece comes to with the number as it now stands.
class _CutLine extends StatelessWidget {
  const _CutLine({required this.cut});

  final LengthSheetCut cut;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (cut.problem != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.report_problem_rounded, size: 15, color: theme.colorScheme.error),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              cut.problem!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }
    return Container(
      key: const Key('length_sheet_cut'),
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
      decoration: BoxDecoration(
        color: AppTheme.tealAccent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppTheme.tealAccent.withValues(alpha: 0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          const Icon(Icons.straighten_rounded, size: 15, color: AppTheme.tealAccent),
          const SizedBox(width: 7),
          Text(
            'Cut size',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppTheme.tealAccent,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          Text(
            cut.inches!,
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppTheme.tealAccent,
              fontWeight: FontWeight.w900,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            cut.centimetres!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.slate,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
