import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/theme/app_theme.dart';
import 'package:my_app/features/formulas/data/formula_book.dart';
import 'package:my_app/features/formulas/data/formula_catalogue.dart';
import 'package:my_app/features/formulas/model/formula_overrides.dart';
import 'package:my_app/features/formulas/model/formula_window_key.dart';
import 'package:my_app/features/formulas/model/piece_size.dart';
import 'package:my_app/features/formulas/presentation/formula_editor_screen.dart';

/// The formula screen for a window measured in inches, on a phone-width
/// screen with the app's own font, so the look can be judged rather than
/// imagined. Run with --update-goldens to refresh.
Future<void> _loadLato() async {
  for (final String name in <String>['Lato-Regular', 'Lato-Bold']) {
    final File file = File('assets/fonts/$name.ttf');
    if (!file.existsSync()) continue;
    final FontLoader loader = FontLoader('Lato')
      ..addFont(Future<ByteData>.value(file.readAsBytesSync().buffer.asByteData()));
    await loader.load();
  }
}

Future<void> _loadIcons() async {
  final String root = Platform.environment['FLUTTER_ROOT'] ?? r'C:\flutter';
  final List<String> candidates = <String>[
    '$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ];
  for (final String path in candidates) {
    final File file = File(path);
    if (!file.existsSync()) continue;
    final FontLoader loader = FontLoader('MaterialIcons')
      ..addFont(Future<ByteData>.value(file.readAsBytesSync().buffer.asByteData()));
    await loader.load();
    return;
  }
}

Map<String, dynamic> _catalogue() {
  return <String, dynamic>{
    'version': 1,
    'formulas': <String>[
      '(h + cm) / feet',
      '(w + cm) / feet',
      '(h - 4.2 + cm) / feet',
      '((w - 15.5) / 2 + 8.5 + cm) / feet',
      '(((w - 20.32) / 2 - 5.08) / 2 + 8.5 + cm) / feet',
      'h - 14.2',
      '(w - 12.3) / 2',
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
            'D29': <dynamic>[
              <dynamic>['HL', 2],
            ],
            'M24': <dynamic>[
              <dynamic>['W1', 3],
              <dynamic>['W2', 4],
            ],
          },
        },
        'glass': <String, dynamic>{
          'collarType=2|lockType=1|rubberType=F': <dynamic>[
            <String, dynamic>{'h': 5, 'w': 6},
          ],
        },
      },
    },
  };
}

void main() {
  final FormulaWindowKey key = FormulaWindowKey.of(
    context: 'fabrication',
    appWindowCode: 'S_win',
    dimensions: <String>{'collarType', 'lockType', 'rubberType'},
    collarIndex: 2,
    lockType: 1,
    rubberType: 'F',
  )!;

  Future<void> pump(WidgetTester tester, {double height = 2400}) async {
    await _loadLato();
    await _loadIcons();
    tester.view.physicalSize = Size(360, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // One formula already the workshop's own, one piece already cut to a
    // size of its own, so every state a piece can be in shows at once.
    final FormulaOverrides overrides = FormulaOverrides.empty()
      ..set(FormulaPieceRef.of(key, 'DC30C', 1), '(w + 3.81 + cm) / feet');
    final PieceSize own = PieceSize(
      ref: FormulaPieceRef.of(key, 'DC30C', 0),
      label: 'HL',
      dimension: 'h',
      base: 220.6625,
      size: 219.71,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: FormulaEditorScreen(
          windowKey: key,
          windowTitle: 'Sliding Window',
          configSummary: 'Collar 2 · Latch · F rubber',
          book: FormulaBook(FormulaCatalogue.fromJson(_catalogue()), overrides),
          measurements: const <String, double>{
            'h': 220.6625,
            'w': 182.88,
            'cm': 0.5,
            'feet': 30.48,
          },
          pieceSizes: <PieceSize>[own],
          inchSuter: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('formula editor in inches', (WidgetTester tester) async {
    await pump(tester);
    await expectLater(
      find.byType(FormulaEditorScreen),
      matchesGoldenFile('goldens/formula_editor_inch.png'),
    );
  });

  testWidgets('one number open for setting', (WidgetTester tester) async {
    await pump(tester, height: 760);
    await tester.tap(find.text("1'' 5'''"));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('length_sheet_more')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/formula_length_sheet.png'),
    );
  });

  testWidgets('a formula typed in inches, with its keys', (WidgetTester tester) async {
    await pump(tester, height: 900);
    await tester.tap(find.byTooltip('Change the formula itself').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, "HL - 1'' 5");
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/formula_editor_inch_typing.png'),
    );
  });
}
