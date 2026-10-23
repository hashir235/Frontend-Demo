import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/data/window_catalog.dart';
import 'package:my_app/features/estimation/data/window_sections.dart';
import 'package:my_app/features/estimation/models/collar_layout.dart';
import 'package:my_app/features/estimation/models/door_strip.dart';
import 'package:my_app/features/estimation/models/window_review_item.dart';
import 'package:my_app/features/estimation/models/window_type.dart';
import 'package:my_app/features/estimation/models/window_variant.dart';
import 'package:my_app/features/estimation/presentation/input/input_registry.dart';
import 'package:my_app/features/estimation/presentation/window_navigation_screen.dart';
import 'package:my_app/features/estimation/state/estimate_session_store.dart';
import 'package:my_app/features/formulas/data/formula_book.dart';
import 'package:my_app/features/formulas/data/formula_catalogue.dart';
import 'package:my_app/features/formulas/data/window_cut_calculator.dart';
import 'package:my_app/features/formulas/model/formula_overrides.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The fix windows and doors on the D51 and D42 frames (Hashir, Oct 2026):
/// the D54 windows exactly, with D51A/D42A where D54A goes and D51F/D42F
/// where D54F goes. Fix Window, Corner Fix, Single Door, Double Door -- not
/// the openable. And a Double Glaze heading -- coming soon at first, its
/// sliding window since.
void main() {
  final FormulaCatalogue catalogue = FormulaCatalogue.fromJson(
    jsonDecode(File('assets/formulas/catalogue.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final WindowCutCalculator calculator =
      WindowCutCalculator(FormulaBook(catalogue, FormulaOverrides.empty()));

  const Map<String, String> bases = <String, String>{
    'F_win': 'Fix Window',
    'FC_win': 'Corner Fix',
    'Single_Door': 'Single Door',
    'Double_Door': 'Double Door',
  };
  const Map<String, Map<String, String>> frames = <String, Map<String, String>>{
    'D51': <String, String>{'D54A': 'D51A', 'D54F': 'D51F'},
    'D42': <String, String>{'D54A': 'D42A', 'D54F': 'D42F'},
  };

  group('the windows', () {
    test('eight of them, each its D54 window with two profiles renamed', () {
      for (final MapEntry<String, Map<String, String>> frame in frames.entries) {
        for (final MapEntry<String, String> base in bases.entries) {
          final String code = '${base.key}_${frame.key}';
          final WindowVariant variant = WindowVariants.of(code)!;
          expect(variant.baseCode, base.key, reason: code);
          expect(variant.collars, isNull, reason: '$code comes in every collar');
          expect(variant.sections, frame.value, reason: code);
          expect(variant.own, isNull);
          final WindowType node = WindowCatalog.byCodeName(code)!;
          expect(node.label, '${frame.key} ${base.value}');
          expect(WindowCatalog.allTypeNames, contains(node.label),
              reason: 'its own hardware rate on the bill');
        }
      }
      expect(WindowVariants.of('O_win_D51'), isNull, reason: 'not the openable');
      expect(WindowVariants.of('O_win_D42'), isNull);
    });

    test('the collars and the drawing are the D54 window\'s', () {
      for (final String series in frames.keys) {
        for (final String base in bases.keys) {
          final CollarLayout? mine = CollarLayout.forWindow('${base}_$series');
          final CollarLayout? theirs = CollarLayout.forWindow(base);
          expect(mine?.collars, theirs?.collars, reason: '${base}_$series');
          final WindowType node = WindowCatalog.byCodeName('${base}_$series')!;
          expect(WindowCatalog.drawnAs(node).codeName, base);
        }
      }
    });

    test('the library cards list D51/D42 where the D54 window lists D54', () {
      for (final MapEntry<String, Map<String, String>> frame in frames.entries) {
        for (final String base in bases.keys) {
          for (final bool fabrication in <bool>[false, true]) {
            final List<String> theirs = <String>[
              for (final UsedSection s in WindowSections.of(base, isFabrication: fabrication))
                frame.value[s.code] ?? s.code,
            ];
            final List<String> mine = <String>[
              for (final UsedSection s
                  in WindowSections.of('${base}_${frame.key}', isFabrication: fabrication))
                s.code,
            ];
            expect(mine, theirs, reason: '${base}_${frame.key}');
            expect(mine.where((String s) => s.startsWith('D54')), isEmpty);
          }
        }
      }
    });

    test('the doors on them take strips too', () {
      for (final String series in frames.keys) {
        expect(DoorStrips.offeredOn('Single_Door_$series'), isTrue);
        expect(DoorStrips.offeredOn('Double_Door_$series'), isTrue);
        expect(DoorStrips.offeredOn('F_win_$series'), isFalse);
      }
    });
  });

  group('the library', () {
    test('two more lines under Box type Windows, then Double Glaze', () {
      for (final bool fabrication in <bool>[false, true]) {
        final List<WindowGroup> groups =
            WindowCatalog.groupsForFlow(isFabrication: fabrication);
        final WindowGroup box = groups.firstWhere((WindowGroup g) => g.id == 'box');
        expect(box.rows.map((WindowRow r) => r.id), <String>['box', 'box_d51', 'box_d42']);
        expect(box.rows.map((WindowRow r) => r.title), <String?>[null, 'D51 Series', 'D42 Series']);
        expect(box.rows[1].nodes.map((WindowType n) => n.label),
            <String>['D51 Fix Window', 'D51 Corner Fix', 'D51 Door']);
        expect(box.rows[2].nodes.map((WindowType n) => n.label),
            <String>['D42 Fix Window', 'D42 Corner Fix', 'D42 Door']);
        expect(box.rows[1].nodes.last.children.map((WindowType n) => n.codeName),
            <String>['Single_Door_D51', 'Double_Door_D51']);

        final WindowGroup glaze = groups.last;
        expect(glaze.id, 'double_glaze');
        expect(glaze.title, 'Double Glaze');
        // Made since (Oct 2026): its sliding window, no longer coming soon.
        expect(glaze.comingSoon, isNull);
        expect(glaze.nodes.map((WindowType n) => n.codeName), <String>['SDG_win']);
      }
    });

    testWidgets('Double Glaze opens on its sliding window', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      tester.view.physicalSize = const Size(1080, 9000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: WindowNavigationScreen.root(
            session: EstimateSessionStore(projectName: 'P', projectLocation: 'L'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // The library is a lazy list: scroll down to each, so it is built.
      Future<void> scrollTo(Finder target) => tester.dragUntilVisible(
        target,
        find.byType(ListView).first,
        const Offset(0, -400),
      );
      await scrollTo(find.byKey(const Key('library_row_box_d51')));
      expect(find.byKey(const Key('library_row_box_d51')), findsOneWidget);
      await scrollTo(find.byKey(const Key('library_row_box_d42')));
      expect(find.byKey(const Key('library_row_box_d42')), findsOneWidget);
      await scrollTo(find.byKey(const Key('library_group_double_glaze')));
      final Finder card = find.text('Double Glaze Sliding Window');
      await scrollTo(card);
      expect(card, findsOneWidget);
      expect(find.byKey(const Key('library_coming_soon_double_glaze')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('cutting', () {
    /// Every piece of a cut list as "SECTION LABEL length", with [rename]
    /// applied to the section -- sorted, since the profiles are listed by
    /// name and D51/D42 sort in other places than D54 among D46, D50, D52.
    List<String> described(WindowCutList list, [Map<String, String> rename = const <String, String>{}]) =>
        <String>[
          for (final CutPiece p in list.pieces)
            '${rename[p.section] ?? p.section} ${p.label} ${p.lengthFt.toStringAsFixed(9)}',
        ]..sort();

    WindowCutRequest request(
      String code, {
      required bool fabrication,
      required int collar,
      bool bottom = false,
      bool tee = false,
    }) {
      final bool corner = WindowVariants.baseCode(code) == 'FC_win';
      return WindowCutRequest(
        isFabrication: fabrication,
        appWindowCode: code,
        collarIndex: collar,
        unitMode: fabrication ? 'feet' : 'inches',
        heightValue: fabrication ? '210' : '84',
        widthValue: fabrication ? (corner ? '80' : '95') : (corner ? '30' : '38'),
        leftWidthValue: corner ? (fabrication ? '100' : '40') : null,
        rightWidthValue: corner ? (fabrication ? '80' : '30') : null,
        lockType: 1,
        rubberType: 'F',
        addBottom: bottom,
        addTee: tee,
      );
    }

    test('every collar, both flows: the D54 window\'s cuts, renamed', () {
      int compared = 0;
      for (final MapEntry<String, Map<String, String>> frame in frames.entries) {
        for (final String base in bases.keys) {
          final String code = '${base}_${frame.key}';
          final CollarLayout layout = CollarLayout.forWindow(base)!;
          for (final int collar in layout.collars) {
            for (final bool fabrication in <bool>[false, true]) {
              for (final bool extras in <bool>[false, true]) {
                final WindowCutList theirs = calculator.compute(
                  request(base, fabrication: fabrication, collar: collar, bottom: extras, tee: extras),
                  margins: const <String, double>{'cm': 0.5},
                );
                final WindowCutList mine = calculator.compute(
                  request(code, fabrication: fabrication, collar: collar, bottom: extras, tee: extras),
                  margins: const <String, double>{'cm': 0.5},
                );
                final String what = '$code collar $collar ${fabrication ? 'fab' : 'est'}';
                expect(mine.problems, theirs.problems, reason: what);
                expect(described(mine), described(theirs, frame.value), reason: what);
                expect(
                  mine.pieces.where((CutPiece p) => p.section.startsWith('D54')),
                  isEmpty,
                  reason: what,
                );
                expect(
                  mine.glass.map((g) => '${g.heightCm}x${g.widthCm}'),
                  theirs.glass.map((g) => '${g.heightCm}x${g.widthCm}'),
                  reason: '$what glass',
                );
                if (theirs.pieces.isNotEmpty) compared++;
              }
            }
          }
        }
      }
      expect(compared, greaterThan(100));
    });
  });

  group('the input screen', () {
    late EstimateSessionStore session;

    Future<void> open(WidgetTester tester, String code) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      session = EstimateSessionStore(
        projectName: 'P',
        projectLocation: 'L',
        flow: EstimateFlow.fabrication,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: buildInputScreen(node: WindowCatalog.byCodeName(code)!, session: session),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder inSidebar(String text) => find.descendant(
      of: find.byKey(const Key('settings_drawer')),
      matching: find.text(text),
    );

    testWidgets('a D51 single door is a door: D46, D52 and strips, its own profiles', (
      WidgetTester tester,
    ) async {
      await open(tester, 'Single_Door_D51');
      await tester.tap(find.byKey(const Key('open_settings_drawer_button')));
      await tester.pumpAndSettle();
      expect(inSidebar('D46 Option'), findsOneWidget);
      expect(inSidebar('D52 Option'), findsOneWidget);
      expect(find.byKey(const Key('strip_D61A')), findsOneWidget);
      expect(inSidebar('D54A'), findsNothing);
      expect(inSidebar('D54F'), findsNothing);

      await tester.ensureVisible(inSidebar('D46 On'));
      await tester.tap(inSidebar('D46 On'));
      await tester.pumpAndSettle();
      expect(inSidebar('D46'), findsOneWidget, reason: 'listed once switched on');

      tester.firstState<ScaffoldState>(find.byType(Scaffold)).closeEndDrawer();
      await tester.pumpAndSettle();
      Finder field(String label) => find.byWidgetPredicate(
        (Widget w) => w is TextField && w.decoration?.labelText == label,
      );
      await tester.enterText(field('Width'), '95');
      await tester.enterText(field('Height'), '210');
      tester.widget<ButtonStyleButton>(find.byKey(const Key('input_save_button'))).onPressed!();
      await tester.pumpAndSettle();
      final WindowReviewItem saved = session.items.single;
      expect(saved.windowCode, 'Single_Door_D51');
      expect(saved.windowLabel, 'D51 Single Door');
      expect(saved.addBottom, isTrue);
    });

    testWidgets('a D42 fix window lists D42A/D42F, no door switches', (
      WidgetTester tester,
    ) async {
      await open(tester, 'F_win_D42');
      await tester.tap(find.byKey(const Key('open_settings_drawer_button')));
      await tester.pumpAndSettle();
      expect(inSidebar('D46 Option'), findsNothing);
      expect(find.byKey(const Key('strip_D61A')), findsNothing);
      expect(inSidebar('D54A'), findsNothing);
      expect(inSidebar('D54F'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('settings_drawer')),
          matching: find.textContaining('D42'),
        ),
        findsWidgets,
      );
    });
  });
}
