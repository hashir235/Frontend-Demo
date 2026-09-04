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
  });

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

  /// How the names change on the way to the screen: the driving measurement
  /// becomes the piece's own label, and whichever margin this formula reads
  /// becomes plain `cm`.
  Map<String, String> get _toDisplay {
    final Map<String, String> names = <String, String>{dimension: label};
    final String? margin = marginName;
    if (margin != null && margin != FormulaVariables.margin) {
      names[margin] = FormulaVariables.margin;
    }
    return names;
  }

  Map<String, String> get _toStored {
    return _toDisplay.map((String from, String to) => MapEntry<String, String>(to, from));
  }

  /// The formula as a fabricator reads it: `(HL + cm) / feet`.
  String get display => expression.renameVariables(_toDisplay).toString();

  /// The names this piece's formula may use, in display terms.
  Set<String> get allowedDisplayVariables {
    return <String>{
      label,
      FormulaVariables.margin,
      if (isFabrication) FormulaVariables.feet,
    };
  }

  /// What each of those names means, for the legend under the box.
  Map<String, String> get legend {
    final Map<String, String> lines = <String, String>{
      label: FormulaVariables.describe(dimension, isFabrication: isFabrication),
      FormulaVariables.margin: FormulaVariables.describe(
        FormulaVariables.margin,
        isFabrication: isFabrication,
      ),
    };
    if (isFabrication) {
      lines[FormulaVariables.feet] =
          FormulaVariables.describe(FormulaVariables.feet, isFabrication: isFabrication);
    }
    return lines;
  }

  /// Reads what a fabricator typed and turns it back into the catalogue's
  /// names, or says why it cannot.
  FormulaEdit readDisplay(String typed) {
    final FormulaCheck check =
        FormulaCheck.of(typed, allowedVariables: allowedDisplayVariables);
    if (!check.isUsable) {
      return FormulaEdit._(null, check.problem);
    }
    final String storedForm = check.expression!.renameVariables(_toStored).toString();
    return FormulaEdit._(storedForm, null);
  }

  /// The same piece with a different formula behind it.
  FormulaSlot withStored(String formula) {
    return FormulaSlot(
      section: section,
      label: label,
      stored: formula,
      isFabrication: isFabrication,
    );
  }

  /// This piece's length, given the window's measurements.
  ///
  /// [variables] is in the catalogue's names -- h, w, cm and the rest -- so a
  /// caller works in one set of names throughout and only the screen sees the
  /// other.
  FormulaResult lengthFor(Map<String, double> variables) {
    return FormulaResult.of(expression, variables, label: '$section $label');
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
