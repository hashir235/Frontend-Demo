import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/data/cost_table_api_client.dart';
import 'package:my_app/features/estimation/data/optimization_repository.dart';
import 'package:my_app/features/estimation/data/rate_review_api_client.dart';
import 'package:my_app/features/estimation/models/cost_table.dart';
import 'package:my_app/features/estimation/models/cutting_report.dart';
import 'package:my_app/features/estimation/models/rate_review.dart';
import 'package:my_app/features/estimation/models/window_material.dart';
import 'package:my_app/features/estimation/models/window_review_item.dart';
import 'package:my_app/features/estimation/presentation/bill_inputs_screen.dart';
import 'package:my_app/features/estimation/presentation/estimation_material_table_screen.dart';
import 'package:my_app/features/estimation/presentation/length_optimization_screen.dart';
import 'package:my_app/features/estimation/presentation/rate_review_screen.dart';
import 'package:my_app/features/estimation/presentation/review_list_screen.dart';
import 'package:my_app/features/estimation/state/estimate_session_store.dart';
import 'package:my_app/features/flow_nav/models/flow_step.dart';
import 'package:my_app/features/flow_nav/state/flow_progress.dart';
import 'package:my_app/shared/widgets/next_step_action.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Review's Next on an estimate lands on Bill Inputs. The lengths, rates and
/// material table are worked out on the way, exactly once each, and wait
/// under it already filled; a step that fails is where the run stops.
void main() {
  late _Optimizer optimizer;
  late _Rates rates;
  late _Costs costs;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FlowProgress.instance.resetForTest();
    FlowProgress.instance.enter(estimationFlow);
    optimizer = _Optimizer();
    rates = _Rates();
    costs = _Costs();
  });

  EstimateSessionStore session({EstimateFlow flow = EstimateFlow.estimation}) {
    final EstimateSessionStore store = EstimateSessionStore(
      projectName: 'House 12',
      projectLocation: 'Lahore',
      flow: flow,
    );
    store.addItem(
      winNo: 1,
      windowLabel: 'Sliding Window',
      windowCode: 'S_win',
      windowIndex: 1,
      collarIndex: 1,
      unitMode: UnitMode.inches,
      heightValue: '48',
      widthValue: '60',
      material: const WindowMaterial(gauge: '2mm', color: 'DULL'),
      glassColor: 'Clear 5mm',
    );
    return store;
  }

  Future<void> openReview(
    WidgetTester tester,
    EstimateSessionStore store,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: ReviewListScreen(
          session: store,
          optimization: optimizer,
          rates: rates,
          costs: costs,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pressNext(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('review_next_button')));
    await tester.pumpAndSettle();
  }

  testWidgets('Next lands on Bill Inputs, each step worked out once', (
    WidgetTester tester,
  ) async {
    final EstimateSessionStore store = session();
    await openReview(tester, store);
    await pressNext(tester);

    expect(find.byType(BillInputsScreen), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Bill Inputs'), findsOneWidget);
    expect(find.byKey(const Key('preparing_bill_dialog')), findsNothing);
    // Every step is under it, filled.
    for (final Type screen in <Type>[
      LengthOptimizationScreen,
      RateReviewScreen,
      EstimationMaterialTableScreen,
    ]) {
      expect(find.byType(screen, skipOffstage: false), findsOneWidget);
    }
    expect(optimizer.calls, 1);
    expect(rates.calls, 1);
    expect(costs.sent, hasLength(1));
    // Priced with the rates the rate screen would have sent on, stock and all.
    expect(costs.sent.single.map((RateOverrideInput o) => o.toJson()), <Object>[
      <String, Object?>{
        'section': 'DC30C',
        'gauge': '2mm',
        'color': 'DULL',
        'rate': 820.0,
      },
      <String, Object?>{
        'section': 'DC26C',
        'gauge': '2mm',
        'color': 'DULL',
        'rate': 640.5,
      },
    ]);
    expect(store.rateOverrides, hasLength(2));
    expect(costs.gauge, '2mm');
    expect(costs.color, 'DULL');
  });

  testWidgets(
    'the bubbles open the steps as they stand, nothing fetched again',
    (WidgetTester tester) async {
      await openReview(tester, session());
      await pressNext(tester);

      await tester.tap(find.text(FlowSteps.rates.label));
      await tester.pumpAndSettle();
      expect(find.text('Rate Setting'), findsOneWidget);
      expect(find.text('DC30C'), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Bill Inputs'), findsNothing);

      await tester.tap(find.text(FlowSteps.lengthOptimization.label));
      await tester.pumpAndSettle();
      expect(find.text('Length Optimization'), findsOneWidget);

      expect(optimizer.calls, 1);
      expect(rates.calls, 1);
      expect(costs.sent, hasLength(1));
    },
  );

  testWidgets('a failed optimization stops on Lengths, which says why', (
    WidgetTester tester,
  ) async {
    optimizer.failWith = Exception('Your phone is not connected.');
    await openReview(tester, session());
    await pressNext(tester);

    expect(find.byType(BillInputsScreen, skipOffstage: false), findsNothing);
    expect(find.text('Length Optimization'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(rates.calls, 0);
    expect(costs.sent, isEmpty);
  });

  testWidgets('no sections to cut: stops on Lengths with its message', (
    WidgetTester tester,
  ) async {
    optimizer.report = const CuttingReport(
      ok: true,
      context: 'estimation',
      displayUnit: 'ft',
      errors: <String>[],
      sections: <CuttingReportSection>[],
    );
    await openReview(tester, session());
    await pressNext(tester);

    expect(find.text('Length Optimization'), findsOneWidget);
    expect(find.text('No optimization data'), findsOneWidget);
    expect(
      optimizer.calls,
      1,
      reason: 'the report is shown, not fetched again',
    );
    expect(rates.calls, 0);
  });

  testWidgets('failed rates stop on Rates, Lengths under it', (
    WidgetTester tester,
  ) async {
    rates.failWith = Exception('Missing rate for section DC30C');
    await openReview(tester, session());
    await pressNext(tester);

    expect(find.text('Rate Setting'), findsOneWidget);
    expect(
      find.byType(LengthOptimizationScreen, skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.byType(EstimationMaterialTableScreen, skipOffstage: false),
      findsNothing,
    );
    expect(costs.sent, isEmpty);
  });

  testWidgets('Cancel stays on Review and opens nothing', (
    WidgetTester tester,
  ) async {
    final Completer<CuttingReport> slow = Completer<CuttingReport>();
    optimizer.waitFor = slow;
    await openReview(tester, session());
    await tester.tap(find.byKey(const Key('review_next_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Preparing your bill'), findsOneWidget);
    expect(find.text('Cutting lengths'), findsOneWidget);

    await tester.tap(find.byKey(const Key('preparing_bill_cancel')));
    await tester.pumpAndSettle();
    slow.complete(_report());
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Review'), findsOneWidget);
    expect(
      find.byType(LengthOptimizationScreen, skipOffstage: false),
      findsNothing,
    );
    expect(rates.calls, 0);
  });

  testWidgets('a rate changed by hand keeps its stock', (
    WidgetTester tester,
  ) async {
    final EstimateSessionStore store = session();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: RateReviewScreen(
          session: store,
          gaugeLabel: '2mm',
          gaugeValue: '2mm',
          colorLabel: 'DULL',
          colorValue: 'DULL',
          projectName: 'House 12',
          projectLocation: 'Lahore',
          costTableApiClient: costs,
          initialReview: _review(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(rates.calls, 0, reason: 'handed over, not fetched');

    await tester.enterText(find.widgetWithText(TextFormField, '820'), '900');
    await tester.tap(find.byType(NextStepAction));
    await tester.pumpAndSettle();

    final RateOverrideInput edited = costs.sent.single.firstWhere(
      (RateOverrideInput o) => o.section == 'DC30C',
    );
    expect(edited.rate, 900);
    expect(edited.gauge, '2mm');
    expect(edited.color, 'DULL');
  });

  testWidgets('a fabrication job keeps the step-by-step way', (
    WidgetTester tester,
  ) async {
    await openReview(tester, session(flow: EstimateFlow.fabrication));
    await tester.tap(find.byKey(const Key('review_next_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byKey(const Key('preparing_bill_dialog')), findsNothing);
    expect(find.byType(LengthOptimizationScreen), findsOneWidget);
    await tester.pumpAndSettle();
    expect(optimizer.calls, 1, reason: 'its own screen does the work there');
    expect(find.byType(BillInputsScreen, skipOffstage: false), findsNothing);
    expect(rates.calls, 0);
  });
}

CuttingReport _report() => const CuttingReport(
  ok: true,
  context: 'estimation',
  displayUnit: 'ft',
  errors: <String>[],
  sections: <CuttingReportSection>[
    CuttingReportSection(
      name: 'DC30C',
      summary: null,
      groups: <CuttingReportGroup>[
        CuttingReportGroup(
          stockLenFt: 16,
          stockLenDisplay: '16',
          wastageFt: 1,
          wastageDisplay: '1',
          offcut: false,
          cuts: <CuttingReportCut>[
            CuttingReportCut(
              label: 'S_win|H',
              windowName: 'Sliding Window',
              windowNo: 1,
              dimension: '48x60',
              lengthFt: 4,
              lengthDisplay: '48',
            ),
          ],
        ),
      ],
      allowedLengthsFt: <double>[16],
      allowedLengthsDisplay: <String>['16'],
    ),
  ],
);

RateReview _review() => const RateReview(
  ok: true,
  errors: <String>[],
  gauge: '2mm',
  color: 'DULL',
  rows: <RateReviewRow>[
    RateReviewRow(
      section: 'DC30C',
      gauge: '2mm',
      color: 'DULL',
      totalFt: 16,
      totalFtDisplay: '16 ft',
      rate: 820,
    ),
    RateReviewRow(
      section: 'DC26C',
      gauge: '2mm',
      color: 'DULL',
      totalFt: 12,
      totalFtDisplay: '12 ft',
      rate: 640.5,
    ),
  ],
);

class _Optimizer extends OptimizationRepository {
  int calls = 0;
  Object? failWith;
  Completer<CuttingReport>? waitFor;
  CuttingReport report = _report();

  @override
  Future<CuttingReport> fetchLengthOptimization(
    List<WindowReviewItem> items, {
    String? projectId,
    String context = 'estimation',
    String? displayUnit,
    required String projectName,
    required String projectLocation,
  }) async {
    calls++;
    if (failWith != null) throw failWith!;
    if (waitFor != null) return waitFor!.future;
    return report;
  }
}

class _Rates extends RateReviewApiClient {
  int calls = 0;
  Object? failWith;

  @override
  Future<RateReview> fetchRateReview({
    required String gauge,
    required String color,
    String? projectId,
    String context = 'estimation',
  }) async {
    calls++;
    if (failWith != null) throw failWith!;
    return _review();
  }
}

class _Costs extends CostTableApiClient {
  final List<List<RateOverrideInput>> sent = <List<RateOverrideInput>>[];
  String? gauge;
  String? color;

  @override
  Future<CostTable> fetchCostTable({
    required String gauge,
    required String color,
    String? projectId,
    List<RateOverrideInput> overrides = const <RateOverrideInput>[],
    String context = 'estimation',
  }) async {
    sent.add(overrides);
    this.gauge = gauge;
    this.color = color;
    return const CostTable(
      ok: true,
      errors: <String>[],
      context: 'estimation',
      gauge: '2mm',
      color: 'DULL',
      grandTotal: 20807,
      rows: <CostTableRow>[],
    );
  }
}
