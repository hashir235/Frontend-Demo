import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/formulas/data/formula_book.dart';
import 'package:my_app/features/formulas/data/formula_catalogue.dart';
import 'package:my_app/features/formulas/data/window_cut_calculator.dart';
import 'package:my_app/features/formulas/model/formula_overrides.dart';
import 'package:my_app/features/formulas/model/formula_window_key.dart';

/// The rubber decides the glass, and the window's own rubber has to be the one
/// that decides it.
///
/// A U-rubber pane is 6mm shorter and 12mm narrower than an F-rubber one in
/// the same opening. Cutting glass to the wrong one gives a pane that either
/// will not go in or rattles when it does -- and glass cut wrong is not a
/// piece you re-cut, it is a sheet you buy again.
///
/// These run against the real shipped catalogue rather than a made-up one,
/// because what matters is that the formulas Quick AL actually carries are
/// picked apart by rubber, not that a test fixture can be.
void main() {
  late FormulaCatalogue catalogue;

  setUpAll(() {
    catalogue = FormulaCatalogue.fromJson(
      jsonDecode(File('assets/formulas/catalogue.json').readAsStringSync())
          as Map<String, dynamic>,
    );
  });

  FormulaWindowKey keyFor(String rubber) {
    return FormulaWindowKey.of(
      context: 'fabrication',
      appWindowCode: 'S_win',
      dimensions: catalogue.dimensionsFor('fabrication/S_win'),
      collarIndex: 2,
      lockType: 1,
      rubberType: rubber,
    )!;
  }

  test('the rubber is part of which formulas a window gets', () {
    expect(keyFor('F').configKey, contains('rubberType=F'));
    expect(keyFor('U').configKey, contains('rubberType=U'));
    expect(keyFor('F').configKey, isNot(keyFor('U').configKey));
  });

  test('changing the rubber changes the glass formulas', () {
    final FormulaBook book = FormulaBook(catalogue, FormulaOverrides.empty());

    String panes(String rubber) {
      return book
          .glassFor(keyFor(rubber))
          .map((EffectiveSection pane) =>
              pane.pieces.map((EffectiveFormula p) => p.slot.stored).join(' x '))
          .join(' | ');
    }

    final String withF = panes('F');
    final String withU = panes('U');

    expect(withF, isNotEmpty);
    expect(withU, isNotEmpty);
    expect(withU, isNot(withF), reason: 'U and F glass must not be the same');

    // The engine's own numbers: F takes 10 off the height and adds 1.6 to the
    // width; U takes 10.6 and adds 1.
    expect(withF, contains('h - 14.2'));
    expect(withU, contains('h - 14.8'));
  });

  test('changing the rubber leaves the aluminium alone', () {
    final FormulaBook book = FormulaBook(catalogue, FormulaOverrides.empty());

    String sections(String rubber) {
      return (book.sectionsFor(keyFor(rubber)) ?? <EffectiveSection>[])
          .map((EffectiveSection s) =>
              '${s.section}:${s.pieces.map((EffectiveFormula p) => p.slot.stored).join(",")}')
          .join('|');
    }

    // The rubber sits between the glass and the frame; it is not part of any
    // bar's length. If this ever starts differing, something has been keyed by
    // rubber that should not be.
    expect(sections('U'), sections('F'));
  });

  test('a window cut with U rubber gets U-rubber panes', () {
    final WindowCutCalculator calculator =
        WindowCutCalculator(FormulaBook(catalogue, FormulaOverrides.empty()));

    WindowCutList cut(String rubber) {
      return calculator.compute(
        WindowCutRequest(
          isFabrication: true,
          appWindowCode: 'S_win',
          collarIndex: 2,
          unitMode: 'cm',
          heightValue: '220.6',
          widthValue: '182.5',
          lockType: 1,
          rubberType: rubber,
        ),
        margins: const <String, double>{'cm': 0.5},
      );
    }

    final WindowCutList withF = cut('F');
    final WindowCutList withU = cut('U');

    expect(withF.problems, isEmpty);
    expect(withU.problems, isEmpty);
    expect(withF.glass.length, 2);
    expect(withU.glass.length, 2);

    // 220.6 - 14.2 against 220.6 - 14.8, and (182.5 - 12.3)/2 against
    // (182.5 - 13.5)/2.
    expect(withF.glass.first.heightCm, closeTo(206.4, 1e-9));
    expect(withU.glass.first.heightCm, closeTo(205.8, 1e-9));
    expect(withF.glass.first.widthCm, closeTo(85.1, 1e-9));
    expect(withU.glass.first.widthCm, closeTo(84.5, 1e-9));

    // The aluminium is the same job either way.
    expect(
      withU.pieces.map((CutPiece p) => '${p.section}${p.label}${p.lengthFt}'),
      withF.pieces.map((CutPiece p) => '${p.section}${p.label}${p.lengthFt}'),
    );
  });

  test('every window that has a rubber cuts different glass for each', () {
    // Not one window: all of them. A single window keyed correctly proves
    // nothing about the other three hundred.
    final Map<String, dynamic> json =
        jsonDecode(File('assets/formulas/catalogue.json').readAsStringSync())
            as Map<String, dynamic>;
    final List<String> formulas = (json['formulas'] as List<dynamic>).cast<String>();

    int pairs = 0;
    final List<String> same = <String>[];

    (json['windows'] as Map<String, dynamic>).forEach((String window, dynamic value) {
      final Map<String, dynamic>? glass =
          (value as Map<String, dynamic>)['glass'] as Map<String, dynamic>?;
      if (glass == null) return;

      for (final String key in glass.keys) {
        if (!key.contains('rubberType=F')) continue;
        final String other = key.replaceAll('rubberType=F', 'rubberType=U');
        final List<dynamic>? panesU = glass[other] as List<dynamic>?;
        if (panesU == null) continue;
        pairs++;

        String describe(List<dynamic> panes) => panes
            .map((dynamic p) =>
                '${formulas[(p as Map<String, dynamic>)['h'] as int]}'
                'x${formulas[p['w'] as int]}')
            .join('|');

        if (describe(glass[key] as List<dynamic>) == describe(panesU)) {
          same.add('$window $key');
        }
      }
    });

    expect(pairs, greaterThan(300), reason: 'the catalogue should carry both rubbers');
    expect(same, isEmpty, reason: 'these cut the same glass for U as for F');
  });
}
