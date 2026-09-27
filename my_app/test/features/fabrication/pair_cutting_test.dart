import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/data/optimization_repository.dart';
import 'package:my_app/features/estimation/models/cutting_report.dart';
import 'package:my_app/features/estimation/models/section_recalculation.dart';
import 'package:my_app/features/estimation/models/window_review_item.dart';
import 'package:my_app/features/estimation/presentation/length_optimization_screen.dart';
import 'package:my_app/features/estimation/state/estimate_session_store.dart';
import 'package:my_app/features/settings/models/fabrication_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pair cutting: the fabrication setting that has M23 and M28 cut two bars at
/// a time, and how a pair shows on the cutting list -- one card, x 2.
void main() {
  Map<String, dynamic> cut(int windowNo, double ft, String display) =>
      <String, dynamic>{
        'label': 'Sliding Window #$windowNo -> 48x60 | H',
        'windowName': 'Sliding Window',
        'windowNo': windowNo,
        'dimension': '48x60',
        'lengthFt': ft,
        'lengthDisplay': display,
      };

  Map<String, dynamic> bar(
    double stock,
    List<Map<String, dynamic>> cuts, {
    int pairId = 0,
    bool offcut = false,
  }) => <String, dynamic>{
    'stockLenFt': stock,
    'stockLenDisplay': "$stock'",
    'wastageFt': 0.5,
    'wastageDisplay': "6''",
    'offcut': offcut,
    if (pairId > 0) 'pairId': pairId,
    'cuts': cuts,
  };

  CuttingReportSection section(List<Map<String, dynamic>> groups) =>
      CuttingReportSection.fromJson(<String, dynamic>{
        'name': 'M23',
        'gauge': '1.6mm',
        'color': 'BLACK',
        'summary': <String, dynamic>{
          'usedLengths': <double>[for (final g in groups) g['stockLenFt'] as double],
          'totalLength': 0,
        },
        'groups': groups,
      });

  group('the setting', () {
    test('off unless the server says on, and sent back as set', () {
      expect(const FabricationSettingsModel.defaults().pairCutting, isFalse);
      expect(
        FabricationSettingsModel.fromJson(<String, dynamic>{}).pairCutting,
        isFalse,
        reason: 'an older server sends nothing',
      );
      final FabricationSettingsModel on = FabricationSettingsModel.fromJson(
        <String, dynamic>{'cuttingMarginCm': 1.2, 'pairCutting': true},
      );
      expect(on.pairCutting, isTrue);
      expect(on.toJson()['pairCutting'], isTrue);
    });

    test('D29 has its own switch, off unless set', () {
      expect(const FabricationSettingsModel.defaults().pairCuttingD29, isFalse);
      final FabricationSettingsModel onlyM23 = FabricationSettingsModel.fromJson(
        <String, dynamic>{'pairCutting': true},
      );
      expect(onlyM23.pairCuttingD29, isFalse, reason: 'the M23 switch is not the D29 one');
      final FabricationSettingsModel d29 = FabricationSettingsModel.fromJson(
        <String, dynamic>{'pairCuttingD29': true},
      );
      expect(d29.pairCuttingD29, isTrue);
      expect(d29.pairCutting, isFalse);
      expect(d29.toJson()['pairCuttingD29'], isTrue);
    });
  });

  group('bars as the cutter handles them', () {
    test('a pair is one block; other bars stand alone', () {
      final CuttingReportSection s = section(<Map<String, dynamic>>[
        bar(16, <Map<String, dynamic>>[cut(1, 4, '48')], pairId: 1),
        bar(16, <Map<String, dynamic>>[cut(1, 4, '48')], pairId: 1),
        bar(18, <Map<String, dynamic>>[cut(3, 5, '60')]),
        bar(14, <Map<String, dynamic>>[cut(2, 4.5, '54')], pairId: 2),
        bar(14, <Map<String, dynamic>>[cut(4, 4.5, '54')], pairId: 2),
      ]);
      final List<CuttingReportBarBlock> blocks = s.barBlocksLongestFirst;
      expect(blocks.length, 3);
      expect(blocks[0].isPair, isFalse);
      expect(blocks[0].bar.stockLenFt, 18);
      expect(blocks[1].isPair, isTrue);
      expect(blocks[1].bar.stockLenFt, 16);
      expect(blocks[2].isPair, isTrue);
      expect(blocks[2].twinCutAt(0)?.windowNo, 4);
      expect(s.hasPairs, isTrue);
    });

    test('with no pairs, one block per bar at the index it always had', () {
      final CuttingReportSection s = section(<Map<String, dynamic>>[
        bar(14, <Map<String, dynamic>>[cut(1, 4, '48')]),
        bar(18, <Map<String, dynamic>>[cut(2, 5, '60')]),
        bar(16, <Map<String, dynamic>>[cut(3, 4.4, '53')]),
      ]);
      final List<CuttingReportBarBlock> blocks = s.barBlocksLongestFirst;
      expect(blocks.map((CuttingReportBarBlock b) => b.index), <int>[0, 1, 2]);
      expect(blocks.every((CuttingReportBarBlock b) => !b.isPair), isTrue);
      expect(
        blocks.map((CuttingReportBarBlock b) => b.bar.stockLenFt),
        <double>[18, 16, 14],
      );
      expect(s.hasPairs, isFalse);
    });

    test('a recalculation names the pile it means', () {
      final SectionRecalculationRequest request = SectionRecalculationRequest(
        context: 'fabrication',
        displayUnit: 'inch_sutter',
        sectionName: 'M23',
        sectionGauge: '2mm',
        sectionColor: 'BLACK',
        sourceCuts: const <CuttingReportCut>[],
        stockOptions: const <SectionStockAvailability>[],
      );
      expect(request.toJson()['sectionGauge'], '2mm');
      expect(request.toJson()['sectionColor'], 'BLACK');
    });
  });

  group('the cutting list', () {
    Future<void> open(WidgetTester tester, CuttingReport report) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: LengthOptimizationScreen(
            session: EstimateSessionStore(
              projectName: 'Pair Test',
              projectLocation: 'Lahore',
              flow: EstimateFlow.fabrication,
            ),
            items: const <WindowReviewItem>[],
            projectName: 'Pair Test',
            projectLocation: 'Lahore',
            requestContext: 'fabrication',
            repository: _FixedReport(report),
            showPdfActions: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    CuttingReport report(List<Map<String, dynamic>> groups) =>
        CuttingReport.fromJson(<String, dynamic>{
          'ok': true,
          'context': 'fabrication',
          'displayUnit': 'inch_sutter',
          'errors': <String>[],
          'sections': <Map<String, dynamic>>[
            <String, dynamic>{
              'name': 'M23',
              'gauge': '1.6mm',
              'color': 'BLACK',
              'summary': <String, dynamic>{
                'usedLengths': <double>[for (final g in groups) g['stockLenFt'] as double],
                'usedLengthsDisplay': <String>[],
                'totalLength': 0,
                'totalLengthDisplay': '',
              },
              'groups': groups,
            },
          ],
        });

    testWidgets('a pair shows once, marked x 2, both windows named', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        report(<Map<String, dynamic>>[
          bar(16, <Map<String, dynamic>>[cut(2, 4, "48'' 0'''"), cut(1, 4, "48'' 0'''")], pairId: 1),
          bar(16, <Map<String, dynamic>>[cut(4, 4, "48'' 0'''"), cut(1, 4, "48'' 0'''")], pairId: 1),
        ]),
      );

      expect(find.byKey(const Key('pair_cutting_note')), findsOneWidget);
      expect(find.textContaining('x 2 — cut together'), findsOneWidget);
      expect(find.text('2 / 4'), findsOneWidget, reason: 'the twins go to windows 2 and 4');
      expect(find.text('1'), findsWidgets, reason: 'both twins go to window 1');
      expect(find.text('1 / 1'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('without pairs, nothing about pairs', (WidgetTester tester) async {
      await open(
        tester,
        report(<Map<String, dynamic>>[
          bar(16, <Map<String, dynamic>>[cut(1, 4, "48'' 0'''")]),
          bar(14, <Map<String, dynamic>>[cut(2, 4, "48'' 0'''")]),
        ]),
      );
      expect(find.byKey(const Key('pair_cutting_note')), findsNothing);
      expect(find.textContaining('x 2'), findsNothing);
    });
  });
}

class _FixedReport extends OptimizationRepository {
  final CuttingReport report;

  _FixedReport(this.report);

  @override
  Future<CuttingReport> fetchLengthOptimization(
    List<WindowReviewItem> items, {
    String? projectId,
    String context = 'estimation',
    String displayUnit = 'ft',
    required String projectName,
    required String projectLocation,
  }) async => report;
}
