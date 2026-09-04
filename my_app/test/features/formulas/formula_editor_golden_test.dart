import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/theme/app_theme.dart';
import 'package:my_app/features/formulas/data/formula_book.dart';
import 'package:my_app/features/formulas/data/formula_catalogue.dart';
import 'package:my_app/features/formulas/data/formula_overrides_store.dart';
import 'package:my_app/features/formulas/model/formula_window_key.dart';
import 'package:my_app/features/formulas/presentation/formula_editor_screen.dart';

/// The formula screen as a fabricator sees it, so the look can be judged
/// rather than imagined. Run with --update-goldens to refresh.
Future<void> _loadLato() async {
  for (final String name in <String>['Lato-Regular', 'Lato-Bold']) {
    final File file = File('assets/fonts/$name.ttf');
    if (!file.existsSync()) continue;
    final FontLoader loader = FontLoader('Lato')
      ..addFont(Future<ByteData>.value(file.readAsBytesSync().buffer.asByteData()));
    await loader.load();
  }
}

/// The real sliding window, collar 2 with a latch lock -- the configuration
/// from the job that turned up the phantom pieces.
Map<String, dynamic> _catalogue() {
  return <String, dynamic>{
    'version': 1,
    'formulas': <String>[
      '(h + cm) / feet',
      '(w + cm) / feet',
      '(h - 4.2 + cm) / feet',
      '((w - 15.5) / 2 + 8.5 + cm) / feet',
      '((w - 15.5) / 2 + cm) / feet',
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
            'DC26C': <dynamic>[
              <dynamic>['WB', 1],
            ],
            'D29': <dynamic>[
              <dynamic>['HL', 2],
              <dynamic>['HR', 2],
              <dynamic>['WT', 3],
              <dynamic>['WB', 3],
            ],
            'M24': <dynamic>[
              <dynamic>['W1', 4],
              <dynamic>['W2', 4],
              <dynamic>['W3', 4],
              <dynamic>['W4', 4],
            ],
          },
        },
      },
    },
  };
}

void main() {
  testWidgets('formula editor', (WidgetTester tester) async {
    await _loadLato();
    tester.view.physicalSize = const Size(1000, 1900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final FormulaCatalogue catalogue = FormulaCatalogue.fromJson(_catalogue());
    final FormulaWindowKey key = FormulaWindowKey.of(
      context: 'fabrication',
      appWindowCode: 'S_win',
      dimensions: <String>{'collarType', 'lockType', 'rubberType'},
      collarIndex: 2,
      lockType: 1,
      rubberType: 'F',
    )!;

    // One piece already changed, so the screen shows both states at once.
    final FormulaOverrides overrides = FormulaOverrides.empty()
      ..set(FormulaPieceRef.of(key, 'DC30C', 2), '(w + 1.5 + cm) / feet');

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: FormulaEditorScreen(
          windowKey: key,
          windowTitle: 'Sliding Window',
          configSummary: 'Collar 2 · Latch · F rubber',
          book: FormulaBook(catalogue, overrides),
          measurements: const <String, double>{
            'h': 220.6,
            'w': 182.5,
            'cm': 0.5,
            'feet': 30.48,
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(FormulaEditorScreen),
      matchesGoldenFile('goldens/formula_editor.png'),
    );
  });
}
