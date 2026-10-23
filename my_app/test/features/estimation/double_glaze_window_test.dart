import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/data/window_catalog.dart';
import 'package:my_app/features/estimation/data/window_sections.dart';
import 'package:my_app/features/estimation/models/collar_layout.dart';
import 'package:my_app/features/estimation/models/window_material.dart';
import 'package:my_app/features/estimation/models/window_variant.dart';
import 'package:my_app/features/estimation/presentation/input/input_registry.dart';
import 'package:my_app/features/estimation/presentation/input/window_input_handler.dart';
import 'package:my_app/features/estimation/state/estimate_session_store.dart';
import 'package:my_app/features/estimation/widgets/own_sliding_overlay.dart';
import 'package:my_app/features/estimation/widgets/sliding_section_overlay.dart';
import 'package:my_app/features/formulas/data/formula_book.dart';
import 'package:my_app/features/formulas/data/formula_catalogue.dart';
import 'package:my_app/features/formulas/data/window_cut_calculator.dart';
import 'package:my_app/features/formulas/model/formula_overrides.dart';
import 'package:my_app/features/formulas/model/window_sides.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Double Glaze sliding window (Hashir, Oct 2026).
///
/// Frame: DG26F on a side with a collar -- as long as DC26F is, the side
/// plus 6cm -- and DG26 on a side without, as measured. Every collar the
/// sliding window comes in; collar 2, none on any side, to start with.
///
/// Inside: DG23 in every place M23, M24 and M28 are -- heights 2 inch 3 suter
/// short, rails (W + 1 inch 7 suter) / 2; DG28 on the two centre DG23s only
/// when switched on; DG29 the net, height and half-width as they are. No
/// glass yet.
void main() {
  final FormulaCatalogue catalogue = FormulaCatalogue.fromJson(
    jsonDecode(File('assets/formulas/catalogue.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final WindowCutCalculator calculator =
      WindowCutCalculator(FormulaBook(catalogue, FormulaOverrides.empty()));

  const double margin = 0.3;
  const double feet = 30.48;
  const double height = 48 * 2.54;
  const double width = 72 * 2.54;
  const double twoInchThreeSuter = 2.375 * 2.54;
  const double oneInchSevenSuter = 1.875 * 2.54;

  double fab(double cm) => (cm + margin) / feet;

  WindowCutList cut({
    required int collar,
    bool fabrication = true,
    Set<String> leaveOut = const <String>{'DG28'},
    SideSizes sides = const SideSizes.empty(),
  }) {
    return calculator.compute(
      WindowCutRequest(
        isFabrication: fabrication,
        appWindowCode: 'SDG_win',
        collarIndex: collar,
        unitMode: 'inches',
        heightValue: '48',
        widthValue: '72',
        lockType: 1,
        rubberType: 'F',
        leaveOut: leaveOut,
        sideSizes: sides,
      ),
      margins: fabrication
          ? const <String, double>{'cm': margin}
          : const <String, double>{},
    );
  }

  List<CutPiece> of(WindowCutList list, String section) =>
      list.pieces.where((CutPiece p) => p.section == section).toList();

  group('the frame', () {
    test('collar 2: DG26 all round, as measured; no DG26F', () {
      final WindowCutList list = cut(collar: 2);
      expect(list.problems, isEmpty);
      expect(of(list, 'DG26F'), isEmpty);
      final Map<String, double> frame = <String, double>{
        for (final CutPiece p in of(list, 'DG26')) p.label: p.lengthFt,
      };
      expect(frame.keys.toSet(), <String>{'HL', 'HR', 'WT', 'WB'});
      expect(frame['HL'], closeTo(fab(height), 1e-9));
      expect(frame['HR'], closeTo(fab(height), 1e-9));
      expect(frame['WT'], closeTo(fab(width), 1e-9));
      expect(frame['WB'], closeTo(fab(width), 1e-9));
    });

    test('collar 1: DG26F all round, 6cm longer, as DC26F is', () {
      final WindowCutList list = cut(collar: 1);
      expect(of(list, 'DG26'), isEmpty);
      final Map<String, double> frame = <String, double>{
        for (final CutPiece p in of(list, 'DG26F')) p.label: p.lengthFt,
      };
      expect(frame['HL'], closeTo(fab(height + 6), 1e-9));
      expect(frame['HR'], closeTo(fab(height + 6), 1e-9));
      expect(frame['WT'], closeTo(fab(width + 6), 1e-9));
      expect(frame['WB'], closeTo(fab(width + 6), 1e-9));
    });

    test('every collar: DG26F exactly on the collared sides', () {
      final CollarLayout layout = CollarLayout.forWindow('SDG_win')!;
      expect(layout.collars.length, 14, reason: 'every collar the sliding window has');
      const Map<CollarSide, String> labelOf = <CollarSide, String>{
        CollarSide.top: 'WT',
        CollarSide.bottom: 'WB',
        CollarSide.left: 'HL',
        CollarSide.right: 'HR',
      };
      for (final int collar in layout.collars) {
        final WindowCutList list = cut(collar: collar);
        expect(list.problems, isEmpty, reason: 'collar $collar');
        final Set<String> collared = <String>{
          for (final CollarSide side in layout.sidesWithCollar(collar)) labelOf[side]!,
        };
        expect(of(list, 'DG26F').map((CutPiece p) => p.label).toSet(), collared,
            reason: 'collar $collar');
        expect(of(list, 'DG26').map((CutPiece p) => p.label).toSet(),
            <String>{'HL', 'HR', 'WT', 'WB'}.difference(collared),
            reason: 'collar $collar');
        for (final CutPiece p in <CutPiece>[...of(list, 'DG26F'), ...of(list, 'DG26')]) {
          final double side = p.label.startsWith('H') ? height : width;
          final double add = p.section == 'DG26F' ? 6 : 0;
          expect(p.lengthFt, closeTo(fab(side + add), 1e-9), reason: 'collar $collar ${p.label}');
        }
      }
    });
  });

  group('inside the frame', () {
    test('DG23: four heights 2 inch 3 suter short, four rails (W + 1 inch 7 suter) / 2', () {
      for (final int collar in <int>[1, 2, 7]) {
        final List<CutPiece> dg23 = of(cut(collar: collar), 'DG23');
        expect(dg23.map((CutPiece p) => p.label),
            <String>['HL', 'HR', 'H', 'H', 'WT', 'WT', 'WB', 'WB']);
        for (final CutPiece p in dg23.take(4)) {
          expect(p.lengthFt, closeTo(fab(height - twoInchThreeSuter), 1e-9));
        }
        for (final CutPiece p in dg23.skip(4)) {
          expect(p.lengthFt, closeTo(fab((width + oneInchSevenSuter) / 2), 1e-9));
        }
      }
    });

    test('DG28 only when switched on: two, as long as the centre DG23s', () {
      expect(of(cut(collar: 2), 'DG28'), isEmpty);
      final List<CutPiece> dg28 = of(cut(collar: 2, leaveOut: const <String>{}), 'DG28');
      expect(dg28, hasLength(2));
      for (final CutPiece p in dg28) {
        expect(p.lengthFt, closeTo(fab(height - twoInchThreeSuter), 1e-9));
      }
    });

    test('DG29, the net: two heights and two half-widths, as they are', () {
      final Map<String, double> net = <String, double>{
        for (final CutPiece p in of(cut(collar: 2), 'DG29')) p.label: p.lengthFt,
      };
      expect(net['HL'], closeTo(fab(height), 1e-9));
      expect(net['HR'], closeTo(fab(height), 1e-9));
      expect(net['WT'], closeTo(fab(width / 2), 1e-9));
      expect(net['WB'], closeTo(fab(width / 2), 1e-9));
    });

    test('nothing of the sliding window\'s own profiles, and no glass yet', () {
      final WindowCutList list = cut(collar: 1, leaveOut: const <String>{});
      expect(list.pieces.map((CutPiece p) => p.section).toSet(),
          <String>{'DG26F', 'DG23', 'DG28', 'DG29'});
      expect(list.glass, isEmpty);
    });
  });

  test('estimation cuts it too, from the same profiles', () {
    final WindowCutList list = cut(collar: 7, fabrication: false);
    expect(list.problems, isEmpty);
    expect(list.pieces.map((CutPiece p) => p.section).toSet(),
        <String>{'DG26F', 'DG26', 'DG23', 'DG29'});
  });

  test('measured side by side: the frame to each side, the rails to theirs when apart', () {
    // Top 72'', bottom 73'' -- 8 suter apart, so the rails follow too.
    final WindowCutList list = cut(
      collar: 2,
      sides: const SideSizes(<String, String>{'WT': '72', 'WB': '73', 'HL': '48', 'HR': '48'}),
    );
    expect(list.problems, isEmpty);
    final Map<String, double> frame = <String, double>{
      for (final CutPiece p in of(list, 'DG26')) p.label: p.lengthFt,
    };
    expect(frame['WT'], closeTo(fab(72 * 2.54), 1e-9));
    expect(frame['WB'], closeTo(fab(73 * 2.54), 1e-9));
    final List<CutPiece> rails = of(list, 'DG23').where((CutPiece p) => p.label.startsWith('W')).toList();
    expect(rails.where((CutPiece p) => p.label == 'WT').every(
        (CutPiece p) => (p.lengthFt - fab((72 * 2.54 + oneInchSevenSuter) / 2)).abs() < 1e-9), isTrue);
    expect(rails.where((CutPiece p) => p.label == 'WB').every(
        (CutPiece p) => (p.lengthFt - fab((73 * 2.54 + oneInchSevenSuter) / 2)).abs() < 1e-9), isTrue);
  });

  group('the screen', () {
    test('the sidebar lists the frame each collar has, DG28 only when on', () {
      final WindowInputHandler handler = handlerForWindowCode('SDG_win');
      expect(handler.sectionsByCollar[2], <String>['DG26', 'DG23', 'DG29']);
      expect(handler.sectionsByCollar[1], <String>['DG26F', 'DG23', 'DG29']);
      expect(handler.sectionsByCollar[7], <String>['DG26F', 'DG26', 'DG23', 'DG29']);
      (handler as VariantInputHandler).netEnabled = true;
      expect(handler.sectionsByCollar[2], <String>['DG26', 'DG23', 'DG28', 'DG29']);
    });

    test('the drawing lights the collared sides for DG26F and the rest for DG26', () {
      // Collar 7: a collar at the bottom and the right.
      final Map<String, Set<SlidingPart>> parts = OwnSlidingOverlay.partsFor('SDG_win', collar: 7);
      expect(parts['DG26F'], <SlidingPart>{SlidingPart.sill, SlidingPart.rightJamb});
      expect(parts['DG26'], <SlidingPart>{SlidingPart.head, SlidingPart.leftJamb});
      expect(parts['DG28'], <SlidingPart>{SlidingPart.centreStiles});
      expect(parts['DG29'], <SlidingPart>{SlidingPart.net});
    });

    test('Used Sections, and every gauge', () {
      expect(
        WindowSections.of('SDG_win', isFabrication: true).map((UsedSection s) => s.code),
        <String>['DG26F', 'DG26', 'DG23', 'DG28', 'DG29'],
      );
      expect(WindowGauges.forWindow('SDG_win'), WindowGauges.all);
      expect(WindowCatalog.byCodeName('SDG_win')?.label, 'Double Glaze Sliding Window');
      expect(WindowVariants.of('SDG_win')?.defaultCollar, 2);
    });

    testWidgets('a new window opens on collar 2, none on any side', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final EstimateSessionStore session = EstimateSessionStore(
        projectName: 'P',
        projectLocation: 'L',
        flow: EstimateFlow.fabrication,
      );
      await tester.pumpWidget(MaterialApp(
        home: buildInputScreen(node: WindowCatalog.byCodeName('SDG_win')!, session: session),
      ));
      await tester.pumpAndSettle();
      Finder field(String label) => find.byWidgetPredicate(
        (Widget w) => w is TextField && w.decoration?.labelText == label,
      );
      await tester.enterText(field('Width'), '72');
      await tester.enterText(field('Height'), '48');
      final Finder save = find.byKey(const Key('input_save_button'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(session.items.single.windowCode, 'SDG_win');
      expect(session.items.single.collarIndex, 2);
    });
  });
}
