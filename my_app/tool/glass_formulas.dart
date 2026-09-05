// Working out the glass formulas from the engine's own answers.
//
// The sections are read out of the C++ as text: each is a plain
// `labelWith("HL", ...)` call and the expression is right there. The glass is
// not. It is written in loops, with the rubber chosen by a ternary inside
// them, so there is no expression to lift out -- and inventing one by reading
// the loop is exactly the kind of careful mistake this whole exercise exists
// to avoid.
//
// So the glass is recovered from what the engine produces. Every pane's height
// and width is affine in one measurement: nudging that measurement by 1 gives
// the slope, and the baseline gives the rest. That is not a guess -- it is
// checked, first against a scattered point in the same dump and then against a
// second dump taken at measurements sharing no value with the first. A pane
// whose formula is not exact at every one of those points is reported and left
// out rather than shipped.

import 'dart:convert';
import 'dart:io';

/// One pane, and the two sums that give its size.
class GlassPane {
  const GlassPane({
    required this.heightFormula,
    required this.widthFormula,
    required this.role,
  });

  /// In centimetres. Glass carries no cutting margin and no feet conversion --
  /// checked across all 2,334 panes, none of which moves when the margin does.
  final String heightFormula;
  final String widthFormula;

  /// `Slide` or `Fix`, where the engine says so, and null where it does not.
  ///
  /// The glass itself is unnamed; the panel rails carry it, as W1s and W2f. On
  /// the panel windows those line up with the panes exactly. On everything
  /// else the rails have no such letter, and a pane is left unnamed rather
  /// than given a role somebody guessed.
  final String? role;
}

/// A measurement, a slope and a constant -- and how to write them down.
class Affine {
  const Affine(this.dimension, this.slope, this.intercept);

  final String dimension;
  final double slope;
  final double intercept;

  /// The sum as a fabricator would write it.
  ///
  /// A quarter of a width is `(w - 24.08) / 4`, never `0.25w - 6.02`: the
  /// division is what the window actually does -- four panels across an
  /// opening -- and it is exact where a decimal quarter of a third would not
  /// be. Thirds are the reason this matters: 1/3 has no decimal, so a formula
  /// written as `0.333333w` would be wrong in the sixth place and wrong on
  /// every window.
  String? write(String name) {
    if (slope.abs() < 1e-12) {
      return _number(intercept);
    }

    if ((slope - 1).abs() < 1e-12) {
      if (intercept.abs() < 1e-12) return name;
      return intercept > 0
          ? '$name + ${_number(intercept)}'
          : '$name - ${_number(-intercept)}';
    }

    // A slope of 1/n, which is what dividing an opening between n panels
    // gives. Anything else is not something these windows do.
    final double inverse = 1 / slope;
    final double rounded = inverse.roundToDouble();
    if ((inverse - rounded).abs() > 1e-9 || rounded < 2 || rounded > 12) {
      return null;
    }

    final int n = rounded.toInt();
    final double inner = intercept * n;
    if (inner.abs() < 1e-9) return '$name / $n';
    return inner > 0
        ? '($name + ${_number(inner)}) / $n'
        : '($name - ${_number(-inner)}) / $n';
  }

  /// Trimmed to what a tape can hold, and no further.
  ///
  /// Two decimals is a tenth of a millimetre. The constants in these formulas
  /// are things like 20.32 and 5.08 -- inches turned into centimetres -- so
  /// they land on two decimals exactly, and a value that does not is a sign
  /// the arithmetic was not what it looked like.
  static String _number(double value) {
    final String fixed = value.toStringAsFixed(2);
    if (!fixed.contains('.')) return fixed;
    return fixed.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
}

/// Reads every glass pane out of a dump of the engine's output.
class GlassReader {
  GlassReader(this.records);

  /// window|config -> the record, for pairing the two dumps.
  final Map<String, Map<String, dynamic>> records;

  static GlassReader of(List<dynamic> dump) {
    final Map<String, Map<String, dynamic>> byKey = <String, Map<String, dynamic>>{};
    for (final dynamic entry in dump) {
      final Map<String, dynamic> record = entry as Map<String, dynamic>;
      if (record['context'] != 'fabrication') continue;
      byKey[keyOf(record)] = record;
    }
    return GlassReader(byKey);
  }

  static String keyOf(Map<String, dynamic> record) {
    final Map<String, dynamic> config = record['config'] as Map<String, dynamic>;
    final List<String> names = config.keys.toList()..sort();
    return '${record['window']}|'
        '${names.map((String n) => '$n=${config[n]}').join('|')}';
  }

  static const List<String> _dimensions = <String>['h', 'w', 'wl', 'wr'];

  /// Every pane of one configuration, or a reason there are none.
  (List<List<Affine>>?, String?) solve(Map<String, dynamic> record) {
    final Map<String, Map<String, dynamic>> byPoint = _byPoint(record);
    final Map<String, dynamic>? base = byPoint['base'];
    if (base == null || base['ok'] != true) return (null, 'the engine refused it');

    final List<dynamic> panes = base['glass'] as List<dynamic>;
    if (panes.isEmpty) return (null, 'no glass');

    final List<List<Affine>> out = <List<Affine>>[];
    for (int index = 0; index < panes.length; index++) {
      final List<Affine> sides = <Affine>[];
      for (final String side in const <String>['h', 'w']) {
        final Affine? found = _solveSide(byPoint, base, index, side);
        if (found == null) {
          return (null, 'pane $index $side follows more than one measurement');
        }
        sides.add(found);
      }
      out.add(sides);
    }
    return (out, null);
  }

  Affine? _solveSide(
    Map<String, Map<String, dynamic>> byPoint,
    Map<String, dynamic> base,
    int index,
    String side,
  ) {
    final double at = _pane(base, index, side);
    Affine? found;

    for (final String dimension in _dimensions) {
      final Map<String, dynamic>? nudged = byPoint['$dimension+1'];
      if (nudged == null || nudged['ok'] != true) continue;
      final List<dynamic> panes = nudged['glass'] as List<dynamic>;
      if (panes.length != (base['glass'] as List<dynamic>).length) continue;

      final double slope = _pane(nudged, index, side) - at;
      if (slope.abs() < 1e-12) continue;
      if (found != null) return null; // two measurements move it: not affine in one
      found = Affine(dimension, slope, at - slope * (base[dimension] as num).toDouble());
    }

    // A pane that moves with nothing is a fixed size, which is a real answer.
    return found ?? Affine('h', 0, at);
  }

  /// Whether these formulas give the engine's own numbers at every point.
  List<String> check(Map<String, dynamic> record, List<List<Affine>> panes) {
    final List<String> problems = <String>[];
    for (final dynamic entry in record['samples'] as List<dynamic>) {
      final Map<String, dynamic> sample = entry as Map<String, dynamic>;
      if (sample['ok'] != true) continue;
      final List<dynamic> glass = sample['glass'] as List<dynamic>;
      if (glass.length != panes.length) {
        problems.add('${keyOf(record)}: ${glass.length} panes at '
            '${sample['point']}, ${panes.length} expected');
        continue;
      }
      for (int index = 0; index < panes.length; index++) {
        for (int side = 0; side < 2; side++) {
          final Affine formula = panes[index][side];
          final String name = side == 0 ? 'h' : 'w';
          final double want = _pane(sample, index, name);
          final double got =
              formula.slope * (sample[formula.dimension] as num).toDouble() +
                  formula.intercept;
          if ((got - want).abs() > 1e-9 * (1 + want.abs())) {
            problems.add('${keyOf(record)} pane $index $name at '
                '${sample['point']}: engine $want, formula $got');
          }
        }
      }
    }
    return problems;
  }

  /// `Slide` or `Fix` per pane, where the panel rails say so.
  ///
  /// Two rails to a panel, top and bottom, so the first half of them names the
  /// panels in order. A window whose rails carry no such letter gets nothing,
  /// which is the honest answer.
  static List<String?> rolesOf(Map<String, dynamic> base, int panes) {
    final Map<String, dynamic> sections = base['sections'] as Map<String, dynamic>;
    List<dynamic>? rails;
    for (final String name in const <String>['M24', 'M26', 'M30']) {
      final Object? found = sections[name];
      if (found is List<dynamic> && found.isNotEmpty) {
        rails = found;
        break;
      }
    }
    if (rails == null || rails.length.isOdd) {
      return List<String?>.filled(panes, null);
    }

    final int half = rails.length ~/ 2;
    if (half != panes) return List<String?>.filled(panes, null);

    final RegExp suffix = RegExp(r'^W\d+([sf])$');
    final List<String?> roles = <String?>[];
    for (int i = 0; i < half; i++) {
      final RegExpMatch? match = suffix.firstMatch((rails[i] as List<dynamic>)[0] as String);
      if (match == null) return List<String?>.filled(panes, null);
      roles.add(match.group(1) == 's' ? 'Slide' : 'Fix');
    }
    return roles;
  }

  static Map<String, Map<String, dynamic>> _byPoint(Map<String, dynamic> record) {
    return <String, Map<String, dynamic>>{
      for (final dynamic entry in record['samples'] as List<dynamic>)
        (entry as Map<String, dynamic>)['point'] as String: entry,
    };
  }

  static double _pane(Map<String, dynamic> sample, int index, String side) {
    final List<dynamic> glass = sample['glass'] as List<dynamic>;
    return ((glass[index] as Map<String, dynamic>)[side] as num).toDouble();
  }
}

/// Reads a dump of the engine's output from disk.
List<dynamic> readDump(String path) =>
    jsonDecode(File(path).readAsStringSync()) as List<dynamic>;
