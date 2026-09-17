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

/// The icon font, so a picture of this screen shows its icons rather than the
/// empty boxes a test renders without it. Judging a layout by a picture full
/// of tofu is judging the wrong picture.
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
      // The glass, which carries no margin and no feet: a pane is measured
      // and scored in centimetres from end to end.
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
        // Two panes, both the same size, as a sliding window takes.
        'glass': <String, dynamic>{
          'collarType=2|lockType=1|rubberType=F': <dynamic>[
            <String, dynamic>{'h': 5, 'w': 6},
            <String, dynamic>{'h': 5, 'w': 6},
          ],
        },
      },
    },
  };
}

void main() {
  testWidgets('formula editor', (WidgetTester tester) async {
    await _loadLato();
    await _loadIcons();
    tester.view.physicalSize = const Size(1000, 2700);
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

    // One formula already changed and one piece already cut to a size of its
    // own, so the screen shows every state a piece can be in at once.
    final FormulaOverrides overrides = FormulaOverrides.empty()
      ..set(FormulaPieceRef.of(key, 'DC30C', 2), '(w + 1.5 + cm) / feet');
    final PieceSize ownSize = PieceSize(
      ref: FormulaPieceRef.of(key, 'D29', 0),
      label: 'HL',
      dimension: 'h',
      base: 220.6,
      size: 210,
    );

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
          pieceSizes: <PieceSize>[ownSize],
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
