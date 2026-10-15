import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/formulas/data/formula_book.dart';
import 'package:my_app/features/formulas/data/formula_catalogue.dart';
import 'package:my_app/features/formulas/data/window_cut_calculator.dart';
import 'package:my_app/features/formulas/model/formula_overrides.dart';

/// The fix window's D41 runs round the glass: its sides are H - 3.4 and its
/// top and bottom W - 3.4 (Hashir, Oct 2026). The top and bottom used to be
/// H - 3.4 as well, which cut a tall fix window's bead as four heights -- far
/// more D41 than its D54A frame, where the two should come out about level.
/// Every collar, in inches and in centimetres, and the D51 and D42 box fix
/// windows built on it.
void main() {
  final FormulaCatalogue catalogue = FormulaCatalogue.fromJson(
    jsonDecode(File('assets/formulas/catalogue.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final WindowCutCalculator calculator =
      WindowCutCalculator(FormulaBook(catalogue, FormulaOverrides.empty()));

  const double margin = 0.3;
  const double feet = 30.48;

  /// 110 inches high and 24 wide, as the inch screen sends it and as the
  /// centimetre one does: a tall fix window, like the one reported.
  const double height = 279.4;
  const double width = 60.96;

  WindowCutList cut({
    required String code,
    required int collar,
    required bool inches,
  }) {
    return calculator.compute(
      WindowCutRequest(
        isFabrication: true,
        appWindowCode: code,
        collarIndex: collar,
        // Fabrication's centimetre screen sends its sizes as "feet".
        unitMode: inches ? 'inches' : 'feet',
        heightValue: inches ? '110' : '279.4',
        widthValue: inches ? '24' : '60.96',
      ),
      margins: const <String, double>{'cm': margin},
    );
  }

  double lengthOf(WindowCutList list, String section, String label) => list.pieces
      .firstWhere((CutPiece p) => p.section == section && p.label == label)
      .lengthFt;

  final double side = (height - 3.4 + margin) / feet;
  final double rail = (width - 3.4 + margin) / feet;

  for (final bool inches in <bool>[true, false]) {
    final String unit = inches ? 'inches' : 'centimetres';

    test('every collar, in $unit: D41 sides from H, top and bottom from W', () {
      for (int collar = 1; collar <= 14; collar++) {
        final WindowCutList list = cut(code: 'F_win', collar: collar, inches: inches);
        expect(list.problems, isEmpty, reason: 'collar $collar');
        expect(lengthOf(list, 'D41', 'HL'), closeTo(side, 1e-3), reason: 'collar $collar');
        expect(lengthOf(list, 'D41', 'HR'), closeTo(side, 1e-3), reason: 'collar $collar');
        expect(lengthOf(list, 'D41', 'WT'), closeTo(rail, 1e-3), reason: 'collar $collar');
        expect(lengthOf(list, 'D41', 'WB'), closeTo(rail, 1e-3), reason: 'collar $collar');
      }
    });

    test('the bead comes out level with the frame, in $unit', () {
      final WindowCutList list = cut(code: 'F_win', collar: 2, inches: inches);
      double total(String section) => list.pieces
          .where((CutPiece p) => p.section == section)
          .fold(0.0, (double sum, CutPiece p) => sum + p.lengthFt);
      // Four pieces of each, the bead 3.4 cm shorter on every side.
      expect(total('D54A') - total('D41'), closeTo(4 * 3.4 / feet, 1e-3));
    });

    test('the box fix windows follow it, in $unit', () {
      for (final String code in <String>['F_win_D51', 'F_win_D42']) {
        final WindowCutList list = cut(code: code, collar: 2, inches: inches);
        expect(list.problems, isEmpty, reason: code);
        expect(lengthOf(list, 'D41', 'WT'), closeTo(rail, 1e-3), reason: code);
        expect(lengthOf(list, 'D41', 'WB'), closeTo(rail, 1e-3), reason: code);
        expect(lengthOf(list, 'D41', 'HL'), closeTo(side, 1e-3), reason: code);
      }
    });

    test('the frame did not move, in $unit', () {
      final WindowCutList list = cut(code: 'F_win', collar: 2, inches: inches);
      expect(lengthOf(list, 'D54A', 'HL'), closeTo((height + margin) / feet, 1e-3));
      expect(lengthOf(list, 'D54A', 'WT'), closeTo((width + margin) / feet, 1e-3));
      final WindowCutList d54f = cut(code: 'F_win', collar: 1, inches: inches);
      expect(lengthOf(d54f, 'D54F', 'HL'), closeTo((height + 6 + margin) / feet, 1e-3));
      expect(lengthOf(d54f, 'D54F', 'WT'), closeTo((width + 6 + margin) / feet, 1e-3));
    });
  }
}
