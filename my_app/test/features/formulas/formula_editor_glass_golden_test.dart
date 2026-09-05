import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/theme/app_theme.dart';
import 'package:my_app/features/formulas/data/formula_book.dart';
import 'package:my_app/features/formulas/data/formula_catalogue.dart';
import 'package:my_app/features/formulas/model/formula_overrides.dart';
import 'package:my_app/features/formulas/model/formula_window_key.dart';
import 'package:my_app/features/formulas/presentation/formula_editor_screen.dart';

/// The glass half of the formula screen, on its own.
///
/// A real window runs to six profiles before the panes are reached, so a
/// picture of the whole screen shows the aluminium and nothing else. This is
/// the panel window that makes the point: three panes, the middle one wider,
/// and the engine's own rail labels saying which slides and which is fixed.
Future<void> _loadFonts() async {
  for (final String name in <String>['Lato-Regular', 'Lato-Bold']) {
    final File file = File('assets/fonts/$name.ttf');
    if (!file.existsSync()) continue;
    final FontLoader loader = FontLoader('Lato')
      ..addFont(Future<ByteData>.value(file.readAsBytesSync().buffer.asByteData()));
    await loader.load();
  }

  final String root = Platform.environment['FLUTTER_ROOT'] ?? r'C:\flutter';
  for (final String path in <String>[
    '$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ]) {
    final File file = File(path);
    if (!file.existsSync()) continue;
    final FontLoader loader = FontLoader('MaterialIcons')
      ..addFont(Future<ByteData>.value(file.readAsBytesSync().buffer.asByteData()));
    await loader.load();
    return;
  }
}

/// The centre-fix panel window, exactly as the catalogue holds it: one profile
/// so the glass is on screen, and the three panes the engine cuts.
Map<String, dynamic> _catalogue() {
  return <String, dynamic>{
    'version': 1,
    'formulas': <String>[
      '(h + cm) / feet', // 0
      'h - 14.2', // 1  every pane's height
      '(w - 24.08) / 4', // 2  a sliding panel
      '(w - 6.96) / 2', // 3  the fixed centre, wider
    ],
    'windows': <String, dynamic>{
      'fabrication/SG_win': <String, dynamic>{
        'variables': <String>['cm', 'feet', 'h', 'w'],
        'configs': <String, dynamic>{
          'collarType=2|lockType=1|rubberType=F|windowType=1': <String, dynamic>{
            'DC30C': <dynamic>[
              <dynamic>['HL', 0],
            ],
          },
        },
        'glass': <String, dynamic>{
          'collarType=2|lockType=1|rubberType=F|windowType=1': <dynamic>[
            <String, dynamic>{'role': 'Slide', 'h': 1, 'w': 2},
            <String, dynamic>{'role': 'Fix', 'h': 1, 'w': 3},
            <String, dynamic>{'role': 'Slide', 'h': 1, 'w': 2},
          ],
        },
      },
    },
  };
}

void main() {
  testWidgets('formula editor glass', (WidgetTester tester) async {
    await _loadFonts();
    tester.view.physicalSize = const Size(1000, 2500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final FormulaCatalogue catalogue = FormulaCatalogue.fromJson(_catalogue());
    final FormulaWindowKey key = FormulaWindowKey.of(
      context: 'fabrication',
      appWindowCode: 'PF3_win',
      dimensions: <String>{'collarType', 'lockType', 'rubberType', 'windowType'},
      collarIndex: 2,
      lockType: 1,
      rubberType: 'F',
    )!;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: FormulaEditorScreen(
          windowKey: key,
          windowTitle: 'Panel Window · Centre Fix',
          configSummary: 'Collar 2 · Latch · F rubber',
          book: FormulaBook(catalogue, FormulaOverrides.empty()),
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

    // The margin note tells the truth about both halves: glass is scored on a
    // sheet, not sawn off a bar, so no blade allowance goes onto it.
    expect(find.textContaining('every aluminium piece'), findsOneWidget);
    expect(find.textContaining('The glass carries none'), findsOneWidget);

    // The panes are on screen, named by the job their panel does.
    expect(find.text('Glass 1 · Slide'), findsOneWidget);
    expect(find.text('Glass 2 · Fix'), findsOneWidget);
    expect(find.text('Glass 3 · Slide'), findsOneWidget);
    expect(find.text('height and width'), findsNWidgets(3));

    // The middle pane really is the wider one: (182.5 - 6.96) / 2 = 87.8
    // against (182.5 - 24.08) / 4 = 39.6, to the millimetre a tape shows.
    expect(find.text('87.8'), findsOneWidget);
    expect(find.text('39.6'), findsNWidgets(2));

    // Glass carries no cutting margin, so its height is the window's less
    // 14.2 and nothing more.
    expect(find.text('206.4'), findsNWidgets(3));

    await expectLater(
      find.byType(FormulaEditorScreen),
      matchesGoldenFile('goldens/formula_editor_glass.png'),
    );
  });
}
