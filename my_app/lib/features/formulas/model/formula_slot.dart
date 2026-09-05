/// One cut piece and the sum that decides its length.
library;

import 'formula_expression.dart';

/// The measurements a formula can be written in terms of.
///
/// Two names for the same thing on purpose: the catalogue stores `h` and `w`
/// because that is what the engine calls them and what every window shares,
/// while a fabricator reads the piece's own label. A piece marked HL on the
/// bench should say HL on the screen.
class FormulaVariables {
  const FormulaVariables._();

  /// The window measurements, as the catalogue stores them.
  static const String height = 'h';
  static const String width = 'w';
  static const String leftWidth = 'wl';
  static const String rightWidth = 'wr';
  static const String arch = 'ar';

  /// Every measurement a piece's length can be driven by. Each formula reads
  /// exactly one of these -- that is what makes it possible to show the piece's
  /// own label in its place.
  static const Set<String> dimensions = <String>{height, width, leftWidth, rightWidth, arch};

  /// The cutting margin, as a fabricator knows it.
  static const String margin = 'cm';

  /// Centimetres in a foot. Fabrication measures in centimetres and cuts in
  /// feet, so this appears at the end of nearly every one of its formulas.
  static const String feet = 'feet';

  /// What each measurement is, said plainly, for the line under a formula box.
  static String describe(String name, {required bool isFabrication}) {
    final String unit = isFabrication ? 'cm' : 'ft';
    switch (name) {
      case height:
        return 'window height ($unit)';
      case width:
        return 'window width ($unit)';
      case leftWidth:
        return 'left width ($unit)';
      case rightWidth:
        return 'right width ($unit)';
      case arch:
        return 'arch height ($unit)';
      case margin:
        return 'cutting margin';
      case feet:
        return 'centimetres in a foot (30.48)';
    }
    return name;
  }
}

/// A piece of aluminium, and the arithmetic that gives its length.
///
/// The formula is held twice over: as the catalogue stores it, in the engine's
/// names, and as a fabricator reads it, in the piece's own. Both are the same
/// arithmetic -- only the names differ -- and every conversion between them
/// goes through the parser rather than a search and replace.
class FormulaSlot {
  FormulaSlot({
    required this.section,
    required this.label,
    required this.stored,
    required this.isFabrication,
    this.measuresInCentimetres = false,
  });

  /// Whether this formula's answer is a length in centimetres rather than feet.
  ///
  /// True for glass and nothing else. Aluminium is worked out in centimetres
  /// and divided by 30.48 on the way out, because the next screen packs it into
  /// stock bars measured in feet. Glass is not packed into anything: it is
  /// scored across a sheet, and the number a cutter wants is centimetres from
  /// end to end. Reading one as the other would show a 88cm pane as 88 feet.
  final bool measuresInCentimetres;

  /// The profile this piece is cut from -- "DC30C".
  final String section;

  /// What the piece is called on the cutting list -- "HL", "WT", "W1s".
  final String label;

  /// The formula in the catalogue's own names: `(h + cm) / feet`.
  final String stored;

  /// Fabrication measures in centimetres and divides by feet; estimation works
  /// in feet already. It changes what the legend under a box should say.
  final bool isFabrication;

  FormulaExpression? _parsed;
  FormulaExpression get expression => _parsed ??= FormulaExpression.parse(stored);

  /// The measurement this piece's length is driven by -- `h`, `w`, `wl`, `wr`
  /// or `ar`. Every formula in the catalogue reads exactly one.
  String get dimension {
    final Iterable<String> found =
        expression.variables.where(FormulaVariables.dimensions.contains);
    return found.isEmpty ? FormulaVariables.height : found.first;
  }

  /// The cutting margin this formula reads.
  ///
  /// Fabrication has one margin and calls it `cm`. Estimation keeps one per
  /// section and names it after the section -- and not always this piece's own
  /// section, which is why it is read off the formula rather than assumed.
  String? get marginName {
    for (final String name in expression.variables) {
      if (name == FormulaVariables.margin) return name;
      if (name.startsWith('cm_')) return name;
    }
    return null;
  }

  /// The two things every formula ends with, and which are not arithmetic a
  /// fabricator chose.
  ///
  /// Nearly every stored formula is `(something + cm) / feet`, or on the
  /// estimation side `something + cm_SECTION`. Neither tail is part of what a
  /// workshop decided: the margin is one blade width, set once in settings and
  /// added to every cut alike, and the division by 30.48 only turns
  /// centimetres into the feet the next screen works in. Showing them puts two
  /// names in every box that a fabricator can neither change usefully nor
  /// ignore safely, so they are taken off on the way to the screen and put
  /// back on the way in.
  ///
  /// Null when a formula has neither -- the round arch's `ar + 1` is the one
  /// such formula in the catalogue -- and then what is stored is what is shown.
  _Envelope? get _envelope => __envelope ??= _Envelope.around(expression, marginName);
  _Envelope? __envelope;

  /// Just the arithmetic, with the margin and the feet conversion set aside.
  FormulaExpression get _core => _envelope?.core ?? expression;

  /// How the names change on the way to the screen: the driving measurement
  /// becomes the piece's own label.
  Map<String, String> get _toDisplay => <String, String>{dimension: label};

  Map<String, String> get _toStored => <String, String>{label: dimension};

  /// The formula as a fabricator reads it: `HL + 6`, not `(h + 6 + cm) / feet`.
  String get display => _core.renameVariables(_toDisplay).toString();

  /// The names this piece's formula may use, in display terms.
  ///
  /// Its own, and nothing else. A formula that could name the margin would
  /// invite somebody to add it twice.
  Set<String> get allowedDisplayVariables => <String>{label};

  /// What that name means, for the line under the box.
  Map<String, String> get legend {
    return <String, String>{
      label: FormulaVariables.describe(dimension, isFabrication: isFabrication),
    };
  }

  /// Whether Quick AL wraps anything around this formula's own arithmetic.
  ///
  /// False for the one formula in the catalogue that has no margin and no
  /// conversion -- the round arch's rib -- where what is stored is what is
  /// shown. The wording for the rest is the screen's business, not this
  /// class's: what belongs here is only whether there is anything to say.
  bool get hasHiddenEnvelope => _envelope != null;

  /// Reads what a fabricator typed and turns it back into the catalogue's
  /// names, or says why it cannot.
  FormulaEdit readDisplay(String typed) {
    final FormulaCheck check =
        FormulaCheck.of(typed, allowedVariables: allowedDisplayVariables);
    if (!check.isUsable) {
      return FormulaEdit._(null, check.problem);
    }

    final FormulaExpression core = check.expression!.renameVariables(_toStored);
    final _Envelope? envelope = _envelope;
    final FormulaExpression whole = envelope == null ? core : envelope.rebuild(core);
    return FormulaEdit._(whole.toString(), null);
  }

  /// The same piece with a different formula behind it.
  FormulaSlot withStored(String formula) {
    return FormulaSlot(
      section: section,
      label: label,
      stored: formula,
      isFabrication: isFabrication,
      measuresInCentimetres: measuresInCentimetres,
    );
  }

  /// This piece's length, given the window's measurements.
  ///
  /// [variables] is in the catalogue's names -- h, w, cm and the rest -- so a
  /// caller works in one set of names throughout and only the screen sees the
  /// other. This is the length that goes to the optimizer: the cutting margin
  /// is in it, because the optimizer needs the blade's own width accounted for
  /// when it decides what fits on a bar.
  FormulaResult lengthFor(Map<String, double> variables) {
    return FormulaResult.of(expression, variables, label: '$section $label');
  }

  /// The size that will actually be cut, as the cutting list shows it.
  ///
  /// Not the same number as [lengthFor], and the difference matters more than
  /// its size. The cutting margin exists so the optimizer can leave the blade
  /// room between pieces; the fabrication cutting list takes it off again
  /// before anybody reads a size off it. Somebody adjusting a formula is
  /// working from the size they will cut, and showing them a number with the
  /// margin still in would invite them to correct for an allowance that is not
  /// really there -- and a formula wrong by one blade width is wrong on every
  /// piece of every job after it.
  ///
  /// The estimation side keeps its margin in the figures it shows, because
  /// there the margin is an allowance on what to buy rather than where to cut.
  /// This follows whichever the report does, so what is shown here and what is
  /// shown there are the same number.
  FormulaResult cutLengthFor(Map<String, double> variables) {
    if (!isFabrication) return lengthFor(variables);

    final String? margin = marginName;
    if (margin == null) return lengthFor(variables);

    // Setting the margin to nothing is exactly what the report does when it
    // subtracts it: (core + cm) / feet, less cm / feet, is core / feet.
    final Map<String, double> withoutMargin = Map<String, double>.of(variables);
    withoutMargin[margin] = 0;
    return FormulaResult.of(expression, withoutMargin, label: '$section $label');
  }
}

/// The margin and the unit conversion wrapped around a formula's real work.
///
/// Recognised by shape rather than by text, and only in the exact shape the
/// engine writes: the margin as the last thing added, the division by feet as
/// the last thing done. Anything else is left alone and shown whole, because a
/// formula this cannot take apart is one it must not put back together either.
class _Envelope {
  const _Envelope({
    required this.core,
    required this.marginName,
    required this.dividesByFeet,
  });

  /// The arithmetic a fabricator actually chose.
  final FormulaExpression core;

  /// The margin that gets added -- `cm`, or `cm_DC30C` on the estimation side.
  final String marginName;

  /// Whether the result is turned from centimetres into feet.
  final bool dividesByFeet;

  /// Finds the envelope around [whole], or null if it is not in this shape.
  static _Envelope? around(FormulaExpression whole, String? marginName) {
    if (marginName == null) return null;

    FormulaExpression inner = whole;
    bool dividesByFeet = false;

    // ... / feet
    if (inner is FormulaBinary &&
        inner.op == '/' &&
        inner.right is FormulaVariable &&
        (inner.right as FormulaVariable).name == FormulaVariables.feet) {
      dividesByFeet = true;
      inner = inner.left;
    }

    // ... + cm
    if (inner is FormulaBinary &&
        inner.op == '+' &&
        inner.right is FormulaVariable &&
        (inner.right as FormulaVariable).name == marginName) {
      return _Envelope(
        core: inner.left,
        marginName: marginName,
        dividesByFeet: dividesByFeet,
      );
    }

    return null;
  }

  /// Puts the same envelope back around a new core.
  FormulaExpression rebuild(FormulaExpression core) {
    final FormulaExpression withMargin =
        FormulaBinary('+', core, FormulaVariable(marginName));
    if (!dividesByFeet) return withMargin;
    return FormulaBinary('/', withMargin, const FormulaVariable(FormulaVariables.feet));
  }
}

/// What came of reading an edited formula.
class FormulaEdit {
  const FormulaEdit._(this.stored, this.problem);

  /// The formula in the catalogue's names, ready to save.
  final String? stored;

  /// Why it cannot be saved, said to a fabricator.
  final String? problem;

  bool get isUsable => stored != null;
}
