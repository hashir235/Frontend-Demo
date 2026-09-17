import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/estimation/state/last_glass_color.dart';
import 'package:my_app/features/fabrication/models/glass_report.dart';
import 'package:my_app/features/fabrication/models/glass_sheet_optimization.dart';
import 'package:my_app/features/fabrication/presentation/glass_row_editor_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Typing a run of glass, and reading what the sheets used.
void main() {
  group('glass area', () {
    test('is given in square feet as well as square inches', () {
      // Cut by the inch, bought by the foot.
      expect(formatArea(1440), '1440 sq in  ·  10 sq ft');
      expect(formatAreaLines(216), '216 sq in\n1.5 sq ft');
      expect(formatSqFt(100), '0.69');
    });
  });

  group('the glass entry sheet', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      LastGlassColor.instance.resetForTest();
    });

    tearDown(LastGlassColor.instance.resetForTest);

    /// A 360-wide phone: the narrow end of what shops actually carry, and
    /// where a title and a badge sharing a line would overflow first.
    Future<void> openSheet(
      WidgetTester tester, {
      ValueChanged<GlassReportRow>? onRowSaved,
    }) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassRowEditorSheet(
              suggestedWindowNo: 1,
              suggestedGlassColor: LastGlassColor.instance.value,
              onRowSaved: onRowSaved ?? (_) {},
            ),
          ),
        ),
      );
    }

    testWidgets('puts width and height side by side, width first', (
      WidgetTester tester,
    ) async {
      await openSheet(tester);
      final Rect width = tester.getRect(
        find.byKey(const Key('glass_width_field')),
      );
      final Rect height = tester.getRect(
        find.byKey(const Key('glass_height_field')),
      );
      expect(width.top, height.top, reason: 'on one line');
      expect(width.right, lessThan(height.left), reason: 'width on the left');
    });

    testWidgets('has no description under the title', (
      WidgetTester tester,
    ) async {
      await openSheet(tester);
      expect(find.textContaining('Glass size is required'), findsNothing);
      expect(find.textContaining('are optional'), findsNothing);
    });

    testWidgets('counts the glass added at the top, beside the title', (
      WidgetTester tester,
    ) async {
      final List<GlassReportRow> saved = <GlassReportRow>[];
      await openSheet(tester, onRowSaved: saved.add);
      expect(find.byKey(const Key('glass_added_count')), findsNothing);

      Future<void> addPiece() async {
        await tester.enterText(
          find.descendant(
            of: find.byKey(const Key('glass_width_field')),
            matching: find.byType(TextField),
          ),
          '22 4',
        );
        await tester.enterText(
          find.descendant(
            of: find.byKey(const Key('glass_height_field')),
            matching: find.byType(TextField),
          ),
          '55 2',
        );
        await tester.ensureVisible(find.text('Save & Next'));
        await tester.tap(find.text('Save & Next'));
        await tester.pumpAndSettle();
      }

      await addPiece();
      await addPiece();

      expect(saved, hasLength(2));
      expect(saved.first.widthDisplay, "22'' 4'''");
      expect(saved.first.heightDisplay, "55'' 2'''");
      expect(
        saved.map((GlassReportRow r) => r.windowNo),
        <int>[1, 2],
        reason: 'the window number steps on with each piece',
      );
      expect(saved.last.quantity, 1);
      expect(find.text('2 added'), findsOneWidget);

      final Rect badge = tester.getRect(
        find.byKey(const Key('glass_added_count')),
      );
      final Rect title = tester.getRect(find.text('Add Glass Row'));
      final Rect sizes = tester.getRect(
        find.byKey(const Key('glass_width_field')),
      );
      expect(
        (badge.center.dy - title.center.dy).abs(),
        lessThan(4),
        reason: 'on the title line',
      );
      expect(badge.bottom, lessThan(sizes.top), reason: 'above the sizes');
      expect(tester.takeException(), isNull, reason: 'no overflow at 360 wide');
    });

    testWidgets('the glass picked is the one every later row opens on', (
      WidgetTester tester,
    ) async {
      final List<GlassReportRow> saved = <GlassReportRow>[];
      await openSheet(tester, onRowSaved: saved.add);

      await tester.ensureVisible(find.byKey(const Key('glass_color_button')));
      await tester.tap(find.byKey(const Key('glass_color_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Green Mer.').last);
      await tester.pumpAndSettle();

      expect(LastGlassColor.instance.value, 'Green Mercury');
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('quick_al.last_glass_color'), 'Green Mercury');

      // A fresh sheet, as the next job would open it.
      await tester.pumpWidget(const SizedBox.shrink());
      await openSheet(tester, onRowSaved: saved.add);
      expect(find.text('Green Mer.'), findsOneWidget);
    });
  });
}
