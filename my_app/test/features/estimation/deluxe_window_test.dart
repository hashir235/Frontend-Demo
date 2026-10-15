import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/data/optimization_api_client.dart';
import 'package:my_app/features/estimation/data/optimization_repository.dart';
import 'package:my_app/features/estimation/data/window_catalog.dart';
import 'package:my_app/features/estimation/data/window_sections.dart';
import 'package:my_app/features/estimation/models/collar_layout.dart';
import 'package:my_app/features/estimation/models/cutting_report.dart';
import 'package:my_app/features/estimation/models/optimization_request.dart';
import 'package:my_app/features/estimation/models/window_material.dart';
import 'package:my_app/features/estimation/models/window_review_item.dart';
import 'package:my_app/features/estimation/models/window_variant.dart';
import 'package:my_app/features/estimation/presentation/input/input_registry.dart';
import 'package:my_app/features/estimation/state/estimate_session_store.dart';
import 'package:my_app/features/estimation/state/last_window_material.dart';
import 'package:my_app/features/estimation/widgets/collar_side_picker.dart';
import 'package:my_app/features/estimation/widgets/own_sliding_overlay.dart';
import 'package:my_app/features/estimation/widgets/sliding_section_overlay.dart';
import 'package:my_app/features/formulas/data/formula_book.dart';
import 'package:my_app/features/formulas/data/formula_book_loader.dart';
import 'package:my_app/features/formulas/data/formula_catalogue.dart';
import 'package:my_app/features/formulas/data/window_cut_calculator.dart';
import 'package:my_app/features/formulas/model/formula_overrides.dart';
import 'package:my_app/features/formulas/model/formula_window_key.dart';
import 'package:my_app/features/formulas/model/window_sides.dart';
import 'package:my_app/features/settings/data/estimation_settings_repository.dart';
import 'package:my_app/features/settings/data/fabrication_settings_repository.dart';
import 'package:my_app/features/settings/models/estimation_settings.dart';
import 'package:my_app/features/settings/models/fabrication_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The DELUXE sliding window (Hashir, Oct 2026): a plain two-panel sliding
/// window with no collar, 0.9mm only, D29 only when switched on, and in
/// fabrication Hashir's final sizes -- given in inches and suter -- and its
/// two panes of glass. Its frame is D30, D27 and D26A; inside it M23, M28,
/// D25 and M24, the first three priced as on every sliding window.
void main() {
  final FormulaCatalogue catalogue = FormulaCatalogue.fromJson(
    jsonDecode(File('assets/formulas/catalogue.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final FormulaBook book = FormulaBook(catalogue, FormulaOverrides.empty());
  final WindowCutCalculator calculator = WindowCutCalculator(book);

  const String code = 'SDX_win';
  const double feet = 30.48;
  const List<String> profiles = <String>[
    'D30', 'D27', 'D26A', 'M23', 'M28', 'D25', 'M24', 'D29',
  ];

  group('the window', () {
    test('a sliding window to the engine, at collar 2, cut its own way', () {
      final WindowVariant variant = WindowVariants.of(code)!;
      expect(variant.baseCode, 'S_win');
      expect(variant.collars, <int>[2]);
      final OwnWindow own = variant.own!;
      expect(own.sections, profiles);
      expect(own.netSection, 'D29');
      expect(own.frame, <String>{'D30', 'D27', 'D26A'});
      expect(own.gauges, <String>['0.9mm']);
      expect(own.estimation.keys.toSet(), own.sections.toSet());
      expect(own.fabrication.keys.toSet(), own.sections.toSet());
    });

    test('the finishes go by the usual names', () {
      final OwnWindow own = WindowVariants.ownOf(code)!;
      expect(own.hasOwnColorNames, isFalse);
      // The Prime Economy window keeps Prime's.
      expect(WindowVariants.ownOf('SPE_win')!.hasOwnColorNames, isTrue);
    });

    test('in the library, a section of its own, both flows', () {
      for (final bool fabrication in <bool>[false, true]) {
        final List<WindowGroup> groups =
            WindowCatalog.groupsForFlow(isFabrication: fabrication);
        expect(groups.map((WindowGroup g) => g.id),
            <String>['sliding', 'economy', 'deluxe', 'box', 'double_glaze']);
        final WindowGroup deluxe = groups.firstWhere((WindowGroup g) => g.id == 'deluxe');
        expect(deluxe.title, 'DELUXE Windows');
        expect(deluxe.rows.single.nodes.single.codeName, code);
      }
      expect(WindowCatalog.byCodeName(code)!.label, 'DELUXE Sliding Window');
      expect(WindowCatalog.byDisplayIndex(57)!.codeName, code);
      expect(WindowCatalog.allTypeNames, contains('DELUXE Sliding Window'),
          reason: 'its own hardware rate on the bill');
    });

    test('its card lists its own profiles, D29 as the net', () {
      for (final bool fabrication in <bool>[false, true]) {
        expect(
          WindowSections.of(code, isFabrication: fabrication).map((UsedSection s) => s.label),
          <String>['D30', 'D27', 'D26A', 'M23', 'M28', 'D25', 'M24', 'D29 (net)'],
        );
      }
    });

    test('every one of its profiles lights its part of the drawing', () {
      final Map<String, Set<SlidingPart>> parts = OwnSlidingOverlay.partsFor(code);
      expect(parts.keys.toSet(), profiles.toSet());
      expect(parts['D30'], <SlidingPart>{SlidingPart.leftJamb, SlidingPart.rightJamb});
      expect(parts['D27'], <SlidingPart>{SlidingPart.head});
      expect(parts['D26A'], <SlidingPart>{SlidingPart.sill});
      expect(parts['M23'], <SlidingPart>{SlidingPart.outerStiles});
      expect(parts['M28'], <SlidingPart>{SlidingPart.centreStiles});
      expect(parts['D25'], <SlidingPart>{SlidingPart.topRails});
      expect(parts['M24'], <SlidingPart>{SlidingPart.bottomRails});
      expect(parts['D29'], <SlidingPart>{SlidingPart.net});
    });

    test("the sliding window's collar 2: one collar, none on any side", () {
      final CollarLayout layout = CollarLayout.forWindow(code)!;
      expect(layout.isFixed, isTrue);
      expect(layout.collars, <int>[2]);
      expect(layout.sidesWithCollar(2), isEmpty);
    });
  });

  group('estimation', () {
    const Map<String, double> margins = <String, double>{
      'cm_DC30C': 0.041,
      'cm_DC26C': 0.041,
      'cm_M23': 0.01,
      'cm_M24': 0.02,
      'cm_M28': 0.03,
      'cm_D29': 0.04,
    };

    WindowCutList cut(String window) => calculator.compute(
          WindowCutRequest(
            isFabrication: false,
            appWindowCode: window,
            collarIndex: 2,
            unitMode: 'inches',
            heightValue: '48',
            widthValue: '60',
          ),
          margins: margins,
        );

    Map<String, List<String>> bySection(WindowCutList list) {
      final Map<String, List<String>> out = <String, List<String>>{};
      for (final CutPiece piece in list.pieces) {
        out.putIfAbsent(piece.section, () => <String>[])
            .add('${piece.label} ${piece.lengthFt.toStringAsFixed(4)}');
      }
      return out;
    }

    test('kept out of the formulas: heights, the width, half the width', () {
      final WindowCutList list = cut(code);
      expect(list.problems, isEmpty);
      expect(bySection(list), <String, List<String>>{
        // 4ft high, 5ft wide, each with its margin.
        'D30': <String>['HL 4.0410', 'HR 4.0410'],
        'D27': <String>['WT 5.0410'],
        'D26A': <String>['WB 5.0410'],
        'M23': <String>['H 4.0100', 'H 4.0100'],
        'M28': <String>['H 4.0300', 'H 4.0300'],
        'D25': <String>['W1 2.5200', 'W2 2.5200'],
        'M24': <String>['W3 2.5200', 'W4 2.5200'],
        'D29': <String>['HL 4.0400', 'HR 4.0400', 'WT 2.5400', 'WB 2.5400'],
      });
    });

    test('piece for piece, the plain sliding window with no collar', () {
      const Map<String, (String, List<String>)> counterpart = <String, (String, List<String>)>{
        'D30': ('DC30C', <String>['HL', 'HR']),
        'D27': ('DC30C', <String>['WT']),
        'D26A': ('DC26C', <String>['WB']),
        'M23': ('M23', <String>['H', 'H']),
        'M28': ('M28', <String>['H', 'H']),
        'D25': ('M24', <String>['W1', 'W2']),
        'M24': ('M24', <String>['W3', 'W4']),
        'D29': ('D29', <String>['HL', 'HR', 'WT', 'WB']),
      };
      final WindowCutList mine = cut(code);
      final WindowCutList sliding = cut('S_win');
      for (final MapEntry<String, (String, List<String>)> entry in counterpart.entries) {
        final List<CutPiece> own =
            mine.pieces.where((CutPiece p) => p.section == entry.key).toList();
        final List<CutPiece> theirs = sliding.pieces
            .where((CutPiece p) => p.section == entry.value.$1 && entry.value.$2.contains(p.label))
            .toList();
        expect(own.map((CutPiece p) => p.label), entry.value.$2, reason: entry.key);
        expect(own.map((CutPiece p) => p.lengthFt),
            theirs.take(own.length).map((CutPiece p) => p.lengthFt),
            reason: '${entry.key} as ${entry.value.$1}');
      }
      expect(mine.pieces, hasLength(sliding.pieces.length));
    });
  });

  group('fabrication', () {
    WindowCutList cut({
      String unitMode = 'feet',
      String height = '120',
      String width = '150',
      double margin = 0,
      Set<String> leaveOut = const <String>{},
      SideSizes sides = const SideSizes.empty(),
    }) =>
        calculator.compute(
          WindowCutRequest(
            isFabrication: true,
            appWindowCode: code,
            collarIndex: 2,
            unitMode: unitMode,
            heightValue: height,
            widthValue: width,
            leaveOut: leaveOut,
            sideSizes: sides,
          ),
          margins: <String, double>{'cm': margin},
        );

    test('the inches and suter, in centimetres', () {
      const double inch = 2.54;
      expect(4 / 8 * inch, closeTo(1.27, 1e-12), reason: '4 suter');
      expect(1 * inch, closeTo(2.54, 1e-12), reason: '1 inch');
      expect((1 + 4 / 8) * inch, closeTo(3.81, 1e-12), reason: '1 inch 4 suter');
      expect((5 + 6 / 8) * inch, closeTo(14.605, 1e-12), reason: '5 inch 6 suter');
    });

    test("Hashir's sizes: D30 as is, 4 suter, 1 inch, (W - 5'' 6''') / 2, D29", () {
      final WindowCutList list = cut();
      expect(list.problems, isEmpty);
      double one(String section, String label) => list.pieces
          .firstWhere((CutPiece p) => p.section == section && p.label == label)
          .lengthFt;
      List<double> all(String section) => <double>[
        for (final CutPiece p in list.pieces)
          if (p.section == section) p.lengthFt * feet,
      ];

      const double h = 120;
      const double w = 150;
      // Frame.
      expect(one('D30', 'HL') * feet, closeTo(h, 1e-9));
      expect(one('D30', 'HR') * feet, closeTo(h, 1e-9));
      expect(one('D27', 'WT') * feet, closeTo(w - 1.27, 1e-9));
      expect(one('D26A', 'WB') * feet, closeTo(w - 1.27, 1e-9));
      // Inside.
      expect(all('M23'), <Matcher>[closeTo(h - 2.54, 1e-9), closeTo(h - 2.54, 1e-9)]);
      expect(all('M28'), <Matcher>[closeTo(h - 2.54, 1e-9), closeTo(h - 2.54, 1e-9)]);
      for (final String label in <String>['W1', 'W2']) {
        expect(one('D25', label) * feet, closeTo((w - 14.605) / 2, 1e-9));
      }
      for (final String label in <String>['W3', 'W4']) {
        expect(one('M24', label) * feet, closeTo((w - 14.605) / 2, 1e-9));
      }
      // The net: 1 inch 4 suter short of the height, half the width as it is.
      expect(one('D29', 'HL') * feet, closeTo(h - 3.81, 1e-9));
      expect(one('D29', 'HR') * feet, closeTo(h - 3.81, 1e-9));
      expect(one('D29', 'WT') * feet, closeTo(w / 2, 1e-9));
      expect(one('D29', 'WB') * feet, closeTo(w / 2, 1e-9));

      // Eight profiles, sixteen pieces: 2 + 1 + 1 + 2 + 2 + 2 + 2 + 4.
      expect(<String, int>{
        for (final String s in profiles) s: all(s).length,
      }, <String, int>{
        'D30': 2, 'D27': 1, 'D26A': 1, 'M23': 2, 'M28': 2, 'D25': 2, 'M24': 2, 'D29': 4,
      });
      expect(list.pieces, hasLength(16));
    });

    test('measured in inches, the same cut', () {
      // 48" x 60" is 121.92 x 152.4 cm.
      final WindowCutList inches = cut(unitMode: 'inches', height: '48', width: '60');
      final WindowCutList cm = cut(height: '121.92', width: '152.4');
      expect(inches.problems, isEmpty);
      expect(
        inches.pieces.map((CutPiece p) => '${p.section} ${p.label} ${p.lengthFt.toStringAsFixed(6)}'),
        cm.pieces.map((CutPiece p) => '${p.section} ${p.label} ${p.lengthFt.toStringAsFixed(6)}'),
      );
    });

    test('the cutting margin is added for the saw, like every window', () {
      final WindowCutList plain = cut();
      final WindowCutList withMargin = cut(margin: 0.5);
      for (int i = 0; i < plain.pieces.length; i++) {
        expect(withMargin.pieces[i].lengthFt * feet,
            closeTo(plain.pieces[i].lengthFt * feet + 0.5, 1e-9));
      }
    });

    test("two panes of glass: H - 4'' 2''', ((W - 5'' 6''') / 2) + 2'''", () {
      expect((4 + 2 / 8) * 2.54, closeTo(10.795, 1e-12), reason: '4 inch 2 suter');
      expect(2 / 8 * 2.54, closeTo(0.635, 1e-12), reason: '2 suter');

      final WindowCutList list = cut();
      expect(list.glass, hasLength(2));
      for (final GlassPiece pane in list.glass) {
        expect(pane.heightCm, closeTo(120 - 10.795, 1e-9));
        expect(pane.widthCm, closeTo((150 - 14.605) / 2 + 0.635, 1e-9));
      }
      // No cutting margin on glass: the blade's allowance is aluminium's.
      final WindowCutList withMargin = cut(margin: 0.5);
      expect(withMargin.glass.first.heightCm, closeTo(120 - 10.795, 1e-9));

      // In the formula book as two panes, H and W, so a workshop can change
      // them on the formula screen like any other glass.
      final FormulaWindowKey key = FormulaWindowKey.of(
        context: 'fabrication',
        appWindowCode: code,
        dimensions: catalogue.dimensionsFor('fabrication/$code'),
        collarIndex: 2,
      )!;
      final List<EffectiveSection> panes = book.glassFor(key);
      expect(panes.map((EffectiveSection p) => p.section), <String>['glass1', 'glass2']);
      expect(
        panes.first.pieces.map((EffectiveFormula f) => f.slot.label),
        <String>['H', 'W'],
      );
    });

    test('measured in inches, the same glass', () {
      final WindowCutList inches = cut(unitMode: 'inches', height: '48', width: '60');
      final WindowCutList cm = cut(height: '121.92', width: '152.4');
      expect(inches.glass, hasLength(2));
      for (int i = 0; i < 2; i++) {
        expect(inches.glass[i].heightCm, closeTo(cm.glass[i].heightCm, 1e-9));
        expect(inches.glass[i].widthCm, closeTo(cm.glass[i].widthCm, 1e-9));
      }
      // 48" - 4 1/4" = 43 3/4"; (60" - 5 3/4") / 2 + 1/4" = 27 3/8".
      expect(inches.glass.first.heightCm, closeTo(43.75 * 2.54, 1e-9));
      expect(inches.glass.first.widthCm, closeTo(27.375 * 2.54, 1e-9));
    });

    test('the Prime Economy window still takes no glass', () {
      final WindowCutList list = calculator.compute(
        const WindowCutRequest(
          isFabrication: true,
          appWindowCode: 'SPE_win',
          collarIndex: 2,
          unitMode: 'feet',
          heightValue: '120',
          widthValue: '150',
        ),
        margins: <String, double>{'cm': 0},
      );
      expect(list.glass, isEmpty);
    });

    test('estimation cuts no glass here, as for every window', () {
      final WindowCutList list = calculator.compute(
        const WindowCutRequest(
          isFabrication: false,
          appWindowCode: code,
          collarIndex: 2,
          unitMode: 'inches',
          heightValue: '48',
          widthValue: '60',
        ),
        margins: <String, double>{},
      );
      expect(list.glass, isEmpty);
    });

    test('no lock and no rubber decide it: one set of formulas', () {
      expect(catalogue.dimensionsFor('fabrication/$code'), <String>{'collarType'});
      expect(catalogue.dimensionsFor('estimation/$code'), <String>{'collarType'});
    });

    test('measured side by side, more than 2 suter apart: each side its own', () {
      expect(catalogue.frameSectionsFor('fabrication/$code'),
          <String>{'D30', 'D27', 'D26A'});
      final WindowCutList list = cut(
        sides: const SideSizes(<String, String>{
          'WT': '150', 'WB': '148', 'HL': '120', 'HR': '119',
        }),
      );
      expect(list.problems, isEmpty);
      List<double> all(String section, [String? label]) => <double>[
        for (final CutPiece p in list.pieces)
          if (p.section == section && (label == null || p.label == label))
            p.lengthFt * feet,
      ];
      // The frame.
      expect(all('D27', 'WT').single, closeTo(150 - 1.27, 1e-9));
      expect(all('D26A', 'WB').single, closeTo(148 - 1.27, 1e-9));
      expect(all('D30', 'HL').single, closeTo(120, 1e-9));
      expect(all('D30', 'HR').single, closeTo(119, 1e-9));
      // Its top rails (D25) to the top, its bottom rails (M24) to the bottom.
      for (final double rail in all('D25')) {
        expect(rail, closeTo((150 - 14.605) / 2, 1e-9));
      }
      for (final double rail in all('M24')) {
        expect(rail, closeTo((148 - 14.605) / 2, 1e-9));
      }
      // Its outer stiles: the left one to the left, the right to the right.
      expect(all('M23'), <Matcher>[
        closeTo(120 - 2.54, 1e-9),
        closeTo(119 - 2.54, 1e-9),
      ]);
      // The stiles meeting at the centre: the smaller height.
      for (final double stile in all('M28')) {
        expect(stile, closeTo(119 - 2.54, 1e-9));
      }
      // The net, by its labels.
      expect(all('D29', 'HL').single, closeTo(120 - 3.81, 1e-9));
      expect(all('D29', 'HR').single, closeTo(119 - 3.81, 1e-9));
      expect(all('D29', 'WT').single, closeTo(150 / 2, 1e-9));
      expect(all('D29', 'WB').single, closeTo(148 / 2, 1e-9));
      // The glass: the smaller of each.
      for (final GlassPiece pane in list.glass) {
        expect(pane.heightCm, closeTo(119 - 10.795, 1e-9));
        expect(pane.widthCm, closeTo((148 - 14.605) / 2 + 0.635, 1e-9));
      }
    });

    test('up to 2 suter apart: the frame each side, everything inside the smaller', () {
      final WindowCutList apartByTwoSuter = cut(
        sides: const SideSizes(<String, String>{
          'WT': '150.635', 'WB': '150', 'HL': '120', 'HR': '120.5',
        }),
      );
      final WindowCutList plain = cut(height: '120', width: '150');
      expect(apartByTwoSuter.problems, isEmpty);
      String key(CutPiece p) => '${p.section} ${p.label}';
      for (int i = 0; i < plain.pieces.length; i++) {
        final CutPiece mine = apartByTwoSuter.pieces[i];
        final CutPiece theirs = plain.pieces[i];
        expect(key(mine), key(theirs));
        final double expected = switch (key(mine)) {
          'D27 WT' => (150.635 - 1.27) / feet,
          'D30 HR' => 120.5 / feet,
          _ => theirs.lengthFt,
        };
        expect(mine.lengthFt, closeTo(expected, 1e-9), reason: key(mine));
      }
    });

    test('D29 left out when off, everything else the same', () {
      final WindowCutList on = cut();
      final WindowCutList off = cut(leaveOut: const <String>{'D29'});
      expect(off.pieces.where((CutPiece p) => p.section == 'D29'), isEmpty);
      expect(
        off.pieces.map((CutPiece p) => '${p.section} ${p.label} ${p.lengthFt}'),
        on.pieces
            .where((CutPiece p) => p.section != 'D29')
            .map((CutPiece p) => '${p.section} ${p.label} ${p.lengthFt}'),
      );
    });
  });

  group('what the engine is sent', () {
    WindowReviewItem item({required bool net, required bool fabrication}) => WindowReviewItem(
      winNo: 1,
      windowLabel: 'DELUXE Sliding Window',
      windowCode: code,
      windowIndex: 57,
      collarIndex: 2,
      unitMode: fabrication ? UnitMode.cm : UnitMode.inches,
      heightValue: fabrication ? '120' : '48',
      widthValue: fabrication ? '150' : '60',
      addNet: net,
      material: const WindowMaterial(gauge: '0.9mm', color: AluminiumColors.milkyWhite),
    );

    Future<OptimizationRequest> send(WindowReviewItem window, {required bool fabrication}) async {
      final _Api api = _Api();
      final OptimizationRepository repository = OptimizationRepository(
        apiClient: api,
        formulas: _Loader(book),
        fabricationSettings: _FabricationSettings(),
        estimationSettings: _EstimationSettings(),
      );
      await expectLater(
        repository.fetchLengthOptimization(
          <WindowReviewItem>[window],
          context: fabrication ? 'fabrication' : 'estimation',
          projectName: 'Job',
          projectLocation: 'Here',
        ),
        throwsA(isA<_Sent>()),
      );
      return api.sent!;
    }

    for (final bool fabrication in <bool>[false, true]) {
      final String flow = fabrication ? 'fabrication' : 'estimation';

      test('$flow: as the sliding window, in 0.9mm, with its own pieces', () async {
        final OptimizationRequest sent =
            await send(item(net: false, fabrication: fabrication), fabrication: fabrication);
        final Map<String, Object?> json = sent.windows.single.toJson();
        expect(json['windowCode'], 'S_win');
        expect(json['gauge'], '0.9mm');
        // Priced at the champagne column by the engine, printed as picked.
        expect(json['color'], AluminiumColors.milkyWhite);
        final List<Map<String, Object?>> pieces = sent.windows.single.computedPieces!;
        expect(pieces.map((Map<String, Object?> p) => p['section']).toSet(),
            <String>{'D30', 'D27', 'D26A', 'M23', 'M28', 'D25', 'M24'},
            reason: 'D29 off: not cut');
        // Always sent, so the engine never cuts the sliding window's own
        // glass for it: its two panes in fabrication, none in estimation.
        expect(json.containsKey('computedGlass'), isTrue);
        final List<Map<String, Object?>> glass = sent.windows.single.computedGlass!;
        if (fabrication) {
          expect(glass, hasLength(2));
          for (final Map<String, Object?> pane in glass) {
            expect(pane['heightCm'] as double, closeTo(120 - 10.795, 1e-9));
            expect(pane['widthCm'] as double, closeTo((150 - 14.605) / 2 + 0.635, 1e-9));
          }
        } else {
          expect(glass, isEmpty);
        }
      });

      test('$flow: D29 switched on is cut', () async {
        final OptimizationRequest sent =
            await send(item(net: true, fabrication: fabrication), fabrication: fabrication);
        final List<Map<String, Object?>> d29 = sent.windows.single.computedPieces!
            .where((Map<String, Object?> p) => p['section'] == 'D29')
            .toList();
        expect(d29.map((Map<String, Object?> p) => p['piece']),
            <String>['HL', 'HR', 'WT', 'WB']);
      });
    }
  });

  group('the input screen', () {
    late EstimateSessionStore session;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      LastWindowMaterial.instance.resetForTest();
    });

    Future<void> open(
      WidgetTester tester,
      String window, {
      bool fabrication = false,
      bool keepSession = false,
    }) async {
      if (!keepSession) {
        session = EstimateSessionStore(
          projectName: 'P',
          projectLocation: 'L',
          flow: fabrication ? EstimateFlow.fabrication : EstimateFlow.estimation,
        );
      }
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          home: buildInputScreen(
            node: WindowCatalog.byCodeName(window)!,
            session: session,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> openSidebar(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('open_settings_drawer_button')));
      await tester.pumpAndSettle();
    }

    Finder inSidebar(String text) => find.descendant(
      of: find.byKey(const Key('settings_drawer')),
      matching: find.text(text),
    );

    Future<void> save(WidgetTester tester) async {
      final ScaffoldState scaffold = tester.firstState<ScaffoldState>(find.byType(Scaffold));
      if (scaffold.isEndDrawerOpen) {
        scaffold.closeEndDrawer();
        await tester.pumpAndSettle();
      }
      Finder field(String label) => find.byWidgetPredicate(
        (Widget w) => w is TextField && w.decoration?.labelText == label,
      );
      await tester.enterText(field('Width'), '60');
      await tester.enterText(field('Height'), '48');
      tester.widget<ButtonStyleButton>(find.byKey(const Key('input_save_button'))).onPressed!();
      await tester.pumpAndSettle();
    }

    testWidgets("the sliding window's collar 2 card, 0.9mm only, the usual names", (
      WidgetTester tester,
    ) async {
      await open(tester, code);
      expect(find.byKey(const Key('own_sliding_drawing')), findsOneWidget);
      expect(find.byType(CollarSidePicker), findsOneWidget);
      final SlidingSectionOverlay drawing =
          tester.widget<SlidingSectionOverlay>(find.byKey(const Key('own_sliding_drawing')));
      expect(drawing.collarId, 2);
      expect(find.text('Collar 2'), findsOneWidget);
      expect(find.text('This window has no collar on any side.'), findsOneWidget);
      expect(find.text('0.9mm'), findsOneWidget);
      expect(find.text('1.2mm'), findsNothing);
      expect(find.text('2mm'), findsNothing);
      // The finish it opens on, under the name every other window uses.
      expect(find.text('H23/PC-RAL (Champagne)'), findsOneWidget);
      expect(find.text('Chm/Ral Gold'), findsNothing);
    });

    testWidgets('picking a profile lights its part of the drawing', (
      WidgetTester tester,
    ) async {
      await open(tester, code);
      await openSidebar(tester);
      await tester.ensureVisible(inSidebar('D25'));
      await tester.pumpAndSettle();
      await tester.tap(inSidebar('D25'));
      await tester.pumpAndSettle();
      final ScaffoldState scaffold = tester.firstState<ScaffoldState>(find.byType(Scaffold));
      if (scaffold.isEndDrawerOpen) {
        scaffold.closeEndDrawer();
        await tester.pumpAndSettle();
      }
      final SlidingSectionOverlay drawing =
          tester.widget<SlidingSectionOverlay>(find.byKey(const Key('own_sliding_drawing')));
      expect(drawing.litParts, <SlidingPart>{SlidingPart.topRails});
    });

    testWidgets('fabrication asks no lock and no rubber', (WidgetTester tester) async {
      await open(tester, code, fabrication: true);
      expect(find.text('Latch'), findsNothing);
      expect(find.text('U'), findsNothing);
      expect(find.byKey(const Key('own_sliding_drawing')), findsOneWidget);
    });

    testWidgets('D29 is off for a new window, and saved off', (WidgetTester tester) async {
      await open(tester, code);
      await openSidebar(tester);
      expect(inSidebar('D29 Option'), findsOneWidget);
      expect(inSidebar('D29'), findsNothing, reason: 'not listed while off');
      for (final String section in profiles.where((String s) => s != 'D29')) {
        expect(inSidebar(section), findsOneWidget, reason: section);
      }
      await save(tester);
      final WindowReviewItem saved = session.items.single;
      expect(saved.windowCode, code);
      expect(saved.windowLabel, 'DELUXE Sliding Window');
      expect(saved.collarIndex, 2);
      expect(saved.addNet, isFalse);
      expect(saved.material.gauge, '0.9mm');
      expect(saved.lockType, isNull);
    });

    testWidgets('D29 switched on: listed, saved, and remembered for the next one', (
      WidgetTester tester,
    ) async {
      await open(tester, code);
      await openSidebar(tester);
      await tester.ensureVisible(inSidebar('D29 On'));
      await tester.tap(inSidebar('D29 On'));
      await tester.pumpAndSettle();
      expect(inSidebar('D29'), findsOneWidget);
      await save(tester);
      expect(session.items.single.addNet, isTrue);

      await open(tester, code);
      await openSidebar(tester);
      expect(inSidebar('D29'), findsOneWidget);
    });

    testWidgets('an ordinary window after it never opens on 0.9mm', (WidgetTester tester) async {
      await open(tester, code);
      await save(tester);
      expect(session.items.single.material.gauge, '0.9mm');

      await open(tester, 'S_win', keepSession: true);
      await save(tester);
      expect(session.items.last.windowCode, 'S_win');
      expect(session.items.last.material.gauge, WindowGauges.g12,
          reason: "the shop's usual gauge");
    });
  });
}

class _Sent implements Exception {}

class _Api implements OptimizationApiClient {
  OptimizationRequest? sent;

  @override
  Future<CuttingReport> fetchLengthOptimization(OptimizationRequest request) {
    sent = request;
    throw _Sent();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Loader implements FormulaBookLoader {
  _Loader(this.book);

  final FormulaBook book;

  @override
  Future<FormulaBook> load() async => book;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FabricationSettings implements FabricationSettingsRepository {
  @override
  Future<FabricationSettingsModel> fetchFabricationSettings() async =>
      const FabricationSettingsModel(cuttingMarginCm: 0.5);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EstimationSettings implements EstimationSettingsRepository {
  @override
  Future<EstimationSettingsModel> fetchEstimationSettings() async =>
      const EstimationSettingsModel(
        sectionLengths: <String, List<int>>{},
        cuttingMargins: <String, double>{'DC30C': 0.041},
        maxExtraPieces: 1,
        enforceMaxExtraPieces: false,
        redZoneEven: 12,
        redZoneOdd: 13,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
