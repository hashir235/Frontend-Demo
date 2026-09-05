// Adds the app's own cut lengths to real optimization requests.
//
// This is the switch itself, prepared for an end-to-end test: the same jobs,
// once with the engine working out its own lengths and once with the app's
// handed to it. If the two cutting reports are not identical, the switch is
// not safe and does not happen.
//
//   dart run tool/inject_computed_pieces.dart <bundle.json> <out.json>
//
// The bundle is a list of {path, request, margins} -- a real archived request
// and the cutting margins the workshop had set when it ran.

import 'dart:convert';
import 'dart:io';

import 'package:my_app/features/formulas/data/formula_book.dart';
import 'package:my_app/features/formulas/data/formula_catalogue.dart';
import 'package:my_app/features/formulas/data/window_cut_calculator.dart';
import 'package:my_app/features/formulas/model/formula_overrides.dart';

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('usage: dart run tool/inject_computed_pieces.dart '
        '<bundle.json> <out.json> [catalogue.json]');
    exit(2);
  }

  final String cataloguePath =
      args.length > 2 ? args[2] : 'assets/formulas/catalogue.json';
  final FormulaCatalogue catalogue = FormulaCatalogue.fromJson(
    jsonDecode(File(cataloguePath).readAsStringSync()) as Map<String, dynamic>,
  );

  // The shipped formulas, untouched -- which is where every workshop starts,
  // and the only state in which the app must agree with the engine.
  final WindowCutCalculator calculator =
      WindowCutCalculator(FormulaBook(catalogue, FormulaOverrides.empty()));

  final List<dynamic> bundle =
      jsonDecode(File(args[0]).readAsStringSync()) as List<dynamic>;

  int windowCount = 0;
  int pieceCount = 0;
  final List<String> refused = <String>[];

  for (final dynamic entry in bundle) {
    final Map<String, dynamic> job = entry as Map<String, dynamic>;
    final Map<String, dynamic> request = job['request'] as Map<String, dynamic>;
    final Map<String, double> margins = (job['margins'] as Map<String, dynamic>)
        .map((String k, dynamic v) => MapEntry<String, double>(k, (v as num).toDouble()));

    final bool isFabrication = request['context'] == 'fabrication';

    for (final dynamic windowEntry in request['windows'] as List<dynamic>) {
      final Map<String, dynamic> window = windowEntry as Map<String, dynamic>;
      windowCount++;

      final WindowCutList cut = calculator.compute(
        WindowCutRequest(
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
        ),
        margins: margins,
      );

      if (cut.problems.isNotEmpty) {
        refused.add('${window['windowCode']} win ${window['winNo']}: '
            '${cut.problems.first}');
      }

      window['computedGlass'] = <Map<String, dynamic>>[
        for (final GlassPiece pane in cut.glass)
          <String, dynamic>{'heightCm': pane.heightCm, 'widthCm': pane.widthCm},
      ];
      window['computedPieces'] = <Map<String, dynamic>>[
        for (final CutPiece piece in cut.pieces)
          <String, dynamic>{
            'section': piece.section,
            'piece': piece.label,
            'lengthFt': piece.lengthFt,
          },
      ];
      pieceCount += cut.pieces.length;
    }
  }

  File(args[1]).writeAsStringSync(jsonEncode(bundle));
  stdout.writeln('jobs: ${bundle.length}  windows: $windowCount  '
      'pieces the app worked out: $pieceCount');
  for (final String problem in refused) {
    stdout.writeln('  note: $problem');
  }
}
