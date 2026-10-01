import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_app/features/estimation/data/billing_repository.dart';
import 'package:my_app/features/estimation/models/bill_request.dart';
import 'package:my_app/features/estimation/models/bill_snapshot.dart';
import 'package:my_app/features/estimation/presentation/actual_bill_screen.dart';
import 'package:my_app/features/estimation/state/estimate_session_store.dart';
import 'package:my_app/features/estimation/state/invoice_print_choices.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Final Bill: every figure that prints on the PDF is a switch. Tapped off,
/// it dims, stays off for the next bills, and the PDF is asked for without it.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    InvoicePrintChoices.instance.resetForTest();
  });

  InvoicePrintChoices choices() => InvoicePrintChoices.instance;

  /// Lets the background write to the phone finish.
  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 10));

  /// What the app reads when it opens again.
  Future<void> reopen() async {
    choices().resetForTest();
    await choices().load();
  }

  group('the choice', () {
    test('everything prints until the shop switches something off', () {
      for (final String figure in InvoiceFigure.all) {
        expect(choices().prints(figure), isTrue, reason: figure);
      }
      expect(choices().hidden, isEmpty);
    });

    test('a figure switched off stays off after the app is closed', () async {
      await choices().toggle(InvoiceFigure.totalLaborCost);
      await choices().toggle(InvoiceFigure.windowHardwareRate);
      await settle();
      await reopen();
      expect(choices().prints(InvoiceFigure.totalLaborCost), isFalse);
      expect(choices().prints(InvoiceFigure.windowHardwareRate), isFalse);
      expect(choices().prints(InvoiceFigure.grandTotal), isTrue);
      expect(choices().hidden, <String>[
        InvoiceFigure.totalLaborCost,
        InvoiceFigure.windowHardwareRate,
      ]);
    });

    test('tapped again, it prints again -- and that is kept too', () async {
      await choices().toggle(InvoiceFigure.grandTotal);
      await choices().toggle(InvoiceFigure.grandTotal);
      await settle();
      await reopen();
      expect(choices().prints(InvoiceFigure.grandTotal), isTrue);
    });

    test('Print all puts every figure back', () async {
      await choices().toggle(InvoiceFigure.totalGlassCost);
      await choices().toggle(InvoiceFigure.glassRate);
      await choices().printAll();
      await settle();
      await reopen();
      expect(choices().hidden, isEmpty);
    });

    test('a name it does not know is never kept or sent', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'quick_al.invoice_hidden_figures': <String>[
          'totals.laborCost',
          'customer.phone',
          '',
        ],
      });
      await reopen();
      expect(choices().hidden, <String>['totals.laborCost']);
      await choices().toggle('customer.name');
      expect(choices().hidden, <String>['totals.laborCost']);
    });
  });

  group('the Final Bill screen', () {
    Map<String, dynamic> bill({double advance = 50000, double extra = 23000}) {
      return <String, dynamic>{
        'ok': true,
        'gauge': '1.2mm',
        'aluminiumColor': 'Champagne',
        'glassColor': 'Clear 5mm',
        'customer': <String, dynamic>{'name': 'Ahmed'},
        'project': <String, dynamic>{'name': 'House 12', 'location': 'Lahore'},
        'company': <String, dynamic>{'workshopName': 'Test Workshop'},
        'rates': <String, dynamic>{
          'glassPerSqFt': 180,
          'laborPerSqFt': 120,
          'hardwarePerWindow': 1500,
          'aluminiumDiscountPercent': 19,
        },
        'totals': <String, dynamic>{
          'totalWindows': 8,
          'totalArea': 103.41,
          'glassCost': 19950.2,
          'laborCost': 12436.2,
          'hardwareCost': 10200,
          'aluminiumOriginal': 126076,
          'aluminiumDiscount': 23954.4,
          'aluminiumAfterDiscount': 102122,
          'extraCharges': extra,
          'advancePaid': advance,
          'grandTotal': 167708,
          'remainingDue': 167708 - advance,
        },
        'windowSummary': <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'Sliding Window 3 Panel With Mesh And Grill',
            'quantity': 6,
            'areaSqFt': 82.91,
            'hardwareRate': 1500,
            'hardwareCost': 9000,
          },
          <String, dynamic>{
            'type': 'Fix Window',
            'quantity': 2,
            'areaSqFt': 20.5,
            'hardwareRate': 600,
            'hardwareCost': 1200,
          },
        ],
        'glassSummary': <Map<String, dynamic>>[
          <String, dynamic>{
            'color': 'Clear 5mm',
            'areaSqFt': 70,
            'rate': 180,
            'cost': 12600,
          },
          <String, dynamic>{
            'color': 'Black Reflective 8mm',
            'areaSqFt': 1033.41,
            'rate': 220,
            'cost': 1227350.2,
          },
        ],
      };
    }

    const BillRequest request = BillRequest(
      projectId: 'p-1',
      glassRatePerSqFt: 180,
      laborRatePerSqFt: 120,
      hardwareRatePerWindow: 1500,
      aluminiumDiscountPercent: 19,
      aluminiumTotal: 126076,
      extraCharges: 23000,
      advancePaid: 50000,
      gauge: '1.2mm',
      aluminiumColor: 'Champagne',
      glassColor: 'Clear 5mm',
      projectName: 'House 12',
      projectLocation: 'Lahore',
      customerName: 'Ahmed',
      customerPhone: '',
      customerAddress: '',
    );

    /// A small phone's width, so nothing may run out of room across; tall
    /// enough that every card of the bill is built at once.
    Future<void> open(WidgetTester tester, Map<String, dynamic> json) async {
      tester.view.physicalSize = const Size(360 * 3, 6000 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: ActualBillScreen(
            session: EstimateSessionStore(
              projectName: 'House 12',
              projectLocation: 'Lahore',
            ),
            request: request,
            repository: _FakeBills(BillSnapshot.fromJson(json)),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// The printer mark in the line or card that reads [label].
    Finder markIn(String label, {bool prints = true}) {
      return find.descendant(
        of: find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first,
        matching: find.byIcon(
          prints ? Icons.print_rounded : Icons.print_disabled_outlined,
        ),
      );
    }

    Future<void> tapLine(WidgetTester tester, String label) async {
      final Finder line = find.text(label).first;
      await tester.ensureVisible(line);
      await tester.pumpAndSettle();
      await tester.tap(line);
      await tester.pumpAndSettle();
    }

    testWidgets('lays out on a small phone with every figure printing', (
      WidgetTester tester,
    ) async {
      await open(tester, bill());
      expect(tester.takeException(), isNull);
      expect(find.text('Hardware by Window'), findsOneWidget);
      expect(find.text('Glass by Color'), findsOneWidget);
      expect(find.byIcon(Icons.print_disabled_outlined), findsNothing);
      // The hint's own icon, then one mark per switch: 4 metric cards, 3
      // Project Summary lines, 10 Cost Breakdown lines, 2 + 3 + 2 headings.
      expect(find.byIcon(Icons.print_rounded), findsNWidgets(1 + 4 + 3 + 10 + 7));
    });

    testWidgets('one window type still has its hardware switches', (
      WidgetTester tester,
    ) async {
      final Map<String, dynamic> json = bill();
      json['windowSummary'] = (json['windowSummary'] as List<dynamic>).sublist(1);
      json['glassSummary'] = <Map<String, dynamic>>[
        <String, dynamic>{'color': '', 'areaSqFt': 20.5, 'rate': 0, 'cost': 0},
      ];
      await open(tester, json);
      expect(find.text('Hardware by Window'), findsOneWidget);
      expect(find.text('H/W Rate'), findsOneWidget);
      // Unnamed glass: the PDF has no glass table, so neither does this.
      expect(find.text('Glass by Color'), findsNothing);
    });

    testWidgets('a tapped line dims, leaves the PDF, and the bill says so', (
      WidgetTester tester,
    ) async {
      await open(tester, bill());
      await tapLine(tester, 'Labor Cost');
      expect(choices().prints(InvoiceFigure.totalLaborCost), isFalse);
      expect(markIn('Labor Cost', prints: false), findsOneWidget);
      expect(find.text('1 figure is off the PDF'), findsOneWidget);

      await tapLine(tester, 'Labor Cost');
      expect(choices().prints(InvoiceFigure.totalLaborCost), isTrue);
      expect(markIn('Labor Cost'), findsOneWidget);
      expect(find.text('1 figure is off the PDF'), findsNothing);
    });

    testWidgets('the same figure shown twice is one switch', (
      WidgetTester tester,
    ) async {
      await open(tester, bill());
      // Before Discount is a card at the top and a line in two cards.
      await tapLine(tester, 'Before Discount');
      expect(choices().prints(InvoiceFigure.aluminiumOriginal), isFalse);
      expect(find.byIcon(Icons.print_disabled_outlined), findsNWidgets(3));
    });

    testWidgets('a table heading switches its whole column', (
      WidgetTester tester,
    ) async {
      await open(tester, bill());
      await tapLine(tester, 'H/W Rate');
      expect(choices().prints(InvoiceFigure.windowHardwareRate), isFalse);
      await tapLine(tester, 'Qty');
      expect(choices().prints(InvoiceFigure.windowQuantity), isFalse);
      // A figure under a heading switches the same column back (600: the
      // Fix Window's hardware rate; 1500 is also in Rates Used).
      await tapLine(tester, '600');
      expect(choices().prints(InvoiceFigure.windowHardwareRate), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('only figures the PDF prints are switches', (
      WidgetTester tester,
    ) async {
      // No advance and no extra charges: the PDF prints neither line, nor
      // Remaining Due.
      await open(tester, bill(advance: 0, extra: 0));
      for (final String label in <String>[
        'Extra Charges',
        'Advance Paid',
        'Remaining Due',
        'Labor Rate / sq.ft',
        'Total Quantity',
      ]) {
        final Finder line = find.text(label).first;
        await tester.ensureVisible(line);
        await tester.tap(line, warnIfMissed: false);
        await tester.pumpAndSettle();
      }
      expect(choices().hidden, isEmpty);
    });

    testWidgets('Print all puts every figure back on', (
      WidgetTester tester,
    ) async {
      await open(tester, bill());
      await tapLine(tester, 'Glass Cost');
      await tapLine(tester, 'Grand Total');
      expect(find.text('2 figures are off the PDF'), findsOneWidget);
      await tester.ensureVisible(find.text('Print all'));
      await tester.tap(find.text('Print all'));
      await tester.pumpAndSettle();
      expect(choices().hidden, isEmpty);
      expect(find.byIcon(Icons.print_disabled_outlined), findsNothing);
    });

    testWidgets('the PDF is asked for without the figures switched off', (
      WidgetTester tester,
    ) async {
      await open(tester, bill());
      await tapLine(tester, 'Labor Cost');
      await tapLine(tester, 'H/W Rate');

      final List<Map<String, dynamic>> sent = <Map<String, dynamic>>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('quick_al/downloads'),
        (MethodCall call) async => null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('quick_al/downloads'),
          null,
        ),
      );
      final MockClient server = MockClient((http.Request request) async {
        sent.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(
          jsonEncode(<String, String>{
            'fileName': 'Invoice_1.pdf',
            'downloadUrl': '/downloads/Invoice_1.pdf',
          }),
          200,
        );
      });

      await http.runWithClient(() async {
        await tester.tap(find.text('Download PDF'));
        await tester.pump();
      }, () => server);
      await tester.pumpAndSettle();

      expect(sent, hasLength(1));
      expect(sent.single['projectId'], 'p-1');
      expect(sent.single['hiddenFigures'], <String>[
        InvoiceFigure.totalLaborCost,
        InvoiceFigure.windowHardwareRate,
      ]);
    });
  });
}

class _FakeBills extends BillingRepository {
  final BillSnapshot snapshot;

  _FakeBills(this.snapshot);

  @override
  Future<BillSnapshot> estimateBill(BillRequest request) async => snapshot;
}
