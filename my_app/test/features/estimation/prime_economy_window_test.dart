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
import 'package:my_app/features/formulas/data/formula_book.dart';
import 'package:my_app/features/formulas/data/formula_book_loader.dart';
import 'package:my_app/features/formulas/data/formula_catalogue.dart';
import 'package:my_app/features/formulas/data/window_cut_calculator.dart';
import 'package:my_app/features/formulas/model/formula_overrides.dart';
import 'package:my_app/features/formulas/model/formula_window_key.dart';
import 'package:my_app/features/settings/data/estimation_settings_repository.dart';
import 'package:my_app/features/settings/data/fabrication_settings_repository.dart';
import 'package:my_app/features/settings/models/estimation_settings.dart';
import 'package:my_app/features/settings/models/fabrication_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Prime Economy sliding window (Hashir, Oct 2026): a plain two-panel
/// sliding window on Prime's EF profiles, no collar, 0.9mm only, the
/// finishes under Prime's own names, D29 only when switched on, and in
/// fabrication its own formulas -- given in suter -- and no glass yet.
void main() {
  final FormulaCatalogue catalogue = FormulaCatalogue.fromJson(
    jsonDecode(File('assets/formulas/catalogue.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final FormulaBook book = FormulaBook(catalogue, FormulaOverrides.empty());
  final WindowCutCalculator calculator = WindowCutCalculator(book);

  const String code = 'SPE_win';
  const double feet = 30.48;

  group('the window', () {
    test('a sliding window to the engine, at collar 2, cut its own way', () {
      final WindowVariant variant = WindowVariants.of(code)!;
      expect(variant.baseCode, 'S_win');
      expect(variant.collars, <int>[2]);
      final OwnWindow own = variant.own!;
      expect(own.sections,
          <String>['EF30', 'EF27', 'EF26A', 'EF25', 'EF24', 'EF22', 'EF28', 'D29']);
      expect(own.netSection, 'D29');
      expect(own.frame, <String>{'EF30', 'EF27', 'EF26A'});
      expect(own.gauges, <String>['0.9mm']);
      expect(own.estimation.keys.toSet(), own.sections.toSet());
      expect(own.fabrication.keys.toSet(), own.sections.toSet());
    });

    test("the finishes go by Prime's names, one for every rate-list column", () {
      final OwnWindow own = WindowVariants.ownOf(code)!;
      expect(own.colorNames.keys.toSet(), AluminiumColors.all.toSet(),
          reason: 'a finish with no name, or a name priced from no column, is wrong');
      expect(own.colorNameFor(AluminiumColors.dull), 'Dull Silver');
      expect(own.colorNameFor(AluminiumColors.champagne), 'Chm/Ral Gold');
      expect(own.colorNameFor(AluminiumColors.sahara), 'Brown Sahara');
      expect(own.colorNameFor(AluminiumColors.black), 'Multi/BLK Ral +');
      expect(own.colorNameFor(AluminiumColors.wood), 'Wood Sahara +');
    });

    test('in the library, a line of its own under the Economy windows, both flows', () {
      for (final bool fabrication in <bool>[false, true]) {
        final WindowGroup economy = WindowCatalog.groupsForFlow(isFabrication: fabrication)
            .firstWhere((WindowGroup g) => g.id == 'economy');
        expect(economy.rows.map((WindowRow r) => r.title),
            <String>['PAK AL TECH', 'Prime Economy Sliding Windows']);
        expect(economy.rows.last.nodes.single.codeName, code);
      }
      expect(WindowCatalog.byCodeName(code)!.label, 'Prime Eco Sliding Window');
      expect(WindowCatalog.allTypeNames, contains('Prime Eco Sliding Window'),
          reason: 'its own hardware rate on the bill');
    });

    test('its card lists its own profiles, D29 as the net', () {
      for (final bool fabrication in <bool>[false, true]) {
        expect(
          WindowSections.of(code, isFabrication: fabrication).map((UsedSection s) => s.label),
          <String>['EF30', 'EF27', 'EF26A', 'EF25', 'EF24', 'EF22', 'EF28', 'D29 (net)'],
        );
      }
    });

    test('no collar to pick', () {
      expect(CollarLayout.forWindow(code), isNull);
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

    WindowCutList cut(String window, {Set<String> leaveOut = const <String>{}}) =>
        calculator.compute(
          WindowCutRequest(
            isFabrication: false,
            appWindowCode: window,
            collarIndex: 2,
            unitMode: 'inches',
            heightValue: '48',
            widthValue: '60',
            leaveOut: leaveOut,
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

    test('the sizes Hashir gave: heights, the width, half the width', () {
      final WindowCutList list = cut(code);
      expect(list.problems, isEmpty);
      expect(bySection(list), <String, List<String>>{
        // 4ft high, 5ft wide, each with its margin.
        'D29': <String>['HL 4.0400', 'HR 4.0400', 'WT 2.5400', 'WB 2.5400'],
        'EF22': <String>['H 4.0100', 'H 4.0100'],
        'EF24': <String>['W3 2.5200', 'W4 2.5200'],
        'EF25': <String>['W1 2.5200', 'W2 2.5200'],
        'EF26A': <String>['WB 5.0410'],
        'EF27': <String>['WT 5.0410'],
        'EF28': <String>['H 4.0300', 'H 4.0300'],
        'EF30': <String>['HL 4.0410', 'HR 4.0410'],
      });
    });

    test('piece for piece, the plain sliding window with no collar', () {
      // Every piece in the place its counterpart has on that window.
      const Map<String, (String, List<String>)> counterpart = <String, (String, List<String>)>{
        'EF30': ('DC30C', <String>['HL', 'HR']),
        'EF27': ('DC30C', <String>['WT']),
        'EF26A': ('DC26C', <String>['WB']),
        'EF25': ('M24', <String>['W1', 'W2']),
        'EF24': ('M24', <String>['W3', 'W4']),
        'EF22': ('M23', <String>['H', 'H']),
        'EF28': ('M28', <String>['H', 'H']),
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
          ),
          margins: <String, double>{'cm': margin},
        );

    test('the suter, in centimetres', () {
      const double inch = 2.54;
      expect(3 / 8 * inch, closeTo(0.9525, 1e-12), reason: '3 suter');
      expect(7 / 8 * inch, closeTo(2.2225, 1e-12), reason: '7 suter');
      expect((3 + 2 / 8) * inch, closeTo(8.255, 1e-12), reason: '3 inch 2 suter');
    });

    test("Hashir's formulas: EF30 as is, 3 suter, 7 suter, (W - 3'' 2''') / 2", () {
      final WindowCutList list = cut();
      expect(list.problems, isEmpty);
      double one(String section, String label) => list.pieces
          .firstWhere((CutPiece p) => p.section == section && p.label == label)
          .lengthFt;
      int count(String section) =>
          list.pieces.where((CutPiece p) => p.section == section).length;

      const double h = 120;
      const double w = 150;
      expect(one('EF30', 'HL') * feet, closeTo(h, 1e-9));
      expect(one('EF30', 'HR') * feet, closeTo(h, 1e-9));
      expect(one('EF27', 'WT') * feet, closeTo(w - 0.9525, 1e-9));
      expect(one('EF26A', 'WB') * feet, closeTo(w - 0.9525, 1e-9));
      expect(one('EF22', 'H') * feet, closeTo(h - 2.2225, 1e-9));
      expect(one('EF28', 'H') * feet, closeTo(h - 2.2225, 1e-9));
      for (final String label in <String>['W1', 'W2']) {
        expect(one('EF25', label) * feet, closeTo((w - 8.255) / 2, 1e-9));
      }
      for (final String label in <String>['W3', 'W4']) {
        expect(one('EF24', label) * feet, closeTo((w - 8.255) / 2, 1e-9));
      }
      expect(one('D29', 'HL') * feet, closeTo(h - 2.2225, 1e-9));
      expect(one('D29', 'HR') * feet, closeTo(h - 2.2225, 1e-9));
      expect(one('D29', 'WT') * feet, closeTo((w - 8.255) / 2, 1e-9));
      expect(one('D29', 'WB') * feet, closeTo((w - 8.255) / 2, 1e-9));

      // Eight profiles, sixteen pieces: 2 + 1 + 1 + 2 + 2 + 2 + 2 + 4.
      expect(<String, int>{for (final String s in <String>[
        'EF30', 'EF27', 'EF26A', 'EF25', 'EF24', 'EF22', 'EF28', 'D29',
      ]) s: count(s)}, <String, int>{
        'EF30': 2, 'EF27': 1, 'EF26A': 1, 'EF25': 2, 'EF24': 2, 'EF22': 2, 'EF28': 2, 'D29': 4,
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

    test('no glass yet: its glass formula is still to come', () {
      final WindowCutList list = cut();
      expect(list.glass, isEmpty);
      final FormulaWindowKey key = FormulaWindowKey.of(
        context: 'fabrication',
        appWindowCode: code,
        dimensions: catalogue.dimensionsFor('fabrication/$code'),
        collarIndex: 2,
      )!;
      expect(book.glassFor(key), isEmpty);
    });

    test('no lock and no rubber decide it: one set of formulas', () {
      expect(catalogue.dimensionsFor('fabrication/$code'), <String>{'collarType'});
      expect(catalogue.dimensionsFor('estimation/$code'), <String>{'collarType'});
    });

    test('a window measured side by side cuts its frame to each side', () {
      expect(catalogue.frameSectionsFor('fabrication/$code'),
          <String>{'EF30', 'EF27', 'EF26A'});
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
      windowLabel: 'Prime Eco Sliding Window',
      windowCode: code,
      windowIndex: 56,
      collarIndex: 2,
      unitMode: fabrication ? UnitMode.cm : UnitMode.inches,
      heightValue: fabrication ? '120' : '48',
      widthValue: fabrication ? '150' : '60',
      addNet: net,
      material: const WindowMaterial(gauge: '0.9mm', color: AluminiumColors.dull),
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

      test('$flow: as the sliding window, in 0.9mm, with its own EF pieces', () async {
        final OptimizationRequest sent =
            await send(item(net: false, fabrication: fabrication), fabrication: fabrication);
        final Map<String, Object?> json = sent.windows.single.toJson();
        expect(json['windowCode'], 'S_win');
        expect(json['gauge'], '0.9mm');
        expect(json['color'], AluminiumColors.dull);
        final List<Map<String, Object?>> pieces = sent.windows.single.computedPieces!;
        expect(pieces.map((Map<String, Object?> p) => p['section']).toSet(),
            <String>{'EF30', 'EF27', 'EF26A', 'EF25', 'EF24', 'EF22', 'EF28'},
            reason: 'D29 off: not cut');
        // Sent, and empty: the engine then cuts no glass for it, rather than
        // the sliding window's own.
        expect(json['computedGlass'], isEmpty);
        expect(json.containsKey('computedGlass'), isTrue);
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
      // A fresh screen each time, as the app pushes one: without this the
      // last screen's state would be kept and simply rebuilt.
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

    testWidgets('plain drawing, no collar, 0.9mm only, Prime names', (WidgetTester tester) async {
      await open(tester, code);
      expect(find.byKey(const Key('prime_economy_drawing')), findsOneWidget);
      expect(find.textContaining('Collar'), findsNothing, reason: 'no collar badge or hint');
      expect(find.text('0.9mm'), findsOneWidget);
      expect(find.text('1.2mm'), findsNothing);
      expect(find.text('2mm'), findsNothing);
      // The finish the window opens on, under Prime's name.
      expect(find.text('Chm/Ral Gold'), findsOneWidget);
      expect(find.text('H23/PC-RAL (Champagne)'), findsNothing);
    });

    testWidgets('fabrication asks no lock and no rubber', (WidgetTester tester) async {
      await open(tester, code, fabrication: true);
      expect(find.text('Latch'), findsNothing);
      expect(find.text('U'), findsNothing);
      expect(find.byKey(const Key('prime_economy_drawing')), findsOneWidget);
    });

    testWidgets('D29 is off for a new window, and saved off', (WidgetTester tester) async {
      await open(tester, code);
      await openSidebar(tester);
      expect(inSidebar('D29 Option'), findsOneWidget);
      expect(inSidebar('D29'), findsNothing, reason: 'not listed while off');
      for (final String section in <String>[
        'EF30', 'EF27', 'EF26A', 'EF25', 'EF24', 'EF22', 'EF28',
      ]) {
        expect(inSidebar(section), findsOneWidget, reason: section);
      }
      await save(tester);
      final WindowReviewItem saved = session.items.single;
      expect(saved.windowCode, code);
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

      // The next Prime Economy window opens with it on.
      await open(tester, code);
      await openSidebar(tester);
      expect(inSidebar('D29'), findsOneWidget);
    });

    testWidgets("an ordinary window after it never opens on 0.9mm", (WidgetTester tester) async {
      await open(tester, code);
      await save(tester);
      expect(session.items.single.material.gauge, '0.9mm');

      // Same job: the next window would take the last one's stock.
      await open(tester, 'S_win', keepSession: true);
      await save(tester);
      expect(session.items.last.windowCode, 'S_win');
      expect(session.items.last.material.gauge, WindowGauges.g12,
          reason: "the shop's usual gauge, which has a price");
      expect(LastWindowMaterial.instance.value.gauge, WindowGauges.g12);
    });

    testWidgets('a finish picked on it carries over; its gauge does not', (
      WidgetTester tester,
    ) async {
      await LastWindowMaterial.instance.remember(
        const WindowMaterial(gauge: WindowGauges.g2, color: AluminiumColors.champagne),
      );
      await open(tester, code);
      const Key black = Key('aluminium_color_option_${AluminiumColors.black}');
      await tester.ensureVisible(find.byKey(black));
      await tester.tap(find.byKey(black));
      await tester.pumpAndSettle();
      expect(find.text('Multi/BLK Ral +'), findsOneWidget);
      expect(LastWindowMaterial.instance.value,
          const WindowMaterial(gauge: WindowGauges.g2, color: AluminiumColors.black));
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
