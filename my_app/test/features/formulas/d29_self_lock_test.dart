import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/formulas/data/formula_book.dart';
import 'package:my_app/features/formulas/data/formula_catalogue.dart';
import 'package:my_app/features/formulas/data/window_cut_calculator.dart';
import 'package:my_app/features/formulas/model/formula_overrides.dart';

/// The sliding window with a self lock cuts its D29 top and bottom to
/// (W - 15.5) / 2 + 7.6 now, in place of (W - 17.2) / 2 + 9 (Hashir,
/// Oct 2026) -- every collar, both rubbers, measured in inches or in
/// centimetres, and in the B, BA and Economy frames built on it. Nothing
/// else the window cuts moves.
void main() {
  final FormulaCatalogue catalogue = FormulaCatalogue.fromJson(
    jsonDecode(File('assets/formulas/catalogue.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final WindowCutCalculator calculator =
      WindowCutCalculator(FormulaBook(catalogue, FormulaOverrides.empty()));

  const double margin = 0.3;
  const double feet = 30.48;

  /// 72 inches wide, as the inch screen sends it and as the centimetre one
  /// does: the same window.
  const double width = 182.88;

  WindowCutList cut({
    required String code,
    required int collar,
    required int lock,
    required String rubber,
    required bool inches,
  }) {
    return calculator.compute(
      WindowCutRequest(
        isFabrication: true,
        appWindowCode: code,
        collarIndex: collar,
        // Fabrication's centimetre screen sends its sizes as "feet".
        unitMode: inches ? 'inches' : 'feet',
        heightValue: inches ? '48' : '121.92',
        widthValue: inches ? '72' : '182.88',
        lockType: lock,
        rubberType: rubber,
      ),
      margins: const <String, double>{'cm': margin},
    );
  }

  double lengthOf(WindowCutList list, String section, String label) => list.pieces
      .firstWhere((CutPiece p) => p.section == section && p.label == label)
      .lengthFt;

  final double now = ((width - 15.5) / 2 + 7.6 + margin) / feet;
  final double before = ((width - 17.2) / 2 + 9 + margin) / feet;

  for (final bool inches in <bool>[true, false]) {
    final String unit = inches ? 'inches' : 'centimetres';

    test('self lock, every collar and rubber, in $unit: D29 WT and WB', () {
      for (int collar = 1; collar <= 14; collar++) {
        for (final String rubber in <String>['F', 'U']) {
          final WindowCutList list = cut(
            code: 'S_win',
            collar: collar,
            lock: 2,
            rubber: rubber,
            inches: inches,
          );
          expect(list.problems, isEmpty, reason: 'collar $collar $rubber');
          for (final String label in <String>['WT', 'WB']) {
            final double length = lengthOf(list, 'D29', label);
            expect(length, closeTo(now, 1e-3), reason: 'collar $collar $rubber $label');
            expect((length - before).abs(), greaterThan(0.01));
          }
        }
      }
    });

    test('the frames built on the sliding window follow it, in $unit', () {
      for (final String code in <String>['SB_win', 'SBA_win', 'SE_win']) {
        final WindowCutList list = cut(
          code: code,
          // The B and BA frames come without a collar, which is collar 2.
          collar: 2,
          lock: 2,
          rubber: 'F',
          inches: inches,
        );
        expect(list.problems, isEmpty, reason: code);
        final Iterable<CutPiece> rails = list.pieces.where(
          (CutPiece p) => p.label == 'WT' || p.label == 'WB',
        );
        final Iterable<CutPiece> d29 = rails.where(
          (CutPiece p) => (p.lengthFt - now).abs() < 1e-3,
        );
        expect(d29, hasLength(2), reason: '$code: its D29 top and bottom');
      }
    });

    test('nothing else changed, in $unit', () {
      final WindowCutList self = cut(
        code: 'S_win',
        collar: 2,
        lock: 2,
        rubber: 'F',
        inches: inches,
      );
      // The self lock's M24 is still (W - 17.2) / 2.
      expect(
        lengthOf(self, 'M24', 'W1'),
        closeTo(((width - 17.2) / 2 + margin) / feet, 1e-3),
      );
      // Latch and handle locks keep their own D29.
      final WindowCutList latch = cut(
        code: 'S_win',
        collar: 2,
        lock: 1,
        rubber: 'F',
        inches: inches,
      );
      expect(
        lengthOf(latch, 'D29', 'WT'),
        closeTo(((width - 15.5) / 2 + 8.5 + margin) / feet, 1e-3),
      );
      final WindowCutList handle = cut(
        code: 'S_win',
        collar: 2,
        lock: 3,
        rubber: 'F',
        inches: inches,
      );
      expect(
        lengthOf(handle, 'D29', 'WT'),
        closeTo(((width - 15.5) / 2 + 5.5 + margin) / feet, 1e-3),
      );
    });
  }
}
