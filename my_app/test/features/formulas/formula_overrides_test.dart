import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/formulas/model/formula_overrides.dart';
import 'package:my_app/features/formulas/model/formula_window_key.dart';

/// A workshop's changed formulas travel to the server as JSON and come back
/// the same way. If that trip loses one, a shop arrives at a new phone cutting
/// to somebody else's numbers without being told -- so the trip is held to
/// coming back exactly as it went.
void main() {
  FormulaPieceRef ref(String window, String config, String section, int index) {
    return FormulaPieceRef(
      windowKey: window,
      configKey: config,
      section: section,
      index: index,
    );
  }

  test('what goes to the server comes back unchanged', () {
    final FormulaOverrides before = FormulaOverrides.empty()
      ..set(ref('fabrication/S_win', 'collarType=2|lockType=1|rubberType=F',
          'DC30C', 0), '(h + 12 + cm) / feet')
      ..set(ref('fabrication/S_win', 'collarType=2|lockType=1|rubberType=F',
          'M23', 1), '(h - 4 + cm) / feet')
      ..set(ref('estimation/D_win', 'addBottom=true|addTee=false|collarType=3|doorType=2',
          'D50', 3), 'w / 2 + cm_D50');

    final String wire = jsonEncode(before.toJson());
    final FormulaOverrides after =
        FormulaOverrides.fromJson(jsonDecode(wire) as Map<String, dynamic>);

    expect(after.count, before.count);
    for (final MapEntry<FormulaPieceRef, String> entry in before.all.entries) {
      expect(after.formulaFor(entry.key), entry.value,
          reason: '${entry.key} did not survive the trip');
    }
  });

  test('the shape is the one the server stores', () {
    final FormulaOverrides overrides = FormulaOverrides.empty()
      ..set(ref('fabrication/S_win', 'collarType=2', 'DC30C', 0), 'h + cm');

    final Map<String, dynamic> json = overrides.toJson();
    expect(json['version'], 1);

    // window -> configuration -> profile -> position. Nested rather than one
    // joined-up key, because a key would need a separator none of the four can
    // contain, and configuration keys already carry "=" and "|".
    final Map<String, dynamic> windows = json['windows'] as Map<String, dynamic>;
    final Map<String, dynamic> configs =
        windows['fabrication/S_win'] as Map<String, dynamic>;
    final Map<String, dynamic> sections = configs['collarType=2'] as Map<String, dynamic>;
    final Map<String, dynamic> pieces = sections['DC30C'] as Map<String, dynamic>;
    expect(pieces['0'], 'h + cm');
  });

  test('rubbish from the server is ignored rather than half-read', () {
    // Better to fall back to the shipped formulas, which a workshop will
    // notice, than to load half a set and cut to it silently.
    final FormulaOverrides parsed = FormulaOverrides.fromJson(<String, dynamic>{
      'version': 1,
      'windows': <String, dynamic>{
        'fabrication/S_win': <String, dynamic>{
          'collarType=2': <String, dynamic>{
            'DC30C': <String, dynamic>{
              '0': 'h + cm', // good
              'x': 'h + cm', // not a position
              '1': 42, // not a formula
            },
          },
          'bad': 'not an object',
        },
        'other': 'not an object',
      },
    });

    expect(parsed.count, 1);
    expect(parsed.formulaFor(ref('fabrication/S_win', 'collarType=2', 'DC30C', 0)),
        'h + cm');
  });

  test('an empty set is empty, not a crash', () {
    expect(FormulaOverrides.fromJson(null).isEmpty, isTrue);
    expect(FormulaOverrides.fromJson(<String, dynamic>{}).isEmpty, isTrue);
    expect(
      FormulaOverrides.fromJson(<String, dynamic>{'windows': 'nonsense'}).isEmpty,
      isTrue,
    );
  });

  test('a configuration can be put back without touching the others', () {
    final FormulaWindowKey key = FormulaWindowKey.of(
      context: 'fabrication',
      appWindowCode: 'S_win',
      dimensions: <String>{'collarType', 'lockType', 'rubberType'},
      collarIndex: 2,
      lockType: 1,
      rubberType: 'F',
    )!;

    final FormulaOverrides overrides = FormulaOverrides.empty()
      ..set(FormulaPieceRef.of(key, 'DC30C', 0), 'h + 1 + cm')
      ..set(ref('fabrication/S_win', 'collarType=13|lockType=1|rubberType=F',
          'DC30C', 0), 'h + 2 + cm');

    expect(overrides.configHasChanges(key), isTrue);
    overrides.clearConfig(key);
    expect(overrides.configHasChanges(key), isFalse);
    expect(overrides.count, 1, reason: 'the other collar type was left alone');
  });
}
