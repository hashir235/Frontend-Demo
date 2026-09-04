// Holds the shipped catalogue against the engine, on windows it has never
// seen.
//
// The catalogue was assembled by matching expressions to numbers. Checking it
// against those same numbers would only prove the matching was self-
// consistent. So this reads the catalogue file as the app will read it, and
// tests every formula in it against a second dump taken at a completely
// different set of measurements -- different heights, widths, margins, none of
// them reachable from the first set.
//
// A formula that merely happened to fit cannot survive that. One that is the
// engine's own arithmetic cannot fail it.
//
// Run from the app root:
//   dart run tool/verify_formula_catalogue.dart <alt_ground_truth.json>

import 'dart:convert';
import 'dart:io';

import 'package:my_app/features/formulas/model/formula_expression.dart';

const double kFeet = 30.48;

/// Both sides are doubles that have been through a decimal round trip. This is
/// far tighter than any saw and far looser than that round trip's noise.
const double kTolerance = 1e-9;

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run tool/verify_formula_catalogue.dart <alt_ground_truth.json>');
    exit(2);
  }

  final String cataloguePath =
      args.length > 1 ? args[1] : 'assets/formulas/catalogue.json';
  final Map<String, dynamic> catalogue =
      jsonDecode(File(cataloguePath).readAsStringSync()) as Map<String, dynamic>;
  final List<String> formulas = (catalogue['formulas'] as List<dynamic>).cast<String>();
  final Map<String, dynamic> windows = catalogue['windows'] as Map<String, dynamic>;

  // Parsed once. If any formula in the catalogue cannot be read back, that is
  // a failure on its own -- the app would hit it at the worst moment.
  final List<FormulaExpression> parsed = <FormulaExpression>[];
  for (int i = 0; i < formulas.length; i++) {
    final FormulaExpression? expression = FormulaExpression.tryParse(formulas[i]);
    if (expression == null) {
      stderr.writeln('Catalogue formula $i cannot be read back: "${formulas[i]}"');
      exit(1);
    }
    parsed.add(expression);
  }
  stdout.writeln('Catalogue: ${formulas.length} formulas, all readable.');

  final List<dynamic> records = jsonDecode(File(args[0]).readAsStringSync()) as List<dynamic>;
  stdout.writeln('Checking against ${records.length} configurations at fresh measurements...\n');

  int checkedPieces = 0;
  int checkedConfigs = 0;
  int missingConfigs = 0;
  int shapeMismatches = 0;
  final List<String> failures = <String>[];

  for (final dynamic entry in records) {
    final Map<String, dynamic> record = entry as Map<String, dynamic>;
    final List<dynamic> samples = record['samples'] as List<dynamic>;
    final Map<String, dynamic> base = samples.first as Map<String, dynamic>;
    if (base['ok'] != true) continue;

    final String windowKey = '${record['context']}/${record['window']}';
    final Map<String, String> config = (record['config'] as Map<String, dynamic>)
        .map((String k, dynamic v) => MapEntry<String, String>(k, v as String));
    final List<String> keys = config.keys.toList()..sort();
    final String configKey = keys.map((String k) => '$k=${config[k]}').join('|');

    final Map<String, dynamic>? window = windows[windowKey] as Map<String, dynamic>?;
    final Map<String, dynamic>? configs =
        window?['configs'] as Map<String, dynamic>?;
    final Map<String, dynamic>? sections =
        configs?[configKey] as Map<String, dynamic>?;

    if (sections == null) {
      missingConfigs++;
      failures.add('$windowKey [$configKey] is not in the catalogue at all');
      continue;
    }
    checkedConfigs++;

    // The margin every un-nudged estimation section sits at, taken from the
    // record rather than assumed.
    final double baseMargin = (base['margin'] as num).toDouble();

    for (final dynamic sampleEntry in samples) {
      final Map<String, dynamic> sample = sampleEntry as Map<String, dynamic>;
      if (sample['ok'] != true) continue;

      final Map<String, dynamic> engineSections =
          sample['sections'] as Map<String, dynamic>;

      // The catalogue must describe the same shape the engine produced --
      // the same sections, each with the same pieces in the same order. A
      // formula that is right about a piece that should not be there, or
      // silent about one that should, is still a wrong cutting list.
      if (engineSections.length != sections.length) {
        shapeMismatches++;
        failures.add('$windowKey [$configKey] has ${engineSections.length} sections, '
            'catalogue has ${sections.length}');
        break;
      }

      for (final MapEntry<String, dynamic> section in engineSections.entries) {
        final List<dynamic>? cataloguePieces = sections[section.key] as List<dynamic>?;
        final List<dynamic> enginePieces = section.value as List<dynamic>;

        if (cataloguePieces == null) {
          shapeMismatches++;
          failures.add('$windowKey [$configKey] section ${section.key} missing from catalogue');
          continue;
        }
        if (cataloguePieces.length != enginePieces.length) {
          shapeMismatches++;
          failures.add('$windowKey [$configKey] ${section.key}: engine cut '
              '${enginePieces.length} pieces, catalogue lists ${cataloguePieces.length}');
          continue;
        }

        final Map<String, double> variables =
            _environment(record['context'] as String, sample, baseMargin, parsed);

        for (int i = 0; i < enginePieces.length; i++) {
          final List<dynamic> enginePiece = enginePieces[i] as List<dynamic>;
          final List<dynamic> cataloguePiece = cataloguePieces[i] as List<dynamic>;

          final String engineLabel = enginePiece[0] as String;
          final String catalogueLabel = cataloguePiece[0] as String;
          if (engineLabel != catalogueLabel) {
            failures.add('$windowKey [$configKey] ${section.key}#$i: engine says '
                '"$engineLabel", catalogue says "$catalogueLabel"');
            continue;
          }

          final double expected = (enginePiece[1] as num).toDouble();
          final FormulaExpression expression = parsed[cataloguePiece[1] as int];

          final double actual;
          try {
            actual = expression.evaluate(variables);
          } on FormulaError catch (error) {
            failures.add('$windowKey [$configKey] ${section.key}#$i "$engineLabel": '
                '${error.message}  [${formulas[cataloguePiece[1] as int]}]');
            continue;
          }

          if ((actual - expected).abs() > kTolerance * (1 + expected.abs())) {
            failures.add('$windowKey [$configKey] ${section.key}#$i "$engineLabel" '
                'at ${sample['point']}: engine $expected, catalogue $actual  '
                '[${formulas[cataloguePiece[1] as int]}]');
          }
          checkedPieces++;
        }
      }
    }
  }

  stdout.writeln('--- held against the engine ---');
  stdout.writeln('  configurations checked : $checkedConfigs');
  stdout.writeln('  configurations missing : $missingConfigs');
  stdout.writeln('  piece evaluations      : $checkedPieces');
  stdout.writeln('  shape mismatches       : $shapeMismatches');
  stdout.writeln('  wrong lengths          : '
      '${failures.length - missingConfigs - shapeMismatches}');

  if (failures.isEmpty) {
    stdout.writeln('\nEvery formula in the catalogue reproduced the engine exactly, '
        'on measurements it was never fitted to.');
    return;
  }

  stdout.writeln('\n${failures.length} problems. First ${failures.length > 20 ? 20 : failures.length}:');
  for (final String failure in failures.take(20)) {
    stdout.writeln('  $failure');
  }
  exit(1);
}

/// What each name stands for at one sample point.
///
/// Built from the dump alone -- nothing here is shared with the tool that
/// assembled the catalogue, because a mistake shared by both would be a
/// mistake neither could see.
Map<String, double> _environment(
  String context,
  Map<String, dynamic> sample,
  double baseMargin,
  List<FormulaExpression> parsed,
) {
  double at(String key) => (sample[key] as num).toDouble();

  final Map<String, double> variables = <String, double>{
    'h': at('h'),
    'w': at('w'),
    'wl': at('wl'),
    'wr': at('wr'),
    'ar': at('arch'),
    'arch': at('arch'),
    'feet': kFeet,
  };

  final double margin = at('margin');
  final String nudged = (sample['marginSection'] as String?) ?? '';

  if (context == 'fabrication') {
    variables['cm'] = margin;
    return variables;
  }

  // Estimation carries a margin per section. Where the dump nudged one, only
  // that one moved; everything else stayed at the record's own baseline.
  for (final String section in _sectionKeys) {
    final bool moved = nudged.isEmpty || nudged == section;
    variables['cm_$section'] = moved ? margin : baseMargin;
  }
  return variables;
}

const List<String> _sectionKeys = <String>[
  'D29', 'D31', 'D41', 'D46', 'D50', 'D50A', 'D51A', 'D51F',
  'D52', 'D54A', 'D54F', 'DC26C', 'DC26F', 'DC30C', 'DC30F', 'M23',
  'M24', 'M26', 'M26F', 'M28', 'M30', 'M30F',
];
