// Holds the app's cut lengths against the engine's, on real work.
//
// The app is taking over the arithmetic that decides how much aluminium a
// workshop buys and where the saw stops. The only acceptable evidence that it
// can is that it already agrees with the engine on every job those workshops
// have actually run -- not on windows invented for a test, which would only
// ever cover the cases somebody thought of.
//
// So this replays every optimized project on the server: same windows, same
// measurements, same cutting margins, and compares piece for piece. A single
// disagreement anywhere is a reason not to switch.
//
// Run from the app root:
//   dart run tool/verify_cut_parity.dart <parity_bundle.json>

import 'dart:convert';
import 'dart:io';

import 'package:my_app/features/formulas/data/formula_book.dart';
import 'package:my_app/features/formulas/data/formula_catalogue.dart';
import 'package:my_app/features/formulas/model/formula_overrides.dart';
import 'package:my_app/features/formulas/data/window_cut_calculator.dart';

/// Both sides are doubles; one of them has been through a decimal round trip
/// on the way out of the engine. Far tighter than a saw, far looser than that.
const double kTolerance = 1e-9;

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run tool/verify_cut_parity.dart <parity_bundle.json>');
    exit(2);
  }

  final String cataloguePath =
      args.length > 1 ? args[1] : 'assets/formulas/catalogue.json';
  final FormulaCatalogue catalogue = FormulaCatalogue.fromJson(
    jsonDecode(File(cataloguePath).readAsStringSync()) as Map<String, dynamic>,
  );

  // The shipped formulas, with nothing changed -- which is the state every
  // workshop is in on the day this ships, and the only state in which the app
  // is expected to agree with the engine at all.
  final WindowCutCalculator calculator =
      WindowCutCalculator(FormulaBook(catalogue, FormulaOverrides.empty()));

  final List<dynamic> bundles =
      jsonDecode(File(args[0]).readAsStringSync()) as List<dynamic>;
  stdout.writeln('Replaying ${bundles.length} real projects...\n');

  int projects = 0;
  int windows = 0;
  int piecesCompared = 0;
  int projectsExact = 0;

  final List<String> mismatches = <String>[];
  final List<String> warnings = <String>[];
  int warnedProjects = 0;
  final Map<String, int> mismatchesByWindowCode = <String, int>{};
  final Map<String, int> unreadable = <String, int>{};

  for (final dynamic entry in bundles) {
    final Map<String, dynamic> bundle = entry as Map<String, dynamic>;
    final String context = bundle['context'] as String;
    final bool isFabrication = context == 'fabrication';
    final String project = '${bundle['projectName']} (${bundle['projectId']})';

    final Map<String, double> margins = (bundle['margins'] as Map<String, dynamic>)
        .map((String k, dynamic v) => MapEntry<String, double>(k, (v as num).toDouble()));

    // What the app makes of the same job.
    final Map<String, List<double>> mine = <String, List<double>>{};
    final List<String> windowProblems = <String>[];

    for (final dynamic windowEntry in bundle['windows'] as List<dynamic>) {
      final Map<String, dynamic> window = windowEntry as Map<String, dynamic>;
      windows++;

      final WindowCutRequest request = WindowCutRequest(
        isFabrication: isFabrication,
        appWindowCode: window['windowCode'] as String,
        collarIndex: (window['collarIndex'] as num?)?.toInt() ?? 0,
        unitMode: window['unitMode'] as String? ?? '',
        heightValue: '${window['heightValue'] ?? ''}',
        widthValue: '${window['widthValue'] ?? ''}',
        leftWidthValue: window['leftWidthValue'] as String?,
        rightWidthValue: window['rightWidthValue'] as String?,
        archValue: window['archValue'] as String?,
        lockType: (window['lockType'] as num?)?.toInt(),
        rubberType: window['rubberType'] as String?,
        addBottom: window['addBottom'] == true,
        addTee: window['addTee'] == true,
        addNet: window['addNet'] == true,
        backCollarCm: (window['backCollarCm'] as num?)?.toDouble() ?? 1.7,
      );

      final WindowCutList cut = calculator.compute(request, margins: margins);
      if (cut.problems.isNotEmpty) {
        final String code = window['windowCode'] as String;
        unreadable['$code: ${cut.problems.first}'] =
            (unreadable['$code: ${cut.problems.first}'] ?? 0) + 1;
        windowProblems.add('window ${window['winNo']}: ${cut.problems.first}');
      }

      final int winNo = (window['winNo'] as num?)?.toInt() ?? 0;
      for (final CutPiece piece in cut.pieces) {
        mine
            .putIfAbsent('$winNo|${piece.section}|${piece.label}', () => <double>[])
            .add(piece.lengthFt);
      }
    }

    // What the engine made of it.
    final Map<String, List<double>> theirs = <String, List<double>>{};
    for (final dynamic pieceEntry in bundle['enginePieces'] as List<dynamic>) {
      final Map<String, dynamic> piece = pieceEntry as Map<String, dynamic>;
      theirs
          .putIfAbsent(
            '${piece['winNo']}|${piece['section']}|${piece['label']}',
            () => <double>[],
          )
          .add((piece['lengthFt'] as num).toDouble());
    }

    projects++;
    final List<String> here = _compare(mine, theirs, project);
    piecesCompared += theirs.values.fold(0, (int sum, List<double> l) => sum + l.length);

    // A cut list that differs is the thing that must never happen. A window
    // the app refused to work out is a different matter and is counted
    // separately: the engine drops a piece it cannot make without saying so,
    // and the app saying so is an improvement, not a disagreement -- as long
    // as both leave the same metal on the list, which is what `here` checks.
    if (windowProblems.isNotEmpty) {
      warnedProjects++;
      for (final String problem in windowProblems) {
        warnings.add('$project  $problem');
      }
    }

    if (here.isEmpty) {
      projectsExact++;
    } else {
      mismatches.addAll(here);
      for (final dynamic windowEntry in bundle['windows'] as List<dynamic>) {
        final String code = (windowEntry as Map<String, dynamic>)['windowCode'] as String;
        mismatchesByWindowCode[code] = (mismatchesByWindowCode[code] ?? 0) + 1;
      }
    }
  }

  stdout.writeln('--- the app against the engine, on real jobs ---');
  stdout.writeln('  projects replayed    : $projects');
  stdout.writeln('  windows              : $windows');
  stdout.writeln('  engine pieces        : $piecesCompared');
  stdout.writeln('  cut lists that match : $projectsExact');
  stdout.writeln('  cut lists that differ: ${projects - projectsExact}');
  stdout.writeln('  projects the app warned about: $warnedProjects');

  if (warnings.isNotEmpty) {
    stdout.writeln('\n  Pieces the engine dropped silently and the app names.');
    stdout.writeln('  The metal on the list is the same either way:');
    for (final String warning in warnings.take(8)) {
      stdout.writeln('    $warning');
    }
    if (warnings.length > 8) {
      stdout.writeln('    ... and ${warnings.length - 8} more');
    }
  }

  if (mismatches.isEmpty) {
    stdout.writeln('\nEvery piece of every job agreed, to the last digit.');
    return;
  }

  if (unreadable.isNotEmpty) {
    stdout.writeln('\n  windows the app could not work out:');
    final List<MapEntry<String, int>> sorted = unreadable.entries.toList()
      ..sort((MapEntry<String, int> a, MapEntry<String, int> b) => b.value - a.value);
    for (final MapEntry<String, int> row in sorted.take(10)) {
      stdout.writeln('    ${row.value}x  ${row.key}');
    }
  }

  stdout.writeln('\n  ${mismatches.length} disagreements. First 15:');
  for (final String mismatch in mismatches.take(15)) {
    stdout.writeln('    $mismatch');
  }
  exit(1);
}

/// Every way two cut lists can differ, said plainly.
List<String> _compare(
  Map<String, List<double>> mine,
  Map<String, List<double>> theirs,
  String project,
) {
  final List<String> problems = <String>[];

  for (final String key in theirs.keys) {
    if (!mine.containsKey(key)) {
      problems.add('$project  $key: engine cut ${theirs[key]!.length}, app cut none');
    }
  }
  for (final String key in mine.keys) {
    if (!theirs.containsKey(key)) {
      problems.add('$project  $key: app cut ${mine[key]!.length}, engine cut none');
    }
  }

  for (final String key in theirs.keys) {
    final List<double>? ours = mine[key];
    if (ours == null) continue;
    final List<double> engine = List<double>.from(theirs[key]!)..sort();
    final List<double> app = List<double>.from(ours)..sort();

    if (engine.length != app.length) {
      problems.add('$project  $key: engine cut ${engine.length} pieces, app cut ${app.length}');
      continue;
    }
    for (int i = 0; i < engine.length; i++) {
      if ((engine[i] - app[i]).abs() > kTolerance * (1 + engine[i].abs())) {
        problems.add('$project  $key: engine ${engine[i]}, app ${app[i]}');
        break;
      }
    }
  }

  return problems;
}
