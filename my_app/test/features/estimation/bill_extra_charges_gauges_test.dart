import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/data/billing_repository.dart';
import 'package:my_app/features/estimation/models/bill_request.dart';
import 'package:my_app/features/estimation/models/bill_snapshot.dart';
import 'package:my_app/features/estimation/models/estimate_flow_state.dart';
import 'package:my_app/features/estimation/models/extra_charge.dart';
import 'package:my_app/features/estimation/models/window_material.dart';
import 'package:my_app/features/estimation/models/window_review_item.dart';
import 'package:my_app/features/estimation/presentation/actual_bill_screen.dart';
import 'package:my_app/features/estimation/presentation/bill_inputs_screen.dart';
import 'package:my_app/features/estimation/state/estimate_session_store.dart';
import 'package:my_app/features/estimation/state/invoice_print_choices.dart';
import 'package:my_app/features/flow_nav/models/flow_step.dart';
import 'package:my_app/features/flow_nav/state/flow_progress.dart';
import 'package:my_app/shared/widgets/next_step_action.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The bill says what each extra charge is for, a line each, and names every
/// gauge the job is made in -- or the one (Hashir, Oct 2026).
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    InvoicePrintChoices.instance.resetForTest();
    FlowProgress.instance.resetForTest();
    FlowProgress.instance.enter(estimationFlow);
  });

  EstimateSessionStore jobIn(List<String> gauges) {
    final EstimateSessionStore store = EstimateSessionStore(
      projectName: 'House 12',
      projectLocation: 'Lahore',
    );
    for (int i = 0; i < gauges.length; i++) {
      store.addItem(
        winNo: i + 1,
        windowLabel: 'F/C Sliding Window',
        windowCode: 'S_win',
        windowIndex: 1,
        collarIndex: 1,
        unitMode: UnitMode.inches,
        heightValue: '48',
        widthValue: '60',
        material: WindowMaterial(gauge: gauges[i], color: 'DULL'),
        glassColor: 'Clear 5mm',
      );
    }
    return store;
  }

  group('gauges', () {
    test('listed once each, thinnest first', () {
      expect(
        WindowGauges.inOrder(<String>['2mm', '1.2mm', '0.9mm', '1.2mm', '1.6mm']),
        <String>['0.9mm', '1.2mm', '1.6mm', '2mm'],
      );
      expect(WindowGauges.inOrder(<String>['1.6mm']), <String>['1.6mm']);
      expect(WindowGauges.inOrder(<String>['', '  ']), isEmpty);
      // One the list does not know goes last, in the order it came.
      expect(
        WindowGauges.inOrder(<String>['3mm', '1mm', '2.5mm']),
        <String>['1mm', '3mm', '2.5mm'],
      );
    });

    test('a job in one gauge names the one; a mixed job names them all', () {
      expect(jobIn(<String>['1.2mm', '1.2mm', '1.2mm']).gaugesUsed, <String>[
        '1.2mm',
      ]);
      expect(jobIn(<String>['2mm', '1.2mm', '2mm', '1mm']).gaugesUsed, <String>[
        '1mm',
        '1.2mm',
        '2mm',
      ]);
      expect(jobIn(<String>[]).gaugesUsed, isEmpty);
    });

    test('a window with no gauge of its own counts as the job-wide one', () {
      final EstimateSessionStore store = jobIn(<String>['1.6mm', '']);
      expect(store.gaugesUsed, <String>['1.6mm']);
    });

    test('kept with the bill, and shown from it', () {
      final BillSnapshot mixed = BillSnapshot.fromJson(<String, dynamic>{
        'gauge': '1.2mm',
        'gauges': <Object?>['1.2mm', '2mm', 7, ''],
      });
      expect(mixed.gauges, <String>['1.2mm', '2mm']);
      expect(mixed.gaugesShown, <String>['1.2mm', '2mm']);
      // A bill made before the list was kept shows its one gauge, as it did.
      final BillSnapshot old = BillSnapshot.fromJson(<String, dynamic>{
        'gauge': '1.6mm',
      });
      expect(old.gauges, isEmpty);
      expect(old.gaugesShown, <String>['1.6mm']);
    });
  });

  group('extra charge lines', () {
    test('read back from a bill, junk left out', () {
      final List<ExtraCharge> lines = ExtraCharge.listFromJson(<Object?>[
        <String, Object?>{'description': ' Transport ', 'amount': 2500},
        <String, Object?>{'description': 'Silicon', 'amount': '1250.5'},
        <String, Object?>{'description': 'free', 'amount': 0},
        <String, Object?>{'description': 'minus', 'amount': -5},
        'not a line',
        null,
      ]);
      expect(lines, const <ExtraCharge>[
        ExtraCharge(description: 'Transport', amount: 2500),
        ExtraCharge(description: 'Silicon', amount: 1250.5),
      ]);
      expect(ExtraCharge.totalOf(lines), 3750.5);
      expect(ExtraCharge.listFromJson(null), isEmpty);
      expect(
        const ExtraCharge(description: '', amount: 5).labelOr('Extra Charges'),
        'Extra Charges',
      );
    });

    test('sent with the total, and only when there are any', () {
      const BillRequest plain = BillRequest(
        projectId: 'p-1',
        glassRatePerSqFt: 180,
        laborRatePerSqFt: 120,
        hardwareRatePerWindow: 1500,
        aluminiumDiscountPercent: 0,
        aluminiumTotal: 1000,
        extraCharges: 0,
        advancePaid: 0,
        gauge: '1.2mm',
        aluminiumColor: 'DULL',
        glassColor: '',
        projectName: 'House 12',
        projectLocation: 'Lahore',
        customerName: '',
        customerPhone: '',
        customerAddress: '',
      );
      // Unchanged on the wire for a bill with neither.
      expect(plain.toJson().containsKey('extraChargeItems'), isFalse);
      expect(plain.toJson().containsKey('gauges'), isFalse);

      const BillRequest withLines = BillRequest(
        projectId: 'p-1',
        glassRatePerSqFt: 180,
        laborRatePerSqFt: 120,
        hardwareRatePerWindow: 1500,
        aluminiumDiscountPercent: 0,
        aluminiumTotal: 1000,
        extraCharges: 3500,
        extraChargeItems: <ExtraCharge>[
          ExtraCharge(description: 'Transport', amount: 2500),
          ExtraCharge(description: 'Silicon', amount: 1000),
        ],
        advancePaid: 0,
        gauge: '1.2mm',
        gauges: <String>['1.2mm', '2mm'],
        aluminiumColor: 'DULL',
        glassColor: '',
        projectName: 'House 12',
        projectLocation: 'Lahore',
        customerName: '',
        customerPhone: '',
        customerAddress: '',
      );
      final Map<String, Object?> json = withLines.toJson();
      expect(json['extraCharges'], 3500);
      expect(json['extraChargeItems'], <Map<String, Object?>>[
        <String, Object?>{'description': 'Transport', 'amount': 2500.0},
        <String, Object?>{'description': 'Silicon', 'amount': 1000.0},
      ]);
      expect(json['gauge'], '1.2mm');
      expect(json['gauges'], <String>['1.2mm', '2mm']);
    });

    test('an opened project brings its lines back to Bill Inputs', () {
      final EstimateBillDraft? draft = estimateBillDraftFromProjectOutputs(
        <String, dynamic>{
          'billResult': <String, dynamic>{
            'totals': <String, dynamic>{'extraCharges': 3500.5},
            'extraChargeItems': <Map<String, dynamic>>[
              <String, dynamic>{'description': 'Transport', 'amount': 2500},
              <String, dynamic>{'description': '', 'amount': 1000.5},
            ],
          },
        },
      );
      expect(draft, isNotNull);
      expect(draft!.extraCharges, '3500.5');
      expect(
        draft.extraChargeLines.map((ExtraChargeDraft l) => <String>[
          l.description,
          l.amount,
        ]),
        <List<String>>[
          <String>['Transport', '2500'],
          <String>['', '1000.5'],
        ],
      );
    });
  });

  group('Bill Inputs', () {
    Future<void> open(
      WidgetTester tester,
      EstimateSessionStore store,
    ) async {
      // A small phone: the lines must fit across 360dp.
      tester.view.physicalSize = const Size(360 * 3, 2400 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: BillInputsScreen(
            session: store,
            aluminiumTotal: 1000,
            gaugeLabel: '1.2mm',
            gaugeValue: '1.2mm',
            colorLabel: 'Dull',
            colorValue: 'DULL',
            projectId: 'p-1',
            projectName: 'House 12',
            projectLocation: 'Lahore',
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder forWhat() => find.widgetWithText(TextFormField, 'What is it for?');
    Finder amount() => find.widgetWithText(TextFormField, 'Amount');

    Future<void> fillRates(WidgetTester tester) async {
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Glass Rate *'),
        '180',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Labor Rate *'),
        '120',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Hardware Rate *'),
        '1500',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Aluminium Discount % *'),
        '0',
      );
    }

    Future<void> pressNext(WidgetTester tester) async {
      await tester.tap(find.byType(NextStepAction));
      await tester.pumpAndSettle();
    }

    testWidgets('the header names every gauge in the job', (
      WidgetTester tester,
    ) async {
      await open(tester, jobIn(<String>['2mm', '1.2mm', '2mm']));
      expect(find.text('Gage: 1.2mm, 2mm'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('one gauge throughout: the one', (WidgetTester tester) async {
      await open(tester, jobIn(<String>['1.6mm', '1.6mm']));
      expect(find.text('Gage: 1.6mm'), findsOneWidget);
    });

    testWidgets('lines, each with what it is for, go to the bill as one total', (
      WidgetTester tester,
    ) async {
      final EstimateSessionStore store = jobIn(<String>['1.2mm', '2mm']);
      await open(tester, store);
      expect(forWhat(), findsOneWidget, reason: 'one line to start');

      await tester.enterText(forWhat().at(0), 'Transport');
      await tester.enterText(amount().at(0), '2500');
      await tester.ensureVisible(find.byKey(const Key('bill_add_extra_charge')));
      await tester.tap(find.byKey(const Key('bill_add_extra_charge')));
      await tester.pumpAndSettle();
      await tester.enterText(forWhat().at(1), 'Extra silicon');
      await tester.enterText(amount().at(1), '1250.5');
      await tester.pumpAndSettle();
      expect(find.text('Total: 3750.5'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await fillRates(tester);
      await pressNext(tester);

      final BillRequest request = tester
          .widget<ActualBillScreen>(find.byType(ActualBillScreen))
          .request;
      expect(request.extraCharges, 3750.5);
      expect(request.extraChargeItems, const <ExtraCharge>[
        ExtraCharge(description: 'Transport', amount: 2500),
        ExtraCharge(description: 'Extra silicon', amount: 1250.5),
      ]);
      expect(request.gauges, <String>['1.2mm', '2mm']);
      expect(request.gauge, '1.2mm', reason: 'the engine still gets its one');
      // Kept for coming back to this screen.
      expect(
        store.billDraft!.extraChargeLines.map(
          (ExtraChargeDraft l) => '${l.description}=${l.amount}',
        ),
        <String>['Transport=2500', 'Extra silicon=1250.5'],
      );
    });

    testWidgets('a line that says what it is for needs an amount', (
      WidgetTester tester,
    ) async {
      await open(tester, jobIn(<String>['1.2mm']));
      await fillRates(tester);
      await tester.enterText(forWhat().at(0), 'Transport');
      await pressNext(tester);
      expect(find.byType(ActualBillScreen), findsNothing);
      expect(find.text('Enter the amount'), findsOneWidget);
    });

    testWidgets('an amount with nothing said is still a charge', (
      WidgetTester tester,
    ) async {
      await open(tester, jobIn(<String>['1.2mm']));
      await fillRates(tester);
      await tester.enterText(amount().at(0), '700');
      await pressNext(tester);
      final BillRequest request = tester
          .widget<ActualBillScreen>(find.byType(ActualBillScreen))
          .request;
      expect(request.extraCharges, 700);
      expect(request.extraChargeItems, const <ExtraCharge>[
        ExtraCharge(description: '', amount: 700),
      ]);
    });

    testWidgets('no extra charges: nothing extra is sent', (
      WidgetTester tester,
    ) async {
      await open(tester, jobIn(<String>['1.2mm']));
      await fillRates(tester);
      await pressNext(tester);
      final BillRequest request = tester
          .widget<ActualBillScreen>(find.byType(ActualBillScreen))
          .request;
      expect(request.extraCharges, 0);
      expect(request.extraChargeItems, isEmpty);
    });

    testWidgets('a line removed takes its amount with it', (
      WidgetTester tester,
    ) async {
      await open(tester, jobIn(<String>['1.2mm']));
      await tester.enterText(forWhat().at(0), 'Transport');
      await tester.enterText(amount().at(0), '2500');
      await tester.tap(find.byKey(const Key('bill_add_extra_charge')));
      await tester.pumpAndSettle();
      await tester.enterText(forWhat().at(1), 'Silicon');
      await tester.enterText(amount().at(1), '500');
      await tester.pumpAndSettle();

      // Remove the first: the second keeps its own words and amount.
      await tester.tap(find.byTooltip('Remove').first);
      await tester.pumpAndSettle();
      expect(forWhat(), findsOneWidget);
      expect(find.text('Silicon'), findsOneWidget);
      expect(find.text('Transport'), findsNothing);
      expect(find.byTooltip('Remove'), findsNothing, reason: 'one line left');
      expect(tester.takeException(), isNull);

      await fillRates(tester);
      await pressNext(tester);
      final BillRequest request = tester
          .widget<ActualBillScreen>(find.byType(ActualBillScreen))
          .request;
      expect(request.extraCharges, 500);
      expect(request.extraChargeItems.single.description, 'Silicon');
    });

    testWidgets('lines come back when the screen is opened again', (
      WidgetTester tester,
    ) async {
      final EstimateSessionStore store = jobIn(<String>['1.2mm']);
      store.setBillDraft(
        const EstimateBillDraft(
          extraCharges: '3000',
          extraChargeLines: <ExtraChargeDraft>[
            ExtraChargeDraft(description: 'Transport', amount: '2000'),
            ExtraChargeDraft(description: 'Silicon', amount: '1000'),
          ],
        ),
      );
      await open(tester, store);
      expect(forWhat(), findsNWidgets(2));
      expect(find.text('Transport'), findsOneWidget);
      expect(find.text('Silicon'), findsOneWidget);
      expect(find.text('Total: 3000'), findsOneWidget);
    });

    testWidgets('a bill whose extra was one figure comes back as one line', (
      WidgetTester tester,
    ) async {
      final EstimateSessionStore store = jobIn(<String>['1.2mm']);
      store.setBillDraft(const EstimateBillDraft(extraCharges: '1500'));
      await open(tester, store);
      expect(forWhat(), findsOneWidget);
      expect(find.text('1500'), findsOneWidget);
    });
  });

  group('the Final Bill', () {
    Map<String, dynamic> bill({
      List<Map<String, dynamic>>? items,
      List<String>? gauges,
      double extra = 3750.5,
    }) {
      return <String, dynamic>{
        'ok': true,
        'gauge': '1.2mm',
        'gauges': ?gauges,
        'aluminiumColor': 'DULL',
        'glassColor': 'Clear 5mm',
        'customer': <String, dynamic>{'name': 'Ahmed'},
        'project': <String, dynamic>{'name': 'House 12', 'location': 'Lahore'},
        'company': <String, dynamic>{'workshopName': 'Test Workshop'},
        'rates': <String, dynamic>{
          'glassPerSqFt': 180,
          'laborPerSqFt': 120,
          'hardwarePerWindow': 1500,
          'aluminiumDiscountPercent': 0,
        },
        'totals': <String, dynamic>{
          'totalWindows': 2,
          'totalArea': 30,
          'glassCost': 5400,
          'laborCost': 3600,
          'hardwareCost': 3000,
          'aluminiumOriginal': 20000,
          'aluminiumDiscount': 0,
          'aluminiumAfterDiscount': 20000,
          'extraCharges': extra,
          'advancePaid': 0,
          'grandTotal': 32000 + extra,
          'remainingDue': 32000 + extra,
        },
        'windowSummary': <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'F/C Sliding Window',
            'quantity': 2,
            'areaSqFt': 30,
            'hardwareRate': 1500,
            'hardwareCost': 3000,
          },
        ],
        'extraChargeItems': ?items,
      };
    }

    const BillRequest request = BillRequest(
      projectId: 'p-1',
      glassRatePerSqFt: 180,
      laborRatePerSqFt: 120,
      hardwareRatePerWindow: 1500,
      aluminiumDiscountPercent: 0,
      aluminiumTotal: 20000,
      extraCharges: 3750.5,
      extraChargeItems: <ExtraCharge>[
        ExtraCharge(description: 'Transport', amount: 2500),
        ExtraCharge(description: 'Extra silicon', amount: 1250.5),
      ],
      advancePaid: 0,
      gauge: '1.2mm',
      gauges: <String>['1.2mm', '2mm'],
      aluminiumColor: 'DULL',
      glassColor: 'Clear 5mm',
      projectName: 'House 12',
      projectLocation: 'Lahore',
      customerName: 'Ahmed',
      customerPhone: '',
      customerAddress: '',
    );

    Future<EstimateSessionStore> open(
      WidgetTester tester,
      Map<String, dynamic> json,
    ) async {
      tester.view.physicalSize = const Size(360 * 3, 6000 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final EstimateSessionStore store = EstimateSessionStore(
        projectName: 'House 12',
        projectLocation: 'Lahore',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ActualBillScreen(
            session: store,
            request: request,
            repository: _FakeBills(BillSnapshot.fromJson(json)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return store;
    }

    final List<Map<String, dynamic>> twoLines = <Map<String, dynamic>>[
      <String, dynamic>{'description': 'Transport', 'amount': 2500},
      <String, dynamic>{'description': 'Extra silicon', 'amount': 1250.5},
    ];

    testWidgets('each extra charge is a line under what it is for', (
      WidgetTester tester,
    ) async {
      await open(tester, bill(items: twoLines, gauges: <String>['1.2mm', '2mm']));
      expect(tester.takeException(), isNull);
      expect(find.text('Transport'), findsOneWidget);
      expect(find.text('2500'), findsOneWidget);
      expect(find.text('Extra silicon'), findsOneWidget);
      expect(find.text('1250.5'), findsOneWidget);
      // In place of the one total.
      expect(find.text('Extra Charges'), findsNothing);
      expect(find.text('3750.5'), findsNothing);
    });

    testWidgets('the lines are one print switch, as on the PDF', (
      WidgetTester tester,
    ) async {
      await open(tester, bill(items: twoLines));
      final Finder line = find.text('Extra silicon');
      await tester.ensureVisible(line);
      await tester.tap(line);
      await tester.pumpAndSettle();
      expect(
        InvoicePrintChoices.instance.prints(InvoiceFigure.extraCharges),
        isFalse,
      );
      // Both lines dim together.
      expect(find.byIcon(Icons.print_disabled_outlined), findsNWidgets(2));
    });

    testWidgets('a line with nothing said reads Extra Charges', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        bill(
          extra: 700,
          items: <Map<String, dynamic>>[
            <String, dynamic>{'description': '', 'amount': 700},
          ],
        ),
      );
      expect(find.text('Extra Charges'), findsOneWidget);
      expect(find.text('700'), findsOneWidget);
    });

    testWidgets('a bill without lines shows its one total, as before', (
      WidgetTester tester,
    ) async {
      await open(tester, bill(extra: 1700));
      expect(find.text('Extra Charges'), findsOneWidget);
      expect(find.text('1700'), findsOneWidget);
    });

    testWidgets('every gauge in the job is named, twice', (
      WidgetTester tester,
    ) async {
      await open(tester, bill(items: twoLines, gauges: <String>['1.2mm', '2mm']));
      expect(find.text('Gage: 1.2mm, 2mm'), findsOneWidget);
      // And in Input Details.
      expect(find.text('1.2mm, 2mm'), findsOneWidget);
    });

    testWidgets('one gauge: the one', (WidgetTester tester) async {
      await open(tester, bill(gauges: <String>['1.6mm']));
      expect(find.text('Gage: 1.6mm'), findsOneWidget);
    });

    testWidgets('going back keeps the lines as typed', (
      WidgetTester tester,
    ) async {
      final EstimateSessionStore store = await open(
        tester,
        bill(items: twoLines),
      );
      expect(
        store.billDraft!.extraChargeLines.map(
          (ExtraChargeDraft l) => '${l.description}=${l.amount}',
        ),
        <String>['Transport=2500', 'Extra silicon=1250.5'],
      );
    });

    testWidgets('a server that does not keep the lines yet loses nothing', (
      WidgetTester tester,
    ) async {
      // It sends back only the total; the lines as typed are kept for Bill
      // Inputs, and the screen shows what the PDF will print.
      final EstimateSessionStore store = await open(tester, bill());
      expect(find.text('Extra Charges'), findsOneWidget);
      expect(
        store.billDraft!.extraChargeLines.map(
          (ExtraChargeDraft l) => '${l.description}=${l.amount}',
        ),
        <String>['Transport=2500', 'Extra silicon=1250.5'],
      );
    });
  });
}

class _FakeBills extends BillingRepository {
  final BillSnapshot snapshot;

  _FakeBills(this.snapshot);

  @override
  Future<BillSnapshot> estimateBill(BillRequest request) async => snapshot;
}
