import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/formulas/data/formula_book.dart';
import 'package:my_app/features/formulas/data/formula_catalogue.dart';
import 'package:my_app/features/formulas/data/window_cut_calculator.dart';
import 'package:my_app/features/formulas/model/formula_overrides.dart';

/// Every M_Section window cuts its M23 and M28 to the height less 1'' 6'''
/// now (Hashir, Oct 2026): 4.445 cm, in place of 4.3 (4.2 on the corners)
/// -- sliding, panel and corner, every collar and lock, measured in inches
/// or centimetres, and the Economy M windows built on them (ET23, ET28).
void main() {
  final FormulaCatalogue catalogue = FormulaCatalogue.fromJson(
    jsonDecode(File('assets/formulas/catalogue.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final WindowCutCalculator calculator =
      WindowCutCalculator(FormulaBook(catalogue, FormulaOverrides.empty()));

  const double margin = 0.3;
  const double feet = 30.48;

  /// 48 inches high, as the inch screen sends it and as the centimetre one
  /// does: the same window.
  const double height = 121.92;
  final double expected = (height - 4.445 + margin) / feet;

  const Map<String, int> collars = <String, int>{
    'MS_win': 14,
    'MPF3_win': 14,
    'MPS4_win': 14,
    'MEF3_win': 14,
    'MSCF_win': 2,
    'MSCS_win': 2,
    'MSCL_win': 2,
    'MSCR_win': 2,
    'MSE_win': 14,
    'MSEA_win': 14,
  };

  const Set<String> stiles = <String>{'M23', 'M28', 'ET23', 'ET28'};

  for (final bool inches in <bool>[true, false]) {
    final String unit = inches ? 'inches' : 'centimetres';

    test('M23 and M28 are the height less 1\'\' 6\'\'\', in $unit', () {
      int checked = 0;
      for (final MapEntry<String, int> window in collars.entries) {
        for (int collar = 1; collar <= window.value; collar++) {
          for (final int lock in <int>[1, 2, 3]) {
            final WindowCutList list = calculator.compute(
              WindowCutRequest(
                isFabrication: true,
                appWindowCode: window.key,
                collarIndex: collar,
                unitMode: inches ? 'inches' : 'feet',
                heightValue: inches ? '48' : '121.92',
                widthValue: inches ? '72' : '182.88',
                lockType: lock,
                rubberType: 'F',
              ),
              margins: const <String, double>{'cm': margin},
            );
            if (list.problems.isNotEmpty) continue;
            final Iterable<CutPiece> heights = list.pieces.where(
              (CutPiece p) => stiles.contains(p.section) && p.label.startsWith('H'),
            );
            expect(heights, isNotEmpty, reason: '${window.key} c$collar l$lock');
            for (final CutPiece piece in heights) {
              expect(
                piece.lengthFt,
                closeTo(expected, 1e-3),
                reason: '${window.key} c$collar l$lock ${piece.section} ${piece.label}',
              );
              checked++;
            }
          }
        }
      }
      expect(checked, greaterThan(500));
    });
  }

  test('the plain sliding window keeps its own: M23 is still the height less 4.2', () {
    final WindowCutList list = calculator.compute(
      const WindowCutRequest(
        isFabrication: true,
        appWindowCode: 'S_win',
        collarIndex: 2,
        unitMode: 'feet',
        heightValue: '121.92',
        widthValue: '182.88',
        lockType: 1,
        rubberType: 'F',
      ),
      margins: const <String, double>{'cm': margin},
    );
    final CutPiece m23 = list.pieces.firstWhere((CutPiece p) => p.section == 'M23');
    expect(m23.lengthFt, closeTo((height - 4.2 + margin) / feet, 1e-3));
  });
}
