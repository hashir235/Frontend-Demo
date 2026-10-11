/// A formula shown the way a fabricator reads it.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/format/suter_half.dart';
import '../../estimation/presentation/input/size_entry_notation.dart';
import '../model/formula_inches.dart';

/// The formula screens' own blue: the brand blue by day, and a lighter one at
/// night, where the brand blue all but disappears into the dark surfaces and
/// a piece's name, its numbers and the keys that change them would go with it.
Color get formulaInk => AppTheme.isDark ? AppTheme.sky : AppTheme.royalBlue;

/// One formula, with the window's own measurement standing where the
/// measurement is.
///
/// Fabricators do not read algebra. `(HL - 15.5) / 2 + 8.5` is a sentence in a
/// language they never learnt, and the number it produces is a thing they know
/// exactly -- so the window's own height stands in the formula's place and the
/// sum reads as arithmetic anybody can follow:
///
///     ( [220.6] - 15.5 ) / 2 + 8.5
///
/// The boxed number is the measurement and the rest is the formula. They are
/// two different things and are edited two different ways on purpose. Changing
/// the number cuts this one piece, in this one window, as though the window
/// measured that. Changing the formula changes how every window like this one
/// is cut from here on. Both are only kept when saved.
///
/// Mixing those up is the one mistake this widget exists to prevent.
class FormulaField extends StatelessWidget {
  const FormulaField({
    super.key,
    required this.formula,
    required this.label,
    required this.sizeController,
    required this.formulaController,
    required this.editingFormula,
    required this.hasSize,
    required this.onFormulaChanged,
    required this.onSizeChanged,
    required this.onToggleEditing,
    this.ownSize = false,
    this.problem,
    this.sizeProblem,
    this.inchSuter = false,
    this.inchParts,
    this.onLengthTap,
  });

  /// The formula in display form -- the piece's own label, no margin, no feet.
  final String formula;

  /// The piece's name, which is what stands for its measurement here.
  final String label;

  /// The measurement, as it currently reads in the inner box.
  final TextEditingController sizeController;

  /// The formula text, for when it is being edited.
  final TextEditingController formulaController;

  /// True while the formula itself is being changed rather than the size.
  final bool editingFormula;

  /// Whether this window has a measurement at all. Without one the piece's own
  /// name shows instead, greyed, because a formula still has to be readable
  /// before anything has been typed.
  final bool hasSize;

  final ValueChanged<String> onFormulaChanged;
  final ValueChanged<String> onSizeChanged;
  final VoidCallback onToggleEditing;

  /// Whether the box holds a size of this piece's own rather than the
  /// window's measurement.
  final bool ownSize;

  /// What is wrong with the formula, if anything.
  final String? problem;

  /// What is wrong with the size in the box, if anything.
  final String? sizeProblem;

  /// Whether this formula, and the size in it, are in inches and suter -- the
  /// way a window measured in inches is read off the tape.
  final bool inchSuter;

  /// The formula in inches, number by number, so each length in it can be
  /// tapped and set on its own. Null when what is typed cannot be read.
  final List<InchPart>? inchParts;

  /// Called with which length was tapped, counting from the left from 0.
  final ValueChanged<int>? onLengthTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: editingFormula
              ? _FormulaText(
                  controller: formulaController,
                  onChanged: onFormulaChanged,
                  problem: problem,
                  inchSuter: inchSuter,
                )
              : _WithTheSizeInIt(
                  formula: formula,
                  label: label,
                  controller: sizeController,
                  hasSize: hasSize,
                  ownSize: ownSize,
                  onChanged: onSizeChanged,
                  // The formula's own problem first: a size cannot be judged
                  // against a formula that does not read.
                  problem: problem ?? sizeProblem,
                  inchSuter: inchSuter,
                  inchParts: inchParts,
                  onLengthTap: onLengthTap,
                ),
        ),
        const SizedBox(width: 6),
        _ModeButton(editing: editingFormula, onTap: onToggleEditing),
      ],
    );
  }
}

/// The formula as text, for changing the arithmetic itself.
class _FormulaText extends StatefulWidget {
  const _FormulaText({
    required this.controller,
    required this.onChanged,
    required this.problem,
    required this.inchSuter,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? problem;

  /// Written in inches and suter, with a row of keys for the marks a phone
  /// keyboard hides two pages deep.
  final bool inchSuter;

  @override
  State<_FormulaText> createState() => _FormulaTextState();
}

class _FormulaTextState extends State<_FormulaText> {
  /// Held so a key from the row below can type into the field without taking
  /// the keyboard away from it.
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  /// Types [text] where the cursor is, over anything selected.
  void _type(String text) {
    final TextEditingValue value = widget.controller.value;
    final TextSelection selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final String typed = value.text.replaceRange(selection.start, selection.end, text);
    widget.controller.value = TextEditingValue(
      text: typed,
      selection: TextSelection.collapsed(offset: selection.start + text.length),
    );
    widget.onChanged(typed);
    if (!_focus.hasFocus) _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final Widget field = TextField(
      controller: widget.controller,
      focusNode: _focus,
      onChanged: widget.onChanged,
      autofocus: true,
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.done,
      autocorrect: false,
      enableSuggestions: false,
      // Arithmetic only. Keeping everything else out of the field is gentler
      // than telling somebody afterwards that they cannot use it.
      inputFormatters: <TextInputFormatter>[
        if (widget.inchSuter)
          const InchFormulaTextFormatter()
        else
          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_ .+\-*/()]')),
      ],
      // The app's own face, not a monospace one. A formula here is six or
      // seven symbols, not a program, and the terminal look would sit oddly
      // against every other field in Quick AL. Figures are held to one width,
      // which is what monospace was really being asked for.
      style: const TextStyle(
        fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
        fontSize: 16,
        height: 1.4,
        letterSpacing: 0.3,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        errorText: widget.problem,
        errorMaxLines: 3,
      ),
    );

    if (!widget.inchSuter) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        field,
        const SizedBox(height: 8),
        // Part of the field as far as focus is concerned: pressing a key here
        // types into it rather than closing the keyboard.
        TextFieldTapRegion(child: _InchKeys(onKey: _type)),
      ],
    );
  }
}

/// The marks and operators a formula in inches is written with, one tap each.
///
/// On a phone the quote mark is on the second page of symbols and has to be
/// pressed two or three times for every number. Here the inch, the suter and
/// the half are each one key, named, beside the few operators a formula uses.
class _InchKeys extends StatelessWidget {
  const _InchKeys({required this.onKey});

  final ValueChanged<String> onKey;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        _InchKey(
          key: const Key('inch_key_inch'),
          mark: "''",
          name: 'inch',
          onTap: () => onKey("''"),
        ),
        _InchKey(
          key: const Key('inch_key_suter'),
          mark: "'''",
          name: 'suter',
          onTap: () => onKey("'''"),
        ),
        _InchKey(
          key: const Key('inch_key_half'),
          mark: SuterHalf.mark,
          onTap: () => onKey(SuterHalf.mark),
        ),
        for (final String op in const <String>['+', '-', '/', '(', ')'])
          _InchKey(
            key: Key('inch_key_$op'),
            mark: op,
            plain: true,
            onTap: () => onKey(op),
          ),
      ],
    );
  }
}

class _InchKey extends StatelessWidget {
  const _InchKey({
    super.key,
    required this.mark,
    required this.onTap,
    this.name,
    this.plain = false,
  });

  final String mark;

  /// What the mark is, beside it -- "inch", "suter".
  final String? name;

  /// An operator rather than a mark: quieter, so the marks stand out.
  final bool plain;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color ink = plain ? AppTheme.textPrimary : formulaInk;
    return Material(
      color: plain
          ? AppTheme.surfaceAlt
          : formulaInk.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
        side: BorderSide(
          color: plain
              ? AppTheme.line
              : formulaInk.withValues(alpha: 0.28),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  mark,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: ink,
                    letterSpacing: 0.5,
                  ),
                ),
                if (name != null) ...<Widget>[
                  const SizedBox(width: 5),
                  Text(
                    name!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.slate,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tidies what is typed into a formula in inches.
///
/// A phone has more than one quote mark, and a fitter should not have to
/// know which one Quick AL wants: a double quote is two marks, curly quotes
/// and primes are the plain one, and ×, ÷ and the long dashes are the
/// operators they look like. Anything that cannot be part of a formula is
/// left out, as it is for one in centimetres.
class InchFormulaTextFormatter extends TextInputFormatter {
  const InchFormulaTextFormatter();

  static const Map<String, String> _same = <String, String>{
    '"': "''",
    '“': "''", // “
    '”': "''", // ”
    '″': "''", // ″
    '‴': "'''", // ‴
    '‘': "'", // ‘
    '’': "'", // ’
    '′': "'", // ′
    '`': "'",
    '´': "'", // ´
    '×': '*', // ×
    '÷': '/', // ÷
    '−': '-', // −
    '–': '-', // –
    '—': '-', // —
  };

  static final RegExp _allowed = RegExp(r"[A-Za-z0-9_ .+\-*/()'½]");

  static String tidy(String text) {
    final StringBuffer out = StringBuffer();
    for (final int unit in text.codeUnits) {
      final String ch = String.fromCharCode(unit);
      for (final int each in (_same[ch] ?? ch).codeUnits) {
        final String kept = String.fromCharCode(each);
        if (_allowed.hasMatch(kept)) out.write(kept);
      }
    }
    return out.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String text = tidy(newValue.text);
    if (text == newValue.text) return newValue;
    final int caret = newValue.selection.isValid
        ? newValue.selection.end.clamp(0, newValue.text.length)
        : newValue.text.length;
    final int at = tidy(newValue.text.substring(0, caret)).length;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: at),
    );
  }
}

/// The formula with the window's measurement boxed inside it.
class _WithTheSizeInIt extends StatelessWidget {
  const _WithTheSizeInIt({
    required this.formula,
    required this.label,
    required this.controller,
    required this.hasSize,
    required this.ownSize,
    required this.onChanged,
    required this.problem,
    required this.inchSuter,
    required this.inchParts,
    required this.onLengthTap,
  });

  final String formula;
  final String label;
  final TextEditingController controller;
  final bool hasSize;
  final bool ownSize;
  final ValueChanged<String> onChanged;
  final String? problem;
  final bool inchSuter;
  final List<InchPart>? inchParts;
  final ValueChanged<int>? onLengthTap;

  /// Where the measurement sits in the formula.
  ///
  /// Every formula Quick AL ships names its measurement exactly once, which is
  /// what makes a box in the middle of a sentence possible at all. A formula
  /// somebody has edited need not: `HL * HL` is arithmetic, just not arithmetic
  /// with one place to put a number. Those are shown as plain text rather than
  /// wrongly boxed.
  (String, String)? _split() {
    final RegExp name = RegExp('(?<![A-Za-z0-9_])${RegExp.escape(label)}(?![A-Za-z0-9_])');
    final Iterable<RegExpMatch> found = name.allMatches(formula);
    if (found.length != 1) return null;
    final RegExpMatch match = found.first;
    return (formula.substring(0, match.start), formula.substring(match.end));
  }

  /// The formula in inches: the size boxed where the measurement is, and
  /// every length a key of its own.
  Widget _inInches(List<InchPart> parts, TextStyle body) {
    // As in centimetres, a box only where there is exactly one place for it.
    final bool oneMeasurement = parts.whereType<InchMeasurement>().length == 1;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 4,
      children: <Widget>[
        for (final InchPart part in parts)
          switch (part) {
            InchWords(:final String text) => Text(text, style: body),
            InchMeasurement() when oneMeasurement => _SizeBox(
                controller: controller,
                label: label,
                hasSize: hasSize,
                ownSize: ownSize,
                onChanged: onChanged,
                inchSuter: true,
              ),
            InchMeasurement(:final String label) => Text(label, style: body),
            InchLengthPart() => _LengthKey(
                key: Key('inch_length_${part.index}'),
                part: part,
                onTap: onLengthTap == null ? null : () => onLengthTap!(part.index),
              ),
          },
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final (String, String)? parts = inchSuter ? null : _split();

    final TextStyle body = const TextStyle(
      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
      fontSize: 16,
      height: 1.4,
      letterSpacing: 0.3,
      fontWeight: FontWeight.w600,
    ).copyWith(color: AppTheme.textPrimary);

    final List<InchPart>? inches = inchParts;
    final Widget content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: problem != null ? theme.colorScheme.error : AppTheme.line,
        ),
      ),
      child: inchSuter
          // What cannot be read is shown as it was typed, with the reason
          // under it, exactly as a formula in centimetres is.
          ? (inches == null ? Text(formula, style: body) : _inInches(inches, body))
          : parts == null
              ? Text(formula, style: body)
              : Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    if (parts.$1.isNotEmpty) Text(parts.$1, style: body),
                    _SizeBox(
                      controller: controller,
                      label: label,
                      hasSize: hasSize,
                      ownSize: ownSize,
                      onChanged: onChanged,
                    ),
                    if (parts.$2.isNotEmpty) Text(parts.$2, style: body),
                  ],
                ),
    );

    if (problem == null) return content;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        content,
        const SizedBox(height: 6),
        Text(
          problem!,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
        ),
      ],
    );
  }
}

/// The measurement, boxed, inside the formula.
///
/// Its own outline and its own colour, because a fabricator has to be able to
/// tell at a glance which number is the window and which numbers are the
/// formula. A size of the piece's own turns amber, the colour of every other
/// decision on this screen the cutting list will follow.
class _SizeBox extends StatelessWidget {
  const _SizeBox({
    required this.controller,
    required this.label,
    required this.hasSize,
    required this.ownSize,
    required this.onChanged,
    this.inchSuter = false,
  });

  final TextEditingController controller;
  final String label;
  final bool hasSize;
  final bool ownSize;
  final ValueChanged<String> onChanged;

  /// Typed as a size is typed on the measuring screen: the inch, then the
  /// point or the space, then the suter, then the point again for the ½.
  final bool inchSuter;

  @override
  Widget build(BuildContext context) {
    // Nothing typed yet: the piece's own name, greyed, so the formula still
    // reads as a formula before any window has been measured.
    if (!hasSize) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppTheme.surfaceMuted,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: AppTheme.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            color: AppTheme.slate.withValues(alpha: 0.75),
          ),
        ),
      );
    }

    final Color accent = ownSize ? AppTheme.amberAccent : AppTheme.tealAccent;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: accent.withValues(alpha: ownSize ? 0.8 : 0.45)),
      ),
      child: IntrinsicWidth(
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          autocorrect: false,
          enableSuggestions: false,
          inputFormatters: <TextInputFormatter>[
            if (inchSuter)
              // Filters and marks in one pass, as the measuring screen does:
              // 86'' 7½''' appearing as it is typed.
              const MergedSizeFormatter()
            else
              // Digits and one decimal point, at most two places after it: a
              // size is a measurement, and "152..4" or "152.4567" is a slip,
              // not a finer one.
              FilteringTextInputFormatter.allow(RegExp(r'^\d{0,4}(\.\d{0,2})?')),
          ],
          style: TextStyle(
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
            color: accent,
          ),
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 6),
            constraints: BoxConstraints(minWidth: inchSuter ? 52 : 44),
          ),
        ),
      ),
    );
  }
}

/// One length in a formula shown in inches, as a key that opens it for
/// changing.
///
/// The formula's own colour, not the size's teal: this number belongs to the
/// formula, and changing it changes every window like this one. A number
/// that is only the nearest half suter to what Quick AL keeps wears a small
/// ≈ in front, so nobody takes `1'' 5'''` for exactly 1'' 5''' when it is
/// really 4.2 cm.
class _LengthKey extends StatelessWidget {
  const _LengthKey({super.key, required this.part, required this.onTap});

  final InchLengthPart part;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Change ${part.length.text}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        // A raised key on the formula's grey, unlike the tinted name tag
        // above it, so it reads as something to press rather than a label.
        child: Material(
          color: AppTheme.surface,
          elevation: 0.5,
          shadowColor: AppTheme.shadowColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(7),
            side: BorderSide(color: formulaInk.withValues(alpha: 0.38)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(7),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(7, 4, 7, 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  if (part.approximate) ...<Widget>[
                    Text(
                      '≈',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.slate,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(width: 3),
                  ],
                  Text(
                    part.length.text,
                    style: TextStyle(
                      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                      height: 1.2,
                      color: formulaInk,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Switches between changing the size and changing the formula.
class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.editing, required this.onTap});

  final bool editing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: editing ? 'Done with the formula' : 'Change the formula itself',
      child: Material(
        color: editing
            ? AppTheme.royalBlue
            : formulaInk.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(
              editing ? Icons.check_rounded : Icons.edit_rounded,
              size: 18,
              color: editing ? Colors.white : formulaInk,
            ),
          ),
        ),
      ),
    );
  }
}
