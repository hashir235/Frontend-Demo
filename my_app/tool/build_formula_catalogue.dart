// Builds the formula catalogue the app ships with, and proves it.
//
// The catalogue has to hold exactly the arithmetic the engine has always used.
// Copying it across by hand would be a thousand chances to mistype a decimal
// point, and a mistyped decimal point here is metal cut wrong. So the
// catalogue is assembled from two independent sources that have to agree:
//
//   * what the engine COMPUTES -- a dump of every window configuration at
//     seven sample points, produced by apps/formula_dump on the server, from
//     the same source files the API is built from;
//   * what the engine SAYS -- the `labelWith("HL", ...)` expressions read out
//     of the C++ text, with no attempt to follow the branches around them.
//
// Neither is trusted alone. Every piece the engine produced is matched to the
// expression that reproduces it at every sample point, including one scattered
// point that no combination of the others can reach. A piece with no matching
// expression, or with two that disagree, is reported and not written -- the
// catalogue is only as good as the part of it that was proved, and a gap that
// is known about is worth more than one that is papered over.
//
// Run from the app root:
//   dart run tool/build_formula_catalogue.dart <ground_truth.json> <quick_al_root>

import 'dart:convert';
import 'dart:io';

import 'package:my_app/features/formulas/model/formula_expression.dart';

import 'glass_formulas.dart';

/// Centimetres in a foot, as the engine spells it.
const double kFeet = 30.48;

/// How close a candidate has to come to the engine's own number.
///
/// The two travel different roads to get here -- the engine's went through a
/// printf and back -- so they are not going to agree bit for bit. A ten-
/// billionth of a foot is far below anything a saw can hold and far above the
/// noise of that round trip.
const double kTolerance = 1e-10;

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('usage: dart run tool/build_formula_catalogue.dart '
        '<ground_truth.json> <quick_al_root> [output.json]');
    exit(2);
  }

  final File truthFile = File(args[0]);
  final Directory root = Directory(args[1]);
  final String outputPath = args.length > 2 ? args[2] : 'assets/formulas/catalogue.json';

  // A second dump, taken at measurements sharing no value with the first. The
  // glass formulas are recovered from numbers rather than read from source, so
  // they are held against a set they were never fitted to before they ship.
  final String? altPath = args.length > 3 ? args[3] : null;

  if (!truthFile.existsSync()) {
    stderr.writeln('No ground truth at ${truthFile.path}');
    exit(2);
  }

  stdout.writeln('Reading the engine\'s own numbers...');
  final List<dynamic> records = jsonDecode(truthFile.readAsStringSync()) as List<dynamic>;
  stdout.writeln('  ${records.length} configurations');

  stdout.writeln('Reading the expressions out of the C++...');
  final _SourceIndex sources = _SourceIndex.load(root);
  stdout.writeln('  ${sources.totalExpressions} expressions across ${sources.fileCount} files');

  final _Builder builder = _Builder(sources);
  for (final dynamic record in records) {
    builder.take(record as Map<String, dynamic>);
  }

  builder.report();

  stdout.writeln('\nWorking the glass out of the engine\'s own answers...');
  final int glassProblems = builder.takeGlass(records, altPath);

  if (builder.unmatched.isNotEmpty ||
      builder.rewritten.isNotEmpty ||
      glassProblems > 0) {
    stderr.writeln('\nRefusing to write a catalogue with unproved formulas in it.');
    exit(1);
  }

  final File output = File(outputPath);
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(builder.catalogue()));
  final int bytes = output.lengthSync();
  stdout.writeln('\nWrote ${output.path} (${(bytes / 1024).toStringAsFixed(0)} KB)');
}

// ---------------------------------------------------------------------------
// The expressions, read out of the source
// ---------------------------------------------------------------------------

/// One `labelWith("HL", <expression>)` found in the C++.
class _Candidate {
  _Candidate(this.label, this.source, this.file, this.line);

  final String label;

  /// The expression exactly as it is written in the engine, brackets and all.
  final String source;

  final String file;
  final int line;

  FormulaExpression? _parsed;
  bool _parseFailed = false;

  FormulaExpression? get parsed {
    if (_parsed != null || _parseFailed) return _parsed;
    _parsed = FormulaExpression.tryParse(source);
    if (_parsed == null) _parseFailed = true;
    return _parsed;
  }

  /// This expression with every shorthand local written out in full.
  ///
  /// The engine defines a handful of locals -- `half`, `d50Height` and the
  /// like -- and some of them differ by configuration. A formula that still
  /// mentions one is no use to anybody: the app cannot evaluate it and a
  /// fabricator cannot read it. Each is substituted, in brackets so it keeps
  /// its own precedence, until none are left.
  _Candidate expandedFor(
    List<_Local> locals,
    Map<String, String> config,
    String? Function(_Local, Map<String, String>) resolve,
  ) {
    if (locals.isEmpty) return this;

    String text = source;
    // Locals never nest more than a step or two; the bound is only here so a
    // definition that somehow referred to itself cannot spin forever.
    for (int pass = 0; pass < 8; pass++) {
      String next = text;
      for (final _Local local in locals) {
        if (!RegExp('\\b${RegExp.escape(local.name)}\\b').hasMatch(next)) continue;
        final String? replacement = resolve(local, config);
        if (replacement == null) continue;
        next = next.replaceAll(
          RegExp('\\b${RegExp.escape(local.name)}\\b'),
          '($replacement)',
        );
      }
      if (next == text) break;
      text = next;
    }

    if (text == source) return this;
    return _Candidate(label, text, file, line);
  }
}

/// A `const double name = ...;` the formulas lean on, and the condition that
/// decides it when there is one.
class _Local {
  _Local(this.name, this.whenTrue, this.whenFalse, this.condition);

  final String name;
  final String whenTrue;

  /// Null when the local is not a choice at all, just a value.
  final String? whenFalse;

  /// The name of the boolean that chooses, or null for an unconditional local.
  final String? condition;
}

class _SourceIndex {
  _SourceIndex(this._byWindow, this._localsByWindow);

  /// "fabrication/S_win" -> every expression in that file.
  final Map<String, List<_Candidate>> _byWindow;

  /// "fabrication/D_win" -> the locals its formulas refer to.
  final Map<String, List<_Local>> _localsByWindow;

  int get fileCount => _byWindow.length;
  int get totalExpressions => _byWindow.values.fold(0, (int sum, List<_Candidate> l) => sum + l.length);

  List<_Candidate> forWindow(String context, String window) {
    return _byWindow['$context/$window'] ?? const <_Candidate>[];
  }

  List<_Local> localsFor(String context, String window) {
    return _localsByWindow['$context/$window'] ?? const <_Local>[];
  }

  static _SourceIndex load(Directory root) {
    final Map<String, List<_Candidate>> byWindow = <String, List<_Candidate>>{};
    final Map<String, List<_Local>> localsByWindow = <String, List<_Local>>{};

    for (final String context in const <String>['estimation', 'fabrication']) {
      final Directory dir = Directory('${root.path}/windows/$context');
      if (!dir.existsSync()) {
        stderr.writeln('No such directory: ${dir.path}');
        exit(2);
      }
      for (final FileSystemEntity entity in dir.listSync()) {
        if (entity is! File || !entity.path.endsWith('.cpp')) continue;
        final String base = entity.uri.pathSegments.last;
        // S_Win_f.cpp -> S_win ; matches the name the dump uses.
        final String window = '${base.split('_').first}_win';
        final String key = '$context/$window';
        final String text = entity.readAsStringSync();
        byWindow[key] = _extractCandidates(text, base);
        localsByWindow[key] = _extractLocals(text);
      }
    }

    return _SourceIndex(byWindow, localsByWindow);
  }

  /// Pulls every `labelWith("X", <expr>)` out of the text.
  ///
  /// No branches are followed and no structure is assumed: whether a given
  /// expression belongs to collar 2 or collar 13 is settled later, by which
  /// numbers it reproduces. That is the whole point -- reading the branches
  /// is exactly the step that could go wrong quietly.
  static List<_Candidate> _extractCandidates(String text, String file) {
    final List<_Candidate> found = <_Candidate>[];
    final RegExp head = RegExp(r'labelWith\(\s*"([^"]*)"\s*,');

    for (final RegExpMatch match in head.allMatches(text)) {
      final String label = match.group(1)!;
      final int exprStart = match.end;
      // Scan to the bracket that closes labelWith itself, so a nested
      // expression keeps all of its own brackets.
      int depth = 1;
      int i = exprStart;
      while (i < text.length && depth > 0) {
        final String c = text[i];
        if (c == '(') {
          depth++;
        } else if (c == ')') {
          depth--;
          if (depth == 0) break;
        }
        i++;
      }
      if (depth != 0) continue;

      final String raw = text.substring(exprStart, i).trim();
      final int line = '\n'.allMatches(text.substring(0, match.start)).length + 1;
      found.add(_Candidate(label, _tidy(raw), file, line));
    }
    return found;
  }

  /// Strips the comments that sit inside some expressions and squeezes the
  /// whitespace, without touching the arithmetic.
  static String _tidy(String raw) {
    String text = raw.replaceAll(RegExp(r'//[^\n]*'), ' ');
    text = text.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }

  /// Names that are measurements in their own right and must never be
  /// substituted away.
  ///
  /// The engine declares them as locals too -- `const double h = toFeet(...)`,
  /// `const double feet = 30.48` -- and expanding those would turn every
  /// formula in the catalogue into unreadable rubble, or worse, into C++.
  static const Set<String> _neverSubstitute = <String>{
    'h', 'w', 'wl', 'wr', 'ar', 'arch', 'cm', 'feet',
  };

  static List<_Local> _extractLocals(String text) {
    final List<_Local> locals = <_Local>[];
    final Set<String> claimed = <String>{};

    // A local that depends on a switch: the back collar's two sizes.
    //   const double d50Height = twoCmCollar ? (h - 3.7) : (h - 3.4);
    final RegExp ternary = RegExp(
      r'(?:const\s+)?double\s+(\w+)\s*=\s*(\w+)\s*\?([^:;]+):([^;]+);',
    );
    for (final RegExpMatch m in ternary.allMatches(text)) {
      final String name = m.group(1)!;
      claimed.add(name);
      locals.add(_Local(name, _tidy(m.group(3)!), _tidy(m.group(4)!), m.group(2)!.trim()));
    }

    // A local that is simply a shorthand:
    //   const double half = w / 2.0;
    // The lines that fetch a margin or convert a unit are caught by the same
    // pattern and are left to fail parsing, which drops them harmlessly --
    // those names are bound directly from the sample instead.
    final RegExp plain = RegExp(r'(?:const\s+)?double\s+(\w+)\s*=\s*([^;?]+);');
    for (final RegExpMatch m in plain.allMatches(text)) {
      final String name = m.group(1)!;
      if (claimed.contains(name)) continue;
      claimed.add(name);
      locals.add(_Local(name, _tidy(m.group(2)!), null, null));
    }

    // const bool twoCmCollar = in.backCollarCm >= 2.0;
    final RegExp boolean = RegExp(r'(?:const\s+)?bool\s+(\w+)\s*=\s*([^;]+);');
    for (final RegExpMatch m in boolean.allMatches(text)) {
      locals.add(_Local(m.group(1)!, _tidy(m.group(2)!), null, null));
    }

    // A measurement is not a shorthand, and a line the formula language cannot
    // read is C++ rather than arithmetic -- a unit conversion or a settings
    // lookup. Neither belongs in a substitution.
    return locals.where((_Local local) {
      if (_neverSubstitute.contains(local.name)) return false;
      if (local.condition != null) return true;
      return FormulaExpression.tryParse(local.whenTrue) != null;
    }).toList();
  }
}

// ---------------------------------------------------------------------------
// Matching what was computed to what was written
// ---------------------------------------------------------------------------

class _Slot {
  _Slot(this.context, this.window, this.config, this.section, this.index, this.label);

  final String context;
  final String window;
  final Map<String, String> config;
  final String section;
  final int index;
  final String label;

  String get configKey {
    final List<String> parts = config.keys.toList()..sort();
    return parts.map((String k) => '$k=${config[k]}').join('|');
  }

  @override
  String toString() => '$context/$window [$configKey] $section#$index "$label"';
}

class _Builder {
  _Builder(this.sources);

  final _SourceIndex sources;

  /// context/window -> configKey -> section -> [[label, formulaIndex], ...]
  final Map<String, Map<String, Map<String, List<dynamic>>>> _out =
      <String, Map<String, Map<String, List<dynamic>>>>{};

  /// context/window -> the measurements its formulas are allowed to read.
  final Map<String, Set<String>> _variables = <String, Set<String>>{};

  final List<_Slot> unmatched = <_Slot>[];
  final List<String> ambiguous = <String>[];

  /// Formulas that stopped reproducing the engine once they were tidied.
  /// There should never be one; if there is, the tidying is at fault and the
  /// catalogue must not be written.
  final List<String> rewritten = <String>[];
  int slotsMatched = 0;
  int configsTaken = 0;
  int configsRefused = 0;

  void take(Map<String, dynamic> record) {
    final String context = record['context'] as String;
    final String window = record['window'] as String;
    final Map<String, String> config = (record['config'] as Map<String, dynamic>)
        .map((String k, dynamic v) => MapEntry<String, String>(k, v as String));
    final List<dynamic> samples = record['samples'] as List<dynamic>;

    final Map<String, dynamic> base = samples.first as Map<String, dynamic>;
    if (base['ok'] != true) {
      // A configuration the engine does not accept -- an out-of-range collar
      // for this window type. There is no formula to record.
      configsRefused++;
      return;
    }
    configsTaken++;

    final List<_Candidate> candidates = sources.forWindow(context, window);
    final List<_Local> locals = sources.localsFor(context, window);
    final String windowKey = '$context/$window';

    final Map<String, dynamic> baseSections = base['sections'] as Map<String, dynamic>;
    for (final MapEntry<String, dynamic> section in baseSections.entries) {
      final List<dynamic> pieces = section.value as List<dynamic>;
      for (int index = 0; index < pieces.length; index++) {
        final List<dynamic> piece = pieces[index] as List<dynamic>;
        final String label = piece[0] as String;

        final _Slot slot =
            _Slot(context, window, config, section.key, index, label);

        // The engine leans on a few shorthand locals -- `half`, `d50Height`
        // and the rest. They mean nothing to a fabricator reading a formula
        // and nothing to the app evaluating one, so each is written out in
        // full here, in whichever form this configuration gives it.
        final List<_Candidate> fits = candidates
            .where((_Candidate c) => c.label == label)
            .map((_Candidate c) => c.expandedFor(locals, config, _resolveLocal))
            .where((_Candidate c) => _reproduces(c, slot, samples, config, locals))
            .toList();

        if (fits.isEmpty) {
          unmatched.add(slot);
          continue;
        }

        final Set<String> distinct = fits.map((_Candidate c) => c.source).toSet();
        if (distinct.length > 1) {
          // Two different-looking expressions that both land on every one of
          // the engine's numbers. They are the same arithmetic written twice;
          // taking the first keeps the catalogue deterministic, and the note
          // says where to look if they were meant to differ.
          ambiguous.add('$slot -> ${distinct.join('  ||  ')}');
        }

        // Written back out through the same reader the app will use, so what
        // a fabricator is shown is character for character what gets
        // evaluated, with the engine's stray brackets and ragged spacing
        // tidied away. The check below is what makes that safe: a tidied
        // formula still has to reproduce every number the engine produced.
        final FormulaExpression parsed = FormulaExpression.parse(_preferred(distinct));
        final String formula = parsed.toString();
        if (!_reproducesText(formula, slot, samples, config, locals)) {
            rewritten.add('$slot -> $formula');
            continue;
        }

        _record(windowKey, slot, formula);
        _variables.putIfAbsent(windowKey, () => <String>{}).addAll(parsed.variables);
        slotsMatched++;
      }
    }
  }

  /// Whichever of two identical-in-value expressions reads best: the shortest,
  /// and alphabetical to break a tie so the catalogue does not change between
  /// runs.
  static String _preferred(Set<String> options) {
    final List<String> sorted = options.toList()
      ..sort((String a, String b) {
        if (a.length != b.length) return a.length - b.length;
        return a.compareTo(b);
      });
    return sorted.first;
  }

  /// Whether this expression produces the engine's number at every sample.
  ///
  /// Every sample, not just one: several expressions in a file land on the
  /// same number for one particular window, and only the nudged points and the
  /// scattered one tell them apart.
  bool _reproduces(
    _Candidate candidate,
    _Slot slot,
    List<dynamic> samples,
    Map<String, String> config,
    List<_Local> locals,
  ) {
    return _check(candidate.parsed, slot, samples, config, locals);
  }

  /// The same check, for a formula that has been written back out as text.
  bool _reproducesText(
    String formula,
    _Slot slot,
    List<dynamic> samples,
    Map<String, String> config,
    List<_Local> locals,
  ) {
    return _check(FormulaExpression.tryParse(formula), slot, samples, config, locals);
  }

  bool _check(
    FormulaExpression? expression,
    _Slot slot,
    List<dynamic> samples,
    Map<String, String> config,
    List<_Local> locals,
  ) {
    if (expression == null) return false;

    for (final dynamic entry in samples) {
      final Map<String, dynamic> sample = entry as Map<String, dynamic>;
      if (sample['ok'] != true) return false;

      final Map<String, dynamic> sections = sample['sections'] as Map<String, dynamic>;
      final List<dynamic>? pieces = sections[slot.section] as List<dynamic>?;
      if (pieces == null || pieces.length <= slot.index) return false;
      final List<dynamic> piece = pieces[slot.index] as List<dynamic>;
      if (piece[0] != slot.label) return false;
      final double expected = (piece[1] as num).toDouble();

      final Map<String, double> variables =
          _environment(slot, sample, config, locals, expression.variables);

      final double actual;
      try {
        actual = expression.evaluate(variables);
      } on FormulaError {
        return false;
      }
      if (!actual.isFinite) return false;
      if ((actual - expected).abs() > kTolerance * (1 + expected.abs())) return false;
    }
    return true;
  }

  /// What each name in a formula stands for at this sample point.
  Map<String, double> _environment(
    _Slot slot,
    Map<String, dynamic> sample,
    Map<String, String> config,
    List<_Local> locals,
    Set<String> wanted,
  ) {
    double at(String key) => (sample[key] as num).toDouble();

    final Map<String, double> env = <String, double>{
      'h': at('h'),
      'w': at('w'),
      'wl': at('wl'),
      'wr': at('wr'),
      'arch': at('arch'),
      // The arch window's own name for the same measurement.
      'ar': at('arch'),
      'feet': kFeet,
    };

    // The cutting margin. Fabrication carries one; estimation carries one per
    // section and names it after the section, so a formula reading the wrong
    // section's margin cannot slip through.
    final String marginSection = (sample['marginSection'] as String?) ?? '';
    final double margin = at('margin');
    if (slot.context == 'fabrication') {
      env['cm'] = margin;
    } else {
      // Only the nudged section carries the nudged margin.
      for (final String key in _estimationMarginNames(wanted)) {
        final String section = key.substring(3);
        final bool nudged = marginSection.isEmpty || marginSection == section;
        env[key] = nudged ? margin : _estimationBaseMargin;
      }
      env['cm'] = margin;
    }

    // Locals such as d50Height, which stand for a whole sub-expression and
    // may depend on which way a configuration switch fell.
    for (final _Local local in locals) {
      if (!wanted.contains(local.name)) continue;
      final String? source = _resolveLocal(local, config);
      if (source == null) continue;
      final FormulaExpression? parsed = FormulaExpression.tryParse(source);
      if (parsed == null) continue;
      try {
        env[local.name] = parsed.evaluate(env);
      } on FormulaError {
        // Leaves it undefined; the candidate then fails to evaluate and is
        // simply not matched, which is the honest outcome.
      }
    }

    return env;
  }

  /// The margin the dump holds every un-nudged estimation section at.
  static const double _estimationBaseMargin = 0.07;

  static Iterable<String> _estimationMarginNames(Set<String> wanted) {
    return wanted.where((String name) => name.startsWith('cm_'));
  }

  /// Which side of a conditional local this configuration takes.
  String? _resolveLocal(_Local local, Map<String, String> config) {
    if (local.condition == null) return local.whenTrue;

    // The only conditional local in the engine turns on the back collar, and
    // the configuration says which one it is.
    if (local.condition == 'twoCmCollar') {
      final String? backCollar = config['backCollarCm'];
      if (backCollar == null) return null;
      final double value = double.tryParse(backCollar) ?? 1.7;
      return value >= 2.0 ? local.whenTrue : local.whenFalse;
    }
    return null;
  }

  /// Every distinct formula, once. Eighteen thousand pieces are written by a
  /// few hundred different sums, and spelling each one out at every piece
  /// makes the file many times larger than it needs to be for no gain -- it
  /// is read by a phone on a building site.
  final List<String> _formulaTable = <String>[];
  final Map<String, int> _formulaIndex = <String, int>{};

  int _internFormula(String formula) {
    final int? existing = _formulaIndex[formula];
    if (existing != null) return existing;
    _formulaTable.add(formula);
    _formulaIndex[formula] = _formulaTable.length - 1;
    return _formulaTable.length - 1;
  }

  void _record(String windowKey, _Slot slot, String formula) {
    _out
        .putIfAbsent(windowKey, () => <String, Map<String, List<dynamic>>>{})
        .putIfAbsent(slot.configKey, () => <String, List<dynamic>>{})
        .putIfAbsent(slot.section, () => <dynamic>[])
        .add(<dynamic>[slot.label, _internFormula(formula)]);
  }

  void report() {
    stdout.writeln('\n--- what was proved ---');
    stdout.writeln('  configurations taken     : $configsTaken');
    stdout.writeln('  configurations refused   : $configsRefused  (out of range for that window)');
    stdout.writeln('  pieces matched to source : $slotsMatched');
    stdout.writeln('  pieces with no match     : ${unmatched.length}');
    stdout.writeln('  pieces matched twice     : ${ambiguous.length}  (same arithmetic, spelt differently)');
    stdout.writeln('  broken by tidying        : ${rewritten.length}');
    stdout.writeln('  distinct formulas        : ${_formulaTable.length}');

    if (rewritten.isNotEmpty) {
      stdout.writeln('\n  TIDYING CHANGED THE ANSWER -- the printer is wrong:');
      for (final String note in rewritten.take(8)) {
        stdout.writeln('    $note');
      }
    }

    if (ambiguous.isNotEmpty) {
      stdout.writeln('\n  written two ways, same arithmetic (first ${ambiguous.length > 5 ? 5 : ambiguous.length}):');
      for (final String note in ambiguous.take(5)) {
        stdout.writeln('    $note');
      }
    }

    if (unmatched.isNotEmpty) {
      stdout.writeln('\n  NO EXPRESSION REPRODUCES THESE:');
      final Map<String, int> byWindow = <String, int>{};
      for (final _Slot slot in unmatched) {
        byWindow['${slot.context}/${slot.window}'] =
            (byWindow['${slot.context}/${slot.window}'] ?? 0) + 1;
      }
      for (final MapEntry<String, int> entry in byWindow.entries) {
        stdout.writeln('    ${entry.key}: ${entry.value}');
      }
      stdout.writeln('\n  first few:');
      for (final _Slot slot in unmatched.take(8)) {
        stdout.writeln('    $slot');
      }
    }
  }

  /// windowKey -> configKey -> the panes of glass that window makes.
  final Map<String, Map<String, List<dynamic>>> _glass =
      <String, Map<String, List<dynamic>>>{};

  int glassPanes = 0;
  int glassConfigs = 0;

  /// Recovers every glass formula, and refuses any it cannot prove.
  ///
  /// Returns how many were unproved, which is how many reasons there are not
  /// to ship.
  int takeGlass(List<dynamic> records, String? altPath) {
    final GlassReader reader = GlassReader.of(records);
    final GlassReader? alt =
        altPath == null ? null : GlassReader.of(readDump(altPath));

    final List<String> problems = <String>[];
    final List<String> unwritable = <String>[];
    int noGlass = 0;

    for (final MapEntry<String, Map<String, dynamic>> entry in reader.records.entries) {
      final Map<String, dynamic> record = entry.value;
      final (List<List<Affine>>?, String?) solved = reader.solve(record);
      if (solved.$1 == null) {
        if (solved.$2 != 'no glass') problems.add('${entry.key}: ${solved.$2}');
        noGlass++;
        continue;
      }
      final List<List<Affine>> panes = solved.$1!;

      // Against its own points, then against a dump it has never seen.
      problems.addAll(reader.check(record, panes));
      final Map<String, dynamic>? other = alt?.records[entry.key];
      if (other != null) problems.addAll(alt!.check(other, panes));

      final Map<String, dynamic> base =
          (record['samples'] as List<dynamic>).first as Map<String, dynamic>;
      final List<String?> roles = GlassReader.rolesOf(base, panes.length);

      final List<dynamic> written = <dynamic>[];
      for (int index = 0; index < panes.length; index++) {
        final String? height = panes[index][0].write(_paneName(panes[index][0]));
        final String? width = panes[index][1].write(_paneName(panes[index][1]));
        if (height == null || width == null) {
          unwritable.add('${entry.key} pane $index');
          continue;
        }
        written.add(<String, dynamic>{
          if (roles[index] != null) 'role': roles[index],
          'h': _internFormula(height),
          'w': _internFormula(width),
        });
        glassPanes++;
      }

      if (written.length != panes.length) continue;

      final String windowKey = 'fabrication/${record['window']}';
      final Map<String, dynamic> config = record['config'] as Map<String, dynamic>;
      final List<String> names = config.keys.toList()..sort();
      final String configKey =
          names.map((String n) => '$n=${config[n]}').join('|');

      _glass
          .putIfAbsent(windowKey, () => <String, List<dynamic>>{})[configKey] = written;
      glassConfigs++;
    }

    stdout.writeln('  configurations with glass : $glassConfigs');
    stdout.writeln('  panes described           : $glassPanes');
    stdout.writeln('  configurations without    : $noGlass');
    stdout.writeln('  formulas that failed      : ${problems.length}');
    stdout.writeln('  formulas that cannot be written readably : ${unwritable.length}');

    for (final String problem in problems.take(10)) {
      stdout.writeln('    $problem');
    }
    for (final String problem in unwritable.take(10)) {
      stdout.writeln('    $problem');
    }

    return problems.length + unwritable.length;
  }

  /// What the measurement is called inside a stored glass formula.
  ///
  /// The catalogue's own name, the same as every section formula uses. What a
  /// fabricator sees -- `H`, `W`, `W_left` -- is put there on the way to the
  /// screen and taken off again on the way back, by the one piece of code that
  /// does that for every formula in the app. Storing the display name instead
  /// would give the screen something to read and the calculator something it
  /// cannot evaluate.
  static String _paneName(Affine formula) => formula.dimension;

  Map<String, dynamic> catalogue() {
    return <String, dynamic>{
      'version': 1,
      'generated': DateTime.now().toUtc().toIso8601String(),
      'note': 'Built from the engine\'s own output. Every formula here was '
          'checked to reproduce it at every sample point, before and after '
          'being tidied. Pieces name a formula by its place in "formulas".',
      'formulas': _formulaTable,
      'windows': _out.map((String key, Map<String, Map<String, List<dynamic>>> configs) {
        return MapEntry<String, dynamic>(key, <String, dynamic>{
          'variables': (_variables[key]?.toList() ?? <String>[])..sort(),
          'configs': configs,
          // Kept apart from the aluminium. Both are formulas a workshop can
          // change, but only one of them is cut from a bar -- and a pane of
          // glass sent to the length optimizer would be optimised into a
          // cutting list nobody can cut.
          if (_glass[key] != null) 'glass': _glass[key],
        });
      }),
    };
  }
}
