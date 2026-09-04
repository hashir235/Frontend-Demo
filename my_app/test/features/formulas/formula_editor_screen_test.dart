import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/theme/app_theme.dart';
import 'package:my_app/features/formulas/data/formula_book.dart';
import 'package:my_app/features/formulas/data/formula_catalogue.dart';
import 'package:my_app/features/formulas/data/formula_overrides_store.dart';
import 'package:my_app/features/formulas/model/formula_window_key.dart';
import 'package:my_app/features/formulas/presentation/formula_editor_screen.dart';

/// The formula screen is where a workshop's own arithmetic gets set, and the
/// only thing standing between a typo and a wrongly cut bar. These check what
/// it shows, what it refuses, and that nothing is saved that should not be.
void main() {
  /// A small catalogue shaped exactly like the shipped one: two collar types
  /// of one window, sharing the same formula for DC30C HL so the "everywhere
  /// it matches" path has something to match.
  Map<String, dynamic> catalogueJson() {
    return <String, dynamic>{
      'version': 1,
      'formulas': <String>[
        '(h + cm) / feet', // 0
        '(w + cm) / feet', // 1
        '(h - 4.2 + cm) / feet', // 2
      ],
      'windows': <String, dynamic>{
        'fabrication/S_win': <String, dynamic>{
          'variables': <String>['cm', 'feet', 'h', 'w'],
          'configs': <String, dynamic>{
            'collarType=2|lockType=1|rubberType=F': <String, dynamic>{
              'DC30C': <dynamic>[
                <dynamic>['HL', 0],
                <dynamic>['HR', 0],
                <dynamic>['WT', 1],
              ],
              'M23': <dynamic>[
                <dynamic>['H', 2],
                <dynamic>['H', 2],
              ],
            },
            'collarType=13|lockType=1|rubberType=F': <String, dynamic>{
              'DC30C': <dynamic>[
                <dynamic>['HL', 0],
                <dynamic>['HR', 0],
                <dynamic>['WT', 1],
              ],
            },
          },
        },
      },
    };
  }

  FormulaWindowKey keyForCollar(int collar) {
    return FormulaWindowKey.of(
      context: 'fabrication',
      appWindowCode: 'S_win',
      dimensions: <String>{'collarType', 'lockType', 'rubberType'},
      collarIndex: collar,
      lockType: 1,
      rubberType: 'F',
    )!;
  }

  Future<FormulaOverrides?> pump(
    WidgetTester tester, {
    FormulaOverrides? starting,
    Map<String, double> measurements = const <String, double>{},
  }) async {
    FormulaOverrides? saved;
    final FormulaCatalogue catalogue = FormulaCatalogue.fromJson(catalogueJson());
    final FormulaBook book = FormulaBook(catalogue, starting ?? FormulaOverrides.empty());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: FormulaEditorScreen(
          windowKey: keyForCollar(2),
          windowTitle: 'Sliding Window',
          configSummary: 'Collar 2 · Latch',
          book: book,
          measurements: measurements,
          onSaved: (FormulaOverrides overrides) async {
            saved = overrides;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return saved;
  }

  testWidgets('shows every piece, in the fabricator\'s own names', (WidgetTester tester) async {
    await pump(tester);

    // The first profile and its pieces.
    expect(find.text('DC30C'), findsOneWidget);
    expect(find.text('HL'), findsOneWidget);
    expect(find.text('WT'), findsOneWidget);

    // The formulas, with h and w replaced by the piece's own label.
    expect(find.text('(HL + cm) / feet'), findsOneWidget);
    expect(find.text('(WT + cm) / feet'), findsOneWidget);

    // M23 is below the fold on a test-sized screen, as it would be on a
    // phone: a real window runs to six profiles and twenty pieces.
    // Named explicitly: every text field brings a scrollable of its own, so
    // "the scrollable" is ambiguous on this screen.
    await tester.scrollUntilVisible(
      find.text('M23'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('M23'), findsOneWidget);

    // Its two uprights share the label H, so they are numbered rather than
    // left looking like the same box drawn twice.
    expect(find.text('1 of 2'), findsOneWidget);
    expect(find.text('2 of 2'), findsOneWidget);
  });

  testWidgets('says what each name in a formula means', (WidgetTester tester) async {
    await pump(tester);
    // The legend is drawn as rich text, so the name and its meaning can carry
    // different weights on one line.
    expect(
      find.textContaining('window height (cm)', findRichText: true),
      findsWidgets,
    );
    expect(find.textContaining('cutting margin', findRichText: true), findsWidgets);
  });

  testWidgets('shows what a formula comes to for the window on the bench',
      (WidgetTester tester) async {
    await pump(tester, measurements: <String, double>{
      'h': 220.6,
      'w': 182.5,
      'cm': 0.5,
      'feet': 30.48,
    });
    // (220.6 + 0.5) / 30.48 = 7.2539... for both uprights, which are cut by
    // the same sum and so come to the same length.
    expect(find.textContaining('7.254 ft for this window'), findsNWidgets(2));
    // The head rail is driven by the width instead: (182.5 + 0.5) / 30.48.
    expect(find.textContaining('6.004 ft for this window'), findsOneWidget);
  });

  testWidgets('refuses a formula it cannot read, and will not save',
      (WidgetTester tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField).first, '(HL + cm / feet');
    await tester.pumpAndSettle();

    expect(find.textContaining('never closed'), findsOneWidget);
    expect(find.text('One formula cannot be used yet.'), findsOneWidget);

    final FilledButton save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save formulas'),
    );
    expect(save.onPressed, isNull, reason: 'a broken formula must not be savable');
  });

  testWidgets('refuses a measurement this piece does not have', (WidgetTester tester) async {
    await pump(tester);

    // HL is driven by the height; the width is not one of its names.
    await tester.enterText(find.byType(TextField).first, '(w + cm) / feet');
    await tester.pumpAndSettle();

    expect(find.textContaining('not a measurement this window has'), findsOneWidget);
  });

  testWidgets('a good edit can be saved, and asks how far it should reach',
      (WidgetTester tester) async {
    FormulaOverrides? saved;
    final FormulaCatalogue catalogue = FormulaCatalogue.fromJson(catalogueJson());
    final FormulaBook book = FormulaBook(catalogue, FormulaOverrides.empty());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: FormulaEditorScreen(
          windowKey: keyForCollar(2),
          windowTitle: 'Sliding Window',
          configSummary: 'Collar 2 · Latch',
          book: book,
          onSaved: (FormulaOverrides overrides) async {
            saved = overrides;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '(HL + 12 + cm) / feet');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Save formulas'));
    await tester.pumpAndSettle();

    // DC30C HL is cut the same way in both collar types, so the question is
    // asked rather than assumed.
    expect(find.text('Where should this apply?'), findsOneWidget);
    expect(find.textContaining('2 configurations'), findsWidgets);

    await tester.tap(find.text('Only Collar 2 · Latch'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.count, 1, reason: 'only the open configuration was chosen');
    final String? stored = saved!.formulaFor(
      FormulaPieceRef.of(keyForCollar(2), 'DC30C', 0),
    );
    expect(stored, '(h + 12 + cm) / feet');
  });

  testWidgets('applying everywhere changes every matching configuration',
      (WidgetTester tester) async {
    FormulaOverrides? saved;
    final FormulaCatalogue catalogue = FormulaCatalogue.fromJson(catalogueJson());
    final FormulaBook book = FormulaBook(catalogue, FormulaOverrides.empty());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: FormulaEditorScreen(
          windowKey: keyForCollar(2),
          windowTitle: 'Sliding Window',
          configSummary: 'Collar 2 · Latch',
          book: book,
          onSaved: (FormulaOverrides overrides) async {
            saved = overrides;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '(HL + 12 + cm) / feet');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save formulas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Everywhere it matches'));
    await tester.pumpAndSettle();

    expect(saved!.count, 2);
    expect(
      saved!.formulaFor(FormulaPieceRef.of(keyForCollar(13), 'DC30C', 0)),
      '(h + 12 + cm) / feet',
    );
  });

  testWidgets('a workshop\'s own formula is marked, and can be put back',
      (WidgetTester tester) async {
    final FormulaOverrides starting = FormulaOverrides.empty()
      ..set(FormulaPieceRef.of(keyForCollar(2), 'DC30C', 0), '(h + 99 + cm) / feet');

    await pump(tester, starting: starting);

    expect(find.text('(HL + 99 + cm) / feet'), findsOneWidget);
    expect(find.text('yours'), findsOneWidget);

    await tester.tap(find.byTooltip('Put this one back'));
    await tester.pumpAndSettle();

    expect(find.text('(HL + cm) / feet'), findsOneWidget);
    expect(find.text('(HL + 99 + cm) / feet'), findsNothing);
  });

  testWidgets('nothing is saved unless something changed', (WidgetTester tester) async {
    await pump(tester);
    final FilledButton save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save formulas'),
    );
    expect(save.onPressed, isNull);
  });
}
