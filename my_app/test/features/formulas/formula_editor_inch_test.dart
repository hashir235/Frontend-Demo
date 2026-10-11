import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/theme/app_theme.dart';
import 'package:my_app/features/formulas/data/formula_book.dart';
import 'package:my_app/features/formulas/data/formula_catalogue.dart';
import 'package:my_app/features/formulas/model/formula_overrides.dart';
import 'package:my_app/features/formulas/model/formula_window_key.dart';
import 'package:my_app/features/formulas/model/piece_size.dart';
import 'package:my_app/features/formulas/presentation/formula_editor_screen.dart';

/// The formula screen for a window measured in inches: formulas and sizes
/// read, typed and adjusted in inches and suter, and still kept in
/// centimetres (or feet) exactly as before.
void main() {
  Map<String, dynamic> catalogueJson() {
    return <String, dynamic>{
      'version': 1,
      'formulas': <String>[
        '(h + cm) / feet', // 0
        '(w + cm) / feet', // 1
        '(h - 4.2 + cm) / feet', // 2
        '((w - 15.5) / 2 + 8.5 + cm) / feet', // 3
        'h + cm_M23', // 4
        'w / 2 + cm_M24', // 5
      ],
      'windows': <String, dynamic>{
        'fabrication/S_win': <String, dynamic>{
          'variables': <String>['cm', 'feet', 'h', 'w'],
          'configs': <String, dynamic>{
            'collarType=2|lockType=1|rubberType=F': <String, dynamic>{
              'DC30C': <dynamic>[
                <dynamic>['HL', 0],
                <dynamic>['WT', 1],
              ],
              'M23': <dynamic>[
                <dynamic>['H', 2],
              ],
              'M24': <dynamic>[
                <dynamic>['W1', 3],
              ],
            },
          },
        },
        'estimation/S_win': <String, dynamic>{
          'variables': <String>['cm_M23', 'cm_M24', 'h', 'w'],
          'configs': <String, dynamic>{
            'collarType=2': <String, dynamic>{
              'M23': <dynamic>[
                <dynamic>['H', 4],
              ],
              'M24': <dynamic>[
                <dynamic>['W1', 5],
              ],
            },
          },
        },
      },
    };
  }

  final FormulaWindowKey key = FormulaWindowKey.of(
    context: 'fabrication',
    appWindowCode: 'S_win',
    dimensions: <String>{'collarType', 'lockType', 'rubberType'},
    collarIndex: 2,
    lockType: 1,
    rubberType: 'F',
  )!;

  /// 86'' 7''' high and 72'' wide, as the measuring screen hands them over:
  /// in centimetres, exactly.
  const Map<String, double> window = <String, double>{
    'h': 220.6625,
    'w': 182.88,
    'cm': 0.5,
    'feet': 30.48,
  };

  Future<void> pump(
    WidgetTester tester, {
    FormulaOverrides? starting,
    Map<String, double> measurements = window,
    List<PieceSize> pieceSizes = const <PieceSize>[],
    void Function(FormulaOverrides)? onSaved,
    void Function(List<PieceSize>)? onSizes,
    FormulaWindowKey? windowKey,
  }) async {
    tester.view.physicalSize = const Size(1500, 7500);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: FormulaEditorScreen(
          windowKey: windowKey ?? key,
          windowTitle: 'Sliding Window',
          configSummary: 'Collar 2 · Latch',
          book: FormulaBook(
            FormulaCatalogue.fromJson(catalogueJson()),
            starting ?? FormulaOverrides.empty(),
          ),
          measurements: measurements,
          pieceSizes: pieceSizes,
          inchSuter: true,
          onSaved: (FormulaOverrides overrides) async => onSaved?.call(overrides),
          onPieceSizesSaved: (List<PieceSize> sizes) => onSizes?.call(sizes),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  FilledButton saveButton(WidgetTester tester) => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save changes'),
      );

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();
  }

  /// The size box in the first piece's formula -- the first box on the
  /// screen, before any formula is opened as text.
  Finder firstSizeBox() => find.byType(TextField).first;

  testWidgets('formulas and sizes read in inch and suter', (WidgetTester tester) async {
    await pump(tester);

    expect(find.textContaining('In inch and suter'), findsOneWidget);
    expect(find.textContaining('Write in centimetres'), findsNothing);
    // 4.2 cm is not a whole number of half suter, so it is said to be near.
    expect(find.textContaining('marks a number Quick AL keeps in centimetres'), findsOneWidget);

    // The window's size in its own formula, as the measuring screen wrote it.
    expect(find.text("86'' 7'''"), findsWidgets);
    expect(find.text("72''"), findsWidgets);

    // The lengths in the formulas, in inches; the counts left as they are.
    expect(find.text("1'' 5'''"), findsOneWidget);
    expect(find.text("6'' 1'''"), findsOneWidget);
    expect(find.text("3'' 3'''"), findsOneWidget);
    expect(find.text(') / 2 + '), findsOneWidget);
    // Three numbers, and the note at the top that explains the mark.
    expect(find.text('≈'), findsNWidgets(4));

    expect(
      find.textContaining('window height (inches)', findRichText: true),
      findsWidgets,
    );
    expect(find.textContaining('(cm)', findRichText: true), findsNothing);
    expect(find.textContaining('nearest ½ suter', findRichText: true), findsWidgets);

    // H = h - 4.2 cm = 216.4625 cm: 85'' 2''' to the half suter. Inches are
    // read first, because that is what the formula is in.
    expect(find.text("85'' 2'''"), findsOneWidget);
    final Offset inch = tester.getTopLeft(find.text("85'' 2'''"));
    final Offset cm = tester.getTopLeft(find.text('216.5'));
    expect(inch.dy, lessThan(cm.dy));

    expect(saveButton(tester).onPressed, isNull, reason: 'nothing changed yet');
  });

  testWidgets('a size is typed the way the measuring screen takes it', (WidgetTester tester) async {
    List<PieceSize>? sizes;
    await pump(tester, onSizes: (List<PieceSize> s) => sizes = s);

    await tester.enterText(firstSizeBox(), '86 4');
    await tester.pumpAndSettle();
    expect(find.text("86'' 4'''"), findsWidgets);
    // The inch and its suter held together, never split over two lines.
    expect(find.textContaining("The window is 86''\u00A07'''."), findsOneWidget);

    await save(tester);
    expect(sizes, hasLength(1));
    // 86.5 inches, exactly, in centimetres.
    expect(sizes!.single.size, 219.71);
    expect(sizes!.single.base, 220.6625);
  });

  testWidgets('a half suter in a size', (WidgetTester tester) async {
    List<PieceSize>? sizes;
    await pump(tester, onSizes: (List<PieceSize> s) => sizes = s);

    await tester.enterText(firstSizeBox(), '86 4.');
    await tester.pumpAndSettle();
    expect(find.text("86'' 4½'''"), findsWidgets);
    await save(tester);
    expect(sizes!.single.size, closeTo(86.5625 * 2.54, 1e-9));
  });

  testWidgets('a size more than double the window is caught, in inches', (WidgetTester tester) async {
    await pump(tester);
    await tester.enterText(firstSizeBox(), '200');
    await tester.pumpAndSettle();
    expect(
      find.text("200'' is more than double this window (86''\u00A07'''). Check the number."),
      findsOneWidget,
    );
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('a number is set from its own box, half a suter at a time', (WidgetTester tester) async {
    FormulaOverrides? saved;
    await pump(tester, onSaved: (FormulaOverrides o) => saved = o);

    await tester.tap(find.text("1'' 5'''"));
    await tester.pumpAndSettle();

    expect(find.text('Change this number'), findsOneWidget);
    expect(find.textContaining('Quick AL keeps this as 4.2\u00A0cm'), findsOneWidget);
    // The cut size follows the number: 85'' 2''' to start with.
    expect(
      find.descendant(of: find.byKey(const Key('length_sheet_cut')), matching: find.text("85'' 2'''")),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('length_sheet_more')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('length_sheet_formula')),
        matching: find.text("H - 1'' 5½'''"),
      ),
      findsOneWidget,
    );
    expect(find.text("Use 1'' 5½'''"), findsOneWidget);

    await tester.tap(find.byKey(const Key('length_sheet_use')));
    await tester.pumpAndSettle();

    expect(find.text("1'' 5½'''"), findsOneWidget);
    expect(find.text('yours'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNotNull);

    await save(tester);
    // 1'' 5½''' is 1.6875 inches, exactly 4.28625 cm; the rest untouched.
    expect(
      saved!.formulaFor(FormulaPieceRef.of(key, 'M23', 0)),
      '(h - 4.28625 + cm) / feet',
    );
    expect(saved!.count, 1);
  });

  testWidgets('a number taken back to its own mark is exactly as it was', (WidgetTester tester) async {
    await pump(tester);
    await tester.tap(find.text("1'' 5'''"));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('length_sheet_more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('length_sheet_less')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('length_sheet_use')));
    await tester.pumpAndSettle();

    expect(find.text('yours'), findsNothing);
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('the number box takes inch and suter typed', (WidgetTester tester) async {
    FormulaOverrides? saved;
    await pump(tester, onSaved: (FormulaOverrides o) => saved = o);

    await tester.tap(find.text("3'' 3'''"));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('length_sheet_inch')), '3');
    await tester.enterText(find.byKey(const Key('length_sheet_suter')), '4.');
    await tester.pumpAndSettle();
    expect(find.text("Use 3'' 4½'''"), findsOneWidget);
    await tester.tap(find.byKey(const Key('length_sheet_use')));
    await tester.pumpAndSettle();
    expect(find.text("3'' 4½'''"), findsOneWidget);

    await save(tester);
    // 15.5 kept exactly; 3'' 4½''' is 3.5625 inches, 9.04875 cm.
    expect(
      saved!.formulaFor(FormulaPieceRef.of(key, 'M24', 0)),
      '((w - 15.5) / 2 + 9.04875 + cm) / feet',
    );
  });

  testWidgets('Cancel changes nothing', (WidgetTester tester) async {
    await pump(tester);
    await tester.tap(find.text("1'' 5'''"));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('length_sheet_more')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text("1'' 5'''"), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('a formula typed in inches, with the inch keys', (WidgetTester tester) async {
    FormulaOverrides? saved;
    await pump(tester, onSaved: (FormulaOverrides o) => saved = o);

    await tester.tap(find.byTooltip('Change the formula itself').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('inch_key_inch')), findsOneWidget);
    expect(find.byKey(const Key('inch_key_suter')), findsOneWidget);
    expect(find.byKey(const Key('inch_key_half')), findsOneWidget);

    final Finder field = find.byType(TextField).first;
    // A phone's double quote is two marks.
    await tester.enterText(field, 'HL + 1" 2');
    await tester.pumpAndSettle();
    expect(find.text("HL + 1'' 2"), findsOneWidget);
    expect(find.textContaining("After 1'' comes the suter"), findsOneWidget);

    await tester.tap(find.byKey(const Key('inch_key_half')));
    await tester.tap(find.byKey(const Key('inch_key_suter')));
    await tester.pumpAndSettle();
    expect(find.text("HL + 1'' 2½'''"), findsOneWidget);
    expect(find.textContaining('comes the suter'), findsNothing);

    await save(tester);
    // 1'' 2½''' is 1.3125 inches: 3.33375 cm.
    expect(
      saved!.formulaFor(FormulaPieceRef.of(key, 'DC30C', 0)),
      '(h + 3.33375 + cm) / feet',
    );
  });

  testWidgets('a length typed without its marks is refused', (WidgetTester tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Change the formula itself').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'HL + 2');
    await tester.pumpAndSettle();
    expect(find.textContaining("2'' for inches, or 2''' for suter"), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('a workshop formula put back goes back to exactly Quick AL\'s', (WidgetTester tester) async {
    FormulaOverrides? saved;
    final FormulaOverrides starting = FormulaOverrides.empty()
      ..set(FormulaPieceRef.of(key, 'M23', 0), '(h - 4.445 + cm) / feet');
    await pump(tester, starting: starting, onSaved: (FormulaOverrides o) => saved = o);

    // 4.445 cm is exactly 1'' 6''': no ≈ on it.
    expect(find.text("1'' 6'''"), findsOneWidget);
    await tester.tap(find.byTooltip('Put this one back'));
    await tester.pumpAndSettle();
    expect(find.text("1'' 5'''"), findsOneWidget);

    await save(tester);
    expect(
      saved!.formulaFor(FormulaPieceRef.of(key, 'M23', 0)),
      '(h - 4.2 + cm) / feet',
    );
  });

  testWidgets('a size already set opens in inches and keeps its value', (WidgetTester tester) async {
    final PieceSize own = PieceSize(
      ref: FormulaPieceRef.of(key, 'DC30C', 0),
      label: 'HL',
      dimension: 'h',
      base: 220.6625,
      size: 219.71,
    );
    await pump(tester, pieceSizes: <PieceSize>[own]);
    expect(find.text("86'' 4'''"), findsWidgets);
    expect(find.textContaining('Own size, this window only'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('estimation in inches: feet behind it', (WidgetTester tester) async {
    List<PieceSize>? sizes;
    final FormulaWindowKey estimation = FormulaWindowKey.of(
      context: 'estimation',
      appWindowCode: 'S_win',
      dimensions: <String>{'collarType'},
      collarIndex: 2,
    )!;
    await pump(
      tester,
      windowKey: estimation,
      measurements: <String, double>{
        'h': 86.875 / 12,
        'w': 72 / 12,
        'cm_M23': 0,
        'cm_M24': 0,
      },
      onSizes: (List<PieceSize> s) => sizes = s,
    );

    expect(find.text("86'' 7'''"), findsWidgets);
    expect(find.text(' / 2'), findsOneWidget);
    expect(
      find.textContaining('window height (inches)', findRichText: true),
      findsWidgets,
    );

    await tester.enterText(firstSizeBox(), '86 4');
    await tester.pumpAndSettle();
    await save(tester);
    expect(sizes!.single.size, 7.20833333);
  });
}
