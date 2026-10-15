import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/formulas/data/formula_book.dart';
import 'package:my_app/features/formulas/data/formula_catalogue.dart';
import 'package:my_app/features/formulas/data/window_cut_calculator.dart';
import 'package:my_app/features/formulas/model/formula_overrides.dart';

/// Two D29 slips found going through every window after the fix window's D41
/// (Hashir, Oct 2026):
///
/// - The M-series sliding corner window takes no D29, but its Left Fix with a
///   latch cut four pieces of it -- left behind when it was copied from the
///   DC corner window.
/// - The three-panel window takes one net whatever the lock. With a self lock
///   it was cut twice over: eight pieces of D29 where latch and handal cut four.
void main() {
  final FormulaCatalogue catalogue = FormulaCatalogue.fromJson(
    jsonDecode(File('assets/formulas/catalogue.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final WindowCutCalculator calculator =
      WindowCutCalculator(FormulaBook(catalogue, FormulaOverrides.empty()));

  const double margin = 0.3;
  const double feet = 30.48;

  WindowCutList cut(
    String code, {
    required int collar,
    required int lock,
    String rubber = 'F',
    String? left,
    String? right,
  }) {
    return calculator.compute(
      WindowCutRequest(
        isFabrication: true,
        appWindowCode: code,
        collarIndex: collar,
        unitMode: 'inches',
        heightValue: '48',
        widthValue: '72',
        leftWidthValue: left,
        rightWidthValue: right,
        lockType: lock,
        rubberType: rubber,
      ),
      margins: const <String, double>{'cm': margin},
    );
  }

  Iterable<CutPiece> d29(WindowCutList list) =>
      list.pieces.where((CutPiece p) => p.section == 'D29');

  test('the M-series corner window cuts no D29, any type, lock or collar', () {
    for (final String code in <String>['MSCF_win', 'MSCS_win', 'MSCR_win', 'MSCL_win']) {
      for (int collar = 1; collar <= 2; collar++) {
        // Center slide offers latch and self only.
        final List<int> locks = code == 'MSCS_win' ? <int>[1, 2] : <int>[1, 2, 3];
        for (final int lock in locks) {
          for (final String rubber in <String>['F', 'U']) {
            final WindowCutList list =
                cut(code, collar: collar, lock: lock, rubber: rubber, left: '40', right: '30');
            expect(list.problems, isEmpty, reason: '$code $collar $lock $rubber');
            expect(d29(list), isEmpty, reason: '$code collar $collar lock $lock $rubber');
          }
        }
      }
    }
  });

  test('the DC corner window keeps its D29 on the Left Fix with a latch', () {
    final WindowCutList list = cut('SCL_win', collar: 1, lock: 1, left: '40', right: '30');
    expect(list.problems, isEmpty);
    expect(d29(list), hasLength(4));
  });

  test('the three-panel window cuts one net with every lock', () {
    const double width = 72 * 2.54;
    const double height = 48 * 2.54;
    for (int collar = 1; collar <= 14; collar++) {
      for (final int lock in <int>[1, 2, 3]) {
        for (final String rubber in <String>['F', 'U']) {
          final WindowCutList list = cut('EF3_win', collar: collar, lock: lock, rubber: rubber);
          expect(list.problems, isEmpty, reason: 'collar $collar lock $lock $rubber');
          final List<CutPiece> net = d29(list).toList();
          expect(net, hasLength(4), reason: 'collar $collar lock $lock $rubber');
          expect(net.map((CutPiece p) => p.label).toList()..sort(),
              <String>['HL', 'HR', 'WB', 'WT']);
          for (final CutPiece side in net.where((CutPiece p) => p.label.startsWith('H'))) {
            expect(side.lengthFt, closeTo((height - 4.2 + margin) / feet, 1e-6));
          }
          if (lock == 2) {
            // The self lock keeps its own top and bottom, once each.
            for (final CutPiece rail in net.where((CutPiece p) => p.label.startsWith('W'))) {
              expect(rail.lengthFt, closeTo(((width - 20.4) / 3 + 9 + margin) / feet, 1e-6));
            }
          }
        }
      }
    }
  });

  test('the other panel windows keep their two nets', () {
    for (final String code in <String>['PF3_win', 'PS4_win']) {
      final WindowCutList list = cut(code, collar: 1, lock: 2);
      expect(list.problems, isEmpty, reason: code);
      expect(d29(list), hasLength(8), reason: code);
    }
  });
}
