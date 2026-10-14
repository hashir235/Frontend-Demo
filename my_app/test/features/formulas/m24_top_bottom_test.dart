import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/formulas/data/formula_book.dart';
import 'package:my_app/features/formulas/data/formula_catalogue.dart';
import 'package:my_app/features/formulas/data/window_cut_calculator.dart';
import 'package:my_app/features/formulas/model/formula_overrides.dart';
import 'package:my_app/features/formulas/model/window_sides.dart';

/// The M24 rails of a window measured side by side (Hashir, Oct 2026): with
/// its top and bottom more than 2 suter apart, the top rails are cut to the
/// top width and the bottom rails to the bottom. Up to 2 suter apart -- or
/// measured the usual way -- every M24 is cut to the smaller width. "Cut M24
/// in fours" no longer decides this; it only groups the bars.
///
/// Run against the real shipped catalogue: what matters is that the rails
/// Quick AL actually carries are told top from bottom correctly.
void main() {
  late FormulaCatalogue catalogue;

  setUpAll(() {
    catalogue = FormulaCatalogue.fromJson(
      jsonDecode(File('assets/formulas/catalogue.json').readAsStringSync())
          as Map<String, dynamic>,
    );
  });

  const Map<String, double> margins = <String, double>{'cm': 0.5};
  WindowCutCalculator calculator() =>
      WindowCutCalculator(FormulaBook(catalogue, FormulaOverrides.empty()));

  WindowCutRequest window(
    String code, {
    SideSizes sides = const SideSizes.empty(),
    String width = '98',
    String? left,
    String? right,
    String unit = 'cm',
    int collar = 2,
  }) {
    return WindowCutRequest(
      isFabrication: true,
      appWindowCode: code,
      collarIndex: collar,
      unitMode: unit,
      heightValue: unit == 'cm' ? '120' : '47',
      widthValue: width,
      leftWidthValue: left,
      rightWidthValue: right,
      lockType: 1,
      rubberType: 'F',
      sideSizes: sides,
    );
  }

  /// The M24 rails of a cut list (under any of its names), in order.
  List<CutPiece> rails(WindowCutList cut) => <CutPiece>[
    for (final CutPiece piece in cut.pieces)
      if (m24Sections.contains(piece.section)) piece,
  ];

  List<double> lengthsOf(List<CutPiece> pieces) =>
      <double>[for (final CutPiece p in pieces) p.lengthFt];

  const SideSizes apart = SideSizes(<String, String>{
    'WT': '100',
    'WB': '98',
    'HL': '120',
    'HR': '120',
  });

  group('a sliding window, top 100 cm and bottom 98 cm', () {
    test('W1 W2 to the top, W3 W4 to the bottom', () {
      final WindowCutList cut = calculator().compute(
        window('S_win', sides: apart),
        margins: margins,
      );
      expect(cut.problems, isEmpty);
      final List<CutPiece> m24 = rails(cut);
      expect(m24.map((CutPiece p) => p.label), <String>['W1', 'W2', 'W3', 'W4']);

      final List<CutPiece> atTop =
          rails(calculator().compute(window('S_win', width: '100'), margins: margins));
      final List<CutPiece> atBottom =
          rails(calculator().compute(window('S_win', width: '98'), margins: margins));
      expect(m24[0].lengthFt, closeTo(atTop[0].lengthFt, 1e-12));
      expect(m24[1].lengthFt, closeTo(atTop[1].lengthFt, 1e-12));
      expect(m24[2].lengthFt, closeTo(atBottom[2].lengthFt, 1e-12));
      expect(m24[3].lengthFt, closeTo(atBottom[3].lengthFt, 1e-12));
      expect(m24[0].lengthFt, greaterThan(m24[2].lengthFt));
    });

    test('the glass stays at the smaller width', () {
      final WindowCutList cut = calculator().compute(
        window('S_win', sides: apart),
        margins: margins,
      );
      final WindowCutList atBottom =
          calculator().compute(window('S_win', width: '98'), margins: margins);
      expect(
        cut.glass.map((GlassPiece g) => '${g.heightCm}x${g.widthCm}'),
        atBottom.glass.map((GlassPiece g) => '${g.heightCm}x${g.widthCm}'),
      );
    });
  });

  group('how far apart is far enough: more than 2 suter', () {
    List<double> railsFor(Map<String, String> sides, String unit) => lengthsOf(rails(
      calculator().compute(
        window('S_win', sides: SideSizes(sides), unit: unit, width: sides['WB']!),
        margins: margins,
      ),
    ));
    List<double> plainFor(Map<String, String> sides, String unit) => lengthsOf(rails(
      calculator().compute(
        window('S_win', unit: unit, width: sides['WB']!),
        margins: margins,
      ),
    ));

    test('3 suter apart: split', () {
      // 40" and 39" 5 suter.
      const Map<String, String> sides = <String, String>{
        'WT': '40', 'WB': '39.5', 'HL': '47', 'HR': '47',
      };
      final List<double> m24 = railsFor(sides, 'inches');
      expect(m24[0], greaterThan(m24[2]));
      expect(m24[0], closeTo(m24[1], 1e-12));
      expect(m24[2], closeTo(m24[3], 1e-12));
    });

    test('2½ suter apart: split', () {
      const Map<String, String> sides = <String, String>{
        'WT': '40', 'WB': '39.55', 'HL': '47', 'HR': '47',
      };
      final List<double> m24 = railsFor(sides, 'inches');
      expect(m24[0], greaterThan(m24[2]));
    });

    test('exactly 2 suter apart: not split', () {
      // 40" and 39" 6 suter.
      const Map<String, String> sides = <String, String>{
        'WT': '40', 'WB': '39.6', 'HL': '47', 'HR': '47',
      };
      expect(railsFor(sides, 'inches'), plainFor(sides, 'inches'));
    });

    test('1½ suter apart: not split', () {
      const Map<String, String> sides = <String, String>{
        'WT': '40', 'WB': '39.65', 'HL': '47', 'HR': '47',
      };
      expect(railsFor(sides, 'inches'), plainFor(sides, 'inches'));
    });

    test('in centimetres: 0.635 apart not split, 0.7 apart split', () {
      const Map<String, String> near = <String, String>{
        'WT': '100', 'WB': '99.365', 'HL': '120', 'HR': '120',
      };
      expect(railsFor(near, 'cm'), plainFor(near, 'cm'));
      const Map<String, String> far = <String, String>{
        'WT': '100', 'WB': '99.3', 'HL': '120', 'HR': '120',
      };
      final List<double> m24 = railsFor(far, 'cm');
      expect(m24[0], greaterThan(m24[2]));
    });

    test('the bottom wider than the top works the same way round', () {
      final List<CutPiece> m24 = rails(calculator().compute(
        window(
          'S_win',
          sides: const SideSizes(<String, String>{
            'WT': '98', 'WB': '100', 'HL': '120', 'HR': '120',
          }),
        ),
        margins: margins,
      ));
      expect(m24[2].lengthFt, greaterThan(m24[0].lengthFt), reason: 'bottom rails to the wider bottom');
    });

    test('measured the usual way (two boxes): never split', () {
      final WindowCutList plain =
          calculator().compute(window('S_win', width: '98'), margins: margins);
      expect(rails(plain).map((CutPiece p) => p.lengthFt).toSet(), hasLength(1));
    });
  });

  group('the other windows', () {
    test('three panels: the first three rails the top, the last three the bottom', () {
      final WindowCutList cut = calculator().compute(
        window('PF3_win', sides: apart, collar: 1),
        margins: margins,
      );
      expect(cut.problems, isEmpty);
      final List<CutPiece> m24 = rails(cut);
      expect(m24, hasLength(6));
      final List<CutPiece> atTop = rails(calculator().compute(
          window('PF3_win', width: '100', collar: 1), margins: margins));
      final List<CutPiece> atBottom = rails(calculator().compute(
          window('PF3_win', width: '98', collar: 1), margins: margins));
      for (int i = 0; i < 6; i++) {
        expect(
          m24[i].lengthFt,
          closeTo((i < 3 ? atTop : atBottom)[i].lengthFt, 1e-12),
          reason: '${m24[i].label} is ${i < 3 ? 'a top' : 'a bottom'} rail',
        );
      }
    });

    test('four panels: four top, four bottom', () {
      final List<CutPiece> m24 = rails(calculator().compute(
        window('PS4_win', sides: apart, collar: 1),
        margins: margins,
      ));
      expect(m24, hasLength(8));
      expect(m24.take(4).map((CutPiece p) => p.lengthFt).toSet(), hasLength(1));
      expect(m24.skip(4).map((CutPiece p) => p.lengthFt).toSet(), hasLength(1));
      expect(m24.first.lengthFt, greaterThan(m24.last.lengthFt));
    });

    test('a corner: each wall on its own top and bottom', () {
      final WindowCutList cut = calculator().compute(
        window(
          'SCF_win',
          collar: 1,
          left: '100',
          right: '80',
          width: '80',
          sides: const SideSizes(<String, String>{
            'WT_l': '100',
            'WB_l': '98',
            // The right wall only half a centimetre out: not split.
            'WT_r': '80.5',
            'WB_r': '80',
            'HL': '120',
            'HR': '120',
          }),
        ),
        margins: margins,
      );
      expect(cut.problems, isEmpty);
      final List<CutPiece> m24 = rails(cut);
      final List<CutPiece> left =
          m24.where((CutPiece p) => p.label.startsWith('WL')).toList();
      final List<CutPiece> right =
          m24.where((CutPiece p) => p.label.startsWith('WR')).toList();
      expect(left.map((CutPiece p) => p.label), <String>['WL1', 'WL2', 'WL3', 'WL4']);
      expect(left[0].lengthFt, closeTo(left[1].lengthFt, 1e-12));
      expect(left[2].lengthFt, closeTo(left[3].lengthFt, 1e-12));
      expect(left[0].lengthFt, greaterThan(left[2].lengthFt), reason: 'left wall split');
      expect(right.map((CutPiece p) => p.lengthFt).toSet(), hasLength(1),
          reason: 'right wall within 2 suter: all to the smaller');
    });

    test('the Economy windows: ET24 split the same way', () {
      final List<CutPiece> m24 = rails(calculator().compute(
        window('MSE_win', sides: apart, collar: 1),
        margins: margins,
      ));
      expect(m24.map((CutPiece p) => p.section).toSet(), <String>{'ET24'});
      expect(m24[0].lengthFt, greaterThan(m24[2].lengthFt));
    });
  });
}
