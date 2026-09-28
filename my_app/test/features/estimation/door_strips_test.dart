import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/data/window_catalog.dart';
import 'package:my_app/features/estimation/data/window_sections.dart';
import 'package:my_app/features/estimation/models/door_strip.dart';
import 'package:my_app/features/estimation/presentation/input/input_registry.dart';
import 'package:my_app/features/estimation/state/estimate_session_store.dart';
import 'package:my_app/features/formulas/data/formula_book.dart';
import 'package:my_app/features/formulas/data/formula_catalogue.dart';
import 'package:my_app/features/formulas/data/window_cut_calculator.dart';
import 'package:my_app/features/formulas/model/formula_overrides.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Strips: a door closed in with aluminium instead of glass. Each strip is as
/// long as the glass is wide; they are laid one above another -- P1 + P2 + ...
/// -- until their widths reach the glass's height; and the door takes no glass.
void main() {
  final FormulaCatalogue catalogue = FormulaCatalogue.fromJson(
    jsonDecode(File('assets/formulas/catalogue.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final WindowCutCalculator calculator =
      WindowCutCalculator(FormulaBook(catalogue, FormulaOverrides.empty()));

  group('how many strips', () {
    test('the fewest whose widths reach the height', () {
      const DoorStrip d61a = DoorStrip('D61A', 100.80);
      expect(d61a.piecesFor(10.08 * 10), 10, reason: 'exactly ten fill it');
      expect(d61a.piecesFor(100.81), 11, reason: 'a hair more takes one more');
      expect(d61a.piecesFor(198.46), 20, reason: '1984.6mm / 100.8mm = 19.69');
      expect(d61a.piecesFor(0), 0);
    });

    test('the four strips and their widths', () {
      expect(
        <String, double>{for (final DoorStrip s in DoorStrips.all) s.section: s.widthMm},
        <String, double>{'D61A': 100.80, 'D61H': 107.42, 'PATTI4': 113.61, 'PATTI6': 151.19},
      );
      expect(DoorStrips.offeredOn('Single_Door'), isTrue);
      expect(DoorStrips.offeredOn('Double_Door'), isTrue);
      expect(DoorStrips.offeredOn('S_win'), isFalse);
    });
  });

  group('the cut list', () {
    const double cm = 0.3;

    WindowCutList fabrication(String code, {DoorStrip? strip, bool addBottom = false}) =>
        calculator.compute(
          WindowCutRequest(
            isFabrication: true,
            appWindowCode: code,
            collarIndex: 1,
            unitMode: 'feet',
            heightValue: '213.4',
            widthValue: '91.4',
            addBottom: addBottom,
            strip: strip,
          ),
          margins: const <String, double>{'cm': cm},
        );

    for (final String code in <String>['Single_Door', 'Double_Door']) {
      for (final DoorStrip strip in DoorStrips.all) {
        test('$code, ${strip.section}: one strip per width of glass, P1 upwards', () {
          final WindowCutList glassDoor = fabrication(code);
          final WindowCutList stripDoor = fabrication(code, strip: strip);
          expect(glassDoor.problems, isEmpty);
          expect(stripDoor.problems, isEmpty);
          expect(glassDoor.glass, isNotEmpty);
          expect(stripDoor.glass, isEmpty, reason: 'strips instead of glass');

          final List<CutPiece> strips =
              stripDoor.pieces.where((CutPiece p) => p.section == strip.section).toList();
          int expected = 0;
          for (final GlassPiece pane in glassDoor.glass) {
            expected += strip.piecesFor(pane.heightCm);
          }
          expect(strips, hasLength(expected));
          expect(strips.map((CutPiece p) => p.label),
              <String>[for (int i = 1; i <= expected; i++) 'P$i']);
          // As long as the glass is wide, with the cutting margin the
          // optimizer adds and the cutting list takes off again.
          final GlassPiece pane = glassDoor.glass.first;
          for (final CutPiece piece in strips) {
            expect(piece.lengthFt, closeTo((pane.widthCm + cm) / 30.48, 1e-9));
          }
          // Covering the height, with no strip to spare.
          expect(strip.piecesFor(pane.heightCm) * strip.widthMm / 10,
              greaterThanOrEqualTo(pane.heightCm));
          expect((strip.piecesFor(pane.heightCm) - 1) * strip.widthMm / 10,
              lessThan(pane.heightCm));

          // The frame is cut exactly as before.
          expect(
            stripDoor.pieces
                .where((CutPiece p) => p.section != strip.section)
                .map((CutPiece p) => '${p.section} ${p.label} ${p.lengthFt}'),
            glassDoor.pieces.map((CutPiece p) => '${p.section} ${p.label} ${p.lengthFt}'),
          );
        });
      }
    }

    test('a double door covers both leaves', () {
      final WindowCutList single = fabrication('Single_Door', strip: DoorStrips.all.first);
      final WindowCutList double = fabrication('Double_Door', strip: DoorStrips.all.first);
      int count(WindowCutList list) =>
          list.pieces.where((CutPiece p) => p.section == 'D61A').length;
      expect(count(double), 2 * count(single));
    });

    test('with the bottom rail (D46) the glass, and so the strips, follow', () {
      final WindowCutList glass = fabrication('Single_Door', addBottom: true);
      final WindowCutList strips =
          fabrication('Single_Door', addBottom: true, strip: DoorStrips.all.first);
      expect(strips.pieces.where((CutPiece p) => p.section == 'D61A'),
          hasLength(DoorStrips.all.first.piecesFor(glass.glass.first.heightCm)));
    });

    test('estimation, which has no door glass of its own, uses the door\'s', () {
      WindowCutList estimate({DoorStrip? strip}) => calculator.compute(
        WindowCutRequest(
          isFabrication: false,
          appWindowCode: 'Single_Door',
          collarIndex: 1,
          unitMode: 'inches',
          heightValue: '84.0',
          widthValue: '36.0',
          strip: strip,
        ),
        margins: const <String, double>{},
      );
      final WindowCutList strips = estimate(strip: DoorStrips.all.first);
      expect(strips.problems, isEmpty);
      // 84 inches = 213.36cm; the glass is h - 14.9 = 198.46cm high and
      // w - 15.8 = 75.64cm wide.
      final List<CutPiece> d61a =
          strips.pieces.where((CutPiece p) => p.section == 'D61A').toList();
      expect(d61a, hasLength(20));
      expect(d61a.first.lengthFt, closeTo((36 * 2.54 - 15.8) / 30.48, 1e-9));
      expect(
        strips.pieces.where((CutPiece p) => p.section != 'D61A').length,
        estimate().pieces.length,
      );
    });
  });

  test('the library lists them as the door\'s strips', () {
    expect(
      WindowSections.of('Single_Door', isFabrication: true).last.label,
      'D61A / D61H / PATTI4 / PATTI6 (strips)',
    );
  });

  group('the sidebar', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    late EstimateSessionStore session;

    Future<void> open(WidgetTester tester, String code) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      session = EstimateSessionStore(projectName: 'P', projectLocation: 'L');
      await tester.pumpWidget(
        MaterialApp(
          home: buildInputScreen(node: WindowCatalog.byCodeName(code)!, session: session),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open_settings_drawer_button')));
      await tester.pumpAndSettle();
    }

    double opacityOf(WidgetTester tester, String section) =>
        tester.widget<AnimatedOpacity>(find.byKey(Key('strip_$section'))).opacity;

    Future<void> tapStrip(WidgetTester tester, String section) async {
      final Finder option = find.descendant(
        of: find.byKey(Key('strip_$section')),
        matching: find.byType(InkWell),
      );
      await tester.ensureVisible(option);
      await tester.tap(option);
      await tester.pumpAndSettle();
    }

    testWidgets('one at a time: the chosen one lit, the rest dimmed, tap again to remove', (
      WidgetTester tester,
    ) async {
      await open(tester, 'Single_Door');
      expect(find.text('Strips'), findsOneWidget);
      for (final DoorStrip strip in DoorStrips.all) {
        expect(opacityOf(tester, strip.section), 1, reason: 'none chosen: all alike');
      }

      await tapStrip(tester, 'D61H');
      expect(opacityOf(tester, 'D61H'), 1);
      for (final String other in <String>['D61A', 'PATTI4', 'PATTI6']) {
        expect(opacityOf(tester, other), lessThan(1), reason: '$other dimmed');
      }

      await tapStrip(tester, 'PATTI6');
      expect(opacityOf(tester, 'PATTI6'), 1, reason: 'another takes its place');
      expect(opacityOf(tester, 'D61H'), lessThan(1));

      await tapStrip(tester, 'PATTI6');
      for (final DoorStrip strip in DoorStrips.all) {
        expect(opacityOf(tester, strip.section), 1, reason: 'tapped again: none');
      }
    });

    testWidgets('saved with the door', (WidgetTester tester) async {
      await open(tester, 'Double_Door');
      await tapStrip(tester, 'PATTI4');
      tester.firstState<ScaffoldState>(find.byType(Scaffold)).closeEndDrawer();
      await tester.pumpAndSettle();
      Finder field(String label) => find.byWidgetPredicate(
        (Widget w) => w is TextField && w.decoration?.labelText == label,
      );
      await tester.enterText(field('Width'), '40');
      await tester.enterText(field('Height'), '80');
      tester.widget<ButtonStyleButton>(find.byKey(const Key('input_save_button'))).onPressed!();
      await tester.pumpAndSettle();
      expect(session.items.single.strip, 'PATTI4');
    });

    testWidgets('only doors have them', (WidgetTester tester) async {
      await open(tester, 'S_win');
      expect(find.byKey(const Key('strip_D61A')), findsNothing);
    });
  });
}
