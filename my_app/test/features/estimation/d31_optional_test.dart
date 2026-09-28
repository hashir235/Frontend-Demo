import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/data/window_catalog.dart';
import 'package:my_app/features/estimation/data/window_sections.dart';
import 'package:my_app/features/estimation/models/window_review_item.dart';
import 'package:my_app/features/estimation/presentation/input/input_registry.dart';
import 'package:my_app/features/estimation/state/estimate_session_store.dart';
import 'package:my_app/features/formulas/data/formula_book.dart';
import 'package:my_app/features/formulas/data/formula_catalogue.dart';
import 'package:my_app/features/formulas/data/window_cut_calculator.dart';
import 'package:my_app/features/formulas/model/formula_overrides.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// D31 is optional wherever a window has it (the center slide panel windows,
/// plain, M-section and every frame of them): it is cut only when the
/// fabricator switches it on in the sidebar. A window saved before the
/// switch existed keeps its D31, cut as it was then.
void main() {
  final FormulaCatalogue catalogue = FormulaCatalogue.fromJson(
    jsonDecode(File('assets/formulas/catalogue.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final WindowCutCalculator calculator =
      WindowCutCalculator(FormulaBook(catalogue, FormulaOverrides.empty()));

  const List<String> withD31 = <String>[
    'PS4_win',
    'MPS4_win',
    'PS4B_win',
    'PS4BA_win',
    'PS4E_win',
    'MPS4E_win',
    'MPS4EA_win',
  ];

  group('the cut list', () {
    for (final String code in withD31) {
      for (final bool fabrication in <bool>[false, true]) {
        test('$code ${fabrication ? 'fabrication' : 'estimation'}: '
            'D31 left out when off, everything else the same', () {
          WindowCutList cut(Set<String> leaveOut) => calculator.compute(
            WindowCutRequest(
              isFabrication: fabrication,
              appWindowCode: code,
              collarIndex: 2,
              unitMode: fabrication ? 'feet' : 'inches',
              heightValue: fabrication ? '120.5' : '48.4',
              widthValue: fabrication ? '150' : '60',
              lockType: fabrication ? 1 : null,
              rubberType: fabrication ? 'F' : null,
              leaveOut: leaveOut,
            ),
            margins: fabrication
                ? <String, double>{'cm': 0.3}
                : <String, double>{'cm_DC30C': 0.041, 'cm_DC26C': 0.041},
          );
          final WindowCutList on = cut(const <String>{});
          final WindowCutList off = cut(const <String>{'D31'});
          expect(on.problems, isEmpty);
          expect(on.pieces.where((CutPiece p) => p.section == 'D31'), isNotEmpty);
          expect(off.pieces.where((CutPiece p) => p.section == 'D31'), isEmpty);
          expect(
            off.pieces.map((CutPiece p) => '${p.section} ${p.label} ${p.lengthFt}'),
            on.pieces
                .where((CutPiece p) => p.section != 'D31')
                .map((CutPiece p) => '${p.section} ${p.label} ${p.lengthFt}'),
          );
          expect(off.glass.length, on.glass.length, reason: 'the glass is not D31');
        });
      }
    }
  });

  test('the library says D31 is optional', () {
    for (final String code in withD31) {
      final UsedSection d31 = WindowSections.of(code, isFabrication: false)
          .firstWhere((UsedSection s) => s.code == 'D31');
      expect(d31.label, 'D31 (optional)', reason: code);
    }
  });

  test('a window saved before the switch keeps its D31', () {
    final WindowReviewItem old = WindowReviewItem.fromJson(<String, dynamic>{
      'winNo': 1,
      'windowLabel': 'Center Slide',
      'windowCode': 'PS4_win',
      'windowIndex': 4,
      'collarIndex': 1,
      'unitMode': 'inches',
      'heightValue': '48',
      'widthValue': '60',
    });
    expect(old.addD31, isNull);
    expect(old.cutsD31, isTrue);

    final WindowReviewItem off = old.copyWith(addD31: false);
    expect(off.cutsD31, isFalse);
    expect(WindowReviewItem.fromJson(off.toJson()).addD31, isFalse,
        reason: 'the choice survives a save and a reload');
  });

  group('the sidebar', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    late EstimateSessionStore session;

    Future<void> open(WidgetTester tester, String code, {WindowReviewItem? editing}) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: buildInputScreen(
            node: WindowCatalog.byCodeName(code)!,
            session: session,
            editingItem: editing,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open_settings_drawer_button')));
      await tester.pumpAndSettle();
    }

    Finder inSidebar(String text) => find.descendant(
      of: find.byKey(const Key('settings_drawer')),
      matching: find.text(text),
    );

    Future<void> save(WidgetTester tester) async {
      final ScaffoldState scaffold = tester.firstState<ScaffoldState>(find.byType(Scaffold));
      scaffold.closeEndDrawer();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('settings_drawer')), findsNothing);
      Finder field(String label) => find.byWidgetPredicate(
        (Widget w) => w is TextField && w.decoration?.labelText == label,
      );
      await tester.enterText(field('Width'), '40');
      await tester.enterText(field('Height'), '30');
      // Pressed directly: where the button lands under the bottom bar is a
      // matter of this test's screen, not of the save.
      tester.widget<ButtonStyleButton>(find.byKey(const Key('input_save_button'))).onPressed!();
      await tester.pumpAndSettle();
    }

    setUp(() {
      session = EstimateSessionStore(projectName: 'P', projectLocation: 'L');
    });

    testWidgets('off for a new window: not listed, saved off', (WidgetTester tester) async {
      await open(tester, 'PS4_win');
      expect(inSidebar('D31 Option'), findsOneWidget);
      expect(inSidebar('D31'), findsNothing, reason: 'not in the sections list while off');
      await save(tester);
      expect(session.items.single.addD31, isFalse);
    });

    testWidgets('switched on: listed, and saved on', (WidgetTester tester) async {
      await open(tester, 'MPS4E_win');
      await tester.ensureVisible(inSidebar('D31 On'));
      await tester.tap(inSidebar('D31 On'));
      await tester.pumpAndSettle();
      expect(inSidebar('D31'), findsOneWidget, reason: 'now in the sections list');
      await save(tester);
      expect(session.items.single.addD31, isTrue);
    });

    testWidgets('a window without D31 has no switch and saves nothing for it', (
      WidgetTester tester,
    ) async {
      await open(tester, 'PF3_win');
      expect(inSidebar('D31 Option'), findsNothing);
      await save(tester);
      expect(session.items.single.addD31, isNull);
    });

    testWidgets('an old window opens with its D31 on', (WidgetTester tester) async {
      final WindowReviewItem old = session.addItem(
        winNo: 1,
        windowLabel: 'Center Slide',
        windowCode: 'PS4_win',
        windowIndex: 4,
        collarIndex: 1,
        unitMode: UnitMode.inches,
        heightValue: '48',
        widthValue: '60',
      );
      expect(old.addD31, isNull);
      await open(tester, 'PS4_win', editing: old);
      expect(inSidebar('D31'), findsOneWidget, reason: 'listed: it is cut, as before');
    });
  });
}
