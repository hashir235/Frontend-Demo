/// A formula shown the way a fabricator reads it.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';

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
/// the number asks "what would this piece be at that size" -- one piece, this
/// screen, gone when it closes. Changing the formula changes how every window
/// like this one is cut from here on, and is only kept when saved.
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
    this.problem,
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

  /// What is wrong with the formula, if anything.
  final String? problem;

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
                )
              : _WithTheSizeInIt(
                  formula: formula,
                  label: label,
                  controller: sizeController,
                  hasSize: hasSize,
                  onChanged: onSizeChanged,
                  problem: problem,
                ),
        ),
        const SizedBox(width: 6),
        _ModeButton(editing: editingFormula, onTap: onToggleEditing),
      ],
    );
  }
}

/// The formula as text, for changing the arithmetic itself.
class _FormulaText extends StatelessWidget {
  const _FormulaText({
    required this.controller,
    required this.onChanged,
    required this.problem,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? problem;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      autofocus: true,
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.done,
      autocorrect: false,
      enableSuggestions: false,
      // Arithmetic only. Keeping everything else out of the field is gentler
      // than telling somebody afterwards that they cannot use it.
      inputFormatters: <TextInputFormatter>[
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
        errorText: problem,
        errorMaxLines: 3,
      ),
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
    required this.onChanged,
    required this.problem,
  });

  final String formula;
  final String label;
  final TextEditingController controller;
  final bool hasSize;
  final ValueChanged<String> onChanged;
  final String? problem;

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

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final (String, String)? parts = _split();

    final TextStyle body = const TextStyle(
      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
      fontSize: 16,
      height: 1.4,
      letterSpacing: 0.3,
      fontWeight: FontWeight.w600,
    ).copyWith(color: AppTheme.textPrimary);

    final Widget content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: problem != null ? theme.colorScheme.error : AppTheme.line,
        ),
      ),
      child: parts == null
          ? Text(formula, style: body)
          : Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                if (parts.$1.isNotEmpty) Text(parts.$1, style: body),
                _SizeBox(
                  controller: controller,
                  label: label,
                  hasSize: hasSize,
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
/// formula -- one is theirs to try, the other is theirs to keep.
class _SizeBox extends StatelessWidget {
  const _SizeBox({
    required this.controller,
    required this.label,
    required this.hasSize,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final bool hasSize;
  final ValueChanged<String> onChanged;

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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: AppTheme.tealAccent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppTheme.tealAccent.withValues(alpha: 0.45)),
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
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          style: TextStyle(
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
            color: AppTheme.tealAccent,
          ),
          decoration: const InputDecoration(
            isDense: true,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 6),
            constraints: BoxConstraints(minWidth: 44),
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
            : AppTheme.royalBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(
              editing ? Icons.check_rounded : Icons.edit_rounded,
              size: 18,
              color: editing ? Colors.white : AppTheme.royalBlue,
            ),
          ),
        ),
      ),
    );
  }
}
