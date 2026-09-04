/// The screen where a workshop reads, and changes, the sums Quick AL cuts by.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/format/cut_length.dart';
import '../data/formula_book.dart';
import '../model/formula_overrides.dart';
import '../model/formula_expression.dart';
import '../model/formula_slot.dart';
import '../model/formula_window_key.dart';

/// Reads and edits the formulas for one window configuration.
///
/// Everything here is about one window as it stands on the bench -- this
/// collar, this lock, this rubber -- because that is the window a fabricator
/// has in front of them. The fourteen collar types are not a list to scroll;
/// they are offered at the moment of saving, as "and everywhere else this
/// applies", which is the only point at which the question means anything.
class FormulaEditorScreen extends StatefulWidget {
  const FormulaEditorScreen({
    super.key,
    required this.windowKey,
    required this.windowTitle,
    required this.configSummary,
    required this.book,
    this.measurements = const <String, double>{},
    this.onSaved,
  });

  /// Which window's formulas these are.
  final FormulaWindowKey windowKey;

  /// "Sliding Window" -- what the fabricator picked.
  final String windowTitle;

  /// "Collar 2 · Latch · F rubber" -- the settings these formulas belong to.
  final String configSummary;

  /// The formulas in force. Edited on a copy; the caller only sees changes if
  /// they are saved.
  final FormulaBook book;

  /// The window's current measurements, in the catalogue's names, so each
  /// formula can be shown working. Empty is fine -- the lengths are simply not
  /// shown, which is what happens before anything has been typed.
  final Map<String, double> measurements;

  /// Handed the changed formulas when the workshop saves.
  final Future<void> Function(FormulaOverrides overrides)? onSaved;

  @override
  State<FormulaEditorScreen> createState() => _FormulaEditorScreenState();
}

class _FormulaEditorScreenState extends State<FormulaEditorScreen> {
  late FormulaBook _draft;
  late List<EffectiveSection> _sections;

  /// One controller per piece, alive for the life of the screen so a caret
  /// does not jump while somebody is typing.
  final Map<FormulaPieceRef, TextEditingController> _controllers =
      <FormulaPieceRef, TextEditingController>{};

  /// What is wrong with what is currently typed, per piece.
  final Map<FormulaPieceRef, String> _problems = <FormulaPieceRef, String>{};

  /// The formula each box started at, so "changed" means changed by this
  /// person in this sitting, not merely different from what Quick AL ships.
  final Map<FormulaPieceRef, String> _opened = <FormulaPieceRef, String>{};

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.book.copy();
    _sections = _draft.sectionsFor(widget.windowKey) ?? <EffectiveSection>[];
    for (final EffectiveSection section in _sections) {
      for (final EffectiveFormula piece in section.pieces) {
        final String shown = piece.slot.display;
        _controllers[piece.ref] = TextEditingController(text: shown);
        _opened[piece.ref] = shown;
      }
    }
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _hasEdits {
    for (final MapEntry<FormulaPieceRef, TextEditingController> entry in _controllers.entries) {
      if (entry.value.text.trim() != _opened[entry.key]) return true;
    }
    return false;
  }

  bool get _hasProblems => _problems.isNotEmpty;

  /// What Quick AL puts around every formula on this screen, and what that
  /// means for the sizes shown under them.
  ///
  /// This is the note that stops a formula being set wrong. A cutting margin
  /// goes onto every piece so the optimizer can leave the blade room, and the
  /// fabrication cutting list takes it off again -- so a fabricator who
  /// remembers the margin but not the taking-off would "correct" a formula for
  /// an allowance that was never in the size they were reading. Saying both
  /// halves, and saying which one the sizes below are, is the difference
  /// between a screen that helps and one that quietly misleads.
  ///
  /// Taken from the first piece that has a margin, because within one window
  /// they all work the same way.
  String? get _appliedAutomatically {
    for (final EffectiveSection section in _sections) {
      for (final EffectiveFormula piece in section.pieces) {
        if (piece.slot.marginName == null) continue;
        return piece.slot.isFabrication
            ? 'A cutting margin is added to every piece for the saw, then taken '
                'off again on the cutting list. The sizes below are the real '
                'cut sizes, without it.'
            : 'Each profile\'s cutting margin is added to every piece. The '
                'sizes below include it, exactly as the cutting list does.';
      }
    }
    return null;
  }

  EffectiveFormula? _pieceFor(FormulaPieceRef ref) {
    for (final EffectiveSection section in _sections) {
      for (final EffectiveFormula piece in section.pieces) {
        if (piece.ref == ref) return piece;
      }
    }
    return null;
  }

  void _onTyped(FormulaPieceRef ref, String text) {
    final EffectiveFormula? piece = _pieceFor(ref);
    if (piece == null) return;
    final FormulaEdit edit = piece.slot.readDisplay(text);
    setState(() {
      if (edit.isUsable) {
        _problems.remove(ref);
      } else {
        _problems[ref] = edit.problem ?? 'This formula cannot be used.';
      }
    });
  }

  /// The size this formula gives for the window on the bench, or why it gives
  /// none.
  ///
  /// Shown under every box as it is typed, because a formula is abstract and a
  /// size is not: "216.4 cm" is checkable against the drawing in a way that
  /// "HL - 4.2" never is. It is the size that will be cut, with the saw's own
  /// allowance already off it, and it is given in all three units because a
  /// workshop that measures in suter should not have to work out in its head
  /// what taking 2mm off a formula does to the cut.
  String? _preview(FormulaPieceRef ref, FormulaSlot slot) {
    if (widget.measurements.isEmpty) return null;
    final String typed = _controllers[ref]?.text ?? slot.display;
    final FormulaEdit edit = slot.readDisplay(typed);
    if (!edit.isUsable) return null;

    final FormulaResult result =
        slot.withStored(edit.stored!).cutLengthFor(widget.measurements);
    if (!result.isUsable) return result.problem;

    return CutLength.fromFeet(result.asCutLength!)
        .threeWays(centimetresFirst: slot.isFabrication);
  }

  Future<void> _resetPiece(FormulaPieceRef ref) async {
    final EffectiveFormula? piece = _pieceFor(ref);
    if (piece == null) return;
    final String? shipped = _draft.shippedFormulaFor(ref);
    if (shipped == null) return;

    final FormulaSlot original = piece.slot.withStored(shipped);
    setState(() {
      _controllers[ref]!.text = original.display;
      _problems.remove(ref);
    });
  }

  Future<void> _resetEverything() async {
    final bool confirmed = await _confirm(
      title: 'Put every formula back?',
      body: 'Every sum on this screen goes back to the one Quick AL ships. '
          'Formulas you have changed for other collar types are left alone.',
      confirmLabel: 'Put back',
    );
    if (!confirmed || !mounted) return;

    _draft.resetConfiguration(widget.windowKey);
    final List<EffectiveSection> refreshed =
        _draft.sectionsFor(widget.windowKey) ?? <EffectiveSection>[];
    setState(() {
      _sections = refreshed;
      _problems.clear();
      for (final EffectiveSection section in refreshed) {
        for (final EffectiveFormula piece in section.pieces) {
          _controllers[piece.ref]!.text = piece.slot.display;
        }
      }
    });
  }

  Future<void> _save() async {
    if (_hasProblems) return;

    // What actually changed, and how far each change could reach.
    final List<_PendingEdit> pending = <_PendingEdit>[];
    for (final EffectiveSection section in _sections) {
      for (final EffectiveFormula piece in section.pieces) {
        final String typed = _controllers[piece.ref]!.text.trim();
        if (typed == _opened[piece.ref]) continue;
        final FormulaEdit edit = piece.slot.readDisplay(typed);
        if (!edit.isUsable) return;
        pending.add(_PendingEdit(
          ref: piece.ref,
          label: piece.slot.label,
          section: section.section,
          stored: edit.stored!,
          reach: _draft.reachOf(piece.ref, piece.slot.label).length,
        ));
      }
    }
    if (pending.isEmpty) return;

    final int widestReach =
        pending.fold(0, (int most, _PendingEdit edit) => edit.reach > most ? edit.reach : most);

    FormulaEditScope scope = FormulaEditScope.thisConfiguration;
    if (widestReach > 1) {
      final FormulaEditScope? chosen = await _askScope(pending, widestReach);
      if (chosen == null || !mounted) return;
      scope = chosen;
    }

    setState(() => _saving = true);
    int changed = 0;
    for (final _PendingEdit edit in pending) {
      changed += _draft.apply(
        ref: edit.ref,
        label: edit.label,
        storedFormula: edit.stored,
        scope: scope,
      );
    }

    // Both taken now. The screen is about to close, and a messenger or
    // navigator looked up through a closed screen's context is a message
    // nobody sees.
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    await widget.onSaved?.call(_draft.overrides);
    if (!mounted) return;
    setState(() => _saving = false);
    navigator.pop(true);

    final String what = pending.length == 1 ? 'formula' : '${pending.length} formulas';
    final String where = changed > pending.length
        ? ' in ${changed ~/ pending.length} configurations'
        : '';
    messenger.showSnackBar(SnackBar(content: Text('Saved $what$where.')));
  }

  Future<FormulaEditScope?> _askScope(List<_PendingEdit> pending, int reach) {
    return showDialog<FormulaEditScope>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Where should this apply?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                pending.length == 1
                    ? 'The same sum cuts ${pending.first.section} '
                        '${pending.first.label} in $reach configurations of this window.'
                    : 'These sums are shared with other configurations of this window.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              _ScopeOption(
                title: 'Only ${widget.configSummary}',
                detail: 'Other collar types keep the formula they have.',
                onTap: () => Navigator.of(context).pop(FormulaEditScope.thisConfiguration),
              ),
              const SizedBox(height: 8),
              _ScopeOption(
                title: 'Everywhere it matches',
                detail: 'Up to $reach configurations that cut this piece the same way today. '
                    'Any you have already made different are left alone.',
                onTap: () => Navigator.of(context).pop(FormulaEditScope.everywhereItMatches),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String confirmLabel,
  }) async {
    final bool? answer = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return answer ?? false;
  }

  Future<bool> _confirmLeaving() async {
    if (!_hasEdits) return true;
    return _confirm(
      title: 'Leave without saving?',
      body: 'The formulas you changed here will go back to what they were.',
      confirmLabel: 'Leave',
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return PopScope<Object?>(
      canPop: !_hasEdits,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        // Taken before the question is asked: once it is answered this
        // context may be gone, and reaching through it then is how a back
        // button ends up doing nothing.
        final NavigatorState navigator = Navigator.of(context);
        if (await _confirmLeaving() && mounted) {
          navigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('Edit formulas'),
              Text(
                '${widget.windowTitle} · ${widget.configSummary}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.appBarTheme.foregroundColor?.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            IconButton(
              tooltip: 'Put every formula back',
              onPressed: _saving ? null : _resetEverything,
              icon: const Icon(Icons.settings_backup_restore_rounded),
            ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(gradient: AppTheme.pageGradient),
          child: _sections.isEmpty
              ? const _EmptyState()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  children: <Widget>[
                    _Introduction(
                      isFabrication: widget.windowKey.context == 'fabrication',
                      applied: _appliedAutomatically,
                    ),
                    const SizedBox(height: 16),
                    for (final EffectiveSection section in _sections) ...<Widget>[
                      _SectionBlock(
                        section: section,

                        controllerFor: (FormulaPieceRef ref) => _controllers[ref]!,
                        problemFor: (FormulaPieceRef ref) => _problems[ref],
                        previewFor: _preview,
                        isEdited: (FormulaPieceRef ref) =>
                            _controllers[ref]!.text.trim() != _opened[ref],
                        onTyped: _onTyped,
                        onReset: _resetPiece,
                      ),
                      const SizedBox(height: 18),
                    ],
                  ],
                ),
        ),
        bottomNavigationBar: _SaveBar(

          canSave: _hasEdits && !_hasProblems && !_saving,
          saving: _saving,
          problemCount: _problems.length,
          onSave: _save,
        ),
      ),
    );
  }
}

class _PendingEdit {
  const _PendingEdit({
    required this.ref,
    required this.label,
    required this.section,
    required this.stored,
    required this.reach,
  });

  final FormulaPieceRef ref;
  final String label;
  final String section;
  final String stored;
  final int reach;
}

/// Says what this screen is, and the two things about it that are not obvious.
///
/// Somebody opening this is looking at the arithmetic behind their own cutting
/// list, which is not a thing most software shows them. Both notes exist
/// because leaving them out would make a formula look wrong: a workshop that
/// measures in inches would wonder why the numbers are in centimetres, and one
/// that knows its blade takes 2mm would wonder where that went.
class _Introduction extends StatelessWidget {
  const _Introduction({required this.isFabrication, required this.applied});

  final bool isFabrication;

  /// What Quick AL adds after the workshop's own arithmetic, if anything.
  final String? applied;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String unit = isFabrication ? 'centimetres' : 'feet';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.royalBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.royalBlue.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(Icons.functions_rounded, size: 20, color: AppTheme.royalBlue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'These are the sums Quick AL cuts this window by. Change one '
                  'and every cutting list from here on uses yours instead.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textPrimary.withValues(alpha: 0.88),
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: AppTheme.royalBlue.withValues(alpha: 0.16)),
          const SizedBox(height: 11),
          _Note(
            icon: Icons.straighten_rounded,
            text: 'Write in $unit. If you measured this window in inches, '
                'Quick AL converts it before the formula runs.',
          ),
          if (applied != null) ...<Widget>[
            const SizedBox(height: 9),
            _Note(icon: Icons.auto_awesome_rounded, text: applied!),
          ],
        ],
      ),
    );
  }
}

/// One short line of small print, with an icon to hang it on.
class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 15, color: AppTheme.slate),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.slate,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

/// One profile, and every piece cut from it.
class _SectionBlock extends StatelessWidget {
  const _SectionBlock({
    required this.section,
    required this.controllerFor,
    required this.problemFor,
    required this.previewFor,
    required this.isEdited,
    required this.onTyped,
    required this.onReset,
  });

  final EffectiveSection section;
  final TextEditingController Function(FormulaPieceRef) controllerFor;
  final String? Function(FormulaPieceRef) problemFor;
  final String? Function(FormulaPieceRef, FormulaSlot) previewFor;
  final bool Function(FormulaPieceRef) isEdited;
  final void Function(FormulaPieceRef, String) onTyped;
  final Future<void> Function(FormulaPieceRef) onReset;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.deepTeal,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  section.section,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                section.pieces.length == 1 ? '1 piece' : '${section.pieces.length} pieces',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.slate,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: AppTheme.panelGradient,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.line),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppTheme.shadowColor.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: <Widget>[
              for (int i = 0; i < section.pieces.length; i++) ...<Widget>[
                if (i != 0)
                  Divider(height: 1, thickness: 1, color: AppTheme.line.withValues(alpha: 0.7)),
                _PieceRow(
                  piece: section.pieces[i],
                  ordinal: _ordinalWithin(section, i),

                  controller: controllerFor(section.pieces[i].ref),
                  problem: problemFor(section.pieces[i].ref),
                  preview: previewFor(section.pieces[i].ref, section.pieces[i].slot),
                  edited: isEdited(section.pieces[i].ref),
                  onTyped: (String text) => onTyped(section.pieces[i].ref, text),
                  onReset: () => onReset(section.pieces[i].ref),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Which of the same-named pieces this is -- "H (1 of 2)".
  ///
  /// A sliding window takes two M23 uprights, both labelled H, and they can be
  /// given different formulas. Without this the second box looks like a
  /// duplicate of the first.
  String? _ordinalWithin(EffectiveSection section, int index) {
    final String label = section.pieces[index].slot.label;
    final List<int> sameName = <int>[
      for (int i = 0; i < section.pieces.length; i++)
        if (section.pieces[i].slot.label == label) i,
    ];
    if (sameName.length < 2) return null;
    return '${sameName.indexOf(index) + 1} of ${sameName.length}';
  }
}

/// One piece: what it is called, the sum, what the sum means, what it comes to.
class _PieceRow extends StatelessWidget {
  const _PieceRow({
    required this.piece,
    required this.ordinal,
    required this.controller,
    required this.problem,
    required this.preview,
    required this.edited,
    required this.onTyped,
    required this.onReset,
  });

  final EffectiveFormula piece;
  final String? ordinal;
  final TextEditingController controller;
  final String? problem;
  final String? preview;
  final bool edited;
  final ValueChanged<String> onTyped;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool broken = problem != null;
    final bool changed = piece.isWorkshopsOwn || edited;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.royalBlue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: AppTheme.royalBlue.withValues(alpha: 0.22)),
                ),
                child: Text(
                  piece.slot.label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppTheme.royalBlue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (ordinal != null) ...<Widget>[
                const SizedBox(width: 8),
                Text(
                  ordinal!,
                  style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.slate),
                ),
              ],
              const Spacer(),
              if (changed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.amberAccent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'yours',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppTheme.amberAccent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              if (changed)
                IconButton(
                  tooltip: 'Put this one back',
                  visualDensity: VisualDensity.compact,
                  onPressed: onReset,
                  icon: Icon(Icons.undo_rounded, size: 18, color: AppTheme.slate),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            onChanged: onTyped,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            enableSuggestions: false,
            // Arithmetic only. Keeping everything else out of the field is
            // gentler than telling somebody afterwards that they cannot use it.
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_ .+\-*/()]')),
            ],
            // The app's own face rather than a monospace one. A formula here is
            // six or seven symbols, not a program, and the terminal look would
            // sit oddly against every other field in Quick AL. Figures are held
            // to one width and the letters given a little air, which is what
            // monospace was really being asked for: digits that line up and
            // brackets that are easy to pair by eye.
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
              suffixIcon: broken
                  ? const Icon(Icons.error_outline_rounded, size: 18)
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          _Legend(slot: piece.slot),
          if (preview != null) ...<Widget>[
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Icon(Icons.straighten_rounded, size: 15, color: AppTheme.tealAccent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    preview!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.tealAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// What each name in the formula above stands for.
class _Legend extends StatelessWidget {
  const _Legend({required this.slot});

  final FormulaSlot slot;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Map<String, String> lines = slot.legend;
    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: <Widget>[
        for (final MapEntry<String, String> line in lines.entries)
          RichText(
            text: TextSpan(
              style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.slate),
              children: <InlineSpan>[
                TextSpan(
                  text: line.key,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.royalBlue,
                    letterSpacing: 0.3,
                  ),
                ),
                TextSpan(text: ' = ${line.value}'),
              ],
            ),
          ),
      ],
    );
  }
}

class _ScopeOption extends StatelessWidget {
  const _ScopeOption({required this.title, required this.detail, required this.onTap});

  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: AppTheme.royalBlue.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.royalBlue,
                ),
              ),
              const SizedBox(height: 3),
              Text(detail, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.canSave,
    required this.saving,
    required this.problemCount,
    required this.onSave,
  });

  final bool canSave;
  final bool saving;
  final int problemCount;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (problemCount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                problemCount == 1
                    ? 'One formula cannot be used yet.'
                    : '$problemCount formulas cannot be used yet.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: canSave ? onSave : null,
              icon: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(saving ? 'Saving...' : 'Save formulas'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();


  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.functions_rounded, size: 44, color: AppTheme.slate),
            const SizedBox(height: 14),
            Text(
              'No formulas for this window yet',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Pick a collar type and the settings this window is built with, '
              'and its formulas will be here.',
              style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.slate),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
