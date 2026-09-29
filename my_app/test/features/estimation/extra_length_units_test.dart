import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/data/optimization_repository.dart';
import 'package:my_app/features/estimation/models/cutting_report.dart';
import 'package:my_app/features/estimation/models/section_recalculation.dart';
import 'package:my_app/features/estimation/presentation/input/feet_inch_suter_notation.dart';
import 'package:my_app/features/estimation/presentation/input/size_entry_notation.dart';
import 'package:my_app/features/estimation/presentation/section_recalculation_screen.dart';
import 'package:my_app/features/settings/state/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Re Calculation's extra length, typed in the unit its buttons say: cm with
/// one digit after the point, inch and suter as the size boxes type them, and
/// feet as feet' -> point -> inch'' -> point -> suter''' -> point -> ½.
void main() {
  /// Types [keys] one at a time where the cursor is, the way a keyboard does,
  /// and presses backspace for every `<`.
  TextEditingValue type(TextInputFormatter formatter, String keys, {TextEditingValue? from}) {
    TextEditingValue value = from ?? TextEditingValue.empty;
    for (final String key in keys.split('')) {
      final int caret = value.selection.isValid ? value.selection.end : value.text.length;
      final TextEditingValue next;
      if (key == '<') {
        if (caret == 0) continue;
        next = TextEditingValue(
          text: value.text.substring(0, caret - 1) + value.text.substring(caret),
          selection: TextSelection.collapsed(offset: caret - 1),
        );
      } else {
        next = TextEditingValue(
          text: value.text.substring(0, caret) + key + value.text.substring(caret),
          selection: TextSelection.collapsed(offset: caret + 1),
        );
      }
      value = formatter.formatEditUpdate(value, next);
    }
    return value;
  }

  const FeetInchSuterFormatter feet = FeetInchSuterFormatter();

  group('feet: feet, point, inch, point, suter, point, half', () {
    test('the point moves on, and after the suter gives the half', () {
      expect(type(feet, '10').text, "10'");
      expect(type(feet, '10.').text, "10' ");
      expect(type(feet, '10.7').text, "10' 7''");
      expect(type(feet, '10.7.').text, "10' 7'' ");
      expect(type(feet, '10.7.4').text, "10' 7'' 4'''");
      expect(type(feet, '10.7.4.').text, "10' 7'' 4½'''");
    });

    test('the space is the same key as the point, and so is a comma', () {
      expect(type(feet, '10 7 4 ').text, "10' 7'' 4½'''");
      expect(type(feet, '10,7,4,').text, "10' 7'' 4½'''");
    });

    test('an inch runs 0 to 11 and a suter 0 to 7', () {
      expect(type(feet, '10.11.7').text, "10' 11'' 7'''");
      expect(type(feet, '10.12').text, "10' 1''", reason: 'no 12th inch');
      expect(type(feet, '10.1.8').text, "10' 1'' ", reason: 'no 8th suter');
      expect(type(feet, '10.1.45').text, "10' 1'' 4'''", reason: 'one suter digit');
    });

    test('nothing after the half, no half without a suter', () {
      expect(type(feet, '10.1.4.5.').text, "10' 1'' 4½'''");
      expect(type(feet, '10..').text, "10' ", reason: 'no inch to move on from');
      expect(type(feet, '.').text, '', reason: 'nothing to move on from');
      expect(type(feet, '10.0.0.').text, "10' 0'' ½'''", reason: 'half a suter alone');
    });

    test('letters never reach the box', () {
      expect(type(feet, '1a0-.7x').text, "10' 7''");
    });

    test('backspace takes the last key, and steps over a gap', () {
      final TextEditingValue full = type(feet, '10.7.4');
      expect(type(feet, '<', from: full).text, "10' 7'' ");
      expect(type(feet, '<<', from: full).text, "10' 7''");
      expect(type(feet, '<<<', from: full).text, "10' ");
      expect(type(feet, '<<<<', from: full).text, "10'");

      // The cursor between the space and the 7: backspace must not run the
      // inch into the feet (107').
      final TextEditingValue beforeSeven = full.copyWith(
        selection: const TextSelection.collapsed(offset: 4),
      );
      final TextEditingValue after = type(feet, '<', from: beforeSeven);
      expect(after.text, "10' 7'' 4'''");
    });

    test('in feet', () {
      expect(FeetInchSuterEntry.read("10' 7'' 4½'''").inFeet,
          closeTo(10 + 7 / 12 + 4.5 / 96, 1e-12));
      expect(FeetInchSuterEntry.read("30'").inFeet, 30);
      expect(FeetInchSuterEntry.read('').inFeet, isNull);
    });
  });

  group('the three units, in feet', () {
    test('cm', () {
      expect(extraLengthInFeet('30.48', ExtraLengthUnit.cm), closeTo(1, 1e-12));
      expect(extraLengthInFeet('320.5', ExtraLengthUnit.cm), closeTo(320.5 / 30.48, 1e-12));
    });

    test('inch, typed as the size boxes type', () {
      final String typed = type(const MergedSizeFormatter(), '127.4.').text;
      expect(typed, "127'' 4½'''");
      expect(extraLengthInFeet(typed, ExtraLengthUnit.inch),
          closeTo((127 + 4.5 / 8) / 12, 1e-12));
    });

    test('feet', () {
      expect(extraLengthInFeet("16' 6''", ExtraLengthUnit.feet), closeTo(16.5, 1e-12));
    });

    test('cm takes one digit after the point, and one point', () {
      const TypedSizeFormatter cm = TypedSizeFormatter(TypedSizeUnit.cm);
      expect(type(cm, '320.55').text, '320.5');
      expect(type(cm, '32..0').text, '32.0');
    });
  });

  group('the Re Calculation screen', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      AppSettings.instance.resetForTest();
    });

    const CuttingReportSection section = CuttingReportSection(
      name: 'DC30F',
      summary: null,
      groups: <CuttingReportGroup>[
        CuttingReportGroup(
          stockLenFt: 16,
          stockLenDisplay: '16 ft',
          wastageFt: 1,
          wastageDisplay: '1 ft',
          offcut: false,
          cuts: <CuttingReportCut>[
            CuttingReportCut(
              label: 'W1|WT',
              windowName: 'S_win',
              windowNo: 1,
              dimension: '48x60',
              lengthFt: 5,
              lengthDisplay: "60''",
            ),
          ],
        ),
      ],
      allowedLengthsFt: <double>[16, 18],
      allowedLengthsDisplay: <String>['16 ft', '18 ft'],
    );

    late _FakeRepository repository;

    Future<void> open(
      WidgetTester tester, {
      CuttingReportSection onSection = section,
    }) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      repository = _FakeRepository();
      await tester.pumpWidget(
        MaterialApp(
          // A new key each time: opening the screen again, not rebuilding it.
          home: SectionRecalculationScreen(
            key: UniqueKey(),
            section: onSection,
            requestContext: 'fabrication',
            displayUnit: 'inch_sutter',
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    final Finder field = find.byKey(const Key('extra_length_field'));

    Future<void> pickUnit(WidgetTester tester, String unit) async {
      await tester.ensureVisible(find.byKey(Key('extra_unit_$unit')));
      await tester.tap(find.byKey(Key('extra_unit_$unit')));
      await tester.pumpAndSettle();
    }

    Future<void> optimize(WidgetTester tester) async {
      await tester.tap(find.text('Optimize Section'));
      await tester.pumpAndSettle();
    }

    SegmentedButton<ExtraLengthUnit> unitButtons(WidgetTester tester) =>
        tester.widget<SegmentedButton<ExtraLengthUnit>>(
          find.byKey(const Key('extra_length_unit')),
        );

    testWidgets('three unit buttons, feet chosen to start with', (
      WidgetTester tester,
    ) async {
      await open(tester);
      expect(find.text('cm'), findsOneWidget);
      expect(find.text('inch'), findsOneWidget);
      expect(find.text('feet'), findsOneWidget);
      expect(unitButtons(tester).selected, <ExtraLengthUnit>{ExtraLengthUnit.feet});
    });

    testWidgets('feet, inch and suter go to the optimizer as feet', (
      WidgetTester tester,
    ) async {
      await open(tester);
      await tester.enterText(field, '10 7 4 ');
      await tester.pump();
      expect(find.text("10' 7'' 4½'''"), findsOneWidget);

      await optimize(tester);
      final SectionStockAvailability extra = repository.last!.stockOptions.last;
      expect(extra.lengthFt, closeTo(10 + 7 / 12 + 4.5 / 96, 1e-9));
      expect(extra.quantity, isNull);
      expect(repository.last!.stockOptions.length, 3, reason: 'two listed lengths and the extra');

      // The result names the bar the way it was typed, not as 10.63 ft.
      final Finder result = find.text("Lengths: 10' 7'' 4½'''");
      await tester.scrollUntilVisible(
        result,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(result, findsOneWidget);
    });

    testWidgets('cm: a new unit empties the box, and cm go as feet', (
      WidgetTester tester,
    ) async {
      await open(tester);
      await tester.enterText(field, '12');
      await pickUnit(tester, 'cm');
      expect(unitButtons(tester).selected, <ExtraLengthUnit>{ExtraLengthUnit.cm});
      expect(tester.widget<TextFormField>(field).controller!.text, isEmpty);

      await tester.enterText(field, '320.5');
      await optimize(tester);
      expect(repository.last!.stockOptions.last.lengthFt, closeTo(320.5 / 30.48, 1e-9));
    });

    testWidgets('inch and suter', (WidgetTester tester) async {
      await open(tester);
      await pickUnit(tester, 'inch');
      await tester.enterText(field, '127 4');
      await tester.pump();
      expect(find.text("127'' 4'''"), findsOneWidget);
      await optimize(tester);
      expect(repository.last!.stockOptions.last.lengthFt, closeTo((127 + 4 / 8) / 12, 1e-9));
    });

    testWidgets('a length no bar comes in is stopped, in the unit typed', (
      WidgetTester tester,
    ) async {
      await open(tester);
      await tester.enterText(field, '3');
      await optimize(tester);
      expect(find.text("Use 4' to 30'"), findsOneWidget);
      expect(repository.calls, 0);

      await pickUnit(tester, 'cm');
      await tester.enterText(field, '100');
      await optimize(tester);
      expect(find.text('Use 122 to 914 cm'), findsOneWidget);
      expect(repository.calls, 0);

      // 30 ft exactly, in cm, is not turned away by rounding.
      await tester.enterText(field, '914.4');
      await optimize(tester);
      expect(repository.calls, 1);
    });

    testWidgets('the unit picked is the one the screen opens on next time', (
      WidgetTester tester,
    ) async {
      await open(tester);
      await pickUnit(tester, 'cm');
      await open(tester);
      expect(unitButtons(tester).selected, <ExtraLengthUnit>{ExtraLengthUnit.cm});
      await pickUnit(tester, 'inch');
      await open(tester);
      expect(unitButtons(tester).selected, <ExtraLengthUnit>{ExtraLengthUnit.inch});
      await tester.pump(const Duration(milliseconds: 10));
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('quick_al.recalc_extra_length_unit'), 'inch',
          reason: 'kept on the phone, not only for this run');
    });

    testWidgets('the lengths are listed longest first: 18, 16, 14', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        onSection: const CuttingReportSection(
          name: 'M23',
          summary: null,
          groups: <CuttingReportGroup>[],
          allowedLengthsFt: <double>[14, 16, 18],
          allowedLengthsDisplay: <String>['14 ft', '16 ft', '18 ft'],
        ),
      );
      final double top18 = tester.getTopLeft(find.text('18 ft')).dy;
      final double top16 = tester.getTopLeft(find.text('16 ft')).dy;
      final double top14 = tester.getTopLeft(find.text('14 ft')).dy;
      expect(top18, lessThan(top16));
      expect(top16, lessThan(top14));

      // Each quantity goes with the length beside it.
      final Finder quantities = find.widgetWithText(TextFormField, 'Quantity');
      await tester.enterText(quantities.at(0), '5');
      await tester.enterText(quantities.at(2), '1');
      await optimize(tester);
      final Map<double, int?> sent = <double, int?>{
        for (final SectionStockAvailability option in repository.last!.stockOptions)
          option.lengthFt: option.quantity,
      };
      expect(sent[18], 5);
      expect(sent[16], isNull);
      expect(sent[14], 1);
    });

    testWidgets('a quantity with no length still asks for the length', (
      WidgetTester tester,
    ) async {
      await open(tester);
      final Finder quantities = find.widgetWithText(TextFormField, 'Quantity');
      await tester.enterText(quantities.last, '2');
      await optimize(tester);
      expect(find.text('Add a length first'), findsOneWidget);
      expect(repository.calls, 0);
    });
  });
}

class _FakeRepository extends OptimizationRepository {
  int calls = 0;
  SectionRecalculationRequest? last;

  @override
  Future<CuttingReport> recalculateSection(SectionRecalculationRequest request) async {
    calls++;
    last = request;
    final double extra = request.stockOptions.last.lengthFt;
    return CuttingReport(
      ok: true,
      context: request.context,
      displayUnit: request.displayUnit,
      errors: const <String>[],
      sections: <CuttingReportSection>[
        CuttingReportSection(
          name: request.sectionName,
          summary: null,
          groups: <CuttingReportGroup>[
            CuttingReportGroup(
              stockLenFt: extra,
              stockLenDisplay: '',
              wastageFt: 0,
              wastageDisplay: '0',
              offcut: false,
              cuts: request.sourceCuts,
            ),
          ],
          allowedLengthsFt: const <double>[],
          allowedLengthsDisplay: const <String>[],
        ),
      ],
    );
  }
}
