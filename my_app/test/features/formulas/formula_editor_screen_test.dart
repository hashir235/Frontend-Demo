import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/theme/app_theme.dart';
import 'package:my_app/features/formulas/data/formula_book.dart';
import 'package:my_app/features/formulas/data/formula_catalogue.dart';
import 'package:my_app/features/formulas/model/formula_overrides.dart';
import 'package:my_app/features/formulas/model/formula_window_key.dart';
import 'package:my_app/features/formulas/model/piece_size.dart';
import 'package:my_app/features/formulas/presentation/formula_editor_screen.dart';
import 'package:my_app/features/help_videos/help_video_button.dart';

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

  /// Puts the first piece into formula-editing mode.
  ///
  /// The box shows the window's size by default and edits that; changing the
  /// formula itself is a separate, deliberate act, so a test that means to
  /// change a formula has to say so the same way a fabricator does.
  Future<void> editFirstFormula(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Change the formula itself').first);
    await tester.pumpAndSettle();
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

    // The first profile.
    expect(find.text('DC30C'), findsOneWidget);

    // With nothing measured, each formula still reads -- the piece's own name
    // stands where its measurement will go. The shipped sum for these is
    // "(h + cm) / feet", of which "HL" is the part anybody chose: no margin
    // and no feet anywhere on the screen.
    expect(find.textContaining('cm)'), findsNothing);
    expect(find.textContaining('feet'), findsNothing);

    // The labels appear twice over: once naming the piece, once standing in
    // its formula.
    expect(find.text('HL'), findsNWidgets(2));
    expect(find.text('WT'), findsNWidgets(2));

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
  });

  testWidgets('says which unit to write in, and what it adds behind the formula',
      (WidgetTester tester) async {
    await pump(tester);
    // Both belong at the top, once. Without the first a workshop measuring in
    // inches would think the numbers were wrong; without the second, one that
    // knows its blade takes 2mm would wonder where that went.
    expect(find.textContaining('Write in centimetres'), findsOneWidget);
    expect(find.textContaining('converts it before the formula runs'), findsOneWidget);
    expect(find.textContaining('added to every piece for the saw'), findsOneWidget);
    // The half that stops a formula being set wrong: the sizes shown are the
    // real cut sizes, so nobody "corrects" for an allowance that is not there.
    expect(find.textContaining('the real cut sizes, without it'), findsOneWidget);
  });

  testWidgets('shows the size that will actually be cut, in all three units',
      (WidgetTester tester) async {
    await pump(tester, measurements: <String, double>{
      'h': 220.6,
      'w': 182.5,
      'cm': 0.5,
      'feet': 30.48,
    });

    // The shipped sum is (h + cm) / feet. With the saw's 0.5cm allowance taken
    // back off, the size cut is the window height itself -- 220.6, not 221.1.
    // A fabricator adjusting this formula is reading the first.
    //
    // It shows up twice per upright: once inside the formula, standing where
    // the measurement goes, and once underneath as the size that gets cut.
    expect(find.text('220.6'), findsNWidgets(4));
    expect(find.text('221.1'), findsNothing);

    // The head rail is driven by the width instead.
    expect(find.text('182.5'), findsNWidgets(2));

    // Three readings, each on its own line, so a workshop working in suter can
    // see what a centimetre off the formula does to the cut. Feet and inches
    // are two different readings of the same bar: 7 feet 2 inches, or 86
    // inches -- never the first read out to somebody who works in the second.
    expect(find.text('cm'), findsWidgets);
    expect(find.text('ft'), findsWidgets);
    expect(find.text('in'), findsWidgets);
    expect(find.text("7' 2'' 7'''"), findsNWidgets(2));
    expect(find.text("86'' 7'''"), findsNWidgets(2));
  });

  testWidgets('offers the how-it-works video', (WidgetTester tester) async {
    await pump(tester);
    // Sits before the reset, because it is what somebody opening this screen
    // for the first time is looking for and the button beside it undoes
    // everything they have done.
    expect(find.byType(HelpVideoButton), findsOneWidget);
  });

  testWidgets('offers the help video, before the button that undoes everything',
      (WidgetTester tester) async {
    await pump(tester);

    final Finder video = find.byKey(const Key('help_video_settings.formulas'));
    final Finder resetAll = find.byTooltip('Put everything back');
    expect(video, findsOneWidget);
    expect(resetAll, findsOneWidget);

    // Order matters here. This screen is the one place a fabricator meets the
    // arithmetic behind their own cuts, so the video is what they reach for
    // first -- and the thing beside it throws away every change they have made.
    expect(
      tester.getCenter(video).dx,
      lessThan(tester.getCenter(resetAll).dx),
      reason: 'the video should sit before the reset, not after it',
    );
  });

  testWidgets('refuses a formula it cannot read, and will not save',
      (WidgetTester tester) async {
    await pump(tester);

    await editFirstFormula(tester);
    await tester.enterText(find.byType(TextField).first, '(HL + 6');
    await tester.pumpAndSettle();

    expect(find.textContaining('never closed'), findsOneWidget);
    expect(find.text('One formula or size cannot be used yet.'), findsOneWidget);

    final FilledButton save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save changes'),
    );
    expect(save.onPressed, isNull, reason: 'a broken formula must not be savable');
  });

  testWidgets('refuses a measurement this piece does not have', (WidgetTester tester) async {
    await pump(tester);

    // HL is driven by the height; the width is not one of its names.
    await editFirstFormula(tester);
    await tester.enterText(find.byType(TextField).first, 'w + 6');
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

    await editFirstFormula(tester);
    await tester.enterText(find.byType(TextField).first, 'HL + 12');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
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

    await editFirstFormula(tester);
    await tester.enterText(find.byType(TextField).first, 'HL + 12');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
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

    await pump(tester, starting: starting, measurements: <String, double>{
      'h': 220.6,
      'w': 182.5,
      'cm': 0.5,
      'feet': 30.48,
    });

    // The measurement stands inside the formula, so what is left of it beside
    // the box is the workshop's own arithmetic: " + 99".
    expect(find.text(' + 99'), findsOneWidget);
    expect(find.text('yours'), findsOneWidget);
    // 220.6 + 99 = 319.6, and the margin is off the cut size.
    expect(find.text('319.6'), findsOneWidget);

    await tester.tap(find.byTooltip('Put this one back'));
    await tester.pumpAndSettle();

    expect(find.text(' + 99'), findsNothing);
    expect(find.text('319.6'), findsNothing);
    expect(find.text('220.6'), findsWidgets);
  });

  group('a size of a piece\'s own', () {
    const Map<String, double> window = <String, double>{
      'h': 220.6,
      'w': 182.5,
      'cm': 0.5,
      'feet': 30.48,
    };

    /// The screen on a measured window, for the checks that only look at it.
    Future<void> pumpSizes(
      WidgetTester tester, {
      List<PieceSize> starting = const <PieceSize>[],
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: FormulaEditorScreen(
            windowKey: keyForCollar(2),
            windowTitle: 'Sliding Window',
            configSummary: 'Collar 2 · Latch',
            book: FormulaBook(
              FormulaCatalogue.fromJson(catalogueJson()),
              FormulaOverrides.empty(),
            ),
            measurements: window,
            pieceSizes: starting,
            onSaved: (FormulaOverrides overrides) async {},
            onPieceSizesSaved: (List<PieceSize> saved) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    FilledButton saveButton(WidgetTester tester) => tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Save changes'),
        );

    PieceSize hlAt(double size) => PieceSize(
          ref: FormulaPieceRef.of(keyForCollar(2), 'DC30C', 0),
          label: 'HL',
          dimension: 'h',
          base: 220.6,
          size: size,
        );

    testWidgets('changes that piece and no other, and is kept for this window',
        (WidgetTester tester) async {
      List<PieceSize>? sizes;
      FormulaOverrides? formulas;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: FormulaEditorScreen(
            windowKey: keyForCollar(2),
            windowTitle: 'Sliding Window',
            configSummary: 'Collar 2 · Latch',
            book: FormulaBook(
              FormulaCatalogue.fromJson(catalogueJson()),
              FormulaOverrides.empty(),
            ),
            measurements: window,
            onSaved: (FormulaOverrides overrides) async => formulas = overrides,
            onPieceSizesSaved: (List<PieceSize> saved) => sizes = saved,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both uprights start at the window's height.
      expect(find.text('220.6'), findsNWidgets(4));

      await tester.enterText(find.byType(TextField).first, '210');
      await tester.pumpAndSettle();

      // Said on the piece, with the window's own size beside it.
      expect(find.textContaining('Own size, this window only'), findsOneWidget);
      expect(find.textContaining('The window is 220.6 cm'), findsOneWidget);
      // The other upright is untouched: its own box and its own cut size.
      expect(find.text('220.6'), findsWidgets);

      expect(saveButton(tester).onPressed, isNotNull,
          reason: 'a size is a change worth keeping now');
      await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
      await tester.pumpAndSettle();

      // No formula changed, so nothing was asked about how far to reach and
      // nothing was written to the formulas.
      expect(find.text('Where should this apply?'), findsNothing);
      expect(formulas, isNull);
      expect(sizes, <PieceSize>[hlAt(210)]);
    });

    testWidgets('a size of 0 is refused', (WidgetTester tester) async {
      await pumpSizes(tester);
      await tester.enterText(find.byType(TextField).first, '0');
      await tester.pumpAndSettle();

      expect(find.text('A size has to be more than 0.'), findsOneWidget);
      expect(find.text('One formula or size cannot be used yet.'), findsOneWidget);
      expect(saveButton(tester).onPressed, isNull);
    });

    testWidgets('a size smaller than the formula takes off is refused',
        (WidgetTester tester) async {
      await pumpSizes(tester);
      // M23 H is h - 4.2: at 3cm the piece would come out below nothing. The
      // list builds lazily, so its box only exists once scrolled to.
      await tester.scrollUntilVisible(
        find.text('1 of 2'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      final double labelTop = tester.getTopLeft(find.text('1 of 2')).dy;
      final Finder fields = find.byType(TextField);
      Finder? m23;
      double nearest = double.infinity;
      for (int i = 0; i < fields.evaluate().length; i++) {
        final double top = tester.getTopLeft(fields.at(i)).dy;
        if (top > labelTop && top < nearest) {
          nearest = top;
          m23 = fields.at(i);
        }
      }
      await tester.enterText(m23!, '3');
      await tester.pumpAndSettle();

      expect(find.textContaining('comes out at nothing'), findsOneWidget);
      expect(saveButton(tester).onPressed, isNull);
    });

    testWidgets('a size more than double the window is taken for a slip',
        (WidgetTester tester) async {
      await pumpSizes(tester);
      await tester.enterText(find.byType(TextField).first, '2206');
      await tester.pumpAndSettle();

      expect(find.textContaining('more than double this window'), findsOneWidget);
      expect(saveButton(tester).onPressed, isNull);
    });

    testWidgets('an empty box is not a size', (WidgetTester tester) async {
      await pumpSizes(tester);
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pumpAndSettle();

      expect(find.textContaining('Type a size'), findsOneWidget);
      expect(saveButton(tester).onPressed, isNull);
    });

    testWidgets('opens on the size already set, and can be put back',
        (WidgetTester tester) async {
      List<PieceSize>? sizes;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: FormulaEditorScreen(
            windowKey: keyForCollar(2),
            windowTitle: 'Sliding Window',
            configSummary: 'Collar 2 · Latch',
            book: FormulaBook(
              FormulaCatalogue.fromJson(catalogueJson()),
              FormulaOverrides.empty(),
            ),
            measurements: window,
            pieceSizes: <PieceSize>[hlAt(205.5)],
            onPieceSizesSaved: (List<PieceSize> saved) => sizes = saved,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('205.5'), findsWidgets);
      expect(find.textContaining('Own size, this window only'), findsOneWidget);
      // Opened on what was saved, nothing has changed yet.
      expect(saveButton(tester).onPressed, isNull);

      await tester.ensureVisible(find.widgetWithText(TextButton, 'Window size'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Window size'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Own size, this window only'), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
      await tester.pumpAndSettle();
      expect(sizes, isEmpty, reason: 'every piece back on the window');
    });

    testWidgets('a size set for a window measured differently is not shown',
        (WidgetTester tester) async {
      // Set against 230cm; this window is 220.6cm. It no longer stands.
      final PieceSize stale = PieceSize(
        ref: FormulaPieceRef.of(keyForCollar(2), 'DC30C', 0),
        label: 'HL',
        dimension: 'h',
        base: 230,
        size: 205.5,
      );
      await pumpSizes(tester, starting: <PieceSize>[stale]);
      expect(find.text('205.5'), findsNothing);
      expect(find.text('220.6'), findsNWidgets(4));
    });
  });

  testWidgets('nothing is saved unless something changed', (WidgetTester tester) async {
    await pump(tester);
    final FilledButton save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save changes'),
    );
    expect(save.onPressed, isNull);
  });
}
