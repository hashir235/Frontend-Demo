/// What this workshop actually cuts to: the shipped formulas, with their own
/// changes on top.
library;

import '../model/formula_slot.dart';
import '../model/formula_window_key.dart';
import 'formula_catalogue.dart';
import 'formula_overrides_store.dart';

/// How widely a change should reach.
enum FormulaEditScope {
  /// Only the window configuration that is open.
  thisConfiguration,

  /// Every configuration of this window that cuts the same piece by the same
  /// sum today -- usually all fourteen collar types.
  everywhereItMatches,
}

/// One piece, and where its formula came from.
class EffectiveFormula {
  const EffectiveFormula(this.slot, this.ref, {required this.isWorkshopsOwn});

  final FormulaSlot slot;
  final FormulaPieceRef ref;

  /// True when this workshop changed it, false when it is what Quick AL ships.
  final bool isWorkshopsOwn;
}

/// One profile's pieces, as this workshop cuts them.
class EffectiveSection {
  const EffectiveSection(this.section, this.pieces);

  final String section;
  final List<EffectiveFormula> pieces;

  bool get hasWorkshopChanges =>
      pieces.any((EffectiveFormula piece) => piece.isWorkshopsOwn);
}

/// The formulas in force, and the only thing that should ever be cut to.
///
/// Everything that needs a length -- the formula screen, the cutting list, the
/// material table -- asks this rather than the catalogue, so a workshop's own
/// arithmetic cannot be honoured in one place and forgotten in another.
class FormulaBook {
  FormulaBook(this.catalogue, this.overrides);

  final FormulaCatalogue catalogue;
  final FormulaOverrides overrides;

  /// This window's pieces, with the workshop's own formulas where they have
  /// set one. Null when the catalogue has nothing for this configuration.
  List<EffectiveSection>? sectionsFor(FormulaWindowKey key) {
    final List<SectionFormulas>? shipped = catalogue.shippedFor(key);
    if (shipped == null) return null;

    return <EffectiveSection>[
      for (final SectionFormulas section in shipped)
        EffectiveSection(section.section, <EffectiveFormula>[
          for (int i = 0; i < section.pieces.length; i++) _effective(key, section, i),
        ]),
    ];
  }

  EffectiveFormula _effective(FormulaWindowKey key, SectionFormulas section, int index) {
    final FormulaSlot shipped = section.pieces[index];
    final FormulaPieceRef ref = FormulaPieceRef.of(key, section.section, index);
    final String? own = overrides.formulaFor(ref);
    if (own == null) {
      return EffectiveFormula(shipped, ref, isWorkshopsOwn: false);
    }
    return EffectiveFormula(shipped.withStored(own), ref, isWorkshopsOwn: true);
  }

  /// What Quick AL ships for this piece, whatever the workshop has since made
  /// of it. This is what "reset" goes back to.
  String? shippedFormulaFor(FormulaPieceRef ref) {
    return catalogue.shippedFormulaAt(ref.windowKey, ref.configKey, ref.section, ref.index);
  }

  /// Everywhere a change to this piece could also apply.
  ///
  /// Only configurations that cut it by the same sum today, so a collar type
  /// somebody has already made different is never quietly overwritten. The
  /// configuration being edited is included.
  List<FormulaPieceRef> reachOf(FormulaPieceRef ref, String label) {
    final String? shipped = shippedFormulaFor(ref);
    if (shipped == null) return <FormulaPieceRef>[ref];

    final List<String> configs = catalogue.configsSharing(
      windowKey: ref.windowKey,
      section: ref.section,
      index: ref.index,
      label: label,
      formula: shipped,
    );

    return <FormulaPieceRef>[
      for (final String configKey in configs)
        FormulaPieceRef(
          windowKey: ref.windowKey,
          configKey: configKey,
          section: ref.section,
          index: ref.index,
        ),
    ];
  }

  /// Records a workshop's own formula for a piece, and for everywhere else it
  /// applies if they asked for that.
  ///
  /// Returns how many pieces were changed, so the screen can say so plainly --
  /// "changed in 14 collar types" is the difference between a change someone
  /// meant and one they did not.
  int apply({
    required FormulaPieceRef ref,
    required String label,
    required String storedFormula,
    required FormulaEditScope scope,
  }) {
    final List<FormulaPieceRef> targets = scope == FormulaEditScope.thisConfiguration
        ? <FormulaPieceRef>[ref]
        : reachOf(ref, label);

    for (final FormulaPieceRef target in targets) {
      overrides.set(target, storedFormula);
    }
    return targets.length;
  }

  /// Puts a piece back to what Quick AL ships, everywhere the workshop had
  /// changed it to the same thing.
  int reset({
    required FormulaPieceRef ref,
    required String label,
    required FormulaEditScope scope,
  }) {
    final List<FormulaPieceRef> targets = scope == FormulaEditScope.thisConfiguration
        ? <FormulaPieceRef>[ref]
        : reachOf(ref, label);

    int cleared = 0;
    for (final FormulaPieceRef target in targets) {
      if (overrides.hasChanged(target)) cleared++;
      overrides.clear(target);
    }
    return cleared;
  }

  /// Puts every piece of one window configuration back to what Quick AL ships.
  void resetConfiguration(FormulaWindowKey key) => overrides.clearConfig(key);

  FormulaBook copy() => FormulaBook(catalogue, overrides.copy());
}
