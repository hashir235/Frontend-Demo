import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/data/optimization_api_client.dart';
import 'package:my_app/features/estimation/data/optimization_repository.dart';
import 'package:my_app/features/estimation/models/cutting_report.dart';
import 'package:my_app/features/estimation/models/optimization_request.dart';
import 'package:my_app/features/estimation/models/window_review_item.dart';
import 'package:my_app/features/formulas/data/formula_book.dart';
import 'package:my_app/features/formulas/data/formula_book_loader.dart';
import 'package:my_app/features/formulas/data/formula_catalogue.dart';
import 'package:my_app/features/formulas/data/window_cut_calculator.dart';
import 'package:my_app/features/formulas/model/formula_overrides.dart';
import 'package:my_app/features/formulas/model/window_sides.dart';
import 'package:my_app/features/settings/data/estimation_settings_repository.dart';
import 'package:my_app/features/settings/data/fabrication_settings_repository.dart';
import 'package:my_app/features/settings/models/estimation_settings.dart';
import 'package:my_app/features/settings/models/fabrication_settings.dart';
import 'package:my_app/features/settings/state/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hashir, Oct 2026.
///
/// Task 1: a fix window measured side by side cuts every side as measured --
/// the bead (D41) as well as the frame -- however close the side facing it.
/// WT 34.4cm and WB 37cm is a 34.4 top and a 37 bottom; neither is swapped
/// for the smaller. The glass, one pane, still takes the smaller so it goes in.
///
/// Task 2: Settings' Cutting Report Unit is the unit asked for in every
/// fabrication run -- cm or inch -- whatever unit each window was typed in;
/// None asks for nothing and the windows decide, as before.
void main() {
  final FormulaCatalogue catalogue = FormulaCatalogue.fromJson(
    jsonDecode(File('assets/formulas/catalogue.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final FormulaBook book = FormulaBook(catalogue, FormulaOverrides.empty());
  final WindowCutCalculator calculator = WindowCutCalculator(book);

  const double margin = 0.5;
  const double feet = 30.48;
  double fab(double cm) => (cm + margin) / feet;

  WindowCutList cut(String code, SideSizes sides, {int collar = 2}) {
    return calculator.compute(
      WindowCutRequest(
        isFabrication: true,
        appWindowCode: code,
        collarIndex: collar,
        unitMode: 'cm',
        heightValue: '120',
        widthValue: '34.4',
        sideSizes: sides,
      ),
      margins: const <String, double>{'cm': margin},
    );
  }

  Map<String, double> of(WindowCutList list, String section) => <String, double>{
    for (final CutPiece p in list.pieces.where((CutPiece p) => p.section == section))
      p.label: p.lengthFt,
  };

  group('Task 1: fix windows, every side as measured', () {
    const SideSizes apart = SideSizes(<String, String>{
      'WT': '34.4',
      'WB': '37',
      'HL': '120',
      'HR': '121',
    });

    for (final String code in <String>['F_win', 'F_win_D51', 'F_win_D42']) {
      test('$code: frame and bead each to its own side', () {
        final WindowCutList list = cut(code, apart);
        expect(list.problems, isEmpty);
        final String frame = code == 'F_win' ? 'D54A' : 'D${code.substring(7)}A';
        final Map<String, double> d54 = of(list, frame);
        expect(d54['WT'], closeTo(fab(34.4), 1e-9));
        expect(d54['WB'], closeTo(fab(37), 1e-9));
        expect(d54['HL'], closeTo(fab(120), 1e-9));
        expect(d54['HR'], closeTo(fab(121), 1e-9));
        final Map<String, double> d41 = of(list, 'D41');
        expect(d41['WT'], closeTo(fab(34.4 - 3.4), 1e-9), reason: 'the top bead to the top');
        expect(d41['WB'], closeTo(fab(37 - 3.4), 1e-9), reason: 'the bottom bead to the bottom');
        expect(d41['HL'], closeTo(fab(120 - 3.4), 1e-9));
        expect(d41['HR'], closeTo(fab(121 - 3.4), 1e-9));
      });
    }

    test('even a hair apart: no smaller one taken for the bead', () {
      // 1mm apart, well inside 2 suter: an inner piece of any other window
      // would take the smaller; a fix window's bead does not.
      final WindowCutList list = cut(
        'F_win',
        const SideSizes(<String, String>{'WT': '34.4', 'WB': '34.5', 'HL': '120', 'HR': '120'}),
      );
      final Map<String, double> d41 = of(list, 'D41');
      expect(d41['WT'], closeTo(fab(34.4 - 3.4), 1e-9));
      expect(d41['WB'], closeTo(fab(34.5 - 3.4), 1e-9));
    });

    test('the glass, one pane, still the smaller of each pair', () {
      final WindowCutList list = cut('F_win', apart);
      expect(list.glass, hasLength(1));
      // Fix window glass: h - 4.4, w - 5.08 -- of the smaller pair.
      expect(list.glass.single.heightCm, closeTo(120 - 4.4, 1e-9));
      expect(list.glass.single.widthCm, closeTo(34.4 - 5.08, 1e-9));
    });

    test('corner fix: each wall\'s top and bottom bead to its own side', () {
      final WindowCutList list = calculator.compute(
        const WindowCutRequest(
          isFabrication: true,
          appWindowCode: 'FC_win',
          collarIndex: 2,
          unitMode: 'cm',
          heightValue: '120',
          widthValue: '60',
          leftWidthValue: '60',
          rightWidthValue: '80',
          sideSizes: SideSizes(<String, String>{
            'WT_l': '60',
            'WB_l': '60.2',
            'WT_r': '80',
            'WB_r': '81',
            'HL': '120',
            'HR': '120',
          }),
        ),
        margins: const <String, double>{'cm': margin},
      );
      expect(list.problems, isEmpty);
      final Map<String, double> d41 = of(list, 'D41');
      expect(d41['WT_l'], closeTo(fab(60 - 1.7), 1e-9));
      expect(d41['WB_l'], closeTo(fab(60.2 - 1.7), 1e-9));
      expect(d41['WT_r'], closeTo(fab(80 - 1.7), 1e-9));
      expect(d41['WB_r'], closeTo(fab(81 - 1.7), 1e-9));
    });

    test('a sliding window still keeps the 2-suter rule inside its frame', () {
      final WindowCutList list = calculator.compute(
        const WindowCutRequest(
          isFabrication: true,
          appWindowCode: 'S_win',
          collarIndex: 2,
          unitMode: 'cm',
          heightValue: '120',
          widthValue: '100',
          lockType: 1,
          rubberType: 'F',
          sideSizes: SideSizes(<String, String>{'WT': '100', 'WB': '100.3', 'HL': '120', 'HR': '120'}),
        ),
        margins: const <String, double>{'cm': margin},
      );
      final List<CutPiece> rails =
          list.pieces.where((CutPiece p) => p.section == 'M24').toList();
      expect(rails.map((CutPiece p) => p.lengthFt).toSet(), hasLength(1),
          reason: '3mm apart: every rail the smaller');
    });
  });

  group('Task 2: the cutting report unit', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      AppSettings.instance.resetForTest();
    });

    Future<String> sentUnit({required String context}) async {
      final _Api api = _Api();
      final OptimizationRepository repository = OptimizationRepository(
        apiClient: api,
        formulas: _Loader(book),
        fabricationSettings: _Settings(),
        estimationSettings: _EstimationSettings(),
      );
      await expectLater(
        repository.fetchLengthOptimization(
          <WindowReviewItem>[
            const WindowReviewItem(
              winNo: 1,
              windowLabel: 'Fix Window',
              windowCode: 'F_win',
              windowIndex: 17,
              collarIndex: 2,
              unitMode: UnitMode.inches,
              heightValue: '48.0',
              widthValue: '24.4',
            ),
          ],
          context: context,
          projectName: 'Job',
          projectLocation: 'Here',
        ),
        throwsA(isA<_Sent>()),
      );
      return api.sent!.displayUnit;
    }

    test('None: nothing asked, the windows decide (as every app before)', () async {
      expect(AppSettings.instance.cuttingReportUnit, CuttingReportUnit.none);
      expect(await sentUnit(context: 'fabrication'), 'ft');
    });

    test('cm: a window typed in inches is reported in cm', () async {
      AppSettings.instance.setCuttingReportUnit(CuttingReportUnit.cm);
      expect(await sentUnit(context: 'fabrication'), 'cm');
    });

    test('Inch: inch-suter', () async {
      AppSettings.instance.setCuttingReportUnit(CuttingReportUnit.inch);
      expect(await sentUnit(context: 'fabrication'), 'inch_sutter');
    });

    test('estimation is left alone', () async {
      AppSettings.instance.setCuttingReportUnit(CuttingReportUnit.cm);
      expect(await sentUnit(context: 'estimation'), 'ft');
    });

    test('the choice is kept on the phone', () async {
      AppSettings.instance.setCuttingReportUnit(CuttingReportUnit.inch);
      await pumpEventQueue();
      AppSettings.instance.resetForTest();
      await AppSettings.instance.load();
      expect(AppSettings.instance.cuttingReportUnit, CuttingReportUnit.inch);
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

class _EstimationSettings implements EstimationSettingsRepository {
  @override
  Future<EstimationSettingsModel> fetchEstimationSettings() async =>
      const EstimationSettingsModel(
        sectionLengths: <String, List<int>>{},
        cuttingMargins: <String, double>{},
        maxExtraPieces: 1,
        enforceMaxExtraPieces: false,
        redZoneEven: 12,
        redZoneOdd: 13,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Settings implements FabricationSettingsRepository {
  @override
  Future<FabricationSettingsModel> fetchFabricationSettings() async =>
      const FabricationSettingsModel(cuttingMarginCm: 0.5);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
